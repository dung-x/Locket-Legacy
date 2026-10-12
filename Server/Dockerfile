FROM node:20-slim
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
ENV PORT=5001
EXPOSE 5001
CMD ["node", "server.js"]
