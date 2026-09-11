-- =====================================================================
-- TurismoUQ - 04_triggers.sql (Entrega 2)
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- Requiere haber corrido antes 02_tabla_auditoria.sql.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Disparador a NIVEL DE SENTENCIA: auditoria de cambios sobre TARIFA.
--
-- Un trigger de sentencia "puro" (sin FOR EACH ROW) no puede leer
-- :OLD/:NEW porque no se ejecuta por fila. Para cumplir "a nivel de
-- sentencia" y aun asi registrar el valor anterior/nuevo de CADA fila
-- modificada, se usa un COMPOUND TRIGGER: la seccion BEFORE EACH ROW solo
-- acumula los cambios en una coleccion PL/SQL (no escribe nada en la BD),
-- y la seccion AFTER STATEMENT hace UN SOLO INSERT masivo (FORALL) al
-- terminar la sentencia completa.
--
-- Por que importa que sea a nivel de sentencia y no fila por fila: si el
-- gerente actualiza el precio de 400 habitaciones de golpe
-- (UPDATE tarifa SET valor_noche = valor_noche * 1.1 WHERE ...), un
-- trigger de fila haria 400 INSERT individuales a auditoria_tarifa; este
-- hace 1 solo INSERT con las 400 filas, mas eficiente y sin el riesgo de
-- "tabla en mutacion" (ORA-04091) que apareceria si esa logica intentara
-- leer/agregar sobre la propia TARIFA fila por fila.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_auditoria_tarifa
FOR UPDATE OF valor_noche ON tarifa
COMPOUND TRIGGER

  TYPE t_cambio IS RECORD (
    id_tarifa      tarifa.id_tarifa%TYPE,
    valor_anterior tarifa.valor_noche%TYPE,
    valor_nuevo    tarifa.valor_noche%TYPE
  );
  TYPE t_cambios IS TABLE OF t_cambio INDEX BY PLS_INTEGER;
  v_cambios t_cambios;

  BEFORE EACH ROW IS
  BEGIN
    v_cambios(v_cambios.COUNT + 1) := t_cambio(:OLD.id_tarifa, :OLD.valor_noche, :NEW.valor_noche);
  END BEFORE EACH ROW;

  AFTER STATEMENT IS
  BEGIN
    FORALL i IN 1..v_cambios.COUNT
      INSERT INTO auditoria_tarifa (id_tarifa, usuario_bd, valor_anterior, valor_nuevo)
      VALUES (v_cambios(i).id_tarifa, USER, v_cambios(i).valor_anterior, v_cambios(i).valor_nuevo);

    v_cambios.DELETE;
  END AFTER STATEMENT;

END trg_auditoria_tarifa;
/

-- ---------------------------------------------------------------------
-- Disparador a NIVEL DE FILA: impide que una habitacion quede reservada
-- dos veces en fechas que se solapen. Es la ultima linea de defensa a
-- nivel de datos (sp_crear_reserva ya valida esto tambien, con un mensaje
-- mas amigable via RAISE_APPLICATION_ERROR) - este trigger protege la
--
-- Nota para la sustentacion: este patron (leer la misma tabla que el
-- trigger esta modificando) funciona sin problema para INSERT/UPDATE de
-- una sola fila, como hace pkg_reservas.sp_crear_reserva (un INSERT por
-- habitacion). Si alguien insertara varias filas de una vez con un
-- unico INSERT...SELECT masivo, Oracle lanzaria ORA-04091 (tabla en
-- mutacion), porque ahi si habria ambiguedad sobre que filas del propio
-- INSERT ya son visibles. No es el caso de este proyecto, pero vale la
-- pena poder explicarlo si preguntan.
-- integridad aunque alguien inserte directo en RESERVA_HABITACION sin
-- pasar por el paquete.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_no_solape_reserva
BEFORE INSERT OR UPDATE ON reserva_habitacion
FOR EACH ROW
DECLARE
  v_checkin    reserva.fecha_checkin%TYPE;
  v_checkout   reserva.fecha_checkout%TYPE;
  v_conflictos NUMBER;
BEGIN
  SELECT fecha_checkin, fecha_checkout
  INTO v_checkin, v_checkout
  FROM reserva
  WHERE id_reserva = :NEW.id_reserva;

  SELECT COUNT(*)
  INTO v_conflictos
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
  WHERE rh.id_habitacion = :NEW.id_habitacion
    AND rh.id_reserva != :NEW.id_reserva
    AND r.estado IN ('PENDIENTE', 'CONFIRMADA')
    AND r.fecha_checkin < v_checkout
    AND r.fecha_checkout > v_checkin;

  IF v_conflictos > 0 THEN
    RAISE_APPLICATION_ERROR(-20002,
      'La habitacion ' || :NEW.id_habitacion ||
      ' ya tiene una reserva activa que se solapa con esas fechas.');
  END IF;
END trg_no_solape_reserva;
/
