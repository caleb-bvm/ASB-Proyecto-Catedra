// Integración en una base temporal propia. No escribe en FonaVitSV_Fase2.
// Requiere .NET SDK 10, SQL Server, sqlcmd, Node y Playwright.
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {spawn,spawnSync}=require('node:child_process'),{randomUUID}=require('node:crypto');
const root=path.resolve(__dirname,'..'),database='FonaVitSV_Test_'+randomUUID().replaceAll('-','');
const instance=process.env.FONAVIT_TEST_SERVER||'.\\SQLEXPRESS',port=Number(process.env.FONAVIT_TEST_PORT||8766);
assert.ok(Number.isInteger(port)&&port>=1024&&port<=65535);
const base=`http://127.0.0.1:${port}/`,temp=fs.mkdtempSync(path.join(os.tmpdir(),'fonavit-test-'));
const results=[],errors=[];let server,browser,created=false,serverOutput='';
const ok=prueba=>{results.push({prueba,resultado:'PASS'});console.log('PASS: '+prueba);};
function sql(query,db='master'){
 const r=spawnSync('sqlcmd',['-S',instance,'-E','-C','-b','-f','65001','-d',db,'-h','-1','-W','-Q',query],{encoding:'utf8',windowsHide:true,timeout:30000});
 if(r.status!==0)throw Error(r.stderr||r.stdout||String(r.error));return r.stdout.trim();
}
function install(){
 for(const file of ['01_base_y_tablas.sql','02_vistas_y_trigger.sql','03_datos.sql']){
  const target=path.join(temp,file);
  fs.writeFileSync(target,fs.readFileSync(path.join(root,'SQL',file),'utf8').replaceAll('FonaVitSV_Fase2',database));
  const r=spawnSync('sqlcmd',['-S',instance,'-E','-C','-b','-f','65001','-i',target],{encoding:'utf8',windowsHide:true,timeout:30000});
  if(file==='01_base_y_tablas.sql')created=sql(`SET NOCOUNT ON; SELECT CASE WHEN DB_ID(N'${database}') IS NULL THEN 0 ELSE 1 END;`)==='1';
  if(r.status!==0)throw Error(r.stderr||r.stdout||String(r.error));
 }
}
async function api(kind,id=0,values={}){
 const r=await fetch(base+'api/records',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({kind,id,values})});
 return {status:r.status,data:await r.json()};
}
async function state(){const r=await fetch(base+'api/data');assert.equal(r.status,200);return r.json();}
const person={name:'Cliente de prueba integración',dui:'88888888-8',birth:'1995-04-12',street:'Calle Prueba',house:'12',city:'Santa Tecla',department:'La Libertad',family:'Soltero/a',beneficiary:'Beneficiario de prueba'};
const formPerson=Object.fromEntries(Object.entries(person).filter(([k])=>k!=='family'));
const totals=db=>sql("SET NOCOUNT ON; SELECT CONCAT((SELECT COUNT(*) FROM dbo.CLIENTE),'|',(SELECT COUNT(*) FROM dbo.CUENTA),'|',(SELECT COUNT(*) FROM dbo.TRANSACCION),'|',(SELECT COUNT(*) FROM dbo.PRESTAMO),'|',(SELECT COUNT(*) FROM dbo.AUDITORIA));",db);
(async()=>{
 const original=totals('FonaVitSV_Fase2');
 try{
  install();
  server=spawn('dotnet',['run','--project',path.join(root,'Servidor','FonaVitSV.csproj'),'--no-build','--no-launch-profile'],{cwd:path.join(root,'Servidor'),windowsHide:true,env:{...process.env,FONAVIT_PORT:String(port),FONAVIT_CONNECTION_STRING:`Server=${instance};Database=${database};Integrated Security=true;Encrypt=true;TrustServerCertificate=true;Connect Timeout=5`}});
  server.stdout.on('data',b=>serverOutput+=b);server.stderr.on('data',b=>serverOutput+=b);server.on('error',e=>errors.push(e.message));
  let healthy=false;
  for(let i=0;i<60;i++){
   if(server.exitCode!==null)throw Error(serverOutput);
   try{const r=await fetch(base+'api/health');if(r.ok){assert.equal((await r.json()).database,database);healthy=true;break;}}catch(e){if(e instanceof assert.AssertionError)throw e;}
   await new Promise(r=>setTimeout(r,250));
  }
  assert.ok(healthy,'El servidor no inició');
  const initial=await state();assert.equal(initial.clients.length,20);assert.equal(initial.accounts.length,25);assert.equal(initial.audit.length,20);ok('Lectura de las seis tablas desde SQL Server');
  browser=await chromium.launch({headless:true,...(process.env.CHROME_PATH?{executablePath:process.env.CHROME_PATH}:{})});
  const page=await browser.newPage({viewport:{width:1440,height:1100}});page.on('pageerror',e=>errors.push(e.message));
  const action=a=>page.locator(`[data-action="${a}"]`).first().click();
  const fill=async values=>{for(const [k,v]of Object.entries(values))await page.locator(`#record-form [name="${k}"]`).fill(String(v));};
  const submit=async()=>{await page.locator('#record-form button[type=submit]').click();await page.waitForFunction(()=>!document.querySelector('#record-form button[type=submit]')?.disabled);};
  const saved=()=>page.locator('dialog').waitFor({state:'hidden'});
  await page.goto(base);await page.locator('#login-form').waitFor();
  await page.locator('[name=dui]').fill('20000001-1');await page.locator('[name=password]').fill('incorrecta');await page.locator('#login-form button').click();assert.match(await page.locator('#login-error').innerText(),/credenciales/);
  await page.locator('[name=password]').fill('Demo2026!');await page.locator('#login-form button').click();await page.locator('.hero').waitFor();ok('Acceso de demostración y pantalla de inicio');
  await action('new-client');await fill(formPerson);await submit();await saved();
  let current=await state();const customer=current.clients.find(x=>x.dui===person.dui);assert.ok(customer);
  assert.equal(current.clients.length,21);assert.equal(current.accounts.length,26);assert.equal(current.audit.length,21);
  const account=current.accounts.find(x=>x.client===customer.id).id;
  assert.equal(sql(`SET NOCOUNT ON; SELECT beneficiario FROM dbo.CLIENTE WHERE codigo_cliente=${customer.id};`,database),person.beneficiary);ok('Cliente, primera cuenta y auditoría guardados desde el formulario');
  await page.goto(base+'#clients');await page.locator('#search').fill(person.dui);assert.equal(await page.locator('tbody tr').count(),1);
  await action('client-detail');await action('add-account');await page.waitForFunction(()=>document.querySelectorAll('.account-card').length===2);await action('close');assert.equal((await state()).accounts.length,27);ok('Segunda cuenta abierta desde el perfil');
  await action('client-detail');await action('edit-client');await fill({name:"Cliente O'Connor <prueba>",beneficiary:'Beneficiario editado'});await submit();await saved();
  await page.reload();await page.locator('#search').fill(person.dui);assert.match(await page.locator('tbody').innerText(),/O'Connor <prueba>/);
  const audit=(await state()).audit.at(-1);assert.equal(audit.operation,'UPDATE');assert.equal(JSON.parse(audit.before).beneficiario,person.beneficiary);assert.equal(JSON.parse(audit.after).beneficiario,'Beneficiario editado');ok('Edición, parámetros SQL, escape HTML y persistencia tras recarga');
  assert.equal((await api('client',0,person)).status,409);assert.equal((await state()).clients.length,21);assert.equal((await state()).accounts.length,27);ok('DUI duplicado rechazado en servidor sin cuenta adicional');
  sql("CREATE TRIGGER dbo.tr_CUENTA_Prueba ON dbo.CUENTA AFTER INSERT AS BEGIN THROW 50070,'Fallo controlado',1; END;",database);
  try{assert.equal((await api('client',0,{...person,dui:'88888887-7'})).status,503);assert.equal((await state()).clients.length,21);assert.equal((await state()).audit.length,22);}
  finally{sql('DROP TRIGGER dbo.tr_CUENTA_Prueba;',database);}ok('Rollback de cliente y auditoría si falla su primera cuenta');
  await page.goto(base+'#transactions');await action('new-transaction');await page.locator('[name=account]').selectOption(account);await fill({amount:250});await submit();await saved();assert.equal((await state()).transactions.at(-1).amount,250);ok('Depósito desde formulario confirmado en SQL');
  await action('new-transaction');await page.locator('[name=account]').selectOption(account);await page.locator('[name=type]').selectOption('withdraw');await fill({amount:300});await submit();assert.match(await page.locator('#form-error').innerText(),/Saldo insuficiente/);ok('Retiro sin saldo rechazado en formulario');
  await fill({amount:50});await submit();await saved();assert.equal((await state()).transactions.at(-1).amount,-50);ok('Retiro válido guardado con monto negativo');
  const date=(await state()).accounts.find(x=>x.id===account).date,movement={account,employee:'1',dui:person.dui,type:'withdraw',amount:'150',date};
  const races=await Promise.all([api('transaction',0,movement),api('transaction',0,movement)]);assert.deepEqual(races.map(x=>x.status).sort(),[200,400]);
  const balance=()=>Number(sql(`SET NOCOUNT ON; SELECT saldo_actual FROM dbo.vw_SaldosCuenta WHERE numero_cuenta='${account}';`,database));assert.equal(balance(),50);ok('Dos retiros simultáneos no gastan el mismo saldo');
  for(const values of [{amount:'0'},{amount:'0.001'},{type:'otro'},{employee:'999999'},{date:'2020-01-01'},{date:'2099-01-01'},{dui:'123'}])assert.equal((await api('transaction',0,{...movement,type:'deposit',amount:'1',...values})).status,400);
  ok('Servidor valida montos, precisión, tipo, empleado, fechas y DUI');
  assert.ok((await Promise.all([api('account',customer.id),api('account',customer.id)])).every(x=>x.status===200));current=await state();assert.equal(new Set(current.accounts.map(x=>x.id)).size,current.accounts.length);ok('Cuentas simultáneas reciben números únicos');
  await page.goto(base+'#loans');await action('new-loan');await page.locator('[name=account]').selectOption(account);await fill({amount:1200,rate:12,months:12});assert.match(await page.locator('#quote').innerText(),/112/);await submit();await saved();
  const loan=(await state()).loans.at(-1);assert.equal(loan.amount,1200);assert.equal(Number(sql(`SET NOCOUNT ON; SELECT cuota_referencial FROM dbo.vw_CarteraPrestamos WHERE codigo_prestamo=${loan.id};`,database)),112);assert.equal(balance(),50);
  await page.locator(`[data-action=loan-status][data-id="${loan.id}"]`).click();await page.locator('[name=status]').selectOption('Pagado');await submit();await saved();assert.equal((await state()).loans.at(-1).status,'Pagado');ok('Préstamo, cuota SQL y estado; sin abono automático');
  await page.goto(base+'#employees');await action('new-employee');await fill({...Object.fromEntries(Object.entries(formPerson).filter(([k])=>k!=='beneficiary')),name:'Empleado de prueba',dui:'77777777-7',role:'Caja',salary:650});await page.locator('[name=boss]').selectOption('1');await submit();await saved();
  const employee=(await state()).employees.at(-1),boss=(await state()).employees.find(x=>x.id===1);assert.equal(employee.boss,1);
  const bossValues=Object.fromEntries(Object.entries(boss).filter(([k])=>k!=='id').map(([k,v])=>[k,v==null?'':String(v)]));assert.equal((await api('employee',1,{...bossValues,boss:String(employee.id)})).status,400);assert.equal((await state()).employees.find(x=>x.id===1).boss,boss.boss);ok('Empleado con jefe y rechazo de ciclos en servidor');
  await page.goto(base+'#audit');assert.equal(await page.locator('tbody tr').count(),22);await action('audit-detail');assert.match(await page.locator('dialog').innerText(),/CLIENTE/);await action('close');ok('Auditoría muestra eventos reales del trigger');
  await page.goto(base+'#transactions');const downloaded=page.waitForEvent('download');await action('export');assert.equal((await downloaded).suggestedFilename(),'FonaVitSV_movimientos.csv');ok('Exportación CSV de movimientos SQL');
  const other=await browser.newContext(),second=await other.newPage();await second.goto(base);await second.locator('[data-action=demo]').waitFor();await second.locator('[data-action=demo]').click();await second.goto(base+'#clients');await second.locator('#search').fill(person.dui);assert.match(await second.locator('tbody').innerText(),/O'Connor/);await other.close();ok('Datos visibles en otro navegador sin almacenamiento local');
  await page.setViewportSize({width:390,height:844});await page.goto(base+'#home');assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await action('new-client');assert.ok(await page.evaluate(()=>document.querySelector('dialog').getBoundingClientRect().width<=innerWidth));await action('close');ok('Vista y formulario adaptados a móvil');
  await page.goto(base+'#settings');assert.equal(await page.locator('[data-action=reset]').count(),0);await action('refresh');await page.locator('[data-action=refresh]').waitFor();ok('Actualizar registros sin borrar la base');
  assert.equal((await fetch(base+'api/records',{method:'POST',headers:{'Content-Type':'application/json',Origin:'https://example.com'},body:JSON.stringify({kind:'account',id:customer.id,values:{}})})).status,403);ok('Escrituras de orígenes externos rechazadas');
  const beforeFailure=JSON.stringify(await state());await page.route('**/api/records',r=>r.abort());await page.goto(base+'#clients');await action('new-client');await fill({...formPerson,dui:'88888886-6'});await submit();assert.match(await page.locator('#form-error').innerText(),/servidor/);assert.equal(JSON.stringify(await state()),beforeFailure);await action('close');await page.unroute('**/api/records');ok('Fallo de conexión visible sin persistencia local');
  await page.route('**/api/data',r=>r.fulfill({status:503,contentType:'application/json',body:JSON.stringify({error:'SQL Server no disponible en prueba'})}));await page.reload();await page.getByRole('heading',{name:'No se pudo abrir la cooperativa'}).waitFor();assert.equal(await page.locator('.hero').count(),0);await page.unroute('**/api/data');await action('refresh');await page.locator('#search').waitFor();ok('Fallo de lectura SQL y recuperación de conexión');
  await page.setViewportSize({width:1440,height:1100});await page.goto(base+'#home');await page.screenshot({path:path.join(root,'Evidencias','20_inicio_conectado_sql.png')});
  assert.deepEqual(errors,[]);ok('Sin errores JavaScript');assert.equal(totals('FonaVitSV_Fase2'),original);ok('Base original preservada');
 }catch(e){errors.push(e.message);throw e;}finally{
  if(browser)await browser.close();
  if(server)spawnSync('taskkill',['/PID',String(server.pid),'/T','/F'],{windowsHide:true,encoding:'utf8'});
  if(created){assert.match(database,/^FonaVitSV_Test_[a-f0-9]{32}$/);sql(`ALTER DATABASE [${database}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [${database}];`);ok('Base temporal de pruebas eliminada');}
  for(const file of fs.readdirSync(temp))fs.unlinkSync(path.join(temp,file));fs.rmdirSync(temp);
  fs.writeFileSync(path.join(root,'Evidencias','19_pruebas_conexion_sql.json'),JSON.stringify({fecha:new Date().toISOString(),base_prueba:database,base_original:'FonaVitSV_Fase2',resultados:results,errores:errors},null,2));
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
