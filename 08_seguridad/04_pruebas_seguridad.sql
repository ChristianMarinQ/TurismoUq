-- =====================================================================
-- TurismoUQ — 04_pruebas_seguridad.sql (Entrega 3 · Seguridad)
-- Demo para sustentación: se conecta como cada usuario de prueba y se
-- comprueba qué puede y qué NO puede hacer. Los errores marcados como
-- "debe fallar" son el resultado ESPERADO (prueban que el permiso no
-- se concedió), no un bug.
-- Correr como un solo script (usa CONNECT para cambiar de usuario).
-- =====================================================================

SET SERVEROUTPUT ON;

PROMPT ===================================================
PROMPT ROL_RECEPCION — solo vistas + el paquete pkg_reservas
PROMPT ===================================================
CONNECT demo_recepcion/&&clave_demo_recepcion@//localhost:1521/XEPDB1

-- Debe FUNCIONAR: accede por vista.
SELECT * FROM v_disponibilidad_habitaciones FETCH FIRST 3 ROWS ONLY;

-- Debe FALLAR con ORA-00942 (tabla o vista no existe): no tiene ningún
-- privilegio directo sobre la tabla RESERVA, solo sobre las vistas.
SELECT * FROM reserva FETCH FIRST 3 ROWS ONLY;

-- Debe FUNCIONAR: crear una reserva a través del paquete (que corre con
-- los privilegios de turismouq, su dueño) sí está permitido.
DECLARE
  v_id_hab NUMBER;
  v_id_cliente NUMBER;
  v_id_reserva NUMBER;
BEGIN
  SELECT id_habitacion INTO v_id_hab FROM v_disponibilidad_habitaciones FETCH FIRST 1 ROWS ONLY;
  -- (usa v_clientes_directorio en vez de CLIENTE directo)
  SELECT id_cliente INTO v_id_cliente FROM v_clientes_directorio FETCH FIRST 1 ROWS ONLY;

  pkg_reservas.sp_crear_reserva(
    p_id_cliente   => v_id_cliente,
    p_checkin      => DATE '2026-10-05',
    p_checkout     => DATE '2026-10-07',
    p_habitaciones => ty_tab_habitaciones(ty_item_habitacion(v_id_hab, 1)),
    p_id_reserva   => v_id_reserva
  );
  DBMS_OUTPUT.PUT_LINE('Recepción creó la reserva ' || v_id_reserva || ' sin tocar tablas directamente.');
END;
/

PROMPT ===================================================
PROMPT ROL_ADMIN_ALOJAMIENTO — catálogo de su alojamiento
PROMPT ===================================================
CONNECT demo_admin_alojamiento/&&clave_demo_admin_alojamiento@//localhost:1521/XEPDB1

-- Debe FUNCIONAR: gestiona el catálogo operativo.
UPDATE habitacion SET estado = 'MANTENIMIENTO' WHERE id_habitacion = (SELECT MIN(id_habitacion) FROM habitacion);
ROLLBACK; -- solo era para probar el permiso, no dejamos el cambio

-- Debe FALLAR con ORA-00942: no tiene permisos sobre PAGO.
SELECT * FROM pago FETCH FIRST 3 ROWS ONLY;

PROMPT ===================================================
PROMPT ROL_GERENTE — lectura amplia, sin escritura
PROMPT ===================================================
CONNECT demo_gerente/&&clave_demo_gerente@//localhost:1521/XEPDB1

-- Debe FUNCIONAR: lectura de cualquier tabla de negocio.
SELECT COUNT(*) FROM pago;

-- Debe FALLAR con ORA-01031 (privilegios insuficientes): solo tiene SELECT.
UPDATE alojamiento SET estado = 'INACTIVO' WHERE id_alojamiento = 1;

PROMPT ===================================================
PROMPT ROL_AUDITOR — lectura total, incluida seguridad/auditoría
PROMPT ===================================================
CONNECT demo_auditor/&&clave_demo_auditor@//localhost:1521/XEPDB1

-- Debe FUNCIONAR: puede ver hasta las tablas de seguridad.
SELECT username, rol FROM usuario_sistema FETCH FIRST 3 ROWS ONLY;
SELECT COUNT(*) FROM auditoria_tarifa;

-- Debe FALLAR (no se le dio EXECUTE sobre el paquete): un auditor observa, no opera.
EXEC pkg_reservas.sp_liquidacion_mensual(1, 2025, 6);

PROMPT ===================================================
PROMPT Volviendo a conectar como turismouq
PROMPT ===================================================
CONNECT turismouq/&&clave_turismouq@//localhost:1521/XEPDB1
