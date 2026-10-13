# 🌉 LocketBridge

Real self-host backend for Locket Legacy: Dio-compatible `/locket/*` routes
backed by the **official Locket API** using the end user's own account.
Zero npm dependencies — plain Node 20 (`http`/`fs`/`path`/`crypto` + global `fetch`).

## Run

```bash
cp .env.example .env   # optional; defaults work
node server.js         # or: docker compose up -d --build (from repo root)
open http://localhost:5001/
```

## How it works

| iOS calls (Dio shape) | Bridge does (official Locket) |
|---|---|
| `POST /locket/login {email,password}` | Firebase `verifyPassword` (`CLIENT_TYPE_IOS`) → `{idToken, refreshToken, localId}` |
| `POST /locket/refresh-token` | securetoken grant → `{id_token, …}` |
| `GET /locket/logout`, `POST /locket/getInfoUser` | `getAccountInfo` → Dio-shaped user |
| `POST /locket/getMomentV2` | `getLatestMomentV2` → official moments + streak |
| `POST /locket/getAllFriendsV2` | Firestore friends docs + `fetchUserV2` names |
| `POST /locket/postMomentV1` (multipart `file` + optional `thumbnail` + `optionsData`) | Firebase Storage resumable upload → official payload builders → official `postMomentV2` |
| `POST /locket/postMomentV2` | same pipeline (media fetched from `mediaInfo.url`) |
| `POST /locket/reactToMoment` | official `reactToMoment` |
| `POST /locket/getAllMessageV2`, `POST /locket/sendMessage` | Firestore conversations + official `sendChatMessageV2` |
| `GET /api/overlays`, `/connect`, `/api/health`, `POST /api/push/register` | local (same as mock) |

## Notes / limits

- Needs internet + a real Locket account (log in from the app).
- Images upload as JPEG, videos as MP4 (no server-side transcoding — the app
  sends a JPEG poster for videos, which the official video post requires).
- Method references: Dio self-host `api/` (upload recipe, payload builders)
  and jumpogpo `locket-api` (official endpoint shapes) — see repo `NOTICE.md`.
