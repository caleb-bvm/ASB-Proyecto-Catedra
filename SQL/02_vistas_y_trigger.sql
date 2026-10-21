-- Selecciona la base de datos donde se crearán el trigger y las vistas.
USE FonaVitSV_Fase2;
-- Envía la instrucción USE como un lote independiente en SSMS.
GO


-- Una fila por cliente afectado, incluso si la sentencia modifica varias filas.
-- Crea o actualiza el trigger encargado de registrar cambios en los clientes.
CREATE OR ALTER TRIGGER dbo.tr_CLIENTE_Auditoria
-- Asocia el trigger con la tabla que contiene los clientes.
ON dbo.CLIENTE AFTER INSERT, UPDATE, DELETE
AS
BEGIN
 -- Evita que los mensajes de cantidad de filas afecten la ejecución del trigger.
 SET NOCOUNT ON;
 -- Inserta en la auditoría la operación y los datos anteriores y nuevos.
 INSERT dbo.AUDITORIA(tabla,codigo_registro,operacion,datos_anteriores,datos_nuevos)
 -- Obtiene los datos de las tablas lógicas inserted y deleted.
 SELECT N'CLIENTE', COALESCE(i.codigo_cliente,d.codigo_cliente),
 -- Determina si el cambio fue una inserción, eliminación o actualización.
 CASE WHEN d.codigo_cliente IS NULL THEN 'INSERT'
      WHEN i.codigo_cliente IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
 -- Convierte los datos anteriores a un objeto JSON cuando existen.
 CASE WHEN d.codigo_cliente IS NOT NULL THEN
   (SELECT d.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
 -- Convierte los datos nuevos a un objeto JSON cuando existen.
 CASE WHEN i.codigo_cliente IS NOT NULL THEN
   (SELECT i.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END
 -- Combina las filas nuevas y anteriores para identificar cualquier cambio.
 FROM inserted i FULL OUTER JOIN deleted d ON i.codigo_cliente=d.codigo_cliente;
 -- Finaliza el cuerpo del trigger.
END;
-- Finaliza el lote de creación o actualización del trigger.
GO


-- Saldo derivado: no se almacena una segunda copia que pueda desactualizarse.
-- Crea o actualiza la vista que calcula el saldo de cada cuenta.
CREATE OR ALTER VIEW dbo.vw_SaldosCuenta AS
-- Selecciona la información de la cuenta, del cliente y el saldo calculado.
SELECT c.numero_cuenta,c.codigo_cliente,cl.nombre_completo,cl.documento_identidad,
 c.fecha_apertura,c.estado,COALESCE(SUM(t.monto),0) AS saldo_actual
-- Parte de la tabla de cuentas.
FROM dbo.CUENTA c
-- Relaciona cada cuenta con su cliente titular.
JOIN dbo.CLIENTE cl ON cl.codigo_cliente=c.codigo_cliente
-- Incluye cuentas sin transacciones y calcula sus movimientos cuando existan.
LEFT JOIN dbo.TRANSACCION t ON t.numero_cuenta=c.numero_cuenta
-- Agrupa por los datos no agregados para obtener un saldo por cuenta.
GROUP BY c.numero_cuenta,c.codigo_cliente,cl.nombre_completo,cl.documento_identidad,c.fecha_apertura,c.estado;
-- Finaliza el lote de creación o actualización de la vista de saldos.
GO


-- El cliente y DUI del deudor se obtienen de la cuenta, sin repetirlos en PRESTAMO.
-- Interés simple anual: cuota referencial, no incluye seguros ni comisiones.
-- Crea o actualiza la vista que presenta la cartera de préstamos.
CREATE OR ALTER VIEW dbo.vw_CarteraPrestamos AS
-- Selecciona los datos del préstamo, la cuenta y el cliente asociado.
SELECT p.codigo_prestamo,p.numero_cuenta,c.codigo_cliente,c.documento_identidad,
 c.nombre_completo,p.codigo_usuario,p.valor_prestamo,p.fecha_desembolso,
 p.interes_anual,p.tiempo_meses,p.estado,
 -- Calcula una cuota referencial usando interés simple anual.
 CAST(p.valor_prestamo*(1+p.interes_anual/100.0*p.tiempo_meses/12.0)/p.tiempo_meses AS decimal(12,2)) AS cuota_referencial
-- Parte de la tabla de préstamos.
FROM dbo.PRESTAMO p
-- Relaciona cada préstamo con la cuenta del deudor.
JOIN dbo.CUENTA a ON a.numero_cuenta=p.numero_cuenta
-- Obtiene los datos del cliente titular de la cuenta.
JOIN dbo.CLIENTE c ON c.codigo_cliente=a.codigo_cliente;
-- Finaliza el lote de creación o actualización de la vista de préstamos.
GO
-- Crea o actualiza la vista que calcula la edad actual de cada cliente.
CREATE OR ALTER VIEW dbo.vw_ClientesEdad AS
-- Devuelve las columnas del cliente y agrega su edad calculada.
SELECT c.*, DATEDIFF(YEAR,c.fecha_nacimiento,CAST(GETDATE() AS date))
 -- Ajusta la edad cuando el cumpleaños del año todavía no ha ocurrido.
 - CASE WHEN DATEADD(YEAR,DATEDIFF(YEAR,c.fecha_nacimiento,GETDATE()),c.fecha_nacimiento)>CAST(GETDATE() AS date)
 THEN 1 ELSE 0 END AS edad
-- Consulta la tabla de clientes y obtiene la fecha actual del servidor.
FROM dbo.CLIENTE c;
-- Finaliza el lote de creación o actualización de la vista de edades.
GO
