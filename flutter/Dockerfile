FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL=http://localhost:8081
ARG FIREBASE_API_KEY=
ARG FIREBASE_APP_ID=
ARG FIREBASE_MESSAGING_SENDER_ID=
ARG FIREBASE_PROJECT_ID=
ARG FIREBASE_AUTH_DOMAIN=
ARG FIREBASE_STORAGE_BUCKET=
ARG FIREBASE_WEB_VAPID_KEY=
WORKDIR /workspace
COPY flutter/pubspec.yaml ./
COPY flutter/ ./
RUN flutter pub get
RUN flutter build web --release -t lib/main.dart \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=FIREBASE_API_KEY=${FIREBASE_API_KEY} \
    --dart-define=FIREBASE_APP_ID=${FIREBASE_APP_ID} \
    --dart-define=FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID} \
    --dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
    --dart-define=FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN} \
    --dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET} \
    --dart-define=FIREBASE_WEB_VAPID_KEY=${FIREBASE_WEB_VAPID_KEY}

FROM nginx:1.27-alpine
COPY flutter/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/build/web /usr/share/nginx/html
EXPOSE 10000
