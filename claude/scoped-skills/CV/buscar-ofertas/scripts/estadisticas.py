#!/usr/bin/env python3
"""Estadísticas acumuladas de la búsqueda de empleo.

Uso: python3 .claude/skills/buscar-ofertas/scripts/estadisticas.py [aplicaciones.md] [ofertas_vistas.md]

Lee las tablas de los dos archivos y escribe los totales en una línea por métrica.
"""
import sys


def filas(ruta, cabecera):
    """Filas de la tabla markdown cuya cabecera empieza por `cabecera`."""
    dentro, salida = False, []
    for linea in open(ruta, encoding="utf-8"):
        if linea.startswith("|"):
            celdas = [c.strip() for c in linea.strip().strip("|").split("|")]
            if celdas[0] == cabecera:
                dentro = True
            elif dentro and not set(celdas[0]) <= {"-"}:
                salida.append(celdas)
        elif dentro:
            dentro = False
    return salida


def main():
    apps = sys.argv[1] if len(sys.argv) > 1 else "aplicaciones.md"
    vistas = sys.argv[2] if len(sys.argv) > 2 else "ofertas_vistas.md"

    por_aplicar = filas(apps, "Encontrada")
    candidaturas = filas(apps, "Empresa")  # columna 4 = Estado
    registro = filas(vistas, "Vista")  # columna 4 = Decisión

    decisiones = [f[4].lower() for f in registro]
    estados = [f[4].lower() for f in candidaturas]

    vistas_n = len(registro)
    descartadas = sum(d == "descartada" for d in decisiones)
    validas = vistas_n - descartadas  # las que pasaron los filtros de la skill
    aplicadas = len(candidaturas)
    rechazadas = sum(e.startswith("rechazada") for e in estados)
    entrevistadas = sum(
        ("entrevista" in e and "sin entrevista" not in e) or e.startswith("oferta")
        for e in estados
    )
    pendientes = sum(
        not (e.startswith(("rechazada", "descartada", "oferta"))) for e in estados
    )

    print(f"Ofertas vistas:       {vistas_n}")
    print(f"Ofertas válidas:      {validas}  (pasaron los filtros de la skill)")
    print(f"Ofertas aplicadas:    {aplicadas}")
    print(f"Ofertas rechazadas:   {rechazadas}  (por la empresa)")
    print(f"Ofertas con entrevista: {entrevistadas}")
    print(f"Ofertas pendientes:   {pendientes}  (aplicadas sin resolver) + {len(por_aplicar)} por aplicar")


if __name__ == "__main__":
    main()
