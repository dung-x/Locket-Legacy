# Notices — third-party methods ported into LocketBridge

`Server/bridge/server.js` re-implements (in dependency-free Node, no copied
files) the following MIT-licensed works. Full license texts ship with the
originals; this project is also MIT licensed.

1. **Client-Locket-Dio** by Dio (@doi2523) — https://github.com/doi2523/Client-Locket-Dio
   MIT. Ported behaviors: self-hosted `/locket/*` route contract, Firebase
   Storage resumable-upload recipe, official `postMomentV2` payload builders
   (base/image/video + analytics), Firestore friends/chat reads, Firebase
   `verifyPassword`/`securetoken` login with `CLIENT_TYPE_IOS`.

2. **locket-api** by jumpogpo — https://github.com/jumpogpo/locket-api
   MIT. Referenced for the official Locket API surface it documents
   (`getLatestMomentV2` / `reactToMoment` / `fetchUserV2` request shapes,
   Firebase identity-toolkit + securetoken flows, Locket app keys/headers).
   No code vendored; all calls re-implemented with `fetch`.
