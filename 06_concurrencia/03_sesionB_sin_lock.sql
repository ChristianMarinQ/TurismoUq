-- =====================================================================
-- SESIÓN B — experimento SIN bloqueo (paso 2 de 2)
-- Ábrelo en una SEGUNDA ventana/worksheet, DISTINTA de la Sesión A, y
-- corre esto MIENTRAS la Sesión A está en su pausa de 15 segundos.
-- Al ejecutar (F5) te va a pedir el valor de "id_habitacion": pega el
-- número que imprimió la Sesión A.
--
-- Resultado esperado (el "problema"): esta sesión NO espera a la A y
-- probablemente también logra reservar la misma habitación para fechas
-- que se solapan -> doble reserva. Verifica con 06_verificar.sql.
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
END;
/
