-- =====================================================================
-- TurismoUQ — 00_reiniciar_y_cargar.sql
-- Atajo: limpia CLIENTE (por si 02_clientes_reservas.sql ya se corrió
-- parcialmente) y vuelve a correr la carga completa de clientes/reservas.
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
--   sqlplus turismouq@//localhost:1521/XEPDB1 @C:/ProyectosIng/TurismoUQ/02_carga_datos/00_reiniciar_y_cargar.sql
-- =====================================================================

TRUNCATE TABLE reserva_servicio;
TRUNCATE TABLE pago;
TRUNCATE TABLE resena;
TRUNCATE TABLE reserva_habitacion;
TRUNCATE TABLE reserva;
TRUNCATE TABLE cliente;

@@02_clientes_reservas.sql
