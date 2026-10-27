# Referencia para contrastar Pandas

`indicadores_06.csv` transcribe los resultados obtenidos al ejecutar `05` y `06` en PostgreSQL 16 con los CSV del proyecto durante la validación del 24/10/2026. Se utilizó una instancia temporal independiente, no la base de trabajo del usuario.

`categorias_06.csv` y `satisfaccion_06.csv` se exportaron directamente al volver a ejecutar `06` en otra instancia temporal para validar el notebook. Cubren el ranking de categorías (incluyendo `unknown`) y la satisfacción por puntualidad.

Ventana de compra: `2016-09-04 <= fecha < 2018-10-18`; estado `delivered`. Los importes están en BRL y los porcentajes en escala 0–100. Las definiciones son las de `report/definicion_indicadores.md`.

Esta es una referencia estática: el notebook no se conecta a PostgreSQL ni ejecuta SQL en tiempo real. Si cambian los CSV, las definiciones o el período, se deben revisar las diferencias y obtener una nueva referencia mediante SQL; no reemplazarla automáticamente por el resultado de Pandas.
