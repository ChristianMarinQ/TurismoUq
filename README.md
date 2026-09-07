# TurismoUQ — Base de datos (Bases de Datos II, 12338)

Entregable de base de datos para TurismoUQ, sobre Oracle XE 21c. **No incluye interfaz** — todo se ejecuta y sustenta desde SQL*Plus / SQL Developer, según el enunciado del curso.

## Requisitos

- Oracle Database XE 21c instalado y corriendo localmente (ver guía de instalación más abajo).
- Un cliente para correr los scripts: `sqlplus` (incluido con XE) o SQL Developer / SQL Developer Extension de VS Code.

## Instalar Oracle XE 21c (Windows)

1. Descarga el instalador desde la página oficial de Oracle: https://www.oracle.com/database/technologies/xe-downloads.html (elige la versión Windows x64, 21c).
2. Ejecuta el instalador. Cuando te pida la contraseña de **SYS/SYSTEM**, elige una y **anótala** — la necesitarás para el primer script.
3. Al terminar, el instalador deja corriendo el servicio `OracleServiceXE` y el listener en el puerto `1521`. La PDB por defecto se llama `XEPDB1`.
4. Verifica que quedó arriba abriendo una consola y corriendo:
   ```bash
   sqlplus system/<tu_clave>@//localhost:1521/XEPDB1
   ```
   Si te conecta y ves `SQL>`, todo listo.

## Orden de ejecución de los scripts

```bash
# 1) Conectado como SYSTEM — crea el tablespace y el usuario del proyecto
sqlplus system/<tu_clave_system>@//localhost:1521/XEPDB1 @01_ddl/01_tablespace_y_usuario.sql

# 2) A partir de aquí, conectado como el usuario del proyecto
sqlplus turismouq@//localhost:1521/XEPDB1 @01_ddl/02_tablas.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @02_carga_datos/01_datos_maestros.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @02_carga_datos/02_clientes_reservas.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @03_consultas_analisis/01_consultas.sql
```

`02_clientes_reservas.sql` genera 25.000 reservas con su lógica de tarifas/pagos/servicios; puede tardar varios minutos. Va mostrando avance cada 1.000 reservas.

**Cambia la clave `<clave_turismouq>`** por una propia antes de usar esto en serio (queda en texto plano en `01_tablespace_y_usuario.sql`, solo apta para ambiente local de desarrollo).

## Estructura del repositorio

```
TurismoUQ/
├── docs/
│   └── 00_modelo_ER.md          # Modelo entidad-relación y las 2 decisiones de diseño clave
├── 01_ddl/
│   ├── 01_tablespace_y_usuario.sql
│   └── 02_tablas.sql            # 14 entidades con PK, FK, CHECK, NOT NULL, UNIQUE
├── 02_carga_datos/
│   ├── 01_datos_maestros.sql    # Municipios, tipos, alojamientos, habitaciones, temporadas, tarifas, servicios, usuarios
│   └── 02_clientes_reservas.sql # 3.000 clientes, 25.000 reservas, pagos, servicios, reseñas
└── 03_consultas_analisis/
    └── 01_consultas.sql         # Las 8 consultas obligatorias de la Entrega 1
```

## Estado del proyecto

- [x] Entrega 1 — Modelo, DDL, carga de datos, 8 consultas de análisis
- [ ] Entrega 2 — Capa PL/SQL (`fn_valor_estadia`, `sp_crear_reserva`, cursor, paquete, triggers)
- [ ] Entrega 3 — Transacciones, índices y seguridad
- [ ] Sustentación

## Nota sobre alcance

Este repositorio es el entregable **académico** (solo base de datos, sin interfaz, tal como exige el enunciado). La aplicación funcional con interfaz (React + Node/TypeScript) y la integración de pasarela de pago (Wompi sandbox) viven en un proyecto aparte: `TurismoUQ-App/`, para no mezclar el alcance calificado con el desarrollo adicional.
