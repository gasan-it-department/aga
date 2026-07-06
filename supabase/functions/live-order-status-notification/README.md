# Live Order Status Notification

Deploy this function as `live-order-status-notification` with JWT verification
disabled. Connect it only to the `app_main_schema.orders` update webhook.

Required custom secrets:

- `ORDER_WEBHOOK_SECRET`
- `FIREBASE_SERVICE_ACCOUNT`
