import { useDraggable } from "@dnd-kit/core";
import { CSS } from "@dnd-kit/utilities";
import { Icon } from "@iconify/react";
import type { Card } from "@/types/domain";
import { useBoardStore, EMPTY_COMMENTS, EMPTY_COLS } from "@/store/boardStore";
import { useSettingsStore } from "@/store/settingsStore";
import { useUserStore } from "@/store/userStore";
import { useToastStore } from "@/store/toastStore";
import { cn } from "@/lib/utils";

function fmtDate(iso: string) {
  const d = new Date(iso);
  const sameDay = d.toDateString() === new Date().toDateString();
  const t = d.toLocaleTimeString("es-ES", { hour: "2-digit", minute: "2-digit" });
  return sameDay
    ? `hoy ${t}`
    : `${d.toLocaleDateString("es-ES", { day: "numeric", month: "short" })}, ${t}`;
}

type Props = {
  card: Card;
  onOpen: () => void;
};

export function CardItem({ card, onOpen }: Props) {
  const { attributes, listeners, setNodeRef, transform, isDragging } = useDraggable({ id: card.id });
  const toggleCardDone = useBoardStore((s) => s.toggleCardDone);
  const currentUser    = useUserStore((s) => s.currentUser);
  const addToast       = useToastStore((s) => s.addToast);
  const _comments      = useBoardStore((s) => s.comments[card.id]);
  const comments       = _comments ?? EMPTY_COMMENTS;
  const _allFieldDefs  = useSettingsStore((s) => s.fieldDefs);
  // Per-column chip override: use cardChipFieldIds if set, else fall back to global showOnCard
  const _propCols      = useBoardStore((s) => s.columns[card.propertyId] ?? EMPTY_COLS);
  const currentCol     = _propCols.find((c) => c.id === card.columnId);
  const cardChipFieldIds = currentCol?.columnConfig?.cardChipFieldIds;
  const cardChipFields = _allFieldDefs.filter((f) => {
    if (!f.enabled) return false;
    if (cardChipFieldIds !== undefined) return cardChipFieldIds.includes(f.id);
    return f.showOnCard;
  });

  // Per-column card element visibility (all default true)
  const colCfg = currentCol?.columnConfig ?? {};
  const showRoomCode    = colCfg.showCardRoomCode    !== false;
  const showDescPreview = colCfg.showCardDescription !== false;
  const showFooter      = colCfg.showCardFooter      !== false;
  const showDoneStamp   = colCfg.showCardDoneStamp   !== false;

  const isUrgent = !card.isDone && card.kind === "ROOM" && (card.priority === "HIGH" || !!card.hasNextDayCheckin);

  const style = transform ? { transform: CSS.Translate.toString(transform) } : undefined;

  function handleToggle(e: React.MouseEvent) {
    e.stopPropagation();
    toggleCardDone(card.id, currentUser.name);
    addToast(card.isDone ? `${card.title} desmarcada` : `${card.title} marcada como hecha`);
  }

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...listeners}
      {...attributes}
      className={cn(
        "bg-white rounded-xl border border-gray-200 shadow-sm px-3 py-2.5 select-none",
        "cursor-grab active:cursor-grabbing touch-none",
        "hover:shadow-md transition-all duration-150 group",
        isDragging && "opacity-40 shadow-xl rotate-1",
        isUrgent   && "border-l-[3px] border-l-red-400",
        card.isDone && "border-l-[3px] border-l-green-400",
        !isUrgent && !card.isDone && card.priority === "HIGH" && "border-l-[3px] border-l-orange-400"
      )}
    >
      {/* Main row */}
      <div className="flex items-start gap-2">
        {/* Checkbox */}
        <button
          onClick={handleToggle}
          onPointerDown={(e) => e.stopPropagation()}
          className="mt-0.5 shrink-0"
        >
          <Icon
            icon={card.isDone ? "mdi:check-circle" : "mdi:checkbox-blank-circle-outline"}
            className={card.isDone ? "text-green-500" : "text-gray-300 hover:text-gray-500"}
            width={18}
          />
        </button>

        {/* Content — clicking here opens edit */}
        <div
          className="flex-1 min-w-0 cursor-grab"
          onClick={onOpen}
        >
          {/* Title + badges */}
          <div className="flex items-start gap-1.5 flex-wrap">
            {showRoomCode && card.roomCode && (
              <span className={cn("font-bold text-sm", card.isDone && "text-gray-400")}>
                {card.roomCode}
              </span>
            )}
            {isUrgent && (
              <span className="inline-flex items-center gap-0.5 bg-red-100 text-red-600 text-[10px] font-bold px-1.5 py-0.5 rounded-full shrink-0">
                <Icon icon="mdi:alert-circle" width={10} />
                URGENTE
              </span>
            )}
            {!isUrgent && card.priority === "HIGH" && (
              <span className="bg-orange-100 text-orange-600 text-[10px] font-semibold px-1.5 py-0.5 rounded-full shrink-0">Alta</span>
            )}
            {card.priority === "LOW" && (
              <span className="bg-gray-100 text-gray-400 text-[10px] px-1.5 py-0.5 rounded-full shrink-0">Baja</span>
            )}
          </div>

          {/* Title (for non-ROOM or when no roomCode) */}
          {(!card.roomCode || !showRoomCode || card.kind !== "ROOM") && (
            <p className={cn("text-sm text-gray-800 leading-snug mt-0.5", card.isDone && "text-gray-400")}>
              {card.title}
            </p>
          )}

          {/* Description preview */}
          {showDescPreview && card.description && (
            <p className="text-xs text-gray-400 mt-0.5 line-clamp-1">{card.description}</p>
          )}

          {/* Custom field chips (showOnCard fields) */}
          {cardChipFields.some((def) => {
            const v = card.customFields?.[def.id];
            if (def.type === "image") {
              try { return (JSON.parse(v as string) as unknown[]).length > 0; } catch { return false; }
            }
            if (def.type === "checkbox") return !!def.offLabel || !!v;
            return (v !== undefined && v !== "");
          }) && (
            <div className="flex items-center gap-1 mt-1.5 flex-wrap">
              {cardChipFields.map((def) => {
                const val = card.customFields?.[def.id];
                if (def.type === "image") {
                  const imgs: unknown[] = val ? (() => { try { return JSON.parse(val as string); } catch { return []; } })() : [];
                  if (imgs.length === 0) return null;
                  return (
                    <span key={def.id} className="inline-flex items-center gap-0.5 bg-purple-100 text-purple-700 text-[10px] font-semibold px-1.5 py-0.5 rounded-full">
                      <Icon icon="mdi:camera-outline" width={9} />
                      {imgs.length}
                    </span>
                  );
                }
                if (def.type === "checkbox") {
                  if (!val && !def.offLabel) return null;
                  const isOn      = !!val;
                  const chipLabel = isOn ? def.label : (def.offLabel ?? def.label);
                  const chipIcon  = isOn ? (def.icon ?? "mdi:check") : "mdi:exit-run";
                  return (
                    <span key={def.id} className={`inline-flex items-center gap-0.5 text-[10px] font-semibold px-1.5 py-0.5 rounded-full ${
                      isOn ? "bg-blue-100 text-blue-700" : "bg-orange-100 text-orange-700"
                    }`}>
                      <Icon icon={chipIcon} width={9} />
                      {chipLabel.toUpperCase()}
                    </span>
                  );
                }
                if (!val || val === "") return null;
                return (
                  <span key={def.id} className="inline-flex items-center gap-0.5 bg-amber-100 text-amber-700 text-[10px] font-semibold px-1.5 py-0.5 rounded-full">
                    <Icon icon={def.icon ?? "mdi:label-outline"} width={9} />
                    {def.label}: {String(val)}
                  </span>
                );
              })}
            </div>
          )}

          {/* Footer icons */}
          {showFooter && (
            <div className="flex items-center gap-2.5 mt-1.5 flex-wrap">
              {comments.length > 0 && (
                <span className="flex items-center gap-0.5 text-[10px] text-gray-400">
                  <Icon icon="mdi:comment-outline" width={11} />{comments.length}
                </span>
              )}
              {card.hasNextDayCheckin && card.checkinDate && (
                <span className="flex items-center gap-0.5 text-[10px] text-red-400">
                  <Icon icon="mdi:calendar-alert" width={11} />
                  {new Date(card.checkinDate + "T12:00:00").toLocaleDateString("es-ES", { day: "numeric", month: "short" })}
                </span>
              )}
              {card.assignedTo && (
                <span className="flex items-center gap-0.5 text-[10px] text-gray-400">
                  <Icon icon="mdi:account-outline" width={11} />{card.assignedTo}
                </span>
              )}
            </div>
          )}

          {/* Done stamp */}
          {showDoneStamp && card.isDone && card.cleanedBy && (
            <div className="mt-1.5 flex items-center gap-1 bg-green-50 border border-green-100 rounded-lg px-2 py-1 text-[10px] text-green-700">
              <Icon icon="mdi:check-circle" className="text-green-500 shrink-0" width={12} />
              <span className="truncate">
                Lista por <strong>{card.cleanedBy}</strong>
                {card.cleanedAt ? ` · ${fmtDate(card.cleanedAt)}` : ""}
              </span>
            </div>
          )}
        </div>

        {/* Edit button — visible on hover */}
        <button
          onClick={onOpen}
          onPointerDown={(e) => e.stopPropagation()}
          className="shrink-0 self-start mt-0.5 p-1 rounded-lg text-gray-300 hover:text-blue-500 hover:bg-blue-50 transition-colors opacity-0 group-hover:opacity-100 focus:opacity-100"
          title="Editar"
        >
          <Icon icon="mdi:pencil-outline" width={13} />
        </button>
      </div>
    </div>
  );
}
