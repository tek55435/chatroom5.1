# Chat WS Cloud Run container
FROM node:20-alpine
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --only=production
COPY ephemeral-chat-server.js ./
RUN mkdir -p public
ENV PORT=8080
EXPOSE 8080
CMD ["npm", "start"]
