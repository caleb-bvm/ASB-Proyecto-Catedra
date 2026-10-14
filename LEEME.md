# FonaVitSV — Proyecto de Cátedra Fase II

## Abrir el sitio

Abre **Prototipo/index.html** con Chrome o Edge. No requiere instalación, internet ni base de datos. Pulsa **Explorar demostración**, o usa DUI `20000001-1` y contraseña `Demo2026!`.

El sitio es un prototipo académico con datos ficticios y almacenamiento local. **No está conectado a SQL Server.** La Parte 05 permite esta modalidad. Cambiar datos en el sitio no cambia la base SQL, y viceversa. El acceso es simulado, no autenticación de producción. La pantalla Ayuda permite restablecer la demostración.

Para presentar: entra a Clientes, registra uno, abre otra cuenta desde su perfil, deposita $250, retira $50 e intenta retirar $300. Después registra un préstamo de $1,200 al 12% anual por 12 meses: la cuota referencial es $112. Consulta Auditoría para ver los cambios locales.

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

- **Proyecto_ASB.docx**: documento editable, partes 01 a 05, manual técnico y evidencias.
- **Proyecto_ASB.pdf**: copia para el formato solicitado por el enunciado.
- **SQL/**: creación, tablas, vistas, trigger, datos, consultas y pruebas.
- **Prototipo/**: sitio HTML, CSS y JavaScript sin dependencias.
- **Diagramas/**: modelo relacional y clases actualizados, PNG y SVG editable; relaciones también en Mermaid.
- **Evidencias/**: capturas reales del sitio y de reportes basados en resultados reales de SQL Server; archivos TXT y JSON para comprobar los resultados.
- **Pruebas/**: recorrido automatizado opcional del prototipo.
- **Referencias_Fase1/**: materiales originales preservados como antecedentes.

La semilla contiene 20 empleados, 20 clientes, 25 cuentas, 50 transacciones, 20 préstamos y 20 eventos de auditoría generados por el trigger. No se insertaron eventos de auditoría artificialmente.

## Decisiones y alcance

Se mantiene la estructura de los mockups de Fase I y se adopta una paleta cálida inspirada en Material 3 Expressive. Se derivan edad y saldo, y el deudor del préstamo se obtiene mediante la cuenta. AUDITORIA conserva antes y después en JSON sin FK para permitir registrar eliminaciones.

La cuota usa interés simple anual, sin seguros ni comisiones. Registrar un préstamo no abona automáticamente su monto a la cuenta. No se implementan pagos parciales, amortización, intereses compuestos ni mora automática. “Cartera vigente” muestra capital original de préstamos no marcados como pagados, no saldo pendiente de cobro.

La base aplica PK, FK, UNIQUE y CHECK. La validación de saldo suficiente, fechas y ciclos de jefatura del prototipo ocurre en JavaScript, no en un servidor. El trigger audita CLIENTE; no se afirma auditoría completa de todas las tablas. Es una entrega académica, no un sistema bancario listo para uso real.

## Revisión antes de entregar

Comprueben nombres y carnets de la portada, revisen las conclusiones y practiquen la explicación de las consultas y el trigger. El enunciado advierte sobre el uso excesivo de IA: este material recibió asistencia de IA y debe revisarse y adaptarse por el equipo, conforme a las reglas de la docente. No se ha enviado nada al aula virtual.

El archivo solicitado para entregar es **ProyCatedra_ASB.zip**. La fecha indicada en la guía es **20 de octubre**. Verifiquen el horario exacto en el aula virtual.

## Repetir las pruebas del sitio de forma opcional

El sitio no necesita Node ni Playwright para usarse. Solo para ejecutar `Pruebas/prototipo.cjs` se necesita Node y Playwright, y un servidor estático que publique la carpeta ProyCatedra_ASB en el puerto 8765. Se puede configurar `PROTOTIPO_URL` para otra dirección y `CHROME_PATH` para un navegador instalado. El recorrido usa un contexto aislado y no modifica los datos del navegador personal.
