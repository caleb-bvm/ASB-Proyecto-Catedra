# FonaVitSV — Proyecto de Cátedra Fase II

## Abrir el sitio

Haz doble clic en **Iniciar.cmd** en esta carpeta. Se abrirá **http://127.0.0.1:8765/**. Deja la ventana del servidor abierta durante el uso. También puedes ejecutar `./Iniciar.ps1` en PowerShell. Si ya está funcionando en ese puerto, el iniciador vuelve a abrirlo.

El prototipo **está conectado a SQL Server**: consulta y guarda en **FonaVitSV_Fase2**, instancia `.\SQLEXPRESS`, usando la cuenta Windows que ejecuta el servidor. Los formularios guardan clientes, empleados, cuentas, movimientos y préstamos. Auditoría muestra los eventos reales del trigger de CLIENTE. No se guardan registros en el almacenamiento del navegador.

Para entrar, pulsa **Entrar al prototipo**, o usa DUI `20000001-1` y contraseña `Demo2026!`. El acceso sigue siendo una sesión de demostración; la base original no incluye usuarios ni contraseñas. Los datos de la semilla son ficticios.

Necesita **Node.js 22 o posterior**, SQL Server y **sqlcmd**. Las herramientas ya están disponibles en este equipo. El servidor no necesita paquetes npm. No abras `Prototipo/index.html` directamente: el sitio necesita el servidor. En Ayuda, **Actualizar datos de la base** vuelve a consultar los registros; también se actualizan al recargar la página. No hay botón que borre o restablezca la base.

Para presentar: entra a Clientes, registra uno, abre otra cuenta desde su perfil, deposita $250, retira $50 e intenta retirar $300. Después registra un préstamo de $1,200 al 12% anual por 12 meses: la cuota referencial es $112. Consulta Auditoría para ver el alta y la modificación del cliente. Estos pasos sí modifican la base de datos.

## SQL Server

En este equipo ya se creó y verificó **FonaVitSV_Fase2** en `.\SQLEXPRESS`, con autenticación Windows. No es necesario volver a instalarla.

Para instalar en otra instancia vacía, ejecuta con sqlcmd disponible:

```powershell
cd SQL
.\Instalar.ps1 -Servidor '.\SQLEXPRESS'
```

Alternativamente, abre los scripts en SSMS y ejecuta **01, 02 y 03**, en ese orden. Antes de ejecutar 01 verifica que **FonaVitSV_Fase2 no exista**. La instalación con Instalar.ps1 se detiene al encontrarla. En SSMS ejecuta 01 solo sobre una instancia donde ese nombre esté libre; SSMS puede continuar lotes después de un error.

Después ejecuta **04_consultas.sql**, **05_pruebas.sql** y **06_integridad.sql**. Los scripts 05 y 06 están preparados para la semilla original. Revierten sus cambios; pueden dejar saltos en identificadores IDENTITY, que es comportamiento normal de SQL Server. La semilla 03 se ejecuta una sola vez. No se incluye ningún borrado automático de la base.

Se usó SQL Server 2025 Express 17.0.1000.7. La sintaxis está diseñada para SQL Server 2016 SP1 o posterior; la ejecución se verificó en la versión instalada.

## Contenido

- **Proyecto_ASB.docx**: documento de la entrega anterior, partes 01 a 05, manual técnico y evidencias. Su descripción del prototipo independiente es histórica; la conexión actual se explica en este LEEME y en `Servidor/LEEME.md`.
- **Proyecto_ASB.pdf**: copia para el formato solicitado por el enunciado.
- **SQL/**: creación, tablas, vistas, trigger, datos, consultas y pruebas.
- **Prototipo/**: interfaz HTML, CSS y JavaScript que consume la API local.
- **Servidor/**: API en Node.js sin paquetes externos; usa sqlcmd para comunicarse con SQL Server.
- **Iniciar.cmd / Iniciar.ps1**: iniciadores del prototipo conectado.
- **Diagramas/**: modelo relacional y clases actualizados, PNG y SVG editable; relaciones también en Mermaid.
- **Evidencias/**: capturas reales del sitio y de reportes basados en resultados reales de SQL Server; archivos TXT y JSON para comprobar los resultados.
- **Pruebas/**: recorrido automatizado opcional del prototipo.
- **Referencias_Fase1/**: materiales originales preservados como antecedentes.

La semilla contiene 20 empleados, 20 clientes, 25 cuentas, 50 transacciones, 20 préstamos y 20 eventos de auditoría generados por el trigger. No se insertaron eventos de auditoría artificialmente.

## Decisiones y alcance

Se mantiene la estructura de los mockups de Fase I y se adopta una paleta cálida inspirada en Material 3 Expressive. Se derivan edad y saldo, y el deudor del préstamo se obtiene mediante la cuenta. AUDITORIA conserva antes y después en JSON sin FK para permitir registrar eliminaciones.

La cuota usa interés simple anual, sin seguros ni comisiones. Registrar un préstamo no abona automáticamente su monto a la cuenta. No se implementan pagos parciales, amortización, intereses compuestos ni mora automática. “Cartera vigente” muestra capital original de préstamos no marcados como pagados, no saldo pendiente de cobro.

La base aplica PK, FK, UNIQUE y CHECK. El servidor valida saldo suficiente, fechas, precisión monetaria, relaciones y ciclos de jefatura. Crear un cliente y su primera cuenta ocurre en una única transacción; un fallo revierte también el evento del trigger. Los retiros mantienen bloqueos hasta confirmar el cambio, para evitar que dos solicitudes gasten el mismo saldo. El trigger audita CLIENTE; no se afirma auditoría completa de todas las tablas. Es una entrega académica con acceso de demostración.

## Revisión antes de entregar

Comprueben nombres y carnets de la portada, revisen las conclusiones y practiquen la explicación de las consultas y el trigger. El enunciado advierte sobre el uso excesivo de IA: este material recibió asistencia de IA y debe revisarse y adaptarse por el equipo, conforme a las reglas de la docente. No se ha enviado nada al aula virtual.

La copia actualizada del código conectado se empaqueta como **ProyCatedra_ASB_Conectado.zip**. El ZIP anterior se conserva como antecedente. El documento Word y las evidencias anteriores aún describen la versión independiente; revisen esa parte antes de una entrega académica. La fecha indicada en la guía es **20 de octubre**. Verifiquen el horario exacto en el aula virtual.

## Repetir las pruebas del sitio de forma opcional

El sitio necesita Node y sqlcmd. Playwright solo se usa para las pruebas opcionales y se mantiene fuera del proyecto. Ejecuta `node Pruebas/prototipo.cjs` con Playwright disponible externamente. `CHROME_PATH` permite elegir un navegador instalado.

El recorrido crea una base temporal con nombre `FonaVitSV_Test_...`, carga allí los scripts 01 a 03, inicia su propio servidor en el puerto 8766 y prueba los formularios, persistencia, auditoría, rollback y retiros simultáneos. Al finalizar elimina únicamente esa base temporal. **No escribe en FonaVitSV_Fase2.** Se puede configurar `FONAVIT_TEST_SERVER` y `FONAVIT_TEST_PORT`. La cuenta Windows necesita permisos para crear y eliminar la base de pruebas. El resultado se guarda en `Evidencias/19_pruebas_conexion_sql.json`.
