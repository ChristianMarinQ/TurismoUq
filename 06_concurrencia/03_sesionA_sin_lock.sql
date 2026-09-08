-- =====================================================================
-- SESIÓN A — experimento SIN bloqueo (paso 2 de 3)
-- Antes de esto, corre 02_elegir_habitacion.sql (checkin=2026-09-15,
-- checkout=2026-09-18) y anota un ID_HABITACION del resultado.
--
-- Ábrelo en una PRIMERA pestaña de SQL Developer conectada a TurismoUQ.
-- Al ejecutar (F5) te va a pedir "id_habitacion": pega el número que
-- anotaste. NO esperes a ver ningún mensaje de esta sesión — apenas le
-- des Aceptar al cuadro, cambia de inmediato a la Sesión B y córrela
-- también (tienes 30 segundos de margen, corriendo por detrás en el
-- servidor aunque esta pantalla no muestre nada todavía).
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
    p_checkin       => DATE '2026-09-15',
    p_checkout      => DATE '2026-09-18',
    p_espera_seg    => 30,
    p_id_reserva    => v_id_reserva
  );
END;
/
