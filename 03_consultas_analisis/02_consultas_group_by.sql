-- =====================================================================
-- TurismoUQ - 02_consultas_group_by.sql - Consultas de agregacion con GROUP BY
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- Requiere 01_ddl/ y 02_carga_datos/ ya ejecutados.
--
-- GROUP BY agrupa las filas que comparten el mismo valor en una o mas
-- columnas y permite calcular funciones de agregacion por cada grupo:
--   COUNT (cuantas), SUM (total), AVG (promedio), MIN y MAX.
-- WHERE filtra filas ANTES de agrupar; HAVING filtra grupos DESPUES.
-- Toda columna del SELECT que no este dentro de una funcion de
-- agregacion debe aparecer en el GROUP BY.
-- =====================================================================

SET LINESIZE 200;
SET PAGESIZE 60;

-- =====================================================================
-- 1. COUNT - Cantidad de alojamientos por municipio
-- =====================================================================
SELECT m.nombre            AS municipio,
       COUNT(a.id_alojamiento) AS cantidad_alojamientos
FROM municipio m
JOIN alojamiento a ON a.id_municipio = m.id_municipio
GROUP BY m.nombre
ORDER BY cantidad_alojamientos DESC;

-- =====================================================================
-- 2. COUNT y AVG - Habitaciones por tipo y capacidad promedio
-- =====================================================================
SELECT h.tipo_habitacion,
       COUNT(*)                 AS cantidad_habitaciones,
       ROUND(AVG(h.capacidad), 2) AS capacidad_promedio,
       MIN(h.capacidad)         AS capacidad_minima,
       MAX(h.capacidad)         AS capacidad_maxima
FROM habitacion h
GROUP BY h.tipo_habitacion
ORDER BY cantidad_habitaciones DESC;

-- =====================================================================
-- 3. COUNT, SUM y AVG - Reservas e ingresos por estado de la reserva
-- =====================================================================
SELECT r.estado,
       COUNT(*)                     AS cantidad_reservas,
       SUM(r.valor_total)           AS valor_total,
       ROUND(AVG(r.valor_total), 0) AS valor_promedio
FROM reserva r
GROUP BY r.estado
ORDER BY cantidad_reservas DESC;

-- =====================================================================
-- 4. WHERE + GROUP BY - Pagos aprobados por metodo de pago
--    WHERE deja solo los pagos APROBADOS y luego se agrupa por metodo.
-- =====================================================================
SELECT p.metodo_pago,
       COUNT(*)     AS cantidad_pagos,
       SUM(p.monto) AS total_recaudado,
       MIN(p.monto) AS pago_minimo,
       MAX(p.monto) AS pago_maximo
FROM pago p
WHERE p.estado = 'APROBADO'
GROUP BY p.metodo_pago
ORDER BY total_recaudado DESC;

-- =====================================================================
-- 5. GROUP BY por dos columnas - Tarifa promedio por temporada y tipo
--    de habitacion (cada combinacion distinta es un grupo).
-- =====================================================================
SELECT t.tipo                      AS temporada,
       h.tipo_habitacion,
       COUNT(*)                    AS cantidad_tarifas,
       ROUND(AVG(ta.valor_noche), 0) AS tarifa_promedio_noche
FROM tarifa ta
JOIN temporada t  ON t.id_temporada  = ta.id_temporada
JOIN habitacion h ON h.id_habitacion = ta.id_habitacion
GROUP BY t.tipo, h.tipo_habitacion
ORDER BY t.tipo, tarifa_promedio_noche DESC;

-- =====================================================================
-- 6. GROUP BY + HAVING - Alojamientos con al menos 10 resenas y su
--    calificacion promedio. HAVING filtra los grupos ya calculados.
-- =====================================================================
SELECT a.nombre                     AS alojamiento,
       COUNT(re.id_resena)          AS cantidad_resenas,
       ROUND(AVG(re.calificacion), 2) AS calificacion_promedio
FROM alojamiento a
JOIN resena re ON re.id_alojamiento = a.id_alojamiento
GROUP BY a.id_alojamiento, a.nombre
HAVING COUNT(re.id_resena) >= 10
ORDER BY calificacion_promedio DESC, cantidad_resenas DESC;

-- =====================================================================
-- 7. GROUP BY + HAVING - Clientes frecuentes: mas de 12 reservas no
--    canceladas, con cuanto han gastado en total.
-- =====================================================================
SELECT c.id_cliente,
       c.nombre || ' ' || c.apellido AS cliente,
       COUNT(r.id_reserva)           AS cantidad_reservas,
       SUM(r.valor_total)            AS total_gastado
FROM cliente c
JOIN reserva r ON r.id_cliente = c.id_cliente
WHERE r.estado <> 'CANCELADA'
GROUP BY c.id_cliente, c.nombre, c.apellido
HAVING COUNT(r.id_reserva) > 12
ORDER BY cantidad_reservas DESC, total_gastado DESC;

-- =====================================================================
-- 8. SUM sobre una expresion - Servicios adicionales mas vendidos
-- =====================================================================
SELECT s.nombre                                  AS servicio,
       SUM(rs.cantidad)                          AS unidades_vendidas,
       SUM(rs.cantidad * rs.precio_unitario)     AS ingreso_servicio
FROM reserva_servicio rs
JOIN servicio s ON s.id_servicio = rs.id_servicio
GROUP BY s.nombre
ORDER BY ingreso_servicio DESC;

-- =====================================================================
-- 9. GROUP BY por fecha - Reservas e ingresos por mes de checkin
--    TO_CHAR convierte la fecha en 'YYYY-MM' para agrupar por mes.
-- =====================================================================
SELECT TO_CHAR(r.fecha_checkin, 'YYYY-MM') AS mes,
       COUNT(*)                            AS cantidad_reservas,
       SUM(r.valor_total)                  AS ingresos
FROM reserva r
WHERE r.estado <> 'CANCELADA'
GROUP BY TO_CHAR(r.fecha_checkin, 'YYYY-MM')
ORDER BY mes;

-- =====================================================================
-- 10. GROUP BY con varias tablas - Ingresos por tipo de alojamiento y
--     municipio, solo los grupos que superan 100 millones.
-- =====================================================================
SELECT ta.nombre              AS tipo_alojamiento,
       m.nombre               AS municipio,
       COUNT(DISTINCT rh.id_reserva) AS cantidad_reservas,
       SUM(rh.valor_estadia)  AS ingresos_estadia
FROM reserva_habitacion rh
JOIN reserva r           ON r.id_reserva      = rh.id_reserva
JOIN habitacion h        ON h.id_habitacion   = rh.id_habitacion
JOIN alojamiento a       ON a.id_alojamiento  = h.id_alojamiento
JOIN tipo_alojamiento ta ON ta.id_tipo        = a.id_tipo
JOIN municipio m         ON m.id_municipio    = a.id_municipio
WHERE r.estado <> 'CANCELADA'
GROUP BY ta.nombre, m.nombre
HAVING SUM(rh.valor_estadia) > 100000000
ORDER BY ingresos_estadia DESC;
