export type RoomStatus =
  | "CHECKOUT"
  | "PENDING"
  | "CLEANING"
  | "READY"
  | "MAINTENANCE";

export type Property = {
  id: string;
  code: string;
  name: string;
  imageUrl?: string;
  totalRooms: number;
  address?: string;
};

export type RoomCard = {
  id: string;
  propertyId: string;
  roomCode: string;
  title: string;
  status: RoomStatus;
  assignedTo?: string;
  cleanedBy?: string;
  cleanedAt?: string;
  notes?: string;
  priority?: "LOW" | "NORMAL" | "HIGH";
  markedReadyBy?: string;
  markedReadyAt?: string;
};

export type BoardColumn = {
  id: RoomStatus;
  title: string;
  color: string;
  cards: RoomCard[];
};
