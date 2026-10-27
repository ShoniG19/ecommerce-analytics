-- Revisar los tipos de todas las columnas de staging, incluidas las fechas de orders_raw.
-- Los importes usados abajo deben ser num?ricos y las fechas usadas con BTRIM, texto.
SELECT
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    numeric_precision,
    numeric_scale
FROM information_schema.columns
WHERE table_schema = 'staging'
ORDER BY table_name, ordinal_position;

-- Comprobar la cantidad de filas importadas en las tablas originales

SELECT 'customers_raw' AS tabla, COUNT(*) AS filas FROM staging.customers_raw
UNION ALL
SELECT 'geolocation_raw', COUNT(*) FROM staging.geolocation_raw
UNION ALL
SELECT 'order_items_raw', COUNT(*) FROM staging.order_items_raw
UNION ALL
SELECT 'order_payments_raw', COUNT(*) FROM staging.order_payments_raw
UNION ALL
SELECT 'order_reviews_raw', COUNT(*) FROM staging.order_reviews_raw
UNION ALL
SELECT 'orders_raw', COUNT(*) FROM staging.orders_raw
UNION ALL
SELECT 'products_raw', COUNT(*) FROM staging.products_raw
UNION ALL
SELECT 'sellers_raw', COUNT(*) FROM staging.sellers_raw
UNION ALL
SELECT 'category_translation_raw', COUNT(*) FROM staging.category_translation_raw
ORDER BY tabla;

-- Revisar la cantidad de pedidos por estado

SELECT
    order_status,
    COUNT(*) AS cantidad_pedidos
FROM staging.orders_raw
GROUP BY order_status
ORDER BY cantidad_pedidos DESC;

-- Revisar el rango de fechas de compra y posibles valores nulos

SELECT
    COUNT(*) AS total_pedidos,
    COUNT(*) FILTER (
        WHERE order_id IS NULL
    ) AS order_id_nulos,
    COUNT(*) FILTER (
        WHERE customer_id IS NULL
    ) AS customer_id_nulos,
    COUNT(*) FILTER (
        WHERE order_status IS NULL
    ) AS estado_nulo,
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(order_purchase_timestamp), '') IS NULL
    ) AS fecha_compra_nula,
    MIN(NULLIF(BTRIM(order_purchase_timestamp), '')::timestamp) AS primera_compra,
    MAX(NULLIF(BTRIM(order_purchase_timestamp), '')::timestamp) AS ultima_compra
FROM staging.orders_raw;

-- Comprobar la calidad de los precios y los gastos de envío

SELECT
    COUNT(*) AS total_articulos,
    COUNT(*) FILTER (WHERE price IS NULL) AS precios_nulos,
    COUNT(*) FILTER (WHERE price < 0) AS precios_negativos,
    COUNT(*) FILTER (WHERE freight_value IS NULL) AS envios_nulos,
    COUNT(*) FILTER (WHERE freight_value < 0) AS envios_negativos
FROM staging.order_items_raw;

-- Comprobar la calidad de los pagos

SELECT
    COUNT(*) AS total_pagos,
    COUNT(*) FILTER (WHERE payment_value IS NULL) AS pagos_nulos,
    COUNT(*) FILTER (WHERE payment_value < 0) AS pagos_negativos
FROM staging.order_payments_raw;
