# Live Chat Message Notification

Deploy this function as `live-chat-message-notification` with JWT verification
disabled.

Required custom secrets:

- `FIREBASE_SERVICE_ACCOUNT`
- `CHAT_WEBHOOK_SECRET`

Create a Supabase database webhook:

- Schema: `app_main_schema`
- Table: `chat_messages`
- Event: `Insert`
- Type: Supabase Edge Functions
- Function: `live-chat-message-notification`
- Header: `x-webhook-secret` = the same value as `CHAT_WEBHOOK_SECRET`

The function resolves whether the recipient is the buyer or seller and sends
Firebase web push notifications to `user_data.web_fcm_tokens`.
