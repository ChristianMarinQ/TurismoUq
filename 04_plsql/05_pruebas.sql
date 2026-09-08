-- =====================================================================
-- TurismoUQ — 05_pruebas.sql (Entrega 2)
-- Script de DEMOSTRACIÓN para la sustentación: no hay interfaz, así que
-- esto es lo que se muestra en vivo en SQL*Plus/SQL Developer para
-- probar cada funcionalidad de la Entrega 2.
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- =====================================================================

SET SERVEROUTPUT ON;

-- =====================================================================
-- PRUEBA 1: reserva exitosa con 2 habitaciones, en fechas que cruzan
-- tres temporadas (BAJA -> Semana Santa ALTA -> BAJA), para demostrar
-- fn_valor_estadia prorrateando por temporada (decisión de diseño 2).
-- =====================================================================
DECLARE
  v_id_reserva NUMBER;
  v_id_hab1    NUMBER;
  v_id_hab2    NUMBER;
  v_id_cliente NUMBER;
  v_checkin    DATE := DATE '2026-03-25';
  v_checkout   DATE := DATE '2026-04-08'; -- 14 noches, cruza Semana Santa 2026 (29 mar - 5 abr)
  v_valor_hab1 NUMBER;
  v_total      NUMBER;
BEGIN
  SELECT id_habitacion INTO v_id_hab1 FROM (
    SELECT h.id_habitacion FROM habitacion h
    WHERE NOT EXISTS (
      SELECT 1 FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
      WHERE rh.id_habitacion = h.id_habitacion AND r.estado IN ('PENDIENTE','CONFIRMADA')
        AND r.fecha_checkin < v_checkout AND r.fecha_checkout > v_checkin
    )
    ORDER BY DBMS_RANDOM.VALUE
  ) WHERE ROWNUM = 1;

  SELECT id_habitacion INTO v_id_hab2 FROM (
    SELECT h.id_habitacion FROM habitacion h
    WHERE h.id_habitacion != v_id_hab1
      AND NOT EXISTS (
        SELECT 1 FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
        WHERE rh.id_habitacion = h.id_habitacion AND r.estado IN ('PENDIENTE','CONFIRMADA')
          AND r.fecha_checkin < v_checkout AND r.fecha_checkout > v_checkin
      )
    ORDER BY DBMS_RANDOM.VALUE
  ) WHERE ROWNUM = 1;

  SELECT id_cliente INTO v_id_cliente FROM (SELECT id_cliente FROM cliente ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;

  v_valor_hab1 := pkg_reservas.fn_valor_estadia(v_id_hab1, v_checkin, v_checkout);
  DBMS_OUTPUT.PUT_LINE('fn_valor_estadia(habitacion=' || v_id_hab1 || ') = ' || v_valor_hab1 ||
                        ' (prorrateado entre BAJA / Semana Santa ALTA / BAJA)');

  pkg_reservas.sp_crear_reserva(
    p_id_cliente   => v_id_cliente,
    p_checkin      => v_checkin,
    p_checkout     => v_checkout,
    p_habitaciones => ty_tab_habitaciones(
                         ty_item_habitacion(v_id_hab1, 2),
                         ty_item_habitacion(v_id_hab2, 1)
                       ),
    p_id_reserva   => v_id_reserva
  );

  SELECT valor_total INTO v_total FROM reserva WHERE id_reserva = v_id_reserva;
  DBMS_OUTPUT.PUT_LINE('PRUEBA 1 OK: reserva ' || v_id_reserva || ' creada con 2 habitaciones, valor_total = ' || v_total);
END;
/

-- =====================================================================
-- PRUEBA 2: checkout <= checkin -> debe fallar con ORA-20001
-- =====================================================================
DECLARE
  v_id_reserva NUMBER;
BEGIN
  pkg_reservas.sp_crear_reserva(
    p_id_cliente   => (SELECT id_cliente FROM (SELECT id_cliente FROM cliente ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1),
    p_checkin      => DATE '2026-05-10',
    p_checkout     => DATE '2026-05-10',
    p_habitaciones => ty_tab_habitaciones(ty_item_habitacion(
                         (SELECT id_habitacion FROM (SELECT id_habitacion FROM habitacion ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1), 1)),
    p_id_reserva   => v_id_reserva
  );
  DBMS_OUTPUT.PUT_LINE('PRUEBA 2 FALLÓ: no debía dejar crear la reserva');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20001 THEN
      DBMS_OUTPUT.PUT_LINE('PRUEBA 2 OK: rechazada como se esperaba -> ' || SQLERRM);
    ELSE
      RAISE;
    END IF;
END;
/

-- =====================================================================
-- PRUEBA 3: capacidad excedida -> debe fallar con ORA-20003
-- =====================================================================
DECLARE
  v_id_reserva NUMBER;
  v_id_hab     NUMBER;
  v_capacidad  NUMBER;
BEGIN
  SELECT id_habitacion, capacidad INTO v_id_hab, v_capacidad
  FROM (SELECT id_habitacion, capacidad FROM habitacion ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;

  pkg_reservas.sp_crear_reserva(
    p_id_cliente   => (SELECT id_cliente FROM (SELECT id_cliente FROM cliente ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1),
    p_checkin      => DATE '2026-05-10',
    p_checkout     => DATE '2026-05-12',
    p_habitaciones => ty_tab_habitaciones(ty_item_habitacion(v_id_hab, v_capacidad + 5)),
    p_id_reserva   => v_id_reserva
  );
  DBMS_OUTPUT.PUT_LINE('PRUEBA 3 FALLÓ: no debía dejar crear la reserva');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20003 THEN
      DBMS_OUTPUT.PUT_LINE('PRUEBA 3 OK: rechazada como se esperaba -> ' || SQLERRM);
    ELSE
      RAISE;
    END IF;
END;
/

-- =====================================================================
-- PRUEBA 4: habitación no disponible (solapamiento) -> ORA-20002
-- Se reserva una habitación libre, y luego se intenta reservarla otra
-- vez para fechas que se cruzan con la anterior.
-- =====================================================================
DECLARE
  v_id_reserva_a NUMBER;
  v_id_reserva_b NUMBER;
  v_id_hab       NUMBER;
  v_checkin      DATE := DATE '2026-06-01';
  v_checkout     DATE := DATE '2026-06-10';
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

  pkg_reservas.sp_crear_reserva(
    p_id_cliente   => (SELECT id_cliente FROM (SELECT id_cliente FROM cliente ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1),
    p_checkin      => v_checkin,
    p_checkout     => v_checkout,
    p_habitaciones => ty_tab_habitaciones(ty_item_habitacion(v_id_hab, 1)),
    p_id_reserva   => v_id_reserva_a
  );
  DBMS_OUTPUT.PUT_LINE('Reserva A creada (' || v_id_reserva_a || ') sobre habitación ' || v_id_hab);

  BEGIN
    pkg_reservas.sp_crear_reserva(
      p_id_cliente   => (SELECT id_cliente FROM (SELECT id_cliente FROM cliente ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1),
      p_checkin      => DATE '2026-06-05', -- se cruza con la reserva A
      p_checkout     => DATE '2026-06-12',
      p_habitaciones => ty_tab_habitaciones(ty_item_habitacion(v_id_hab, 1)),
      p_id_reserva   => v_id_reserva_b
    );
    DBMS_OUTPUT.PUT_LINE('PRUEBA 4 FALLÓ: no debía dejar crear la reserva B');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20002 THEN
        DBMS_OUTPUT.PUT_LINE('PRUEBA 4 OK: rechazada como se esperaba -> ' || SQLERRM);
      ELSE
        RAISE;
      END IF;
  END;
END;
/

-- =====================================================================
-- PRUEBA 5: el trigger trg_no_solape_reserva también protege aunque se
-- inserte directo en RESERVA_HABITACION sin pasar por el paquete.
-- =====================================================================
DECLARE
  v_id_reserva_c NUMBER;
  v_id_reserva_d NUMBER;
  v_id_hab       NUMBER;
  v_id_cliente   NUMBER;
  v_checkin      DATE := DATE '2026-07-01';
  v_checkout     DATE := DATE '2026-07-05';
BEGIN
  SELECT id_habitacion INTO v_id_hab FROM (
    SELECT h.id_habitacion FROM habitacion h
    WHERE NOT EXISTS (
      SELECT 1 FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
      WHERE rh.id_habitacion = h.id_habitacion AND r.estado IN ('PENDIENTE','CONFIRMADA')
        AND r.fecha_checkin < DATE '2026-07-08' AND r.fecha_checkout > v_checkin
    )
    ORDER BY DBMS_RANDOM.VALUE
  ) WHERE ROWNUM = 1;
  SELECT id_cliente INTO v_id_cliente FROM (SELECT id_cliente FROM cliente ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;

  -- Reserva C: encabezado + línea, todo "a mano" (sin pkg_reservas)
  INSERT INTO reserva (id_cliente, fecha_checkin, fecha_checkout, estado, valor_total)
  VALUES (v_id_cliente, v_checkin, v_checkout, 'CONFIRMADA', 0)
  RETURNING id_reserva INTO v_id_reserva_c;

  INSERT INTO reserva_habitacion (id_reserva, id_habitacion, num_huespedes, valor_estadia)
  VALUES (v_id_reserva_c, v_id_hab, 1, 100000);

  DBMS_OUTPUT.PUT_LINE('Reserva C creada a mano (' || v_id_reserva_c || ') sobre habitación ' || v_id_hab);

  -- Reserva D: mismo cuarto, fechas solapadas -> el TRIGGER debe bloquear el INSERT
  INSERT INTO reserva (id_cliente, fecha_checkin, fecha_checkout, estado, valor_total)
  VALUES (v_id_cliente, DATE '2026-07-03', DATE '2026-07-06', 'CONFIRMADA', 0)
  RETURNING id_reserva INTO v_id_reserva_d;

  BEGIN
    INSERT INTO reserva_habitacion (id_reserva, id_habitacion, num_huespedes, valor_estadia)
    VALUES (v_id_reserva_d, v_id_hab, 1, 100000);
    DBMS_OUTPUT.PUT_LINE('PRUEBA 5 FALLÓ: el trigger no bloqueó el INSERT directo');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20002 THEN
        DBMS_OUTPUT.PUT_LINE('PRUEBA 5 OK: trg_no_solape_reserva bloqueó el INSERT directo -> ' || SQLERRM);
        DELETE FROM reserva WHERE id_reserva = v_id_reserva_d; -- limpiar encabezado huérfano de la prueba
      ELSE
        RAISE;
      END IF;
  END;

  COMMIT;
END;
/

-- =====================================================================
-- PRUEBA 6: trg_auditoria_tarifa — un UPDATE masivo genera un solo INSERT
-- (FORALL) con una fila de auditoría por cada tarifa modificada.
-- =====================================================================
DECLARE
  v_id_temporada NUMBER;
  v_antes        NUMBER;
BEGIN
  SELECT id_temporada INTO v_id_temporada FROM (SELECT id_temporada FROM temporada ORDER BY DBMS_RANDOM.VALUE) WHERE ROWNUM = 1;
  SELECT COUNT(*) INTO v_antes FROM auditoria_tarifa;

  UPDATE tarifa SET valor_noche = ROUND(valor_noche * 1.10, -2) WHERE id_temporada = v_id_temporada;
  DBMS_OUTPUT.PUT_LINE('UPDATE aplicado a ' || SQL%ROWCOUNT || ' tarifas de la temporada ' || v_id_temporada);

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('Filas nuevas en auditoria_tarifa: ' ||
    (SELECT COUNT(*) FROM auditoria_tarifa) - v_antes);
END;
/

SELECT * FROM auditoria_tarifa ORDER BY id_auditoria DESC FETCH FIRST 5 ROWS ONLY;

-- =====================================================================
-- PRUEBA 7: sp_liquidacion_mensual — proceso masivo con cursor explícito
-- =====================================================================
EXEC pkg_reservas.sp_liquidacion_mensual(1, 2025, 6);
