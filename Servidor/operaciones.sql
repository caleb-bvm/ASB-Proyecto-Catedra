BEGIN TRY
 SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 BEGIN TRANSACTION;
 DECLARE @lock int;
 EXEC @lock=sys.sp_getapplock @Resource=N'FonaVitSV_Prototipo',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
 IF @lock<0 THROW 50001,N'VALIDACION:La base está ocupada. Intenta de nuevo.',1;
 DECLARE @kind nvarchar(30)=JSON_VALUE(@payload,'$.kind'), @id int=TRY_CONVERT(int,JSON_VALUE(@payload,'$.id'));
 DECLARE @today date=CONVERT(date,SYSDATETIMEOFFSET() AT TIME ZONE 'Central America Standard Time');
 DECLARE @name nvarchar(120),@dui nvarchar(10),@birth date,@street nvarchar(120),@house nvarchar(20),@city nvarchar(80),@department nvarchar(80),@family nvarchar(20),@beneficiary nvarchar(120),@role nvarchar(60),@salary decimal(12,2),@boss int,@account nvarchar(20),@date date,@amount decimal(12,2),@employee int,@type nvarchar(10),@rate decimal(5,2),@months int,@status nvarchar(12);
 SELECT @name=name,@dui=dui,@birth=birth,@street=street,@house=house,@city=city,@department=department,@family=family,@beneficiary=beneficiary,@role=role,@salary=salary,@boss=TRY_CONVERT(int,NULLIF(boss,'')),@account=account,@date=[date],@amount=amount,@employee=employee,@type=[type],@rate=rate,@months=months,@status=[status]
 FROM OPENJSON(@payload,'$.values') WITH(name nvarchar(120),dui nvarchar(10),birth date,street nvarchar(120),house nvarchar(20),city nvarchar(80),department nvarchar(80),family nvarchar(20),beneficiary nvarchar(120),role nvarchar(60),salary decimal(12,2),boss nvarchar(20),account nvarchar(20),[date] date,amount decimal(12,2),employee int,[type] nvarchar(10),rate decimal(5,2),months int,[status] nvarchar(12));
 IF @kind='client'
 BEGIN
  IF @id>0
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM dbo.CLIENTE WHERE codigo_cliente=@id) THROW 50001,N'VALIDACION:El registro ya no existe.',1;
   UPDATE dbo.CLIENTE SET nombre_completo=@name,documento_identidad=@dui,fecha_nacimiento=@birth,calle=@street,casa=@house,ciudad=@city,departamento=@department,estado_familiar=@family,beneficiario=@beneficiary WHERE codigo_cliente=@id;
  END
  ELSE
  BEGIN
   INSERT dbo.CLIENTE(nombre_completo,documento_identidad,fecha_nacimiento,calle,casa,ciudad,departamento,estado_familiar,beneficiario) VALUES(@name,@dui,@birth,@street,@house,@city,@department,@family,@beneficiary);
   SET @id=CONVERT(int,SCOPE_IDENTITY()); SET @kind='account';
  END
 END
 IF @kind='employee'
 BEGIN
  IF @id>0 AND NOT EXISTS(SELECT 1 FROM dbo.EMPLEADO WHERE codigo_empleado=@id) THROW 50001,N'VALIDACION:El registro ya no existe.',1;
  DECLARE @current int=@boss; DECLARE @seen table(id int PRIMARY KEY);
  IF @id>0 INSERT @seen VALUES(@id);
  WHILE @current IS NOT NULL
  BEGIN
   IF EXISTS(SELECT 1 FROM @seen WHERE id=@current) THROW 50001,N'VALIDACION:La jerarquía de jefes no puede formar un ciclo.',1;
   INSERT @seen VALUES(@current);
   IF NOT EXISTS(SELECT 1 FROM dbo.EMPLEADO WHERE codigo_empleado=@current) THROW 50001,N'VALIDACION:El jefe seleccionado no existe.',1;
   SELECT @current=codigo_jefe FROM dbo.EMPLEADO WITH(UPDLOCK,HOLDLOCK) WHERE codigo_empleado=@current;
  END
  IF @id>0 UPDATE dbo.EMPLEADO SET nombre_completo=@name,documento_identidad=@dui,fecha_nacimiento=@birth,calle=@street,casa=@house,ciudad=@city,departamento=@department,puesto=@role,sueldo=@salary,codigo_jefe=@boss WHERE codigo_empleado=@id;
  ELSE INSERT dbo.EMPLEADO(nombre_completo,documento_identidad,fecha_nacimiento,calle,casa,ciudad,departamento,puesto,sueldo,codigo_jefe) VALUES(@name,@dui,@birth,@street,@house,@city,@department,@role,@salary,@boss);
 END
 IF @kind='account'
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM dbo.CLIENTE WHERE codigo_cliente=@id) THROW 50001,N'VALIDACION:El cliente ya no existe.',1;
  DECLARE @prefix varchar(9)=CONCAT('CTA-',YEAR(@today),'-'),@next int;
  SELECT @next=COALESCE(MAX(TRY_CONVERT(int,SUBSTRING(numero_cuenta,10,11))),0)+1 FROM dbo.CUENTA WITH(UPDLOCK,HOLDLOCK) WHERE numero_cuenta LIKE @prefix+'%';
  SET @account=@prefix+CASE WHEN @next<10000 THEN RIGHT('0000'+CONVERT(varchar(11),@next),4) ELSE CONVERT(varchar(11),@next) END;
  INSERT dbo.CUENTA(numero_cuenta,codigo_cliente,fecha_apertura,estado) VALUES(@account,@id,@today,'Activa');
 END
 IF @kind IN('transaction','loan')
 BEGIN
  DECLARE @opened date;
  SELECT @opened=fecha_apertura FROM dbo.CUENTA WITH(UPDLOCK,HOLDLOCK) WHERE numero_cuenta=@account AND estado='Activa';
  IF @opened IS NULL THROW 50001,N'VALIDACION:Selecciona una cuenta activa.',1;
  IF @date<@opened OR @date>@today THROW 50001,N'VALIDACION:La fecha debe estar entre la apertura de la cuenta y hoy.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.EMPLEADO WHERE codigo_empleado=@employee) THROW 50001,N'VALIDACION:Selecciona un empleado válido.',1;
  IF @kind='transaction'
  BEGIN
   IF @type='withdraw'
   BEGIN
    DECLARE @balance decimal(38,2);
    SELECT @balance=COALESCE(SUM(monto),0) FROM dbo.TRANSACCION WITH(UPDLOCK,HOLDLOCK) WHERE numero_cuenta=@account;
    IF @amount>@balance THROW 50001,N'VALIDACION:Saldo insuficiente. El retiro no fue registrado.',1;
    SET @amount=-@amount;
   END
   INSERT dbo.TRANSACCION(numero_cuenta,documento_persona,codigo_usuario,monto,fecha) VALUES(@account,@dui,@employee,@amount,@date);
  END
  ELSE INSERT dbo.PRESTAMO(numero_cuenta,codigo_usuario,valor_prestamo,fecha_desembolso,interes_anual,tiempo_meses,estado) VALUES(@account,@employee,@amount,@date,@rate,@months,N'Al día');
 END
 IF @kind='status'
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM dbo.PRESTAMO WHERE codigo_prestamo=@id) THROW 50001,N'VALIDACION:El préstamo ya no existe.',1;
  UPDATE dbo.PRESTAMO SET estado=@status WHERE codigo_prestamo=@id;
 END
 -- La lectura se captura dentro de la transacción y se devuelve solo tras confirmar.
 DECLARE @result nvarchar(max);
 SET @result=(SELECT
          JSON_QUERY((SELECT codigo_cliente id,nombre_completo name,documento_identidad dui,
            CONVERT(char(10),fecha_nacimiento,23) birth,calle street,casa house,ciudad city,
            departamento department,estado_familiar family,beneficiario beneficiary
            FROM dbo.CLIENTE ORDER BY codigo_cliente FOR JSON PATH,INCLUDE_NULL_VALUES)) clients,
          JSON_QUERY((SELECT codigo_empleado id,nombre_completo name,documento_identidad dui,
            CONVERT(char(10),fecha_nacimiento,23) birth,calle street,casa house,ciudad city,
            departamento department,puesto role,sueldo salary,codigo_jefe boss
            FROM dbo.EMPLEADO ORDER BY codigo_empleado FOR JSON PATH,INCLUDE_NULL_VALUES)) employees,
          JSON_QUERY((SELECT numero_cuenta id,codigo_cliente client,CONVERT(char(10),fecha_apertura,23) date,estado status
            FROM dbo.CUENTA ORDER BY numero_cuenta FOR JSON PATH)) accounts,
          JSON_QUERY((SELECT codigo_transaccion id,numero_cuenta account,documento_persona dui,codigo_usuario employee,
            monto amount,CONVERT(varchar(19),fecha,126) date FROM dbo.TRANSACCION ORDER BY codigo_transaccion FOR JSON PATH)) transactions,
          JSON_QUERY((SELECT codigo_prestamo id,numero_cuenta account,codigo_usuario employee,valor_prestamo amount,
            CONVERT(char(10),fecha_desembolso,23) date,interes_anual rate,tiempo_meses months,estado status
            FROM dbo.PRESTAMO ORDER BY codigo_prestamo FOR JSON PATH)) loans,
          JSON_QUERY((SELECT codigo_auditoria id,tabla [table],codigo_registro record,operacion operation,
            CONVERT(varchar(19),fecha_utc,126)+'Z' date,usuario_sql [user],datos_anteriores [before],datos_nuevos [after]
            FROM dbo.AUDITORIA ORDER BY codigo_auditoria FOR JSON PATH,INCLUDE_NULL_VALUES)) audit,
          DB_NAME() [database],1 version
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 COMMIT;
 SELECT @result;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK;
 THROW;
END CATCH;
