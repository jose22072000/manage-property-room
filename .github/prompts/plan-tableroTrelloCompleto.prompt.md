# Plan: Tablero estilo Trello completo (Fase 3)

Convertir el tablero actual de 6 columnas fijas en un Trello completo: columnas dinámicas creables/editables por usuario, modal de detalle de tarjeta con campos personalizados y comentarios, y `PropertiesPage` con tarjetas estilo "tableros marcados" de Trello (gradientes generados como fondo).

Bump `pmr-board-v2` → `pmr-board-v3` con migración: las habitaciones existentes se asignan a columnas por defecto según su `status` actual.

---

## Fases

### Fase 1 — Modelo de datos y store (foundation)

1. **Tipos en `src/types/domain.ts`**:
   - `Column = { id, propertyId, title, color, position, archived? }`
   - `Card` unificada (reemplaza `RoomCard` y `PropertyTask`): `{ id, propertyId, columnId, title, description?, isDone, position, createdAt, kind: "ROOM" | "TASK" | "FREE", customFields?, roomCode?, cleanedBy?, cleanedAt?, priority?, hasNextDayCheckin?, checkinDate?, assignedTo? }`.
   - `CardCustomFields = { salida?, entrada?: bool, cobrar?, statusMant?, pendiente? }` (los campos de la foto 2).
   - `Comment = { id, cardId, author, text, createdAt }`
   - `ActivityEvent = { id, cardId, type, message, createdAt }`
   - `COLUMN_COLORS`: paleta de 10 entradas (verde, amarillo, naranja, rojo, morado, azul, cian, lima, rosa, gris).

2. **Reescribir `src/store/boardStore.ts`** (persist key `pmr-board-v3`):
   - State: `columns: Record<propertyId, Column[]>`, `cards: Record<columnId, Card[]>`, `archivedCards: Card[]`, `comments: Record<cardId, Comment[]>`, `activity: Record<cardId, ActivityEvent[]>`.
   - Acciones de columna: `addColumn`, `renameColumn`, `setColumnColor`, `moveColumn(id, toPosition)`, `archiveColumn(id)`, `archiveAllCardsIn(columnId)`, `copyColumn(id)`.
   - Acciones de card: `addCard`, `updateCard`, `moveCard`, `toggleCardDone`, `archiveCard`, `addComment`.
   - `loadProperty(propertyId)`: si no hay columnas, sembrar las 6 default y migrar `rooms[propertyId]` previas según su `status`. Eventos de actividad se generan automáticamente en `moveCard`/`archiveCard`/`toggleCardDone`/`addCard`.
   - Constantes `EMPTY_*` fuera de selectores (evitar loops infinitos).

3. **`src/services/cardsService.ts`**:
   - `seedDefaultColumns(propertyId)`: 6 columnas con colores — Apartamentos libres (verde), Aviso del día (amarillo), Salidas (gris), Hecho (verde-esmeralda), Compras (morado), Mantenimiento (naranja).
   - `migrateRoomsToCards(rooms[])`: mapea `status → columnId`.

### Fase 2 — UI: Columnas dinámicas

4. **Reescribir `src/components/board/Board.tsx`**:
   - Render `columns.map(col => <BoardColumn />)` ordenadas por `position`. Eliminar el array `SECTIONS` hardcoded.
   - Botón final **"+ Añade otra lista"** que abre input inline → llama `addColumn`.
   - Drop targets `useDroppable` por columna; drag de cards entre columnas → `moveCard(id, toColumnId)`.

5. **Nuevo `src/components/board/BoardColumn.tsx`** (reescritura):
   - Header: título editable inline (doble-click), contador, botón **[⋯]** menú, botón **[+]** añadir tarjeta.
   - Borde superior 3px del color de columna; fondo header tinte 50 del color.
   - Lista de cards; "+ Añade una tarjeta" al final del cuerpo (input inline tipo Trello).

6. **Nuevo `src/components/board/ColumnActionsMenu.tsx`** (popover, foto 3 + foto 8):
   - Añadir tarjeta · Copiar lista · Mover lista · Mover todas las tarjetas de esta lista · Ordenar por · Cambiar color de lista (paleta 5×2) · Quitar color · Archivar esta lista · Archivar todas las tarjetas de esta lista.

7. **Nuevo `src/components/board/AddListInline.tsx`**:
   - Input "Introduce el nombre de la lista…" + "Añadir lista" + X (foto 7).

### Fase 3 — Tarjeta + modal de detalle

8. **`CardItem.tsx`** (renombre de `RoomCardItem.tsx` simplificado):
   - Card sencilla: checkbox redondo (toggle done sin abrir modal), título, badges (URGENTE/Alta/Baja), preview de descripción (1 línea), iconos (💬 si comentarios, 📅 si checkin, 👤 si asignado).
   - Click en cuerpo → abre `CardDetailModal`.
   - Borde izq coloreado solo si `priority HIGH` o `isDone`.

9. **Nuevo `src/components/board/CardDetailModal.tsx`** (foto 2):
   - Layout 2 columnas. Izq: título editable → "en lista [columna ▾]" → descripción (textarea) → campos personalizados (Salida/Entrada/Cobrar/Status Mantenimiento/PENDIENTE). Der: barra de acciones (Añadir, Votar, Archivar, Eliminar) + Comentarios (textarea + lista cronológica) + Actividad (log derivado).
   - Cierre: Esc, click backdrop, X.

10. **Comentarios y actividad**:
    - `addComment(cardId, text)` registra autor (usuario actual) + timestamp.
    - Actividad se inserta automáticamente al crear/mover/archivar/completar (read-only).

### Fase 4 — PropertiesPage estilo Trello (foto 1)

11. **Reescribir `src/pages/PropertiesPage.tsx`**:
    - Sección **"Tableros marcados"**: grid de tarjetas rectangulares (~250×140) con **gradiente generado** determinístico por `propertyId`.
    - Overlay oscuro 30% para legibilidad.
    - Esquina sup-der: ⭐ visual (favorito sin lógica).
    - Pie: nombre en blanco bold con sombra ("Limpieza FN13").
    - Hover: lift + brillo.
    - Sección **"Visto recientemente"** debajo (top 4, persistido en `userStore.recentVisits[]`).

12. **`src/lib/propertyVisuals.ts`**:
    - `getPropertyGradient(id): string` — 8-10 combinaciones predefinidas tipo `bg-gradient-to-br from-blue-500 to-purple-700`.

### Fase 5 — Migración y resto de páginas

13. **Migración localStorage v2 → v3**: al cargar v3 por primera vez, si existe v2, migrar columnas+cards. Conservar v2 intacto (rollback).

14. **`TodoPage` y `ArchivePage`**: actualizar para leer del nuevo modelo (`cards` + `archivedCards`). Filtros: pendiente = no `isDone`, urgente = `priority HIGH | hasNextDayCheckin`.

15. **`AddRoomModal` → `AddCardModal`**: mismos campos pero recibe `defaultColumnId` en vez de `defaultStatus`.

---

## Relevant files

### A crear
- `src/components/board/BoardColumn.tsx`
- `src/components/board/ColumnActionsMenu.tsx`
- `src/components/board/ColumnColorPicker.tsx`
- `src/components/board/CardItem.tsx`
- `src/components/board/CardDetailModal.tsx`
- `src/components/board/AddListInline.tsx`
- `src/lib/propertyVisuals.ts`
- `src/services/cardsService.ts`

### A modificar (cambios mayores)
- `src/types/domain.ts` — `Column`, `Card` unificada, `Comment`, `ActivityEvent`, `COLUMN_COLORS`.
- `src/store/boardStore.ts` — reescritura completa, persist key `pmr-board-v3`.
- `src/components/board/Board.tsx` — render dinámico desde store, sin `SECTIONS`.
- `src/pages/PropertiesPage.tsx` — grid Trello con gradientes.
- `src/pages/TodoPage.tsx`, `src/pages/ArchivePage.tsx` — leer de `cards`/`archivedCards`.
- `src/components/board/AddRoomModal.tsx` → `AddCardModal.tsx`.

### A eliminar después de migrar
- Lógica `SECTIONS` y `resolveDropStatus` en `Board.tsx` actual.
- `RoomCardItem.tsx` (sustituido por `CardItem.tsx`).

---

## Verification

1. `npm run build` pasa sin errores TS.
2. **Migración**: con v2 poblado, abrir → 6 columnas con cards distribuidas correctamente. Sin pérdida de datos.
3. **Crear columna**: "+ Añade otra lista" → "Test" → Enter → aparece al final.
4. **Renombrar**: doble-click en título → editar → Enter guarda.
5. **Cambiar color**: ⋯ → "Cambiar color de lista" → click swatch → header y borde superior cambian.
6. **Archivar lista**: ⋯ → "Archivar esta lista" → confirmar → desaparece, sus cards van a `/archive`.
7. **Archivar todas las tarjetas**: ⋯ → opción correspondiente → cards en archivo, columna vacía.
8. **Modal de tarjeta**: click en card → modal con título, descripción, campos personalizados, comentarios. Editar descripción → persiste tras recargar.
9. **Comentario**: escribir + Guardar → aparece con avatar.
10. **Actividad**: mover card → "<usuario> movió de X a Y" en log.
11. **Toggle done**: click checkbox → tachado verde, sin abrir modal.
12. **PropertiesPage**: 5 propiedades con gradientes consistentes; "Visto recientemente" tras visitar.
13. **Sin loops**: navegar/abrir modales/editar → consola limpia.
14. **Mobile**: scroll horizontal del board funciona; modal full-screen <768px.

---

## Decisions

- **Columnas dinámicas** (Opción A elegida en preguntas).
- **Modal completo** con descripción, campos personalizados, comentarios, actividad.
- **Gradientes generados** (sin red, sin uploads).
- **Tipo `Card` unificado** con `kind` (ROOM/TASK/FREE) — simplifica drag, modal, store. Campos de habitación opcionales preservan badge URGENTE.
- **Migración no destructiva**: v3 nuevo, v2 conservado.
- **Excluido**: drag para reordenar columnas (solo desde menú "Mover lista"), vistas alternativas (Tabla/Calendario/etc), favoritos persistidos, multiusuario realtime, etiquetas, adjuntos, automatizaciones.

---

## Further Considerations

1. **Archivar lista vs Archivar tarjetas**: "Archivar lista" elimina la columna y manda todas sus cards al archivo; "Archivar todas las tarjetas" vacía la columna pero la mantiene. Confirmar antes de implementar.
2. **Custom fields fijos vs editables**: hardcodear los 5 campos de foto 2 (Salida, Entrada, Cobrar, Status Mantenimiento, PENDIENTE) en el modal. No permitir crear nuevos campos custom (más simple, cubre el caso real).
3. **Cards con kind="ROOM" vs "FREE"**: las habitaciones existentes mantienen `roomCode` y badge URGENTE; nuevas cards "FREE" (como las de foto 6: "1A No drena el fregadero…") no requieren `roomCode` y se muestran solo con título largo + descripción.
