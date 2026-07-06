import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "https://deno.land/x/jose@v5.9.6/index.ts";

type ChatMessage = {
  message_id?: string;
  message_conversation_id?: string;
  message_sender_id?: string;
  message_body?: string;
  message_image_url?: string;
};

type WebhookPayload = {
  type?: string;
  table?: string;
  schema?: string;
  record?: ChatMessage;
};

const targetSchema = "app_main_schema";
const functionName = "live-chat-message-notification";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, x-webhook-secret",
};

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

async function sendPush(
  tokens: string[],
  title: string,
  body: string,
  conversationId: string,
  messageId: string,
) {
  if (tokens.length === 0) return { sent: 0, failed: 0, errors: [] };
  const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
  const accessToken = await firebaseAccessToken();

  const results = await Promise.allSettled(tokens.map(async (token) => {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token,
            data: {
              title,
              body,
              notification_type: "chat_message",
              conversation_id: conversationId,
              message_id: messageId,
            },
            webpush: {
              headers: { Urgency: "high" },
              notification: {
                title,
                body,
                icon: "/aga_gasan_app_logo_rounded.png",
                image: "/aga_gasan_app_logo_rounded.png",
                tag: messageId,
                renotify: true,
                requireInteraction: false,
                data: {
                  notification_type: "chat_message",
                  conversation_id: conversationId,
                  message_id: messageId,
                },
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
  return { sent: results.length - errors.length, failed: errors.length, errors };
}

Deno.serve(async (req) => {
  console.log(`${functionName} invoked.`);
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const expectedSecret = Deno.env.get("CHAT_WEBHOOK_SECRET");
    if (!expectedSecret || req.headers.get("x-webhook-secret") !== expectedSecret) {
      return new Response("Unauthorized", { status: 401, headers: corsHeaders });
    }

    const payload = (await req.json()) as WebhookPayload;
    if (payload.schema !== targetSchema) {
      throw new Error(`Expected schema ${targetSchema}, received ${payload.schema ?? "none"}.`);
    }
    const message = payload.record;
    if (
      payload.type !== "INSERT" ||
      payload.table !== "chat_messages" ||
      !message?.message_id ||
      !message.message_conversation_id ||
      !message.message_sender_id
    ) {
      return Response.json({ skipped: true }, { headers: corsHeaders });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const database = supabase.schema(targetSchema);
    const { data: conversation, error: conversationError } = await database
      .from("chat_conversations")
      .select("conversation_buyer_id, conversation_seller_id")
      .eq("conversation_id", message.message_conversation_id)
      .maybeSingle();
    if (conversationError || !conversation) {
      console.error("Conversation lookup failed:", conversationError);
      return Response.json(
        {
          delivered: false,
          skipped: "conversation_not_found",
          conversation_id: message.message_conversation_id,
          error: conversationError?.message,
        },
        { headers: corsHeaders },
      );
    }

    let recipientId: string;
    let title: string;
    if (message.message_sender_id === conversation.conversation_buyer_id) {
      const { data: seller, error } = await database
        .from("sellers")
        .select("seller_user_id")
        .eq("seller_id", conversation.conversation_seller_id)
        .maybeSingle();
      if (error) throw error;
      recipientId = seller?.seller_user_id;
      const { data: buyer } = await database
        .from("user_data")
        .select("user_name")
        .eq("user_id", conversation.conversation_buyer_id)
        .maybeSingle();
      title = buyer?.user_name?.trim() || "Buyer";
    } else {
      recipientId = conversation.conversation_buyer_id;
      const { data: seller } = await database
        .from("sellers")
        .select("seller_store_name")
        .eq("seller_id", conversation.conversation_seller_id)
        .maybeSingle();
      title = seller?.seller_store_name
        ? `New message from ${seller.seller_store_name}`
        : "New seller message";
    }
    if (!recipientId) {
      return Response.json(
        { delivered: false, skipped: "recipient_not_found" },
        { headers: corsHeaders },
      );
    }

    const { data: user, error: userError } = await database
      .from("user_data")
      .select("web_fcm_tokens")
      .eq("user_id", recipientId)
      .maybeSingle();
    if (userError) {
      console.error("Recipient user lookup failed:", userError);
      return Response.json(
        {
          delivered: false,
          skipped: "recipient_user_not_found",
          recipient_id: recipientId,
          error: userError.message,
        },
        { headers: corsHeaders },
      );
    }

    const tokens = Array.isArray(user?.web_fcm_tokens)
      ? user.web_fcm_tokens.filter((token) => typeof token === "string")
      : [];
    if (tokens.length === 0) {
      return Response.json(
        {
          delivered: false,
          skipped: "no_web_fcm_tokens",
          recipient_id: recipientId,
        },
        { headers: corsHeaders },
      );
    }
    const body = message.message_body?.trim() ||
      (message.message_image_url ? "Sent an image." : "Sent a message.");
    console.log(`Chat ${message.message_id}: found ${tokens.length} web FCM token(s).`);
    const push = await sendPush(
      tokens,
      title,
      body.length > 140 ? `${body.slice(0, 137)}...` : body,
      message.message_conversation_id,
      message.message_id,
    );
    console.log("Chat FCM delivery result:", JSON.stringify(push));

    return Response.json(
      { delivered: push.sent > 0, recipient_id: recipientId, push_tokens: tokens.length, push },
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
