# Conclusiones del análisis de Olist

## Alcance y criterio de lectura

El análisis considera compras realizadas entre el **4 de septiembre de 2016 y el 17 de octubre de 2018**, inclusive. Los indicadores comerciales corresponden a pedidos con estado registrado `delivered`. Los importes se expresan en reales brasileños y representan valor de mercancía, sin flete: no son beneficios ni ingresos propios de la plataforma.

La base analizada incluye **96.478 pedidos entregados**, **110.197 artículos** y **93.358 clientes compradores**. El valor de mercancía observado es **R$ 13.221.498,11**, con un valor medio de **R$ 137,04 por pedido**.

Las conclusiones se apoyan en el notebook, los resultados agregados de Pandas y las referencias SQL. Las capturas de Power BI sirven para mostrar los resultados y su contexto de filtros; no sustituyen las comprobaciones numéricas.

## 1. ¿Cómo evolucionan las ventas y los pedidos?

El volumen observado crece durante buena parte de 2017. Noviembre de ese año registra el máximo mensual de valor de mercancía y de pedidos entregados en la serie analizada. En 2018 el volumen permanece por encima de los primeros meses de 2017, aunque con fluctuaciones.

| Mes de compra | Pedidos entregados | Valor de mercancía |
| --- | ---: | ---: |
| Enero de 2017 | 750 | R$ 111.798,36 |
| Octubre de 2017 | 4.478 | R$ 648.247,65 |
| Noviembre de 2017 | 7.289 | R$ 987.765,37 |
| Diciembre de 2017 | 5.513 | R$ 726.033,19 |
| Mayo de 2018 | 6.749 | R$ 977.544,69 |
| Agosto de 2018 | 6.351 | R$ 838.576,64 |

**Interpretación.** El negocio observado presenta cambios importantes de demanda que conviene considerar al planificar capacidad operativa. El pico de noviembre es una señal para investigar, no una prueba de estacionalidad recurrente.

**Posible acción.** Revisar planificación de inventario, preparación de pedidos y capacidad de transporte antes de períodos de demanda alta. Contrastar el pico con campañas y condiciones comerciales si se dispone de esa información.

**Limitación.** No se puede atribuir el pico a una campaña específica con estos datos. La cobertura de los extremos es escasa: septiembre y diciembre de 2016 tienen un único pedido entregado cada uno. La ventana de compras se extiende hasta octubre de 2018, pero la serie de compras de pedidos entregados termina en agosto. Ausencia de registros entregados al final no demuestra una caída a cero de la actividad comercial.

Evidencia: análisis mensual y cobertura del
[notebook](../notebooks/01_exploracion_olist.ipynb), y consultas 01 y 03 de [`06_business_analysis.sql`](../sql/06_business_analysis.sql).

## 2. ¿Qué categorías generan más valor de mercancía?

`health_beauty` lidera el ranking. Las cinco primeras categorías concentran **39,83 %** del valor de mercancía observado.

| Categoría | Valor de mercancía | Participación |
| --- | ---: | ---: |
| health_beauty | R$ 1.233.131,72 | 9,33 % |
| watches_gifts | R$ 1.166.176,98 | 8,82 % |
| bed_bath_table | R$ 1.023.434,76 | 7,74 % |
| sports_leisure | R$ 954.852,55 | 7,22 % |
| computers_accessories | R$ 888.724,61 | 6,72 % |

**Interpretación.** Estas categorías tienen un peso comercial relevante, pero ninguna representa por sí sola una mayoría de las ventas. El ranking por importe tampoco equivale al ranking por cantidad: `bed_bath_table` registra
10.953 artículos entregados, frente a 9.465 de `health_beauty`.

**Posible acción.** Priorizar el seguimiento de disponibilidad y cumplimiento logístico de estas categorías, considerando conjuntamente volumen de artículos y valor de mercancía. Para decidir inversiones comerciales también harían falta costos, márgenes y capacidad de los vendedores.

**Limitación.** Vender más no implica ser más rentable. Además, la categoría `unknown` conserva **R$ 170.726,63**, el **1,29 %** del valor observado; se incluye en el denominador aunque no aparezca entre las diez primeras. Los pedidos de distintas categorías no se suman, porque un pedido puede contener varias.

Evidencia: [ranking SQL](referencias_sql/categorias_06.csv) y sección de categorías del [notebook](../notebooks/01_exploracion_olist.ipynb).

## 3. ¿Qué porcentaje de pedidos llega después de lo estimado?

De los **96.470 pedidos entregados con ambas fechas disponibles**, **6.534** llegaron después del día estimado: una tasa de tardanza del **6,77 %**. Hay **8 pedidos entregados sin clasificación**, excluidos de ese denominador.

Entre los pedidos tardíos, el retraso medio es de **10,62 días calendario** y la mediana, de **7 días**. La diferencia indica que los retrasos más largos elevan el promedio.

**Interpretación.** Aunque la mayoría de los pedidos evaluables llega a tiempo, los que incumplen la promesa presentan una demora relevante para la experiencia del cliente.

**Posible acción.** Investigar los segmentos con tasas altas y volumen suficiente, priorizando también la cantidad absoluta de pedidos afectados. Revisar rutas, vendedores y etapas de preparación antes de atribuir el problema a un único actor.

**Limitación.** La puntualidad se define por día, no por hora. La comparación de timestamps habría marcado como tardíos **1.292 pedidos** entregados durante el día prometido. Tampoco hay que interpretar porcentajes sin su denominador: septiembre de 2016 tiene 100 % de tardanza, pero se basa en un solo pedido.

En el dashboard, los rankings de estados y la serie mensual se presentan con un mínimo de **100 pedidos evaluables por grupo**. Este umbral mejora la interpretación de grupos pequeños; no es una prueba de significancia estadística. Las tarjetas generales conservan todos los pedidos elegibles. El mínimo de la serie mensual es un filtro visual: las series exploratorias de SQL/Pandas conservan también los meses de bajo volumen.

Evidencia: [indicadores SQL](referencias_sql/indicadores_06.csv), reglas de [puntualidad](definicion_indicadores.md) y distribuciones del notebook.

## 4. ¿Qué relación existe entre retrasos y calificaciones?

Los pedidos tardíos presentan una puntuación media menor y una mayor proporción de calificaciones bajas. Primero se promedian las reseñas válidas de cada pedido; después se calcula el promedio del grupo, dando el mismo peso a cada pedido.

| Clasificación | Pedidos con puntuación válida | Puntuación media | Promedio por pedido ≤ 2 |
| --- | ---: | ---: | ---: |
| A tiempo | 89.443 | 4,29 | 9,23 % |
| Tardío | 6.381 | 2,27 | 62,36 % |

La diferencia de puntuación es de aproximadamente **2,02 puntos** en una escala de 1 a 5. La calificación media del conjunto de pedidos entregados con puntuación válida, incluidos los no clasificables por puntualidad, es **4,16**.

**Interpretación.** Existe una asociación descriptiva marcada entre incumplir la fecha prometida y una peor evaluación de la experiencia.

**Posible acción.** Priorizar la prevención y comunicación de retrasos, y estudiar si las acciones de seguimiento mejoran la experiencia. Analizar conjuntamente categoría, vendedor, región y características del pedido para identificar otros factores asociados.

**Limitación.** No se demuestra causalidad. Pueden intervenir calidad del producto, atención y otros factores. Además, **646 pedidos entregados no tienen puntuación válida**: la comparación representa a quienes dejaron una evaluación utilizable, no necesariamente a todos los compradores. Los 8 pedidos sin clasificación de puntualidad se mantienen aparte y no se asignan al grupo puntual.

Evidencia: [comparación SQL de satisfacción](referencias_sql/satisfaccion_06.csv) y sección de satisfacción del notebook.

## 5. ¿Cuántos clientes vuelven a comprar?

De **93.358 clientes compradores**, **2.801** tienen más de un pedido entregado en la ventana: **3,00 %** de recurrencia observada. Los **90.557** restantes tienen una sola compra entregada.

**Interpretación.** La mayoría de los clientes identificados realiza una única compra observable dentro del período disponible.

**Posible acción.** Explorar iniciativas de segunda compra y analizar recurrencia por cohortes con ventanas de seguimiento comparables. Evaluar sus resultados antes de asumir que una campaña produce compras adicionales.

**Limitación.** Este porcentaje no es una tasa de abandono ni de retención histórica. Los clientes que compran al final tienen menos tiempo para repetir, y pueden existir compras fuera del período observado. Se utiliza
`customer_unique_id`, no `customer_id`, para reconocer al mismo cliente.

Evidencia: [indicadores SQL](referencias_sql/indicadores_06.csv) y sección de recurrencia del notebook.

## Prioridades sugeridas

| Prioridad | Investigación o acción | Cómo evaluar el avance |
| --- | --- | --- |
| Logística | Localizar segmentos con retrasos frecuentes y alto volumen afectado. | Tasa de tardanza, cantidad de pedidos afectados y días de demora. |
| Experiencia | Revisar comunicación y atención de pedidos con retraso. | Puntuación por pedido, proporción de calificaciones bajas y cobertura de reseñas. |
| Comercial | Planificar capacidad en categorías relevantes y períodos de mayor demanda. | Pedidos, artículos, valor de mercancía y cumplimiento de entrega. |
| Recurrencia | Estudiar la segunda compra con cohortes y tiempos de observación comparables. | Recompra dentro de una ventana fija; no solo el porcentaje global. |

Estas acciones son propuestas derivadas de un análisis descriptivo. El dataset no permite cuantificar por sí solo el retorno económico de implementarlas.

## Trazabilidad y validación

Se comprobaron **14 indicadores generales y 45 comparaciones de categorías y satisfacción** entre Pandas y referencias SQL, sin diferencias al nivel de precisión definido. Esto valida consistencia de cálculos, no garantiza que todas las interacciones de Power BI sean correctas; esas se revisan en el informe.

Las referencias SQL están versionadas en [referencias_sql](referencias_sql/README.md). Los CSV y figuras de `report/resultados_pandas/` se regeneran al ejecutar el notebook y están excluidos del versionado. Los resultados mensuales, de calidad y distribución también pueden consultarse en sus salidas guardadas.

Las [capturas del dashboard](../powerbi/capturas/) son evidencia visual complementaria del informe real. Muestran el período 04/09/2016–17/10/2018 y todos los estados del cliente seleccionados.
