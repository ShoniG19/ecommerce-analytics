# Exploración con Pandas

Abrir `01_exploracion_olist.ipynb` en VS Code con las extensiones Python y
Jupyter. Seleccionar como kernel el Python de `.venv` y usar **Run All / Ejecutar
todo**. El notebook encuentra la raíz tanto desde `notebooks/` como desde la
carpeta principal del proyecto.

## Preparación desde la raíz

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Si `.venv` ya existe y tiene las dependencias, no hace falta recrearlo. No es
necesario activar el entorno ni modificar la política de ejecución de PowerShell.

También se puede ejecutar y guardar el notebook desde la terminal:

```powershell
.\.venv\Scripts\python.exe notebooks/ejecutar_notebook.py
```

El ejecutor utiliza ese mismo Python para el kernel y muestra el avance por celda.

## Contenido

1. Carga de los nueve CSV, inventario y huellas SHA-256 de las fuentes.
2. Tipos originales, nulos, duplicados, claves y relaciones.
3. Preparación de fechas, importes y categorías, con conteo de incidencias.
4. Agregación por pedido antes de combinar artículos y reseñas.
5. Evolución comercial, categorías, entregas, satisfacción y recurrencia.
6. Distribuciones de precios y tiempos con identificación de valores extremos.
7. Contraste con referencias SQL y observaciones basadas en resultados.

Se conservan los CSV originales. Los importes se representan en centavos enteros
para evitar errores de precisión; los nulos no se convierten a cero. La tabla
de geolocalización se perfila, pero no se une a los pedidos porque contiene
varias filas por prefijo y no es necesaria para las cinco preguntas del proyecto.

## Resultados y límites

El notebook guarda tablas agregadas, gráficos PNG y `observaciones.md` en
`report/resultados_pandas/`. Una nueva ejecución reemplaza esos resultados.
`configuracion_ejecucion.csv` y `fuentes_sha256.csv` documentan el período,
versiones y archivos utilizados.

Las referencias de `report/referencias_sql/` son capturas de ejecuciones en una
instancia temporal de PostgreSQL 16 con los CSV del proyecto. El notebook no se
conecta a la base de trabajo ni solicita credenciales. Si se cambia el período,
se omite la comparación contra la referencia de la ventana completa. Si cambian
los datos manteniendo el período, una diferencia detiene la validación para
investigarla; no se actualiza automáticamente la referencia a partir de Pandas.

Este notebook es exploratorio: las recomendaciones no demuestran causalidad.
Las reglas completas están en
[`definicion_indicadores.md`](../report/definicion_indicadores.md).
