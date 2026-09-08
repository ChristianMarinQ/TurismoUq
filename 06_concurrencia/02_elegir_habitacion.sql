-- =====================================================================
-- PASO 0 (nuevo): elegir de antemano la habitación y fechas del
-- experimento. Esto se corre UNA vez, antes de abrir las dos sesiones,
-- para no depender de leer un mensaje "en vivo" mientras una sesión
-- está dormida (DBMS_OUTPUT no se ve hasta que el bloque completo
-- termina, así que no sirve para coordinar en tiempo real).
--
-- Al ejecutar te va a pedir "checkin" y "checkout": escribe fechas en
-- formato YYYY-MM-DD, por ejemplo 2026-09-15 y 2026-09-18.
-- Anota el ID_HABITACION de la primera fila del resultado: ese número
-- lo vas a pegar tanto en la Sesión A como en la Sesión B.
-- =====================================================================

SELECT h.id_habitacion, a.nombre AS alojamiento, h.tipo_habitacion
FROM habitacion h
JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
WHERE NOT EXISTS (
  SELECT 1 FROM reserva_habitacion rh JOIN reserva r ON r.id_reserva = rh.id_reserva
  WHERE rh.id_habitacion = h.id_habitacion AND r.estado IN ('PENDIENTE','CONFIRMADA')
    AND r.fecha_checkin < DATE '&checkout' AND r.fecha_checkout > DATE '&checkin'
)
FETCH FIRST 5 ROWS ONLY;
