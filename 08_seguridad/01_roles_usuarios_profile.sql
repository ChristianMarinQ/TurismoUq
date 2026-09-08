-- =====================================================================
-- TurismoUQ — 01_roles_usuarios_profile.sql (Entrega 3 · Seguridad)
-- CREATE ROLE / CREATE USER / CREATE PROFILE son privilegios de sistema
-- que el usuario turismouq NO tiene (solo tiene CONNECT/RESOURCE sobre
-- su propio esquema) — este script se ejecuta conectado como SYSTEM.
--   sqlplus system/<tu_clave>@//localhost:1521/XEPDB1 @01_roles_usuarios_profile.sql
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4 roles con privilegios diferenciados (los privilegios concretos se
-- otorgan en 03_permisos_por_rol.sql, conectado como turismouq, porque
-- es quien es dueño de las tablas/vistas/paquetes).
-- ---------------------------------------------------------------------
CREATE ROLE rol_recepcion;
CREATE ROLE rol_admin_alojamiento;
CREATE ROLE rol_gerente;
CREATE ROLE rol_auditor;

-- ---------------------------------------------------------------------
-- Perfil con límites de sesión, para los 4 usuarios de demostración.
-- ---------------------------------------------------------------------
CREATE PROFILE perfil_operativo LIMIT
  SESSIONS_PER_USER      2      -- máximo 2 sesiones simultáneas por usuario
  IDLE_TIME              30     -- se desconecta tras 30 min sin actividad
  CONNECT_TIME           480    -- máximo 8 horas por conexión
  FAILED_LOGIN_ATTEMPTS  3      -- se bloquea tras 3 intentos fallidos
  PASSWORD_LOCK_TIME     1      -- 1 día bloqueado tras exceder los intentos
  PASSWORD_LIFE_TIME     90;    -- la clave expira cada 90 días

-- ---------------------------------------------------------------------
-- Un usuario de ejemplo por rol, para la demo de la sustentación.
-- CAMBIA estas claves antes de usarlas en un ambiente real.
-- ---------------------------------------------------------------------
CREATE USER demo_recepcion IDENTIFIED BY "&&clave_demo_recepcion"
  PROFILE perfil_operativo DEFAULT TABLESPACE users QUOTA 0 ON users;
GRANT CREATE SESSION TO demo_recepcion;
GRANT rol_recepcion TO demo_recepcion;

CREATE USER demo_admin_alojamiento IDENTIFIED BY "&&clave_demo_admin_alojamiento"
  PROFILE perfil_operativo DEFAULT TABLESPACE users QUOTA 0 ON users;
GRANT CREATE SESSION TO demo_admin_alojamiento;
GRANT rol_admin_alojamiento TO demo_admin_alojamiento;

CREATE USER demo_gerente IDENTIFIED BY "&&clave_demo_gerente"
  PROFILE perfil_operativo DEFAULT TABLESPACE users QUOTA 0 ON users;
GRANT CREATE SESSION TO demo_gerente;
GRANT rol_gerente TO demo_gerente;

CREATE USER demo_auditor IDENTIFIED BY "&&clave_demo_auditor"
  PROFILE perfil_operativo DEFAULT TABLESPACE users QUOTA 0 ON users;
GRANT CREATE SESSION TO demo_auditor;
GRANT rol_auditor TO demo_auditor;
