-- =====================================================================
-- SESIÓN A — experimento CON bloqueo (paso 2 de 3)
-- Antes de esto, corre 02_elegir_habitacion.sql con checkin=2026-09-22,
-- checkout=2026-09-25, y anota un ID_HABITACION distinto al usado en el
-- experimento anterior (para no chocar con esos datos).
--
-- Igual que la Sesión A sin bloqueo: pega el id_habitacion, dale
-- Aceptar, y SIN ESPERAR NADA cambia a la Sesión B y córrela también.
-- Esta vez la Sesión B debería quedarse "colgada" (bloqueada) hasta que
-- esta sesión termine.
-- =====================================================================

SET SERVEROUTPUT ON;

DECLARE
  v_id_cliente NUMBER;
  v_id_reserva NUMBER;
BEGIN
  SELECT id_cliente INTO v_id_cliente FROM (SELECT id_cliente FROM cliente ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;

  pkg_demo_concurrencia.sp_reservar_con_lock(
    p_id_habitacion => &id_habitacion,
    p_id_cliente    => v_id_cliente,
    p_checkin       => DATE '2026-09-22',
    p_checkout      => DATE '2026-09-25',
    p_espera_seg    => 30,
    p_id_reserva    => v_id_reserva
  );
END;
/
