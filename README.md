# Manage Property Room

Sistema de gestión de habitaciones y propiedades, compuesto por una API REST en Go y una aplicación móvil/web en Flutter.

```
manage-property-room/
├── manage_property_room_api/   ← API REST (Go 1.23 + SQLite + Docker)
└── manage_property_room_app/   ← App Flutter (web, Android, iOS, Linux)
```

---

## Requisitos

| Herramienta | Versión mínima | Notas |
|-------------|---------------|-------|
| Docker + Docker Compose | v2 | Para la API |
| Go | 1.23 | Solo si corrés sin Docker |
| Flutter | 3.41+ / Dart 3.11.5+ | Para la app |
| GCC / CGO | — | Requerido para `mattn/go-sqlite3` |

---

## 1 · API (`manage_property_room_api/`)

### Levantar con Docker (recomendado)

```bash
cd manage_property_room_api

# Primera vez: crea .env a partir del ejemplo
cp .env.example .env   # editar JWT_SECRET en producción

# Build + run
docker compose up --build

# O en background
docker compose up -d
```

La API queda en `http://localhost:8080`.  
El archivo de base de datos se guarda en `manage_property_room_api/data/app.db` (volumen local).

#### Variables de entorno (`.env`)

| Variable | Default | Descripción |
|----------|---------|-------------|
| `PORT` | `8080` | Puerto del servidor HTTP |
| `ENV` | `dev` | `dev` o `prod` |
| `DB_DRIVER` | `sqlite` | Solo SQLite soportado |
| `DB_DSN` | `/data/app.db` | Ruta del archivo SQLite |
| `JWT_SECRET` | `dev-secret-change-me` | **Cambiar en producción** |
| `JWT_TTL` | `24h` | Duración del token JWT |
| `CORS_ORIGINS` | `*` | Orígenes permitidos (ej: `http://localhost:5000`) |

#### Comandos Make

```bash
make docker-up     # docker compose up --build (dev)
make docker-build  # solo buildear imagen
make docker-down   # bajar contenedor
make local         # correr sin Docker (requiere Go + GCC)
make build         # compilar binario a bin/api
make test          # correr tests
make clean         # eliminar bin/ y data/
```

### Levantar sin Docker (local)

```bash
cd manage_property_room_api
CGO_ENABLED=1 go run ./cmd/api
```

> `CGO_ENABLED=1` es obligatorio porque `go-sqlite3` usa CGO.

### Migraciones y seed

Las migraciones se corren automáticamente al arrancar. El seed inicial es **idempotente** (se puede correr múltiples veces sin duplicar datos).

**Usuario de prueba creado por el seed:**

| Campo | Valor |
|-------|-------|
| Email | `maria@app.local` |
| Contraseña | `admin123` |
| Rol | `admin` |

### Roles de usuario

| Rol | Permisos |
|-----|----------|
| `admin` | Acceso completo, gestión de usuarios, auditoría |
| `operator` | Crear/editar tarjetas y columnas, ver todo |
| `cleaning` | Ver tablero, marcar tarjetas como listas |
| `maintenance` | Ver tablero, acciones de mantenimiento |

### Endpoints principales

```
POST   /auth/login
POST   /auth/logout
GET    /auth/me

GET    /properties
POST   /properties
PATCH  /properties/:id
DELETE /properties/:id

GET    /properties/:id/board
POST   /columns
PATCH  /columns/:id
DELETE /columns/:id
POST   /columns/:id/config
POST   /columns/reorder

POST   /columns/:id/cards
PATCH  /cards/:id
DELETE /cards/:id
POST   /cards/:id/move
POST   /cards/:id/toggle-done
POST   /cards/:id/archive

GET    /fields
POST   /fields
PATCH  /fields/:id
DELETE /fields/:id
POST   /fields/reorder

GET    /users           (admin)
POST   /users           (admin)
PATCH  /users/:id       (admin)
DELETE /users/:id       (admin)

GET    /audit           (admin)
```

---

## 2 · App Flutter (`manage_property_room_app/`)

### Correr en web (desarrollo)

```bash
cd manage_property_room_app

flutter pub get

flutter run -d web-server \
  --web-port 5000 \
  --dart-define=API_BASE_URL=http://localhost:8080
```

La app queda en `http://localhost:5000`.

### Build web (producción)

```bash
flutter build web \
  --dart-define=API_BASE_URL=https://tu-api.com \
  --release
# Output en build/web/
```

Servir `build/web/` con cualquier servidor estático (nginx, Caddy, etc.).

> La app usa **hash URL strategy** (`#/ruta`), por lo tanto el servidor no necesita configuración especial de rewrite.

### Build Android

```bash
flutter build apk --dart-define=API_BASE_URL=https://tu-api.com
# Output en build/app/outputs/apk/release/
```

### Variables de compilación (`--dart-define`)

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `API_BASE_URL` | URL base de la API (sin `/` final) | `http://localhost:8080` |

### Estructura de la app

```
lib/
├── main.dart
├── app/
│   └── router.dart          ← GoRouter, rutas y guards de autenticación
├── application/
│   ├── notifiers/           ← Riverpod AsyncNotifier (BoardNotifier, FieldsNotifier…)
│   └── providers/           ← Providers de API, repo, estado global
├── core/                    ← Tema, constantes, utilidades
├── data/
│   └── remote/              ← Clientes HTTP (api_client.dart, board_api.dart…)
├── domain/
│   └── entities.dart        ← Modelos de dominio (BoardCard, BoardColumn, AuditEvent…)
├── permissions/
│   └── policy.dart          ← RBAC en el cliente
└── presentation/
    ├── pages/               ← Pantallas (board_page, settings_page, audit_page…)
    └── widgets/             ← Componentes reutilizables
```

---

## 3 · Flujo de trabajo típico

1. Levantar API: `cd manage_property_room_api && docker compose up -d`
2. Correr app: `cd manage_property_room_app && flutter run -d web-server --web-port 5000 --dart-define=API_BASE_URL=http://localhost:8080`
3. Abrir `http://localhost:5000` y loguearse con `maria@app.local` / `admin123`

---

## 4 · Posibles errores y soluciones

### `CGO_ENABLED` no activo (sin Docker)
```
// error: could not determine kind of name for C.sqlite3_...
```
**Solución:** `export CGO_ENABLED=1` antes de `go run` o `go build`.

### Puerto 8080 ya en uso
```
bind: address already in use
```
**Solución:** `docker compose down` o cambiar `PORT` en `.env` y en `docker-compose.yml`.

### CORS rechazado en el browser
El header `Origin` del browser no está en `CORS_ORIGINS`.  
**Solución:** Poner `CORS_ORIGINS=*` (dev) o el origen exacto en producción.

### `flutter run` no encuentra dispositivo web
```
No supported devices found
```
**Solución:** Usar `-d web-server` explícitamente o instalar Chrome/Chromium.

### App muestra "No autorizado" después de rebuild de la API
El JWT_SECRET cambió o la DB fue reseteada — los tokens anteriores son inválidos.  
**Solución:** Cerrar sesión y volver a loguearse.

### Auditoría muestra `?` como actor
Tokens JWT emitidos antes de agregar el claim `name`. La API ahora hace fallback al nombre de la DB automáticamente. Si persiste, simplemente cerrar sesión y volver a entrar.

### Base de datos no encontrada en producción
El volumen `./data` no existe o no tiene permisos.  
**Solución:** `mkdir -p data && chmod 755 data` en `manage_property_room_api/`.

### `flutter pub get` falla en Linux (falta libgtk)
```
Package gtk+-3.0 was not found
```
**Solución (Ubuntu/Debian):**
```bash
sudo apt-get install libgtk-3-dev libblkid-dev liblzma-dev
```

### Hot reload / restart en desarrollo

Mientras `flutter run` está corriendo en terminal:
- `r` → hot reload (recarga código, mantiene estado)
- `R` → hot restart (reinicia app completa)
- `q` → salir

---

## 5 · Producción

### API
- Cambiar `JWT_SECRET` por un secreto seguro (≥ 32 caracteres)
- Poner `ENV=prod`
- Usar un volumen persistente externo para `/data`
- Poner `CORS_ORIGINS=https://tu-dominio.com`
- Poner la API detrás de un reverse proxy (nginx / Caddy) con HTTPS

### App (web)
```bash
flutter build web --release --dart-define=API_BASE_URL=https://tu-api.com
# Servir build/web/ con nginx o similar
```

Ejemplo de configuración nginx mínima:
```nginx
server {
    listen 80;
    root /var/www/manage-property-room;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```
