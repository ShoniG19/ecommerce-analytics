-- Comprobar si hay pedidos que no tienen un cliente asociado

SELECT COUNT(*) AS pedidos_sin_cliente
FROM staging.orders_raw o
LEFT JOIN staging.customers_raw c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Comprobar si hay artículos que no tienen un pedido asociado

SELECT COUNT(*) AS articulos_sin_pedido
FROM staging.order_items_raw oi
LEFT JOIN staging.orders_raw o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Comprobar si hay artículos que no tienen un producto asociado

SELECT COUNT(*) AS articulos_sin_producto
FROM staging.order_items_raw oi
LEFT JOIN staging.products_raw p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- Comprobar si hay artículos que no tienen un vendedor asociado

SELECT COUNT(*) AS articulos_sin_vendedor
FROM staging.order_items_raw oi
LEFT JOIN staging.sellers_raw s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

-- Comprobar si hay pagos que no tienen un pedido asociado

SELECT COUNT(*) AS pagos_sin_pedido
FROM staging.order_payments_raw pay
LEFT JOIN staging.orders_raw o
    ON pay.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Comprobar si hay reseñas que no tienen un pedido asociado

SELECT COUNT(*) AS resenas_sin_pedido
FROM staging.order_reviews_raw r
LEFT JOIN staging.orders_raw o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;
