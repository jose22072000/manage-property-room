# Manage Property Room

Sistema de gestión de habitaciones y propiedades.

```
manage-property-room/
├── manage_property_room_api/   ← API REST (Go 1.23 + SQLite + Docker)
└── manage_property_room_app/   ← App Flutter (web, Android, iOS)
```

Repositorio: **git@github.com:divergtech-dev/call-center-board.git**

---

## ⚡ Desarrollo local

> Requisitos: **Docker** y **Flutter 3.41+**

```bash
# 1. Levantar API
cd manage_property_room_api
docker compose up -d

# 2. Compilar y servir web
cd ../manage_property_room_app
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=http://localhost:8080
cd build/web && python3 -m http.server 5000
```

Abrir **http://localhost:5000** → login: `maria@app.local` / `admin123`

---

## 🚀 Despliegue en Dokploy — Plan completo paso a paso

### PASO 0 — Preparar el repositorio en GitHub

```bash
# En la raíz del proyecto
git init   # (si no está inicializado)
git remote add origin git@github.com:divergtech-dev/call-center-board.git

# Asegúrate de que .gitignore ignora los secretos:
#   manage_property_room_api/.env
#   manage_property_room_api/.env.prod
# (ya están en .gitignore)

git add .
git commit -m "chore: initial production-ready commit"
git push -u origin main
```

---

### PASO 1 — Desplegar la API en Dokploy

**En el panel de Dokploy:**

1. `New Application` → tipo **Docker Compose** → conectar repositorio `divergtech-dev/call-center-board`
2. **Compose path:** `manage_property_room_api/docker-compose.prod.yml`
3. `Environment → Variables` — añadir estas variables (valores reales):

   ```
   PORT=8080
   ENV=prod
   DB_DRIVER=sqlite
   DB_DSN=/data/app.db
   JWT_SECRET=<genera con: openssl rand -base64 48>
   JWT_TTL=24h
   CORS_ORIGINS=https://<dominio-de-la-web>
   BASE_URL=https://<dominio-de-la-api>
   ```

4. `Domains` → asignar dominio para la API, ej: `api.midominio.com` → puerto `8080`
5. `Volumes` → verificar que el volumen `/data` está persistido (ya está en el compose)
6. `Deploy` → esperar que el build termine
7. Verificar: `curl https://api.midominio.com/health` → `{"ok":true}`

> ⚠️ El archivo `.env.prod` del repo está en `.gitignore` — las variables van **solo en el panel de Dokploy**.

---

### PASO 2 — Desplegar la Web App en Dokploy

**En el panel de Dokploy:**

1. `New Application` → tipo **Docker Compose** → mismo repositorio
2. **Compose path:** `manage_property_room_app/docker-compose.prod.yml`
3. `Build → Build Arguments` — **NO en Environment Variables** — añadir:

   ```
   API_BASE_URL=https://<dominio-de-la-api>
   ```

   > ⚠️ `API_BASE_URL` se inyecta en **compile time** (Flutter `--dart-define`). Si lo pones en Environment Variables no funcionará.

4. `Domains` → asignar dominio para la web, ej: `app.midominio.com` → puerto `80`
5. `Deploy` → el build de Flutter tarda ~5 min la primera vez
6. Abrir `https://app.midominio.com` → debe mostrar el login

---

### PASO 3 — Build y distribución de la app Android

La APK **no se buildea en Dokploy** — se genera localmente y se sube al servidor.

#### 3a. Generar la APK release firmada

```bash
cd manage_property_room_app

# Build APK apuntando a la API de producción
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.midominio.com

# El APK estará en:
# build/app/outputs/flutter-apk/app-release.apk
```

#### 3b. Subir la APK al volumen de la API

```bash
# Copiar al servidor (ajusta usuario y host)
scp build/app/outputs/flutter-apk/app-release.apk \
    usuario@servidor:/ruta/al/volumen/data/downloads/app-release.apk
```

Si usas Dokploy con volumen local en el servidor, el path suele ser algo como:
```
/var/lib/docker/volumes/pmr-api-prod_data/_data/downloads/app-release.apk
```

Crear la carpeta si no existe:
```bash
ssh usuario@servidor "mkdir -p /ruta/al/volumen/data/downloads"
```

#### 3c. Verificar que la descarga funciona

```bash
curl -I https://api.midominio.com/download/app
# → HTTP/2 200
# → content-type: application/vnd.android.package-archive
```

Los usuarios descargan la APK desde el **botón verde Android** en la pantalla de login de la web.

---

### PASO 4 — Build y distribución de la app iOS

> ⚠️ iOS requiere **macOS + Xcode + certificado Apple Developer** ($99/año mínimo).  
> Para instalación directa (sin App Store) se necesita **Apple Developer Enterprise Program** ($299/año).  
> Alternativa sin coste extra: distribuir por **TestFlight**.

#### 4a. Generar el IPA (en macOS)

```bash
cd manage_property_room_app

flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.midominio.com

# El IPA estará en:
# build/ios/ipa/manage_property_room_app.ipa
```

#### 4b. Subir el IPA al servidor

```bash
scp build/ios/ipa/manage_property_room_app.ipa \
    usuario@servidor:/ruta/al/volumen/data/downloads/app-release.ipa
```

Los usuarios descargan el IPA desde el **botón azul iOS** en la pantalla de login de la web.

---

### PASO 5 — Actualizar la contraseña del admin

Tras el primer deploy, cambia la contraseña por defecto del seed:

```
POST https://api.midominio.com/auth/change-password
Authorization: Bearer <token>
{ "currentPassword": "admin123", "newPassword": "contraseña-segura" }
```

O desde la app: **Ajustes → Cambiar contraseña**.

---

### Checklist de producción

| # | Tarea | Estado |
|---|-------|--------|
| 1 | Repo subido a GitHub | ☐ |
| 2 | API desplegada en Dokploy | ☐ |
| 3 | `curl https://api.midominio.com/health` devuelve `{"ok":true}` | ☐ |
| 4 | Web desplegada en Dokploy con `API_BASE_URL` en Build Args | ☐ |
| 5 | Login funciona en `https://app.midominio.com` | ☐ |
| 6 | APK subida a `/data/downloads/app-release.apk` | ☐ |
| 7 | Botón "Android" en login descarga el APK | ☐ |
| 8 | Contraseña admin cambiada (no usar `admin123`) | ☐ |
| 9 | `CORS_ORIGINS` apunta al dominio real de la web | ☐ |
| 10 | `JWT_SECRET` es un secreto seguro (≥32 chars) | ☐ |

---

## Estructura de variables de entorno

### API (`manage_property_room_api/.env.example`)

| Variable | Requerida | Descripción |
|----------|-----------|-------------|
| `PORT` | No | Puerto HTTP. Default: `8080` |
| `ENV` | No | `dev` o `prod`. Default: `dev` |
| `DB_DSN` | No | Ruta SQLite. Default: `/data/app.db` |
| `JWT_SECRET` | **Sí** | Secreto JWT. Mínimo 32 chars. Generar: `openssl rand -base64 48` |
| `JWT_TTL` | No | Expiración token. Default: `24h` |
| `CORS_ORIGINS` | **Sí en prod** | Dominio de la web. Ej: `https://app.midominio.com` |
| `BASE_URL` | **Sí en prod** | URL pública de la API. Usada para links de descarga |

### Web App (`manage_property_room_app/.env.example`)

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `API_BASE_URL` | **Build Arg** | URL de la API. Se inyecta en compile time con `--dart-define` |

---

## Detalles técnicos

### API

| Elemento | Detalle |
|----------|---------|
| Lenguaje | Go 1.23 |
| Router | chi v5 |
| DB | SQLite (mattn/go-sqlite3, requiere CGO) |
| Auth | JWT (golang-jwt/jwt v5) + bcrypt |
| Imagen base | `golang:1.23-bookworm` (builder) + `debian:bookworm-slim` (runtime) |

### App Flutter

| Elemento | Detalle |
|----------|---------|
| Flutter | 3.41.9 / Dart 3.11.5 |
| State management | Riverpod 2.x (hand-written, sin codegen) |
| Router | go_router 14.x |
| Storage local | Hive |
| HTTP | package:http |

### Descarga de apps móviles

- **Android:** `GET /download/app` → sirve `/data/downloads/app-release.apk`
- **iOS:** `GET /download/ios` → sirve `/data/downloads/app-release.ipa`
- Ambos endpoints son **públicos** (sin autenticación)
- Botones visibles en la pantalla de login (solo en web)

---

## Comandos útiles

```bash
# API — levantar dev
cd manage_property_room_api && docker compose up -d

# API — logs
docker logs pmr-api -f

# API — rebuild producción
cd manage_property_room_api && docker compose -f docker-compose.prod.yml up --build -d

# Web — build dev
cd manage_property_room_app
flutter build web --release --dart-define=API_BASE_URL=http://localhost:8080
cd build/web && python3 -m http.server 5000

# Android — build release
flutter build apk --release --dart-define=API_BASE_URL=https://api.midominio.com

# iOS — build release (requiere macOS)
flutter build ipa --release --dart-define=API_BASE_URL=https://api.midominio.com

# Ejecutar en dispositivo Android físico (por ADB WiFi)
adb connect 192.168.x.x:PORT
flutter run -d 192.168.x.x:PORT --dart-define=API_BASE_URL=http://192.168.x.x:8080
```
