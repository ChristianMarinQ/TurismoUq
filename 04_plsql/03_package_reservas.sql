-- =====================================================================
-- TurismoUQ - 03_package_reservas.sql (Entrega 2)
-- Paquete pkg_reservas: fn_valor_estadia, sp_crear_reserva y
-- sp_liquidacion_mensual (con cursor explicito parametrizado).
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- Requiere haber corrido antes 01_tipos.sql y 02_tabla_auditoria.sql.
-- =====================================================================

CREATE OR REPLACE PACKAGE pkg_reservas AS

  -- Calcula el valor de una estadia prorrateando por cada temporada que
  -- atraviese el rango [p_checkin, p_checkout). Ver docs/00_modelo_ER.md,
  -- decision de diseno 2, para el algoritmo.
  FUNCTION fn_valor_estadia(
    p_id_habitacion IN NUMBER,
    p_checkin       IN DATE,
    p_checkout      IN DATE
  ) RETURN NUMBER;

  -- Crea una reserva con una o varias habitaciones (decision de diseno 1).
  -- Lanza excepciones propias via RAISE_APPLICATION_ERROR:
  --   -20001  checkout <= checkin
  --   -20002  habitacion no disponible en esas fechas (solapamiento)
  --   -20003  capacidad de la habitacion excedida
  --   -20004  no se indico ninguna habitacion
  PROCEDURE sp_crear_reserva(
    p_id_cliente    IN  NUMBER,
    p_checkin       IN  DATE,
    p_checkout      IN  DATE,
    p_habitaciones  IN  ty_tab_habitaciones,
    p_id_reserva    OUT NUMBER
  );

  -- Proceso masivo: liquidacion (resumen de ingresos) de un alojamiento
  -- para un mes/ano dado, recorriendo sus reservas FINALIZADAS con un
  -- cursor explicito parametrizado. Imprime el detalle con DBMS_OUTPUT.
  PROCEDURE sp_liquidacion_mensual(
    p_id_alojamiento IN NUMBER,
    p_anio           IN NUMBER,
    p_mes            IN NUMBER
  );

END pkg_reservas;
/

CREATE OR REPLACE PACKAGE BODY pkg_reservas AS

  FUNCTION fn_valor_estadia(
    p_id_habitacion IN NUMBER,
    p_checkin       IN DATE,
    p_checkout      IN DATE
  ) RETURN NUMBER
  IS
    v_total NUMBER := 0;
  BEGIN
    SELECT NVL(SUM(
             (LEAST(p_checkout, t.fecha_fin + 1) - GREATEST(p_checkin, t.fecha_inicio)) * tar.valor_noche
           ), 0)
    INTO v_total
    FROM temporada t
    JOIN tarifa tar ON tar.id_temporada = t.id_temporada AND tar.id_habitacion = p_id_habitacion
    WHERE t.fecha_inicio < p_checkout
      AND t.fecha_fin   >= p_checkin;

    RETURN v_total;
  END fn_valor_estadia;


  PROCEDURE sp_crear_reserva(
    p_id_cliente    IN  NUMBER,
    p_checkin       IN  DATE,
    p_checkout      IN  DATE,
    p_habitaciones  IN  ty_tab_habitaciones,
    p_id_reserva    OUT NUMBER
  )
  IS
    v_capacidad   NUMBER;
    v_conflictos  NUMBER;
    v_valor       NUMBER;
    v_total       NUMBER := 0;
  BEGIN
    IF p_checkout <= p_checkin THEN
      RAISE_APPLICATION_ERROR(-20001, 'La fecha de checkout debe ser posterior a la de checkin.');
    END IF;

    IF p_habitaciones IS NULL OR p_habitaciones.COUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20004, 'La reserva debe incluir al menos una habitacion.');
    END IF;

    -- Fase 1: validar TODAS las habitaciones antes de escribir nada,
    -- para no dejar una reserva a medias si alguna falla.
    FOR i IN 1..p_habitaciones.COUNT LOOP
      SELECT capacidad INTO v_capacidad
      FROM habitacion
      WHERE id_habitacion = p_habitaciones(i).id_habitacion;

      IF p_habitaciones(i).num_huespedes > v_capacidad THEN
        RAISE_APPLICATION_ERROR(-20003,
          'La habitacion ' || p_habitaciones(i).id_habitacion ||
          ' tiene capacidad ' || v_capacidad || ' y se pidieron ' ||
          p_habitaciones(i).num_huespedes || ' huespedes.');
      END IF;

      SELECT COUNT(*) INTO v_conflictos
      FROM reserva_habitacion rh
      JOIN reserva r ON r.id_reserva = rh.id_reserva
      WHERE rh.id_habitacion = p_habitaciones(i).id_habitacion
        AND r.estado IN ('PENDIENTE', 'CONFIRMADA')
        AND r.fecha_checkin < p_checkout
        AND r.fecha_checkout > p_checkin;

      IF v_conflictos > 0 THEN
        RAISE_APPLICATION_ERROR(-20002,
          'La habitacion ' || p_habitaciones(i).id_habitacion ||
          ' no esta disponible entre ' || TO_CHAR(p_checkin, 'YYYY-MM-DD') ||
          ' y ' || TO_CHAR(p_checkout, 'YYYY-MM-DD') || '.');
      END IF;
    END LOOP;

    -- Fase 2: ya validado todo, se escribe la reserva.
    INSERT INTO reserva (id_cliente, fecha_checkin, fecha_checkout, estado, valor_total)
    VALUES (p_id_cliente, p_checkin, p_checkout, 'CONFIRMADA', 0)
    RETURNING id_reserva INTO p_id_reserva;

    FOR i IN 1..p_habitaciones.COUNT LOOP
      v_valor := fn_valor_estadia(p_habitaciones(i).id_habitacion, p_checkin, p_checkout);

      INSERT INTO reserva_habitacion (id_reserva, id_habitacion, num_huespedes, valor_estadia)
      VALUES (p_id_reserva, p_habitaciones(i).id_habitacion, p_habitaciones(i).num_huespedes, v_valor);

      v_total := v_total + v_valor;
    END LOOP;

    UPDATE reserva SET valor_total = v_total WHERE id_reserva = p_id_reserva;
  END sp_crear_reserva;


  PROCEDURE sp_liquidacion_mensual(
    p_id_alojamiento IN NUMBER,
    p_anio           IN NUMBER,
    p_mes            IN NUMBER
  )
  IS
    -- Cursor explicito con parametros: recorre las reservas FINALIZADAS
    -- de un alojamiento durante un mes/ano dado.
    CURSOR c_reservas_mes(p_id_alojamiento NUMBER, p_anio NUMBER, p_mes NUMBER) IS
      SELECT r.id_reserva, r.fecha_checkin, r.fecha_checkout, r.valor_total
      FROM reserva r
      WHERE r.estado = 'FINALIZADA'
        AND EXTRACT(YEAR FROM r.fecha_checkin) = p_anio
        AND EXTRACT(MONTH FROM r.fecha_checkin) = p_mes
        AND EXISTS (
          SELECT 1
          FROM reserva_habitacion rh
          JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
          WHERE rh.id_reserva = r.id_reserva
            AND h.id_alojamiento = p_id_alojamiento
        );

    v_num_reservas   NUMBER := 0;
    v_total_ingresos NUMBER := 0;
    v_nombre_alojam  alojamiento.nombre%TYPE;
  BEGIN
    SELECT nombre INTO v_nombre_alojam FROM alojamiento WHERE id_alojamiento = p_id_alojamiento;

    DBMS_OUTPUT.PUT_LINE('=== Liquidacion ' || p_mes || '/' || p_anio || ' - ' || v_nombre_alojam || ' ===');

    FOR r IN c_reservas_mes(p_id_alojamiento, p_anio, p_mes) LOOP
      DBMS_OUTPUT.PUT_LINE(
        '  Reserva ' || r.id_reserva ||
        '  checkin=' || TO_CHAR(r.fecha_checkin, 'YYYY-MM-DD') ||
        '  checkout=' || TO_CHAR(r.fecha_checkout, 'YYYY-MM-DD') ||
        '  valor=' || TO_CHAR(r.valor_total, '999,999,999')
      );
      v_num_reservas   := v_num_reservas + 1;
      v_total_ingresos := v_total_ingresos + r.valor_total;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--- Total: ' || v_num_reservas || ' reservas, ingresos = ' ||
                          TO_CHAR(v_total_ingresos, '999,999,999') || ' ---');
  END sp_liquidacion_mensual;

END pkg_reservas;
/
