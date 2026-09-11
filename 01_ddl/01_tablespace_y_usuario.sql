-- =====================================================================
-- TurismoUQ - 01_tablespace_y_usuario.sql
-- Ejecutar conectado como SYSTEM (o SYS AS SYSDBA) a la PDB del proyecto,
-- por ejemplo: sqlplus system/<tu_clave>@//localhost:1521/XEPDB1
-- =====================================================================

-- Tablespace dedicado al historico de reservas (ver docs/00_modelo_ER.md, seccion 5).
-- Aqui viviran RESERVA, RESERVA_HABITACION, PAGO y RESERVA_SERVICIO.
CREATE TABLESPACE ts_historico_reservas
  DATAFILE 'ts_historico_reservas01.dbf'
  SIZE 200M
  AUTOEXTEND ON NEXT 100M MAXSIZE 4G
  EXTENT MANAGEMENT LOCAL
  SEGMENT SPACE MANAGEMENT AUTO;

-- Si el datafile falla porque tu PDB no tiene "OMF"/db_create_file_dest configurado,
-- reemplaza la linea DATAFILE por la ruta completa, por ejemplo en Windows:
--   DATAFILE 'C:\APP\ORACLE\ORADATA\XE\XEPDB1\ts_historico_reservas01.dbf'
-- (ajusta segun donde haya quedado instalado tu Oracle XE 21c).

-- Usuario/esquema del proyecto. CAMBIA la clave antes de usarla en produccion.
CREATE USER turismouq IDENTIFIED BY "&&clave_turismouq"
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users
  QUOTA UNLIMITED ON ts_historico_reservas;

GRANT CONNECT, RESOURCE TO turismouq;
GRANT CREATE VIEW TO turismouq;
GRANT CREATE MATERIALIZED VIEW TO turismouq;
GRANT CREATE SEQUENCE TO turismouq;
GRANT CREATE TRIGGER TO turismouq;
GRANT CREATE PROCEDURE TO turismouq;
GRANT CREATE SESSION TO turismouq;

-- A partir de aqui, todos los demas scripts (02_tablas.sql en adelante)
-- se ejecutan conectado como: sqlplus turismouq@//localhost:1521/XEPDB1
