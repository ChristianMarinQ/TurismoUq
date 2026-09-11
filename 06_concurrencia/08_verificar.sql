-- =====================================================================
-- Verificacion: corre esto despues de cada experimento (sin/con lock)
-- pegando el mismo id_habitacion que usaste en ese experimento.
-- Si aparecen 2 filas con fechas que se solapan y ambas CONFIRMADA,
-- hubo doble reserva (esperado en el experimento SIN bloqueo).
-- Si solo hay 1 fila (o la segunda reserva nunca se creo porque el
-- procedimiento la rechazo), el bloqueo funciono.
-- =====================================================================

SELECT r.id_reserva, r.fecha_checkin, r.fecha_checkout, r.estado, rh.id_habitacion
FROM reserva_habitacion rh
JOIN reserva r ON r.id_reserva = rh.id_reserva
WHERE rh.id_habitacion = &id_habitacion
ORDER BY r.fecha_checkin;
