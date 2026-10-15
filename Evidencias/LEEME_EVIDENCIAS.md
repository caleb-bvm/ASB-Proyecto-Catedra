# Evidencias del proceso

Las evidencias 00 a 18 se capturaron el 11 de octubre de 2026 y corresponden a la versión anterior. Los datos personales usados por el prototipo y la semilla SQL son ficticios.

## Conexión del prototipo a SQL Server — 14 de octubre de 2026

- `19_pruebas_conexion_sql.json`: resultados del recorrido con lectura y escritura SQL, rollback, persistencia, auditoría, validaciones en servidor y concurrencia de retiros. Las escrituras se realizan en una base temporal propia; la base del proyecto se preserva.
- `20_inicio_conectado_sql.png`: vista del prototipo conectado durante ese recorrido. Incluye datos de prueba de la base temporal, que se elimina al finalizar.

El recorrido actual está en `Pruebas/prototipo.cjs`. El funcionamiento e inicio del sitio conectado se describen en el LEEME principal y en `Servidor/LEEME.md`.

## Base de datos real

- `00_entorno_sql.txt`: versión, edición y nombre de la base obtenidos por consulta.
- `01_instalacion.txt`: salida de la instalación correcta.
- `02_pruebas_sql.txt`: salida real de la prueba del trigger, conteos y comprobación de restricciones.
- `03_integridad_sql.txt`: cinco intentos inválidos rechazados por SQL Server.
- `04_consultas_sql.txt`: resultados de las consultas y vistas.
- `05_resumen_consultas.txt`: conteos obtenidos de las cinco consultas.
- `17_auditoria_sql.png`: captura de un reporte HTML que tabula la salida de `02_pruebas_sql.txt`; los eventos provienen de SQL Server, no de JavaScript.
- `18_integridad_sql.png`: captura de un reporte que reproduce el entorno y las cinco pruebas de integridad.

Los reportes HTML acompañan a las imágenes. No son capturas de SSMS. Los archivos TXT permiten contrastar sus resultados. SQL/05_pruebas.sql utiliza una transacción que se revierte: los seis eventos mostrados fueron consultados antes de ROLLBACK. Al terminar quedan las veinte auditorías originales de la semilla; los saltos de IDENTITY son normales.

## Prototipo independiente

- `03_pruebas_prototipo.json`: 21 comprobaciones satisfactorias del recorrido automatizado y lista vacía de errores JavaScript.
- `04_acceso.png`: acceso de demostración.
- `05_inicio.png`: panel con semilla inicial.
- `06_registro_cliente.png`: formulario completado.
- `07_varias_cuentas.png`: cliente de prueba con dos cuentas.
- `08_transaccion.png`: depósito de $250 en cuenta nueva.
- `09_saldo_insuficiente.png`: rechazo del retiro de $300 con saldo de $250.
- `10_solicitud_prestamo.png`: cuota referencial de $112.
- `11_prestamos.png`: filtro de préstamos atrasados.
- `12_empleado.png`: registro de empleado con jefe.
- `13_auditoria_prototipo.png`: historial local del navegador.
- `14_inicio_movil.png`: vista móvil de 390 × 844 píxeles durante el recorrido.
- `15_clientes.png` y `16_empleados.png`: listados después de restablecer la semilla.

Las capturas de formularios se toman directamente del diálogo visible. El resto conserva el área visible de la página. El recorrido usa un navegador aislado; las altas y modificaciones son reales dentro del almacenamiento local de ese contexto, y no se presentan como cambios en SQL Server. Después de las pruebas se restableció la demostración.

## Secuencia de trabajo

1. Lectura de los cuatro PDF y cinco diagramas de Fase I, más la guía de Fase II.
2. Ajuste del modelo, separación de clientes y cuentas y definición de datos derivados.
3. Creación de la base, relaciones, vistas y trigger en SQL Server Express.
4. Corrección durante la primera instalación de un patrón de formato DUI; repetición sobre la base nueva vacía y carga final satisfactoria.
5. Ejecución de consultas, prueba multirregistro y pruebas de integridad con reversión.
6. Implementación del prototipo y recorrido automatizado con capturas.
7. Elaboración del DOCX, exportación a PDF mediante Word y revisión visual de las veinte páginas.
8. Empaquetado de los entregables con las referencias originales.

Las evidencias corresponden al estado probado. Modificar posteriormente la semilla, los scripts o el sitio puede cambiar los resultados.
