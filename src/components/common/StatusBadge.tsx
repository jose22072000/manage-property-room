import type { RoomStatus } from "../../types";
import { STATUS_COLORS, STATUS_LABELS } from "../../data/mockBoardData";

interface StatusBadgeProps {
  status: RoomStatus;
  small?: boolean;
}

export function StatusBadge({ status, small = false }: StatusBadgeProps) {
  const color = STATUS_COLORS[status];
  const label = STATUS_LABELS[status];

  return (
    <span
      style={{
        display: "inline-block",
        background: color,
        color: "#fff",
        borderRadius: "9999px",
        padding: small ? "2px 8px" : "3px 10px",
        fontSize: small ? "11px" : "12px",
        fontWeight: 600,
        letterSpacing: "0.02em",
      }}
    >
      {label}
    </span>
  );
}
