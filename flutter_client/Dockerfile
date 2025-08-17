# Flutter Web static hosting via nginx for Cloud Run
FROM node:20-alpine AS build-env
# Expect the project already contains flutter build output, but we can just serve source with a simple dev server
# For production, you should run `flutter build web --release` and copy the build/web here.

FROM nginx:alpine
ENV PORT=8080
COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
