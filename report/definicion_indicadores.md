# Definición de indicadores

Proyecto: **E-commerce Business Performance Analytics**.

Este documento establece las reglas comunes para PostgreSQL, Pandas y Power BI. El análisis estudia las operaciones registradas en el dataset de Olist, que incluye múltiples vendedores. Los importes de mercancía no representan ganancias ni ingresos propios de la plataforma.

Estado: definiciones implementadas en los archivos SQL `05`, `06` y `07` y en `notebooks/01_exploracion_olist.ipynb`. Los resultados de Pandas se contrastaron con referencias de PostgreSQL 16. Las páginas «Rendimiento comercial» y «Logística y clientes» ya se construyeron en Power BI. Las capturas permiten revisar los resultados visibles, pero no sustituyen la comprobación de las medidas DAX y sus interacciones con los filtros. Modificar los archivos del repositorio no actualiza las tablas, las medidas DAX ni los datos importados.

## 1. Alcance y período

- Fuente: los nueve CSV originales de `data/`.
- Ventana general: todas las compras observadas, del **4 de septiembre de 2016 al 17 de octubre de 2018**, inclusive. Estos límites se verificaron en `olist_orders_dataset.csv`.
- Fecha de referencia para filtros y evolución mensual: `order_purchase_timestamp`. Las ventas se atribuyen al mes de compra de pedidos cuyo estado registrado es `delivered`, no al mes de entrega ni al mes del pago.
- Conservar las fechas tal como aparecen en la fuente, sin inventar una zona horaria ni aplicar conversiones de zona horaria.
- No asumir cobertura completa: septiembre de 2016 contiene 4 pedidos; septiembre y octubre de 2018 contienen 16 y 4, respectivamente, considerando todos los estados. Un descenso en esos extremos no prueba una caída del negocio.
- En la exploración se mostrará la ventana completa. No se publicarán tasas de crecimiento de períodos de cobertura dudosa sin revisar primero su integridad. Cualquier cambio del universo de análisis deberá quedar documentado y aplicarse por igual a SQL, Python y Power BI al comparar resultados. Los filtros exclusivos de una visualización, como el mínimo de pedidos evaluables del gráfico mensual de puntualidad, se documentan por separado y no cambian el universo de las tarjetas ni de la exploración completa.
- Los estados corresponden a la fotografía del dataset. No permiten reconstruir con certeza el estado que tenía cada pedido en una fecha histórica.

## 2. Unidades de análisis

| Unidad | Identificador | Uso |
| --- | --- | --- |
| Artículo de pedido | `order_id` + `order_item_id` | Valor de mercancía, flete y categorías. |
| Pedido | `order_id` | Cantidad de pedidos, entregas y satisfacción. |
| Cliente | `customer_unique_id` | Clientes distintos y recurrencia. |

`customer_id` vincula pedidos con los registros de clientes; no se utiliza como identificador de persona para calcular recurrencia.

`analytics.fact_sales` tiene una fila por artículo. Contar sus filas no equivale a contar pedidos. En las consultas SQL, las métricas generales parten de `analytics.orders` y las monetarias de sus artículos asociados. Para Power BI, `07` crea `analytics.fact_orders`, con una fila por pedido y con artículos y reseñas agregados por separado antes de unirlos. Esta vista conserva todos los estados; las medidas aplican el universo correspondiente a cada indicador. Los pedidos sin artículos se reportan como una diferencia de cobertura, sin asignarles un valor de venta cero.

El modelo de Power BI relaciona `dim_date[date]` con `fact_orders[order_purchase_date]`, y `fact_orders[order_id]` con `fact_sales[order_id]`, con filtros en una sola dirección: calendario -> pedidos -> artículos. Las métricas por pedido utilizan `fact_orders`; el análisis por artículo y categoría utiliza `fact_sales`. No se suman los importes de ambas tablas entre sí. Los detalles de configuración están en [`powerbi/README.md`](../powerbi/README.md).

Antes de combinar pagos, artículos y reseñas, agregar cada tabla al nivel necesario. No unir directamente sus filas de detalle para sumar importes.

## 3. Indicadores comerciales

Universo principal: pedidos con `order_status = 'delivered'` dentro de la ventana de compra seleccionada. Los análisis de cancelaciones y otros estados se presentan aparte y se identifican expresamente.

| Indicador | Regla de cálculo | Unidad |
| --- | --- | --- |
| Valor de mercancía vendida (ventas) | Suma de `price` de los artículos de pedidos entregados. Excluye flete. | BRL (R$) |
| Pedidos entregados | Cantidad distinta de `order_id` entregados. | Pedidos |
| Artículos vendidos | Cantidad de filas de artículos de pedidos entregados, con su clave validada como única. | Artículos |
| Clientes compradores | Cantidad distinta de `customer_unique_id` no nulos con pedidos entregados. | Clientes |
| Valor medio por pedido | Valor de mercancía / cantidad de pedidos entregados con detalle monetario completo. Numerador y denominador usan los mismos pedidos. | BRL por pedido |
| Precio medio por artículo | Suma de precios válidos / cantidad de artículos con precio válido. | BRL por artículo |
| Importe de flete | Suma de `freight_value` de artículos de pedidos entregados. No se interpreta como costo operativo de Olist. | BRL |
| Participación de una categoría | Valor de mercancía de la categoría / valor total de mercancía del mismo período y universo comercial. | Porcentaje |

Para el valor medio por pedido, un pedido tiene detalle monetario completo si tiene al menos un artículo y ninguno de sus artículos tiene precio faltante o inválido. Si hay importes faltantes, el total observado se identifica como incompleto y se informa la cantidad afectada; no se presenta como total definitivo.

Para categorías, usar la traducción no vacía cuando exista, luego la categoría original no vacía y finalmente `unknown`. Mantener `unknown` en los totales y mostrar su volumen. El denominador de participación incluye todas las categorías del universo elegido, no solo el top 10 mostrado.

Un pedido con varias categorías puede contarse en más de una. El valor medio por pedido de una categoría incluye únicamente la mercancía de esa categoría; no representa el carrito completo. No sumar pedidos de distintas categorías para obtener el total global.

## 4. Puntualidad y retraso

Universo: pedidos entregados, una fila por `order_id`.

Un pedido es **evaluable** cuando tiene fecha real y fecha estimada de entrega. La promesa se interpreta a nivel de día: entregar en cualquier hora del día estimado se considera puntual. Esta es una decisión metodológica del proyecto.

```sql
CASE
    WHEN order_status = 'delivered'
     AND order_delivered_customer_date IS NOT NULL
     AND order_estimated_delivery_date IS NOT NULL
    THEN order_delivered_customer_date::date
         > order_estimated_delivery_date::date
    ELSE NULL
END
```

| Indicador | Regla |
| --- | --- |
| Pedidos tardíos | Pedidos evaluables cuya fecha real es posterior al día estimado. |
| Porcentaje de entregas tardías | `100 × pedidos tardíos / pedidos evaluables`. |
| Pedidos sin clasificación | Pedidos entregados a los que falta alguna de las dos fechas. Mostrar aparte. |
| Días de retraso | Fecha real menos fecha estimada, ambas como `date`, únicamente para pedidos tardíos. |
| Retraso medio | Promedio de los días de retraso entre pedidos tardíos. |

Ejemplo: promesa para el 10 de mayo y entrega el 10 de mayo a las 18:00 implica entrega puntual. Una entrega el 11 de mayo implica un día de retraso.

Aplicar el mismo denominador en las tasas por mes, estado y categoría. Por categoría se usa una fila por combinación pedido-categoría. Cuando se muestre un ranking con mínimo de 100 casos, el umbral se aplica a **pedidos evaluables** y se explicita en el gráfico. Siempre mostrar el tamaño del grupo.

En Power BI, el gráfico «Entregas tardías por mes de compra» muestra únicamente meses con **al menos 100 pedidos evaluables**, calculados dentro de los filtros seleccionados. Es un filtro de esa visualización: los meses con menos casos permanecen en los datos y en los indicadores generales. Las tarjetas conservan todo el período y los estados seleccionados, usando el denominador propio de cada indicador. El mínimo mensual debe indicarse en el subtítulo o en la información de ayuda del gráfico. Para contrastar esa serie con SQL o Pandas, aplicar el mismo umbral a los agregados mensuales.

## 5. Calificaciones y relación con los retrasos

- Puntuación válida: `review_score` entre 1 y 5, inclusive.
- Calificación de un pedido: promedio de sus puntuaciones válidas. No seleccionar arbitrariamente una reseña cuando haya varias.
- Calificación media de un grupo: promedio de las calificaciones por pedido. Cada pedido tiene el mismo peso, independientemente de sus artículos o reseñas.
- Pedido con calificación baja: calificación media por pedido menor o igual a 2. No equivale a tener al menos una reseña de 1 o 2.
- Porcentaje de calificaciones bajas: `100 × pedidos con calificación baja / pedidos con al menos una puntuación válida`, dentro del grupo analizado.
- Comparar pedidos entregados puntuales y tardíos. Mostrar por separado los que no tienen clasificación de entrega; no asignarlos al grupo puntual.
- Excluir del cálculo de satisfacción los pedidos sin puntuación válida y mostrar su cantidad o cobertura. No convertir una reseña ausente en cero.

El resultado describe una asociación entre puntualidad y satisfacción. No demuestra que los retrasos sean la única causa de una calificación baja.

## 6. Recurrencia

Universo: clientes con identificador válido y al menos un pedido entregado en la ventana de compra seleccionada.

| Indicador | Regla |
| --- | --- |
| Cliente recurrente | `customer_unique_id` con más de un `order_id` entregado distinto dentro de la ventana seleccionada. |
| Clientes recurrentes | Cantidad de clientes que cumplen la regla anterior. |
| Porcentaje de recurrencia | `100 × clientes recurrentes / clientes compradores`. |

Esta métrica mide repetición observada, no retención por cohortes ni toda la historia de compra del cliente. Un cliente con una sola compra observada podría haber comprado fuera del período disponible.

Al filtrar un año, la métrica se recalcula dentro de ese año: no cuenta como recurrente a quien compró una vez en cada uno de dos años distintos. Para evitar ambigüedad, el indicador principal de recurrencia responde a filtros de fecha y de estado del cliente, pero no a filtros de categoría o vendedor. Tanto el conteo de pedidos por cliente como el denominador de clientes compradores se calculan dentro de la misma selección. Si una persona tiene pedidos asociados a distintos estados, al seleccionar uno solo se consideran únicamente sus pedidos en ese estado. Si se desarrolla una variante por categoría o vendedor, debe nombrarse y documentarse por separado.

## 7. Datos faltantes, anomalías y presentación

| Situación | Tratamiento |
| --- | --- |
| Denominador cero | Devolver `NULL` / vacío y mostrar «Sin datos», no 0 %. |
| Fecha de compra faltante | Excluir de análisis temporales y contabilizar como incidencia. |
| Fecha de entrega faltante | Mantener el pedido; excluir solo de las métricas que requieren esa fecha. |
| Precio o flete nulo | No reemplazar por cero. Informar cobertura y revisar el origen. |
| Importe negativo | Marcar para revisión; no convertir a positivo ni interpretar como devolución sin evidencia. |
| Precio o flete igual a cero | Conservar y revisar; cero no es un nulo. |
| Identificador de cliente faltante | Excluir de compradores únicos y recurrencia; conservar el pedido para métricas compatibles. |
| Clave de pedido o artículo duplicada | Investigar antes de publicar sumas; no eliminar registros automáticamente. |
| Comentario de reseña vacío | Conservar. La puntuación puede ser válida sin comentario. |
| Puntuación fuera de 1–5 | Excluir de satisfacción y reportar como incidencia. |

Conservar los archivos originales. Documentar toda exclusión o corrección y su cantidad de registros afectados. Las exclusiones se limitan a los indicadores afectados, no se aplican indiscriminadamente a todas las tablas.

Mantener precisión durante los cálculos y redondear al presentar: importes a dos decimales, porcentajes a dos decimales y conteos como enteros. En Power BI, una medida con formato porcentaje devuelve la fracción entre 0 y 1; si SQL devuelve el porcentaje entre 0 y 100, normalizar la escala al comparar resultados.

En `06`, los importes «observados» suman únicamente valores no negativos disponibles, y muestran las incidencias por separado. Si hay valores faltantes o negativos, esos importes son parciales y no se presentan como totales definitivos. Los ceros sí participan. El valor medio por pedido excluye del numerador y denominador los pedidos sin artículos o con algún precio inválido.

Los análisis complementarios de pagos deben indicar su universo. Un pedido puede tener varios métodos: los conteos por método no son aditivos. El importe pagado no sustituye automáticamente al valor de mercancía.
