# 📸 Locket Legacy — iOS (Objective-C, iOS 12+)

Native iOS port of [Client-Locket-Dio](https://github.com/doi2523/Client-Locket-Dio) (web).
Same product idea, same screens, rewritten in **Objective-C + UIKit**, **minimum iOS 12.0**, zero third-party pods.

## Screens (Core MVP, mirrors web)

| Web (`apps/self-hosted/web/src`) | iOS |
|---|---|
| `pages/Public/Login` | `LDLoginViewController` — labeled rows ① API server / ② email / ③ password, 📷 Scan QR button |
| `pages/LocketCameraBeta/MainHomeScreen` (live feed, flip, flash) | `LDCameraViewController` — AVFoundation live preview, front/back, flash, photo shutter, video REC, library pick |
| `components/common/CropImageStudio` | Square crop in camera + preview |
| Preview / caption / overlay | `LDPreviewViewController` — caption field, audience segment, `postMomentV1` multipart upload |
| Moment history (`getMomentV2`) | `LDFeedViewController` — 3-col grid (`LDMomentCell`) |
| Friends (`getAllFriendsV2`) | `LDFriendsViewController` |
| Profile (`getInfoUser`) | `LDProfileViewController` — user info, streak, backend summary, entry to Settings |
| Settings (new) | `LDSettingsViewController` — backend preset, theme, push, storage, about, logout |
| Server QR connect | `LDQRScannerViewController` — AVFoundation QR scan, accepts `locketlegacy://connect?api=…`, raw URL, or JSON |

## Connect via QR (phone ↔ Docker)

1. `docker compose up -d --build`, then open the dashboard on your computer: `http://<lan-ip>:5001/`
   (use the machine's LAN IP, not localhost — the phone must reach it).
2. Dashboard section ① shows a QR encoding `locketlegacy://connect?api=http://<lan-ip>:5001`.
3. In the app: Login (or Profile) → **📷 Scan QR** → point at the code. The ① row fills in.
4. Machine-readable too: `GET /connect` → `{ apiBaseUrl, qrPayload }`, `GET /api/health`.

## API mapping (upstream `apps/self-hosted/api`)

Base URL default `http://localhost:5001`, routes under `/locket` (see upstream `API_DOCS.md` + `src/routes/locket.route.js`):

- `POST /locket/login` → `LDAPIClient loginWithEmail`
- `POST /locket/refresh-token`, `GET /locket/logout`
- `POST /locket/getInfoUser`, `POST /locket/getAllFriendsV2`
- `POST /locket/postMomentV1` (multipart `file` + `optionsData.caption`) → legacy path, kept as fallback
- `POST /locket/postMomentV2` (JSON `mediaInfo` + `options`) → used by the original flow
- `POST /locket/getMomentV2`, `POST /locket/getInfoMomentV2`, `POST /locket/getAllMessageV2`
- `POST /api/presignedV3` + `PUT /api/upload/<token>` → storage grants, same as upstream `storage` service

Send path (identical to web `createRequestPayloadV5` + `PostMoments`):
1. filename `locketdio_<ms>_<localId>_cli<ver>.<ext>` → `POST {api}/api/presignedV3`
   (falls back to same host `:5003` for upstream split-host) → `{url, publicURL, key}`
2. `PUT` raw bytes to `url` with the file's `Content-Type`
3. `POST /locket/postMomentV2` `{model: Version-UploadmediaV3.1, mediaInfo: {url, path, name, size, uploadedAt, type}, options: {caption, audience, recipients, …}, contentType}`

Auth: `Authorization: Bearer <idToken>`, token persisted in `NSUserDefaults`.

## Project layout

```
LocketLegacy.xcodeproj/        hand-written, Xcode 15 compatible
LocketLegacy/
  main.m, AppDelegate.h/m      no SceneDelegate (iOS 12 safe)
  Config.h/m                   base URL store
  API/LDAPIClient.h/m
  Models/LDUser, LDMoment, LDFriend
  Controllers/ Login, MainTab, Camera, Preview, Feed, Friends, Profile, QRScanner
  Views/ LDMomentCell, LDFriendCell
  Assets.xcassets/AppIcon.appiconset  gold-on-black camera glyph (all sizes + 1024)
  Info.plist, LaunchScreen.storyboard
Server/                        self-host mock (ZERO npm deps — node builtins only) implementing /locket/* + dashboard UI at / for dev
docker-compose.yml             `docker compose up -d --build` → API on :5001
.github/workflows/ios-build.yml  macOS build + docker build
```

## Run

### iOS
1. Open `LocketLegacy.xcodeproj` in Xcode 14+.
2. Select iPhone simulator (iOS 12+), Run.
3. Pick the backend in Login → ① (or later in Profile → ⚙️ Settings):
   - **Self-host Docker**: your `http://<lan-ip>:5001` (or 📷 Scan QR from the dashboard).
   - **Original Locket Dio API** (needs the dev's permission): auth → `auth.locket-dio.com`
     (`loginV2`, `refresh-token`, `logout`, `getInfoUser`), data → `api.locket-dio.com`
     (`postMomentV2`/`createMomentPayloadV2`, moments, friends, messages, reactions),
     storage → `storage.locket-dio.com` (`presignedV3`) — with the same public
     `x-api-key` / `x-app-*` headers the web client sends.

### Self-host mock (from manual)

Upstream manual (`apps/self-hosted/README.md`) requires Firebase/R2 secrets and 3 services
(api :5001, storage :5003, web :5173). For iOS dev this repo ships a zero-config mock
with the same routes:

```bash
docker compose up -d --build
open http://localhost:5001/        # dashboard: connect QR + login/data/upload testers
curl http://localhost:5001/api/health
# login test:
curl -X POST http://localhost:5001/locket/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"demo@locket.legacy","password":"x"}'
```

No `npm install` runs during `docker build` (server uses node builtins only), so a
blocked/unreachable npm registry will not break the build. If `docker build` still
fails pulling `node:20-slim` with DNS errors (`EAI_AGAIN`), fix the host's Docker DNS:

```bash
docker run --rm alpine nslookup registry-1.docker.io   # should resolve
# if not: echo '{"dns":["8.8.8.8","1.1.1.1"]}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

To use the real upstream backend instead:
```bash
git clone https://github.com/doi2523/Client-Locket-Dio /tmp/upstream
cd /tmp/upstream/apps/self-hosted
cp api/.env.example api/.env.production
# fill FIREBASE_*, LOCKET_API_BASE, etc.
docker compose up -d --build
```
Then point the iOS app at that host.

### CI
`ios-build.yml` builds with `xcodebuild -sdk iphonesimulator ... CODE_SIGNING_ALLOWED=NO`
on `macos-15`, plus builds the mock Docker image.

## Notes / limits
- Objective-C, UIKit programmatic layout (no SwiftUI, no SF Symbols, no compositional layout) for iOS 12.
- No push notifications / PWA / music overlay in MVP (web-only features).
- Image download in feed uses plain `NSData dataWithContentsOfURL` for simplicity.
