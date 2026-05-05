import type { RoomStatus } from "@/types/domain";

export const STATUS_ORDER: RoomStatus[] = [
  "CHECKOUT",
  "PENDING",
  "CLEANING",
  "READY",
  "AVAILABLE",
  "MAINTENANCE",
];

export const DONE_STATUSES: RoomStatus[] = ["READY", "AVAILABLE"];

export const STATUS_LABELS: Record<RoomStatus, string> = {
  CHECKOUT:    "Salida",
  PENDING:     "Pendiente",
  CLEANING:    "En limpieza",
  READY:       "Lista",
  AVAILABLE:   "Disponible",
  MAINTENANCE: "Mantenimiento",
};

export const STATUS_COLORS: Record<
  RoomStatus,
  { bg: string; text: string; border: string; dot: string; hover: string }
> = {
  CHECKOUT:    { bg: "bg-slate-100",  text: "text-slate-700",  border: "border-slate-200",  dot: "bg-slate-400",  hover: "hover:bg-slate-200" },
  PENDING:     { bg: "bg-amber-50",   text: "text-amber-700",  border: "border-amber-200",  dot: "bg-amber-400",  hover: "hover:bg-amber-100" },
  CLEANING:    { bg: "bg-blue-50",    text: "text-blue-700",   border: "border-blue-200",   dot: "bg-blue-500",   hover: "hover:bg-blue-100"  },
  READY:       { bg: "bg-green-50",   text: "text-green-700",  border: "border-green-200",  dot: "bg-green-500",  hover: "hover:bg-green-100" },
  AVAILABLE:   { bg: "bg-teal-50",    text: "text-teal-700",   border: "border-teal-200",   dot: "bg-teal-500",   hover: "hover:bg-teal-100"  },
  MAINTENANCE: { bg: "bg-red-50",     text: "text-red-700",    border: "border-red-200",    dot: "bg-red-500",    hover: "hover:bg-red-100"   },
};
