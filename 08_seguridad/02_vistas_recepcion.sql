-- =====================================================================
-- TurismoUQ - 02_vistas_recepcion.sql (Entrega 3 - Seguridad)
-- Vistas por las que el rol de recepcion accede a los datos - NUNCA
-- directo a las tablas base (ver justificacion en 03_permisos_por_rol.sql).
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- =====================================================================

CREATE OR REPLACE VIEW v_disponibilidad_habitaciones AS
SELECT h.id_habitacion, a.nombre AS alojamiento, m.nombre AS municipio,
       h.numero, h.tipo_habitacion, h.capacidad, h.estado
FROM habitacion h
JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
JOIN municipio m ON m.id_municipio = a.id_municipio;

CREATE OR REPLACE VIEW v_reservas_activas AS
SELECT r.id_reserva, c.nombre || ' ' || c.apellido AS cliente, c.telefono,
       r.fecha_checkin, r.fecha_checkout, r.estado, r.valor_total,
       h.id_habitacion, a.nombre AS alojamiento
FROM reserva r
JOIN cliente c ON c.id_cliente = r.id_cliente
JOIN reserva_habitacion rh ON rh.id_reserva = r.id_reserva
JOIN habitacion h ON h.id_habitacion = rh.id_habitacion
JOIN alojamiento a ON a.id_alojamiento = h.id_alojamiento
WHERE r.estado IN ('PENDIENTE', 'CONFIRMADA');

CREATE OR REPLACE VIEW v_clientes_directorio AS
SELECT id_cliente, tipo_documento, numero_documento, nombre, apellido, email, telefono
FROM cliente;
