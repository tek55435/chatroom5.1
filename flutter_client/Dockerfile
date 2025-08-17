# Flutter Web static hosting via nginx for Cloud Run
FROM node:20-alpine AS build-env
# Expect the project already contains flutter build output, but we can just serve source with a simple dev server
# For production, you should run `flutter build web --release` and copy the build/web here.

FROM nginx:alpine
ENV PORT=8080
REM Dockerfile contents removed per user request to undo deployment artifacts that required Artifact Registry permissions.
REM If you need to recreate this later, restore from backup or follow DEPLOY-CLOUD-RUN.md instructions.
