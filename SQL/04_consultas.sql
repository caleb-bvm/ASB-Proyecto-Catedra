-- Selecciona la base de datos donde se ejecutarán las consultas.
USE FonaVitSV_Fase2;
-- Envía la instrucción USE como un lote independiente en SSMS.
GO

-- 1 WHERE: cuentas activas con saldo igual o mayor a $1,000.
-- Selecciona los datos principales de cada cuenta que cumple el filtro.
SELECT numero_cuenta,nombre_completo,saldo_actual
-- Consulta la vista que contiene los saldos calculados por cuenta.
FROM dbo.vw_SaldosCuenta
-- Conserva únicamente cuentas activas con saldo de al menos $1,000.
WHERE estado='Activa' AND saldo_actual>=1000
-- Ordena las cuentas desde el saldo más alto hasta el más bajo.
ORDER BY saldo_actual DESC;


-- 2 JOIN: movimientos con titular y empleado que atendió.
-- Selecciona la transacción y asigna alias descriptivos a cliente y empleado.
SELECT t.codigo_transaccion,c.nombre_completo AS cliente,e.nombre_completo AS empleado,
 t.numero_cuenta,t.documento_persona,t.monto,t.fecha
-- Inicia la consulta desde la tabla de transacciones.
FROM dbo.TRANSACCION t
-- Relaciona cada movimiento con la cuenta correspondiente.
JOIN dbo.CUENTA a ON a.numero_cuenta=t.numero_cuenta
-- Obtiene el titular de la cuenta mediante su código de cliente.
JOIN dbo.CLIENTE c ON c.codigo_cliente=a.codigo_cliente
-- Obtiene el empleado que registró o atendió la transacción.
JOIN dbo.EMPLEADO e ON e.codigo_empleado=t.codigo_usuario
-- Presenta los movimientos en orden ascendente por código.
ORDER BY t.codigo_transaccion;


-- 3 GROUP BY: cantidad de cuentas y ahorro total por cliente.
-- Cuenta las cuentas y suma sus saldos para cada cliente.
SELECT codigo_cliente,nombre_completo,COUNT(*) AS cantidad_cuentas,SUM(saldo_actual) AS ahorro_total
-- Utiliza la vista con la información consolidada de saldos.
FROM dbo.vw_SaldosCuenta
-- Agrupa los resultados para obtener un resumen por cliente.
GROUP BY codigo_cliente,nombre_completo
-- Ordena el resumen por código de cliente.
ORDER BY codigo_cliente;


-- 4 HAVING: clientes que ya poseen más de una cuenta.
-- Selecciona cada cliente y calcula cuántas cuentas posee.
SELECT c.codigo_cliente,c.nombre_completo,COUNT(*) AS cantidad_cuentas
-- Relaciona clientes con sus cuentas registradas.
FROM dbo.CLIENTE c
JOIN dbo.CUENTA a ON a.codigo_cliente=c.codigo_cliente
-- Agrupa las cuentas por cliente para poder contarlas.
GROUP BY c.codigo_cliente,c.nombre_completo
-- Filtra los grupos y conserva clientes con más de una cuenta.
HAVING COUNT(*)>1;


-- 5 Subconsulta: préstamos superiores al promedio de los préstamos registrados.
-- Selecciona los préstamos cuyo valor supera el promedio general.
SELECT codigo_prestamo,nombre_completo,valor_prestamo
-- Consulta la vista que muestra la cartera y el nombre del titular.
FROM dbo.vw_CarteraPrestamos
-- Compara cada préstamo con el promedio calculado por la subconsulta.
WHERE valor_prestamo>(SELECT AVG(valor_prestamo) FROM dbo.PRESTAMO);


-- 6 Vistas: saldo por cuenta y cartera con cuota de referencia.
-- Muestra todas las columnas de la vista de saldos ordenadas por cuenta.
SELECT * FROM dbo.vw_SaldosCuenta ORDER BY numero_cuenta;
-- Muestra todas las columnas de la vista de préstamos ordenadas por código.
SELECT * FROM dbo.vw_CarteraPrestamos ORDER BY codigo_prestamo;
-- Envía las consultas de las vistas como un lote independiente en SSMS.
GO
