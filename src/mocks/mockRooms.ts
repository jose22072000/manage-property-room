import type { RoomCard } from "@/types/domain";

export const mockRooms: RoomCard[] = [
  // ── FN13 ─────────────────────────────────────────────────────────────────
  { id: "fn13-1a", propertyId: "fn13", roomCode: "1A", title: "Habitación 1A", status: "CHECKOUT",    priority: "HIGH",   hasNextDayCheckin: true,  checkinDate: "2026-05-04" },
  { id: "fn13-1b", propertyId: "fn13", roomCode: "1B", title: "Habitación 1B", status: "PENDING",     priority: "NORMAL", assignedTo: "María" },
  { id: "fn13-2a", propertyId: "fn13", roomCode: "2A", title: "Habitación 2A", status: "CLEANING",    priority: "NORMAL", assignedTo: "Carlos" },
  { id: "fn13-2b", propertyId: "fn13", roomCode: "2B", title: "Habitación 2B", status: "READY",       priority: "LOW",    cleanedBy: "Lucía",  cleanedAt: "2026-05-03T10:30:00.000Z" },
  { id: "fn13-3a", propertyId: "fn13", roomCode: "3A", title: "Habitación 3A", status: "MAINTENANCE", priority: "HIGH",   notes: "Fontanería urgente" },

  // ── Madrid Rio ────────────────────────────────────────────────────────────
  { id: "mr-101", propertyId: "madrid-rio", roomCode: "101", title: "Apartamento 101", status: "CHECKOUT",  priority: "HIGH",   hasNextDayCheckin: true, checkinDate: "2026-05-04" },
  { id: "mr-102", propertyId: "madrid-rio", roomCode: "102", title: "Apartamento 102", status: "CLEANING",  priority: "NORMAL", assignedTo: "María" },
  { id: "mr-201", propertyId: "madrid-rio", roomCode: "201", title: "Apartamento 201", status: "AVAILABLE", priority: "NORMAL", cleanedBy: "Diego",  cleanedAt: "2026-05-03T09:00:00.000Z" },
  { id: "mr-202", propertyId: "madrid-rio", roomCode: "202", title: "Apartamento 202", status: "PENDING",   priority: "LOW"  },

  // ── Romeo ─────────────────────────────────────────────────────────────────
  { id: "rom-1", propertyId: "romeo", roomCode: "1", title: "Habitación 1", status: "PENDING",   priority: "NORMAL" },
  { id: "rom-2", propertyId: "romeo", roomCode: "2", title: "Habitación 2", status: "CLEANING",  priority: "HIGH",   assignedTo: "Carlos" },
  { id: "rom-3", propertyId: "romeo", roomCode: "3", title: "Habitación 3", status: "AVAILABLE", priority: "LOW",    cleanedBy: "María",  cleanedAt: "2026-05-03T11:00:00.000Z" },
  { id: "rom-4", propertyId: "romeo", roomCode: "4", title: "Habitación 4", status: "CHECKOUT",  priority: "HIGH",   hasNextDayCheckin: true, checkinDate: "2026-05-04" },

  // ── Julieta ───────────────────────────────────────────────────────────────
  { id: "jul-1", propertyId: "julieta", roomCode: "1", title: "Habitación 1", status: "CHECKOUT",    priority: "HIGH" },
  { id: "jul-2", propertyId: "julieta", roomCode: "2", title: "Habitación 2", status: "PENDING",     priority: "NORMAL" },
  { id: "jul-3", propertyId: "julieta", roomCode: "3", title: "Habitación 3", status: "CLEANING",    priority: "NORMAL", assignedTo: "Lucía" },
  { id: "jul-4", propertyId: "julieta", roomCode: "4", title: "Habitación 4", status: "MAINTENANCE", priority: "HIGH",   notes: "Pintura pared" },

  // ── Moroto ────────────────────────────────────────────────────────────────
  { id: "mor-1", propertyId: "moroto", roomCode: "1", title: "Habitación 1", status: "PENDING",   priority: "NORMAL" },
  { id: "mor-2", propertyId: "moroto", roomCode: "2", title: "Habitación 2", status: "AVAILABLE", priority: "LOW",   cleanedBy: "Carlos", cleanedAt: "2026-05-03T08:45:00.000Z" },
  { id: "mor-3", propertyId: "moroto", roomCode: "3", title: "Habitación 3", status: "CHECKOUT",  priority: "HIGH",  hasNextDayCheckin: true, checkinDate: "2026-05-04" },
];
