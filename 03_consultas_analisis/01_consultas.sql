-- =====================================================================
-- TurismoUQ - 01_consultas.sql - Entrega 1, seccion 5 (8 consultas obligatorias)
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- Requiere haber corrido antes todo 01_ddl/ y 02_carga_datos/.
-- =====================================================================

SET LINESIZE 200;
SET PAGESIZE 50;

-- =====================================================================
-- 1. Ocupacion por municipio y mes (2025) - con PIVOT
--    Metrica: habitaciones-noche vendidas, asignadas al mes de checkin.
-- =====================================================================
SELECT *
FROM (
  SELECT m.nombre AS municipio,
         EXTRACT(MONTH FROM r.fecha_checkin) AS mes,
         (r.fecha_checkout - r.fecha_checkin) AS noches
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
  JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
  JOIN municipio m ON m.id_municipio = a.id_municipio
  WHERE EXTRACT(YEAR FROM r.fecha_checkin) = 2025
    AND r.estado <> 'CANCELADA'
)
PIVOT (
  SUM(noches)
  FOR mes IN (1 AS ene, 2 AS feb, 3 AS mar, 4 AS abr, 5 AS may, 6 AS jun,
              7 AS jul, 8 AS ago, 9 AS sep, 10 AS oct, 11 AS nov, 12 AS dic)
)
ORDER BY municipio;

-- =====================================================================
-- 2. Ingresos por municipio, tipo de alojamiento y temporada - ROLLUP + GROUPING
--    Ingreso = suma de valor_estadia de cada linea reservada (RESERVA_HABITACION).
--    La temporada se asigna por la fecha de checkin de la reserva.
-- =====================================================================
SELECT
  CASE WHEN GROUPING(m.nombre)  = 1 THEN 'TOTAL GENERAL' ELSE m.nombre  END AS municipio,
  CASE WHEN GROUPING(ta.nombre) = 1 THEN 'Subtotal municipio' ELSE ta.nombre END AS tipo_alojamiento,
  CASE WHEN GROUPING(t.tipo)    = 1 THEN 'Subtotal tipo' ELSE t.tipo END AS tipo_temporada,
  SUM(rh.valor_estadia) AS ingresos,
  GROUPING(m.nombre)  AS g_municipio,
  GROUPING(ta.nombre) AS g_tipo_alojamiento,
  GROUPING(t.tipo)    AS g_temporada
FROM reserva_habitacion rh
JOIN reserva r ON r.id_reserva = rh.id_reserva
JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
JOIN municipio m ON m.id_municipio = a.id_municipio
JOIN tipo_alojamiento ta ON ta.id_tipo = a.id_tipo
JOIN temporada t ON r.fecha_checkin BETWEEN t.fecha_inicio AND t.fecha_fin
WHERE r.estado <> 'CANCELADA'
GROUP BY ROLLUP(m.nombre, ta.nombre, t.tipo)
ORDER BY g_municipio, municipio, g_tipo_alojamiento, tipo_alojamiento, g_temporada, tipo_temporada;

-- =====================================================================
-- 3. Top 3 alojamientos de mayor ingreso dentro de cada municipio - RANK() PARTITION BY
-- =====================================================================
SELECT municipio, alojamiento, ingresos, ranking
FROM (
  SELECT m.id_municipio, m.nombre AS municipio, a.nombre AS alojamiento,
         SUM(rh.valor_estadia) AS ingresos,
         RANK() OVER (PARTITION BY m.id_municipio ORDER BY SUM(rh.valor_estadia) DESC) AS ranking
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
  JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
  JOIN municipio m ON m.id_municipio = a.id_municipio
  WHERE r.estado <> 'CANCELADA'
  GROUP BY m.id_municipio, m.nombre, a.id_alojamiento, a.nombre
)
WHERE ranking <= 3
ORDER BY municipio, ranking;

-- =====================================================================
-- 4. Variacion de ingresos mes contra mes - LAG
-- =====================================================================
SELECT anio, mes, ingresos,
       LAG(ingresos) OVER (ORDER BY anio, mes) AS ingresos_mes_anterior,
       ingresos - LAG(ingresos) OVER (ORDER BY anio, mes) AS variacion_absoluta,
       ROUND( (ingresos - LAG(ingresos) OVER (ORDER BY anio, mes))
              / NULLIF(LAG(ingresos) OVER (ORDER BY anio, mes), 0) * 100, 2) AS variacion_pct
FROM (
  SELECT EXTRACT(YEAR FROM r.fecha_checkin) AS anio,
         EXTRACT(MONTH FROM r.fecha_checkin) AS mes,
         SUM(rh.valor_estadia) AS ingresos
  FROM reserva_habitacion rh
  JOIN reserva r ON r.id_reserva = rh.id_reserva
  WHERE r.estado <> 'CANCELADA'
  GROUP BY EXTRACT(YEAR FROM r.fecha_checkin), EXTRACT(MONTH FROM r.fecha_checkin)
)
ORDER BY anio, mes;

-- =====================================================================
-- 5. Consulta parametrizada con variables de enlace (bind variables)
--    Reservas cuyo checkin cae en un rango de fechas dado.
-- =====================================================================
VARIABLE p_fecha_ini VARCHAR2(10)
VARIABLE p_fecha_fin VARCHAR2(10)
EXEC :p_fecha_ini := '2025-06-01';
EXEC :p_fecha_fin := '2025-07-31';

SELECT DISTINCT r.id_reserva,
       c.nombre || ' ' || c.apellido AS cliente,
       a.nombre AS alojamiento,
       r.fecha_checkin, r.fecha_checkout, r.estado, r.valor_total
FROM reserva r
JOIN cliente c ON c.id_cliente = r.id_cliente
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
WHERE r.fecha_checkin >= TO_DATE(:p_fecha_ini, 'YYYY-MM-DD')
  AND r.fecha_checkin <= TO_DATE(:p_fecha_fin, 'YYYY-MM-DD')
ORDER BY r.fecha_checkin;

-- =====================================================================
-- 6. Vista materializada de ocupacion mensual + politica de refresco
-- =====================================================================
-- Permite volver a correr este script sobre una BD donde la vista ya
-- exista (CREATE MATERIALIZED VIEW no admite OR REPLACE en Oracle).
BEGIN
  EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_ocupacion_mensual';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -12003 THEN -- ORA-12003: la vista materializada no existe
      RAISE;
    END IF;
END;
/

CREATE MATERIALIZED VIEW mv_ocupacion_mensual
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT m.id_municipio, m.nombre AS municipio,
       EXTRACT(YEAR FROM r.fecha_checkin) AS anio,
       EXTRACT(MONTH FROM r.fecha_checkin) AS mes,
       COUNT(rh.id_habitacion) AS habitaciones_reservadas,
       SUM(r.fecha_checkout - r.fecha_checkin) AS noches_totales,
       SUM(rh.valor_estadia) AS ingresos
FROM reserva_habitacion rh
JOIN reserva r ON r.id_reserva = rh.id_reserva
JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
JOIN municipio m ON m.id_municipio = a.id_municipio
WHERE r.estado <> 'CANCELADA'
GROUP BY m.id_municipio, m.nombre, EXTRACT(YEAR FROM r.fecha_checkin), EXTRACT(MONTH FROM r.fecha_checkin);

-- Politica de refresco: COMPLETE + ON DEMAND (no ON COMMIT, no FAST), programado
-- una vez al dia via DBMS_SCHEDULER. Justificacion:
--  - La vista agrega 4 tablas con SUM/COUNT; un refresco FAST exigiria materialized
--    view logs sobre RESERVA, RESERVA_HABITACION, HABITACION y ALOJAMIENTO, lo que
--    anade overhead a cada INSERT/UPDATE transaccional (justo las tablas con mas
--    escrituras del sistema).
--  - ON COMMIT recalcularia la vista en cada una de las ~25.000 reservas de la carga
--    masiva (o de cada reserva nueva en produccion), inaceptable para un reporte
--    gerencial que se consulta como mucho un par de veces al dia.
--  - Un refresco nocturno (baja demanda del sistema) es suficiente: la ocupacion de
--    "ayer" no cambia y los gerentes revisan el reporte en la manana.
-- Requiere GRANT CREATE JOB TO turismouq; (una sola vez, conectado como
-- system/sysdba). Es seguro volver a correr este bloque: si el job ya
-- existe, se elimina primero.
BEGIN
  BEGIN
    DBMS_SCHEDULER.DROP_JOB('JOB_REFRESH_MV_OCUPACION');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE != -27475 THEN -- ORA-27475: el job no existe
        RAISE;
      END IF;
  END;

  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_REFRESH_MV_OCUPACION',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN DBMS_MVIEW.REFRESH(''MV_OCUPACION_MENSUAL'', ''C''); END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=2; BYMINUTE=0',
    enabled         => TRUE
  );
END;
/

-- Consulta de ejemplo sobre la vista materializada
SELECT * FROM mv_ocupacion_mensual ORDER BY municipio, anio, mes;

-- =====================================================================
-- 7. UNPIVOT - reservas por estado y municipio (de columnas a filas)
-- =====================================================================
WITH resumen AS (
  SELECT m.nombre AS municipio,
         COUNT(DISTINCT CASE WHEN r.estado = 'PENDIENTE'  THEN r.id_reserva END) AS pendiente,
         COUNT(DISTINCT CASE WHEN r.estado = 'CONFIRMADA' THEN r.id_reserva END) AS confirmada,
         COUNT(DISTINCT CASE WHEN r.estado = 'CANCELADA'  THEN r.id_reserva END) AS cancelada,
         COUNT(DISTINCT CASE WHEN r.estado = 'FINALIZADA' THEN r.id_reserva END) AS finalizada
  FROM reserva r
  JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
  JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
  JOIN municipio m ON m.id_municipio = a.id_municipio
  GROUP BY m.nombre
)
SELECT municipio, estado, cantidad
FROM resumen
UNPIVOT (
  cantidad FOR estado IN (
    pendiente  AS 'PENDIENTE',
    confirmada AS 'CONFIRMADA',
    cancelada  AS 'CANCELADA',
    finalizada AS 'FINALIZADA'
  )
)
ORDER BY municipio, estado;

-- =====================================================================
-- 8. Pregunta de negocio propuesta por el equipo:
--    Los clientes recurrentes (2+ reservas) dejan un ticket promedio mas alto
--    que los clientes de una sola reserva, y en que tipo de alojamiento se nota mas?
--    (Sirve para decidir donde invertir en fidelizacion.)
-- =====================================================================
WITH reserva_base AS (
  SELECT r.id_reserva, r.id_cliente, r.valor_total,
         MIN(ta.nombre) AS tipo_alojamiento
  FROM reserva r
  JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
  JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
  JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
  JOIN tipo_alojamiento ta ON ta.id_tipo = a.id_tipo
  WHERE r.estado <> 'CANCELADA'
  GROUP BY r.id_reserva, r.id_cliente, r.valor_total
),
conteo_cliente AS (
  SELECT id_cliente, COUNT(*) AS num_reservas FROM reserva_base GROUP BY id_cliente
)
SELECT rb.tipo_alojamiento,
       CASE WHEN cc.num_reservas >= 2 THEN 'RECURRENTE' ELSE 'NUEVO' END AS segmento_cliente,
       COUNT(*) AS reservas,
       ROUND(AVG(rb.valor_total), 0) AS ticket_promedio
FROM reserva_base rb
JOIN conteo_cliente cc ON cc.id_cliente = rb.id_cliente
GROUP BY rb.tipo_alojamiento, CASE WHEN cc.num_reservas >= 2 THEN 'RECURRENTE' ELSE 'NUEVO' END
ORDER BY rb.tipo_alojamiento, segmento_cliente;
