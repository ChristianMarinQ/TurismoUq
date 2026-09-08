-- =====================================================================
-- SESIÓN B — experimento CON bloqueo (paso 3 de 3)
-- Ábrelo en la segunda pestaña, ya listo ANTES de correr la Sesión A.
-- En cuanto le des Aceptar al cuadro de la Sesión A, ven aquí y corre
-- este (F5) de inmediato — pega el MISMO id_habitacion.
--
-- Resultado esperado (la corrección): esta sesión se queda "pensando"
-- (el ícono de ejecución sigue girando, sin mostrar nada) porque está
-- esperando a que la Sesión A libere el bloqueo. Cuando la Sesión A
-- termine (a los 30s) y haga COMMIT, esta se libera, hace su propio
-- chequeo, YA ve la reserva de A, y la rechaza con ORA-20002.
-- Verifica con 08_verificar.sql que NO quedó doble reserva.
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
    DBMS_OUTPUT.PUT_LINE('Sesión B rechazada como se esperaba (después de esperar el bloqueo) -> ' || SQLERRM);
END;
/
