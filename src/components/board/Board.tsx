import { useState } from "react";
import {
  DndContext,
  DragOverlay,
  PointerSensor,
  TouchSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragStartEvent,
} from "@dnd-kit/core";
import { Icon } from "@iconify/react";
import type { Card } from "@/types/domain";
import { useBoardStore, EMPTY_COLS } from "@/store/boardStore";
import { useUserStore } from "@/store/userStore";
import { BoardColumn } from "./BoardColumn";
import { AddListInline } from "./AddListInline";
import { CardItem } from "./CardItem";

type Props = {
  propertyId: string;
};

export function Board({ propertyId }: Props) {
  const _cols   = useBoardStore((s) => s.columns[propertyId]);
  const cols    = _cols ?? EMPTY_COLS;
  const addCol  = useBoardStore((s) => s.addColumn);
  const moveCard = useBoardStore((s) => s.moveCard);
  const allCards = useBoardStore((s) => s.cards);
  const currentUser = useUserStore((s) => s.currentUser);

  const [showAddList, setShowAddList] = useState(false);
  const [activeCard,   setActiveCard]  = useState<Card | null>(null);

  const sortedCols = [...cols].sort((a, b) => a.position - b.position);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 8 } }),
    useSensor(TouchSensor,   { activationConstraint: { delay: 300, tolerance: 5 } })
  );

  function handleDragStart(e: DragStartEvent) {
    const cardId = e.active.id as string;
    for (const colId of Object.keys(allCards)) {
      const found = allCards[colId]?.find((c) => c.id === cardId);
      if (found) { setActiveCard(found); return; }
    }
  }

  function handleDragEnd(e: DragEndEvent) {
    setActiveCard(null);
    const { active, over } = e;
    if (!over || active.id === over.id) return;
    const cardId     = active.id as string;
    const toColumnId = over.id as string;
    if (sortedCols.some((c) => c.id === toColumnId)) {
      moveCard(cardId, toColumnId, currentUser.name);
    }
  }

  return (
    <DndContext sensors={sensors} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
      <div className="h-full overflow-x-auto overflow-y-hidden [&::-webkit-scrollbar]:h-1.5 [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-track]:bg-transparent">
        <div className="flex gap-4 h-full items-start min-w-max pb-3 pt-1">
        {sortedCols.map((col) => (
          <BoardColumn
            key={col.id}
            column={col}
            allColumns={sortedCols}
            onAddCardModal={(_colId) => {}}
          />
        ))}

        {showAddList ? (
          <AddListInline
            onAdd={(title) => addCol(propertyId, title)}
            onCancel={() => setShowAddList(false)}
          />
        ) : (
          <button
            onClick={() => setShowAddList(true)}
            className="flex items-center gap-2 shrink-0 bg-white/60 hover:bg-white/90 border border-gray-200 border-dashed text-gray-500 hover:text-gray-800 rounded-2xl px-4 py-3 text-sm font-medium transition-all w-56"
          >
            <Icon icon="mdi:plus" width={18} />
            Anadir otra lista
          </button>
        )}
        </div>
      </div>

      <DragOverlay>
        {activeCard && (
          <div className="rotate-2 shadow-2xl opacity-90 pointer-events-none">
            <CardItem card={activeCard} onOpen={() => {}} />
          </div>
        )}
      </DragOverlay>
    </DndContext>
  );
}
