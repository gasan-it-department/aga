# Test Order Status Notification

Deploy this function as `test-order-status-notification` with JWT verification
disabled. Connect it only to the `test.orders` update webhook.

Required custom secrets:

- `ORDER_WEBHOOK_SECRET`
- `FIREBASE_SERVICE_ACCOUNT`
