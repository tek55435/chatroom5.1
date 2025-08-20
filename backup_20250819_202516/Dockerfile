FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production
COPY . .
# Flexible entrypoint: default to index.js, override with ENTRY_FILE env var (e.g., ephemeral-chat-server.js)
ENV ENTRY_FILE=index.js
EXPOSE 8080
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/bin/sh", "/entrypoint.sh"]
