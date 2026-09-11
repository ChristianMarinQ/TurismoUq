-- =====================================================================
-- SESION B - experimento CON bloqueo (paso 3 de 3)
-- Abrelo en la segunda pestana, ya listo ANTES de correr la Sesion A.
-- En cuanto le des Aceptar al cuadro de la Sesion A, ven aqui y corre
-- este (F5) de inmediato - pega el MISMO id_habitacion.
--
-- Resultado esperado (la correccion): esta sesion se queda "pensando"
-- (el icono de ejecucion sigue girando, sin mostrar nada) porque esta
-- esperando a que la Sesion A libere el bloqueo. Cuando la Sesion A
-- termine (a los 30s) y haga COMMIT, esta se libera, hace su propio
-- chequeo, YA ve la reserva de A, y la rechaza con ORA-20002.
-- Verifica con 08_verificar.sql que NO quedo doble reserva.
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
    p_checkin       => DATE '2026-09-23', -- se solapa a proposito con la Sesion A
    p_checkout      => DATE '2026-09-26',
    p_espera_seg    => 0,
    p_id_reserva    => v_id_reserva
  );
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Sesion B rechazada como se esperaba (despues de esperar el bloqueo) -> ' || SQLERRM);
END;
/
