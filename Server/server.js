// LocketLegacy self-host mock + web dashboard — ZERO dependencies (node builtins only).
// No `npm install` needed, so `docker build` works even when the npm registry
// is unreachable (e.g. DNS EAI_AGAIN on restricted hosts).
//
// API: POST /locket/login, POST /locket/refresh-token, GET /locket/logout,
// POST /locket/getInfoUser, POST /locket/getAllFriendsV2,
// POST /locket/postMomentV1 (multipart), POST /locket/postMomentV2 (json),
// POST /locket/getMomentV2, POST /locket/getInfoMomentV2, POST /locket/getAllMessageV2
// Dashboard: GET / (human UI with connect QR), GET /api/health, GET /connect
// Data is in-memory + ./uploads on disk. Configure via env vars.
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.PORT || '5001', 10);
const PUBLIC_API_URL = process.env.PUBLIC_API_URL || ''; // e.g. http://192.168.1.5:5001
const MAX_BODY = 25 * 1024 * 1024;

const UP = path.join(__dirname, 'uploads');
if (!fs.existsSync(UP)) fs.mkdirSync(UP, { recursive: true });

let moments = [];
let seq = 1;

// One-time presigned PUT grants: token -> { key, fname, contentType, expires }.
const pendingUploads = {};
const MOCK_UID = 'mock-uid-1';
const ALLOWED_MIME_TYPES = [
  'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif',
  'video/mp4', 'video/webm', 'video/quicktime',
];

function todayFolder() {
  const d = new Date();
  function p(n) { return (n < 10 ? '0' : '') + n; }
  return d.getFullYear() + '-' + p(d.getMonth() + 1) + '-' + p(d.getDate());
}

function randomToken() {
  // 32 hex chars; Math.random is fine for a mock one-time grant.
  let s = '';
  const abc = '0123456789abcdef';
  for (let i = 0; i < 32; i++) s += abc[Math.floor(Math.random() * 16)];
  return s;
}

function safeFilename(name) {
  return String(name || '').replace(/[^a-zA-Z0-9._-]/g, '').slice(0, 120) || 'file.bin';
}

// ---- social stores (mirror upstream UX on self-host) ----
const reactions = {};   // momentId -> { emoji -> count }
const chatMessages = []; // { id, text, sender, createdAt }
let msgSeq = 1;
const pushTokens = [];
const ymd = (d) => d.toISOString().slice(0, 10);

// Consecutive-day posting streak ending today (or yesterday if none today).
function computeStreak() {
  const days = {};
  moments.forEach(function (m) { if (m.createdAt) days[String(m.createdAt).slice(0, 10)] = 1; });
  const keys = Object.keys(days).sort().reverse();
  if (!keys.length) return { count: 0, last_updated_yyyymmdd: null };
  const today = ymd(new Date());
  const y = new Date(Date.now() - 86400000);
  const yesterday = ymd(y);
  let cursor = keys[0] === today ? today : (keys[0] === yesterday ? yesterday : null);
  if (!cursor) return { count: 0, last_updated_yyyymmdd: keys[0] };
  let count = 0;
  let c = new Date(cursor + 'T00:00:00Z').getTime();
  const set = {};
  keys.forEach(function (k) { set[k] = 1; });
  for (;;) {
    const k = new Date(c).toISOString().slice(0, 10);
    if (!set[k]) break;
    count++;
    c -= 86400000;
  }
  return { count: count, last_updated_yyyymmdd: keys[0] };
}

function withReactions(list) {
  return (list || []).map(function (m) {
    const r = reactions[m.id] || {};
    const copy = {};
    Object.keys(m).forEach(function (k) { copy[k] = m[k]; });
    copy.reactions = r;
    return copy;
  });
}

// Bundled caption-overlay catalog (mirrors upstream overlay themes).
const OVERLAYS = {
  decorative: [
    { overlay_id: 'standard', type: 'default', title: 'Standard', icon: '', text_color: '#FFFFFF', color_top: '', color_bottom: '' },
    { overlay_id: 'love', type: 'caption_theme', title: 'Love', icon: '❤️', text_color: '#FFFFFF', color_top: '#FF4D6D', color_bottom: '#B5179E' },
    { overlay_id: 'sunset', type: 'caption_theme', title: 'Sunset', icon: '🌅', text_color: '#FFFFFF', color_top: '#F3722C', color_bottom: '#F94144' },
    { overlay_id: 'ocean', type: 'caption_theme', title: 'Ocean', icon: '🌊', text_color: '#FFFFFF', color_top: '#277DA1', color_bottom: '#43AA8B' },
  ],
  background: [
    { overlay_id: 'midnight', type: 'background', title: 'Midnight', icon: '', text_color: '#FFD75E', color_top: '#000000', color_bottom: '#333333' },
    { overlay_id: 'candy', type: 'background', title: 'Candy', icon: '🍬', text_color: '#5A189A', color_top: '#FFC8DD', color_bottom: '#FFAFCC' },
  ],
  special: [
    { overlay_id: 'fire', type: 'special', title: 'On fire', icon: '🔥', text_color: '#FFFFFF', color_top: '#F48C06', color_bottom: '#DC2F02' },
  ],
};

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function sendJSON(res, status, obj) {
  const body = JSON.stringify(obj);
  cors(res);
  res.writeHead(status, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
  res.end(body);
}

function ok(res, data, extra) {
  sendJSON(res, 200, Object.assign({ success: true, message: 'ok', data: data }, extra || {}));
}

function authOk(req) {
  const h = req.headers['authorization'] || '';
  return h.indexOf('Bearer ') === 0 && h.length > 10;
}

// Base URL as the caller's browser sees it (right for LAN QR), unless overridden.
function publicBase(req) {
  if (PUBLIC_API_URL) return PUBLIC_API_URL.replace(/\/+$/, '');
  const fwd = req.headers['x-forwarded-proto'];
  const proto = (Array.isArray(fwd) ? fwd[0] : (fwd || 'http')).split(',')[0].trim() || 'http';
  const host = req.headers['host'] || ('localhost:' + PORT);
  return proto + '://' + host;
}

function qrPayload(base) {
  return 'locketlegacy://connect?api=' + encodeURIComponent(base);
}

function readBody(req) {
  return new Promise(function (resolve, reject) {
    const chunks = [];
    let size = 0;
    req.on('data', function (c) {
      size += c.length;
      if (size > MAX_BODY) {
        reject(new Error('body too large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', function () { resolve(Buffer.concat(chunks)); });
    req.on('error', reject);
  });
}

// Minimal binary-safe multipart parser (single file field is all we need).
function parseMultipart(buf, boundary) {
  const fields = {};
  const files = [];
  const sep = Buffer.from('--' + boundary, 'latin1');
  const crlfSep = Buffer.from('\r\n--' + boundary, 'latin1');
  let pos = buf.indexOf(sep);
  if (pos === -1) return { fields: fields, files: files };
  pos += sep.length;
  for (;;) {
    if (buf[pos] === 0x2d && buf[pos + 1] === 0x2d) break; // closing '--'
    if (buf[pos] === 0x0d && buf[pos + 1] === 0x0a) pos += 2; // CRLF after delimiter
    const hEnd = buf.indexOf('\r\n\r\n', pos);
    if (hEnd === -1) break;
    const head = buf.slice(pos, hEnd).toString('latin1');
    const cStart = hEnd + 4;
    let cEnd = buf.indexOf(crlfSep, cStart);
    let last = false;
    if (cEnd === -1) { cEnd = buf.length; last = true; }
    const content = buf.slice(cStart, cEnd);
    const disp = /name="([^"]*)"/.exec(head);
    const fn = /filename="([^"]*)"/.exec(head);
    const name = disp && disp[1];
    if (name) {
      if (fn && fn[1]) {
        const originalname = fn[1].split(/[\\/]/).pop() || 'upload.bin';
        let ext = (path.extname(originalname) || '.jpg').replace(/[^a-zA-Z0-9.]/g, '').slice(0, 8) || '.jpg';
        const fname = 'm' + Date.now() + '_' + Math.floor(Math.random() * 1e6) + ext;
        const fpath = path.join(UP, fname);
        fs.writeFileSync(fpath, content);
        files.push({ fieldname: name, originalname: originalname, path: fpath, size: content.length });
      } else {
        fields[name] = content.toString('utf8');
      }
    }
    if (last) break;
    pos = cEnd + 2 + sep.length; // skip CRLF + delimiter
  }
  return { fields: fields, files: files };
}

const MIME = {
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
  '.webp': 'image/webp', '.gif': 'image/gif', '.mp4': 'video/mp4',
  '.mov': 'video/quicktime', '.webm': 'video/webm',
};

function serveUpload(req, res, name) {
  const safe = path.basename(name || '');
  if (!safe || safe.charAt(0) === '.') { sendJSON(res, 400, { success: false, message: 'bad file' }); return; }
  const fp = path.join(UP, safe);
  fs.stat(fp, function (err, st) {
    if (err || !st.isFile()) { sendJSON(res, 404, { success: false, message: 'not found' }); return; }
    cors(res);
    res.writeHead(200, { 'Content-Type': MIME[path.extname(safe).toLowerCase()] || 'application/octet-stream', 'Content-Length': st.size });
    fs.createReadStream(fp).pipe(res);
  });
}

async function route(req, res, url) {
  const method = req.method.toUpperCase();
  const pathname = url.pathname;

  if (method === 'OPTIONS') { cors(res); res.writeHead(204); res.end(); return; }

  if (method === 'GET' && pathname === '/') {
    const base = publicBase(req);
    const html = DASHBOARD_HTML.split('__BASE__').join(base).split('__QR__').join(qrPayload(base));
    cors(res);
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Content-Length': Buffer.byteLength(html) });
    res.end(html);
    return;
  }
  if (method === 'GET' && pathname === '/api/health') {
    sendJSON(res, 200, { status: 'ok', service: 'locketlegacy-mock', moments: moments.length, time: new Date().toISOString() });
    return;
  }
  if (method === 'GET' && pathname === '/connect') {
    const base = String(url.searchParams.get('base') || publicBase(req)).replace(/\/+$/, '');
    sendJSON(res, 200, { apiBaseUrl: base, qrPayload: qrPayload(base), ios: 'Login → 📷 Scan QR → point at the dashboard code' });
    return;
  }
  if (method === 'GET' && pathname === '/api/overlays') {
    sendJSON(res, 200, { success: true, message: 'ok', data: OVERLAYS });
    return;
  }
  if (method === 'POST' && pathname === '/api/push/register') {
    let pj = {};
    try { pj = JSON.parse((await readBody(req)).toString('utf8')) || {}; } catch (e) { pj = {}; }
    if (pj.token) pushTokens.push({ token: String(pj.token), platform: String(pj.platform || 'ios'), at: new Date().toISOString() });
    sendJSON(res, 200, { success: true, message: 'registered', data: { devices: pushTokens.length } });
    return;
  }
  if (method === 'GET' && pathname === '/locket/logout') {
    sendJSON(res, 200, { success: true, message: 'ok' });
    return;
  }
  if (method === 'GET' && pathname.indexOf('/uploads/') === 0) {
    serveUpload(req, res, decodeURIComponent(pathname.slice('/uploads/'.length)));
    return;
  }

  // ---- storage flow (mirrors upstream storage/api/presignedV3) ----
  // Step 1: client asks for a one-time PUT grant.
  if (method === 'POST' && pathname === '/api/presignedV3') {
    if (!authOk(req)) { sendJSON(res, 401, { success: false, error: { code: 'UNAUTHORIZED', message: 'missing token' } }); return; }
    let pj = {};
    try { pj = JSON.parse((await readBody(req)).toString('utf8')) || {}; }
    catch (e) { sendJSON(res, 400, { status: 'error', message: 'invalid json', errorCode: 'BAD_JSON' }); return; }
    const filename = pj.filename;
    const contentType = pj.contentType || '';
    const ftype = pj.type || '';
    if (!filename || !ftype) {
      sendJSON(res, 400, { status: 'error', message: "Request body must include 'filename' and 'type'", errorCode: 'MISSING_BODY_FIELDS' });
      return;
    }
    if (ALLOWED_MIME_TYPES.indexOf(contentType) === -1) {
      sendJSON(res, 400, { status: 'error', message: 'File type not allowed', errorCode: 'INVALID_FILE_TYPE', allowed: ALLOWED_MIME_TYPES });
      return;
    }
    const safeType = contentType.indexOf('video/') === 0 ? 'video' : 'image';
    const clean = safeFilename(filename);
    const key = 'LocketCloud/' + todayFolder() + '/' + safeType + '/' + MOCK_UID + '/' + clean;
    const ext = (path.extname(clean) || '.jpg').slice(0, 8);
    const fname = 'm' + Date.now() + '_' + Math.floor(Math.random() * 1e6) + ext;
    const token = randomToken();
    pendingUploads[token] = { key: key, fname: fname, contentType: contentType, expires: Date.now() + 300000 };
    const base = publicBase(req);
    sendJSON(res, 200, {
      status: 'success',
      data: {
        url: base + '/api/upload/' + token,
        expiresIn: 300,
        key: key,
        publicURL: base + '/uploads/' + fname,
      },
      message: 'Presigned URL generated successfully',
      meta: { note: 'Use this URL only once — it will expire in 5 minutes!' },
    });
    return;
  }
  // Step 2: raw bytes PUT to the granted URL (no auth header — grant IS the auth).
  if (method === 'PUT' && pathname.indexOf('/api/upload/') === 0) {
    const token = decodeURIComponent(pathname.slice('/api/upload/'.length));
    const grant = pendingUploads[token];
    delete pendingUploads[token]; // single use
    if (!grant || grant.expires < Date.now()) {
      sendJSON(res, 403, { status: 'error', message: 'Upload grant expired or invalid', errorCode: 'INVALID_GRANT' });
      return;
    }
    let raw;
    try { raw = await readBody(req); }
    catch (e) { sendJSON(res, 413, { status: 'error', message: 'body too large', errorCode: 'TOO_LARGE' }); return; }
    if (!raw.length) { sendJSON(res, 400, { status: 'error', message: 'empty file', errorCode: 'EMPTY_FILE' }); return; }
    fs.writeFileSync(path.join(UP, grant.fname), raw);
    sendJSON(res, 200, { status: 'success', data: { key: grant.key, size: raw.length }, message: 'uploaded' });
    return;
  }

  if (method !== 'POST' || pathname.indexOf('/locket/') !== 0) {
    sendJSON(res, 404, { success: false, message: 'not found' });
    return;
  }

  const ctype = String(req.headers['content-type'] || '');
  let body = {};
  let files = [];
  if (ctype.indexOf('multipart/form-data') === 0) {
    const m = /boundary=(?:"([^"]+)"|([^;]+))/.exec(ctype);
    if (!m) { sendJSON(res, 400, { success: false, message: 'missing multipart boundary' }); return; }
    const raw = await readBody(req);
    const parsed = parseMultipart(raw, (m[1] || m[2]).trim());
    body = parsed.fields;
    files = parsed.files;
  } else {
    const raw = await readBody(req);
    if (raw.length > 0) {
      try { body = JSON.parse(raw.toString('utf8')) || {}; }
      catch (e) { sendJSON(res, 400, { success: false, message: 'invalid json' }); return; }
    }
  }

  const authed = function () {
    if (!authOk(req)) { sendJSON(res, 401, { success: false, error: { code: 'UNAUTHORIZED', message: 'missing token' } }); return false; }
    return true;
  };

  if (pathname === '/locket/login') {
    if (!body.email) { sendJSON(res, 400, { success: false, message: 'email required' }); return; }
    ok(res, {
      kind: 'identitytoolkit#VerifyPasswordResponse',
      localId: 'mock-uid-1',
      email: body.email,
      displayName: 'Legacy User',
      idToken: 'mock-id-token-abc123',
      refreshToken: 'mock-refresh-abc123',
      expiresIn: '3600',
    });
    return;
  }
  if (pathname === '/locket/refresh-token') {
    ok(res, {
      access_token: 'mock-id-token-abc123',
      id_token: 'mock-id-token-abc123',
      refresh_token: 'mock-refresh-abc123',
      expires_in: '3600',
      token_type: 'Bearer',
      user_id: 'mock-uid-1',
    });
    return;
  }
  if (pathname === '/locket/getInfoUser') {
    if (!authed()) return;
    ok(res, {
      uid: 'mock-uid-1', localId: 'mock-uid-1', email: 'demo@locket.legacy',
      displayName: 'Legacy User', username: 'legacy', firstName: 'Legacy', lastName: 'User',
      profilePicture: '', createdAt: new Date().toISOString(),
    });
    return;
  }
  if (pathname === '/locket/getAllFriendsV2') {
    if (!authed()) return;
    ok(res, [
      { uid: 'friend-1', displayName: 'Dio', profilePicture: '' },
      { uid: 'friend-2', displayName: 'Locket Fan', profilePicture: '' },
    ]);
    return;
  }
  if (pathname === '/locket/postMomentV1') {
    if (!authed()) return;
    let caption = '';
    try { caption = JSON.parse(body.optionsData || '{}').caption || ''; }
    catch (e) { caption = body.optionsData || ''; }
    let murl = '';
    // Absolute URL: the phone's feed can load it directly (a bare "/uploads/…"
    // path is unresolvable from the app). publicBase reflects the caller's host.
    if (files.length > 0) murl = publicBase(req) + '/uploads/' + path.basename(files[0].path);
    const m = { id: 'm' + (seq++), url: murl, caption: caption, author: 'Legacy User', createdAt: new Date().toISOString() };
    moments.unshift(m);
    sendJSON(res, 200, { success: true, message: 'Upload media successfully', data: m });
    return;
  }
  if (pathname === '/locket/postMomentV2') {
    if (!authed()) return;
    const mediaInfo = body.mediaInfo || {};
    const options = body.options || {};
    const m = { id: 'm' + (seq++), url: mediaInfo.url || '', caption: options.caption || '', author: 'Legacy User', createdAt: new Date().toISOString() };
    moments.unshift(m);
    sendJSON(res, 200, { success: true, message: 'Upload media successfully', data: m });
    return;
  }
  if (pathname === '/locket/getMomentV2') {
    if (!authed()) return;
    sendJSON(res, 200, { success: true, message: 'ok', data: withReactions(moments), nextPageToken: null, streak: computeStreak() });
    return;
  }
  if (pathname === '/locket/getInfoMomentV2') {
    const found = moments.filter(function (x) { return x.id === body.idMoment; });
    sendJSON(res, 200, { success: true, message: 'ok', data: withReactions(found), nextPageToken: null });
    return;
  }
  if (pathname === '/locket/getAllMessageV2') {
    sendJSON(res, 200, { success: true, message: 'ok', data: chatMessages, nextPageToken: null });
    return;
  }
  if (pathname === '/locket/sendMessage') {
    if (!authed()) return;
    const text = String(body.text || body.msg || '').slice(0, 1000);
    if (!text) { sendJSON(res, 400, { success: false, message: 'empty message' }); return; }
    const msg = { id: 'msg' + (msgSeq++), text: text, sender: 'me', createdAt: new Date().toISOString() };
    chatMessages.push(msg);
    sendJSON(res, 200, { success: true, message: 'sent', data: msg });
    return;
  }
  if (pathname === '/locket/reactToMoment') {
    if (!authed()) return;
    const mid = String(body.momentId || body.moment_uid || '');
    const emoji = String(body.emoji || body.reaction || '❤️').slice(0, 8);
    if (!mid) { sendJSON(res, 400, { success: false, message: 'missing momentId' }); return; }
    reactions[mid] = reactions[mid] || {};
    reactions[mid][emoji] = (reactions[mid][emoji] || 0) + 1;
    sendJSON(res, 200, { success: true, message: 'reacted', data: { momentId: mid, reactions: reactions[mid] } });
    return;
  }
  sendJSON(res, 404, { success: false, message: 'not found' });
}

const server = http.createServer(function (req, res) {
  let url;
  try {
    url = new URL(req.url || '/', 'http://' + (req.headers['host'] || ('localhost:' + PORT)));
  } catch (e) {
    sendJSON(res, 400, { success: false, message: 'bad request' });
    return;
  }
  route(req, res, url).catch(function (err) {
    if (!res.headersSent) sendJSON(res, err && err.message === 'body too large' ? 413 : 500, { success: false, message: (err && err.message) || 'error' });
    else try { res.end(); } catch (e2) { /* noop */ }
  });
});

server.listen(PORT, function () { console.log('LocketLegacy mock listening on :' + PORT); });

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
<div class="card"><h2>④ Upload tester → original flow (presigned → PUT → postMomentV2)</h2>
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
$('up').onclick=function(){var f=$('file').files[0];if(!f){$('upOut').textContent='Pick a file first';return}var t=tok();var h={'Content-Type':'application/json'};if(t)h['Authorization']='Bearer '+t;var kind=f.type.indexOf('video/')===0?'video':'image';var out=function(s){$('upOut').textContent=s};out('1/3 presigned…');fetch('/api/presignedV3',{method:'POST',headers:h,body:JSON.stringify({filename:f.name,contentType:f.type,type:kind,size:f.size,uploadedAt:new Date().toISOString()})}).then(function(r){return r.json().then(function(j){return{ok:r.ok,j:j}})}).then(function(a){if(a.j.status!=='success')throw new Error(JSON.stringify(a.j));out('1/3 presigned OK → 2/3 PUT '+a.j.data.url);return fetch(a.j.data.url,{method:'PUT',headers:{'Content-Type':f.type},body:f}).then(function(r){return r.json().then(function(j){return{ok:r.ok,j:j,pre:a.j.data}}})})}).then(function(a){if(a.j.status!=='success')throw new Error(JSON.stringify(a.j));out('2/3 PUT OK → 3/3 postMomentV2…');var mediaInfo={url:a.pre.publicURL,path:a.pre.key,name:f.name,size:f.size,uploadedAt:new Date().toISOString(),type:kind};return fetch('/locket/postMomentV2',{method:'POST',headers:h,body:JSON.stringify({model:'Version-UploadmediaV3.1',mediaInfo:mediaInfo,options:{caption:$('cap').value,audience:'all',recipients:[]}})})}).then(function(r){return r.json()}).then(function(j){out('3/3 postMomentV2:\n'+JSON.stringify(j,null,2))}).catch(function(e){out('FAILED: '+e.message||e)})};
</script></body></html>`;
