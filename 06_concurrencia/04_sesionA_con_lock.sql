-- =====================================================================
-- SESIÓN A — experimento CON bloqueo (paso 1 de 2)
-- Igual que 02_sesionA_sin_lock.sql, pero usando sp_reservar_con_lock
-- (SELECT ... FOR UPDATE). Usa una habitación y fechas distintas a las
-- del experimento anterior para no chocar con esos datos.
-- =====================================================================

SET SERVEROUTPUT ON;

DECLARE
  v_id_hab     NUMBER;
  v_id_cliente NUMBER;
  v_id_reserva NUMBER;
  v_checkin    DATE := DATE '2026-09-22';
  v_checkout   DATE := DATE '2026-09-25';
BEGIN
  SELECT id_habitacion INTO v_id_hab FROM (
    SELECT h.id_habitacion FROM habitacion h
    WHERE NOT EXISTS (
      SELECT 1 FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
      WHERE rh.id_habitacion = h.id_habitacion AND r.estado IN ('PENDIENTE','CONFIRMADA')
        AND r.fecha_checkin < v_checkout AND r.fecha_checkout > v_checkin
    )
    ORDER BY DBMS_RANDOM.VALUE
  ) WHERE ROWNUM = 1;

  SELECT id_cliente INTO v_id_cliente FROM (SELECT id_cliente FROM cliente ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;

  DBMS_OUTPUT.PUT_LINE('===================================================');
  DBMS_OUTPUT.PUT_LINE('>>> Habitación para el experimento: ' || v_id_hab);
  DBMS_OUTPUT.PUT_LINE('>>> Ve YA a la Sesión B, pega ese número cuando te lo pida, y corre 05_sesionB_con_lock.sql');
  DBMS_OUTPUT.PUT_LINE('>>> Esta vez la Sesión B debería quedarse ESPERANDO (bloqueada) hasta que esta termine.');
  DBMS_OUTPUT.PUT_LINE('===================================================');

  pkg_demo_concurrencia.sp_reservar_con_lock(
    p_id_habitacion => v_id_hab,
    p_id_cliente    => v_id_cliente,
    p_checkin       => v_checkin,
    p_checkout      => v_checkout,
    p_espera_seg    => 15,
    p_id_reserva    => v_id_reserva
  );
END;
/
