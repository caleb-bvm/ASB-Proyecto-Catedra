USE FonaVitSV_Fase2;
GO
SET NOCOUNT ON;
-- Esta prueba revierte sus cambios. Los IDENTITY pueden dejar saltos normales.
BEGIN TRANSACTION;
DECLARE @antes bigint=(SELECT COUNT_BIG(*) FROM dbo.AUDITORIA);
INSERT dbo.CLIENTE(nombre_completo,documento_identidad,fecha_nacimiento,calle,casa,ciudad,departamento,estado_familiar,beneficiario)
VALUES(N'Prueba auditoría A','99999991-1','1990-01-01',N'Calle prueba',N'1',N'Santa Tecla',N'La Libertad',N'Soltero/a',N'Beneficiario prueba'),
(N'Prueba auditoría B','99999992-2','1991-01-01',N'Calle prueba',N'2',N'Santa Tecla',N'La Libertad',N'Soltero/a',N'Beneficiario prueba');
UPDATE dbo.CLIENTE SET beneficiario=N'Beneficiario actualizado' WHERE documento_identidad IN('99999991-1','99999992-2');
DELETE dbo.CLIENTE WHERE documento_identidad IN('99999991-1','99999992-2');
SELECT codigo_auditoria,codigo_registro,operacion,fecha_utc,
 CAST(JSON_VALUE(datos_anteriores,'$.beneficiario') AS nvarchar(25)) AS beneficiario_antes,
 CAST(JSON_VALUE(datos_nuevos,'$.beneficiario') AS nvarchar(25)) AS beneficiario_despues
FROM dbo.AUDITORIA WHERE codigo_auditoria>(SELECT ISNULL(MAX(codigo_auditoria),0)-6 FROM dbo.AUDITORIA)
ORDER BY codigo_auditoria;
IF (SELECT COUNT_BIG(*) FROM dbo.AUDITORIA)-@antes<>6
BEGIN ROLLBACK; THROW 50002,'FALLO: se esperaban seis eventos de auditoría.',1; END;
PRINT 'PASS: INSERT, UPDATE y DELETE de dos filas producen seis eventos.';
ROLLBACK;
PRINT 'PASS: la prueba se revirtió sin dejar clientes ficticios adicionales.';
SELECT 'EMPLEADO' AS tabla,COUNT(*) AS filas FROM dbo.EMPLEADO
UNION ALL SELECT 'CLIENTE',COUNT(*) FROM dbo.CLIENTE
UNION ALL SELECT 'CUENTA',COUNT(*) FROM dbo.CUENTA
UNION ALL SELECT 'TRANSACCION',COUNT(*) FROM dbo.TRANSACCION
UNION ALL SELECT 'PRESTAMO',COUNT(*) FROM dbo.PRESTAMO
UNION ALL SELECT 'AUDITORIA',COUNT(*) FROM dbo.AUDITORIA;
IF EXISTS(SELECT 1 FROM (SELECT COUNT(*) n FROM dbo.EMPLEADO UNION ALL SELECT COUNT(*) FROM dbo.CLIENTE UNION ALL SELECT COUNT(*) FROM dbo.CUENTA UNION ALL SELECT COUNT(*) FROM dbo.TRANSACCION UNION ALL SELECT COUNT(*) FROM dbo.PRESTAMO UNION ALL SELECT COUNT(*) FROM dbo.AUDITORIA) x WHERE n<20)
 THROW 50003,'FALLO: una tabla tiene menos de 20 filas.',1;
PRINT 'PASS: todas las tablas contienen al menos 20 filas.';
IF (SELECT COUNT(*) FROM dbo.vw_SaldosCuenta)<>25 OR (SELECT COUNT(*) FROM dbo.vw_CarteraPrestamos)<>20
 THROW 50004,'FALLO: cardinalidad inesperada en vistas de la semilla.',1;
PRINT 'PASS: vistas con 25 cuentas y 20 préstamos.';
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
GO

