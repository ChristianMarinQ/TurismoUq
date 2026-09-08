-- =====================================================================
-- TurismoUQ — 03_permisos_por_rol.sql (Entrega 3 · Seguridad)
-- Otorga los privilegios de cada rol. Se ejecuta conectado como
-- turismouq (dueño de las tablas/vistas/paquetes) — cualquier dueño de
-- objeto puede otorgar privilegios sobre lo que le pertenece a un rol,
-- sin necesitar privilegios de sistema adicionales.
-- Requiere haber corrido antes 01_roles_usuarios_profile.sql (como
-- system) y 02_vistas_recepcion.sql (como turismouq).
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- =====================================================================

-- ---------------------------------------------------------------------
-- ROL_RECEPCION: opera SOLO a través de vistas y del paquete
-- pkg_reservas (que corre con privilegios del dueño, turismouq). Nunca
-- recibe SELECT/INSERT/UPDATE directo sobre las tablas base — así, aunque
-- alguien con este rol intente "SELECT * FROM reserva", Oracle se lo
-- niega (ORA-00942), y solo puede leer lo que exponen las vistas y
-- escribir reservas a través de sp_crear_reserva (que sí valida reglas
-- de negocio: fechas, disponibilidad, capacidad).
-- ---------------------------------------------------------------------
GRANT SELECT ON v_disponibilidad_habitaciones TO rol_recepcion;
GRANT SELECT ON v_reservas_activas            TO rol_recepcion;
GRANT SELECT ON v_clientes_directorio         TO rol_recepcion;
GRANT EXECUTE ON pkg_reservas                 TO rol_recepcion;

-- ---------------------------------------------------------------------
-- ROL_ADMIN_ALOJAMIENTO: administra el catálogo operativo (habitaciones,
-- tarifas, servicios de su(s) alojamiento(s)) y consulta reservas para
-- saber qué está pasando en su propiedad. No toca pagos ni usuarios del
-- sistema. (Restringir esto a "solo su propio alojamiento" requeriría
-- Virtual Private Database/contexto de aplicación — queda como mejora
-- futura, fuera del alcance de esta entrega.)
-- ---------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE         ON alojamiento TO rol_admin_alojamiento;
GRANT SELECT, INSERT, UPDATE, DELETE ON habitacion  TO rol_admin_alojamiento;
GRANT SELECT, INSERT, UPDATE, DELETE ON tarifa      TO rol_admin_alojamiento;
GRANT SELECT, INSERT, UPDATE, DELETE ON servicio    TO rol_admin_alojamiento;
GRANT SELECT ON reserva            TO rol_admin_alojamiento;
GRANT SELECT ON reserva_habitacion TO rol_admin_alojamiento;
GRANT SELECT ON resena             TO rol_admin_alojamiento;

-- ---------------------------------------------------------------------
-- ROL_GERENTE: lectura amplia para reportes y toma de decisiones +
-- ejecutar las funciones/procedimientos de consulta (liquidación
-- mensual). Nunca inserta/actualiza/borra directamente.
-- ---------------------------------------------------------------------
GRANT SELECT ON municipio          TO rol_gerente;
GRANT SELECT ON tipo_alojamiento   TO rol_gerente;
GRANT SELECT ON alojamiento        TO rol_gerente;
GRANT SELECT ON habitacion         TO rol_gerente;
GRANT SELECT ON temporada          TO rol_gerente;
GRANT SELECT ON tarifa             TO rol_gerente;
GRANT SELECT ON cliente            TO rol_gerente;
GRANT SELECT ON reserva            TO rol_gerente;
GRANT SELECT ON reserva_habitacion TO rol_gerente;
GRANT SELECT ON pago               TO rol_gerente;
GRANT SELECT ON servicio           TO rol_gerente;
GRANT SELECT ON reserva_servicio   TO rol_gerente;
GRANT SELECT ON resena             TO rol_gerente;
GRANT SELECT ON mv_ocupacion_mensual TO rol_gerente;
GRANT EXECUTE ON pkg_reservas      TO rol_gerente;

-- ---------------------------------------------------------------------
-- ROL_AUDITOR: lectura total, incluyendo lo que ni gerencia ni
-- recepción deberían ver (usuarios del sistema, auditoría de tarifas).
-- Estrictamente de solo lectura: no se le da EXECUTE sobre ningún
-- paquete, porque un auditor observa, no opera.
-- ---------------------------------------------------------------------
GRANT SELECT ON municipio          TO rol_auditor;
GRANT SELECT ON tipo_alojamiento   TO rol_auditor;
GRANT SELECT ON alojamiento        TO rol_auditor;
GRANT SELECT ON habitacion         TO rol_auditor;
GRANT SELECT ON temporada          TO rol_auditor;
GRANT SELECT ON tarifa             TO rol_auditor;
GRANT SELECT ON cliente            TO rol_auditor;
GRANT SELECT ON reserva            TO rol_auditor;
GRANT SELECT ON reserva_habitacion TO rol_auditor;
GRANT SELECT ON pago               TO rol_auditor;
GRANT SELECT ON servicio           TO rol_auditor;
GRANT SELECT ON reserva_servicio   TO rol_auditor;
GRANT SELECT ON resena             TO rol_auditor;
GRANT SELECT ON usuario_sistema    TO rol_auditor;
GRANT SELECT ON auditoria_tarifa   TO rol_auditor;
