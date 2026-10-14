USE FonaVitSV_Fase2;
GO
-- 1 WHERE: cuentas activas con saldo igual o mayor a $1,000.
SELECT numero_cuenta,nombre_completo,saldo_actual
FROM dbo.vw_SaldosCuenta WHERE estado='Activa' AND saldo_actual>=1000
ORDER BY saldo_actual DESC;
-- 2 JOIN: movimientos con titular y empleado que atendió.
SELECT t.codigo_transaccion,c.nombre_completo AS cliente,e.nombre_completo AS empleado,
 t.numero_cuenta,t.documento_persona,t.monto,t.fecha
FROM dbo.TRANSACCION t
JOIN dbo.CUENTA a ON a.numero_cuenta=t.numero_cuenta
JOIN dbo.CLIENTE c ON c.codigo_cliente=a.codigo_cliente
JOIN dbo.EMPLEADO e ON e.codigo_empleado=t.codigo_usuario
ORDER BY t.codigo_transaccion;
-- 3 GROUP BY: cantidad de cuentas y ahorro total por cliente.
SELECT codigo_cliente,nombre_completo,COUNT(*) AS cantidad_cuentas,SUM(saldo_actual) AS ahorro_total
FROM dbo.vw_SaldosCuenta GROUP BY codigo_cliente,nombre_completo
ORDER BY codigo_cliente;
-- 4 HAVING: clientes que ya poseen más de una cuenta.
SELECT c.codigo_cliente,c.nombre_completo,COUNT(*) AS cantidad_cuentas
FROM dbo.CLIENTE c JOIN dbo.CUENTA a ON a.codigo_cliente=c.codigo_cliente
GROUP BY c.codigo_cliente,c.nombre_completo HAVING COUNT(*)>1;
-- 5 Subconsulta: préstamos superiores al promedio de los préstamos registrados.
SELECT codigo_prestamo,nombre_completo,valor_prestamo
FROM dbo.vw_CarteraPrestamos
WHERE valor_prestamo>(SELECT AVG(valor_prestamo) FROM dbo.PRESTAMO);
-- 6 Vistas: saldo por cuenta y cartera con cuota de referencia.
SELECT * FROM dbo.vw_SaldosCuenta ORDER BY numero_cuenta;
SELECT * FROM dbo.vw_CarteraPrestamos ORDER BY codigo_prestamo;
GO
