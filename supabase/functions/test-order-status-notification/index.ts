import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v5.9.6/index.ts";

type OrderRecord = {
  order_id?: string;
  order_user_id?: string;
  order_status?: string;
};

type DatabaseWebhookPayload = {
  type?: string;
  table?: string;
  schema?: string;
  record?: OrderRecord;
  old_record?: OrderRecord;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-webhook-secret",
};
const targetSchema = "test";
const functionName = "test-order-status-notification";

function statusTitle(status: string): string {
  switch (status) {
    case "preparing":
      return "Your order is being prepared";
    case "ready for pickup":
    case "ready_for_pickup":
    case "ready":
      return "Your order is ready for pickup";
    case "out for delivery":
    case "out_for_delivery":
      return "Your order is out for delivery";
    case "completed":
      return "Your order is completed";
    case "cancelled":
    case "canceled":
      return "Your order was cancelled";
    default:
      return `Order updated: ${status.toUpperCase()}`;
  }
}

async function firebaseAccessToken(): Promise<string> {
  const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(serviceAccount.private_key, "RS256");
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok) throw new Error(`Firebase authentication failed: ${JSON.stringify(result)}`);
  return result.access_token;
}

async function sendPush(tokens: string[], title: string, body: string, orderId: string) {
  if (tokens.length === 0) return { sent: 0, failed: 0, errors: [] };
  if (!Deno.env.get("FIREBASE_SERVICE_ACCOUNT")) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT secret is missing.");
  }
  const accessToken = await firebaseAccessToken();
  const projectId = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!).project_id;

  const results = await Promise.allSettled(tokens.map(async (token) => {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            data: { order_id: orderId, title, body },
            webpush: {
              headers: { Urgency: "high" },
              notification: {
                title,
                body,
                icon: "/aga_gasan_app_logo_rounded.png",
                image: "/aga_gasan_app_logo_rounded.png",
                tag: orderId,
                renotify: true,
                requireInteraction: false,
                data: { order_id: orderId },
              },
              fcm_options: { link: "/" },
            },
          },
        }),
      },
    );
    if (!response.ok) throw new Error(`FCM ${response.status}: ${await response.text()}`);
    return await response.json();
  }));
  const errors = results
    .filter((result) => result.status === "rejected")
    .map((result) => String((result as PromiseRejectedResult).reason));
  errors.forEach((error) => console.error("Push delivery failed:", error));
  return {
    sent: results.length - errors.length,
    failed: errors.length,
    errors,
  };
}

Deno.serve(async (req) => {
  console.log(`${functionName} invoked.`);
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const expectedSecret = Deno.env.get("ORDER_WEBHOOK_SECRET");
    if (!expectedSecret || req.headers.get("x-webhook-secret") !== expectedSecret) {
      return new Response("Unauthorized", { status: 401, headers: corsHeaders });
    }

    const payload = (await req.json()) as DatabaseWebhookPayload;
    if (payload.schema !== targetSchema) {
      throw new Error(`Expected schema ${targetSchema}, received ${payload.schema ?? "none"}.`);
    }
    const order = payload.record;
    const oldOrder = payload.old_record;
    const newStatus = order?.order_status?.trim().toLowerCase() ?? "";
    const oldStatus = oldOrder?.order_status?.trim().toLowerCase() ?? "";
    const userId = order?.order_user_id;
    const orderId = order?.order_id;

    if (
      payload.type !== "UPDATE" ||
      !order ||
      !userId ||
      !orderId ||
      !newStatus ||
      newStatus === oldStatus
    ) {
      return Response.json({ skipped: true }, { headers: corsHeaders });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const database = supabase.schema(targetSchema);
    const { data: user, error: fetchError } = await database
      .from("user_data")
      .select("limited_notifications, web_fcm_tokens")
      .eq("user_id", userId)
      .maybeSingle();

    if (fetchError) throw fetchError;

    const existing = Array.isArray(user?.limited_notifications)
      ? user.limited_notifications
      : [];
    const notificationId = `ORDER_${orderId}_${newStatus.replaceAll(" ", "_")}`;

    const notification = {
      id: notificationId,
      title: statusTitle(newStatus),
      message: `Order ${orderId} is now ${newStatus}.`,
      source: "order",
      order_id: orderId,
      status: newStatus,
      date_sent: Date.now(),
    };

    const duplicate = existing.some((item) => item?.id === notificationId);
    if (!duplicate) {
      const { error: updateError } = await database
        .from("user_data")
        .update({ limited_notifications: [notification, ...existing].slice(0, 100) })
        .eq("user_id", userId);

      if (updateError) throw updateError;
    }

    const tokens = Array.isArray(user?.web_fcm_tokens)
      ? user.web_fcm_tokens.filter((token) => typeof token === "string")
      : [];
    console.log(`Order ${orderId}: found ${tokens.length} web FCM token(s).`);
    const push = await sendPush(tokens, notification.title, notification.message, orderId);
    console.log("FCM delivery result:", JSON.stringify(push));
    if (tokens.length === 0) {
      throw new Error(`No web FCM tokens found for buyer ${userId} in schema ${payload.schema}.`);
    }
    if (push.failed > 0) {
      throw new Error(`FCM delivery failed: ${push.errors.join(" | ")}`);
    }

    return Response.json(
      { delivered: true, duplicate_in_app: duplicate, push_tokens: tokens.length, push, notification },
      { headers: corsHeaders },
    );
  } catch (error) {
    console.error(error);
    return Response.json(
      { error: error instanceof Error ? error.message : "Unknown error" },
      { status: 500, headers: corsHeaders },
    );
  }
});
