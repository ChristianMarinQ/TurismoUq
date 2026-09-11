-- =====================================================================
-- TurismoUQ - 01_indices.sql (Entrega 3 - Indices)
-- 3 consultas lentas + indices que las mejoran (uno compuesto, uno
-- basado en funcion), y 1 caso donde un indice NO ayuda.
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
--
-- Para cada caso: EXPLAIN PLAN antes -> CREATE INDEX -> EXPLAIN PLAN
-- despues. Compara la columna "Cost" y el tipo de acceso
-- (TABLE ACCESS FULL vs INDEX RANGE/SKIP SCAN) en cada DBMS_XPLAN.
-- =====================================================================

SET LINESIZE 150;
SET PAGESIZE 100;

-- =====================================================================
-- CASO 1 - INDICE COMPUESTO
-- Consulta: pagos por metodo y estado (reporte de conciliacion con la
-- pasarela, ej. "todos los pagos aprobados por Wompi").
-- =====================================================================
EXPLAIN PLAN FOR
SELECT id_pago, id_reserva, monto, fecha_pago
FROM pago
WHERE metodo_pago = 'WOMPI' AND estado = 'APROBADO';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- ANTES: esperar TABLE ACCESS FULL sobre PAGO (no hay indice en metodo_pago/estado).

CREATE INDEX ix_pago_metodo_estado ON pago (metodo_pago, estado);

EXPLAIN PLAN FOR
SELECT id_pago, id_reserva, monto, fecha_pago
FROM pago
WHERE metodo_pago = 'WOMPI' AND estado = 'APROBADO';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- DESPUES: esperar INDEX RANGE SCAN sobre ix_pago_metodo_estado + TABLE
-- ACCESS BY INDEX ROWID, con un Cost bastante menor que el full scan.


-- =====================================================================
-- CASO 2 - INDICE BASADO EN FUNCION
-- Consulta: busqueda de alojamientos por nombre sin importar mayusculas
-- (tipica barra de busqueda). Un indice normal sobre NOMBRE no sirve
-- aqui porque la condicion filtra por UPPER(nombre), no por nombre.
-- =====================================================================
EXPLAIN PLAN FOR
SELECT id_alojamiento, nombre
FROM alojamiento
WHERE UPPER(nombre) LIKE 'VISTA%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- ANTES: TABLE ACCESS FULL (no existe ningun indice sobre UPPER(nombre)).

CREATE INDEX ix_alojamiento_nombre_upper ON alojamiento (UPPER(nombre));

EXPLAIN PLAN FOR
SELECT id_alojamiento, nombre
FROM alojamiento
WHERE UPPER(nombre) LIKE 'VISTA%';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- DESPUES: esperar INDEX RANGE SCAN sobre ix_alojamiento_nombre_upper.
-- (ALOJAMIENTO solo tiene 60 filas, asi que la mejora de "Cost" es
-- pequena en terminos absolutos, pero el tipo de acceso cambia
-- igual - con 60 filas el optimizador puede decidir seguir usando
-- FULL SCAN por ser una tabla chiquita; si eso pasa, se documenta como
-- parte de la explicacion: "con tan pocas filas, Oracle prefiere leer
-- todo el bloque una sola vez".)


-- =====================================================================
-- CASO 3 - INDICE COMPUESTO (segundo ejemplo)
-- Consulta: resenas de un alojamiento con una calificacion especifica
-- (ej. "las resenas de 5 estrellas del alojamiento X", para mostrarlas
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
-- DESPUES: INDEX RANGE SCAN sobre ix_resena_alojamiento_calif.


-- =====================================================================
-- CASO 4 - UN INDICE QUE **NO** AYUDA (baja selectividad)
-- Consulta: todas las reservas que NO estan canceladas. Esto matchea
-- ~80% de las 25.000 reservas (solo ~15% quedan CANCELADA, ver la
-- consulta 7/UNPIVOT de la Entrega 1). Cuando una condicion devuelve
-- la mayoria de las filas de la tabla, leer fila por fila a traves de
-- un indice (muchos accesos aleatorios de un solo bloque) termina
-- costando MAS que un simple recorrido secuencial completo (Full Table
-- Scan), asi que el optimizador con razon IGNORA el indice.
-- =====================================================================
CREATE INDEX ix_reserva_estado ON reserva (estado);

EXPLAIN PLAN FOR
SELECT id_reserva FROM reserva WHERE estado <> 'CANCELADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Resultado esperado: el optimizador sigue eligiendo TABLE ACCESS FULL
-- a pesar de que el indice existe - no lo usa porque no conviene.

-- Para comprobar que de verdad "no ayuda" (y no que el optimizador se
-- equivoco), se fuerza su uso con un hint y se compara el costo:
EXPLAIN PLAN FOR
SELECT /*+ INDEX(reserva ix_reserva_estado) */ id_reserva
FROM reserva
WHERE estado <> 'CANCELADA';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
-- Resultado esperado: forzado con el hint, el plan usa el indice, pero
-- el "Cost" reportado es MAYOR que el del Full Table Scan del paso
-- anterior - evidencia numerica de que el indice, en este caso
-- concreto, empeora el desempeno en vez de mejorarlo. Esto es lo que
-- se documenta como el caso "el indice no ayuda", con la razon: baja
-- selectividad de la condicion (~80% de la tabla cumple el filtro).

-- Este indice se deja creado a proposito, como evidencia del
-- experimento (no se usa en produccion para esta consulta).
