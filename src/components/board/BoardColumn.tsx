import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { useDroppable } from "@dnd-kit/core";
import { Icon } from "@iconify/react";
import type { Column } from "@/types/domain";
import { COLUMN_COLOR_CLASSES } from "@/types/domain";
import { useBoardStore, EMPTY_CARDS } from "@/store/boardStore";
import { useUserStore } from "@/store/userStore";
import { CardItem } from "./CardItem";
import { CardDetailModal } from "./CardDetailModal";
import { ColumnActionsMenu } from "./ColumnActionsMenu";
import { ColumnConfigModal } from "./ColumnConfigModal";
import { cn } from "@/lib/utils";

type Props = {
  column: Column;
  allColumns: Column[];
  onAddCardModal: (defaultColId: string) => void;
};

export function BoardColumn({ column, allColumns }: Props) {
  const { setNodeRef, isOver } = useDroppable({ id: column.id });
  const _cards    = useBoardStore((s) => s.cards[column.id]);
  const cards     = _cards ?? EMPTY_CARDS;
  const addCard   = useBoardStore((s) => s.addCard);
  const renameCol = useBoardStore((s) => s.renameColumn);
  const currentUser = useUserStore((s) => s.currentUser);

  const [menuOpen,        setMenuOpen]        = useState(false);
  const [showConfigModal, setShowConfigModal] = useState(false);
  const [showInlineAdd,   setShowInlineAdd]   = useState(false);
  const [inlineText,      setInlineText]      = useState("");
  const [editingTitle,    setEditingTitle]    = useState(false);
  const [titleDraft,      setTitleDraft]      = useState(column.title);
  const [openCardId,      setOpenCardId]      = useState<string | null>(null);

  const inlineRef  = useRef<HTMLInputElement>(null);
  const titleRef   = useRef<HTMLInputElement>(null);
  const menuBtnRef = useRef<HTMLButtonElement>(null);
  const [menuPos, setMenuPos] = useState<{ top: number; right: number } | null>(null);

  useEffect(() => { if (showInlineAdd) inlineRef.current?.focus(); }, [showInlineAdd]);
  useEffect(() => { if (editingTitle)  titleRef.current?.select();  }, [editingTitle]);

  function submitInlineAdd() {
    const t = inlineText.trim();
    if (t) {
      addCard({ propertyId: column.propertyId, columnId: column.id, title: t, kind: "FREE" }, currentUser.name);
    }
    setInlineText("");
    setShowInlineAdd(false);
  }

  function saveTitle() {
    const t = titleDraft.trim();
    if (t && t !== column.title) renameCol(column.id, t);
    else setTitleDraft(column.title);
    setEditingTitle(false);
  }

  const colors = COLUMN_COLOR_CLASSES[column.color] ?? COLUMN_COLOR_CLASSES.gray;
  const openCard = openCardId ? cards.find((c) => c.id === openCardId) ?? null : null;

  return (
    <>
      <div
        className={cn(
          "flex flex-col bg-white border border-gray-200 rounded-2xl overflow-hidden",
          "shrink-0 w-72 transition-shadow border-t-[3px] h-full",
          colors.border,
          isOver && "shadow-xl ring-2 ring-blue-400 ring-offset-1"
        )}
      >
        {/* Header */}
        <div className={cn("flex items-center justify-between px-3.5 py-3 border-b border-gray-100", colors.headerBg)}>
          <div className="flex items-center gap-2 flex-1 min-w-0">
            {editingTitle ? (
              <input
                ref={titleRef}
                value={titleDraft}
                onChange={(e) => setTitleDraft(e.target.value)}
                onBlur={saveTitle}
                onKeyDown={(e) => {
                  if (e.key === "Enter") { e.preventDefault(); saveTitle(); }
                  if (e.key === "Escape") { setTitleDraft(column.title); setEditingTitle(false); }
                }}
                className="font-semibold text-sm text-gray-800 bg-transparent border-b-2 border-blue-400 focus:outline-none min-w-0 flex-1"
              />
            ) : (
              <div className="min-w-0 flex-1">
                <span
                  className="font-semibold text-sm text-gray-800 truncate cursor-pointer hover:text-blue-600 transition-colors block"
                  onDoubleClick={() => setEditingTitle(true)}
                  title="Doble click para renombrar"
                >
                  {column.title}
                </span>
                {column.description && (
                  <span className="text-[10px] text-gray-400 truncate block leading-tight">{column.description}</span>
                )}
              </div>
            )}
            {cards.length > 0 && !editingTitle && (
              <span className="text-[11px] font-bold bg-white/80 text-gray-500 rounded-full px-1.5 py-px shrink-0">
                {cards.length}
              </span>
            )}
          </div>
          <div className="flex items-center gap-0.5 shrink-0">
            <button
              ref={menuBtnRef}
              onClick={() => {
                if (!menuBtnRef.current) return;
                const r = menuBtnRef.current.getBoundingClientRect();
                setMenuPos({ top: r.bottom + 6, right: window.innerWidth - r.right });
                setMenuOpen((v) => !v);
              }}
              className="p-1.5 rounded-xl hover:bg-white/70 text-gray-400 hover:text-gray-700 transition-colors"
            >
              <Icon icon="mdi:dots-horizontal" width={16} />
            </button>
            <button
              onClick={() => setShowInlineAdd(true)}
              className="p-1.5 rounded-xl hover:bg-white/70 text-gray-400 hover:text-gray-700 transition-colors"
            >
              <Icon icon="mdi:plus" width={18} />
            </button>
          </div>
        </div>

        {/* Cards area */}
        <div
          ref={setNodeRef}
          className="flex-1 min-h-0 overflow-y-auto p-3 space-y-2.5 [&::-webkit-scrollbar]:w-1 [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-gray-200 [&::-webkit-scrollbar-track]:bg-transparent"
        >
          {cards.map((card) => (
            <CardItem
              key={card.id}
              card={card}
              onOpen={() => setOpenCardId(card.id)}
            />
          ))}

          {showInlineAdd && (
            <div className="flex items-center gap-1.5 bg-blue-50 border border-blue-200 rounded-xl px-2.5 py-2">
              <input
                ref={inlineRef}
                type="text"
                value={inlineText}
                onChange={(e) => setInlineText(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") { e.preventDefault(); submitInlineAdd(); }
                  if (e.key === "Escape") { setShowInlineAdd(false); setInlineText(""); }
                }}
                placeholder="Introduce un titulo..."
                className="flex-1 text-sm bg-transparent focus:outline-none min-w-0 text-gray-800 placeholder-gray-400"
              />
              <button onClick={submitInlineAdd} className="p-1 bg-blue-500 hover:bg-blue-600 text-white rounded-lg shrink-0">
                <Icon icon="mdi:check" width={13} />
              </button>
              <button onClick={() => { setShowInlineAdd(false); setInlineText(""); }} className="p-1 hover:bg-gray-200 text-gray-400 rounded-lg shrink-0">
                <Icon icon="mdi:close" width={13} />
              </button>
            </div>
          )}

            {cards.length === 0 && !showInlineAdd && (
              <button
                onClick={() => setShowInlineAdd(true)}
                className="w-full flex items-center justify-center gap-1.5 h-16 text-xs text-gray-300 hover:text-gray-500 hover:bg-gray-50 rounded-xl transition-colors italic"
              >
                <Icon icon="mdi:plus" width={14} />
                Anadir una tarjeta
              </button>
            )}
        </div>

        {cards.length > 0 && !showInlineAdd && (
          <button
            onClick={() => setShowInlineAdd(true)}
            className="flex items-center gap-1.5 px-3.5 py-2.5 text-xs text-gray-400 hover:text-gray-700 hover:bg-gray-50 border-t border-gray-100 transition-colors"
          >
            <Icon icon="mdi:plus" width={14} />
            Anade una tarjeta
          </button>
        )}
      </div>

      {menuOpen && menuPos && createPortal(
        <>
          <div className="fixed inset-0 z-[50]" onClick={() => setMenuOpen(false)} />
          <div className="fixed z-[51]" style={{ top: menuPos.top, right: menuPos.right }}>
            <ColumnActionsMenu
              column={column}
              allColumns={allColumns}
              onClose={() => setMenuOpen(false)}
              onAddCard={() => setShowInlineAdd(true)}
              onOpenConfig={() => setShowConfigModal(true)}
            />
          </div>
        </>,
        document.body
      )}
      {openCard && (
        <CardDetailModal
          card={openCard}
          columns={allColumns}
          onClose={() => setOpenCardId(null)}
        />
      )}
      {showConfigModal && (
        <ColumnConfigModal
          column={column}
          onClose={() => setShowConfigModal(false)}
        />
      )}
    </>
  );
}
