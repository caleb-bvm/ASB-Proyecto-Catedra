# Servidor Node.js

Usa Iniciar.cmd desde la carpeta principal, o `node Servidor/server.cjs`.
Requiere Node.js 22 o posterior, SQL Server y sqlcmd en PATH. No utiliza paquetes npm ni necesita compilación.

La interfaz HTML, CSS y JavaScript se sirve en http://127.0.0.1:8765/.
La conexión usa autenticación Windows mediante sqlcmd, herramienta de SQL Server. La cuenta Windows necesita permisos sobre la base. Se acepta el certificado local con -C.

Configuración opcional en PowerShell:

```powershell
$env:FONAVIT_SERVER = '.\SQLEXPRESS'
$env:FONAVIT_DATABASE = 'FonaVitSV_Fase2'
.\Iniciar.ps1 -Puerto 8765
```

FONAVIT_PORT cambia el puerto al iniciar directamente con Node. FONAVIT_SQLCMD permite indicar la ruta de sqlcmd. FONAVIT_SERVER y FONAVIT_DATABASE sustituyen la antigua variable de cadena de conexión.

- GET /api/health: comprueba la conexión real.
- GET /api/data: obtiene las seis tablas.
- POST /api/records: recibe kind, id y values; operaciones client, employee, account, transaction, loan y status.

Node valida los campos. Los datos se codifican como hexadecimal UTF-16 y SQL Server los lee con OPENJSON en variables tipadas; los datos nunca se interpolan como instrucciones SQL. sqlcmd se ejecuta sin shell y con sustitución de variables desactivada. Cada solicitud abre una conexión mediante sqlcmd; esta solución académica local no utiliza un pool.

Las operaciones conservan la transacción serializable, el bloqueo de aplicación, la primera cuenta automática, el rollback del trigger, la comprobación de saldo y los controles de jefatura. El estado se devuelve después de confirmar la transacción.

El servidor escucha solo en 127.0.0.1, rechaza orígenes externos y limita el JSON a 32 KB. La sesión sigue siendo demostrativa. Los préstamos no abonan dinero automáticamente.
