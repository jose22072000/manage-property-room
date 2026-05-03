import type { BoardColumn, RoomStatus } from "../types";
import { mockRooms } from "./mockRooms";

export const COLUMN_DEFINITIONS: Omit<BoardColumn, "cards">[] = [
  {
    id: "CHECKOUT" as RoomStatus,
    title: "Salida",
    color: "#6b7280",
  },
  {
    id: "PENDING" as RoomStatus,
    title: "Pendiente",
    color: "#f59e0b",
  },
  {
    id: "CLEANING" as RoomStatus,
    title: "En Limpieza",
    color: "#3b82f6",
  },
  {
    id: "READY" as RoomStatus,
    title: "Lista ✓",
    color: "#10b981",
  },
  {
    id: "MAINTENANCE" as RoomStatus,
    title: "Mantenimiento",
    color: "#ef4444",
  },
];

export const STATUS_LABELS: Record<RoomStatus, string> = {
  CHECKOUT: "Salida",
  PENDING: "Pendiente",
  CLEANING: "En Limpieza",
  READY: "Lista",
  MAINTENANCE: "Mantenimiento",
};

export const STATUS_COLORS: Record<RoomStatus, string> = {
  CHECKOUT: "#6b7280",
  PENDING: "#f59e0b",
  CLEANING: "#3b82f6",
  READY: "#10b981",
  MAINTENANCE: "#ef4444",
};

/**
 * Build board columns for a given property from mock room data.
 * Replace this function with an API call in the future.
 */
export function getBoardColumnsForProperty(propertyId: string): BoardColumn[] {
  const rooms = mockRooms.filter((r) => r.propertyId === propertyId);

  return COLUMN_DEFINITIONS.map((col) => ({
    ...col,
    cards: rooms.filter((r) => r.status === col.id),
  }));
}
