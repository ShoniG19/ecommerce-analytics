# Exploración con Pandas

El notebook `notebooks/01_exploracion_olist.ipynb` contiene el análisis exploratorio del conjunto de datos de Olist mediante Python y Pandas. Examina la calidad de los datos, prepara las variables necesarias y calcula indicadores comerciales, logísticos y de satisfacción. También contrasta los resultados con referencias obtenidas mediante SQL.

### Requisitos

- Python 3.12 y las dependencias especificadas en `requirements.txt`.
- Los nueve archivos CSV originales en el directorio `data/`.
- Las referencias SQL ubicadas en `report/referencias_sql/`.
- Permisos de escritura en `report/resultados_pandas/` para guardar los resultados.

El análisis puede ejecutarse en un entorno Python local o en un servicio compatible con Jupyter. La configuración concreta depende del entorno elegido, pero deben mantenerse disponibles los archivos del proyecto y las dependencias necesarias.

### Ejecución

1. Preparar un entorno Python e instalar las dependencias de `requirements.txt`.
2. Colocar los datos originales en `data/` y verificar que estén disponibles las referencias SQL.
3. Abrir `notebooks/01_exploracion_olist.ipynb` en una interfaz compatible con Jupyter.
4. Seleccionar el entorno Python preparado y ejecutar las celdas en orden, desde el inicio.

El notebook localiza la raíz del proyecto buscando `data/olist_orders_dataset.csv` en el directorio de trabajo y sus directorios superiores. Por ello, se recomienda ejecutarlo desde la raíz del proyecto o desde `notebooks/`.

También es posible ejecutar el análisis desde la terminal mediante el ejecutor incluido:

```powershell
.venv\Scripts\python.exe notebooks/ejecutar_notebook.py
```

Este método utiliza el entorno Python indicado para ejecutar el notebook y mostrar el avance de las celdas.

### Contenido del análisis

1. Carga e inventario de los nueve archivos CSV, con generación de huellas SHA-256.
2. Evaluación de tipos de datos, valores nulos, duplicados, claves y relaciones.
3. Preparación de fechas, importes y categorías, con registro de incidencias.
4. Agregación por pedido antes de combinar artículos y reseñas, para evitar duplicaciones en los cálculos.
5. Análisis de evolución comercial, categorías, entregas, satisfacción y recurrencia de clientes.
6. Estudio de distribuciones de precios y tiempos, incluidos los valores extremos.
7. Validación de resultados mediante su contraste con referencias SQL.

Los archivos originales se conservan sin modificaciones. Los importes se representan en centavos enteros para evitar problemas de precisión, y los valores nulos no se convierten automáticamente en cero.

La tabla de geolocalización se analiza por separado y no se incorpora a las relaciones principales, ya que contiene varias filas por prefijo y no es necesaria para responder las cinco preguntas del proyecto.

### Resultados

La ejecución genera tablas agregadas y gráficos en formato PNG dentro de `report/resultados_pandas/`. Cada ejecución sobrescribe los archivos de salida que genera.

El archivo `fuentes_sha256.csv` permite identificar los archivos utilizados en el análisis. El período estudiado y las versiones del entorno se documentan en el notebook.

Las conclusiones se presentan por separado en [`report/conclusiones.md`](../report/conclusiones.md), mientras que las reglas de cálculo de los indicadores están documentadas en [`report/definicion_indicadores.md`](../report/definicion_indicadores.md).

### Validación y limitaciones

Las referencias de `report/referencias_sql/` corresponden a ejecuciones realizadas en una instancia temporal de PostgreSQL 16. El notebook las utiliza para contrastar resultados, sin conectarse a la base de datos de trabajo ni solicitar credenciales.

Cuando cambia el período analizado, se omite la comparación con la referencia correspondiente a la ventana completa. Si cambian los datos sin cambiar el período y los resultados dejan de coincidir, la validación se detiene para facilitar la investigación de las diferencias. Las referencias no se actualizan automáticamente a partir de los resultados de Pandas.

La ejecución completa se ha verificado en Windows con Python 3.12 y las versiones especificadas en `requirements.txt`. Otros entornos pueden requerir ajustes de compatibilidad.

Este análisis es exploratorio: identifica patrones y asociaciones en los datos, pero sus resultados no demuestran causalidad.
