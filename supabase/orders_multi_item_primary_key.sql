-- Run this in the Supabase SQL Editor for both app_main_schema and test.
-- The application stores one row per item and groups rows by order_id.

alter table app_main_schema.orders
  drop constraint if exists orders_pkey;

alter table app_main_schema.orders
  add constraint orders_pkey primary key (order_id, order_item_id);

alter table test.orders
  drop constraint if exists orders_pkey;

alter table test.orders
  add constraint orders_pkey primary key (order_id, order_item_id);
