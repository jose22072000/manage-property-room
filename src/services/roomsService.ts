import type { Property, RoomCard } from "@/types/domain";
import { mockProperties } from "@/mocks/mockProperties";
import { mockRooms } from "@/mocks/mockRooms";

// Deep-copy the seed data so mutations don't corrupt the original arrays
const propertyStore: Property[] = mockProperties.map((p) => ({ ...p }));
const roomStore: RoomCard[] = mockRooms.map((r) => ({ ...r }));

const delay = (ms: number) => new Promise<void>((res) => setTimeout(res, ms));

/**
 * roomsService — the ONLY module that touches mock data directly.
 * Replace the implementations below with real fetch/axios calls to connect
 * to the backend API; the rest of the app stays untouched.
 */
export const roomsService = {
  async listProperties(): Promise<Property[]> {
    await delay(150);
    return propertyStore.map((p) => ({ ...p }));
  },

  async listRoomsByProperty(propertyId: string): Promise<RoomCard[]> {
    await delay(100);
    return roomStore
      .filter((r) => r.propertyId === propertyId)
      .map((r) => ({ ...r }));
  },

  async updateRoomStatus(
    roomId: string,
    patch: Partial<RoomCard>
  ): Promise<RoomCard> {
    await delay(80);
    const room = roomStore.find((r) => r.id === roomId);
    if (!room) throw new Error(`Room not found: ${roomId}`);
    Object.assign(room, patch);
    return { ...room };
  },
};
