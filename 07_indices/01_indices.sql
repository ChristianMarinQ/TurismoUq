-- =====================================================================
-- TurismoUQ — 01_indices.sql (Entrega 3 · Índices)
-- 3 consultas lentas + índices que las mejoran (uno compuesto, uno
-- basado en función), y 1 caso donde un índice NO ayuda.
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
--
-- Para cada caso: EXPLAIN PLAN antes -> CREATE INDEX -> EXPLAIN PLAN
-- después. Compara la columna "Cost" y el tipo de acceso
-- (TABLE ACCESS FULL vs INDEX RANGE/SKIP SCAN) en cada DBMS_XPLAN.
-- =====================================================================

SET LINESIZE 150;
SET PAGESIZE 100;

-- =====================================================================
-- CASO 1 — ÍNDICE COMPUESTO
-- Consulta: pagos por método y estado (reporte de conciliación con la
-- pasarela, ej. "todos los pagos aprobados por Wompi").
-- =====================================================================
EXPLAIN PLAN FOR
SELECT id_pago, id_reserva, monto, fecha_pago
FROM pago
WHERE metodo_pago = 'WOMPI' AND estado = 'APROBADO';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- ANTES: esperar TABLE ACCESS FULL sobre PAGO (no hay índice en metodo_pago/estado).

CREATE INDEX ix_pago_metodo_estado ON pago (metodo_pago, estado);

EXPLAIN PLAN FOR
SELECT id_pago, id_reserva, monto, fecha_pago
FROM pago
WHERE metodo_pago = 'WOMPI' AND estado = 'APROBADO';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- DESPUÉS: esperar INDEX RANGE SCAN sobre ix_pago_metodo_estado + TABLE
-- ACCESS BY INDEX ROWID, con un Cost bastante menor que el full scan.


-- =====================================================================
-- CASO 2 — ÍNDICE BASADO EN FUNCIÓN
-- Consulta: búsqueda de alojamientos por nombre sin importar mayúsculas
-- (típica barra de búsqueda). Un índice normal sobre NOMBRE no sirve
-- aquí porque la condición filtra por UPPER(nombre), no por nombre.
-- =====================================================================
EXPLAIN PLAN FOR
SELECT id_alojamiento, nombre
FROM alojamiento
WHERE UPPER(nombre) LIKE 'VISTA%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- ANTES: TABLE ACCESS FULL (no existe ningún índice sobre UPPER(nombre)).

CREATE INDEX ix_alojamiento_nombre_upper ON alojamiento (UPPER(nombre));

EXPLAIN PLAN FOR
SELECT id_alojamiento, nombre
FROM alojamiento
WHERE UPPER(nombre) LIKE 'VISTA%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- DESPUÉS: esperar INDEX RANGE SCAN sobre ix_alojamiento_nombre_upper.
-- (ALOJAMIENTO solo tiene 60 filas, así que la mejora de "Cost" es
-- pequeña en términos absolutos, pero el tipo de acceso cambia
-- igual — con 60 filas el optimizador puede decidir seguir usando
-- FULL SCAN por ser una tabla chiquita; si eso pasa, se documenta como
-- parte de la explicación: "con tan pocas filas, Oracle prefiere leer
-- todo el bloque una sola vez".)


-- =====================================================================
-- CASO 3 — ÍNDICE COMPUESTO (segundo ejemplo)
-- Consulta: reseñas de un alojamiento con una calificación específica
-- (ej. "las reseñas de 5 estrellas del alojamiento X", para mostrarlas
-- destacadas).
-- =====================================================================
EXPLAIN PLAN FOR
SELECT id_resena, id_cliente, comentario
FROM resena
WHERE id_alojamiento = 5 AND calificacion = 5;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- ANTES: TABLE ACCESS FULL sobre RESENA.

CREATE INDEX ix_resena_alojamiento_calif ON resena (id_alojamiento, calificacion);

EXPLAIN PLAN FOR
SELECT id_resena, id_cliente, comentario
FROM resena
WHERE id_alojamiento = 5 AND calificacion = 5;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- DESPUÉS: INDEX RANGE SCAN sobre ix_resena_alojamiento_calif.


-- =====================================================================
-- CASO 4 — UN ÍNDICE QUE **NO** AYUDA (baja selectividad)
-- Consulta: todas las reservas que NO están canceladas. Esto matchea
-- ~80% de las 25.000 reservas (solo ~15% quedan CANCELADA, ver la
-- consulta 7/UNPIVOT de la Entrega 1). Cuando una condición devuelve
-- la mayoría de las filas de la tabla, leer fila por fila a través de
-- un índice (muchos accesos aleatorios de un solo bloque) termina
-- costando MÁS que un simple recorrido secuencial completo (Full Table
-- Scan), así que el optimizador con razón IGNORA el índice.
-- =====================================================================
CREATE INDEX ix_reserva_estado ON reserva (estado);

EXPLAIN PLAN FOR
SELECT id_reserva FROM reserva WHERE estado <> 'CANCELADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Resultado esperado: el optimizador sigue eligiendo TABLE ACCESS FULL
-- a pesar de que el índice existe — no lo usa porque no conviene.

-- Para comprobar que de verdad "no ayuda" (y no que el optimizador se
-- equivocó), se fuerza su uso con un hint y se compara el costo:
EXPLAIN PLAN FOR
SELECT /*+ INDEX(reserva ix_reserva_estado) */ id_reserva
FROM reserva
WHERE estado <> 'CANCELADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Resultado esperado: forzado con el hint, el plan usa el índice, pero
-- el "Cost" reportado es MAYOR que el del Full Table Scan del paso
-- anterior — evidencia numérica de que el índice, en este caso
-- concreto, empeora el desempeño en vez de mejorarlo. Esto es lo que
-- se documenta como el caso "el índice no ayuda", con la razón: baja
-- selectividad de la condición (~80% de la tabla cumple el filtro).

-- Este índice se deja creado a propósito, como evidencia del
-- experimento (no se usa en producción para esta consulta).
