// ── Legacy types (kept for migration compatibility) ──────────────────────────
export type RoomStatus =
  | "CHECKOUT"
  | "PENDING"
  | "CLEANING"
  | "READY"
  | "AVAILABLE"
  | "MAINTENANCE";

export type Property = {
  id: string;
  code: string;
  name: string;
  totalRooms: number;
};

// Legacy — still used by roomsService / mockRooms for seeding
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
  hasNextDayCheckin?: boolean;
  checkinDate?: string;
};

export type MockUser = {
  id: string;
  name: string;
  initials: string;
};

// Legacy — kept for ArchivePage
export type ArchivedRoom = RoomCard & {
  archivedAt: string;
  archivedBy: string;
};

export type PropertyTaskCategory = "AVISO" | "COMPRAS";
export type PropertyTask = {
  id: string;
  propertyId: string;
  category: PropertyTaskCategory;
  text: string;
  done: boolean;
  createdAt: string;
};

// ── New dynamic board types ───────────────────────────────────────────────────

export type ColumnColor =
  | "green" | "yellow" | "orange" | "red"
  | "purple" | "blue" | "cyan" | "lime" | "pink" | "gray";

export const COLUMN_COLOR_CLASSES: Record<
  ColumnColor,
  { border: string; headerBg: string; iconColor: string; swatch: string; dot: string }
> = {
  green:  { border: "border-t-green-400",   headerBg: "bg-green-50",   iconColor: "text-green-600",   swatch: "bg-green-400",   dot: "bg-green-500"   },
  yellow: { border: "border-t-amber-400",   headerBg: "bg-amber-50",   iconColor: "text-amber-600",   swatch: "bg-amber-400",   dot: "bg-amber-500"   },
  orange: { border: "border-t-orange-400",  headerBg: "bg-orange-50",  iconColor: "text-orange-600",  swatch: "bg-orange-400",  dot: "bg-orange-500"  },
  red:    { border: "border-t-red-400",     headerBg: "bg-red-50",     iconColor: "text-red-600",     swatch: "bg-red-400",     dot: "bg-red-500"     },
  purple: { border: "border-t-purple-400",  headerBg: "bg-purple-50",  iconColor: "text-purple-600",  swatch: "bg-purple-400",  dot: "bg-purple-500"  },
  blue:   { border: "border-t-blue-400",    headerBg: "bg-blue-50",    iconColor: "text-blue-600",    swatch: "bg-blue-400",    dot: "bg-blue-500"    },
  cyan:   { border: "border-t-cyan-400",    headerBg: "bg-cyan-50",    iconColor: "text-cyan-600",    swatch: "bg-cyan-400",    dot: "bg-cyan-500"    },
  lime:   { border: "border-t-lime-400",    headerBg: "bg-lime-50",    iconColor: "text-lime-600",    swatch: "bg-lime-400",    dot: "bg-lime-500"    },
  pink:   { border: "border-t-pink-400",    headerBg: "bg-pink-50",    iconColor: "text-pink-600",    swatch: "bg-pink-400",    dot: "bg-pink-500"    },
  gray:   { border: "border-t-slate-400",   headerBg: "bg-slate-50",   iconColor: "text-slate-600",   swatch: "bg-slate-400",   dot: "bg-slate-500"   },
};

export const COLUMN_COLORS_ORDER: ColumnColor[] = [
  "green", "yellow", "orange", "red", "purple",
  "blue",  "cyan",   "lime",   "pink", "gray",
];

/** Per-column visual configuration — all booleans default to true when undefined */
export type ColumnConfig = {
  // ── Card modal sections ──────────────────────────────────────────────────
  showDescription?: boolean;    // show Description section in card modal
  showCustomFields?: boolean;   // show Custom Fields section in card modal
  showComments?: boolean;       // show Comments/Activity section in card modal
  // ── Card modal sidebar ───────────────────────────────────────────────────
  showAssign?: boolean;         // show Asignar sidebar action
  showPriority?: boolean;       // show Prioridad sidebar action
  showCheckin?: boolean;        // show Fecha checkin sidebar action
  // ── Card item display ────────────────────────────────────────────────────
  cardChipFieldIds?: string[];  // which field chips show on cards (undefined = use global showOnCard)
  showCardDescription?: boolean; // description preview line on card
  showCardRoomCode?: boolean;    // room code badge on card
  showCardFooter?: boolean;      // comments / date / assignee footer icons
  showCardDoneStamp?: boolean;   // green "cleaned by" done stamp
};

export type Column = {
  id: string;
  propertyId: string;
  title: string;
  color: ColumnColor;
  position: number;
  archived?: boolean;
  description?: string;
  /** If set, only these field IDs are shown in card modals for this column.
   *  If undefined, all globally enabled fields are shown. */
  fieldIds?: string[];
  /** Per-column visual configuration for cards and card modal */
  columnConfig?: ColumnConfig;
};

export type CardKind = "ROOM" | "TASK" | "FREE";

// Flexible custom fields — keys map to FieldDef ids
export type CardCustomFields = Record<string, string | boolean | undefined>;

// Field definition for settings
export type FieldType = "text" | "select" | "checkbox" | "image";

export type FieldDef = {
  id: string;
  label: string;
  type: FieldType;
  options?: string[];     // for select
  enabled: boolean;       // show in card modal
  showOnCard?: boolean;   // show as chip on CardItem
  icon?: string;          // mdi icon name
  offLabel?: string;      // for checkbox: label shown when unchecked (always visible if set)
};

export type Card = {
  id: string;
  propertyId: string;
  columnId: string;
  title: string;
  description?: string;
  isDone: boolean;
  position: number;
  createdAt: string;
  kind: CardKind;
  customFields?: CardCustomFields;
  // ROOM-specific
  roomCode?: string;
  cleanedBy?: string;
  cleanedAt?: string;
  priority?: "LOW" | "NORMAL" | "HIGH";
  hasNextDayCheckin?: boolean;
  checkinDate?: string;
  assignedTo?: string;
  notes?: string;
};

export type ArchivedCard = Card & {
  archivedAt: string;
  archivedBy: string;
};

export type Comment = {
  id: string;
  cardId: string;
  author: string;
  authorInitials: string;
  text: string;
  createdAt: string;
};

export type ActivityEvent = {
  id: string;
  cardId: string;
  type: "created" | "moved" | "archived" | "done" | "undone" | "commented";
  message: string;
  createdAt: string;
};
