import type { Column, Card, ColumnColor, RoomCard, RoomStatus } from "@/types/domain";
import { mockRooms } from "@/mocks/mockRooms";

// ── Default column seed ───────────────────────────────────────────────────────
type DefaultColDef = { id: string; title: string; color: ColumnColor; statuses: RoomStatus[] };

const DEFAULT_COLS: DefaultColDef[] = [
  { id: "col-free",  title: "Apartamentos libres", color: "green",  statuses: ["AVAILABLE"] },
  { id: "col-alert", title: "Aviso del día",        color: "yellow", statuses: [] },
  { id: "col-out",   title: "Salidas",              color: "gray",   statuses: ["CHECKOUT", "PENDING", "CLEANING"] },
  { id: "col-done",  title: "Hecho",                color: "cyan",   statuses: ["READY"] },
  { id: "col-shop",  title: "Compras",              color: "purple", statuses: [] },
  { id: "col-maint", title: "Mantenimiento",        color: "orange", statuses: ["MAINTENANCE"] },
];

export function seedDefaultColumns(propertyId: string): Column[] {
  return DEFAULT_COLS.map((def, i) => ({
    id:         `${propertyId}__${def.id}`,
    propertyId,
    title:      def.title,
    color:      def.color,
    position:   i,
  }));
}

export function migrateRoomsToCards(
  propertyId: string,
  rooms: RoomCard[],
  columns: Column[]
): Card[] {
  // Map from RoomStatus to columnId using DEFAULT_COLS definition
  const statusToColId: Partial<Record<RoomStatus, string>> = {};
  DEFAULT_COLS.forEach((def) => {
    const col = columns.find((c) => c.id === `${propertyId}__${def.id}`);
    if (col) def.statuses.forEach((s) => (statusToColId[s] = col.id));
  });

  // Fallback column = "Salidas"
  const fallbackColId = columns.find((c) => c.id === `${propertyId}__col-out`)?.id ?? columns[0]?.id ?? "";

  return rooms.map((r, i): Card => ({
    id:          r.id,
    propertyId:  r.propertyId,
    columnId:    statusToColId[r.status] ?? fallbackColId,
    title:       r.title,
    description: r.notes,
    isDone:      r.status === "READY" || r.status === "AVAILABLE",
    position:    i,
    createdAt:   r.cleanedAt ?? new Date().toISOString(),
    kind:        "ROOM",
    roomCode:    r.roomCode,
    cleanedBy:   r.cleanedBy,
    cleanedAt:   r.cleanedAt,
    priority:    r.priority,
    hasNextDayCheckin: r.hasNextDayCheckin,
    checkinDate: r.checkinDate,
    assignedTo:  r.assignedTo,
    notes:       r.notes,
  }));
}

export function seedPropertyCards(propertyId: string, columns: Column[]): Card[] {
  const rooms = mockRooms.filter((r) => r.propertyId === propertyId);
  return migrateRoomsToCards(propertyId, rooms, columns);
}
