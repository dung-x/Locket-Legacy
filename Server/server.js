// LocketLegacy self-host mock + web dashboard.
// API: POST /locket/login, POST /locket/refresh-token, GET /locket/logout,
// POST /locket/getInfoUser, POST /locket/getAllFriendsV2,
// POST /locket/postMomentV1 (multipart), POST /locket/postMomentV2 (json),
// POST /locket/getMomentV2, POST /locket/getInfoMomentV2, POST /locket/getAllMessageV2
// Dashboard: GET / (human UI with connect QR), GET /api/health, GET /connect
// Data is in-memory + ./uploads on disk. Configure via .env / env vars.
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 5001;
const PUBLIC_API_URL = process.env.PUBLIC_API_URL || ''; // e.g. http://192.168.1.5:5001
const app = express();
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

const UP = path.join(__dirname, 'uploads');
if (!fs.existsSync(UP)) fs.mkdirSync(UP, { recursive: true });
app.use('/uploads', express.static(UP));

const upload = multer({ dest: path.join(UP, 'tmp'), limits: { fileSize: 20 * 1024 * 1024 } });

let moments = [];
let seq = 1;

function ok(res, data, extra = {}) {
  return res.json(Object.assign({ success: true, message: 'ok', data }, extra));
}
function authOk(req) {
  const h = req.headers.authorization || '';
  return h.startsWith('Bearer ') && h.length > 10;
}
// Base URL as the caller's browser sees it (right for LAN QR), unless overridden.
function publicBase(req) {
  if (PUBLIC_API_URL) return PUBLIC_API_URL.replace(/\/+$/, '');
  const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').split(',')[0];
  const host = req.get('host');
  return `${proto}://${host}`;
}
function qrPayload(base) {
  return `locketlegacy://connect?api=${encodeURIComponent(base)}`;
}

// ---------- dashboard / health ----------
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'locketlegacy-mock', moments: moments.length, time: new Date().toISOString() });
});

app.get('/connect', (req, res) => {
  const base = (req.query.base || publicBase(req)).replace(/\/+$/, '');
  res.json({ apiBaseUrl: base, qrPayload: qrPayload(base), ios: 'Login → 📷 Scan QR → point at the dashboard code' });
});

app.get('/', (req, res) => {
  const base = publicBase(req);
  res.type('html').send(DASHBOARD_HTML.replaceAll('__BASE__', base).replaceAll('__QR__', qrPayload(base)));
});

// ---------- API ----------
app.get('/locket/logout', (req, res) => res.json({ success: true, message: 'ok' }));

app.post('/locket/login', (req, res) => {
  const { email } = req.body || {};
  if (!email) return res.status(400).json({ success: false, message: 'email required' });
  return ok(res, {
    kind: 'identitytoolkit#VerifyPasswordResponse',
    localId: 'mock-uid-1',
    email,
    displayName: 'Legacy User',
    idToken: 'mock-id-token-abc123',
    refreshToken: 'mock-refresh-abc123',
    expiresIn: '3600',
  });
});

app.post('/locket/refresh-token', (req, res) => {
  return ok(res, {
    access_token: 'mock-id-token-abc123',
    id_token: 'mock-id-token-abc123',
    refresh_token: 'mock-refresh-abc123',
    expires_in: '3600',
    token_type: 'Bearer',
    user_id: 'mock-uid-1',
  });
});

app.post('/locket/getInfoUser', (req, res) => {
  if (!authOk(req)) return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'missing token' } });
  return ok(res, {
    uid: 'mock-uid-1', localId: 'mock-uid-1', email: 'demo@locket.legacy',
    displayName: 'Legacy User', username: 'legacy', firstName: 'Legacy', lastName: 'User',
    profilePicture: '', createdAt: new Date().toISOString(),
  });
});

app.post('/locket/getAllFriendsV2', (req, res) => {
  if (!authOk(req)) return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'missing token' } });
  return ok(res, [
    { uid: 'friend-1', displayName: 'Dio', profilePicture: '' },
    { uid: 'friend-2', displayName: 'Locket Fan', profilePicture: '' },
  ]);
});

app.post('/locket/postMomentV1', upload.single('file'), (req, res) => {
  if (!authOk(req)) return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'missing token' } });
  let caption = '';
  try { caption = JSON.parse(req.body.optionsData || '{}').caption || ''; } catch (e) { caption = req.body.optionsData || ''; }
  let url = '';
  if (req.file) {
    const ext = path.extname(req.file.originalname || '.jpg') || '.jpg';
    const name = `m${Date.now()}${ext}`;
    fs.renameSync(req.file.path, path.join(UP, name));
    url = `/uploads/${name}`;
  }
  const m = { id: `m${seq++}`, url, caption, author: 'Legacy User', createdAt: new Date().toISOString() };
  moments.unshift(m);
  return res.json({ success: true, message: 'Upload media successfully', data: m });
});

app.post('/locket/postMomentV2', (req, res) => {
  if (!authOk(req)) return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'missing token' } });
  const { mediaInfo = {}, options = {} } = req.body || {};
  const m = { id: `m${seq++}`, url: mediaInfo.url || '', caption: options.caption || '', author: 'Legacy User', createdAt: new Date().toISOString() };
  moments.unshift(m);
  return res.json({ success: true, message: 'Upload media successfully', data: m });
});

app.post('/locket/getMomentV2', (req, res) => {
  if (!authOk(req)) return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'missing token' } });
  return res.json({ success: true, message: 'ok', data: moments, nextPageToken: null });
});

app.post('/locket/getInfoMomentV2', (req, res) => {
  const { idMoment } = req.body || {};
  const m = moments.find((x) => x.id === idMoment);
  return res.json({ success: true, message: 'ok', data: m ? [m] : [], nextPageToken: null });
});

app.post('/locket/getAllMessageV2', (req, res) => {
  return res.json({ success: true, message: 'ok', data: [], nextPageToken: null });
});

app.listen(PORT, () => console.log(`LocketLegacy mock listening on :${PORT}`));

const DASHBOARD_HTML = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>LocketLegacy API — dashboard</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#0b0b0e;color:#eee;font:14px/1.5 system-ui,sans-serif}
.wrap{max-width:960px;margin:0 auto;padding:24px 16px 64px}h1{font-size:22px;margin:0 0 4px}.sub{color:#999;margin:0 0 20px}
.grid{display:grid;gap:16px;grid-template-columns:1fr}@media(min-width:820px){.grid{grid-template-columns:1fr 1fr}}
.card{background:#15151b;border:1px solid #2a2a33;border-radius:12px;padding:16px}
.card h2{font-size:15px;margin:0 0 10px;color:#ffd75e}label{display:block;font-size:12px;color:#aaa;margin:10px 0 4px}
input,textarea{width:100%;background:#0e0e12;border:1px solid #333;border-radius:8px;color:#fff;padding:9px 10px;font-size:13px}
button{background:#ffd75e;border:0;border-radius:9px;padding:9px 14px;font-weight:700;cursor:pointer;margin-top:10px;color:#111}
button.ghost{background:#26262e;color:#fff}pre{background:#0e0e12;border:1px solid #2c2c35;border-radius:8px;padding:10px;max-height:260px;overflow:auto;font-size:12px;white-space:pre-wrap}
.qrrow{display:flex;gap:16px;align-items:flex-start;flex-wrap:wrap}#qr{background:#fff;padding:10px;border-radius:10px;min-width:190px;min-height:190px;display:flex;align-items:center;justify-content:center}
.mono{font-family:ui-monospace,monospace;font-size:12px;word-break:break-all;color:#9fd08a}
.gallery{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}.gallery img{width:96px;height:96px;object-fit:cover;border-radius:8px;border:1px solid #333}
.row{display:flex;gap:8px}.row>*{flex:1}.ok{color:#7dd87d}.err{color:#ff8a8a}.hint{font-size:12px;color:#888}
</style></head><body><div class="wrap">
<h1>📸 LocketLegacy API <span id="dot">…</span></h1>
<p class="sub">Self-host mock + dashboard. iOS app points its <b>① API SERVER</b> row here.</p>
<div class="grid">
<div class="card"><h2>① Connect — QR for the iOS app</h2>
<div class="qrrow"><div id="qr"></div>
<div style="flex:1;min-width:220px"><label>API base URL (what the phone must reach — use LAN IP, not localhost)</label>
<input id="base" value="__BASE__">
<div class="row"><button id="regen">Regenerate QR</button><button id="copy" class="ghost">Copy URL</button></div>
<p class="hint">On the iPhone: open Locket Legacy → Login → <b>📷 Scan QR</b> → point at this code.<br>Payload: <span class="mono" id="payload">__QR__</span></p></div></div></div>
<div class="card"><h2>② Login tester → POST /locket/login</h2>
<label>Email</label><input id="email" value="demo@locket.legacy"><label>Password</label><input id="pw" type="password" value="demo1234">
<button id="login">Log in</button><pre id="loginOut">—</pre></div>
<div class="card"><h2>③ Data tester (needs Bearer idToken)</h2>
<label>idToken (paste from login — mock accepts any long Bearer)</label><input id="tok" value="mock-id-token-abc123">
<div class="row"><button id="bUser">Get user</button><button id="bFriends">Friends</button><button id="bMoments">Moments</button></div>
<pre id="dataOut">—</pre><div class="gallery" id="gal"></div></div>
<div class="card"><h2>④ Upload tester → POST /locket/postMomentV1</h2>
<label>File (jpg/png/mp4)</label><input id="file" type="file" accept="image/*,video/*"><label>Caption</label><input id="cap" value="Hello from dashboard 📸">
<button id="up">Upload moment</button><pre id="upOut">—</pre>
<p class="hint">Endpoints: <span class="mono">/locket/login · /locket/refresh-token · /locket/logout · /locket/getInfoUser · /locket/getAllFriendsV2 · /locket/postMomentV1 · /locket/postMomentV2 · /locket/getMomentV2 · /locket/getInfoMomentV2 · /locket/getAllMessageV2</span><br>Health: <span class="mono">GET /api/health</span> · Connect JSON: <span class="mono">GET /connect</span></p></div>
</div></div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
<script>
var $=function(id){return document.getElementById(id)};
function show(el,ok){el.className=ok?'ok':'err'}
fetch('/api/health').then(function(r){return r.json()}).then(function(j){$('dot').textContent='● '+j.status+' ('+j.moments+' moments)';show($('dot'),true)}).catch(function(){$('dot').textContent='● unreachable';show($('dot'),false)});
function payloadFor(base){return 'locketlegacy://connect?api='+encodeURIComponent(base.replace(/\\/+$/,''))}
function drawQR(text){var q=$('qr');q.innerHTML='';try{if(window.QRCode){new QRCode(q,{text:text,width:170,height:170,correctLevel:QRCode.CorrectLevel.M})}else{throw 0}}catch(e){var i=document.createElement('img');i.width=170;i.src='https://api.qrserver.com/v1/create-qr-code/?size=170x170&data='+encodeURIComponent(text);q.appendChild(i)}$('payload').textContent=text}
function refresh(){var b=$('base').value.trim().replace(/\\/+$/,'');drawQR(payloadFor(b))}
$('regen').onclick=refresh;$('copy').onclick=function(){var b=$('base').value.trim();if(navigator.clipboard)navigator.clipboard.writeText(b)};
refresh();
function tok(){return $('tok').value.trim()}
function post(path,body,isForm){var h={};if(!isForm)h['Content-Type']='application/json';var t=tok();if(t)h['Authorization']='Bearer '+t;return fetch(path,{method:'POST',headers:h,body:isForm?body:JSON.stringify(body||{})}).then(function(r){return r.json()})}
$('login').onclick=function(){fetch('/locket/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:$('email').value,password:$('pw').value})}).then(function(r){return r.json()}).then(function(j){$('loginOut').textContent=JSON.stringify(j,null,2);if(j.data&&(j.data.idToken||j.data.access_token)){$('tok').value=j.data.idToken||j.data.access_token}}).catch(function(e){$('loginOut').textContent=String(e)})};
function showData(p){p.then(function(j){$('dataOut').textContent=JSON.stringify(j,null,2);var g=$('gal');g.innerHTML='';var arr=j.data||[];if(arr&&!Array.isArray(arr)&&arr.moments)arr=arr.moments;if(Array.isArray(arr))arr.slice(0,12).forEach(function(m){var u=m.url||(m.mediaInfo&&m.mediaInfo.url)||'';if(!u)return;if(u.charAt(0)==='/')u=$('base').value.trim().replace(/\\/+$/,'')+u;if(/\\.mp4/i.test(u)){var v=document.createElement('video');v.src=u;v.controls=true;v.style.cssText='width:96px;height:96px;object-fit:cover;border-radius:8px';g.appendChild(v)}else{var i=document.createElement('img');i.src=u;g.appendChild(i)}})}).catch(function(e){$('dataOut').textContent=String(e)})}
$('bUser').onclick=function(){showData(post('/locket/getInfoUser',{}))};
$('bFriends').onclick=function(){showData(post('/locket/getAllFriendsV2',{}))};
$('bMoments').onclick=function(){showData(post('/locket/getMomentV2',{}))};
$('up').onclick=function(){var f=$('file').files[0];if(!f){$('upOut').textContent='Pick a file first';return}var fd=new FormData();fd.append('file',f);fd.append('optionsData',JSON.stringify({caption:$('cap').value}));var t=tok();var h={};if(t)h['Authorization']='Bearer '+t;fetch('/locket/postMomentV1',{method:'POST',headers:h,body:fd}).then(function(r){return r.json()}).then(function(j){$('upOut').textContent=JSON.stringify(j,null,2)}).catch(function(e){$('upOut').textContent=String(e)})};
</script></body></html>`;
