# Test Chat Message Notification

Deploy this function as `test-chat-message-notification` with JWT verification
disabled. It is locked to the `test` schema.

Create an Insert webhook on `test.chat_messages` and select
`test-chat-message-notification`.

Required custom secrets:

- `FIREBASE_SERVICE_ACCOUNT`
- `CHAT_WEBHOOK_SECRET`

Add webhook header `x-webhook-secret` with the same value as
`CHAT_WEBHOOK_SECRET`.
