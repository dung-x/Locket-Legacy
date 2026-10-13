// LocketBridge — real self-host backend for Locket Legacy.
// Dio-compatible routes (/locket/*) backed by the OFFICIAL Locket API,
// so the iOS app works unchanged against real accounts. Zero npm
// dependencies (node builtins only: http, fs, path, crypto).
//
// Method reference (ported from Client-Locket-Dio self-host api +
// jumpogpo/locket-api SDK, both MIT — see NOTICE below):
//  - auth via Firebase verifyPassword / securetoken (Locket app keys)
//  - media via Firebase Storage resumable upload (user's own bucket)
//  - feed/friends/react/chat via api.locketcamera.com + Firestore REST
//
// Env: PORT (5001), LOCKET_API_BASE, FIREBASE_API_KEY, FIREBASE_PROJECT_ID.
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT || '5001', 10);
const LOCKET_API = (process.env.LOCKET_API_BASE || 'https://api.locketcamera.com').replace(/\/+$/, '');
const FB_KEY = process.env.FIREBASE_API_KEY || 'AIzaSyCQngaaXQIfJaH0aS2l7REgIjD7nL431So';
const FB_PROJECT = process.env.FIREBASE_PROJECT_ID || 'locket-4252a';
const MAX_BODY = 60 * 1024 * 1024;

const UP = path.join(__dirname, 'uploads-tmp');
if (!fs.existsSync(UP)) fs.mkdirSync(UP, { recursive: true });

// ---------- tiny http helpers ----------
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
function fail(res, status, message, code) {
  sendJSON(res, status, { success: false, message: message, error: { code: code || 'ERROR', message: message } });
}
function readBody(req) {
  return new Promise(function (resolve, reject) {
    const chunks = [];
    let size = 0;
    req.on('data', function (c) {
      size += c.length;
      if (size > MAX_BODY) { reject(new Error('body too large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', function () { resolve(Buffer.concat(chunks)); });
    req.on('error', reject);
  });
}
async function jfetch(url, opts) {
  opts = opts || {};
  const ctrl = new AbortController();
  const timer = setTimeout(function () { ctrl.abort(); }, opts.timeout || 30000);
  try {
    const r = await fetch(url, {
      method: opts.method || 'GET',
      headers: opts.headers || {},
      body: opts.body,
      signal: ctrl.signal,
    });
    const text = await r.text();
    let json = null;
    try { json = text ? JSON.parse(text) : null; } catch (e) { /* non-json */ }
    return { status: r.status, ok: r.ok, json: json, text: text, headers: r.headers };
  } finally {
    clearTimeout(timer);
  }
}

// ---------- auth helpers ----------
function bearer(req) {
  const h = req.headers['authorization'] || '';
  if (h.indexOf('Bearer ') !== 0) return null;
  const t = h.slice(7).trim();
  return t.length > 10 ? t : null;
}
function jwtUid(token) {
  try {
    const parts = String(token).split('.');
    if (parts.length < 2) return null;
    const p = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
    return p.user_id || p.uid || p.sub || null;
  } catch (e) { return null; }
}
function needAuth(req, res) {
  const t = bearer(req);
  if (!t) { fail(res, 401, 'Missing Authorization', 'UNAUTHORIZED'); return null; }
  const uid = jwtUid(t);
  if (!uid) { fail(res, 401, 'Invalid token', 'UNAUTHORIZED'); return null; }
  return { token: t, uid: uid };
}

// ---------- official Locket plumbing ----------
const LOCKET_UA = 'FirebaseAuth.iOS/10.23.1 com.locket.Locket/2.8.0 iPhone/18.0 hw/iPhone12_1';
function locketHeaders(idToken, extra) {
  return Object.assign({
    'Content-Type': 'application/json',
    'Accept-Language': 'en-US',
    'X-Ios-Bundle-Identifier': 'com.locket.Locket',
    'User-Agent': LOCKET_UA,
    'X-Client-Version': 'iOS/FirebaseSDK/10.23.1/FirebaseCore-iOS',
    'X-Firebase-GMPID': '1:641029076083:ios:cc8eb46290d69b234fa609',
    'X-Firebase-Client': 'H4sIAAAAAAAAAKtWykhNLCpJSk0sKVayio7VUSpLLSrOzM9TslIyUqoFAFyivEQfAAAA',
    'X-Firebase-AppCheck': 'eyJraWQiOiJNbjVDS1EiLCJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxOjY0MTAyOTA3NjA4Mzppb3M6Y2M4ZWI0NjI5MGQ2OWIyMzRmYTYwNiIsImF1ZCI6WyJwcm9qZWN0c1wvNjQxMDI5MDc2MDgzIiwicHJvamVjdHNcL2xvY2tldC00MjUyYSJdLCJwcm92aWRlciI6ImRldmljZV9jaGVja19kZXZpY2VfaWRlbnRpZmljYXRpb24iLCJpc3MiOiJodHRwczpcL1wvZmlyZWJhc2VhcHBjaGVjay5nb29nbGVhcGlzLmNvbVwvNjQxMDI5MDc2MDgzIiwiZXhwIjoxNzIyMTY3ODk4LCJpYXQiOjE3MjIxNjQyOTgsImp0aSI6ImlHUGlsT1dDZGg4Mll3UTJXRC1neEpXeWY5TU9RRFhHcU5OR3AzTjFmRGcifQ.lqTOJfdoYLpZwYeeXtRliCdkVT7HMd7_Lj-d44BNTGuxSYPIa9yVAR4upu3vbZSh9mVHYS8kJGYtMqjP-L6YXsk_qsV_gzKC2IhVAV6KbPDRHdevMfBC6fRiOSVn7vt749GVFdZqAuDCXhCILsaMhvgDBgZoDilgAPtpNwyjz-VtRB7OdOUbuKTCqdoSOX0SJWVUMyuI8nH0-unY--YRctunK8JHZDxBaMhVFxYkdoTmuI8nH0iEYyhfUPncER3S-b1CmuXR7tFCdTgQe5j7NGWjFvN_CnL7D2nudLwxWlpqwASCHvHyi8HBaJ5GpgriTLXAAinY48RukRDBi9HwEzpRecELX05KTD2lTOfQCjKyGpfG2VUHP5Xm36YbA3iqTDoDXWMvV',
    'Authorization': 'Bearer ' + idToken,
  }, extra || {});
}
function uuid4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
    const r = (Math.random() * 16) | 0;
    return (c === 'x' ? r : ((r & 0x3) | 0x8)).toString(16);
  });
}
function intValue(v) {
  return { '@type': 'type.googleapis.com/google.protobuf.Int64Value', value: String(v) };
}
function createAnalytics() {
  return {
    experiments: {
      flag_4: intValue(43), flag_10: intValue(505), flag_23: intValue(400),
      flag_22: intValue(1203), flag_19: intValue(52), flag_18: intValue(1203),
      flag_16: intValue(303), flag_15: intValue(501), flag_14: intValue(500),
      flag_25: intValue(23),
    },
    amplitude: { device_id: uuid4(), session_id: intValue(Date.now().toString()) },
    google_analytics: { app_instance_id: '5BDC04DA16FF4B0C9CA14FFB9C502900' },
    platform: 'ios',
  };
}
function yyyymmddVN(d) {
  try {
    const vn = new Date((d || new Date()).toLocaleString('en-US', { timeZone: 'Asia/Ho_Chi_Minh' }));
    const p = function (n) { return (n < 10 ? '0' : '') + n; };
    return Number('' + vn.getFullYear() + p(vn.getMonth() + 1) + p(vn.getDate()));
  } catch (e) {
    const t = d || new Date();
    const p = function (n) { return (n < 10 ? '0' : '') + n; };
    return Number('' + t.getFullYear() + p(t.getMonth() + 1) + p(t.getDate()));
  }
}
function firestoreId() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let s = '';
  for (let i = 0; i < 20; i++) s += chars.charAt(Math.floor(Math.random() * chars.length));
  return s;
}
function md5(str) {
  return crypto.createHash('md5').update(str).digest('hex');
}

// ---------- Firebase Storage resumable upload (user's own bucket) ----------
const FIREBASE_UA = 'com.locket.Locket/1.43.1 iPhone/17.3 hw/iPhone15_3 (GTMSUF/1)';
async function firebaseUpload(userId, idToken, buffer, kind, momentId, mime) {
  // kind: 'image' | 'video' | 'thumb'
  const ext = kind === 'video' ? 'mp4' : (kind === 'thumb' ? 'jpg' : 'jpg');
  const folder = kind === 'video' ? 'moments/videos' : 'moments/thumbnails';
  const objectName = momentId + '.' + ext;
  const encPath = 'users%2F' + userId + '%2F' + folder.replace(/\//g, '%2F') + '%2F' + objectName;
  const bucket = kind === 'video' ? 'locket-video' : 'locket-img';
  const initUrl = 'https://firebasestorage.googleapis.com/v0/b/' + bucket + '/o/' + encPath +
    '?uploadType=resumable&name=users%2F' + userId + '%2F' + folder.replace(/\//g, '%2F') + '%2F' + objectName;
  const initRes = await jfetch(initUrl, {
    method: 'POST',
    headers: {
      'content-type': 'application/json; charset=UTF-8',
      'authorization': 'Bearer ' + idToken,
      'x-goog-upload-protocol': 'resumable',
      'accept': '*/*',
      'x-goog-upload-command': 'start',
      'x-goog-upload-content-length': String(buffer.length),
      'accept-language': 'vi-VN,vi;q=0.9',
      'x-firebase-storage-version': 'ios/10.13.0',
      'user-agent': FIREBASE_UA,
      'x-goog-upload-content-type': mime,
      'x-firebase-gmpid': '1:641029076083:ios:cc8eb46290d69b234fa609',
    },
    body: JSON.stringify({
      name: 'users/' + userId + '/' + folder + '/' + objectName,
      contentType: mime,
      bucket: '',
      metadata: { creator: userId, visibility: 'private' },
    }),
  });
  if (!initRes.ok) {
    throw new Error('Firebase upload init failed: HTTP ' + initRes.status + ' ' + (initRes.text || '').slice(0, 200));
  }
  const uploadUrl = initRes.headers.get('x-goog-upload-url');
  if (!uploadUrl) throw new Error('Firebase did not return upload URL');
  const putRes = await jfetch(uploadUrl, {
    method: 'PUT',
    headers: { 'content-type': mime, 'content-length': String(buffer.length) },
    body: buffer,
    timeout: 120000,
  });
  if (!putRes.ok) throw new Error('Firebase byte upload failed: HTTP ' + putRes.status);
  const metaUrl = 'https://firebasestorage.googleapis.com/v0/b/' + bucket + '/o/' + encPath;
  const metaRes = await jfetch(metaUrl, {
    method: 'GET',
    headers: { 'content-type': 'application/json; charset=UTF-8', 'authorization': 'Bearer ' + idToken },
  });
  if (!metaRes.ok || !metaRes.json || !metaRes.json.downloadTokens) {
    throw new Error('Firebase download token failed: HTTP ' + metaRes.status);
  }
  return metaUrl + '?alt=media&token=' + metaRes.json.downloadTokens;
}

// ---------- official payload builders (ported shape) ----------
function basePayload(mediaUrl, thumbnailUrl, optionsData, isVideo) {
  const recipients = optionsData.recipients;
  const audience = optionsData.audience;
  const payload = {
    thumbnail_url: thumbnailUrl || mediaUrl,
    md5: md5(mediaUrl),
    show_personally: false,
    analytics: createAnalytics(),
    overlays: [],
  };
  if (audience === 'private') {
    payload.sent_to_self_only = true;
    payload.sent_to_all = false;
  } else {
    payload.sent_to_self_only = false;
    payload.sent_to_all = true;
    payload.recipients = Array.isArray(recipients) ? recipients : (recipients ? [recipients] : []);
  }
  if (isVideo) payload.video_url = mediaUrl;
  payload.update_streak_for_yyyymmdd = yyyymmddVN();
  return payload;
}
function pushCaptionOverlay(data, o, maxLines, iconType, overlayId) {
  data.overlays.push({
    data: {
      text: o.caption || '',
      text_color: o.text_color || '#FFFFFF',
      type: o.type === 'default' ? 'standard' : 'static_content',
      icon: o.icon ? { type: iconType || 'emoji', data: o.icon } : undefined,
      max_lines: (maxLines === 4 && o.type !== 'default')
        ? { '@type': 'type.googleapis.com/google.protobuf.Int64Value', value: '4' }
        : (maxLines || 4),
      background: { material_blur: 'ultra_thin', colors: [o.color_top, o.color_bottom].filter(Boolean) },
    },
    alt_text: o.caption || '',
    overlay_id: overlayId,
    overlay_type: 'caption',
  });
}
function imagePostData(imageUrl, o) {
  const data = basePayload(imageUrl, null, o, false);
  const t = o.type || 'default';
  if (o.caption && String(o.caption).trim()) {
    if (t === 'default') {
      pushCaptionOverlay(data, Object.assign({ type: 'default' }, o), 4, null, 'caption:standard');
    } else if (t === 'decorative' || t === 'caption_theme') {
      pushCaptionOverlay(data, o, 4, 'emoji', 'caption:' + (o.overlay_id || 'custom'));
    } else {
      pushCaptionOverlay(data, o, 4, 'emoji', 'caption:miss_you');
    }
  }
  return { data: data };
}
function videoPostData(videoUrl, thumbnailUrl, o) {
  const data = basePayload(videoUrl, thumbnailUrl, o, true);
  const t = o.type || 'default';
  if (o.caption && String(o.caption).trim()) {
    if (t === 'default') {
      pushCaptionOverlay(data, Object.assign({ type: 'default' }, o), 4, null, 'caption:standard');
    } else {
      pushCaptionOverlay(data, o, 1, 'emoji', 'caption:' + (o.overlay_id || 'custom'));
    }
  }
  return { data: data };
}

// ---------- multipart (binary-safe, single file + optional thumbnail) ----------
function parseMultipart(buf, boundary) {
  const fields = {};
  const files = [];
  const sep = Buffer.from('--' + boundary, 'latin1');
  const crlfSep = Buffer.from('\r\n--' + boundary, 'latin1');
  let pos = buf.indexOf(sep);
  if (pos === -1) return { fields: fields, files: files };
  pos += sep.length;
  for (;;) {
    if (buf[pos] === 0x2d && buf[pos + 1] === 0x2d) break;
    if (buf[pos] === 0x0d && buf[pos + 1] === 0x0a) pos += 2;
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
        files.push({ fieldname: name, originalname: fn[1].split(/[\\/]/).pop(), data: content });
      } else {
        fields[name] = content.toString('utf8');
      }
    }
    if (last) break;
    pos = cEnd + 2 + sep.length;
  }
  return { fields: fields, files: files };
}

// ---------- social helpers ----------
function withStreak(moments) {
  const days = {};
  moments.forEach(function (m) {
    const d = m && (m.date || m.createdAt || m.created_at);
    const s = typeof d === 'string' ? d.slice(0, 10) : null;
    if (s) days[s] = 1;
  });
  const keys = Object.keys(days).sort().reverse();
  const out = { count: 0, last_updated_yyyymmdd: keys[0] || null };
  if (!keys.length) return out;
  const day = 86400000;
  const today = new Date().toISOString().slice(0, 10);
  const yest = new Date(Date.now() - day).toISOString().slice(0, 10);
  let cursor = keys[0] === today ? today : (keys[0] === yest ? yest : null);
  if (!cursor) return out;
  let c = new Date(cursor + 'T00:00:00Z').getTime();
  for (;;) {
    const k = new Date(c).toISOString().slice(0, 10);
    if (!days[k]) break;
    out.count++;
    c -= day;
  }
  return out;
}

// ---------- overlays / push (Dio-client compat) ----------
const OVERLAYS = {
  decorative: [
    { overlay_id: 'standard', type: 'default', title: 'Standard', icon: '', text_color: '#FFFFFF', color_top: '', color_bottom: '' },
    { overlay_id: 'love', type: 'caption_theme', title: 'Love', icon: '❤️', text_color: '#FFFFFF', color_top: '#FF4D6D', color_bottom: '#B5179E' },
    { overlay_id: 'sunset', type: 'caption_theme', title: 'Sunset', icon: '🌅', text_color: '#FFFFFF', color_top: '#F3722C', color_bottom: '#F94144' },
    { overlay_id: 'ocean', type: 'caption_theme', title: 'Ocean', icon: '🌊', text_color: '#FFFFFF', color_top: '#277DA1', color_bottom: '#43AA8B' },
  ],
  background: [
    { overlay_id: 'midnight', type: 'background', title: 'Midnight', icon: '', text_color: '#FFD75E', color_top: '#000000', color_bottom: '#333333' },
  ],
  special: [
    { overlay_id: 'fire', type: 'special', title: 'On fire', icon: '🔥', text_color: '#FFFFFF', color_top: '#F48C06', color_bottom: '#DC2F02' },
  ],
};
const pushTokens = [];
function publicBase(req) {
  if (process.env.PUBLIC_API_URL) return process.env.PUBLIC_API_URL.replace(/\/+$/, '');
  const proto = String(req.headers['x-forwarded-proto'] || 'http').split(',')[0].trim() || 'http';
  return proto + '://' + (req.headers['host'] || ('localhost:' + PORT));
}

// ---------- upload pipeline shared by V1 (file) and V2 (mediaInfo.url) ----------
async function runUploadPipeline(user, fileBuffer, fileName, mime, thumbBuffer, optionsData) {
  const isVideo = String(mime || '').indexOf('video/') === 0;
  const momentId = firestoreId();
  if (isVideo) {
    const videoUrl = await firebaseUpload(user.uid, user.token, fileBuffer, 'video', momentId, 'video/mp4');
    let thumbUrl = videoUrl;
    if (thumbBuffer && thumbBuffer.length) {
      try { thumbUrl = await firebaseUpload(user.uid, user.token, thumbBuffer, 'thumb', momentId, 'image/jpeg'); }
      catch (e) { /* fall back to video url */ }
    }
    const postData = videoPostData(videoUrl, thumbUrl, optionsData);
    const pr = await jfetch(LOCKET_API + '/postMomentV2', {
      method: 'POST', headers: locketHeaders(user.token), body: JSON.stringify(postData), timeout: 60000,
    });
    return finishOfficialPost(pr);
  }
  const imageUrl = await firebaseUpload(user.uid, user.token, fileBuffer, 'image', momentId, 'image/jpeg');
  const postData = imagePostData(imageUrl, optionsData);
  const pr = await jfetch(LOCKET_API + '/postMomentV2', {
    method: 'POST', headers: locketHeaders(user.token), body: JSON.stringify(postData), timeout: 60000,
  });
  return finishOfficialPost(pr);
}
function finishOfficialPost(pr) {
  const body = pr.json || {};
  const result = body.result || body.data || body;
  const errs = result && result.errors;
  if (Array.isArray(errs) && errs.length) {
    const e = new Error(errs.join(', '));
    e.status = result.status || pr.status;
    throw e;
  }
  if (pr.status >= 400) {
    const e = new Error((body && (body.message || body.error)) || ('Locket API error HTTP ' + pr.status));
    e.status = pr.status;
    throw e;
  }
  return result && (result.data !== undefined ? result.data : result);
}

// ---------- router ----------
async function route(req, res, url) {
  const method = req.method.toUpperCase();
  const pathname = url.pathname;
  if (method === 'OPTIONS') { cors(res); res.writeHead(204); res.end(); return; }

  if (method === 'GET' && pathname === '/') {
    const html = '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>LocketBridge</title></head>' +
      '<body style="background:#0b0b0e;color:#eee;font:14px system-ui;padding:24px"><h1>🌉 LocketBridge — real self-host backend</h1>' +
      '<p>Dio-compatible <code>/locket/*</code> routes backed by the <b>official Locket API</b> with your own account. Use the iOS app in <b>Self-host</b> mode pointing here.</p>' +
      '<p>Health: <a style="color:#ffd75e" href="/api/health">/api/health</a> · Connect JSON: <a style="color:#ffd75e" href="/connect">/connect</a></p></body></html>';
    cors(res);
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(html);
    return;
  }
  if (method === 'GET' && pathname === '/api/health') {
    sendJSON(res, 200, { status: 'ok', service: 'locketbridge', serverVersion: '1.0.0+official', features: ['official-auth', 'official-feed', 'official-upload', 'overlays', 'push'], time: new Date().toISOString() });
    return;
  }
  if (method === 'GET' && pathname === '/connect') {
    const base = String(url.searchParams.get('base') || publicBase(req)).replace(/\/+$/, '');
    sendJSON(res, 200, { apiBaseUrl: base, qrPayload: 'locketlegacy://connect?api=' + encodeURIComponent(base), ios: 'Login → 📷 Scan QR → point at the dashboard code' });
    return;
  }
  if (method === 'GET' && pathname === '/api/overlays') {
    return ok(res, OVERLAYS);
  }
  if (method === 'POST' && pathname === '/api/push/register') {
    let pj = {};
    try { pj = JSON.parse((await readBody(req)).toString('utf8')) || {}; } catch (e) { pj = {}; }
    if (pj.token) pushTokens.push({ token: String(pj.token), platform: String(pj.platform || 'ios'), at: new Date().toISOString() });
    return ok(res, { devices: pushTokens.length });
  }

  // ----- auth (Firebase, Locket app keys) -----
  if (method === 'POST' && pathname === '/locket/login') {
    let b = {};
    try { b = JSON.parse((await readBody(req)).toString('utf8')) || {}; } catch (e) { return fail(res, 400, 'invalid json', 'BAD_JSON'); }
    if (!b.email || !b.password) return fail(res, 400, 'email and password required', 'BAD_REQUEST');
    const fr = await jfetch('https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=' + FB_KEY, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: b.email, password: b.password, returnSecureToken: true, clientType: 'CLIENT_TYPE_IOS' }),
    });
    if (!fr.ok || !fr.json || !fr.json.idToken) {
      const msg = (fr.json && (fr.json.error || {}).message) || 'Login failed';
      return fail(res, fr.status === 400 ? 401 : fr.status, String(msg).replace(/_/g, ' '), 'INVALID_CREDENTIALS');
    }
    return ok(res, {
      kind: 'identitytoolkit#VerifyPasswordResponse',
      localId: fr.json.localId, email: fr.json.email, displayName: fr.json.displayName || '',
      idToken: fr.json.idToken, refreshToken: fr.json.refreshToken, expiresIn: fr.json.expiresIn || '3600',
    });
  }
  if (method === 'POST' && pathname === '/locket/refresh-token') {
    let b = {};
    try { b = JSON.parse((await readBody(req)).toString('utf8')) || {}; } catch (e) { b = {}; }
    if (!b.refreshToken) return fail(res, 400, 'refreshToken required', 'BAD_REQUEST');
    const fr = await jfetch('https://securetoken.googleapis.com/v1/token?key=' + FB_KEY, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ grant_type: 'refresh_token', grantType: 'refresh_token', refreshToken: b.refreshToken }),
    });
    if (!fr.ok || !fr.json || !fr.json.id_token) return fail(res, 401, 'Session expired, log in again', 'UNAUTHORIZED');
    return ok(res, fr.json);
  }
  if (method === 'GET' && pathname === '/locket/logout') {
    return ok(res, null);
  }

  // ----- everything below needs a real user token -----
  const ctype0 = String(req.headers['content-type'] || '');
  const isMultipart = ctype0.indexOf('multipart/form-data') === 0;
  let body = {};
  let files = [];
  if (isMultipart) {
    const m = /boundary=(?:"([^"]+)"|([^;]+))/.exec(ctype0);
    if (!m) return fail(res, 400, 'missing multipart boundary', 'BAD_REQUEST');
    let raw;
    try { raw = await readBody(req); } catch (e) { return fail(res, 413, 'body too large', 'TOO_LARGE'); }
    const parsed = parseMultipart(raw, (m[1] || m[2]).trim());
    body = parsed.fields;
    files = parsed.files.map(function (f) {
      const fp = path.join(UP, 'up' + Date.now() + '_' + Math.floor(Math.random() * 1e6));
      fs.writeFileSync(fp, f.data);
      return { fieldname: f.fieldname, originalname: f.originalname, path: fp, size: f.data.length };
    });
  } else if (method === 'POST') {
    try {
      const raw = await readBody(req);
      body = raw.length ? (JSON.parse(raw.toString('utf8')) || {}) : {};
    } catch (e) { return fail(res, 400, 'invalid json', 'BAD_JSON'); }
  }

  if (method === 'POST' && pathname === '/locket/getInfoUser') {
    const user = needAuth(req, res);
    if (!user) return;
    const fr = await jfetch('https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo?key=' + FB_KEY, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ idToken: user.token }),
    });
    const u = (fr.json && fr.json.users && fr.json.users[0]) || {};
    return ok(res, {
      uid: u.localId || user.uid, localId: u.localId || user.uid,
      email: u.email || '', displayName: u.displayName || '', username: '',
      firstName: '', lastName: '', profilePicture: u.photoUrl || '', customAuth: true,
    });
  }
  if (method === 'POST' && pathname === '/locket/getMomentV2') {
    const user = needAuth(req, res);
    if (!user) return;
    const users = (body.friendId && typeof body.friendId === 'string') ? [body.friendId] : [];
    const fr = await jfetch(LOCKET_API + '/getLatestMomentV2', {
      method: 'POST', headers: locketHeaders(user.token),
      body: JSON.stringify({ data: { excluded_users: [], users: users, should_count_missed_moments: true } }),
    });
    const result = (fr.json && fr.json.result) || {};
    const moments = Array.isArray(result.data) ? result.data : (Array.isArray(result.moments) ? result.moments : (Array.isArray(fr.json && fr.json.data) ? fr.json.data : []));
    if (!fr.ok) return fail(res, fr.status, (fr.json && (fr.json.message || fr.json.error)) || 'feed failed', 'FEED_FAILED');
    return ok(res, moments, { streak: result.streak || withStreak(moments), nextPageToken: null });
  }
  if (method === 'POST' && pathname === '/locket/getAllFriendsV2') {
    const user = needAuth(req, res);
    if (!user) return;
    const fr = await jfetch('https://firestore.googleapis.com/v1/projects/' + FB_PROJECT + '/databases/(default)/documents/users/' + user.uid + '/friends', {
      method: 'GET', headers: { 'Authorization': 'Bearer ' + user.token },
    });
    const docs = (fr.json && fr.json.documents) || [];
    const list = docs.map(function (d) {
      const uid = (d.fields && d.fields.user && d.fields.user.stringValue) || String(d.name || '').split('/').pop() || '';
      return { uid: uid, localId: uid, displayName: '', username: '', profilePicture: '' };
    }).filter(function (f) { return f.uid; });
    // Best-effort display names (up to 20) via official fetchUserV2.
    const slice = list.slice(0, 20);
    await Promise.all(slice.map(async function (f) {
      try {
        const ur = await jfetch(LOCKET_API + '/fetchUserV2', {
          method: 'POST', headers: locketHeaders(user.token), body: JSON.stringify({ data: { user_uid: f.uid } }),
        });
        const u = (ur.json && ur.json.result && ur.json.result.data) || {};
        const dn = [u.first_name, u.last_name].filter(Boolean).join(' ').trim();
        f.displayName = dn || u.username || u.displayName || '';
        f.username = u.username || '';
        f.firstName = u.first_name || '';
        f.lastName = u.last_name || '';
      } catch (e) { /* keep uid-only */ }
    }));
    return ok(res, list);
  }
  if (method === 'POST' && pathname === '/locket/getInfoMomentV2') {
    const user = needAuth(req, res);
    if (!user) return;
    const idMoment = body.idMoment || (body.data && body.data.moment_uid) || '';
    const fr = await jfetch(LOCKET_API + '/getLatestMomentV2', {
      method: 'POST', headers: locketHeaders(user.token),
      body: JSON.stringify({ data: { excluded_users: [], users: [], should_count_missed_moments: true } }),
    });
    const result = (fr.json && fr.json.result) || {};
    const moments = Array.isArray(result.data) ? result.data : [];
    return ok(res, moments.filter(function (m) { return m && (m.canonical_uid === idMoment || m.id === idMoment); }), { nextPageToken: null });
  }
  if (method === 'POST' && pathname === '/locket/reactToMoment') {
    const user = needAuth(req, res);
    if (!user) return;
    const mid = body.momentId || body.moment_uid || '';
    const emoji = String(body.emoji || body.reaction || '❤️').slice(0, 8);
    if (!mid) return fail(res, 400, 'missing momentId', 'BAD_REQUEST');
    const fr = await jfetch(LOCKET_API + '/reactToMoment', {
      method: 'POST', headers: locketHeaders(user.token),
      body: JSON.stringify({ data: { moment_uid: mid, reaction: emoji } }),
    });
    const result = (fr.json && fr.json.result) || {};
    if (Array.isArray(result.errors) && result.errors.length) return fail(res, 400, result.errors.join(', '), 'REACT_FAILED');
    if (!fr.ok) return fail(res, fr.status, 'react failed', 'REACT_FAILED');
    return ok(res, { momentId: mid, reactions: { [emoji]: 1 } });
  }
  if (method === 'POST' && pathname === '/locket/getAllMessageV2') {
    const user = needAuth(req, res);
    if (!user) return;
    const fr = await jfetch('https://firestore.googleapis.com/v1/projects/' + FB_PROJECT + '/databases/(default)/documents/users/' + user.uid + '/conversations?pageSize=20&orderBy=' + encodeURIComponent('last_updated desc'), {
      method: 'GET', headers: { 'Authorization': 'Bearer ' + user.token },
    });
    const docs = (fr.json && fr.json.documents) || [];
    const out = docs.map(function (doc) {
      const f = (doc.fields) || {};
      const sv = function (o) { return (o && o.stringValue) || ''; };
      const ts = function (o) { const t = (o && o.timestampValue) || ''; const ms = Date.parse(t); return Number.isNaN(ms) ? '' : new Date(ms).toISOString(); };
      const latest = (f.latest_message && f.latest_message.mapValue && f.latest_message.mapValue.fields) || null;
      return {
        id: sv(f.uid) || String(doc.name || '').split('/').pop(),
        text: latest ? sv(latest.body) : '',
        sender: latest ? sv(latest.sender) : '',
        createdAt: latest ? ts(latest.created_at) : ts(f.last_updated),
      };
    });
    return ok(res, out, { nextPageToken: null });
  }
  if (method === 'POST' && pathname === '/locket/sendMessage') {
    const user = needAuth(req, res);
    if (!user) return;
    const text = String(body.text || body.msg || '').slice(0, 1000);
    if (!text) return fail(res, 400, 'empty message', 'BAD_REQUEST');
    const fr = await jfetch(LOCKET_API + '/sendChatMessageV2', {
      method: 'POST', headers: locketHeaders(user.token),
      body: JSON.stringify({ data: {
        msg: text,
        analytics: {
          amplitude: { device_id: uuid4(), session_id: -1 },
          google_analytics: { app_instance_id: 'e88d4daed0ded172248753851bf67772' },
          android_version: '1.196.0', android_build: '406', platform: 'android',
        },
        client_token: uuid4(),
        moment_uid: body.moment_uid || body.momentId || null,
        receiver_uid: body.receiver_uid || body.receiverUid || null,
      } }),
    });
    if (!fr.ok) return fail(res, fr.status, (fr.json && (fr.json.message || fr.json.error)) || 'send failed', 'SEND_FAILED');
    return ok(res, fr.json && (fr.json.result || fr.json.data) || { text: text });
  }
  if (method === 'POST' && pathname === '/locket/postMomentV1') {
    const user = needAuth(req, res);
    if (!user) return;
    const file = files.filter(function (f) { return f.fieldname === 'file'; })[0];
    if (!file) return fail(res, 400, 'No media found', 'BAD_REQUEST');
    let optionsData = {};
    try { optionsData = JSON.parse(body.optionsData || '{}'); }
    catch (e) { optionsData = { caption: String(body.optionsData || '') }; }
    if (!optionsData.type) optionsData.type = 'default';
    const thumb = files.filter(function (f) { return f.fieldname === 'thumbnail'; })[0] || null;
    try {
      const buf = fs.readFileSync(file.path);
      const tbuf = thumb ? fs.readFileSync(thumb.path) : null;
      const out = await runUploadPipeline(user, buf, file.originalname, guessMime(file.originalname), tbuf, optionsData);
      return ok(res, out, { message: 'Upload media successfully' });
    } catch (e) {
      return fail(res, e.status && e.status < 500 ? e.status : 400, e.message || 'upload failed', 'UPLOAD_FAILED');
    } finally {
      files.forEach(function (f) { try { fs.unlinkSync(f.path); } catch (e2) { /* noop */ } });
    }
  }
  if (method === 'POST' && pathname === '/locket/postMomentV2') {
    // Compat: Dio shape {mediaInfo, options} — fetch the media bytes, same pipeline.
    const user = needAuth(req, res);
    if (!user) return;
    const mediaInfo = body.mediaInfo || {};
    const options = body.options || {};
    if (!options.type) options.type = 'default';
    if (!mediaInfo.url) return fail(res, 400, 'mediaInfo.url required', 'BAD_REQUEST');
    try {
      const r2 = await fetch(mediaInfo.url);
      if (!r2.ok) throw new Error('media download failed: HTTP ' + r2.status);
      const ab = await r2.arrayBuffer();
      const buf = Buffer.from(ab);
      let tbuf = null;
      if (mediaInfo.thumbnailUrl) {
        try {
          const tr = await fetch(mediaInfo.thumbnailUrl);
          if (tr.ok) tbuf = Buffer.from(await tr.arrayBuffer());
        } catch (e) { /* optional */ }
      }
      const out = await runUploadPipeline(user, buf, mediaInfo.name || 'upload.bin', mediaInfo.contentType || guessMime(mediaInfo.name || ''), tbuf, options);
      return ok(res, out, { message: 'Upload media successfully' });
    } catch (e) {
      return fail(res, 400, e.message || 'upload failed', 'UPLOAD_FAILED');
    }
  }
  sendJSON(res, 404, { success: false, message: 'not found' });
}
function guessMime(name) {
  const ext = String(name || '').split('.').pop().toLowerCase();
  if (ext === 'mp4' || ext === 'mov') return ext === 'mp4' ? 'video/mp4' : 'video/quicktime';
  if (ext === 'png') return 'image/png';
  if (ext === 'webp') return 'image/webp';
  if (ext === 'gif') return 'image/gif';
  return 'image/jpeg';
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
    if (!res.headersSent) sendJSON(res, 500, { success: false, message: (err && err.message) || 'error' });
    else try { res.end(); } catch (e2) { /* noop */ }
  });
});

server.listen(PORT, function () { console.log('LocketBridge (official-backed) listening on :' + PORT); });
