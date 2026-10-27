-- Crear las nueve tablas de analytics y comprobar cada transformación
-- Requiere: 01 ejecutado y las nueve tablas de staging cargadas y revisadas con 02 y 03
-- Ejecutar completo una sola vez. Si las tablas ya existen, ejecutar únicamente
-- los SELECT de comprobación; este script no elimina ni reemplaza tablas existentes.
-- Las columnas sin conversión explícita conservan el tipo de staging.
-- Los SELECT muestran diagnósticos; no detienen la carga por anomalías.
-- La transacción evita dejar una creación parcial si falla una conversión o un CREATE.

BEGIN;

-- customers
-- Crear tabla limpia

CREATE TABLE analytics.customers AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
FROM staging.customers_raw;

-- Validar la tabla transformada

SELECT
    (SELECT COUNT(*) FROM staging.customers_raw) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.customers) AS filas_transformadas;

-- Revisar los tipos de datos

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'customers'
ORDER BY ordinal_position;


-- Revisar identificadores nulos y cantidad de clientes por estado

SELECT
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS ids_nulos,
    COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS ids_unicos_nulos,
    COUNT(DISTINCT customer_state) AS estados_distintos
FROM analytics.customers;

-- Contar clientes por estado para identificar las principales regiones

SELECT
    customer_state,
    COUNT(*) AS cantidad_clientes
FROM analytics.customers
GROUP BY customer_state
ORDER BY cantidad_clientes DESC;


-- orders
-- Crear tabla limpia, varias fechas están almacenadas como texto (character varying o text) y los importes están almacenados como real,
-- conviene convertir las fechas a timestamp y los importes monetarios a numeric, que permite controlar mejor la precisión decimal

CREATE TABLE analytics.orders AS
SELECT
    order_id,
    customer_id,
    order_status,
    NULLIF(BTRIM(order_purchase_timestamp), '')::timestamp
        AS order_purchase_timestamp,
    NULLIF(BTRIM(order_approved_at), '')::timestamp
        AS order_approved_at,
    NULLIF(BTRIM(order_delivered_carrier_date), '')::timestamp
        AS order_delivered_carrier_date,
    NULLIF(BTRIM(order_delivered_customer_date), '')::timestamp
        AS order_delivered_customer_date,
    NULLIF(BTRIM(order_estimated_delivery_date), '')::timestamp
        AS order_estimated_delivery_date
FROM staging.orders_raw;


-- Validar la tabla transformada

SELECT
    (SELECT COUNT(*) FROM staging.orders_raw) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.orders) AS filas_transformadas;

-- Revisar los tipos de datos

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'orders'
ORDER BY ordinal_position;


-- Revisar el rango temporal y los pedidos sin fecha de compra

SELECT
    MIN(order_purchase_timestamp) AS primera_compra,
    MAX(order_purchase_timestamp) AS ultima_compra,
    COUNT(*) FILTER (
        WHERE order_purchase_timestamp IS NULL
    ) AS compras_sin_fecha
FROM analytics.orders;

-- order_items
-- Crear tabla limpia, convertimos los importes de real a numeric(12,2) para trabajar con dos decimales en los cálculos monetarios. 
-- También convertimos la fecha límite de envío a timestamp

CREATE TABLE analytics.order_items AS
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    NULLIF(BTRIM(shipping_limit_date), '')::timestamp
        AS shipping_limit_date,
    price::numeric(12,2) AS price,
    freight_value::numeric(12,2) AS freight_value
FROM staging.order_items_raw;


-- Validar la tabla transformada

SELECT
    (SELECT COUNT(*) FROM staging.order_items_raw) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.order_items) AS filas_transformadas;

-- Revisar los tipos de datos

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'order_items'
ORDER BY ordinal_position;


-- Verificar valores nulos y rangos de precios y costos de envío

SELECT
    COUNT(*) FILTER (WHERE price IS NULL) AS precios_nulos,
    COUNT(*) FILTER (WHERE freight_value IS NULL) AS envios_nulos,
    MIN(price) AS precio_minimo,
    MAX(price) AS precio_maximo,
    MIN(freight_value) AS envio_minimo,
    MAX(freight_value) AS envio_maximo
FROM analytics.order_items;


-- order_payments
-- Crear tabla limpia, convertimos los importes de real a numeric(12,2)

CREATE TABLE analytics.order_payments AS
SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value::numeric(12,2) AS payment_value
FROM staging.order_payments_raw;


-- Validar la tabla transformada

SELECT
    (SELECT COUNT(*) FROM staging.order_payments_raw) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.order_payments) AS filas_transformadas;

-- Revisar los tipos de datos

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'order_payments'
ORDER BY ordinal_position;


-- Calcular la cantidad de pagos y el importe total por cada método de pago

SELECT
    payment_type,
    COUNT(*) AS cantidad_pagos,
    ROUND(SUM(payment_value), 2) AS importe_total
FROM analytics.order_payments
GROUP BY payment_type
ORDER BY importe_total DESC;


-- products
-- Crear tabla limpia

CREATE TABLE analytics.products AS
SELECT
    product_id,
    product_category_name,
    product_name_lenght,
    product_description_lenght,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
FROM staging.products_raw;

-- Validar la tabla transformada

SELECT
    (SELECT COUNT(*) FROM staging.products_raw) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.products) AS filas_transformadas;

-- Revisar los tipos de datos

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'products'
ORDER BY ordinal_position;


-- Revisar productos sin categoría y distribución de categorías registradas

SELECT
    COUNT(*) FILTER (
        WHERE product_category_name IS NULL
    ) AS productos_sin_categoria,
    COUNT(DISTINCT product_category_name) AS categorias_distintas
FROM analytics.products;


-- category_translation
-- Crear tabla limpia

CREATE TABLE analytics.category_translation AS
SELECT
    product_category_name,
    product_category_name_english
FROM staging.category_translation_raw;

-- Validar la tabla transformada

SELECT
    (SELECT COUNT(*) FROM staging.category_translation_raw) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.category_translation) AS filas_transformadas;

-- Revisar los tipos de datos

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'category_translation'
ORDER BY ordinal_position;


-- Identificar productos con categoría registrada pero sin traducción al inglés

SELECT
    COUNT(*) AS productos_sin_traduccion
FROM analytics.products p
LEFT JOIN analytics.category_translation ct
    ON p.product_category_name = ct.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND ct.product_category_name IS NULL;


-- sellers
-- Crear tabla limpia

CREATE TABLE analytics.sellers AS
SELECT
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
FROM staging.sellers_raw;

-- Validar la tabla transformada

SELECT
    (SELECT COUNT(*) FROM staging.sellers_raw) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.sellers) AS filas_transformadas;

-- Revisar los tipos de datos

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'sellers'
ORDER BY ordinal_position;


-- Revisar identificadores nulos y cantidad de vendedores por estado

SELECT
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS ids_nulos,
    COUNT(DISTINCT seller_state) AS estados_distintos
FROM analytics.sellers;

-- Contar vendedores por estado para analizar su distribución geográfica

SELECT
    seller_state,
    COUNT(*) AS cantidad_vendedores
FROM analytics.sellers
GROUP BY seller_state
ORDER BY cantidad_vendedores DESC;


-- order_reviews
-- Crear tabla limpia, convertimos las fechas a timestamp

CREATE TABLE analytics.order_reviews AS
SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    NULLIF(BTRIM(review_creation_date), '')::timestamp
        AS review_creation_date,
    NULLIF(BTRIM(review_answer_timestamp), '')::timestamp
        AS review_answer_timestamp
FROM staging.order_reviews_raw;


-- Validar la tabla transformada

SELECT
    (SELECT COUNT(*) FROM staging.order_reviews_raw) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.order_reviews) AS filas_transformadas;

-- Revisar los tipos de datos

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'order_reviews'
ORDER BY ordinal_position;


-- Revisar puntuaciones válidas y fechas faltantes en las reseñas

SELECT
    COUNT(*) FILTER (
        WHERE review_score IS NULL
    ) AS puntuaciones_nulas,
    COUNT(*) FILTER (
        WHERE review_score NOT BETWEEN 1 AND 5
    ) AS puntuaciones_fuera_de_rango,
    COUNT(*) FILTER (
        WHERE review_creation_date IS NULL
    ) AS fechas_resena_nulas,
    COUNT(*) FILTER (
        WHERE review_answer_timestamp IS NULL
    ) AS fechas_respuesta_nulas
FROM analytics.order_reviews;


-- geolocation
-- Crear tabla limpia

CREATE TABLE analytics.geolocation AS
SELECT
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
FROM staging.geolocation_raw;


-- Validar la tabla transformada

SELECT
    (SELECT COUNT(*) FROM staging.geolocation_raw) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.geolocation) AS filas_transformadas;

-- Revisar los tipos de datos

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'analytics'
  AND table_name = 'geolocation'
ORDER BY ordinal_position;


-- Revisar coordenadas nulas y valores fuera de los rangos geográficos válidos

SELECT
    COUNT(*) FILTER (
        WHERE geolocation_lat IS NULL OR geolocation_lng IS NULL
    ) AS coordenadas_nulas,
    COUNT(*) FILTER (
        WHERE geolocation_lat NOT BETWEEN -90 AND 90
           OR geolocation_lng NOT BETWEEN -180 AND 180
    ) AS coordenadas_invalidas
FROM analytics.geolocation;

COMMIT;
