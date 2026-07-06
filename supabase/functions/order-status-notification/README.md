# Order Status Notification Webhook

This Edge Function receives `orders` update webhooks and adds an order-status
notification to the buyer's `user_data.limited_notifications`.

## Deploy

```powershell
supabase functions deploy order-status-notification --no-verify-jwt
supabase secrets set ORDER_WEBHOOK_SECRET="replace-with-a-long-random-secret"
```

Add the Firebase service-account JSON as the custom secret
`FIREBASE_SERVICE_ACCOUNT`. Download it from Firebase Console under
**Project Settings > Service accounts > Generate new private key**, then paste
the entire JSON object as the secret value.

## Create the Database Webhook

In the Supabase Dashboard, open **Database > Webhooks** and create:

- Name: `order-status-notification`
- Table: `orders`
- Events: `Update`
- Type: `Supabase Edge Functions`
- Edge Function: `order-status-notification`
- HTTP Header: `x-webhook-secret: <the same ORDER_WEBHOOK_SECRET>`

Create the webhook for every schema containing an active `orders` table.

The function uses the service-role key supplied automatically by Supabase Edge
Functions. Never place that key in Flutter or commit it to the repository.
