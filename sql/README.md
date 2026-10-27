# Ejecución de los scripts SQL

## Requisitos previos

La base de datos PostgreSQL `olist_analytics` debe existir y la conexión debe apuntar a ella. Los scripts no crean la base de datos.

Para una primera ejecución:

1. Ejecutar `01_create_schemas.sql` para crear los esquemas `staging` y `analytics`.
2. Crear y cargar las nueve tablas raw en `staging` a partir de los CSV originales. La creación de estas tablas y la importación se realizan por separado; no están incluidas en los scripts del repositorio.
3. Con las nueve tablas cargadas, continuar con `02` y `03`, revisar sus resultados y resolver las incidencias antes de crear analytics con `04`. Los scripts `05`–`07` requieren las tablas de analytics creadas en los pasos anteriores.

Las tablas esperadas en `staging` son:

```text
customers_raw
geolocation_raw
order_items_raw
order_payments_raw
order_reviews_raw
orders_raw
products_raw
sellers_raw
category_translation_raw
```

Comprobar también los tipos elegidos durante la importación: `02` utiliza comparaciones numéricas para los importes y funciones de texto para la fecha de compra. `04` espera texto en las fechas que convierte con `BTRIM` y `NULLIF`. La primera consulta de `02` permite inspeccionar los tipos cargados.

## Orden de ejecución

Ejecutar sobre `olist_analytics` en este orden, completando la carga de staging entre `01` y `02`:

| Script | Propósito |
| --- | --- |
| `01_create_schemas.sql` | Crear los esquemas `staging` y `analytics`. |
| `02_validate_raw_data.sql` | Inspeccionar tipos, conteos, estados, fechas de compra e importes de las tablas raw. |
| `03_validate_relationships.sql` | Detectar pedidos, artículos, pagos y reseñas sin su registro relacionado en staging. |
| `04_create_and_validate_analytics.sql` | Crear las nueve tablas de analytics, convertir fechas e importes y comprobar cada tabla. |
| `05_create_and_validate_fact_sales.sql` | Crear la tabla de hechos por artículo y comprobar conteos, claves, importes y categorías. |
| `06_business_analysis.sql` | Consultar indicadores de ventas, entregas, reseñas, recurrencia y pagos. |
| `07_create_and_validate_powerbi_model.sql` | Crear las vistas de pedidos y calendario para Power BI; validar claves, cobertura e indicadores. |

`07` se puede ejecutar completo varias veces porque utiliza `CREATE OR REPLACE VIEW`. Requiere las tablas de `04` y `fact_sales` actualizada según `05`. No hace falta repetir `01`–`06` si esos pasos ya se completaron. Las vistas contienen todos los pedidos; los filtros comerciales se aplican al consultar o en las medidas DAX. El modelo y sus relaciones están documentados en [`powerbi/README.md`](../powerbi/README.md).

## Tipos de datos y nivel de detalle

`04` convierte las fechas a `timestamp`, tratando las cadenas vacías como nulos, y los importes `price`, `freight_value` y `payment_value` a `NUMERIC(12,2)`. Las columnas sin conversión explícita, incluidos los prefijos postales, conservan el tipo de staging. Este script no recupera ceros iniciales perdidos durante la importación. Para futuras cargas, se recomienda importar los prefijos postales como texto y verificar los tipos con los controles de `02` y `04`.

`05` crea `fact_sales` con una fila por artículo de pedido, sin unir directamente pagos ni reseñas. `07` agrega artículos y reseñas por separado a nivel de `order_id` antes de unirlos a `orders`, para obtener una fila por pedido en `fact_orders`. `06` conserva el nivel de detalle necesario para cada análisis; las consultas por medio de pago trabajan con registros de pago. La recurrencia se calcula con `customer_unique_id` sobre pedidos entregados dentro del período seleccionado.

`06` y `07` utilizan cero para ciertos conteos sin registros asociados, pero no sustituyen indiscriminadamente los importes ni las puntuaciones ausentes por cero. Conservan controles e indicadores para identificar datos incompletos.

## Categorías de fact_sales

`05` usa primero la traducción no vacía, luego la categoría original no vacía y finalmente `unknown`. Su UPDATE recupera también categorías nulas, vacías o marcadas como `unknown` a partir de productos y traducciones disponibles.

La tardanza se calcula comparando días: entregar durante el día estimado es puntual. El script incluye un UPDATE para aplicar esta regla a `fact_sales` existente. Si la tabla ya existe, omite únicamente el CREATE TABLE y ejecuta los UPDATE y controles. Estos cambios no incorporan pedidos nuevos ni sincronizan todos los campos con staging. Refresca Power BI después de ejecutarlos; las
medidas DAX deben revisarse por separado.

`06` contiene únicamente consultas, con el universo comercial restringido a pedidos entregados. La primera consulta muestra cobertura de todos los estados. Cada bloque `WITH ... SELECT` es independiente y declara la ventana de compra en `parametros`: inicio incluido y final excluido. Para comparar resultados, usa las mismas fechas en todos los bloques.

Los importes observados excluyen nulos y negativos, informando las incidencias; con incidencias no deben presentarse como totales definitivos. El valor medio por pedido usa solo pedidos con detalle monetario completo. Las tasas de tardanza usan pedidos evaluables y las de satisfacción, pedidos con puntuación válida. Los porcentajes SQL están en escala 0–100, con NULL si no hay denominador.

Las consultas mensuales, por estado y de comparación de categorías se consolidaron para evitar repetir indicadores. El ranking de categorías incluye `unknown` aunque quede fuera del top 10, y calcula la participación antes de recortar el ranking. Consulta las reglas completas en [`report/definicion_indicadores.md`](../report/definicion_indicadores.md).
