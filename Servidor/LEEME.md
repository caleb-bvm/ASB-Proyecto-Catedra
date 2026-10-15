# Prototipo conectado — 14 de octubre de 2026

La interfaz conserva el diseño de FonaVitSV. Se reemplazó el guardado local por una API que usa SQL Server con autenticación Windows. No se cambia el esquema de la base existente ni se vuelve a ejecutar su semilla.

## Iniciar

Usa `Iniciar.cmd` desde la carpeta principal. Necesita .NET SDK 10 y la base instalada. La dirección predeterminada es http://127.0.0.1:8765/. El servidor escucha únicamente en el equipo local.

Para otra instancia, define `FONAVIT_CONNECTION_STRING` antes de ejecutar el iniciador. Por ejemplo, en PowerShell:

```powershell
$env:FONAVIT_CONNECTION_STRING = 'Server=.\SQLEXPRESS;Database=FonaVitSV_Fase2;Integrated Security=true;Encrypt=true;TrustServerCertificate=true;Connect Timeout=5'
.\Iniciar.ps1 -Puerto 8765
```

El certificado de la instancia local se acepta expresamente en esta configuración de demostración. No incluyas contraseñas en los archivos del proyecto. La cuenta Windows del proceso debe tener permisos de lectura y escritura en la base.

## Funcionamiento

- `GET /api/health`: comprueba la conexión.
- `GET /api/data`: obtiene clientes, empleados, cuentas, transacciones, préstamos y auditoría desde SQL.
- `POST /api/records`: registra o modifica un elemento y devuelve el estado actualizado después de confirmar la transacción. Recibe `kind`, `id` y `values`. Operaciones: `client`, `employee`, `account`, `transaction`, `loan`, `status`.

Los valores ingresados se envían como parámetros SQL. El servidor valida los datos incluso si la solicitud no procede del formulario. Los montos aceptan dos decimales; la fecha de operación debe estar entre la apertura y el día actual en Guatemala.

Se usa una transacción serializable por operación y un bloqueo de aplicación para ordenar las solicitudes del prototipo. Al retirar, se bloquean la cuenta y los movimientos mientras se valida el saldo y se inserta el retiro. Los números de cuenta se asignan en el servidor. Las jefaturas se validan recorriendo la cadena de responsables.

Crear un cliente y su primera cuenta es atómico. El trigger existente registra los cambios de CLIENTE en la misma transacción. La API consulta AUDITORIA sin fabricar eventos de otras tablas. Registrar préstamos no abona dinero a las cuentas; el estado sigue siendo manual.

La sesión de acceso continúa siendo demostrativa. No hay autenticación de usuarios en el servidor ni roles de aplicación; la API es local y usa los permisos Windows del proceso. Se rechazan orígenes externos y el contenido del sitio se sirve desde el mismo servidor.

## Comprobar

`Pruebas/prototipo.cjs` crea una base temporal propia, comprueba formularios y SQL con Playwright y la elimina al finalizar. Ver `Evidencias/19_pruebas_conexion_sql.json`. Las evidencias 00 a 18 y el documento Word corresponden a la versión anterior y se conservan como antecedentes.
