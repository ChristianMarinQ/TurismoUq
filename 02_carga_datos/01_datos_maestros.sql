-- =====================================================================
-- TurismoUQ - 01_datos_maestros.sql
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- Carga: MUNICIPIO, TIPO_ALOJAMIENTO, ALOJAMIENTO (60), HABITACION (400),
--        TEMPORADA, TARIFA, SERVICIO, USUARIO_SISTEMA.
-- Debe poder correr solo (no depende de 02_clientes_reservas.sql).
-- =====================================================================

SET SERVEROUTPUT ON;

-- ---------------------------------------------------------------------
-- 1. MUNICIPIO (los 12 del Quindio)
-- ---------------------------------------------------------------------
INSERT INTO municipio (nombre) VALUES ('Armenia');
INSERT INTO municipio (nombre) VALUES ('Calarca');
INSERT INTO municipio (nombre) VALUES ('Circasia');
INSERT INTO municipio (nombre) VALUES ('Cordoba');
INSERT INTO municipio (nombre) VALUES ('Filandia');
INSERT INTO municipio (nombre) VALUES ('Genova');
INSERT INTO municipio (nombre) VALUES ('La Tebaida');
INSERT INTO municipio (nombre) VALUES ('Montenegro');
INSERT INTO municipio (nombre) VALUES ('Pijao');
INSERT INTO municipio (nombre) VALUES ('Quimbaya');
INSERT INTO municipio (nombre) VALUES ('Salento');
INSERT INTO municipio (nombre) VALUES ('Buenavista');

-- ---------------------------------------------------------------------
-- 2. TIPO_ALOJAMIENTO
-- ---------------------------------------------------------------------
INSERT INTO tipo_alojamiento (nombre, descripcion) VALUES ('Finca Cafetera', 'Alojamiento rural en finca productora de cafe');
INSERT INTO tipo_alojamiento (nombre, descripcion) VALUES ('Hotel', 'Alojamiento urbano con servicios hoteleros estandar');
INSERT INTO tipo_alojamiento (nombre, descripcion) VALUES ('Glamping', 'Alojamiento tipo camping de lujo (domos, cabanas)');
INSERT INTO tipo_alojamiento (nombre, descripcion) VALUES ('Hostal', 'Alojamiento economico, habitaciones individuales o compartidas');

COMMIT;

-- ---------------------------------------------------------------------
-- 3. ALOJAMIENTO - 60 filas
-- ---------------------------------------------------------------------
DECLARE
  TYPE t_lista IS TABLE OF VARCHAR2(40);
  v_nombres_base t_lista := t_lista(
    'Vista Hermosa','El Mirador','Buenos Aires','La Esperanza','El Paraiso',
    'Villa del Rio','Los Naranjos','El Recuerdo','Bella Vista','El Encanto',
    'La Palma','Villa Cafe','El Roble','Monte Verde','La Colina',
    'El Jardin','Villa Sol','La Cascada','El Bosque','Rincon Andino'
  );
  v_id_municipio NUMBER;
  v_id_tipo      NUMBER;
  v_nombre       VARCHAR2(150);
  v_capacidad    NUMBER;
  v_fecha_reg    DATE;
BEGIN
  DBMS_RANDOM.SEED(20260907);
  FOR i IN 1..60 LOOP
    v_id_municipio := TRUNC(DBMS_RANDOM.VALUE(1,13)); -- 1..12
    v_id_tipo      := TRUNC(DBMS_RANDOM.VALUE(1,5));  -- 1..4
    v_nombre       := v_nombres_base(MOD(i-1, v_nombres_base.COUNT) + 1) || ' ' || TO_CHAR(i);
    v_capacidad    := TRUNC(DBMS_RANDOM.VALUE(4,41));
    v_fecha_reg    := DATE '2023-01-01' + TRUNC(DBMS_RANDOM.VALUE(0,700));

    INSERT INTO alojamiento (id_municipio, id_tipo, nombre, direccion, capacidad_max, fecha_registro, estado)
    VALUES (
      v_id_municipio, v_id_tipo,
      v_nombre,
      'Vereda/Calle ' || TRUNC(DBMS_RANDOM.VALUE(1,99)) || ', zona rural/urbana',
      v_capacidad,
      v_fecha_reg,
      'ACTIVO'
    );
  END LOOP;
  COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- 4. HABITACION - exactamente 400 filas repartidas entre los 60 alojamientos
--    (cada alojamiento recibe entre 6 y 7 habitaciones)
-- ---------------------------------------------------------------------
DECLARE
  TYPE t_tipos IS TABLE OF VARCHAR2(20);
  v_tipos t_tipos := t_tipos('INDIVIDUAL','DOBLE','TRIPLE','SUITE','FAMILIAR');
  v_id_alojamiento NUMBER;
  v_numero_hab     NUMBER;
  v_tipo_hab       VARCHAR2(20);
  v_capacidad      NUMBER;
BEGIN
  FOR i IN 1..400 LOOP
    v_id_alojamiento := MOD(i-1, 60) + 1;
    v_numero_hab     := TRUNC((i-1)/60) + 1;
    v_tipo_hab       := v_tipos(TRUNC(DBMS_RANDOM.VALUE(1,6)));
    v_capacidad      := CASE v_tipo_hab
                           WHEN 'INDIVIDUAL' THEN 1
                           WHEN 'DOBLE'      THEN 2
                           WHEN 'TRIPLE'     THEN 3
                           WHEN 'SUITE'      THEN 2
                           WHEN 'FAMILIAR'   THEN TRUNC(DBMS_RANDOM.VALUE(4,7))
                         END;

    INSERT INTO habitacion (id_alojamiento, numero, tipo_habitacion, capacidad, estado)
    VALUES (v_id_alojamiento, TO_CHAR(v_numero_hab), v_tipo_hab, v_capacidad, 'DISPONIBLE');
  END LOOP;
  COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- 5. TEMPORADA - filas concretas por ano 2024/2025/2026, particionando
--    el calendario completo (ver docs/00_modelo_ER.md, decision de diseno 2)
-- ---------------------------------------------------------------------
DECLARE
  TYPE t_periodo IS RECORD (
    fecha_ini DATE,
    fecha_fin DATE,
    nombre    VARCHAR2(80),
    tipo      VARCHAR2(10),
    factor    NUMBER
  );
  TYPE t_periodos IS TABLE OF t_periodo INDEX BY PLS_INTEGER;
  v_esp          t_periodos;
  v_n            PLS_INTEGER;
  v_anio_inicio  DATE;
  v_anio_fin     DATE;
  v_cursor_fecha DATE;

  PROCEDURE agregar(p_ini DATE, p_fin DATE, p_nombre VARCHAR2, p_tipo VARCHAR2, p_factor NUMBER) IS
  BEGIN
    v_n := v_n + 1;
    v_esp(v_n).fecha_ini := p_ini;
    v_esp(v_n).fecha_fin := p_fin;
    v_esp(v_n).nombre    := p_nombre;
    v_esp(v_n).tipo      := p_tipo;
    v_esp(v_n).factor    := p_factor;
  END agregar;

  PROCEDURE insertar_temporada(p_nombre VARCHAR2, p_tipo VARCHAR2, p_ini DATE, p_fin DATE, p_factor NUMBER) IS
  BEGIN
    IF p_fin >= p_ini THEN
      INSERT INTO temporada (nombre, tipo, fecha_inicio, fecha_fin, factor_ajuste)
      VALUES (p_nombre, p_tipo, p_ini, p_fin, p_factor);
    END IF;
  END insertar_temporada;

  PROCEDURE generar_anio(p_anio PLS_INTEGER) IS
  BEGIN
    v_n := 0;
    v_anio_inicio := TO_DATE(p_anio || '-01-01', 'YYYY-MM-DD');
    v_anio_fin    := TO_DATE(p_anio || '-12-31', 'YYYY-MM-DD');

    -- Enero: si el ano anterior ya genero su tramo de diciembre, aqui solo
    -- va la cola "Diciembre-Enero" de enero; si no (2024, primer ano del
    -- historico), va un puente corto de ano nuevo.
    IF p_anio > 2024 THEN
      agregar(v_anio_inicio, TO_DATE(p_anio || '-01-15', 'YYYY-MM-DD'),
              'Diciembre-Enero ' || (p_anio-1) || '-' || p_anio || ' (enero)', 'ALTA', 1.6);
    ELSE
      agregar(v_anio_inicio, TO_DATE(p_anio || '-01-03', 'YYYY-MM-DD'),
              'Puente ano nuevo ' || p_anio, 'ALTA', 1.4);
    END IF;

    -- Semana Santa (fechas reales por ano)
    IF p_anio = 2024 THEN
      agregar(DATE '2024-03-24', DATE '2024-03-31', 'Semana Santa 2024', 'ALTA', 1.6);
    ELSIF p_anio = 2025 THEN
      agregar(DATE '2025-04-13', DATE '2025-04-20', 'Semana Santa 2025', 'ALTA', 1.6);
    ELSIF p_anio = 2026 THEN
      agregar(DATE '2026-03-29', DATE '2026-04-05', 'Semana Santa 2026', 'ALTA', 1.6);
    END IF;

    agregar(TO_DATE(p_anio || '-05-01', 'YYYY-MM-DD'), TO_DATE(p_anio || '-05-03', 'YYYY-MM-DD'),
            'Puente mayo ' || p_anio, 'ALTA', 1.4);

    agregar(TO_DATE(p_anio || '-06-15', 'YYYY-MM-DD'), TO_DATE(p_anio || '-07-15', 'YYYY-MM-DD'),
            'Mitad de ano ' || p_anio, 'MEDIA', 1.2);

    agregar(TO_DATE(p_anio || '-08-07', 'YYYY-MM-DD'), TO_DATE(p_anio || '-08-09', 'YYYY-MM-DD'),
            'Puente agosto ' || p_anio, 'ALTA', 1.4);

    agregar(TO_DATE(p_anio || '-10-12', 'YYYY-MM-DD'), TO_DATE(p_anio || '-10-14', 'YYYY-MM-DD'),
            'Puente octubre ' || p_anio, 'ALTA', 1.4);

    agregar(TO_DATE(p_anio || '-11-02', 'YYYY-MM-DD'), TO_DATE(p_anio || '-11-04', 'YYYY-MM-DD'),
            'Puente noviembre ' || p_anio, 'ALTA', 1.4);

    agregar(TO_DATE(p_anio || '-12-01', 'YYYY-MM-DD'), v_anio_fin,
            'Diciembre-Enero ' || p_anio || '-' || (p_anio+1) || ' (diciembre)', 'ALTA', 1.6);

    -- Insertar periodos especiales y rellenar BAJA en cada hueco
    v_cursor_fecha := v_anio_inicio;
    FOR i IN 1..v_n LOOP
      IF v_esp(i).fecha_ini > v_cursor_fecha THEN
        insertar_temporada('Temporada baja ' || p_anio || ' (' || TO_CHAR(v_cursor_fecha,'Mon') || ')',
                            'BAJA', v_cursor_fecha, v_esp(i).fecha_ini - 1, 1.0);
      END IF;
      insertar_temporada(v_esp(i).nombre, v_esp(i).tipo, v_esp(i).fecha_ini, v_esp(i).fecha_fin, v_esp(i).factor);
      IF v_esp(i).fecha_fin + 1 > v_cursor_fecha THEN
        v_cursor_fecha := v_esp(i).fecha_fin + 1;
      END IF;
    END LOOP;
    IF v_cursor_fecha <= v_anio_fin THEN
      insertar_temporada('Temporada baja ' || p_anio || ' (cierre)', 'BAJA', v_cursor_fecha, v_anio_fin, 1.0);
    END IF;
  END generar_anio;

BEGIN
  generar_anio(2024);
  generar_anio(2025);
  generar_anio(2026);
  COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- 6. TARIFA - una fila por cada combinacion (habitacion, temporada)
--    valor_noche = precio_base(tipo_alojamiento, tipo_habitacion) * factor_ajuste * ruido(+/-10%)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_precio_base_seed(p_tipo_alojamiento VARCHAR2, p_tipo_habitacion VARCHAR2)
RETURN NUMBER
IS
BEGIN
  RETURN CASE p_tipo_alojamiento
    WHEN 'Hostal' THEN
      CASE p_tipo_habitacion
        WHEN 'INDIVIDUAL' THEN 40000 WHEN 'DOBLE' THEN 60000 WHEN 'TRIPLE' THEN 80000
        WHEN 'SUITE' THEN 120000 ELSE 100000 END
    WHEN 'Hotel' THEN
      CASE p_tipo_habitacion
        WHEN 'INDIVIDUAL' THEN 80000 WHEN 'DOBLE' THEN 120000 WHEN 'TRIPLE' THEN 160000
        WHEN 'SUITE' THEN 250000 ELSE 200000 END
    WHEN 'Finca Cafetera' THEN
      CASE p_tipo_habitacion
        WHEN 'INDIVIDUAL' THEN 70000 WHEN 'DOBLE' THEN 110000 WHEN 'TRIPLE' THEN 150000
        WHEN 'SUITE' THEN 220000 ELSE 190000 END
    WHEN 'Glamping' THEN
      CASE p_tipo_habitacion
        WHEN 'INDIVIDUAL' THEN 150000 WHEN 'DOBLE' THEN 220000 WHEN 'TRIPLE' THEN 280000
        WHEN 'SUITE' THEN 380000 ELSE 320000 END
    ELSE 100000
  END;
END fn_precio_base_seed;
/

DECLARE
  CURSOR c_combo IS
    SELECT h.id_habitacion, ta.nombre AS tipo_alojamiento, h.tipo_habitacion,
           t.id_temporada, t.factor_ajuste
    FROM habitacion h
    JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
    JOIN tipo_alojamiento ta ON ta.id_tipo = a.id_tipo
    CROSS JOIN temporada t;

  TYPE t_hab   IS TABLE OF NUMBER;
  TYPE t_temp  IS TABLE OF NUMBER;
  TYPE t_valor IS TABLE OF NUMBER;
  v_hab   t_hab   := t_hab();
  v_temp  t_temp  := t_temp();
  v_valor t_valor := t_valor();
  v_precio_base NUMBER;
  v_ruido       NUMBER;
  c_lote CONSTANT PLS_INTEGER := 2000;
BEGIN
  FOR r IN c_combo LOOP
    v_precio_base := fn_precio_base_seed(r.tipo_alojamiento, r.tipo_habitacion);
    v_ruido       := DBMS_RANDOM.VALUE(0.9, 1.1);

    v_hab.EXTEND;   v_hab(v_hab.LAST)     := r.id_habitacion;
    v_temp.EXTEND;  v_temp(v_temp.LAST)   := r.id_temporada;
    v_valor.EXTEND; v_valor(v_valor.LAST) := ROUND(v_precio_base * r.factor_ajuste * v_ruido, -3);

    IF v_hab.COUNT >= c_lote THEN
      FORALL i IN 1..v_hab.COUNT
        INSERT INTO tarifa (id_habitacion, id_temporada, valor_noche)
        VALUES (v_hab(i), v_temp(i), v_valor(i));
      v_hab.DELETE; v_temp.DELETE; v_valor.DELETE;
      COMMIT;
    END IF;
  END LOOP;

  IF v_hab.COUNT > 0 THEN
    FORALL i IN 1..v_hab.COUNT
      INSERT INTO tarifa (id_habitacion, id_temporada, valor_noche)
      VALUES (v_hab(i), v_temp(i), v_valor(i));
  END IF;
  COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- 7. SERVICIO - 4 a 6 servicios por alojamiento (catalogo variado)
-- ---------------------------------------------------------------------
DECLARE
  TYPE t_cat IS TABLE OF VARCHAR2(60);
  v_catalogo t_cat := t_cat(
    'Desayuno incluido','Tour cafetero','Transporte aeropuerto','Cabalgata',
    'Spa y masajes','Piscina','Parqueadero privado','Guianza turistica',
    'Alquiler de bicicletas','Noche de karaoke','Fogata nocturna','Avistamiento de aves'
  );
  TYPE t_precios IS TABLE OF NUMBER;
  v_precios t_precios := t_precios(
    0, 60000, 90000, 70000,
    120000, 15000, 10000, 50000,
    25000, 20000, 30000, 40000
  );
  v_cant NUMBER;
  v_idx  NUMBER;
  v_usados t_cat;
BEGIN
  FOR a IN (SELECT id_alojamiento FROM alojamiento) LOOP
    v_cant := TRUNC(DBMS_RANDOM.VALUE(4,7)); -- 4..6
    v_usados := t_cat();
    FOR k IN 1..v_cant LOOP
      LOOP
        v_idx := TRUNC(DBMS_RANDOM.VALUE(1, v_catalogo.COUNT + 1));
        EXIT WHEN v_usados.COUNT = 0 OR v_catalogo(v_idx) NOT MEMBER OF v_usados;
      END LOOP;
      v_usados.EXTEND;
      v_usados(v_usados.LAST) := v_catalogo(v_idx);

      INSERT INTO servicio (id_alojamiento, nombre, descripcion, precio)
      VALUES (a.id_alojamiento, v_catalogo(v_idx), 'Servicio complementario: ' || v_catalogo(v_idx), v_precios(v_idx));
    END LOOP;
  END LOOP;
  COMMIT;
END;
/

-- ---------------------------------------------------------------------
-- 8. USUARIO_SISTEMA - usuarios de ejemplo para los 4 roles de la Entrega 3
-- ---------------------------------------------------------------------
INSERT INTO usuario_sistema (username, password_hash, rol, id_alojamiento)
  VALUES ('recepcion.arm1', STANDARD_HASH('Clave_2026#1','SHA256'), 'RECEPCION', 1);
INSERT INTO usuario_sistema (username, password_hash, rol, id_alojamiento)
  VALUES ('recepcion.arm2', STANDARD_HASH('Clave_2026#2','SHA256'), 'RECEPCION', 2);
INSERT INTO usuario_sistema (username, password_hash, rol, id_alojamiento)
  VALUES ('admin.alojamiento1', STANDARD_HASH('Clave_2026#3','SHA256'), 'ADMIN_ALOJAMIENTO', 1);
INSERT INTO usuario_sistema (username, password_hash, rol, id_alojamiento)
  VALUES ('admin.alojamiento2', STANDARD_HASH('Clave_2026#4','SHA256'), 'ADMIN_ALOJAMIENTO', 2);
INSERT INTO usuario_sistema (username, password_hash, rol, id_alojamiento)
  VALUES ('gerente.turismouq', STANDARD_HASH('Clave_2026#5','SHA256'), 'GERENTE', NULL);
INSERT INTO usuario_sistema (username, password_hash, rol, id_alojamiento)
  VALUES ('auditor.turismouq', STANDARD_HASH('Clave_2026#6','SHA256'), 'AUDITOR', NULL);

COMMIT;

-- ---------------------------------------------------------------------
-- Verificacion rapida de volumen
-- ---------------------------------------------------------------------
SELECT 'municipio' tabla, COUNT(*) filas FROM municipio
UNION ALL SELECT 'tipo_alojamiento', COUNT(*) FROM tipo_alojamiento
UNION ALL SELECT 'alojamiento', COUNT(*) FROM alojamiento
UNION ALL SELECT 'habitacion', COUNT(*) FROM habitacion
UNION ALL SELECT 'temporada', COUNT(*) FROM temporada
UNION ALL SELECT 'tarifa', COUNT(*) FROM tarifa
UNION ALL SELECT 'servicio', COUNT(*) FROM servicio
UNION ALL SELECT 'usuario_sistema', COUNT(*) FROM usuario_sistema;
