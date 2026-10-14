-- FonaVitSV | Fase II | SQL Server 2016 SP1 o posterior.
-- Instalación segura: se detiene si la base ya existe. No borra información.
USE master;
GO
IF DB_ID(N'FonaVitSV_Fase2') IS NOT NULL
    THROW 50001, 'La base FonaVitSV_Fase2 ya existe. No se ha reemplazado.', 1;
GO
CREATE DATABASE FonaVitSV_Fase2;
GO
USE FonaVitSV_Fase2;
GO
CREATE TABLE dbo.EMPLEADO (
 codigo_empleado int IDENTITY(1,1) CONSTRAINT PK_EMPLEADO PRIMARY KEY,
 nombre_completo nvarchar(120) NOT NULL,
 documento_identidad varchar(10) NOT NULL CONSTRAINT UQ_EMPLEADO_DUI UNIQUE,
 fecha_nacimiento date NOT NULL,
 calle nvarchar(120) NOT NULL, casa nvarchar(20) NOT NULL,
 ciudad nvarchar(80) NOT NULL, departamento nvarchar(80) NOT NULL,
 puesto nvarchar(60) NOT NULL,
 sueldo decimal(12,2) NOT NULL CONSTRAINT CK_EMPLEADO_SUELDO CHECK(sueldo>0),
 codigo_jefe int NULL CONSTRAINT FK_EMPLEADO_JEFE REFERENCES dbo.EMPLEADO(codigo_empleado),
 CONSTRAINT CK_EMPLEADO_JEFE CHECK(codigo_jefe<>codigo_empleado),
 CONSTRAINT CK_EMPLEADO_DUI CHECK(documento_identidad LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]')
);
CREATE TABLE dbo.CLIENTE (
 codigo_cliente int IDENTITY(1,1) CONSTRAINT PK_CLIENTE PRIMARY KEY,
 nombre_completo nvarchar(120) NOT NULL,
 documento_identidad varchar(10) NOT NULL CONSTRAINT UQ_CLIENTE_DUI UNIQUE,
 fecha_nacimiento date NOT NULL,
 calle nvarchar(120) NOT NULL, casa nvarchar(20) NOT NULL,
 ciudad nvarchar(80) NOT NULL, departamento nvarchar(80) NOT NULL,
 estado_familiar nvarchar(20) NOT NULL CONSTRAINT CK_CLIENTE_ESTADO CHECK(estado_familiar IN(N'Soltero/a',N'Casado/a',N'Acompañado/a',N'Divorciado/a',N'Viudo/a')),
 beneficiario nvarchar(120) NOT NULL,
 CONSTRAINT CK_CLIENTE_DUI CHECK(documento_identidad LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]')
);
CREATE TABLE dbo.CUENTA (
 numero_cuenta varchar(20) CONSTRAINT PK_CUENTA PRIMARY KEY,
 codigo_cliente int NOT NULL CONSTRAINT FK_CUENTA_CLIENTE REFERENCES dbo.CLIENTE(codigo_cliente),
 fecha_apertura date NOT NULL,
 estado varchar(10) NOT NULL DEFAULT 'Activa' CONSTRAINT CK_CUENTA_ESTADO CHECK(estado IN('Activa','Cerrada'))
);
CREATE TABLE dbo.TRANSACCION (
 codigo_transaccion bigint IDENTITY(1,1) CONSTRAINT PK_TRANSACCION PRIMARY KEY,
 numero_cuenta varchar(20) NOT NULL CONSTRAINT FK_TRANSACCION_CUENTA REFERENCES dbo.CUENTA(numero_cuenta),
 documento_persona varchar(10) NOT NULL,
 codigo_usuario int NOT NULL CONSTRAINT FK_TRANSACCION_EMPLEADO REFERENCES dbo.EMPLEADO(codigo_empleado),
 monto decimal(12,2) NOT NULL CONSTRAINT CK_TRANSACCION_MONTO CHECK(monto<>0),
 fecha datetime2(0) NOT NULL DEFAULT SYSDATETIME(),
 CONSTRAINT CK_TRANSACCION_DUI CHECK(documento_persona LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9]')
);
CREATE TABLE dbo.PRESTAMO (
 codigo_prestamo int IDENTITY(1,1) CONSTRAINT PK_PRESTAMO PRIMARY KEY,
 numero_cuenta varchar(20) NOT NULL CONSTRAINT FK_PRESTAMO_CUENTA REFERENCES dbo.CUENTA(numero_cuenta),
 codigo_usuario int NOT NULL CONSTRAINT FK_PRESTAMO_EMPLEADO REFERENCES dbo.EMPLEADO(codigo_empleado),
 valor_prestamo decimal(12,2) NOT NULL CONSTRAINT CK_PRESTAMO_VALOR CHECK(valor_prestamo>0),
 fecha_desembolso date NOT NULL,
 interes_anual decimal(5,2) NOT NULL CONSTRAINT CK_PRESTAMO_INTERES CHECK(interes_anual BETWEEN 0 AND 100),
 tiempo_meses smallint NOT NULL CONSTRAINT CK_PRESTAMO_PLAZO CHECK(tiempo_meses BETWEEN 1 AND 360),
 estado nvarchar(12) NOT NULL DEFAULT N'Al día' CONSTRAINT CK_PRESTAMO_ESTADO CHECK(estado IN(N'Al día',N'Atrasado',N'Pagado'))
);
CREATE TABLE dbo.AUDITORIA (
 codigo_auditoria bigint IDENTITY(1,1) CONSTRAINT PK_AUDITORIA PRIMARY KEY,
 tabla nvarchar(50) NOT NULL,
 codigo_registro int NOT NULL,
 operacion varchar(6) NOT NULL CONSTRAINT CK_AUDITORIA_OPERACION CHECK(operacion IN('INSERT','UPDATE','DELETE')),
 fecha_utc datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
 usuario_sql nvarchar(128) NOT NULL DEFAULT ORIGINAL_LOGIN(),
 datos_anteriores nvarchar(max) NULL,
 datos_nuevos nvarchar(max) NULL
);
CREATE INDEX IX_CUENTA_CLIENTE ON dbo.CUENTA(codigo_cliente);
CREATE INDEX IX_TRANSACCION_CUENTA ON dbo.TRANSACCION(numero_cuenta);
CREATE INDEX IX_PRESTAMO_CUENTA ON dbo.PRESTAMO(numero_cuenta);
GO

