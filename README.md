# Olist E-commerce Analytics

Análisis de datos de un e-commerce brasileño utilizando **SQL, PostgreSQL, Python, Pandas y Power BI**, con el objetivo de identificar tendencias de ventas, evaluar el desempeño logístico y analizar la satisfacción de los
clientes.

## Descripción del proyecto

Este proyecto analiza datos históricos de pedidos de Olist, una plataforma brasileña de comercio electrónico. El objetivo es transformar datos transaccionales en información útil para comprender el comportamiento de las
ventas, el rendimiento de las categorías de productos y la relación entre las entregas y las reseñas de los clientes.

El proyecto abarca desde la importación y preparación de los datos hasta la creación de consultas analíticas, validaciones cruzadas y visualizaciones interactivas.

## Objetivos

- Analizar la evolución mensual de los pedidos y del valor de mercancía vendido.
- Identificar las categorías de productos con mayor valor de mercancía y volumen de artículos vendidos.
- Evaluar la puntualidad de las entregas y los retrasos logísticos.
- Investigar la asociación entre los tiempos de entrega y las puntuaciones de las reseñas.
- Analizar la cantidad de clientes y sus patrones de compra.
- Desarrollar un dashboard interactivo para facilitar la exploración de los resultados.

## Tecnologías utilizadas

- **PostgreSQL:** almacenamiento, transformación y análisis de datos.
- **SQL:** limpieza, validación, agregaciones y consultas analíticas.
- **DBeaver:** gestión de la base de datos y ejecución de consultas.
- **Python y Pandas:** análisis exploratorio, validación de resultados, generación de indicadores y visualizaciones.
- **Power BI Desktop:** creación de dashboards, indicadores KPI y visualizaciones interactivas.
- **DAX:** creación de medidas y cálculos para el análisis en Power BI.

## Fuente de datos

El proyecto utiliza el conjunto de datos público de Olist, que contiene información sobre pedidos, clientes, productos, vendedores, pagos, entregas y reseñas.

Dataset: [Brazilian E-Commerce Public Dataset by Olist — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

Los datos originales se distribuyen en varios archivos CSV relacionados entre sí mediante identificadores como `order_id`, `customer_id` y `product_id`.

## Proceso de análisis

### 1. Preparación e importación de datos

- Descarga e identificación de los archivos CSV.
- Importación de las tablas en PostgreSQL.
- Organización de los datos en los esquemas `staging` y `analytics`.
- Validación de cantidades de registros, valores nulos, claves únicas y tipos de datos.
- Preparación de campos de fecha e importes para el análisis.

### 2. Transformación y modelado con SQL

Se desarrollaron consultas para transformar los datos originales y preparar tablas analíticas para el análisis y Power BI.

Entre las tareas realizadas se incluyen:

- Validación de identificadores y registros relacionados.
- Preparación de fechas de compra y entrega.
- Integración de información de pedidos, artículos, productos y clientes.
- Cálculo del valor de mercancía y del importe de flete.
- Clasificación de pedidos entregados a tiempo y con retraso.
- Agregación de reseñas por pedido y validación de sus puntuaciones.
- Preparación de vistas de pedidos y calendario para Power BI.

La tabla `analytics.fact_sales` contiene información a nivel de artículo de pedido. La vista `analytics.fact_orders` contiene una fila por pedido, con artículos y reseñas agregados antes de unirlos. `analytics.dim_date` proporciona el calendario. Las relaciones del informe transmiten los filtros desde el calendario a los pedidos y desde estos a los artículos, en una sola dirección.

Las métricas generales de pedidos se calculan sobre `fact_orders`; las ventas por categoría, sobre `fact_sales`. La recurrencia utiliza `customer_unique_id`. Así se evita ponderar pedidos por su número de artículos o multiplicar importes al combinar tablas de detalle.

El valor de mercancía representa el precio de los artículos vendidos. No debe interpretarse como beneficio, margen ni ingreso neto de la plataforma. Del mismo modo, el importe de flete no representa necesariamente el costo operativo asumido por Olist.

### 3. Análisis exploratorio

El notebook de Pandas permite analizar y validar diferentes indicadores para identificar patrones relevantes:

- Evolución del valor de mercancía y de los pedidos por mes.
- Categorías con mayor valor de mercancía y cantidad de artículos vendidos.
- Porcentaje de entregas tardías.
- Diferencias en las puntuaciones medias de reseñas según la puntualidad de la entrega.
- Frecuencia de compra y recurrencia de clientes.
- Distribuciones de precios y tiempos de entrega; controles de calidad e importes de flete.
- Contraste de resultados entre Pandas y PostgreSQL.

### 4. Visualización con Power BI

El dashboard se organiza en dos páginas temáticas:

**Rendimiento comercial**

- Tarjetas de valor de mercancía, pedidos entregados, artículos vendidos y valor medio por pedido.
- Evolución mensual del valor de mercancía y de los pedidos entregados.
- Top 10 categorías y top 10 estados por valor de mercancía.
- Filtros por período de compra y estado del cliente.

**Logística y clientes**

- Tarjetas de porcentaje de tardanza, retraso medio, calificación media y porcentaje de clientes recurrentes.
- Evolución mensual de la tardanza, con un mínimo de 100 pedidos evaluables por mes mostrado.
- Comparación de calificaciones medias entre entregas puntuales y tardías.
- Top 10 estados por tasa de tardanza, con un mínimo de 100 pedidos evaluables por estado.
- Clientes con una compra frente a clientes con más de una compra entregada.
- Filtros por período de compra y estado del cliente.

Las páginas utilizan medidas DAX y filtros interactivos para facilitar el análisis de los datos. Los mínimos de volumen limitan los grupos mostrados en esos gráficos, no el universo de las tarjetas generales. El filtro de fecha siempre se refiere a la compra, aunque se analice una entrega posterior.

Las siguientes capturas muestran el informe con el período 04/09/2016–17/10/2018 y todos los estados del cliente seleccionados. Son evidencia visual del dashboard, no datos de prueba.

### Rendimiento comercial

![Dashboard de rendimiento comercial](<powerbi/capturas/rendimiento general.png>)

### Logística y clientes

![Dashboard de logística y clientes](<powerbi/capturas/logistica y clientes.png>)

## Principales resultados

Los resultados de referencia corresponden a la ventana completa de compras, desde el 4 de septiembre de 2016 hasta el 17 de octubre de 2018 inclusive, y utilizan pedidos con estado `delivered` para los indicadores comerciales.

| Indicador | Resultado |
| --- | ---: |
| Pedidos entregados | 96.478 |
| Artículos vendidos | 110.197 |
| Clientes compradores | 93.358 |
| Valor de mercancía | R$ 13.221.498,11 |
| Valor medio por pedido | R$ 137,04 |
| Pedidos evaluables para puntualidad | 96.470 |
| Pedidos entregados tarde | 6.534 |
| Porcentaje de entregas tardías | 6,77 % |
| Retraso medio de pedidos tardíos | 10,62 días |
| Calificación media por pedido con puntuación válida | 4,16 |
| Clientes recurrentes | 2.801 |
| Porcentaje de recurrencia | 3,00 % |

Como inventario técnico, `fact_sales` contiene **112.650 filas** y **98.666 pedidos distintos**, considerando todos los estados. Esos conteos no deben confundirse con los indicadores anteriores, restringidos a entregados.

La puntualidad se evalúa comparando la fecha real con la fecha estimada de entrega. Entregar durante el día estimado se considera puntual, independientemente de la hora.

Los 8 pedidos entregados sin fechas suficientes no entran en el denominador de puntualidad. El valor medio por pedido considera únicamente pedidos con detalle monetario completo. Las reglas están en [`report/definicion_indicadores.md`](report/definicion_indicadores.md).

### Entregas y satisfacción del cliente

La puntuación media de las reseñas se analiza por pedido y se compara entre entregas puntuales y tardías. Esta comparación describe una asociación entre el retraso y la satisfacción, pero no demuestra por sí sola una relación causal.

Los pedidos sin una puntuación válida se excluyen del promedio y se informan como falta de cobertura; no se convierten en puntuaciones de cero.

La media es **4,29** para entregas puntuales y **2,27** para entregas tardías. Noviembre de 2017 registra el máximo mensual observado de mercancía (**R$ 987.765,37**). Las cinco primeras categorías concentran **39,83 %** del
valor de mercancía. Estos resultados y sus posibles implicaciones se desarrollan en [`report/conclusiones.md`](report/conclusiones.md), que responde las cinco preguntas del proyecto e incluye limitaciones y acciones sugeridas.

## Validación y límites

- Pandas y las referencias de PostgreSQL coinciden en **59 comprobaciones**: 14 indicadores generales y 45 comparaciones de categorías y satisfacción.
- Las referencias de [`report/referencias_sql/`](report/referencias_sql/README.md) son resultados guardados de PostgreSQL 16, no una conexión en vivo del notebook.
- Los meses extremos tienen cobertura limitada; no se interpretan como períodos completos ni se atribuye el pico de ventas a una campaña sin evidencia adicional.
- La recurrencia del 3,00 % mide repetición dentro de la ventana, no abandono ni retención de largo plazo. Los clientes observados al final tienen menos tiempo para volver a comprar.
- Las capturas permiten revisar apariencia y filtros visibles; no prueban por sí solas las fórmulas DAX ni todas las interacciones del informe.

## Cómo reproducir el análisis

1. Descargar los nueve CSV y colocarlos en `data/`, conservando los nombres indicados en [`data/README.md`](data/README.md).
2. Crear la base `olist_analytics`, ejecutar `01_create_schemas.sql` y crear/cargar las tablas raw de staging. **Este paso de creación y carga aún es manual**: no se incluye un instalador SQL completo de staging.
3. Seguir el orden de [`sql/README.md`](sql/README.md) para validar, transformar y analizar. Si las tablas ya existen, respetar las instrucciones de cada script; no repetir sus `CREATE TABLE` indiscriminadamente.
4. Desde la raíz del proyecto, preparar Python y ejecutar el notebook. Ejemplo para Windows con PowerShell y Python 3.12, el entorno validado:

   ```powershell
   python -m venv .venv
   .\.venv\Scripts\python.exe -m pip install -r requirements.txt
   .\.venv\Scripts\python.exe notebooks/ejecutar_notebook.py
   ```

   El notebook lee directamente los CSV y puede ejecutarse sin PostgreSQL. Guarda resultados agregados y figuras en `report/resultados_pandas/`. Más detalles en [`notebooks/README.md`](notebooks/README.md).
5. Para Power BI, importar `dim_date`, `fact_orders` y `fact_sales`, configurar las relaciones descritas en [`powerbi/README.md`](powerbi/README.md) y aplicar las definiciones del proyecto a las medidas. El `.pbix` se mantiene local; el repositorio por sí solo no reconstruye automáticamente el dashboard.

## Estructura del proyecto

```text
ecommerce-analytics/
├── data/
│   └── README.md
├── notebooks/
│   ├── README.md
│   ├── 01_exploracion_olist.ipynb
│   └── ejecutar_notebook.py
├── sql/
│   ├── README.md
│   ├── 01_create_schemas.sql
│   ├── 02_validate_raw_data.sql
│   ├── 03_validate_relationships.sql
│   ├── 04_create_and_validate_analytics.sql
│   ├── 05_create_and_validate_fact_sales.sql
│   ├── 06_business_analysis.sql
│   └── 07_create_and_validate_powerbi_model.sql
├── powerbi/
│   ├── README.md
│   ├── capturas/
│   │   ├── rendimiento general.png
│   │   └── logistica y clientes.png
│   └── tema_olist.json
├── report/
│   ├── definicion_indicadores.md
│   ├── conclusiones.md
│   ├── referencias_sql/
│   └── resultados_pandas/          # generado localmente, excluido de Git
├── requirements.txt
├── .gitignore
└── README.md
```

Los CSV originales, el informe `.pbix` y los resultados regenerables de Pandas se mantienen como archivos locales y están excluidos por `.gitignore`. El notebook conserva salidas ejecutadas; las referencias SQL y las conclusiones
sí se incluyen en el repositorio. La carpeta `powerbi/capturas/` contiene las dos capturas del informe y no está excluida de Git.
