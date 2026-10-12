// Minimal self-host mock implementing upstream API contract:
// POST /locket/login, POST /locket/refresh-token, GET /locket/logout,
// POST /locket/getInfoUser, POST /locket/getAllFriendsV2,
// POST /locket/postMomentV1 (multipart), POST /locket/postMomentV2 (json),
// POST /locket/getMomentV2, POST /locket/getInfoMomentV2, POST /locket/getAllMessageV2
// Data is in-memory + ./uploads on disk. Configure via .env / env vars.
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 5001;
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

app.get('/', (req, res) => res.json({ message: '🚀 LocketLegacy mock server running' }));
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
