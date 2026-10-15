FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL=http://localhost:8081
WORKDIR /workspace
COPY flutter/pubspec.yaml ./
COPY flutter/ ./
RUN flutter pub get
RUN flutter build web --release -t lib/Main.dart --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:1.27-alpine
COPY flutter/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/build/web /usr/share/nginx/html
EXPOSE 10000
