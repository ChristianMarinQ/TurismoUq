-- =====================================================================
-- SESIÓN B — experimento SIN bloqueo (paso 3 de 3)
-- Ábrelo en una SEGUNDA pestaña, ya lista ANTES de correr la Sesión A.
-- En cuanto le des Aceptar al cuadro de la Sesión A, ven aquí y corre
-- este (F5) de inmediato — pega el MISMO id_habitacion.
--
-- Resultado esperado (el "problema"): esta sesión no espera a la A y
-- logra reservar la misma habitación para fechas que se solapan ->
-- doble reserva. Verifica con 08_verificar.sql.
-- =====================================================================

SET SERVEROUTPUT ON;

DECLARE
  v_id_cliente NUMBER;
  v_id_reserva NUMBER;
BEGIN
  SELECT id_cliente INTO v_id_cliente FROM (SELECT id_cliente FROM cliente ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;

  pkg_demo_concurrencia.sp_reservar_sin_lock(
    p_id_habitacion => &id_habitacion,
    p_id_cliente    => v_id_cliente,
    p_checkin       => DATE '2026-09-16', -- se solapa a propósito con la Sesión A
    p_checkout      => DATE '2026-09-19',
    p_espera_seg    => 0,
    p_id_reserva    => v_id_reserva
  );
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Sesión B rechazada -> ' || SQLERRM ||
      ' (si esto pasó, NO hubo condición de carrera esta vez: la Sesión A ya había confirmado antes de que B llegara al chequeo)');
END;
/
