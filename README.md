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

# 3) Entrega 2 — capa PL/SQL (requiere GRANT CREATE JOB TO turismouq; ya dado en la Entrega 1)
sqlplus turismouq@//localhost:1521/XEPDB1 @04_plsql/01_tipos.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @04_plsql/02_tabla_auditoria.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @04_plsql/03_package_reservas.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @04_plsql/04_triggers.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @04_plsql/05_pruebas.sql

# 4) Entrega 3 — transacciones
sqlplus turismouq@//localhost:1521/XEPDB1 @05_transacciones/01_pkg_transacciones.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @05_transacciones/02_pruebas_transacciones.sql

# 5) Entrega 3 — concurrencia (requiere DOS ventanas/worksheets abiertas a la vez)
sqlplus turismouq@//localhost:1521/XEPDB1 @06_concurrencia/01_pkg_demo_concurrencia.sql
# 02_elegir_habitacion.sql (checkin/checkout de cada experimento) para anotar un id_habitacion libre
# luego, ventana A: 03_sesionA_sin_lock.sql | ventana B (sin esperar nada): 04_sesionB_sin_lock.sql
# después, ventana A: 06_sesionA_con_lock.sql | ventana B (sin esperar nada): 07_sesionB_con_lock.sql
# y para revisar cada experimento: 08_verificar.sql

# 6) Entrega 3 — índices
sqlplus turismouq@//localhost:1521/XEPDB1 @07_indices/01_indices.sql

# 7) Entrega 3 — seguridad (el primer script va como SYSTEM, el resto como turismouq)
sqlplus system/<tu_clave_system>@//localhost:1521/XEPDB1 @08_seguridad/01_roles_usuarios_profile.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @08_seguridad/02_vistas_recepcion.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @08_seguridad/03_permisos_por_rol.sql
sqlplus turismouq@//localhost:1521/XEPDB1 @08_seguridad/04_pruebas_seguridad.sql
```

`02_clientes_reservas.sql` genera 25.000 reservas con su lógica de tarifas/pagos/servicios; puede tardar varios minutos. Va mostrando avance cada 1.000 reservas.

`05_pruebas.sql` es el script de demostración para la sustentación: crea reservas válidas e inválidas para mostrar cada excepción (`ORA-20001`..`ORA-20004`), dispara el trigger anti-solape con un INSERT directo, dispara la auditoría de tarifas con un UPDATE masivo, y corre la liquidación mensual.

El experimento de concurrencia (`06_concurrencia/`) necesita **dos ventanas de SQL Developer abiertas al mismo tiempo, ambas conectadas a TurismoUQ** — una hace de "Sesión A" y otra de "Sesión B". Cada script de sesión explica en sus comentarios cuándo correr el otro.

**Las claves no van escritas en los scripts.** Al ejecutarlos, sqlplus pide la de cada usuario la primera vez que la necesita (variables `&&clave_turismouq`, `&&clave_demo_recepcion`, etc.) y la reutiliza el resto de la sesión. Elige claves propias.

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
├── 03_consultas_analisis/
│   └── 01_consultas.sql         # Las 8 consultas obligatorias de la Entrega 1
├── 04_plsql/
│   ├── 01_tipos.sql             # Tipos SQL para pasar listas de habitaciones a sp_crear_reserva
│   ├── 02_tabla_auditoria.sql   # Tabla donde el trigger de auditoría registra cambios de TARIFA
│   ├── 03_package_reservas.sql  # pkg_reservas: fn_valor_estadia, sp_crear_reserva, sp_liquidacion_mensual
│   ├── 04_triggers.sql          # Trigger de sentencia (auditoría) y de fila (anti-solape)
│   └── 05_pruebas.sql           # Script de demo/sustentación con los 7 casos de prueba
├── 05_transacciones/
│   ├── 01_pkg_transacciones.sql # sp_registrar_reserva_pago: reserva + pago atómico con SAVEPOINT
│   └── 02_pruebas_transacciones.sql # Pago exitoso vs. rollback parcial por pago insuficiente
├── 06_concurrencia/
│   ├── 01_pkg_demo_concurrencia.sql # sp_reservar_sin_lock / sp_reservar_con_lock
│   ├── 02_elegir_habitacion.sql # Elige de antemano el id_habitacion del experimento (evita depender de DBMS_OUTPUT en vivo)
│   ├── 03_sesionA_sin_lock.sql  # Experimento SIN bloqueo (reproduce doble reserva)
│   ├── 04_sesionB_sin_lock.sql
│   ├── 06_sesionA_con_lock.sql  # Mismo experimento CON SELECT...FOR UPDATE (corrige el problema)
│   ├── 07_sesionB_con_lock.sql
│   └── 08_verificar.sql         # Confirma si hubo o no doble reserva
├── 07_indices/
│   └── 01_indices.sql           # 3 consultas lentas + índices (1 compuesto, 1 función) + 1 caso donde no ayuda
└── 08_seguridad/
    ├── 01_roles_usuarios_profile.sql # 4 roles, PROFILE y usuarios demo (conectado como SYSTEM)
    ├── 02_vistas_recepcion.sql       # Vistas por las que opera recepción
    ├── 03_permisos_por_rol.sql       # GRANTs diferenciados por rol
    └── 04_pruebas_seguridad.sql      # Demo: qué puede y qué no puede hacer cada rol
```

## Estado del proyecto

- [x] Entrega 1 — Modelo, DDL, carga de datos, 8 consultas de análisis
- [x] Entrega 2 — Capa PL/SQL (`fn_valor_estadia`, `sp_crear_reserva`, cursor, paquete, triggers)
- [x] Entrega 3 — Transacciones, índices y seguridad
- [ ] Sustentación

## Nota sobre alcance

Este repositorio es el entregable **académico** (solo base de datos, sin interfaz, tal como exige el enunciado). La aplicación funcional con interfaz (React + Node/TypeScript) y la integración de pasarela de pago (Wompi sandbox) viven en un proyecto aparte: `TurismoUQ-App/`, para no mezclar el alcance calificado con el desarrollo adicional.
