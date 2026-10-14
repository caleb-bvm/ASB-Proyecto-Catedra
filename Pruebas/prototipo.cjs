// Requiere Node.js y Playwright. Ejecutar con el servidor del prototipo disponible.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const base=process.env.PROTOTIPO_URL||'http://127.0.0.1:8765/Prototipo/';
const out=path.resolve(__dirname,'../Evidencias');
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{})});
 const page=await browser.newPage({viewport:{width:1440,height:1100}}),results=[],errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 const ok=t=>{results.push({prueba:t,resultado:'PASS'});console.log('PASS: '+t);};
 const shot=async n=>{const target=await page.locator('dialog').isVisible()?page.locator('dialog'):page;return target.screenshot({path:path.join(out,n+'.png')});};
 const state=()=>page.evaluate(()=>JSON.parse(localStorage.getItem('fonavit-fase2-v1')));
 const action=a=>page.locator(`[data-action="${a}"]`).first().click();
 const fill=async values=>{for(const [k,v]of Object.entries(values))await page.locator(`#record-form [name="${k}"]`).fill(String(v));};
 const submit=()=>page.locator('#record-form button[type=submit]').click();
 try{
 await page.goto(base);await shot('04_acceso');
 await page.locator('[name=dui]').fill('20000001-1');await page.locator('[name=password]').fill('incorrecta');await page.locator('#login-form button').click();assert.match(await page.locator('#login-error').innerText(),/credenciales/);ok('Rechazo de credenciales incorrectas');
 await page.locator('[name=password]').fill('Demo2026!');await page.locator('#login-form button').click();await page.locator('.hero').waitFor();ok('Inicio de sesión de demostración');await shot('05_inicio');
 await action('new-client');await fill({name:'Cliente de prueba QA',dui:'88888888-8',birth:'1995-04-12',street:'Colonia Prueba',house:'12',city:'Santa Tecla',department:'La Libertad',beneficiary:'Beneficiaria de prueba'});await shot('06_registro_cliente');await submit();assert.equal((await state()).clients.length,21);assert.equal((await state()).accounts.length,26);ok('Registro de cliente con primera cuenta automática');
 await page.goto(base+'#clients');await page.locator('#search').fill('88888888-8');assert.equal(await page.locator('tbody tr').count(),1);ok('Búsqueda de cliente por DUI');await action('client-detail');await action('add-account');assert.equal((await state()).accounts.length,27);ok('Varias cuentas por cliente');await shot('07_varias_cuentas');await action('close');
 await action('new-client');await fill({name:'Duplicado',dui:'88888888-8',birth:'1995-04-12',street:'Calle',house:'1',city:'Ciudad',department:'Departamento',beneficiary:'Persona'});await submit();assert.match(await page.locator('#form-error').innerText(),/ya está registrado/);assert.equal((await state()).clients.length,21);ok('Rechazo de DUI duplicado');await action('close');
 await action('client-detail');await action('edit-client');await fill({beneficiary:'Beneficiario editado'});await submit();assert.equal((await state()).clients.at(-1).beneficiary,'Beneficiario editado');ok('Edición de cliente');
 await page.goto(base+'#transactions');await action('new-transaction');await page.locator('[name=account]').selectOption('CTA-2026-0026');await fill({amount:250});await shot('08_transaccion');await submit();assert.equal((await state()).transactions.at(-1).amount,250);ok('Depósito en cuenta nueva');
 await action('new-transaction');await page.locator('[name=account]').selectOption('CTA-2026-0026');await page.locator('[name=type]').selectOption('withdraw');await fill({amount:300});await submit();assert.match(await page.locator('#form-error').innerText(),/Saldo insuficiente/);await shot('09_saldo_insuficiente');ok('Bloqueo de retiro sin saldo');
 await fill({amount:50});await submit();assert.equal((await state()).transactions.at(-1).amount,-50);ok('Retiro con monto negativo en historial');
 await action('new-transaction');await fill({amount:10,date:'2020-01-01'});await submit();assert.match(await page.locator('#form-error').innerText(),/apertura/);ok('Rechazo de movimiento anterior a apertura');await action('close');
 const downloadPromise=page.waitForEvent('download');await action('export');const download=await downloadPromise;assert.equal(download.suggestedFilename(),'FonaVitSV_movimientos.csv');ok('Exportación CSV de movimientos');
 await page.goto(base+'#loans');await action('new-loan');await page.locator('[name=account]').selectOption('CTA-2026-0026');await fill({amount:1200,rate:12,months:12});assert.match(await page.locator('#quote').innerText(),/112/);await shot('10_solicitud_prestamo');await submit();assert.equal((await state()).loans.length,21);ok('Préstamo con cuenta previa y cálculo de cuota');
 await page.locator('[data-action=loan-status]').last().click();await page.locator('[name=status]').selectOption('Atrasado');await submit();await page.locator('[data-action=filter-loan][data-id=Atrasado]').click();assert.equal(await page.locator('.loan').count(),5);ok('Cambio de estado y filtro de préstamos');await shot('11_prestamos');
 await page.goto(base+'#employees');await action('new-employee');await fill({name:'Empleado de prueba QA',dui:'77777777-7',birth:'1992-07-20',street:'Calle Prueba',house:'2',city:'San Salvador',department:'San Salvador',role:'Caja',salary:650});await page.locator('[name=boss]').selectOption('1');await shot('12_empleado');await submit();assert.equal((await state()).employees.length,21);ok('Registro de empleado con jefe');
 await page.locator('[data-action=edit-employee][data-id="1"]').click();await page.locator('[name=boss]').selectOption('21');await submit();assert.match(await page.locator('#form-error').innerText(),/ciclo/);ok('Bloqueo de ciclo en jefatura');await action('close');
 await page.goto(base+'#audit');assert.ok(await page.locator('tbody tr').count()>5);await shot('13_auditoria_prototipo');ok('Historial local de cambios');
 await page.reload();assert.equal((await state()).clients.length,21);ok('Persistencia de datos después de recargar');
 await page.setViewportSize({width:390,height:844});await page.goto(base+'#home');assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await shot('14_inicio_movil');await action('new-client');assert.ok(await page.evaluate(()=>document.querySelector('dialog').getBoundingClientRect().width<=innerWidth));await action('close');ok('Diseño móvil y formulario sin desbordamiento');
 await page.setViewportSize({width:1440,height:1100});await page.goto(base+'#settings');await action('reset');await action('confirm-reset');assert.equal((await state()).clients.length,20);assert.equal((await state()).audit.length,0);ok('Restablecimiento confirmado de datos');
 assert.deepEqual(errors,[]);ok('Sin errores JavaScript durante el recorrido');
 // Captura limpia de clientes y empleados tras restaurar la semilla.
 await page.goto(base+'#clients');await shot('15_clientes');await page.goto(base+'#employees');await shot('16_empleados');
 }finally{fs.writeFileSync(path.join(out,'03_pruebas_prototipo.json'),JSON.stringify({fecha:new Date().toISOString(),navegador:'Chromium',resultados:results,errores:errors},null,2));await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});


