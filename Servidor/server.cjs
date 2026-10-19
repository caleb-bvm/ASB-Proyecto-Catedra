'use strict';
// Sin paquetes externos: HTTP y procesos son módulos incluidos en Node.
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const { spawn } = require('node:child_process');
const instance = process.env.FONAVIT_SERVER || '.\\SQLEXPRESS';
const database = process.env.FONAVIT_DATABASE || 'FonaVitSV_Fase2';
const root = path.resolve(__dirname, '../Prototipo');
const today = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Guatemala' }).format(new Date());
class ValidationError extends Error {}
function check(condition, message) { if (!condition) throw new ValidationError(message); }
function validate(op) {
  check(op && typeof op === 'object' && Number.isInteger(op.id) && op.id >= 0 && op.values && typeof op.values === 'object' && !Array.isArray(op.values), 'Solicitud inválida.');
  const v = op.values;
  check(Object.values(v).every(x => typeof x === 'string'), 'Los campos deben ser texto.');
  const text = (key, max) => { const s = (v[key] || '').trim(); check(s.length > 0 && s.length <= max, `Revisa el campo ${key}: es obligatorio y admite hasta ${max} caracteres.`); v[key] = s; return s; };
  const number = (key, min, max, integer = false) => { const s = v[key] || ''; const n = Number(s); check((integer ? /^\d+$/ : /^\d+(?:\.\d+)?$/).test(s) && Number.isFinite(n) && n >= min && n <= max && (integer ? Number.isInteger(n) : /^\d+(?:\.\d{1,2}0*)?$/.test(s)), `Revisa el campo ${key}: rango ${min} a ${max}, ${integer ? 'solo enteros' : 'máximo dos decimales'}.`); };
  const date = key => { const s = v[key]; check(typeof s === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s) && Number.isFinite(Date.parse(s)) && new Date(s).toISOString().slice(0, 10) === s, 'Ingresa una fecha válida.'); check(s <= today(), 'La fecha no puede ser posterior a hoy.'); };
  const dui = () => check(/^[0-9]{8}-[0-9]$/.test(text('dui', 10)), 'El DUI debe tener el formato 00000000-0.');
  if (['client', 'employee'].includes(op.kind)) {
    for (const [k, max] of Object.entries({ name:120, street:120, house:20, city:80, department:80 })) text(k, max);
    dui(); date('birth'); check(v.birth >= '1900-01-01', 'Revisa la fecha de nacimiento.');
    if (op.kind === 'client') { check(['Soltero/a','Casado/a','Acompañado/a','Divorciado/a','Viudo/a'].includes(text('family',20)), 'Estado familiar inválido.'); text('beneficiary',120); }
    else { text('role',60); number('salary',0.01,9999999999.99); v.boss = (v.boss || '').trim(); if (v.boss) number('boss',1,2147483647,true); }
  } else if (op.kind === 'account') check(op.id > 0, 'Selecciona un cliente válido.');
  else if (['transaction','loan'].includes(op.kind)) {
    text('account',20); date('date'); number('amount',0.01,9999999999.99); number('employee',1,2147483647,true);
    if (op.kind === 'transaction') { dui(); check(['deposit','withdraw'].includes(text('type',10)), 'Tipo de movimiento inválido.'); }
    else { number('rate',0,100); number('months',1,360,true); }
  } else if (op.kind === 'status') check(['Al día','Atrasado','Pagado'].includes(text('status',12)), 'Estado de préstamo inválido.');
  else throw new ValidationError('Operación no disponible.');
}
async function sql(query) {
  const temporary = await fs.mkdtemp(path.join(os.tmpdir(),'fonavit-sql-'));
  const output = path.join(temporary,'respuesta.txt');
  try { return await new Promise((resolve, reject) => {
    // El SQL viaja por stdin, sin shell ni sustitución de variables de sqlcmd.
    // -f fija la codificación de archivos; sin -o sqlcmd usa la de la consola.
    const child = spawn(process.env.FONAVIT_SQLCMD || 'sqlcmd', ['-S',instance,'-d',database,'-E','-C','-b','-x','-f','i:65001,o:65001','-o',output,'-y','0','-w','65535','-l','5','-t','30'], { windowsHide:true });
    let out = '', err = ''; const timer = setTimeout(() => { child.kill(); reject(new Error('SQL Server excedió el tiempo de espera.')); }, 35000);
    child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8');
    child.stdout.on('data', b => out += b); child.stderr.on('data', b => err += b);
    child.on('error', e => { clearTimeout(timer); reject(e); });
    child.stdin.on('error', () => {});
    child.on('close', async code => {
      clearTimeout(timer);
      try {
        out = (await fs.readFile(output,'utf8')).replace(/^\uFEFF/,'');
        if (code !== 0) reject(new Error(out || err));
        else resolve(JSON.parse(out.trim()));
      } catch (e) { reject(e); }
    });
    // También preserva los acentos del SQL en consolas Windows con otra página de códigos.
    child.stdin.end('DECLARE @script nvarchar(max)=CONVERT(nvarchar(max),0x' + Buffer.from(query,'utf16le').toString('hex') + '); EXEC sys.sp_executesql @script;\nGO\n');
  }); } finally { await fs.rm(temporary,{recursive:true,force:true}); }
}
async function run(op) {
  if (op) validate(op);
  // UTF-16 hexadecimal: los datos nunca se concatenan como instrucciones SQL.
  const payload = Buffer.from(JSON.stringify(op || {}), 'utf16le').toString('hex');
  const script = await fs.readFile(path.join(__dirname,'operaciones.sql'),'utf8');
  return sql(`SET NOCOUNT ON; SET XACT_ABORT ON; DECLARE @payload nvarchar(max)=CONVERT(nvarchar(max),0x${payload});\n${script}`);
}
const types = { '.html':'text/html', '.css':'text/css', '.js':'text/javascript', '.json':'application/json', '.svg':'image/svg+xml', '.png':'image/png', '.ico':'image/x-icon', '.jpg':'image/jpeg' };
const server = http.createServer(async (req,res) => {
  const json = (status, data) => { res.writeHead(status, {'Content-Type':'application/json; charset=utf-8'}); res.end(JSON.stringify(data)); };
  res.setHeader('X-Content-Type-Options','nosniff');
  try {
    const host = req.headers.host || '';
    if (!/^(127\.0\.0\.1|localhost)(:\d+)?$/.test(host)) return json(403,{error:'Host no permitido.'});
    const url = new URL(req.url, `http://${host}`);
    if (url.pathname.startsWith('/api')) {
      res.setHeader('Cache-Control','no-store');
      if (req.headers.origin && req.headers.origin !== `http://${host}`) return json(403,{error:'Origen no permitido.'});
      if (req.method === 'GET' && url.pathname === '/api/health') return json(200,await sql('SET NOCOUNT ON; SELECT CAST(1 AS bit) connected,DB_NAME() [database],CONVERT(nvarchar(128),SERVERPROPERTY(\'ServerName\')) server FOR JSON PATH,WITHOUT_ARRAY_WRAPPER;'));
      if (req.method === 'GET' && url.pathname === '/api/data') return json(200,await run(null));
      if (req.method === 'POST' && url.pathname === '/api/records') {
        let length = 0; const chunks = [];
        for await (const chunk of req) { length += chunk.length; if (length > 32768) return json(413,{error:'Solicitud demasiado grande.'}); chunks.push(chunk); }
        let op; try { op = JSON.parse(Buffer.concat(chunks).toString('utf8')); } catch { throw new ValidationError('Solicitud JSON inválida.'); }
        check(op !== null, 'Solicitud inválida.'); return json(200,await run(op));
      }
      return json(404,{error:'Ruta de API no disponible.'});
    }
    if (!['GET','HEAD'].includes(req.method)) return json(405,{error:'Método no permitido.'});
    const file = path.resolve(root, '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname));
    if (!file.startsWith(root + path.sep)) return json(403,{error:'Ruta no permitida.'});
    const content = await fs.readFile(file);
    res.writeHead(200, {'Content-Type':(types[path.extname(file)] || 'application/octet-stream') + '; charset=utf-8','Cache-Control':'no-cache'}); res.end(req.method === 'HEAD' ? undefined : content);
  } catch (e) {
    if (e.code === 'ENOENT' || e.code === 'EISDIR') return json(404,{error:'Archivo no disponible.'});
    if (e instanceof ValidationError) return json(400,{error:e.message});
    console.error(e.message);
    const custom = e.message.match(/VALIDACION:([^\r\n]+)/);
    if (custom) return json(400,{error:custom[1].trim()});
    if (/\b(2601|2627)\b/.test(e.message)) return json(409,{error:'Este documento o número de cuenta ya está registrado.'});
    if (/\b(547|1205)\b/.test(e.message)) return json(409,{error:'SQL Server rechazó el cambio por una relación o una operación simultánea.'});
    json(503,{error:'No se pudo operar con SQL Server. Comprueba la instancia y la base de datos.'});
  }
});
const port = Number(process.env.FONAVIT_PORT || 8765);
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Puerto inválido.');
server.on('error', e => { console.error(e.message); process.exitCode = 1; });
server.listen(port,'127.0.0.1',() => console.log(`FonaVitSV: http://127.0.0.1:${port}/`));
