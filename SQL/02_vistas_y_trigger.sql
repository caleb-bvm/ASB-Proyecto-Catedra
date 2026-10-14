USE FonaVitSV_Fase2;
GO
-- Una fila por cliente afectado, incluso si la sentencia modifica varias filas.
CREATE OR ALTER TRIGGER dbo.tr_CLIENTE_Auditoria
ON dbo.CLIENTE AFTER INSERT, UPDATE, DELETE
AS
BEGIN
 SET NOCOUNT ON;
 INSERT dbo.AUDITORIA(tabla,codigo_registro,operacion,datos_anteriores,datos_nuevos)
 SELECT N'CLIENTE', COALESCE(i.codigo_cliente,d.codigo_cliente),
 CASE WHEN d.codigo_cliente IS NULL THEN 'INSERT'
      WHEN i.codigo_cliente IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
 CASE WHEN d.codigo_cliente IS NOT NULL THEN
   (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
 CASE WHEN i.codigo_cliente IS NOT NULL THEN
   (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
 FROM inserted i FULL OUTER JOIN deleted d ON i.codigo_cliente=d.codigo_cliente;
END;
GO
-- Saldo derivado: no se almacena una segunda copia que pueda desactualizarse.
CREATE OR ALTER VIEW dbo.vw_SaldosCuenta AS
SELECT c.numero_cuenta,c.codigo_cliente,cl.nombre_completo,cl.documento_identidad,
 c.fecha_apertura,c.estado,COALESCE(SUM(t.monto),0) AS saldo_actual
FROM dbo.CUENTA c
JOIN dbo.CLIENTE cl ON cl.codigo_cliente=c.codigo_cliente
LEFT JOIN dbo.TRANSACCION t ON t.numero_cuenta=c.numero_cuenta
GROUP BY c.numero_cuenta,c.codigo_cliente,cl.nombre_completo,cl.documento_identidad,c.fecha_apertura,c.estado;
GO
-- El cliente y DUI del deudor se obtienen de la cuenta, sin repetirlos en PRESTAMO.
-- Interés simple anual: cuota referencial, no incluye seguros ni comisiones.
CREATE OR ALTER VIEW dbo.vw_CarteraPrestamos AS
SELECT p.codigo_prestamo,p.numero_cuenta,c.codigo_cliente,c.documento_identidad,
 c.nombre_completo,p.codigo_usuario,p.valor_prestamo,p.fecha_desembolso,
 p.interes_anual,p.tiempo_meses,p.estado,
 CAST(p.valor_prestamo*(1+p.interes_anual/100.0*p.tiempo_meses/12.0)/p.tiempo_meses AS decimal(12,2)) AS cuota_referencial
FROM dbo.PRESTAMO p
JOIN dbo.CUENTA a ON a.numero_cuenta=p.numero_cuenta
JOIN dbo.CLIENTE c ON c.codigo_cliente=a.codigo_cliente;
GO
CREATE OR ALTER VIEW dbo.vw_ClientesEdad AS
SELECT c.*, DATEDIFF(YEAR,c.fecha_nacimiento,CAST(GETDATE() AS date))
 - CASE WHEN DATEADD(YEAR,DATEDIFF(YEAR,c.fecha_nacimiento,GETDATE()),c.fecha_nacimiento)>CAST(GETDATE() AS date)
 THEN 1 ELSE 0 END AS edad
FROM dbo.CLIENTE c;
GO
