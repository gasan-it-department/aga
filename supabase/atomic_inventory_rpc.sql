-- Installs the same atomic inventory functions in test and app_main_schema.
do $installer$
declare
  target_schema text;
begin
  foreach target_schema in array array['test', 'app_main_schema']
  loop
    execute format($ddl$
      create or replace function %1$I.place_order_with_stock_check(
        p_order_rows jsonb
      )
      returns jsonb
      language plpgsql
      security definer
      set search_path = %1$I, public, auth
      as $function$
      declare
        v_user_id uuid := auth.uid();
        v_order jsonb;
        v_order_id text;
        v_group_id text;
        v_item_id text;
        v_variation jsonb;
        v_variation_id text;
        v_variation_name text;
        v_quantity numeric;
        v_stock numeric;
        v_not_applicable boolean;
        v_new_stock numeric;
        v_now numeric := extract(epoch from clock_timestamp()) * 1000;
      begin
        if v_user_id is null then
          raise exception 'Authentication required';
        end if;

        if p_order_rows is null
          or jsonb_typeof(p_order_rows) <> 'array'
          or jsonb_array_length(p_order_rows) = 0 then
          raise exception 'Order rows are required';
        end if;

        v_group_id := nullif(trim(p_order_rows->0->>'order_group_id'), '');
        if v_group_id is null then
          raise exception 'Order group ID is required';
        end if;

        if exists (
          select 1 from orders where order_group_id = v_group_id
        ) then
          return jsonb_build_object(
            'success', true,
            'already_processed', true,
            'order_group_id', v_group_id
          );
        end if;

        for v_order in
          select value from jsonb_array_elements(p_order_rows)
        loop
          if v_order->>'order_user_id' is distinct from v_user_id::text then
            raise exception 'Order user does not match authenticated user';
          end if;

          if v_order->>'order_group_id' is distinct from v_group_id then
            raise exception 'Every order row must use the same order group ID';
          end if;

          v_order_id := nullif(trim(v_order->>'order_id'), '');
          v_item_id := nullif(trim(v_order->>'order_item_id'), '');
          v_quantity := coalesce((v_order->>'order_quantity')::numeric, 0);
          v_variation := v_order->'order_variation';
          v_variation_id := null;

          if v_order_id is null or v_item_id is null then
            raise exception 'Order ID and item ID are required';
          end if;
          if v_quantity <= 0 then
            raise exception 'Order quantity must be greater than zero';
          end if;

          if v_variation is not null
            and jsonb_typeof(v_variation) = 'object'
            and nullif(trim(v_variation->>'label'), '') is not null then
            v_variation_name := trim(v_variation->>'label');

            select
              variation_id,
              variation_stock,
              variation_stock_not_applicable
            into
              v_variation_id,
              v_stock,
              v_not_applicable
            from store_item_variations
            where variation_item_id = v_item_id
              and lower(variation_name) = lower(v_variation_name)
              and variation_available = true
            order by variation_id
            limit 1
            for update;

            if v_variation_id is null then
              raise exception 'Variation %% is unavailable for item %%',
                v_variation_name, v_item_id;
            end if;

            if not coalesce(v_not_applicable, false) then
              if coalesce(v_stock, 0) < v_quantity then
                raise exception 'Insufficient stock for variation %%',
                  v_variation_name;
              end if;

              v_new_stock := v_stock - v_quantity;
              update store_item_variations
              set variation_stock = v_new_stock,
                  variation_updated_at = v_now
              where variation_id = v_variation_id;

              -- Keep the legacy JSONB value synchronized for older apps.
              update store_items item
              set item_variations = (
                    select jsonb_agg(
                      case
                        when lower(element->>'label') = lower(v_variation_name)
                          then jsonb_set(
                            element,
                            '{stock}',
                            to_jsonb(v_new_stock),
                            true
                          )
                        else element
                      end
                      order by position
                    )
                    from jsonb_array_elements(
                      case
                        when jsonb_typeof(item.item_variations) = 'array'
                          then item.item_variations
                        else '[]'::jsonb
                      end
                    ) with ordinality as legacy(element, position)
                  ),
                  item_stock_updated_at = v_now
              where item_id = v_item_id;
            end if;
          else
            select item_stocks, item_stock_not_applicable
            into v_stock, v_not_applicable
            from store_items
            where item_id = v_item_id
            for update;

            if not found then
              raise exception 'Item %% was not found', v_item_id;
            end if;

            if not coalesce(v_not_applicable, v_stock = -1) then
              if coalesce(v_stock, 0) < v_quantity then
                raise exception 'Insufficient stock for item %%', v_item_id;
              end if;

              update store_items
              set item_stocks = item_stocks - v_quantity,
                  item_stock_updated_at = v_now
              where item_id = v_item_id;
            end if;
          end if;

          insert into inventory_transactions (
            inventory_transaction_id,
            inventory_order_id,
            inventory_order_group_id,
            inventory_item_id,
            inventory_variation_id,
            inventory_quantity,
            inventory_type,
            inventory_created_at,
            inventory_created_by
          ) values (
            'INV_' || md5(v_order_id || ':' || v_item_id || ':' ||
              coalesce(v_variation_id, '') || ':reserve'),
            v_order_id,
            v_group_id,
            v_item_id,
            v_variation_id,
            v_quantity,
            'reserve',
            v_now,
            v_user_id::text
          );
        end loop;

        insert into orders
        select *
        from jsonb_populate_recordset(null::orders, p_order_rows);

        return jsonb_build_object(
          'success', true,
          'already_processed', false,
          'order_group_id', v_group_id
        );
      end;
      $function$;

      revoke all on function %1$I.place_order_with_stock_check(jsonb)
        from public;
      grant execute on function %1$I.place_order_with_stock_check(jsonb)
        to authenticated;
    $ddl$, target_schema);

    execute format($ddl$
      create or replace function %1$I.cancel_order_and_restore_stock(
        p_order_group_id text
      )
      returns jsonb
      language plpgsql
      security definer
      set search_path = %1$I, public, auth
      as $function$
      declare
        v_user_id uuid := auth.uid();
        v_transaction record;
        v_variation_name text;
        v_new_stock numeric;
        v_now numeric := extract(epoch from clock_timestamp()) * 1000;
      begin
        if v_user_id is null then
          raise exception 'Authentication required';
        end if;
        if nullif(trim(p_order_group_id), '') is null then
          raise exception 'Order group ID is required';
        end if;

        perform 1
        from orders
        where order_group_id = p_order_group_id
        for update;

        if not found then
          raise exception 'Order was not found';
        end if;

        if not exists (
          select 1
          from orders order_row
          where order_row.order_group_id = p_order_group_id
            and (
              order_row.order_user_id = v_user_id::text
              or exists (
                select 1
                from sellers seller
                where seller.seller_id = order_row.order_seller_id
                  and seller.seller_user_id = v_user_id::text
              )
            )
        ) then
          raise exception 'You cannot cancel this order';
        end if;

        if exists (
          select 1 from orders
          where order_group_id = p_order_group_id
            and lower(order_status) = 'completed'
        ) then
          raise exception 'Completed orders cannot be cancelled';
        end if;

        for v_transaction in
          select reserve.*
          from inventory_transactions reserve
          where reserve.inventory_order_group_id = p_order_group_id
            and reserve.inventory_type = 'reserve'
            and not exists (
              select 1
              from inventory_transactions restored
              where restored.inventory_order_id = reserve.inventory_order_id
                and restored.inventory_item_id = reserve.inventory_item_id
                and coalesce(restored.inventory_variation_id, '') =
                    coalesce(reserve.inventory_variation_id, '')
                and restored.inventory_type = 'restore'
            )
          for update
        loop
          if v_transaction.inventory_variation_id is not null then
            select variation_name
            into v_variation_name
            from store_item_variations
            where variation_id = v_transaction.inventory_variation_id
            for update;

            update store_item_variations
            set variation_stock = variation_stock +
                    v_transaction.inventory_quantity,
                variation_updated_at = v_now
            where variation_id = v_transaction.inventory_variation_id
              and variation_stock_not_applicable = false
            returning variation_stock into v_new_stock;

            if found then
              update store_items item
              set item_variations = (
                    select jsonb_agg(
                      case
                        when lower(element->>'label') = lower(v_variation_name)
                          then jsonb_set(
                            element,
                            '{stock}',
                            to_jsonb(v_new_stock),
                            true
                          )
                        else element
                      end
                      order by position
                    )
                    from jsonb_array_elements(
                      case
                        when jsonb_typeof(item.item_variations) = 'array'
                          then item.item_variations
                        else '[]'::jsonb
                      end
                    ) with ordinality as legacy(element, position)
                  ),
                  item_stock_updated_at = v_now
              where item_id = v_transaction.inventory_item_id;
            end if;
          else
            update store_items
            set item_stocks = item_stocks +
                    v_transaction.inventory_quantity,
                item_stock_updated_at = v_now
            where item_id = v_transaction.inventory_item_id
              and item_stock_not_applicable = false
              and item_stocks <> -1;
          end if;

          insert into inventory_transactions (
            inventory_transaction_id,
            inventory_order_id,
            inventory_order_group_id,
            inventory_item_id,
            inventory_variation_id,
            inventory_quantity,
            inventory_type,
            inventory_created_at,
            inventory_created_by
          ) values (
            'INV_' || md5(v_transaction.inventory_order_id || ':' ||
              v_transaction.inventory_item_id || ':' ||
              coalesce(v_transaction.inventory_variation_id, '') || ':restore'),
            v_transaction.inventory_order_id,
            p_order_group_id,
            v_transaction.inventory_item_id,
            v_transaction.inventory_variation_id,
            v_transaction.inventory_quantity,
            'restore',
            v_now,
            v_user_id::text
          ) on conflict do nothing;
        end loop;

        update orders
        set order_status = 'cancelled',
            order_inventory_status = 'restored'
        where order_group_id = p_order_group_id;

        return jsonb_build_object(
          'success', true,
          'already_cancelled', false,
          'order_group_id', p_order_group_id
        );
      end;
      $function$;

      revoke all on function %1$I.cancel_order_and_restore_stock(text)
        from public;
      grant execute on function %1$I.cancel_order_and_restore_stock(text)
        to authenticated;
    $ddl$, target_schema);
  end loop;
end;
$installer$;
