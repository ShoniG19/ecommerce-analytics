-- Requiere las tablas de analytics creadas por 04.
-- Definiciones: report/definicion_indicadores.md.
-- Si fact_sales ya existe, omitir SOLO el CREATE TABLE y ejecutar los UPDATE
-- y los controles. No se eliminan filas ni se reconstruye la tabla existente.
-- Los UPDATE usan los datos ya cargados; no incorporan nuevos pedidos/articulos.

-- Crear la tabla de hechos con una fila por artículo de pedido

CREATE TABLE analytics.fact_sales AS
SELECT
    oi.order_id,
    oi.order_item_id,
    o.customer_id,
    c.customer_unique_id,
    oi.product_id,
    COALESCE(
        NULLIF(BTRIM(ct.product_category_name_english), ''),
        NULLIF(BTRIM(p.product_category_name), ''),
        'unknown'
    ) AS product_category,
    oi.seller_id,
    o.order_status,
    c.customer_state,
    s.seller_state,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS item_total_value,
    CASE
        WHEN o.order_status = 'delivered'
         AND o.order_delivered_customer_date IS NOT NULL
         AND o.order_estimated_delivery_date IS NOT NULL
        THEN o.order_delivered_customer_date::date
             > o.order_estimated_delivery_date::date
        ELSE NULL
    END AS is_delivered_late
FROM analytics.order_items oi
JOIN analytics.orders o
    ON oi.order_id = o.order_id
LEFT JOIN analytics.products p
    ON oi.product_id = p.product_id
LEFT JOIN analytics.category_translation ct
    ON p.product_category_name = ct.product_category_name
LEFT JOIN analytics.customers c
    ON o.customer_id = c.customer_id
LEFT JOIN analytics.sellers s
    ON oi.seller_id = s.seller_id;

-- Actualizar tambien tablas existentes: entregar durante el dia estimado
-- es puntual. Una fecha faltante conserva la clasificacion NULL.
-- IS DISTINCT FROM evita reescribir filas que ya tienen el valor correcto.

UPDATE analytics.fact_sales
SET is_delivered_late = CASE
    WHEN order_status = 'delivered'
     AND order_delivered_customer_date IS NOT NULL
     AND order_estimated_delivery_date IS NOT NULL
    THEN order_delivered_customer_date::date > order_estimated_delivery_date::date
    ELSE NULL
END
WHERE is_delivered_late IS DISTINCT FROM CASE
    WHEN order_status = 'delivered'
     AND order_delivered_customer_date IS NOT NULL
     AND order_estimated_delivery_date IS NOT NULL
    THEN order_delivered_customer_date::date > order_estimated_delivery_date::date
    ELSE NULL
END;

-- Debe devolver cero: clasificaciones que no siguen la regla por dia

SELECT COUNT(*) AS articulos_con_clasificacion_incorrecta
FROM analytics.fact_sales
WHERE is_delivered_late IS DISTINCT FROM CASE
    WHEN order_status = 'delivered'
     AND order_delivered_customer_date IS NOT NULL
     AND order_estimated_delivery_date IS NOT NULL
    THEN order_delivered_customer_date::date > order_estimated_delivery_date::date
    ELSE NULL
END;

-- Verificar que la tabla de hechos conserve todos los artículos de pedido

SELECT
    (SELECT COUNT(*) FROM analytics.order_items) AS filas_originales,
    (SELECT COUNT(*) FROM analytics.fact_sales) AS filas_fact_sales;

-- Verificar que cada pedido y número de artículo formen una clave única

SELECT
    COUNT(*) AS total_filas,
    COUNT(DISTINCT (order_id, order_item_id)) AS claves_unicas,
    COUNT(*) - COUNT(DISTINCT (order_id, order_item_id)) AS claves_duplicadas
FROM analytics.fact_sales;

-- Comparar precios y costos de envío entre los artículos originales y la tabla de hechos

SELECT
    (SELECT ROUND(SUM(price), 2)
     FROM analytics.order_items) AS precio_original,
    (SELECT ROUND(SUM(price), 2)
     FROM analytics.fact_sales) AS precio_fact_sales,
    (SELECT ROUND(SUM(freight_value), 2)
     FROM analytics.order_items) AS envio_original,
    (SELECT ROUND(SUM(freight_value), 2)
     FROM analytics.fact_sales) AS envio_fact_sales;

-- Contar los productos que no tienen categoría identificada

SELECT
    COUNT(*) AS filas_fact_sales,
    COUNT(DISTINCT product_id) AS productos_distintos,
    COUNT(DISTINCT order_id) AS pedidos_distintos
FROM analytics.fact_sales
WHERE product_category IS NULL
   OR TRIM(product_category) = ''
   OR product_category = 'unknown';

-- Revisar si los productos sin categoría tienen una categoría original disponible

SELECT
    p.product_category_name AS categoria_original,
    COUNT(*) AS filas_fact_sales,
    COUNT(DISTINCT f.product_id) AS productos_distintos
FROM analytics.fact_sales f
LEFT JOIN analytics.products p
    ON f.product_id = p.product_id
WHERE f.product_category IS NULL
   OR TRIM(f.product_category) = ''
   OR f.product_category = 'unknown'
GROUP BY p.product_category_name
ORDER BY filas_fact_sales DESC;

-- Recuperar categorias faltantes aplicando la misma prioridad del CREATE:
-- traduccion, categoria original y unknown. Incluye unknown de cargas anteriores
-- La subconsulta escalar falla si el producto tiene varias coincidencias:
-- investigar esa duplicacion en vez de elegir una categoria arbitrariamente

UPDATE analytics.fact_sales f
SET product_category = COALESCE((
    SELECT COALESCE(
        NULLIF(BTRIM(ct.product_category_name_english), ''),
        NULLIF(BTRIM(p.product_category_name), '')
    )
    FROM analytics.products p
    LEFT JOIN analytics.category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE p.product_id = f.product_id
), 'unknown')
WHERE NULLIF(BTRIM(f.product_category), '') IS NULL
   OR f.product_category = 'unknown';

-- Verificar que no queden categorías vacías o nulas

SELECT
    COUNT(*) FILTER (
        WHERE product_category IS NULL
    ) AS categorias_nulas,
    COUNT(*) FILTER (
        WHERE TRIM(product_category) = ''
    ) AS categorias_vacias,
    COUNT(*) FILTER (
        WHERE product_category = 'unknown'
    ) AS categorias_unknown
FROM analytics.fact_sales;
