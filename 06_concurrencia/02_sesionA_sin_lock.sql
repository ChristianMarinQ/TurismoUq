-- =====================================================================
-- SESIÓN A — experimento SIN bloqueo (paso 1 de 2)
-- Ábrelo en una PRIMERA ventana/worksheet de SQL Developer, conectado a
-- TurismoUQ, y ejecútalo (F5). Va a imprimir el ID de una habitación
-- libre y luego esperar 15 segundos: en ese lapso, corre
-- 03_sesionB_sin_lock.sql en una SEGUNDA ventana, pegando ese mismo ID.
-- =====================================================================

SET SERVEROUTPUT ON;

DECLARE
  v_id_hab     NUMBER;
  v_id_cliente NUMBER;
  v_id_reserva NUMBER;
  v_checkin    DATE := DATE '2026-09-15';
  v_checkout   DATE := DATE '2026-09-18';
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
  DBMS_OUTPUT.PUT_LINE('>>> Ve YA a la Sesión B, pega ese número cuando te lo pida, y corre 03_sesionB_sin_lock.sql');
  DBMS_OUTPUT.PUT_LINE('===================================================');

  pkg_demo_concurrencia.sp_reservar_sin_lock(
    p_id_habitacion => v_id_hab,
    p_id_cliente    => v_id_cliente,
    p_checkin       => v_checkin,
    p_checkout      => v_checkout,
    p_espera_seg    => 15,
    p_id_reserva    => v_id_reserva
  );
END;
/
