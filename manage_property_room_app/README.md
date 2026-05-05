# Gestión de Propiedades — manage_property_room_app

App Flutter multi-plataforma para gestionar propiedades, habitaciones y trabajadores. Funciona en **Linux desktop** y **Web** (Chrome/navegador).

---

## Índice
1. [Requisitos previos](#requisitos-previos)
2. [Instalar Flutter](#instalar-flutter)
3. [Clonar y preparar el proyecto](#clonar-y-preparar-el-proyecto)
4. [Ejecutar la app](#ejecutar-la-app)
5. [Ver dispositivos disponibles](#ver-dispositivos-disponibles)
6. [Acceder a la versión web](#acceder-a-la-versión-web)
7. [Usuarios y roles](#usuarios-y-roles)
8. [Errores comunes y soluciones](#errores-comunes-y-soluciones)

---

## Requisitos previos

| Herramienta | Versión mínima | Cómo comprobar |
|---|---|---|
| Flutter SDK | 3.x stable | `flutter --version` |
| Dart SDK | incluido con Flutter | `dart --version` |
| Linux (Ubuntu/WSL) | Ubuntu 22+/24+ | — |
| Python 3 | 3.x (para servir web) | `python3 --version` |
| Android Studio + SDK | opcional (solo Android) | `flutter doctor` |

### Dependencias del sistema (Ubuntu/WSL)

```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
```

---

## Instalar Flutter

```bash
# 1. Descargar Flutter SDK
cd ~
git clone https://github.com/flutter/flutter.git -b stable

# 2. Añadir al PATH (añadir también en ~/.bashrc o ~/.zshrc)
export PATH="$HOME/flutter/bin:$PATH"

# 3. Verificar instalación
flutter doctor
```

---

## Clonar y preparar el proyecto

```bash
# Clonar repositorio
git clone <url-del-repo> manage_property_room_app
cd manage_property_room_app

# Instalar dependencias
flutter pub get
```

---

## Ejecutar la app

### Linux Desktop (ventana nativa)

```bash
flutter run -d linux
```

La app abre una ventana GTK directamente en el escritorio (o en WSL si tienes un servidor X11/Wayland configurado).

### Web (navegador)

**Opción A — Desarrollo (hot reload):**
```bash
flutter run -d web-server --web-port 8080
# Luego abrir en el navegador: http://localhost:8080
```

**Opción B — Producción compilada (recomendado en WSL):**
```bash
# 1. Compilar
flutter build web --release

# 2. Servir
cd build/web
python3 -m http.server 8080

# 3. Abrir en Chrome (Windows o Linux): http://localhost:8080
```

**En WSL con Chrome en Windows:**
```bash
export CHROME_EXECUTABLE="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
flutter run -d web-server --web-port 8080
```

### Android (requiere Android SDK)

```bash
# Listar dispositivos/emuladores
flutter devices

# Ejecutar en dispositivo Android conectado
flutter run -d <device-id>

# Ejecutar en emulador
flutter emulators --launch <emulator-id>
flutter run -d emulator-<id>
```

---

## Ver dispositivos disponibles

```bash
# Ver todos los dispositivos conectados
flutter devices

# Ver emuladores disponibles
flutter emulators

# Diagnóstico completo
flutter doctor -v
```

**Ejemplo de salida en este entorno (WSL):**
```
Found 1 connected device:
  Linux (desktop) • linux • linux-x64 • Ubuntu 24.04.1 LTS
```

> **¿Por qué solo veo Linux?**
> En WSL sin Android SDK instalado ni emulador configurado, solo está disponible el target Linux.
> Para tener Android: instala Android Studio → configura un AVD → conecta un dispositivo físico por USB (con USB passthrough a WSL).
> Para tener Web/Chrome: funciona con `flutter build web` + servidor HTTP (ver arriba).

---

## Acceder a la versión web

Una vez lanzado el servidor en el paso anterior:

| Desde | URL |
|---|---|
| Windows (host) | `http://localhost:8080` |
| Linux / WSL | `http://localhost:8080` |
| Red local | `http://<IP-WSL>:8080` |

> **La web sale en blanco:**
> Esto suele pasar cuando `flutter run -d web-server` no compiló correctamente.
> Usa siempre **Opción B** (build + python3 server): es más estable en WSL.

---

## Usuarios y roles

La app viene con datos de prueba. Selecciona un usuario en el menú **"Sin usuario"** (arriba a la derecha).

| Usuario | Iniciales | Rol | Contraseña |
|---|---|---|---|
| María | MA | Administrador | — |
| Carlos | CA | Limpieza | — |
| Lucía | LU | Limpieza | — |
| Diego | DI | Mantenimiento | — |

> No hay contraseñas: el "login" es solo seleccionar el usuario del desplegable.
> La contraseña de sudo del sistema es `123`.

### Permisos por rol

| Función | Sin usuario | Admin (María) | Limpieza/Mant. |
|---|---|---|---|
| Ver propiedades | ✅ | ✅ | Solo asignadas |
| Añadir propiedad | ✅ | ✅ | ❌ |
| Asignar trabajadores a propiedad | ✅ | ✅ | ❌ |
| Ver tablero (board) | ✅ | ✅ | ✅ |
| Gestionar usuarios | ✅ | ✅ | ❌ |
| Ajustes | ✅ | ✅ | ❌ |

### Cómo asignar trabajadores a una propiedad

**Desde Propiedades:**
1. En la tarjeta de la propiedad, toca el icono 👥 (personas) en la esquina superior derecha.
2. Se abre un panel con la lista de trabajadores activos.
3. Marca/desmarca con los checkboxes.

**Desde Usuarios:**
1. Ve a la sección **Usuarios** en el menú lateral.
2. En la tarjeta de cada trabajador verás las propiedades asignadas como chips de colores.
3. Toca el icono 🏠 (casa) para abrir el panel de asignación de propiedades.
4. Marca/desmarca las propiedades.
5. También puedes quitar una propiedad tocando la **X** en el chip.

---

## Errores comunes y soluciones

### `flutter: command not found`
Flutter no está en el PATH.
```bash
export PATH="$HOME/flutter/bin:$PATH"
# Añade esa línea en ~/.bashrc y ejecuta: source ~/.bashrc
```

### `Unable to locate Android SDK`
No afecta a Linux desktop ni Web. Si necesitas Android:
```bash
# Instala Android Studio y luego:
flutter config --android-sdk /path/to/android-sdk
flutter doctor --android-licenses
```

### `Cannot find Chrome executable`
En WSL, Chrome no está en el PATH de Linux.
```bash
export CHROME_EXECUTABLE="/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
# O usa la Opción B: flutter build web + python3 server
```

### La app web sale en blanco (blank page)
- El proceso `flutter run -d web-server` terminó o falló.
- Usa `flutter build web --release` y sirve con `python3 -m http.server 8080`.

### `Error: Build process failed` (Linux desktop)
```bash
# Instalar dependencias del sistema
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev

# Limpiar caché y volver a intentar
flutter clean
flutter pub get
flutter run -d linux
```

### Puerto 8080 en uso
```bash
sudo fuser -k 8080/tcp
# Luego vuelve a lanzar el servidor
```

### Datos no se guardan / app arranca vacía
La app usa **Hive** (base de datos local). Si hay corrupción del almacenamiento:
```bash
# Limpia la caché de Hive (web: borra IndexedDB del navegador; desktop: borra ~/.local/share/manage_property_room_app/)
flutter clean
flutter pub get
flutter run -d linux  # o build web
```

### No aparecen los trabajadores en la hoja de asignación
- Asegúrate de que existen usuarios con rol **Limpieza** o **Mantenimiento** y que están **activos**.
- Ve a la sección **Usuarios** y verifica que no están marcados como "Inactivo".

---

## Estructura del proyecto

```
lib/
├── main.dart                  # Punto de entrada, inicialización Hive
├── domain/
│   ├── entities.dart          # Modelos: AppUser, Property, BoardCard…
│   └── enums.dart             # UserRole, CardKind, FieldType…
├── data/
│   ├── seed_data.dart         # Datos iniciales de prueba
│   ├── sources/               # Implementaciones Hive
│   └── repositories/         # Contratos de repositorio
├── application/
│   ├── notifiers/             # Riverpod notifiers (estado global)
│   └── providers/             # Providers de repositorios
├── permissions/
│   └── policy.dart            # Reglas de acceso por rol
└── presentation/
    ├── pages/                 # Pantallas (Properties, Board, Users…)
    ├── router/                # GoRouter + rutas
    ├── theme/                 # Tema visual (colores, gradientes)
    └── widgets/               # Componentes reutilizables
```

---

## Comandos útiles

```bash
# Hot reload mientras la app está corriendo (terminal interactivo)
r         # hot reload
R         # hot restart
q         # salir

# Tests
flutter test

# Linting
flutter analyze

# Generar build de producción web
flutter build web --release

# Generar APK Android (requiere Android SDK)
flutter build apk --release
```

---

## Notas WSL

- La app **Linux desktop** se abre como ventana gráfica. Necesitas un servidor X11/Wayland en Windows (ej. VcXsrv, X410, o WSLg en Windows 11).
- Windows 11 con **WSLg** abre ventanas Linux nativas automáticamente, sin configuración extra.
- La app **web** funciona perfectamente desde WSL: compila con Flutter y sirve con Python. El navegador Windows accede en `http://localhost:8080`.


- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
