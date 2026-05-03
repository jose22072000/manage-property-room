import type { BoardColumn as BoardColumnType, RoomCard as RoomCardType, RoomStatus } from "../../types";
import { RoomCard } from "./RoomCard";
import "./BoardColumn.css";

interface BoardColumnProps {
  column: BoardColumnType;
  onStatusChange: (cardId: string, newStatus: RoomStatus, updatedFields?: Partial<RoomCardType>) => void;
  currentUser?: string;
}

export function BoardColumn({ column, onStatusChange, currentUser }: BoardColumnProps) {
  const isEmpty = column.cards.length === 0;

  return (
    <div className="board-column">
      <div className="board-column__header" style={{ borderBottom: `3px solid ${column.color}` }}>
        <span className="board-column__title">{column.title}</span>
        <span
          className="board-column__count"
          style={{ background: column.color }}
        >
          {column.cards.length}
        </span>
      </div>

      <div className="board-column__cards">
        {isEmpty ? (
          <div className="board-column__empty">Sin habitaciones</div>
        ) : (
          column.cards.map((card) => (
            <RoomCard
              key={card.id}
              card={card}
              onStatusChange={onStatusChange}
              currentUser={currentUser}
            />
          ))
        )}
      </div>
    </div>
  );
}
