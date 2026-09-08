-- =====================================================================
-- SESIÓN B — experimento CON bloqueo (paso 2 de 2)
-- Corre esto en la segunda ventana MIENTRAS la Sesión A está en su
-- pausa de 15 segundos. Te va a pedir "id_habitacion": pega el número
-- que imprimió la Sesión A.
--
-- Resultado esperado (la corrección): esta sesión se queda "colgada"
-- (sin responder) en el SELECT ... FOR UPDATE hasta que la Sesión A
-- hace COMMIT. En ese momento se libera, esta sesión hace su propio
-- chequeo, YA ve la reserva de A, y rechaza la suya con ORA-20002.
-- Verifica con 06_verificar.sql que NO quedó doble reserva.
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
    p_checkin       => DATE '2026-09-23', -- se solapa a propósito con la Sesión A
    p_checkout      => DATE '2026-09-26',
    p_espera_seg    => 0,
    p_id_reserva    => v_id_reserva
  );
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Sesión B rechazada como se esperaba -> ' || SQLERRM);
END;
/
