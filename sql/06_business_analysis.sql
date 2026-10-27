-- Analisis segun report/definicion_indicadores.md
-- Ejecutar despues de 05 y resolver claves duplicadas antes de publicar sumas
-- Solo SELECT: cada bloque WITH ... SELECT se puede ejecutar por separado
-- Cada bloque declara la misma ventana [desde, hasta): al cambiar el periodo,
-- mantener esos parametros iguales en todos los bloques que se comparen
-- Universo comercial: pedidos entregados. Pedidos se cuentan desde orders;
-- los importes usan fact_sales agregada antes del JOIN para no multiplicarlos
-- Importes observados: solo valores >= 0; nulos/negativos se reportan aparte
-- No se imputan precios ni fletes con cero. Con incidencias, el importe observado
-- es parcial y no debe publicarse como total definitivo. Cero sigue siendo valido
-- El valor medio por pedido usa solo pedidos con articulos y precios completos
-- Porcentajes en escala 0-100; NULL significa sin datos (denominador cero)
-- Las tasas de entrega y satisfaccion usan pedidos, nunca filas de articulos.

-- 01. Cobertura de compra: todos los estados; los nulos no entran en la ventana

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
), pedidos_con_articulos AS (
    SELECT DISTINCT order_id FROM analytics.order_items
)
SELECT COUNT(*) AS pedidos_fuente,
       COUNT(*) FILTER (WHERE o.order_purchase_timestamp IS NULL) AS compras_sin_fecha,
       COUNT(*) FILTER (WHERE o.order_purchase_timestamp >= p.desde
                          AND o.order_purchase_timestamp < p.hasta) AS pedidos_en_ventana,
       COUNT(*) FILTER (WHERE o.order_status = 'delivered'
                          AND o.order_purchase_timestamp >= p.desde
                          AND o.order_purchase_timestamp < p.hasta
                          AND i.order_id IS NULL) AS entregados_sin_articulos
FROM analytics.orders o
CROSS JOIN parametros p
LEFT JOIN pedidos_con_articulos i ON i.order_id = o.order_id;

-- 02. Resumen comercial: solo entregados; importes observados con cobertura

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
),
detalle AS (
    SELECT f.order_id,
           COUNT(*) AS articulos,
           COUNT(*) FILTER (WHERE f.price IS NULL OR f.price < 0) AS precios_invalidos,
           COUNT(*) FILTER (WHERE f.freight_value IS NULL OR f.freight_value < 0) AS fletes_invalidos,
           SUM(f.price) FILTER (WHERE f.price >= 0) AS valor_mercancia_observado,
           SUM(f.freight_value) FILTER (WHERE f.freight_value >= 0) AS flete_observado,
           COUNT(*) FILTER (WHERE f.price >= 0) AS articulos_precio_valido
    FROM analytics.fact_sales f
    JOIN pedidos p ON p.order_id = f.order_id
    GROUP BY f.order_id
),
ventas AS (
    SELECT p.*, COALESCE(d.articulos, 0) AS articulos,
           COALESCE(d.precios_invalidos, 0) AS precios_invalidos,
           COALESCE(d.fletes_invalidos, 0) AS fletes_invalidos,
           d.valor_mercancia_observado, d.flete_observado,
           COALESCE(d.articulos_precio_valido, 0) AS articulos_precio_valido,
           COALESCE(d.articulos, 0) > 0 AND d.precios_invalidos = 0 AS detalle_completo
    FROM pedidos p
    LEFT JOIN detalle d ON d.order_id = p.order_id
)
SELECT COUNT(*) AS pedidos_entregados,
       COUNT(DISTINCT customer_unique_id) AS clientes_compradores,
       COALESCE(SUM(articulos), 0) AS articulos_vendidos,
       COUNT(*) FILTER (WHERE articulos = 0) AS pedidos_sin_articulos,
       COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS pedidos_sin_id_cliente,
       COUNT(*) FILTER (WHERE detalle_completo) AS pedidos_detalle_completo,
       COALESCE(SUM(precios_invalidos), 0) AS articulos_precio_invalido,
       COALESCE(SUM(fletes_invalidos), 0) AS articulos_flete_invalido,
       ROUND(SUM(valor_mercancia_observado), 2) AS valor_mercancia_observado,
       ROUND(SUM(flete_observado), 2) AS importe_flete_observado,
       ROUND(AVG(valor_mercancia_observado) FILTER (WHERE detalle_completo), 2) AS valor_medio_por_pedido,
       ROUND(SUM(valor_mercancia_observado) / NULLIF(SUM(articulos_precio_valido), 0), 2) AS precio_medio_articulo
FROM ventas;

-- 03. Evolucion mensual y valor medio por pedido (consultas consolidadas)
-- Los meses extremos no implican cobertura completa. Meses sin compras
-- no aparecen: su ausencia no se interpreta automaticamente como ventas cero

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
),
detalle AS (
    SELECT f.order_id,
           COUNT(*) AS articulos,
           COUNT(*) FILTER (WHERE f.price IS NULL OR f.price < 0) AS precios_invalidos,
           COUNT(*) FILTER (WHERE f.freight_value IS NULL OR f.freight_value < 0) AS fletes_invalidos,
           SUM(f.price) FILTER (WHERE f.price >= 0) AS valor_mercancia_observado,
           SUM(f.freight_value) FILTER (WHERE f.freight_value >= 0) AS flete_observado,
           COUNT(*) FILTER (WHERE f.price >= 0) AS articulos_precio_valido
    FROM analytics.fact_sales f
    JOIN pedidos p ON p.order_id = f.order_id
    GROUP BY f.order_id
),
ventas AS (
    SELECT p.*, COALESCE(d.articulos, 0) AS articulos,
           COALESCE(d.precios_invalidos, 0) AS precios_invalidos,
           COALESCE(d.fletes_invalidos, 0) AS fletes_invalidos,
           d.valor_mercancia_observado, d.flete_observado,
           COALESCE(d.articulos_precio_valido, 0) AS articulos_precio_valido,
           COALESCE(d.articulos, 0) > 0 AND d.precios_invalidos = 0 AS detalle_completo
    FROM pedidos p
    LEFT JOIN detalle d ON d.order_id = p.order_id
)
SELECT mes,
       COUNT(*) AS pedidos_entregados,
       COUNT(DISTINCT customer_unique_id) AS clientes_compradores,
       COALESCE(SUM(articulos), 0) AS articulos_vendidos,
       COUNT(*) FILTER (WHERE articulos = 0) AS pedidos_sin_articulos,
       COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS pedidos_sin_id_cliente,
       COUNT(*) FILTER (WHERE detalle_completo) AS pedidos_detalle_completo,
       COALESCE(SUM(precios_invalidos), 0) AS articulos_precio_invalido,
       COALESCE(SUM(fletes_invalidos), 0) AS articulos_flete_invalido,
       ROUND(SUM(valor_mercancia_observado), 2) AS valor_mercancia_observado,
       ROUND(SUM(flete_observado), 2) AS importe_flete_observado,
       ROUND(AVG(valor_mercancia_observado) FILTER (WHERE detalle_completo), 2) AS valor_medio_por_pedido,
       ROUND(SUM(valor_mercancia_observado) / NULLIF(SUM(articulos_precio_valido), 0), 2) AS precio_medio_articulo
FROM ventas
GROUP BY mes
ORDER BY mes;

-- 04. Top 10 categorias y unknown, con participacion sobre TODAS las categorias
-- Consolida ranking y comparacion de precios; unknown se muestra aunque quede
-- fuera del top 10. El valor medio incluye solo articulos de esa categoria

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
),
pedidos_categoria AS (
    -- Una fila por pedido y categoria: no sumar estos conteos entre categorias
    SELECT p.order_id, p.is_delivered_late,
           COALESCE(NULLIF(BTRIM(f.product_category), ''), 'unknown') AS product_category,
           COUNT(*) AS articulos,
           COUNT(*) FILTER (WHERE f.price IS NULL OR f.price < 0) AS precios_invalidos,
           COUNT(*) FILTER (WHERE f.price >= 0) AS articulos_precio_valido,
           SUM(f.price) FILTER (WHERE f.price >= 0) AS valor_mercancia_observado
    FROM pedidos p
    JOIN analytics.fact_sales f ON f.order_id = p.order_id
    GROUP BY p.order_id, p.is_delivered_late,
             COALESCE(NULLIF(BTRIM(f.product_category), ''), 'unknown')
),
categorias AS (
    SELECT product_category, COUNT(*) AS pedidos_categoria,
           SUM(articulos) AS articulos_vendidos,
           SUM(precios_invalidos) AS articulos_precio_invalido,
           COUNT(*) FILTER (WHERE precios_invalidos = 0) AS pedidos_categoria_completos,
           SUM(valor_mercancia_observado) AS valor_mercancia_observado,
           SUM(articulos_precio_valido) AS articulos_precio_valido,
           AVG(valor_mercancia_observado) FILTER (WHERE precios_invalidos = 0) AS valor_medio_categoria_por_pedido
    FROM pedidos_categoria
    GROUP BY product_category
), ranking AS (
    SELECT *,
           ROW_NUMBER() OVER (ORDER BY valor_mercancia_observado DESC NULLS LAST, product_category) AS posicion,
           SUM(valor_mercancia_observado) OVER () AS total_mercancia_observado,
           SUM(articulos_precio_invalido) OVER () AS precios_invalidos_universo
    FROM categorias
)
SELECT posicion, product_category, pedidos_categoria, articulos_vendidos,
       articulos_precio_invalido, precios_invalidos_universo, pedidos_categoria_completos,
       ROUND(valor_mercancia_observado, 2) AS valor_mercancia_observado,
       ROUND(100.0 * valor_mercancia_observado / NULLIF(total_mercancia_observado, 0), 2) AS participacion_porcentaje,
       ROUND(valor_mercancia_observado / NULLIF(articulos_precio_valido, 0), 2) AS precio_medio_articulo,
       ROUND(valor_medio_categoria_por_pedido, 2) AS valor_medio_categoria_por_pedido
FROM ranking
WHERE posicion <= 10 OR product_category = 'unknown'
ORDER BY posicion;

-- 05. Ventas y valor medio por estado (consultas consolidadas).

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
),
detalle AS (
    SELECT f.order_id,
           COUNT(*) AS articulos,
           COUNT(*) FILTER (WHERE f.price IS NULL OR f.price < 0) AS precios_invalidos,
           COUNT(*) FILTER (WHERE f.freight_value IS NULL OR f.freight_value < 0) AS fletes_invalidos,
           SUM(f.price) FILTER (WHERE f.price >= 0) AS valor_mercancia_observado,
           SUM(f.freight_value) FILTER (WHERE f.freight_value >= 0) AS flete_observado,
           COUNT(*) FILTER (WHERE f.price >= 0) AS articulos_precio_valido
    FROM analytics.fact_sales f
    JOIN pedidos p ON p.order_id = f.order_id
    GROUP BY f.order_id
),
ventas AS (
    SELECT p.*, COALESCE(d.articulos, 0) AS articulos,
           COALESCE(d.precios_invalidos, 0) AS precios_invalidos,
           COALESCE(d.fletes_invalidos, 0) AS fletes_invalidos,
           d.valor_mercancia_observado, d.flete_observado,
           COALESCE(d.articulos_precio_valido, 0) AS articulos_precio_valido,
           COALESCE(d.articulos, 0) > 0 AND d.precios_invalidos = 0 AS detalle_completo
    FROM pedidos p
    LEFT JOIN detalle d ON d.order_id = p.order_id
)
SELECT customer_state,
       COUNT(*) AS pedidos_entregados,
       COUNT(DISTINCT customer_unique_id) AS clientes_compradores,
       COALESCE(SUM(articulos), 0) AS articulos_vendidos,
       COUNT(*) FILTER (WHERE articulos = 0) AS pedidos_sin_articulos,
       COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS pedidos_sin_id_cliente,
       COUNT(*) FILTER (WHERE detalle_completo) AS pedidos_detalle_completo,
       COALESCE(SUM(precios_invalidos), 0) AS articulos_precio_invalido,
       COALESCE(SUM(fletes_invalidos), 0) AS articulos_flete_invalido,
       ROUND(SUM(valor_mercancia_observado), 2) AS valor_mercancia_observado,
       ROUND(SUM(flete_observado), 2) AS importe_flete_observado,
       ROUND(AVG(valor_mercancia_observado) FILTER (WHERE detalle_completo), 2) AS valor_medio_por_pedido,
       ROUND(SUM(valor_mercancia_observado) / NULLIF(SUM(articulos_precio_valido), 0), 2) AS precio_medio_articulo
FROM ventas
GROUP BY customer_state
ORDER BY valor_mercancia_observado DESC NULLS LAST;

-- 06. Tardanza general y dias calendario de retraso; una fila por pedido

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
)
SELECT COUNT(*) AS pedidos_entregados,
       COUNT(is_delivered_late) AS pedidos_evaluables,
       COUNT(*) FILTER (WHERE is_delivered_late IS NULL) AS pedidos_sin_clasificacion,
       COUNT(*) FILTER (WHERE is_delivered_late) AS pedidos_tardios,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_delivered_late)
             / NULLIF(COUNT(is_delivered_late), 0), 2) AS porcentaje_tardios,
       ROUND(AVG(fecha_entrega - fecha_estimada) FILTER (WHERE is_delivered_late), 2) AS dias_promedio_retraso
FROM pedidos;

-- 07. Tardanza por mes de compra

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
)
SELECT mes,
       COUNT(*) AS pedidos_entregados,
       COUNT(is_delivered_late) AS pedidos_evaluables,
       COUNT(*) FILTER (WHERE is_delivered_late IS NULL) AS pedidos_sin_clasificacion,
       COUNT(*) FILTER (WHERE is_delivered_late) AS pedidos_tardios,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_delivered_late)
             / NULLIF(COUNT(is_delivered_late), 0), 2) AS porcentaje_tardios
FROM pedidos
GROUP BY mes
ORDER BY mes;

-- 08. Tardanza por estado: interpretar el porcentaje junto con su volumen

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
)
SELECT customer_state,
       COUNT(*) AS pedidos_entregados,
       COUNT(is_delivered_late) AS pedidos_evaluables,
       COUNT(*) FILTER (WHERE is_delivered_late IS NULL) AS pedidos_sin_clasificacion,
       COUNT(*) FILTER (WHERE is_delivered_late) AS pedidos_tardios,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_delivered_late)
             / NULLIF(COUNT(is_delivered_late), 0), 2) AS porcentaje_tardios
FROM pedidos
GROUP BY customer_state
ORDER BY porcentaje_tardios DESC NULLS LAST;

-- 09. Tardanza por categoria: minimo de 100 pedidos EVALUABLES
-- Un pedido puede participar en varias categorias

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
),
pedidos_categoria AS (
    -- Una fila por pedido y categoria: no sumar estos conteos entre categorias
    SELECT p.order_id, p.is_delivered_late,
           COALESCE(NULLIF(BTRIM(f.product_category), ''), 'unknown') AS product_category,
           COUNT(*) AS articulos,
           COUNT(*) FILTER (WHERE f.price IS NULL OR f.price < 0) AS precios_invalidos,
           COUNT(*) FILTER (WHERE f.price >= 0) AS articulos_precio_valido,
           SUM(f.price) FILTER (WHERE f.price >= 0) AS valor_mercancia_observado
    FROM pedidos p
    JOIN analytics.fact_sales f ON f.order_id = p.order_id
    GROUP BY p.order_id, p.is_delivered_late,
             COALESCE(NULLIF(BTRIM(f.product_category), ''), 'unknown')
)
SELECT product_category,
       COUNT(*) AS pedidos_categoria,
       COUNT(is_delivered_late) AS pedidos_evaluables,
       COUNT(*) FILTER (WHERE is_delivered_late IS NULL) AS pedidos_sin_clasificacion,
       COUNT(*) FILTER (WHERE is_delivered_late) AS pedidos_tardios,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_delivered_late)
             / NULLIF(COUNT(is_delivered_late), 0), 2) AS porcentaje_tardios
FROM pedidos_categoria
GROUP BY product_category
HAVING COUNT(is_delivered_late) >= 100
ORDER BY porcentaje_tardios DESC NULLS LAST;

-- 10. Satisfaccion segun puntualidad: asociacion, no causalidad.
-- LEFT JOIN mantiene visibles los pedidos sin puntuaciones validas

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
),
resenas AS (
    -- Una fila por pedido; las puntuaciones invalidas no entran en el promedio
    SELECT r.order_id,
           AVG(r.review_score) FILTER (WHERE r.review_score BETWEEN 1 AND 5) AS puntuacion_media,
           COUNT(*) FILTER (WHERE r.review_score IS NULL OR r.review_score NOT BETWEEN 1 AND 5) AS puntuaciones_invalidas
    FROM analytics.order_reviews r
    JOIN pedidos p ON p.order_id = r.order_id
    GROUP BY r.order_id
)
SELECT CASE WHEN p.is_delivered_late THEN 'Tardio'
            WHEN p.is_delivered_late = FALSE THEN 'A tiempo'
            ELSE 'Sin clasificar' END AS estado_entrega,
       COUNT(*) AS pedidos_entregados,
       COUNT(r.puntuacion_media) AS pedidos_con_puntuacion_valida,
       COUNT(*) FILTER (WHERE r.puntuacion_media IS NULL) AS pedidos_sin_puntuacion_valida,
       COALESCE(SUM(r.puntuaciones_invalidas), 0) AS puntuaciones_invalidas,
       ROUND(100.0 * COUNT(r.puntuacion_media) / NULLIF(COUNT(*), 0), 2) AS cobertura_resenas_porcentaje,
       ROUND(AVG(r.puntuacion_media), 2) AS puntuacion_media_por_pedido,
       COUNT(*) FILTER (WHERE r.puntuacion_media <= 2) AS pedidos_calificacion_baja,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.puntuacion_media <= 2)
             / NULLIF(COUNT(r.puntuacion_media), 0), 2) AS porcentaje_calificaciones_bajas
FROM pedidos p
LEFT JOIN resenas r ON r.order_id = p.order_id
GROUP BY p.is_delivered_late
ORDER BY puntuacion_media_por_pedido NULLS LAST;

-- 11. Recurrencia en la ventana seleccionada, sin filtros de categoria/vendedor

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
),
pedidos_por_cliente AS (
    SELECT customer_unique_id, COUNT(DISTINCT order_id) AS cantidad_pedidos
    FROM pedidos
    WHERE customer_unique_id IS NOT NULL
    GROUP BY customer_unique_id
)
SELECT COUNT(*) AS clientes_compradores,
       COUNT(*) FILTER (WHERE cantidad_pedidos > 1) AS clientes_recurrentes,
       ROUND(100.0 * COUNT(*) FILTER (WHERE cantidad_pedidos > 1)
             / NULLIF(COUNT(*), 0), 2) AS porcentaje_recurrencia,
       (SELECT COUNT(*) FROM pedidos WHERE customer_unique_id IS NULL) AS pedidos_sin_id_cliente
FROM pedidos_por_cliente;

-- 12. Pagos de pedidos entregados. Importe pagado no equivale a mercancía.
-- Los pedidos por metodo no se suman: un pedido puede usar varios metodos

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
)
SELECT pay.payment_type AS metodo_pago,
       COUNT(DISTINCT pay.order_id) AS pedidos_con_metodo,
       COUNT(*) AS registros_pago,
       COUNT(*) FILTER (WHERE pay.payment_value IS NULL OR pay.payment_value < 0) AS importes_invalidos,
       ROUND(SUM(pay.payment_value) FILTER (WHERE pay.payment_value >= 0), 2) AS importe_pagado_observado,
       ROUND(AVG(pay.payment_value) FILTER (WHERE pay.payment_value >= 0), 2) AS importe_medio_registro_valido,
       (SELECT COUNT(*) FROM pedidos p2 WHERE NOT EXISTS (
           SELECT 1 FROM analytics.order_payments x WHERE x.order_id = p2.order_id
       )) AS pedidos_sin_registros_pago
FROM analytics.order_payments pay
JOIN pedidos p ON p.order_id = pay.order_id
GROUP BY pay.payment_type
ORDER BY importe_pagado_observado DESC NULLS LAST;

-- 13. Exploracion secundaria: satisfaccion por metodo de pago
-- Un pedido con varios metodos aparece una vez en cada metodo; no son grupos
-- excluyentes. La comparacion no demuestra un efecto causal del metodo

WITH parametros AS (
    -- Fecha inicial incluida y fecha final excluida. Repetir el mismo cambio
    -- en las consultas que se comparen; por defecto se usa toda la ventana
    SELECT DATE '2016-09-04' AS desde, DATE '2018-10-18' AS hasta
),
pedidos AS (
    SELECT o.order_id,
           NULLIF(BTRIM(c.customer_unique_id), '') AS customer_unique_id,
           COALESCE(NULLIF(BTRIM(c.customer_state), ''), 'unknown') AS customer_state,
           DATE_TRUNC('month', o.order_purchase_timestamp)::date AS mes,
           o.order_delivered_customer_date::date AS fecha_entrega,
           o.order_estimated_delivery_date::date AS fecha_estimada,
           CASE
               WHEN o.order_delivered_customer_date IS NOT NULL
                AND o.order_estimated_delivery_date IS NOT NULL
               THEN o.order_delivered_customer_date::date
                    > o.order_estimated_delivery_date::date
               ELSE NULL
           END AS is_delivered_late
    FROM analytics.orders o
    LEFT JOIN analytics.customers c ON c.customer_id = o.customer_id
    CROSS JOIN parametros p
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= p.desde
      AND o.order_purchase_timestamp < p.hasta
),
resenas AS (
    -- Una fila por pedido; las puntuaciones invalidas no entran en el promedio
    SELECT r.order_id,
           AVG(r.review_score) FILTER (WHERE r.review_score BETWEEN 1 AND 5) AS puntuacion_media,
           COUNT(*) FILTER (WHERE r.review_score IS NULL OR r.review_score NOT BETWEEN 1 AND 5) AS puntuaciones_invalidas
    FROM analytics.order_reviews r
    JOIN pedidos p ON p.order_id = r.order_id
    GROUP BY r.order_id
),
pagos_por_pedido AS (
    SELECT DISTINCT pay.order_id, pay.payment_type
    FROM analytics.order_payments pay
    JOIN pedidos p ON p.order_id = pay.order_id
)
SELECT pay.payment_type AS metodo_pago,
       COUNT(*) AS pedidos_entregados,
       COUNT(r.puntuacion_media) AS pedidos_con_puntuacion_valida,
       COUNT(*) FILTER (WHERE r.puntuacion_media IS NULL) AS pedidos_sin_puntuacion_valida,
       COALESCE(SUM(r.puntuaciones_invalidas), 0) AS puntuaciones_invalidas,
       ROUND(100.0 * COUNT(r.puntuacion_media) / NULLIF(COUNT(*), 0), 2) AS cobertura_resenas_porcentaje,
       ROUND(AVG(r.puntuacion_media), 2) AS puntuacion_media_por_pedido,
       COUNT(*) FILTER (WHERE r.puntuacion_media <= 2) AS pedidos_calificacion_baja,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.puntuacion_media <= 2)
             / NULLIF(COUNT(r.puntuacion_media), 0), 2) AS porcentaje_calificaciones_bajas
FROM pagos_por_pedido pay
LEFT JOIN resenas r ON r.order_id = pay.order_id
GROUP BY pay.payment_type
ORDER BY porcentaje_calificaciones_bajas DESC NULLS LAST;
