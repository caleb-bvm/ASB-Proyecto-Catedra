USE FonaVitSV_Fase2;
GO
SET NOCOUNT ON;
-- Cada intento inválido se revierte. Si se acepta, la prueba falla.
BEGIN TRY
 BEGIN TRAN;
 INSERT dbo.CUENTA VALUES('CUENTA-PRUEBA',999999,'2026-10-01','Activa');
 ROLLBACK;
 THROW 50101,'FALLO: se aceptó una cuenta sin cliente.',1;
END TRY BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 IF ERROR_NUMBER()<>547 THROW;
 PRINT 'PASS: una cuenta requiere un cliente existente.';
END CATCH;
BEGIN TRY
 BEGIN TRAN;
 INSERT dbo.PRESTAMO(numero_cuenta,codigo_usuario,valor_prestamo,fecha_desembolso,interes_anual,tiempo_meses)
 VALUES('NO-EXISTE',1,1000,'2026-10-01',12,12);
 ROLLBACK;
 THROW 50102,'FALLO: se aceptó un préstamo sin cuenta.',1;
END TRY BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 IF ERROR_NUMBER()<>547 THROW;
 PRINT 'PASS: un préstamo requiere una cuenta existente.';
END CATCH;
BEGIN TRY
 BEGIN TRAN;
 UPDATE dbo.CLIENTE SET documento_identidad='10000001-1' WHERE codigo_cliente=2;
 ROLLBACK;
 THROW 50103,'FALLO: se aceptó un DUI duplicado.',1;
END TRY BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 IF ERROR_NUMBER() NOT IN(2601,2627) THROW;
 PRINT 'PASS: DUI de cliente único.';
END CATCH;
BEGIN TRY
 BEGIN TRAN;
 INSERT dbo.TRANSACCION(numero_cuenta,documento_persona,codigo_usuario,monto)
 VALUES('CTA-2026-0001','10000001-1',1,0);
 ROLLBACK;
 THROW 50104,'FALLO: se aceptó monto cero.',1;
END TRY BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 IF ERROR_NUMBER()<>547 THROW;
 PRINT 'PASS: el monto de transacción no puede ser cero.';
END CATCH;
BEGIN TRY
 BEGIN TRAN;
 DELETE dbo.CLIENTE WHERE codigo_cliente=1;
 ROLLBACK;
 THROW 50105,'FALLO: se eliminó un cliente con cuentas.',1;
END TRY BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 IF ERROR_NUMBER()<>547 THROW;
 PRINT 'PASS: se preserva el cliente con cuentas relacionadas.';
END CATCH;
GO
