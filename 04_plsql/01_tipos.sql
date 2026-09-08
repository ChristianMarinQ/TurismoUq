-- =====================================================================
-- TurismoUQ — 01_tipos.sql (Entrega 2)
-- Tipos SQL a nivel de esquema, necesarios para pasarle a sp_crear_reserva
-- la lista de habitaciones de una reserva (una reserva puede incluir
-- varias habitaciones — ver docs/00_modelo_ER.md, decisión de diseño 1).
-- Ejecutar conectado como: turismouq@//localhost:1521/XEPDB1
-- =====================================================================

CREATE OR REPLACE TYPE ty_item_habitacion AS OBJECT (
  id_habitacion NUMBER,
  num_huespedes NUMBER
);
/

CREATE OR REPLACE TYPE ty_tab_habitaciones AS TABLE OF ty_item_habitacion;
/
