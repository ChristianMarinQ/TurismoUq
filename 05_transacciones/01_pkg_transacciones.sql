-- =====================================================================
-- TurismoUQ - 01_pkg_transacciones.sql (Entrega 3 - Transacciones)
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- Requiere Entrega 2 (pkg_reservas, tipos ty_item_habitacion/ty_tab_habitaciones).
-- =====================================================================

CREATE OR REPLACE PACKAGE pkg_transacciones AS

  -- Registra una reserva y su pago de forma atomica:
  --   1) Crea la reserva (estado PENDIENTE) y sus lineas de habitacion.
  --   2) SAVEPOINT.
  --   3) Intenta registrar el pago y confirmar la reserva.
  --   4) Si el pago falla (monto insuficiente, etc.), hace ROLLBACK TO
  --      SAVEPOINT: deshace SOLO el intento de pago, la reserva queda
  --      creada y en PENDIENTE (no se pierde la reserva por un pago malo).
  -- p_pago_exitoso queda en 'S' o 'N' para que el llamador sepa que paso.
  PROCEDURE sp_registrar_reserva_pago(
    p_id_cliente    IN  NUMBER,
    p_checkin       IN  DATE,
    p_checkout      IN  DATE,
    p_habitaciones  IN  ty_tab_habitaciones,
    p_monto_pago    IN  NUMBER,
    p_metodo_pago   IN  VARCHAR2,
    p_id_reserva    OUT NUMBER,
    p_pago_exitoso  OUT VARCHAR2
  );

END pkg_transacciones;
/

CREATE OR REPLACE PACKAGE BODY pkg_transacciones AS

  PROCEDURE sp_registrar_reserva_pago(
    p_id_cliente    IN  NUMBER,
    p_checkin       IN  DATE,
    p_checkout      IN  DATE,
    p_habitaciones  IN  ty_tab_habitaciones,
    p_monto_pago    IN  NUMBER,
    p_metodo_pago   IN  VARCHAR2,
    p_id_reserva    OUT NUMBER,
    p_pago_exitoso  OUT VARCHAR2
  )
  IS
    v_total NUMBER;
  BEGIN
    -- Paso 1: crear la reserva (reutiliza toda la validacion de la Entrega 2:
    -- fechas, capacidad, disponibilidad). Si esto falla, no hay nada que
    -- deshacer todavia (sp_crear_reserva no escribe nada si algo es invalido).
    pkg_reservas.sp_crear_reserva(
      p_id_cliente   => p_id_cliente,
      p_checkin      => p_checkin,
      p_checkout     => p_checkout,
      p_habitaciones => p_habitaciones,
      p_id_reserva   => p_id_reserva
    );

    -- sp_crear_reserva deja la reserva en CONFIRMADA; para este flujo
    -- (reserva + pago atomico) la bajamos a PENDIENTE hasta que el pago
    -- se confirme.
    UPDATE reserva SET estado = 'PENDIENTE' WHERE id_reserva = p_id_reserva;
    SELECT valor_total INTO v_total FROM reserva WHERE id_reserva = p_id_reserva;

    -- Paso 2: punto de control. Todo lo anterior (reserva + habitaciones)
    -- se conserva pase lo que pase con el pago.
    SAVEPOINT sp_despues_reserva;

    BEGIN
      IF p_monto_pago < v_total THEN
        RAISE_APPLICATION_ERROR(-20005,
          'Monto insuficiente: se requieren ' || v_total || ' y se recibieron ' || p_monto_pago || '.');
      END IF;

      INSERT INTO pago (id_reserva, monto, metodo_pago, estado)
      VALUES (p_id_reserva, p_monto_pago, p_metodo_pago, 'APROBADO');

      UPDATE reserva SET estado = 'CONFIRMADA' WHERE id_reserva = p_id_reserva;

      p_pago_exitoso := 'S';
    EXCEPTION
      WHEN OTHERS THEN
        -- Rollback PARCIAL: deshace el intento de pago (y el UPDATE de
        -- estado si alcanzo a correr), pero NO la reserva del paso 1,
        -- que sigue viva desde antes del SAVEPOINT.
        ROLLBACK TO sp_despues_reserva;
        p_pago_exitoso := 'N';
    END;

    COMMIT;
  END sp_registrar_reserva_pago;

END pkg_transacciones;
/
