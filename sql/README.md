# Ejecución de los scripts SQL

Ejecutar sobre la base `olist_analytics`, en este orden:

| Script | Propósito |
| --- | --- |
| `01_create_schemas.sql` | Crear los esquemas `staging` y `analytics`. |
| `02_validate_raw_data.sql` | Inspeccionar tipos, conteos, estados, fechas de compra e importes de las tablas raw. |
| `03_validate_relationships.sql` | Detectar pedidos, artículos, pagos y reseñas sin su registro relacionado en staging. |
| `04_create_and_validate_analytics.sql` | Crear las nueve tablas de analytics, convertir fechas e importes y comprobar cada tabla. |
| `05_create_and_validate_fact_sales.sql` | Crear la tabla de hechos por artículo y comprobar conteos, claves, importes y categorías. |
| `06_business_analysis.sql` | Consultar indicadores de ventas, entregas, reseñas, recurrencia y pagos. |
| `07_create_and_validate_powerbi_model.sql` | Crear las vistas de pedidos y calendario para Power BI; validar claves, cobertura e indicadores. |

Entre `01` y `02` deben estar creadas y cargadas las nueve tablas raw. Estos
scripts no realizan la importación de los CSV ni crean las tablas de staging.

`07` se puede ejecutar completo varias veces porque utiliza `CREATE OR REPLACE
VIEW`. Requiere las tablas de `04` y `fact_sales` actualizada según `05`. No hace
falta repetir `01`–`06` si esos pasos ya se completaron. Las vistas contienen
todos los pedidos; los filtros comerciales se aplican al consultar o en las
medidas DAX. El modelo y sus relaciones están documentados en
[`powerbi/README.md`](../powerbi/README.md).

## Categorías de fact_sales

`05` usa primero la traducción no vacía, luego la categoría original no vacía y
finalmente `unknown`. Su UPDATE recupera también categorías nulas, vacías o
marcadas como `unknown` a partir de productos y traducciones disponibles.

La tardanza se calcula comparando días: entregar durante el día estimado es
puntual. El script incluye un UPDATE para aplicar esta regla a `fact_sales`
existente. Si la tabla ya existe, omite únicamente el CREATE TABLE y ejecuta los
UPDATE y controles. Estos cambios no incorporan pedidos nuevos ni sincronizan
todos los campos con staging. Refresca Power BI después de ejecutarlos; las
medidas DAX deben revisarse por separado.

`06` contiene únicamente consultas, con el universo comercial restringido a
pedidos entregados. La primera consulta muestra cobertura de todos los estados.
Cada bloque `WITH ... SELECT` es independiente y declara la ventana de compra
en `parametros`: inicio incluido y final excluido. Para comparar resultados,
usa las mismas fechas en todos los bloques.

Los importes observados excluyen nulos y negativos, informando las incidencias;
con incidencias no deben presentarse como totales definitivos. El valor medio
por pedido usa solo pedidos con detalle monetario completo. Las tasas de
tardanza usan pedidos evaluables y las de satisfacción, pedidos con puntuación
válida. Los porcentajes SQL están en escala 0–100, con NULL si no hay denominador.

Las consultas mensuales, por estado y de comparación de categorías se
consolidaron para evitar repetir indicadores. El ranking de categorías incluye
`unknown` aunque quede fuera del top 10, y calcula la participación antes de
recortar el ranking. Consulta las reglas completas en
[`report/definicion_indicadores.md`](../report/definicion_indicadores.md).
