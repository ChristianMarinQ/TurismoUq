-- =====================================================================
-- TurismoUQ — 02_pruebas_transacciones.sql (Entrega 3 · Transacciones)
-- Demo para sustentación: pago exitoso vs. pago insuficiente (rollback parcial).
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- =====================================================================

SET SERVEROUTPUT ON;

-- =====================================================================
-- CASO A: pago exitoso (monto = valor_total) -> reserva queda CONFIRMADA
-- =====================================================================
DECLARE
  v_id_reserva   NUMBER;
  v_id_cliente   NUMBER;
  v_id_hab       NUMBER;
  v_pago_exitoso VARCHAR2(1);
  v_total        NUMBER;
  v_checkin      DATE := DATE '2026-08-10';
  v_checkout     DATE := DATE '2026-08-14';
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

  v_total := pkg_reservas.fn_valor_estadia(v_id_hab, v_checkin, v_checkout);

  pkg_transacciones.sp_registrar_reserva_pago(
    p_id_cliente   => v_id_cliente,
    p_checkin      => v_checkin,
    p_checkout     => v_checkout,
    p_habitaciones => ty_tab_habitaciones(ty_item_habitacion(v_id_hab, 1)),
    p_monto_pago   => v_total,
    p_metodo_pago  => 'WOMPI',
    p_id_reserva   => v_id_reserva,
    p_pago_exitoso => v_pago_exitoso
  );

  DBMS_OUTPUT.PUT_LINE('CASO A: reserva=' || v_id_reserva || '  pago_exitoso=' || v_pago_exitoso);
END;
/

SELECT id_reserva, estado, valor_total FROM reserva
WHERE id_reserva = (SELECT MAX(id_reserva) FROM reserva);

SELECT id_pago, id_reserva, monto, estado FROM pago
WHERE id_reserva = (SELECT MAX(id_reserva) FROM reserva);

-- =====================================================================
-- CASO B: pago insuficiente -> ROLLBACK PARCIAL. La reserva debe seguir
-- existiendo en estado PENDIENTE, y NO debe quedar ninguna fila en PAGO.
-- =====================================================================
DECLARE
  v_id_reserva   NUMBER;
  v_id_cliente   NUMBER;
  v_id_hab       NUMBER;
  v_pago_exitoso VARCHAR2(1);
  v_total        NUMBER;
  v_checkin      DATE := DATE '2026-08-20';
  v_checkout     DATE := DATE '2026-08-24';
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

  v_total := pkg_reservas.fn_valor_estadia(v_id_hab, v_checkin, v_checkout);
  DBMS_OUTPUT.PUT_LINE('Valor total real de la estadía: ' || v_total || ' — se va a pagar solo la mitad a propósito.');

  pkg_transacciones.sp_registrar_reserva_pago(
    p_id_cliente   => v_id_cliente,
    p_checkin      => v_checkin,
    p_checkout     => v_checkout,
    p_habitaciones => ty_tab_habitaciones(ty_item_habitacion(v_id_hab, 1)),
    p_monto_pago   => ROUND(v_total / 2),  -- monto insuficiente a propósito
    p_metodo_pago  => 'WOMPI',
    p_id_reserva   => v_id_reserva,
    p_pago_exitoso => v_pago_exitoso
  );

  DBMS_OUTPUT.PUT_LINE('CASO B: reserva=' || v_id_reserva || '  pago_exitoso=' || v_pago_exitoso ||
                        '  (esperado: N, la reserva debe seguir existiendo en PENDIENTE)');
END;
/

-- La reserva SÍ debe aparecer (el INSERT de la reserva es anterior al SAVEPOINT)
SELECT id_reserva, estado, valor_total FROM reserva
WHERE id_reserva = (SELECT MAX(id_reserva) FROM reserva);

-- No debe existir ningún pago para esa reserva (el INSERT de pago se deshizo)
SELECT COUNT(*) AS pagos_para_esa_reserva FROM pago
WHERE id_reserva = (SELECT MAX(id_reserva) FROM reserva);
