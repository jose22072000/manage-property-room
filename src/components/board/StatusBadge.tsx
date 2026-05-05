import type { RoomStatus } from "@/types/domain";
import { STATUS_COLORS, STATUS_LABELS } from "@/mocks/mockBoardData";
import { cn } from "@/lib/utils";

export function StatusBadge({ status }: { status: RoomStatus }) {
  const c = STATUS_COLORS[status];
  return (
    <span
      className={cn(
        "inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full border",
        c.bg,
        c.text,
        c.border
      )}
    >
      <span className={cn("w-1.5 h-1.5 rounded-full shrink-0", c.dot)} />
      {STATUS_LABELS[status]}
    </span>
  );
}
