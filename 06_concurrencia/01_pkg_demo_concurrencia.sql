-- =====================================================================
-- TurismoUQ — 01_pkg_demo_concurrencia.sql (Entrega 3 · Concurrencia)
-- Paquete SOLO PARA EL EXPERIMENTO de concurrencia de la sustentación.
-- No lo usa la aplicación real (para eso está pkg_reservas.sp_crear_reserva).
--
-- Reproduce a propósito la condición de carrera clásica
-- "verificar disponibilidad, LUEGO insertar": entre el chequeo y el
-- INSERT hay una pausa (DBMS_SESSION.SLEEP) para poder correr una
-- segunda sesión en el medio, a mano, desde otra ventana.
--
-- sp_reservar_sin_lock  -> reproduce el problema (puede doble-reservar).
-- sp_reservar_con_lock  -> lo corrige con SELECT ... FOR UPDATE sobre la
--                          fila de HABITACION antes de chequear/insertar.
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- =====================================================================

CREATE OR REPLACE PACKAGE pkg_demo_concurrencia AS

  PROCEDURE sp_reservar_sin_lock(
    p_id_habitacion IN  NUMBER,
    p_id_cliente    IN  NUMBER,
    p_checkin       IN  DATE,
    p_checkout      IN  DATE,
    p_espera_seg    IN  NUMBER,
    p_id_reserva    OUT NUMBER
  );

  PROCEDURE sp_reservar_con_lock(
    p_id_habitacion IN  NUMBER,
    p_id_cliente    IN  NUMBER,
    p_checkin       IN  DATE,
    p_checkout      IN  DATE,
    p_espera_seg    IN  NUMBER,
    p_id_reserva    OUT NUMBER
  );

END pkg_demo_concurrencia;
/

CREATE OR REPLACE PACKAGE BODY pkg_demo_concurrencia AS

  PROCEDURE sp_reservar_sin_lock(
    p_id_habitacion IN  NUMBER,
    p_id_cliente    IN  NUMBER,
    p_checkin       IN  DATE,
    p_checkout      IN  DATE,
    p_espera_seg    IN  NUMBER,
    p_id_reserva    OUT NUMBER
  )
  IS
    v_conflictos NUMBER;
    v_valor      NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_conflictos
    FROM reserva_habitacion rh
    JOIN reserva r ON r.id_reserva = rh.id_reserva
    WHERE rh.id_habitacion = p_id_habitacion
      AND r.estado IN ('PENDIENTE', 'CONFIRMADA')
      AND r.fecha_checkin < p_checkout
      AND r.fecha_checkout > p_checkin;

    IF v_conflictos > 0 THEN
      RAISE_APPLICATION_ERROR(-20002,
        'Habitación ' || p_id_habitacion || ' no disponible (detectado en el chequeo, sin bloqueo).');
    END IF;

    DBMS_OUTPUT.PUT_LINE('[sin_lock] Chequeo OK. Esperando ' || p_espera_seg ||
                          's antes de insertar — corre la otra sesión AHORA.');
    DBMS_SESSION.SLEEP(p_espera_seg);

    INSERT INTO reserva (id_cliente, fecha_checkin, fecha_checkout, estado, valor_total)
    VALUES (p_id_cliente, p_checkin, p_checkout, 'CONFIRMADA', 0)
    RETURNING id_reserva INTO p_id_reserva;

    v_valor := pkg_reservas.fn_valor_estadia(p_id_habitacion, p_checkin, p_checkout);

    INSERT INTO reserva_habitacion (id_reserva, id_habitacion, num_huespedes, valor_estadia)
    VALUES (p_id_reserva, p_id_habitacion, 1, v_valor);

    UPDATE reserva SET valor_total = v_valor WHERE id_reserva = p_id_reserva;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[sin_lock] Reserva ' || p_id_reserva || ' CONFIRMADA sobre habitación ' || p_id_habitacion || '.');
  END sp_reservar_sin_lock;


  PROCEDURE sp_reservar_con_lock(
    p_id_habitacion IN  NUMBER,
    p_id_cliente    IN  NUMBER,
    p_checkin       IN  DATE,
    p_checkout      IN  DATE,
    p_espera_seg    IN  NUMBER,
    p_id_reserva    OUT NUMBER
  )
  IS
    v_dummy      NUMBER;
    v_conflictos NUMBER;
    v_valor      NUMBER;
  BEGIN
    DBMS_OUTPUT.PUT_LINE('[con_lock] Bloqueando habitación ' || p_id_habitacion || ' con SELECT ... FOR UPDATE...');
    SELECT id_habitacion INTO v_dummy FROM habitacion WHERE id_habitacion = p_id_habitacion FOR UPDATE;

    DBMS_OUTPUT.PUT_LINE('[con_lock] Bloqueo obtenido. Esperando ' || p_espera_seg ||
                          's — si corres la otra sesión ahora, debería quedarse esperando.');
    DBMS_SESSION.SLEEP(p_espera_seg);

    SELECT COUNT(*) INTO v_conflictos
    FROM reserva_habitacion rh
    JOIN reserva r ON r.id_reserva = rh.id_reserva
    WHERE rh.id_habitacion = p_id_habitacion
      AND r.estado IN ('PENDIENTE', 'CONFIRMADA')
      AND r.fecha_checkin < p_checkout
      AND r.fecha_checkout > p_checkin;

    IF v_conflictos > 0 THEN
      RAISE_APPLICATION_ERROR(-20002,
        'Habitación ' || p_id_habitacion || ' no disponible (detectado con el bloqueo activo).');
    END IF;

    INSERT INTO reserva (id_cliente, fecha_checkin, fecha_checkout, estado, valor_total)
    VALUES (p_id_cliente, p_checkin, p_checkout, 'CONFIRMADA', 0)
    RETURNING id_reserva INTO p_id_reserva;

    v_valor := pkg_reservas.fn_valor_estadia(p_id_habitacion, p_checkin, p_checkout);

    INSERT INTO reserva_habitacion (id_reserva, id_habitacion, num_huespedes, valor_estadia)
    VALUES (p_id_reserva, p_id_habitacion, 1, v_valor);

    UPDATE reserva SET valor_total = v_valor WHERE id_reserva = p_id_reserva;

    COMMIT; -- libera el bloqueo sobre HABITACION
    DBMS_OUTPUT.PUT_LINE('[con_lock] Reserva ' || p_id_reserva || ' CONFIRMADA sobre habitación ' || p_id_habitacion || '. Bloqueo liberado.');
  END sp_reservar_con_lock;

END pkg_demo_concurrencia;
/
