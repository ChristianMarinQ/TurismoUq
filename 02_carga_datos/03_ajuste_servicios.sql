-- =====================================================================
-- TurismoUQ — 03_ajuste_servicios.sql
-- Agrega líneas a RESERVA_SERVICIO hasta superar el volumen mínimo
-- (40.000) sin rehacer toda la carga de reservas. Es seguro correrlo
-- varias veces: si ya se cumplió el mínimo, no hace nada.
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- =====================================================================

SET SERVEROUTPUT ON;

DECLARE
  v_actual NUMBER;
  v_faltan NUMBER;

  TYPE t_num IS TABLE OF NUMBER;
  v_reserva_ids     t_num;
  v_alojamiento_ids t_num;

  v_id_servicio NUMBER;
  v_precio      NUMBER;
  v_cantidad    NUMBER;
  v_idx         PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_actual FROM reserva_servicio;
  v_faltan := 41000 - v_actual; -- margen sobre el mínimo de 40.000

  IF v_faltan <= 0 THEN
    DBMS_OUTPUT.PUT_LINE('Ya hay ' || v_actual || ' líneas, no hace falta agregar más.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Hay ' || v_actual || ' líneas, agregando ' || v_faltan || ' más...');

    -- Cargar UNA sola vez la lista de reservas elegibles con su alojamiento
    -- (antes se reordenaba aleatoriamente esta consulta en cada vuelta del
    -- loop, lo cual era muy lento y mantenía transacciones abiertas más
    -- tiempo del necesario).
    SELECT r.id_reserva, h.id_alojamiento
    BULK COLLECT INTO v_reserva_ids, v_alojamiento_ids
    FROM reserva r
    JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
    JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
    WHERE r.estado IN ('CONFIRMADA','FINALIZADA');

    FOR i IN 1..v_faltan LOOP
      v_idx := TRUNC(DBMS_RANDOM.VALUE(1, v_reserva_ids.COUNT+1));

      BEGIN
        SELECT id_servicio, precio INTO v_id_servicio, v_precio
        FROM (
          SELECT id_servicio, precio FROM servicio
          WHERE id_alojamiento = v_alojamiento_ids(v_idx)
          ORDER BY DBMS_RANDOM.VALUE
        )
        WHERE ROWNUM = 1;

        v_cantidad := TRUNC(DBMS_RANDOM.VALUE(1,4));

        INSERT INTO reserva_servicio (id_reserva, id_servicio, cantidad, precio_unitario)
        VALUES (v_reserva_ids(v_idx), v_id_servicio, v_cantidad, v_precio);

        UPDATE reserva SET valor_total = valor_total + v_precio * v_cantidad
        WHERE id_reserva = v_reserva_ids(v_idx);

        IF MOD(i, 2000) = 0 THEN
          COMMIT;
          DBMS_OUTPUT.PUT_LINE('Líneas agregadas: ' || i);
        END IF;
      EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
      END;
    END LOOP;
    COMMIT;
  END IF;
END;
/

SELECT COUNT(*) AS reserva_servicio_total FROM reserva_servicio;
