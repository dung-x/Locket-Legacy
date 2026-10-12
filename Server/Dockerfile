# LocketLegacy self-host mock — zero npm dependencies (node builtins only),
# so no registry access is needed at build time.
FROM node:20-slim

WORKDIR /app

# Only source is copied; `node server.js` needs nothing installed.
COPY . .

ENV PORT=5001
EXPOSE 5001
CMD ["node", "server.js"]
