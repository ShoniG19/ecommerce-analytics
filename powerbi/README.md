# Modelo de datos para Power BI

El modelo usa tres objetos de `olist_analytics`. El script
[`07_create_and_validate_powerbi_model.sql`](../sql/07_create_and_validate_powerbi_model.sql)
crea dos vistas: `analytics.fact_orders` y `analytics.dim_date`. Se puede ejecutar
completo de nuevo: no requiere borrar ni recrear las tablas de origen.

Las vistas consultan las tablas preparadas por `04`. `fact_sales` sigue siendo
la tabla creada por `05`; no se actualiza automáticamente al cambiar las tablas
de analytics. Las comprobaciones de `07` detectan diferencias de conteos e
importes entre ambas capas. Si un control de consistencia devuelve incidencias,
investigar antes de cargar Power BI. Estos controles muestran resultados; no
reparan automáticamente los datos.

## 1. Ejecutar y comprobar en PostgreSQL

1. Conectar a `olist_analytics` y ejecutar completo `07`.
2. Confirmar que `fact_orders` tiene una fila por pedido, con clave no nula.
3. Confirmar que el calendario no tiene fechas repetidas ni días faltantes.
4. Los controles de artículos sin pedido, claves duplicadas/incompletas,
   discrepancias de tardanza e importes deben devolver cero.
5. Comparar los indicadores finales con las referencias de `06` y Pandas.

`fact_orders` conserva **todos los estados**, pedidos sin artículos y pedidos
sin reseñas. Un pedido sin artículos tiene `item_count = 0`, pero su importe
permanece NULL. Los promedios de reseñas consideran únicamente puntuaciones de
1 a 5. No se guarda una bandera fija de cliente recurrente: se calculará en DAX
según el período elegido.

Si una instrucción falla dentro de la transacción, ejecutar `ROLLBACK` antes
de reintentar. El bloque inicial detiene la creación si detecta claves inválidas
en orders, customers u order_items.

## 2. Importar las tres tablas

En Power BI Desktop, usar el conector **Base de datos PostgreSQL**, indicar
servidor y base `olist_analytics`, y elegir **Importar**. Para una instalación
local con el puerto habitual, el servidor suele ser `localhost:5432`; usar los
datos reales de tu instalación. Seleccionar estos objetos y renombrar sus
consultas como se indica. El conector admite el modo Importar.

| Objeto de PostgreSQL | Nombre en Power BI | Una fila representa |
| --- | --- | --- |
| `analytics.dim_date` | `dim_date` | Un día. |
| `analytics.fact_orders` | `fact_orders` | Un pedido. |
| `analytics.fact_sales` | `fact_sales` | Un artículo de pedido. |

Comprobar los tipos en Power Query: identificadores como texto, `date` y
`order_purchase_date` como fecha, banderas como verdadero/falso, conteos como
números enteros. Los importes pueden usar decimal fijo; `review_score_avg` y
`delivery_days` deben conservar precisión decimal, redondeando solo al presentar.
No sustituir nulos de importes, puntuaciones o tardanza por cero/falso.

No combinar estas consultas mediante Merge en una única tabla plana: repetiría
los importes y las calificaciones de pedidos con varios artículos. Tampoco es
necesario importar las reseñas originales para las cinco preguntas actuales.

## 3. Relaciones

Crear exactamente estas dos relaciones activas y revisar cualquier relación
detectada automáticamente. El filtro debe viajar del lado 1 al lado muchos.

| Lado 1 | Lado muchos | Dirección |
| --- | --- | --- |
| `dim_date[date]` | `fact_orders[order_purchase_date]` | Única: calendario → pedidos. |
| `fact_orders[order_id]` | `fact_sales[order_id]` | Única: pedidos → artículos. |

```mermaid
flowchart LR
    D["dim_date · un día"] -->|"1 a muchos · fecha de compra"| O["fact_orders · un pedido"]
    O -->|"1 a muchos · order_id"| S["fact_sales · un artículo"]
```

Este es un modelo simplificado de cabecera y detalle: `fact_orders` contiene
métricas del pedido y transmite filtros a los artículos. No conectar además
el calendario directamente a `fact_sales`, ni activar filtros bidireccionales.

Usar `dim_date[date]` como columna de la tabla de fechas para el modelo clásico
de inteligencia temporal. La vista contiene años completos y días continuos.
Ordenar `month_name` por `month_number`, y `year_month` por `year_month_number`.
Usar `year_month` en la evolución mensual para no mezclar meses de diferentes años.

El calendario cubre años completos por razones de modelado; eso no significa
que existan compras durante todos sus días. Para validar el proyecto, filtrar
desde 04/09/2016 hasta 17/10/2018, inclusive. No convertir automáticamente meses
sin observaciones en cero ventas ni comparar extremos como períodos completos.

## 4. Campos que usará cada análisis

| Análisis | Campos de referencia |
| --- | --- |
| Ventas y categorías | `fact_sales[price]`, `product_category`; excluir importes negativos/nulos y mostrar incidencias. |
| Pedidos generales | `fact_orders[order_id]`; no contar filas de artículos. |
| Valor medio por pedido | Promedio de `fact_orders[merchandise_value_complete]`: omite pedidos sin detalle monetario completo. |
| Puntualidad | `fact_orders[is_delivery_evaluable]`, `is_delivered_late`, `delivery_status`, `delay_days`. |
| Satisfacción | Promedio de `fact_orders[review_score_avg]`, una fila por pedido; `has_valid_review` informa cobertura. |
| Calificaciones bajas | `is_low_review`; dividir por pedidos con `has_valid_review = TRUE`. |
| Recurrencia | Agrupar por `customer_unique_id` y contar pedidos entregados dentro del período. Excluir identificadores vacíos. |
| Auditoría monetaria | `item_count`, `invalid_price_item_count`, `invalid_freight_item_count`, `has_complete_item_prices`. |

`merchandise_value_observed` y `freight_value_observed` son sumas disponibles por
pedido; pueden ser parciales si existen incidencias. `merchandise_value_complete`
es NULL si falta algún precio o hay precios negativos. Los ceros válidos se conservan.

Los importes por pedido y por artículo representan el mismo dinero a distinta
granularidad: nunca sumar ambas columnas para calcular ventas. La calificación
del pedido ya promedia sus reseñas válidas; no ponderarla por cantidad de reseñas.

Para las páginas comerciales, usar pedidos entregados. Al crear las medidas
DAX, incorporar `fact_orders[is_delivered] = TRUE` para que el criterio no
dependa únicamente de un filtro visual. Las tasas devuelven BLANK si no tienen
denominador. Los porcentajes DAX se expresan como fracción 0–1 y se formatean como
porcentaje; las referencias SQL usan escala 0–100.

### Comportamiento de filtros que hay que comprobar

- El calendario filtra pedidos y artículos.
- Un filtro de estado del cliente desde `fact_orders` filtra también las ventas.
- Una categoría de `fact_sales` filtra artículos, pero no regresa a `fact_orders`.
  Por eso los pedidos **por categoría** se cuentan con DISTINCTCOUNT sobre
  `fact_sales[order_id]`, no con un conteo de `fact_orders`.
- Para la primera versión, mantener el segmentador de categoría en la página
  comercial. Las tarjetas globales de logística y recurrencia no deben aparentar
  estar filtradas por categoría. La recurrencia principal no responde a categoría
  o vendedor, de acuerdo con las definiciones del proyecto.
- Un futuro análisis de logística por categoría requiere transferir el conjunto
  de pedidos con una medida explícita; no resolverlo cambiando toda la relación
  a bidireccional.

Ocultar en la vista de informe los identificadores técnicos y las fechas,
estados y atributos del cliente duplicados en `fact_sales`. Conservar sus
columnas en el modelo si son útiles para validación. Usar las fechas de
`dim_date` y los atributos del pedido de `fact_orders` en los segmentadores.

## 5. Criterios para pasar al diseño visual

| Comprobación, ventana completa y entregados | Referencia |
| --- | ---: |
| Pedidos entregados | 96.478 |
| Artículos vendidos | 110.197 |
| Valor de mercancía | R$ 13.221.498,11 |
| Valor medio por pedido | R$ 137,04 |
| Pedidos evaluables | 96.470 |
| Pedidos tardíos | 6.534 |
| Tardanza | 6,77 % |
| Clientes recurrentes | 2.801 |
| Recurrencia | 3,00 % |

Validar primero una tabla de medidas y los filtros de fecha, estado y categoría.
Después crear las páginas «Rendimiento comercial» y «Logística y clientes».
La próxima tarea es escribir y comprobar las medidas DAX; este documento y el
script SQL preparan el modelo, pero no modifican automáticamente el `.pbix`.
