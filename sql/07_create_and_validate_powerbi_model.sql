-- Preparar el modelo de Power BI. Requiere 04 y fact_sales creada/actualizada por 05
-- Ejecutar COMPLETO, incluso si estas vistas ya existen. No elimina tablas.
-- Las vistas consultan analytics en tiempo real; Power BI en modo Importar
-- requiere una actualizacion para incorporar cambios de PostgreSQL.
-- Ante un error dentro de la transaccion, ejecutar ROLLBACK antes de reintentar.

BEGIN;

-- Detenerse si las claves de origen pueden multiplicar pedidos o importes
-- No se eliminan duplicados ni se escoge una fila arbitrariamente
DO $$
BEGIN
    IF EXISTS (
        SELECT order_id FROM analytics.orders GROUP BY order_id
        HAVING COUNT(*) > 1 OR NULLIF(BTRIM(order_id), '') IS NULL
    ) THEN
        RAISE EXCEPTION 'analytics.orders: revisar order_id duplicados o vacios';
    END IF;
    IF EXISTS (
        SELECT customer_id FROM analytics.customers GROUP BY customer_id
        HAVING COUNT(*) > 1 OR NULLIF(BTRIM(customer_id), '') IS NULL
    ) THEN
        RAISE EXCEPTION 'analytics.customers: revisar customer_id duplicados o vacios';
    END IF;
    IF EXISTS (
        SELECT order_id, order_item_id FROM analytics.order_items
        GROUP BY order_id, order_item_id
        HAVING COUNT(*) > 1 OR NULLIF(BTRIM(order_id), '') IS NULL OR order_item_id IS NULL
    ) THEN
        RAISE EXCEPTION 'analytics.order_items: revisar clave compuesta duplicada o incompleta';
    END IF;
END $$;

-- Una fila por pedido, incluidos cancelados y pedidos sin articulos o resenas
-- No guardar una bandera de recurrencia: debe recalcularse segun el periodo DAX
CREATE OR REPLACE VIEW analytics.fact_orders AS
WITH items_por_pedido AS (
    SELECT order_id,
           COUNT(*) AS item_count,
           COUNT(*) FILTER (WHERE price >= 0) AS valid_price_item_count,
           COUNT(*) FILTER (WHERE price IS NULL OR price < 0) AS invalid_price_item_count,
           COUNT(*) FILTER (WHERE freight_value IS NULL OR freight_value < 0) AS invalid_freight_item_count,
           SUM(price) FILTER (WHERE price >= 0) AS merchandise_value_observed,
           SUM(freight_value) FILTER (WHERE freight_value >= 0) AS freight_value_observed
    FROM analytics.order_items
    GROUP BY order_id
), resenas_por_pedido AS (
    SELECT order_id,
           COUNT(*) AS review_count,
           COUNT(*) FILTER (WHERE review_score BETWEEN 1 AND 5) AS valid_review_count,
           COUNT(*) FILTER (WHERE review_score IS NULL OR review_score NOT BETWEEN 1 AND 5) AS invalid_review_count,
           AVG(review_score) FILTER (WHERE review_score BETWEEN 1 AND 5) AS review_score_avg
    FROM analytics.order_reviews
    GROUP BY order_id
), pedidos AS (
    SELECT o.order_id, o.customer_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           o.order_status,
           o.order_purchase_timestamp,
           o.order_purchase_timestamp::date AS order_purchase_date,
           o.order_approved_at,
           o.order_delivered_carrier_date,
           o.order_delivered_customer_date,
           o.order_estimated_delivery_date,
           COALESCE(o.order_status = 'delivered', FALSE) AS is_delivered,
           COALESCE(o.order_status = 'delivered', FALSE)
               AND o.order_delivered_customer_date IS NOT NULL
               AND o.order_estimated_delivery_date IS NOT NULL AS is_delivery_evaluable,
           CASE WHEN o.order_status = 'delivered'
                 AND o.order_delivered_customer_date IS NOT NULL
                 AND o.order_estimated_delivery_date IS NOT NULL
                THEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
                ELSE NULL END AS is_delivered_late,
           COALESCE(i.item_count, 0) AS item_count,
           COALESCE(i.valid_price_item_count, 0) AS valid_price_item_count,
           COALESCE(i.invalid_price_item_count, 0) AS invalid_price_item_count,
           COALESCE(i.invalid_freight_item_count, 0) AS invalid_freight_item_count,
           COALESCE(i.item_count, 0) > 0 AS has_items,
           COALESCE(i.item_count, 0) > 0 AND COALESCE(i.invalid_price_item_count, 0) = 0 AS has_complete_item_prices,
           i.merchandise_value_observed,
           i.freight_value_observed,
           CASE WHEN i.item_count > 0 AND i.invalid_price_item_count = 0
                THEN i.merchandise_value_observed ELSE NULL END AS merchandise_value_complete,
           COALESCE(r.review_count, 0) AS review_count,
           COALESCE(r.valid_review_count, 0) AS valid_review_count,
           COALESCE(r.invalid_review_count, 0) AS invalid_review_count,
           COALESCE(r.valid_review_count, 0) > 0 AS has_valid_review,
           r.review_score_avg,
           r.review_score_avg <= 2 AS is_low_review
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    LEFT JOIN items_por_pedido i ON i.order_id = o.order_id
    LEFT JOIN resenas_por_pedido r ON r.order_id = o.order_id
)
SELECT pedidos.*,
       CASE WHEN NOT is_delivered THEN 'No entregado'
            WHEN is_delivered_late THEN 'Tardio'
            WHEN is_delivered_late = FALSE THEN 'A tiempo'
            ELSE 'Sin clasificar' END AS delivery_status,
       CASE WHEN is_delivered_late THEN
                order_delivered_customer_date::date - order_estimated_delivery_date::date
            ELSE NULL END AS delay_days,
       CASE WHEN is_delivered AND order_purchase_timestamp IS NOT NULL
                 AND order_delivered_customer_date IS NOT NULL THEN
                EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400.0
            ELSE NULL END AS delivery_days
FROM pedidos;

-- Calendario continuo de anos completos, segun las fechas de compra disponibles
-- Tener fechas en el calendario no significa que el dataset cubra todos esos dias
CREATE OR REPLACE VIEW analytics.dim_date AS
WITH limites AS (
    SELECT DATE_TRUNC('year', MIN(order_purchase_timestamp)) AS desde,
           DATE_TRUNC('year', MAX(order_purchase_timestamp)) + INTERVAL '1 year - 1 day' AS hasta
    FROM analytics.orders
), dias AS (
    SELECT serie::date AS date
    FROM limites
    CROSS JOIN LATERAL GENERATE_SERIES(desde, hasta, INTERVAL '1 day') AS serie
)
SELECT date,
       EXTRACT(YEAR FROM date)::integer AS year,
       EXTRACT(QUARTER FROM date)::integer AS quarter,
       EXTRACT(MONTH FROM date)::integer AS month_number,
       (ARRAY['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
              'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'])
           [EXTRACT(MONTH FROM date)::integer] AS month_name,
       TO_CHAR(date, 'YYYY-MM') AS year_month,
       EXTRACT(YEAR FROM date)::integer * 100 + EXTRACT(MONTH FROM date)::integer AS year_month_number,
       DATE_TRUNC('month', date)::date AS month_start
FROM dias;

COMMIT;

-- 1. Deben coincidir filas y claves unicas con todos los pedidos de origen
SELECT (SELECT COUNT(*) FROM analytics.orders) AS pedidos_origen,
       COUNT(*) AS filas_fact_orders,
       COUNT(DISTINCT order_id) AS claves_unicas,
       COUNT(*) FILTER (WHERE order_id IS NULL) AS claves_nulas,
       COUNT(*) FILTER (WHERE NOT has_items) AS pedidos_sin_articulos,
       COUNT(*) FILTER (WHERE NOT has_valid_review) AS pedidos_sin_puntuacion_valida
FROM analytics.fact_orders;

-- 2. El calendario debe ser unico, continuo y cubrir todas las compras no nulas.
SELECT MIN(date) AS primera_fecha, MAX(date) AS ultima_fecha,
       COUNT(*) AS dias_calendario, COUNT(DISTINCT date) AS fechas_unicas,
       MAX(date) - MIN(date) + 1 AS dias_esperados,
       (SELECT COUNT(*) FROM analytics.fact_orders o
        WHERE o.order_purchase_date IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM analytics.dim_date d WHERE d.date = o.order_purchase_date)) AS compras_fuera_calendario,
       (SELECT COUNT(*) FROM analytics.fact_orders WHERE order_purchase_date IS NULL) AS compras_sin_fecha
FROM analytics.dim_date;

-- 3. Relacion entre las dos tablas de hechos: no debe haber articulos huerfanos
-- ni claves de articulo duplicadas. Un pedido sin articulos SI es admisible
SELECT COUNT(*) FILTER (WHERE o.order_id IS NULL) AS articulos_sin_pedido,
       COUNT(*) - COUNT(DISTINCT (s.order_id, s.order_item_id)) AS claves_articulo_duplicadas,
       COUNT(*) FILTER (WHERE s.order_id IS NULL OR s.order_item_id IS NULL) AS claves_articulo_incompletas,
       COUNT(*) FILTER (WHERE s.is_delivered_late IS DISTINCT FROM o.is_delivered_late) AS articulos_tardanza_distinta
FROM analytics.fact_sales s
LEFT JOIN analytics.fact_orders o ON o.order_id = s.order_id;

-- 4. Detectar fact_sales desactualizada o multiplicada, pedido por pedido.
-- Todos estos conteos deben ser cero antes de importar el modelo a Power BI
WITH ventas AS (
    SELECT order_id, COUNT(*) AS item_count,
           SUM(price) FILTER (WHERE price >= 0) AS merchandise_value_observed,
           SUM(freight_value) FILTER (WHERE freight_value >= 0) AS freight_value_observed
    FROM analytics.fact_sales
    GROUP BY order_id
)
SELECT COUNT(*) FILTER (WHERE COALESCE(v.item_count, 0) IS DISTINCT FROM o.item_count) AS pedidos_cantidad_distinta,
       COUNT(*) FILTER (WHERE v.merchandise_value_observed IS DISTINCT FROM o.merchandise_value_observed) AS pedidos_mercancia_distinta,
       COUNT(*) FILTER (WHERE v.freight_value_observed IS DISTINCT FROM o.freight_value_observed) AS pedidos_flete_distinto
FROM analytics.fact_orders o
LEFT JOIN ventas v ON v.order_id = o.order_id;

-- 5. Referencia para medidas DAX: la misma ventana de 06 y del notebook.
-- Solo entregados. No sumar importes de fact_orders y fact_sales entre si
WITH entregados AS (
    SELECT * FROM analytics.fact_orders
    WHERE is_delivered
      AND order_purchase_date >= DATE '2016-09-04'
      AND order_purchase_date < DATE '2018-10-18'
), clientes AS (
    SELECT customer_unique_id, COUNT(*) AS pedidos
    FROM entregados WHERE customer_unique_id IS NOT NULL
    GROUP BY customer_unique_id
)
SELECT COUNT(*) AS pedidos_entregados,
       COUNT(DISTINCT customer_unique_id) AS clientes_compradores,
       SUM(item_count) AS articulos_vendidos,
       ROUND(SUM(merchandise_value_observed), 2) AS valor_mercancia_observado,
       ROUND(SUM(freight_value_observed), 2) AS importe_flete_observado,
       ROUND(AVG(merchandise_value_complete), 2) AS valor_medio_por_pedido,
       ROUND(SUM(merchandise_value_observed) / NULLIF(SUM(valid_price_item_count), 0), 2) AS precio_medio_articulo,
       COUNT(*) FILTER (WHERE is_delivery_evaluable) AS pedidos_evaluables,
       COUNT(*) FILTER (WHERE NOT is_delivery_evaluable) AS pedidos_sin_clasificacion,
       COUNT(*) FILTER (WHERE is_delivered_late) AS pedidos_tardios,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_delivered_late)
             / NULLIF(COUNT(*) FILTER (WHERE is_delivery_evaluable), 0), 2) AS porcentaje_tardios,
       ROUND(AVG(delay_days), 2) AS dias_promedio_retraso,
       (SELECT COUNT(*) FROM clientes WHERE pedidos > 1) AS clientes_recurrentes,
       ROUND(100.0 * (SELECT COUNT(*) FROM clientes WHERE pedidos > 1)
             / NULLIF((SELECT COUNT(*) FROM clientes), 0), 2) AS porcentaje_recurrencia
FROM entregados;

-- 6. Satisfaccion por pedido; los nulos se cuentan como falta de cobertura.
SELECT delivery_status, COUNT(*) AS pedidos_entregados,
       COUNT(review_score_avg) AS pedidos_con_puntuacion_valida,
       COUNT(*) FILTER (WHERE NOT has_valid_review) AS pedidos_sin_puntuacion_valida,
       ROUND(AVG(review_score_avg), 2) AS puntuacion_media_por_pedido,
       COUNT(*) FILTER (WHERE is_low_review) AS pedidos_calificacion_baja,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_low_review)
             / NULLIF(COUNT(review_score_avg), 0), 2) AS porcentaje_calificaciones_bajas
FROM analytics.fact_orders
WHERE is_delivered
  AND order_purchase_date >= DATE '2016-09-04'
  AND order_purchase_date < DATE '2018-10-18'
GROUP BY delivery_status
ORDER BY delivery_status;
