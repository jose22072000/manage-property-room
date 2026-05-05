import { useRef as _useRef, useRef, useState } from "react";
import { Icon } from "@iconify/react";
import { COLUMN_COLOR_CLASSES, COLUMN_COLORS_ORDER } from "@/types/domain";
import type { Column } from "@/types/domain";
import { useBoardStore } from "@/store/boardStore";
import { useConfirmStore } from "@/store/confirmStore";
import { useToastStore } from "@/store/toastStore";
import { useUserStore } from "@/store/userStore";
import { cn } from "@/lib/utils";

type Props = {
  column: Column;
  allColumns: Column[];
  onClose: () => void;
  onAddCard: () => void;
  onOpenConfig: () => void;
};

export function ColumnActionsMenu({ column, allColumns, onClose, onAddCard, onOpenConfig }: Props) {
  const setColumnColor    = useBoardStore((s) => s.setColumnColor);
  const moveColumn        = useBoardStore((s) => s.moveColumn);
  const archiveColumn     = useBoardStore((s) => s.archiveColumn);
  const archiveAllCardsIn = useBoardStore((s) => s.archiveAllCardsIn);
  const copyColumn        = useBoardStore((s) => s.copyColumn);
  const copyColumnToProperty = useBoardStore((s) => s.copyColumnToProperty);
  const allProperties     = useBoardStore((s) => s.properties);
  const updateColumnDescription = useBoardStore((s) => s.updateColumnDescription);
  const addToast          = useToastStore((s) => s.addToast);
  const ask               = useConfirmStore((s) => s.ask);
  const currentUser       = useUserStore((s) => s.currentUser);

  const [showColors,   setShowColors]   = useState(false);
  const [showMovePos,  setShowMovePos]  = useState(false);
  const [showMoveTo,   setShowMoveTo]   = useState(false);
  const [showCopyTo,   setShowCopyTo]   = useState(false);
  const [showDesc,     setShowDesc]     = useState(false);
  const [descDraft,    setDescDraft]    = useState(column.description ?? "");
  const descRef = useRef<HTMLTextAreaElement>(null);

  const sortedCols = [...allColumns].sort((a, b) => a.position - b.position);

  return (
    <div className="bg-white border border-gray-200 rounded-2xl shadow-2xl w-64 py-2 text-sm">
      <div className="px-4 py-2 flex items-center justify-between border-b border-gray-100 mb-1">
        <span className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Acciones de lista</span>
        <button onClick={onClose} className="text-gray-400 hover:text-gray-700 p-0.5">
          <Icon icon="mdi:close" width={16} />
        </button>
      </div>

      <MenuItem label="Añadir tarjeta" icon="mdi:plus" onClick={() => { onAddCard(); onClose(); }} />

      {/* Copiar lista */}
      <div>
        <MenuItem label="Copiar lista" icon="mdi:content-copy" onClick={() => setShowCopyTo((v) => !v)} />
        {showCopyTo && (
          <div className="mx-3 mb-2 bg-gray-50 rounded-xl p-2 space-y-1">
            <div className="text-[10px] font-semibold text-gray-400 uppercase tracking-wide mb-1 px-1">
              Copiar a
            </div>
            {/* Same property */}
            <button
              onClick={() => { copyColumn(column.id); addToast(`"${column.title}" copiada`); onClose(); }}
              className="w-full text-left px-2 py-1.5 rounded-lg text-xs text-gray-700 hover:bg-gray-100 transition-colors flex items-center gap-2"
            >
              <Icon icon="mdi:home-outline" className="text-gray-400 shrink-0" width={13} />
              Esta propiedad (copia)
            </button>
            {/* Other properties */}
            {allProperties.filter((p) => p.id !== column.propertyId).map((p) => (
              <button
                key={p.id}
                onClick={() => {
                  copyColumnToProperty(column.id, p.id);
                  addToast(`"${column.title}" copiada a ${p.name}`);
                  onClose();
                }}
                className="w-full text-left px-2 py-1.5 rounded-lg text-xs text-gray-700 hover:bg-gray-100 transition-colors flex items-center gap-2"
              >
                <Icon icon="mdi:home-switch-outline" className="text-blue-400 shrink-0" width={13} />
                {p.name}
              </button>
            ))}
          </div>
        )}
      </div>

      <MenuItem
        label="Configurar lista"
        icon="mdi:tune-variant"
        onClick={() => { onOpenConfig(); onClose(); }}
      />

      {/* Descripción de lista */}
      <div>
        <MenuItem
          label={column.description ? "Editar descripción" : "Añadir descripción"}
          icon="mdi:text-box-edit-outline"
          onClick={() => { setShowDesc((v) => !v); setTimeout(() => descRef.current?.focus(), 50); }}
        />
        {showDesc && (
          <div className="mx-3 mb-2 space-y-1.5">
            <textarea
              ref={descRef}
              value={descDraft}
              onChange={(e) => setDescDraft(e.target.value)}
              rows={2}
              placeholder="Para qué sirve esta lista…"
              className="w-full text-xs border border-gray-200 rounded-xl px-2.5 py-2 focus:outline-none focus:ring-2 focus:ring-blue-400 resize-none"
            />
            <div className="flex gap-1.5">
              <button
                onClick={() => { updateColumnDescription(column.id, descDraft); setShowDesc(false); addToast("Descripción guardada"); onClose(); }}
                className="flex-1 py-1.5 bg-blue-500 hover:bg-blue-600 text-white text-xs font-semibold rounded-xl transition-colors"
              >
                Guardar
              </button>
              <button onClick={() => setShowDesc(false)} className="px-3 py-1.5 bg-gray-100 hover:bg-gray-200 text-gray-600 text-xs rounded-xl transition-colors">
                Cancelar
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Mover lista */}
      <div>
        <MenuItem label="Mover lista" icon="mdi:arrow-left-right" onClick={() => setShowMovePos((v) => !v)} />
        {showMovePos && (
          <div className="mx-3 mb-2 bg-gray-50 rounded-xl p-2 space-y-1">
            <div className="text-[10px] font-semibold text-gray-400 uppercase tracking-wide mb-1 px-1">
              Mover a posición
            </div>
            {sortedCols.map((col, i) => (
              <button
                key={col.id}
                onClick={() => { moveColumn(column.id, i); onClose(); }}
                className={cn(
                  "w-full text-left px-2 py-1 rounded-lg text-xs transition-colors",
                  col.id === column.id
                    ? "bg-blue-100 text-blue-700 font-semibold"
                    : "hover:bg-gray-100 text-gray-700"
                )}
              >
                {i + 1}. {col.title}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Mover todas las tarjetas */}
      <div>
        <MenuItem label="Mover todas las tarjetas de esta lista" icon="mdi:cards-outline" onClick={() => setShowMoveTo((v) => !v)} />
        {showMoveTo && (
          <div className="mx-3 mb-2 bg-gray-50 rounded-xl p-2 space-y-1">
            <div className="text-[10px] font-semibold text-gray-400 uppercase tracking-wide mb-1 px-1">
              Mover a lista
            </div>
            {sortedCols.filter((c) => c.id !== column.id).map((col) => (
              <MoveAllCardsToCol
                key={col.id}
                fromColId={column.id}
                toCol={col}
                userName={currentUser.name}
                onDone={() => { addToast(`Tarjetas movidas a "${col.title}"`); onClose(); }}
              />
            ))}
          </div>
        )}
      </div>

      <div className="mx-4 my-1.5 h-px bg-gray-100" />

      {/* Color picker */}
      <div>
        <MenuItem label="Cambiar color de lista" icon="mdi:palette-outline" onClick={() => setShowColors((v) => !v)} />
        {showColors && (
          <div className="mx-3 mb-2">
            <div className="grid grid-cols-5 gap-1.5 p-2 bg-gray-50 rounded-xl">
              {COLUMN_COLORS_ORDER.map((color) => (
                <button
                  key={color}
                  onClick={() => { setColumnColor(column.id, color); onClose(); }}
                  className={cn(
                    "w-9 h-7 rounded-lg transition-all",
                    COLUMN_COLOR_CLASSES[color].swatch,
                    column.color === color && "ring-2 ring-offset-1 ring-gray-400"
                  )}
                  title={color}
                />
              ))}
            </div>
            <button
              onClick={() => { setColumnColor(column.id, "gray"); onClose(); }}
              className="w-full text-xs text-gray-400 hover:text-gray-700 mt-1 py-1 text-center"
            >
              × Quitar color
            </button>
          </div>
        )}
      </div>

      <div className="mx-4 my-1.5 h-px bg-gray-100" />

      <MenuItem
        label="Archivar todas las tarjetas de esta lista"
        icon="mdi:archive-outline"
        onClick={async () => {
          const ok = await ask({
            message: `¿Archivar todas las tarjetas de "${column.title}"?`,
            description: "La lista quedará vacía. Se podrán ver en el historial.",
            confirmLabel: "Archivar tarjetas",
          });
          if (ok) {
            archiveAllCardsIn(column.id, currentUser.name);
            addToast(`Tarjetas de "${column.title}" archivadas`, { label: "Ver historial", href: "/archive" });
          }
          onClose();
        }}
      />

      <MenuItem
        label="Archivar esta lista"
        icon="mdi:archive-arrow-down-outline"
        danger
        onClick={async () => {
          const ok = await ask({
            message: `¿Archivar la lista "${column.title}"?`,
            description: "Se eliminará la columna y todas sus tarjetas irán al historial.",
            confirmLabel: "Archivar lista",
            danger: true,
          });
          if (ok) {
            archiveColumn(column.id, currentUser.name);
            addToast(`Lista "${column.title}" archivada`);
          }
          onClose();
        }}
      />
    </div>
  );
}

function MenuItem({
  label, icon, onClick, danger = false,
}: {
  label: string; icon: string; onClick: () => void; danger?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "w-full text-left flex items-center gap-2.5 px-4 py-2 text-sm transition-colors",
        danger
          ? "text-red-600 hover:bg-red-50"
          : "text-gray-700 hover:bg-gray-50"
      )}
    >
      <Icon icon={icon} width={15} className="shrink-0 text-gray-400" />
      {label}
    </button>
  );
}

function MoveAllCardsToCol({
  fromColId, toCol, userName, onDone,
}: { fromColId: string; toCol: Column; userName: string; onDone: () => void }) {
  const moveCard = useBoardStore((s) => s.moveCard);
  const cards    = useBoardStore((s) => s.cards[fromColId]) ?? EMPTY_CARDS;
  return (
    <button
      onClick={() => {
        cards.forEach((c) => moveCard(c.id, toCol.id, userName));
        onDone();
      }}
      className="w-full text-left px-2 py-1 rounded-lg text-xs hover:bg-gray-100 text-gray-700 transition-colors"
    >
      {toCol.title}
    </button>
  );
}

const EMPTY_CARDS: import("@/types/domain").Card[] = [];
