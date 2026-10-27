"""Ejecutar y guardar el notebook usando el mismo Python que inicia este script."""

import os
from pathlib import Path
import subprocess
import sys

import nbformat
from nbclient import NotebookClient
from jupyter_client import KernelManager


def main():
    root = Path(__file__).resolve().parents[1]
    path = root / 'notebooks/01_exploracion_olist.ipynb'
    notebook = nbformat.read(path, as_version=4)
    nbformat.validate(notebook)
    manager = KernelManager(kernel_name='python3')
    manager.kernel_spec.argv = [sys.executable, '-m', 'ipykernel_launcher',
                                '-f', '{connection_file}']

    def progreso(cell, cell_index, **kwargs):
        if cell.cell_type == 'code':
            print(f'Ejecutando celda {cell_index + 1}/{len(notebook.cells)}', flush=True)

    client = NotebookClient(notebook, km=manager, timeout=300,
                            resources={'metadata': {'path': str(root)}},
                            on_cell_start=progreso)
    try:
        kwargs = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {}
        client.execute(**kwargs)
    finally:
        # En caso de error, conservar la salida que permite localizarlo.
        try:
            nbformat.write(notebook, path)
        finally:
            if manager.has_kernel:
                manager.shutdown_kernel(now=True)
    print('Notebook ejecutado y guardado con resultados.', flush=True)


if __name__ == '__main__':
    main()
