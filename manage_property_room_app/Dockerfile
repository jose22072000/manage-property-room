# ─── builder — compila Flutter web ───────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:3.41.9 AS builder

# API_BASE_URL se inyecta en compile-time via --dart-define
# En Dokploy: Environment → Build Args → API_BASE_URL=https://api.tuapp.com
ARG API_BASE_URL=https://api.example.com

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ─── runtime — nginx sirve los assets estáticos ───────────────────────────────
FROM nginx:1.27-alpine AS runtime

# Configuración básica: single-page app (redirige todo a index.html)
RUN printf 'server {\n\
  listen 80;\n\
  root /usr/share/nginx/html;\n\
  index index.html;\n\
  location / {\n\
    try_files $uri $uri/ /index.html;\n\
  }\n\
  # Cache de assets hashed\n\
  location ~* \\.(?:js|css|wasm|png|jpg|svg|ico|woff2?)$ {\n\
    expires 1y;\n\
    add_header Cache-Control "public, immutable";\n\
  }\n\
  gzip on;\n\
  gzip_types text/plain text/css application/javascript application/wasm;\n\
}\n' > /etc/nginx/conf.d/default.conf

COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80
