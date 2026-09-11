-- =====================================================================
-- TurismoUQ - 02_clientes_reservas.sql
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- Requiere haber corrido antes 01_datos_maestros.sql.
-- Carga: CLIENTE (3.000), RESERVA (25.000), RESERVA_HABITACION, PAGO,
--        RESERVA_SERVICIO (>=40.000), RESENA.
-- Puede tardar varios minutos: hay ~25.000 reservas con logica de
-- tarifas, pagos y servicios por fila.
-- =====================================================================

SET SERVEROUTPUT ON;

-- ---------------------------------------------------------------------
-- Funcion auxiliar de carga: mismo algoritmo que tendra fn_valor_estadia
-- en la Entrega 2 (ver docs/00_modelo_ER.md, decision de diseno 2).
-- Se llama "_seed" porque es solo para poblar datos coherentes en la
-- Entrega 1; la version oficial se construye dentro del paquete PL/SQL
-- de la Entrega 2.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_valor_estadia_seed(
  p_id_habitacion NUMBER, p_checkin DATE, p_checkout DATE
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
END fn_valor_estadia_seed;
/

-- ---------------------------------------------------------------------
-- 1. CLIENTE - 3.000 filas
-- ---------------------------------------------------------------------
DECLARE
  TYPE t_lista IS TABLE OF VARCHAR2(30);
  v_nombres t_lista := t_lista(
    'Juan','Maria','Carlos','Ana','Luis','Laura','Andres','Camila','Diego','Valentina',
    'Sergio','Daniela','Felipe','Paula','Jorge','Natalia','Miguel','Sofia','Ricardo','Alejandra',
    'David','Carolina','Julian','Manuela','Oscar','Isabella','Fernando','Gabriela','Santiago','Mariana'
  );
  v_apellidos t_lista := t_lista(
    'Gomez','Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Perez','Sanchez','Ramirez','Torres',
    'Diaz','Vargas','Castro','Ruiz','Alvarez','Romero','Suarez','Rojas','Moreno','Munoz',
    'Jimenez','Ortiz','Gil','Herrera','Medina','Aguilar','Castano','Cardona','Salazar','Zapata'
  );
  TYPE t_num IS TABLE OF NUMBER;
  TYPE t_str IS TABLE OF VARCHAR2(120);
  v_tipo_doc t_str := t_str();
  v_num_doc  t_str := t_str();
  v_nombre   t_str := t_str();
  v_apellido t_str := t_str();
  v_email    t_str := t_str();
  v_telefono t_str := t_str();
  v_fecha    t_num := t_num();
  v_n VARCHAR2(30);
  v_a VARCHAR2(30);
BEGIN
  DBMS_RANDOM.SEED(20260907);
  FOR i IN 1..3000 LOOP
    v_n := v_nombres(TRUNC(DBMS_RANDOM.VALUE(1, v_nombres.COUNT+1)));
    v_a := v_apellidos(TRUNC(DBMS_RANDOM.VALUE(1, v_apellidos.COUNT+1)));

    v_tipo_doc.EXTEND; v_tipo_doc(v_tipo_doc.LAST) := CASE WHEN DBMS_RANDOM.VALUE < 0.9 THEN 'CC' ELSE 'CE' END;
    v_num_doc.EXTEND;  v_num_doc(v_num_doc.LAST)   := TO_CHAR(1000000000 + i);
    v_nombre.EXTEND;   v_nombre(v_nombre.LAST)     := v_n;
    v_apellido.EXTEND; v_apellido(v_apellido.LAST) := v_a;
    v_email.EXTEND;    v_email(v_email.LAST)       := LOWER(v_n || '.' || v_a || i || '@correo.com');
    v_telefono.EXTEND; v_telefono(v_telefono.LAST) := '3' || TO_CHAR(TRUNC(DBMS_RANDOM.VALUE(100000000,999999999)));
  END LOOP;

  FORALL i IN 1..3000
    INSERT INTO cliente (tipo_documento, numero_documento, nombre, apellido, email, telefono, fecha_registro)
    VALUES (v_tipo_doc(i), v_num_doc(i), v_nombre(i), v_apellido(i), v_email(i), v_telefono(i),
            DATE '2023-01-01' + TRUNC(DBMS_RANDOM.VALUE(0,1000)));
  COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- 2. RESERVA + RESERVA_HABITACION + PAGO + RESERVA_SERVICIO + RESENA
--    25.000 reservas repartidas entre 2024-01-01 y 2026-11-30.
-- ---------------------------------------------------------------------
DECLARE
  v_total_alojamientos NUMBER;
  v_id_alojamiento     NUMBER;
  v_checkin            DATE;
  v_checkout           DATE;
  v_noches             NUMBER;
  v_estado             VARCHAR2(15);
  v_id_cliente         NUMBER;
  v_id_reserva         NUMBER;
  v_valor_total        NUMBER;
  v_num_habs           PLS_INTEGER;
  v_hoy                CONSTANT DATE := DATE '2026-09-07';

  TYPE t_num IS TABLE OF NUMBER;
  v_hab_ids     t_num;
  v_hab_caps    t_num;
  v_cliente_ids t_num;

  CURSOR c_rooms(p_alo NUMBER) IS
    SELECT id_habitacion, capacidad FROM habitacion
    WHERE id_alojamiento = p_alo
    ORDER BY DBMS_RANDOM.VALUE;

  v_id_servicio NUMBER;
  v_precio_serv NUMBER;
  v_num_serv_lines PLS_INTEGER;

  v_monto_pago  NUMBER;
  v_metodo      VARCHAR2(20);
  v_rand_metodo NUMBER;

  v_calificacion NUMBER;
  v_comentario   VARCHAR2(200);
  TYPE t_com IS TABLE OF VARCHAR2(200);
  v_comentarios_buenos t_com := t_com(
    'Excelente atencion y muy buena ubicacion.', 'El lugar supero nuestras expectativas.',
    'Volveriamos sin duda, muy recomendado.', 'Muy limpio y comodo, el desayuno espectacular.'
  );
  v_comentarios_medios t_com := t_com(
    'Buena estadia, aunque el servicio puede mejorar.', 'Cumplio lo esperado, nada excepcional.'
  );
  v_comentarios_malos t_com := t_com(
    'La habitacion no estaba como en las fotos.', 'Tuvimos problemas con el servicio de recepcion.'
  );
BEGIN
  DBMS_RANDOM.SEED(7);
  SELECT COUNT(*) INTO v_total_alojamientos FROM alojamiento;
  -- IDs reales de cliente (no asumir rango 1..3000: IDENTITY no se reinicia con TRUNCATE)
  SELECT id_cliente BULK COLLECT INTO v_cliente_ids FROM cliente;

  FOR i IN 1..25000 LOOP
    -- Fechas de la estadia
    v_checkin  := DATE '2024-01-01' + TRUNC(DBMS_RANDOM.VALUE(0, 1064)); -- hasta ~2026-11-30
    v_noches   := TRUNC(DBMS_RANDOM.VALUE(1,11)); -- 1..10 noches
    v_checkout := v_checkin + v_noches;

    -- Estado segun si la estadia ya paso respecto a "hoy"
    IF v_checkout < v_hoy THEN
      v_estado := CASE
        WHEN DBMS_RANDOM.VALUE < 0.75 THEN 'FINALIZADA'
        WHEN DBMS_RANDOM.VALUE < 0.90 THEN 'CANCELADA'
        ELSE 'CONFIRMADA'
      END;
    ELSE
      v_estado := CASE
        WHEN DBMS_RANDOM.VALUE < 0.55 THEN 'CONFIRMADA'
        WHEN DBMS_RANDOM.VALUE < 0.85 THEN 'PENDIENTE'
        ELSE 'CANCELADA'
      END;
    END IF;

    v_id_cliente     := v_cliente_ids(TRUNC(DBMS_RANDOM.VALUE(1, v_cliente_ids.COUNT+1)));
    v_id_alojamiento := TRUNC(DBMS_RANDOM.VALUE(1, v_total_alojamientos+1));

    INSERT INTO reserva (id_cliente, fecha_reserva, fecha_checkin, fecha_checkout, estado, valor_total)
    VALUES (v_id_cliente, v_checkin - TRUNC(DBMS_RANDOM.VALUE(1,90)), v_checkin, v_checkout, v_estado, 0)
    RETURNING id_reserva INTO v_id_reserva;

    -- Habitaciones de esa reserva (1 a 3, limitado a las que tenga el alojamiento)
    OPEN c_rooms(v_id_alojamiento);
    FETCH c_rooms BULK COLLECT INTO v_hab_ids, v_hab_caps LIMIT 3;
    CLOSE c_rooms;

    v_num_habs := LEAST(v_hab_ids.COUNT, TRUNC(DBMS_RANDOM.VALUE(1,4)));
    v_valor_total := 0;

    FOR r IN 1..v_num_habs LOOP
      DECLARE
        v_valor_estadia NUMBER;
        v_huespedes     NUMBER;
      BEGIN
        v_valor_estadia := fn_valor_estadia_seed(v_hab_ids(r), v_checkin, v_checkout);
        v_huespedes     := TRUNC(DBMS_RANDOM.VALUE(1, v_hab_caps(r)+1));

        INSERT INTO reserva_habitacion (id_reserva, id_habitacion, num_huespedes, valor_estadia)
        VALUES (v_id_reserva, v_hab_ids(r), v_huespedes, v_valor_estadia);

        v_valor_total := v_valor_total + v_valor_estadia;
      END;
    END LOOP;

    -- Servicios contratados (solo si la reserva no quedo cancelada/pendiente)
    IF v_estado IN ('CONFIRMADA','FINALIZADA') THEN
      v_num_serv_lines := TRUNC(DBMS_RANDOM.VALUE(1,4)); -- 1..3, promedio 2 -> ~40.000+ lineas en total
      FOR s IN 1..v_num_serv_lines LOOP
        BEGIN
          SELECT id_servicio, precio INTO v_id_servicio, v_precio_serv
          FROM (
            SELECT id_servicio, precio FROM servicio
            WHERE id_alojamiento = v_id_alojamiento
            ORDER BY DBMS_RANDOM.VALUE
          )
          WHERE ROWNUM = 1;

          INSERT INTO reserva_servicio (id_reserva, id_servicio, cantidad, precio_unitario)
          VALUES (v_id_reserva, v_id_servicio, TRUNC(DBMS_RANDOM.VALUE(1,4)), v_precio_serv);

          v_valor_total := v_valor_total + v_precio_serv;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN NULL; -- alojamiento sin servicios (no deberia pasar)
        END;
      END LOOP;
    END IF;

    UPDATE reserva SET valor_total = v_valor_total WHERE id_reserva = v_id_reserva;

    -- Pagos
    IF v_estado IN ('CONFIRMADA','FINALIZADA') AND v_valor_total > 0 THEN
      v_rand_metodo := DBMS_RANDOM.VALUE;
      v_metodo := CASE
        WHEN v_rand_metodo < 0.30 THEN 'WOMPI'
        WHEN v_rand_metodo < 0.55 THEN 'TARJETA'
        WHEN v_rand_metodo < 0.75 THEN 'TRANSFERENCIA'
        WHEN v_rand_metodo < 0.90 THEN 'PSE'
        ELSE 'EFECTIVO'
      END;

      IF DBMS_RANDOM.VALUE < 0.6 THEN
        INSERT INTO pago (id_reserva, fecha_pago, monto, metodo_pago, estado)
        VALUES (v_id_reserva, v_checkin - TRUNC(DBMS_RANDOM.VALUE(1,30)), v_valor_total, v_metodo, 'APROBADO');
      ELSE
        v_monto_pago := ROUND(v_valor_total * 0.4, -2);
        INSERT INTO pago (id_reserva, fecha_pago, monto, metodo_pago, estado)
        VALUES (v_id_reserva, v_checkin - TRUNC(DBMS_RANDOM.VALUE(15,60)), v_monto_pago, v_metodo, 'APROBADO');
        INSERT INTO pago (id_reserva, fecha_pago, monto, metodo_pago, estado)
        VALUES (v_id_reserva, v_checkin - TRUNC(DBMS_RANDOM.VALUE(1,10)), v_valor_total - v_monto_pago, v_metodo, 'APROBADO');
      END IF;
    ELSIF v_estado = 'CANCELADA' AND v_valor_total > 0 AND DBMS_RANDOM.VALUE < 0.2 THEN
      INSERT INTO pago (id_reserva, fecha_pago, monto, metodo_pago, estado)
      VALUES (v_id_reserva, v_checkin - TRUNC(DBMS_RANDOM.VALUE(15,60)), ROUND(v_valor_total*0.4,-2), 'WOMPI', 'REEMBOLSADO');
    END IF;

    -- Resena (solo reservas finalizadas, ~55% de probabilidad)
    IF v_estado = 'FINALIZADA' AND DBMS_RANDOM.VALUE < 0.55 THEN
      v_calificacion := CASE
        WHEN DBMS_RANDOM.VALUE < 0.6 THEN TRUNC(DBMS_RANDOM.VALUE(4,6))
        WHEN DBMS_RANDOM.VALUE < 0.9 THEN 3
        ELSE TRUNC(DBMS_RANDOM.VALUE(1,3))
      END;

      -- El comentario se resuelve en PL/SQL puro (no dentro del INSERT):
      -- el metodo .COUNT de una coleccion no es valido dentro de una
      -- expresion SQL embebida (VALUES ...), solo en codigo PL/SQL.
      IF v_calificacion >= 4 THEN
        v_comentario := v_comentarios_buenos(TRUNC(DBMS_RANDOM.VALUE(1, v_comentarios_buenos.COUNT+1)));
      ELSIF v_calificacion = 3 THEN
        v_comentario := v_comentarios_medios(TRUNC(DBMS_RANDOM.VALUE(1, v_comentarios_medios.COUNT+1)));
      ELSE
        v_comentario := v_comentarios_malos(TRUNC(DBMS_RANDOM.VALUE(1, v_comentarios_malos.COUNT+1)));
      END IF;

      INSERT INTO resena (id_cliente, id_alojamiento, id_reserva, calificacion, comentario, fecha_resena)
      VALUES (
        v_id_cliente, v_id_alojamiento, v_id_reserva, v_calificacion, v_comentario,
        v_checkout + TRUNC(DBMS_RANDOM.VALUE(1,10))
      );
    END IF;

    IF MOD(i, 1000) = 0 THEN
      COMMIT;
      DBMS_OUTPUT.PUT_LINE('Reservas cargadas: ' || i);
    END IF;
  END LOOP;

  COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- Recalcular calificacion_promedio de ALOJAMIENTO a partir de RESENA
-- (se recalculara tambien via trigger/proceso en entregas posteriores)
-- ---------------------------------------------------------------------
UPDATE alojamiento a
SET calificacion_promedio = NVL((
  SELECT ROUND(AVG(calificacion),2) FROM resena r WHERE r.id_alojamiento = a.id_alojamiento
), 0);
COMMIT;

-- ---------------------------------------------------------------------
-- Verificacion de volumen minimo
-- ---------------------------------------------------------------------
SELECT 'cliente' tabla, COUNT(*) filas FROM cliente
UNION ALL SELECT 'reserva', COUNT(*) FROM reserva
UNION ALL SELECT 'reserva_habitacion', COUNT(*) FROM reserva_habitacion
UNION ALL SELECT 'pago', COUNT(*) FROM pago
UNION ALL SELECT 'reserva_servicio', COUNT(*) FROM reserva_servicio
UNION ALL SELECT 'resena', COUNT(*) FROM resena;
