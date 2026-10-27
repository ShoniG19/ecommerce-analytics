# Datos del proyecto

Este directorio contiene el dataset público de **Olist Brazilian E-Commerce**, un conjunto de datos transaccionales de una plataforma de comercio electrónico de Brasil. Las tablas permiten analizar clientes, pedidos, productos, vendedores, pagos, reseñas, logística y geolocalización.

Los archivos están en formato CSV, utilizan coma como separador y tienen una fila de encabezados. Los identificadores de pedidos, clientes, productos, vendedores y reseñas son cadenas hexadecimales; los números secuenciales de artículos y pagos son enteros. Las fechas no vacías se almacenan como texto con el formato `YYYY-MM-DD HH:MM:SS`, algunas con hora `00:00:00`. Los importes monetarios se expresan en reales brasileños (BRL).

## Archivos disponibles

| Archivo | Filas* | Descripción |
| --- | ---: | --- |
| `olist_customers_dataset.csv` | 99.441 | Identificadores del cliente y ubicación asociada al pedido. |
| `olist_geolocation_dataset.csv` | 1.000.163 | Coordenadas geográficas por prefijo de código postal. |
| `olist_order_items_dataset.csv` | 112.650 | Productos incluidos en cada pedido, vendedor, precio y flete. |
| `olist_order_payments_dataset.csv` | 103.886 | Métodos, cuotas y valores de pago de los pedidos. |
| `olist_order_reviews_dataset.csv` | 99.224 | Puntuaciones y comentarios de los clientes. |
| `olist_orders_dataset.csv` | 99.441 | Estado y principales fechas del ciclo de vida de cada pedido. |
| `olist_products_dataset.csv` | 32.951 | Categoría, dimensiones, peso, fotos y longitudes del producto. |
| `olist_sellers_dataset.csv` | 3.095 | Identificador, ubicación y estado del vendedor. |
| `product_category_name_translation.csv` | 71 | Traducción de categorías del portugués al inglés. |

\* Cantidad de registros observada en los archivos, sin contar el encabezado. En `olist_order_reviews_dataset.csv` algunos comentarios contienen saltos de línea dentro de campos entrecomillados; por eso el número de registros no coincide con el número de líneas físicas del archivo.

## Diccionario de datos

### `olist_customers_dataset.csv`

| Columna | Descripción |
| --- | --- |
| `customer_id` | Identificador del cliente asociado a un pedido concreto; una misma persona recibe distintos valores en diferentes pedidos. |
| `customer_unique_id` | Identificador único del cliente; un cliente puede tener varios `customer_id`. |
| `customer_zip_code_prefix` | Prefijo del código postal del cliente. |
| `customer_city` | Ciudad del cliente. |
| `customer_state` | Estado brasileño del cliente. |

### `olist_orders_dataset.csv`

| Columna | Descripción |
| --- | --- |
| `order_id` | Identificador único del pedido. |
| `customer_id` | Relación con `olist_customers_dataset.csv`. |
| `order_status` | Estado del pedido, por ejemplo `delivered`, `shipped`, `canceled` o `unavailable`. |
| `order_purchase_timestamp` | Fecha y hora de compra. |
| `order_approved_at` | Fecha y hora de aprobación del pago. |
| `order_delivered_carrier_date` | Fecha y hora de entrega al transportista. |
| `order_delivered_customer_date` | Fecha y hora de entrega al cliente. |
| `order_estimated_delivery_date` | Fecha estimada de entrega. |

### `olist_order_items_dataset.csv`

| Columna | Descripción |
| --- | --- |
| `order_id` | Relación con `olist_orders_dataset.csv`. |
| `order_item_id` | Número secuencial del artículo dentro del pedido. |
| `product_id` | Relación con `olist_products_dataset.csv`. |
| `seller_id` | Relación con `olist_sellers_dataset.csv`. |
| `shipping_limit_date` | Límite previsto para el envío del artículo. |
| `price` | Precio del artículo. |
| `freight_value` | Valor del flete del artículo. |

### `olist_order_payments_dataset.csv`

| Columna | Descripción |
| --- | --- |
| `order_id` | Relación con `olist_orders_dataset.csv`. |
| `payment_sequential` | Secuencia del pago dentro del pedido. |
| `payment_type` | Medio de pago, por ejemplo `credit_card`, `boleto`, `voucher` o `debit_card`. |
| `payment_installments` | Cantidad de cuotas. |
| `payment_value` | Valor del pago. |

### `olist_order_reviews_dataset.csv`

| Columna | Descripción |
| --- | --- |
| `review_id` | Identificador de la reseña. |
| `order_id` | Relación con `olist_orders_dataset.csv`. |
| `review_score` | Puntuación de 1 a 5. |
| `review_comment_title` | Título opcional del comentario. |
| `review_comment_message` | Mensaje opcional del comentario. |
| `review_creation_date` | Fecha de envío de la encuesta de satisfacción al cliente. |
| `review_answer_timestamp` | Fecha y hora en que el cliente respondió la encuesta de satisfacción. |

### `olist_products_dataset.csv`

| Columna | Descripción |
| --- | --- |
| `product_id` | Identificador único del producto. |
| `product_category_name` | Categoría del producto en portugués. |
| `product_name_lenght` | Longitud del nombre del producto. El nombre de la columna conserva el error ortográfico del archivo original. |
| `product_description_lenght` | Longitud de la descripción. El nombre de la columna conserva el error ortográfico del archivo original. |
| `product_photos_qty` | Cantidad de fotografías. |
| `product_weight_g` | Peso en gramos. |
| `product_length_cm` | Longitud en centímetros. |
| `product_height_cm` | Altura en centímetros. |
| `product_width_cm` | Ancho en centímetros. |

### `olist_sellers_dataset.csv`

| Columna | Descripción |
| --- | --- |
| `seller_id` | Identificador único del vendedor. |
| `seller_zip_code_prefix` | Prefijo del código postal del vendedor. |
| `seller_city` | Ciudad del vendedor. |
| `seller_state` | Estado brasileño del vendedor. |

### `olist_geolocation_dataset.csv`

| Columna | Descripción |
| --- | --- |
| `geolocation_zip_code_prefix` | Prefijo del código postal. |
| `geolocation_lat` | Latitud. |
| `geolocation_lng` | Longitud. |
| `geolocation_city` | Ciudad asociada al prefijo. |
| `geolocation_state` | Estado brasileño asociado al prefijo. |

Esta tabla puede contener varias coordenadas para un mismo prefijo postal. No debe tratarse automáticamente como una tabla con una fila única por código postal; para obtener una coordenada representativa es necesario definir una regla de agregación.

### `product_category_name_translation.csv`

| Columna | Descripción |
| --- | --- |
| `product_category_name` | Nombre de la categoría en portugués; relación con la columna homónima de productos. |
| `product_category_name_english` | Traducción de la categoría al inglés. |

## Relaciones principales

```text
customers (1) ──── (1) orders   [por customer_id en estos archivos]
orders    (1) ──── (N) order_items ──── (N:1) products
orders    (1) ──── (N) order_items ──── (N:1) sellers
orders    (1) ──── (N) order_payments
orders    (1) ──── (N) order_reviews
products  (N) ──── (1) product_category_name_translation
```

La relación 1:1 entre `customers` y `orders` describe los datos observados en estos archivos. Una persona puede realizar varios pedidos; se identifica mediante `customer_unique_id`. El esquema muestra las relaciones principales, pero no garantiza que todos los pedidos tengan artículos, pagos o reseñas, ni que todas las categorías tengan traducción.

Las tablas de artículos y pagos son de detalle: un pedido puede tener varios artículos, vendedores o registros de pago. Por eso, al combinar varias tablas de detalle directamente con `orders`, se pueden multiplicar filas y sobrestimar métricas. Para análisis a nivel de pedido, conviene agregar cada tabla de detalle al nivel de `order_id` antes de combinarlas. Para analizar artículos o categorías, se conserva el detalle necesario y se controla que las uniones no multipliquen sus filas.

## Recomendaciones de uso

- Conservar los CSV originales sin modificaciones y trabajar sobre copias o datos derivados.
- Convertir las columnas de fecha a un tipo de fecha y hora antes de analizarlas, comprobando valores vacíos o no válidos.
- Representar los importes en reales brasileños mediante decimales exactos o centavos enteros para evitar errores de precisión en los cálculos.
- Mantener los identificadores hexadecimales y los prefijos postales como texto. Estos últimos pueden contener ceros iniciales.
- Tratar los comentarios y varias dimensiones de producto como valores potencialmente nulos. Un dato ausente no equivale automáticamente a cero.
- Usar `customer_unique_id` para identificar personas y estudiar recurrencia; usar `customer_id` para relacionar pedidos con el registro de cliente asociado.
- Usar la tabla de traducción para mostrar categorías en inglés, considerando que puede haber categorías sin traducción o productos sin categoría.
- Considerar que las fechas de entrega pueden faltar porque el pedido no llegó a esa etapa o por datos incompletos. En estos archivos hay 8 pedidos con estado `delivered` sin fecha de entrega al cliente; su puntualidad no puede determinarse con las fechas disponibles.

## Origen

Dataset: [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).
