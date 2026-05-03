import { useState, useCallback } from "react";
import type { BoardColumn as BoardColumnType, RoomCard as RoomCardType, RoomStatus } from "../../types";
import { getBoardColumnsForProperty, STATUS_COLORS, STATUS_LABELS } from "../../data/mockBoardData";
import { BoardColumn } from "./BoardColumn";
import "./BoardView.css";

interface BoardViewProps {
  propertyId: string;
  propertyName: string;
  onBack: () => void;
  currentUser?: string;
}

export function BoardView({ propertyId, propertyName, onBack, currentUser = "Usuario" }: BoardViewProps) {
  const [columns, setColumns] = useState<BoardColumnType[]>(() =>
    getBoardColumnsForProperty(propertyId)
  );

  const handleStatusChange = useCallback(
    (cardId: string, newStatus: RoomStatus, updatedFields?: Partial<RoomCardType>) => {
      setColumns((prev) => {
        // Find the card across all columns
        let movedCard: RoomCardType | undefined;

        const withoutCard = prev.map((col) => {
          const idx = col.cards.findIndex((c) => c.id === cardId);
          if (idx !== -1) {
            movedCard = col.cards[idx];
            return { ...col, cards: col.cards.filter((c) => c.id !== cardId) };
          }
          return col;
        });

        if (!movedCard) return prev;

        const updatedCard: RoomCardType = {
          ...movedCard,
          ...updatedFields,
          status: newStatus,
        };

        return withoutCard.map((col) => {
          if (col.id === newStatus) {
            return { ...col, cards: [...col.cards, updatedCard] };
          }
          return col;
        });
      });
    },
    []
  );

  const totalRooms = columns.reduce((sum, col) => sum + col.cards.length, 0);
  const readyRooms = columns.find((c) => c.id === "READY")?.cards.length ?? 0;

  return (
    <div className="board-view">
      {/* Header */}
      <div className="board-view__header">
        <button className="board-view__back" onClick={onBack} aria-label="Volver">
          ← Propiedades
        </button>
        <div className="board-view__title-group">
          <h1 className="board-view__title">{propertyName}</h1>
          <p className="board-view__subtitle">
            Tablero de habitaciones
          </p>
        </div>
        <div className="board-view__stats">
          <div className="board-view__stat board-view__stat--ready">
            <span className="board-view__stat-value">{readyRooms}</span>
            <span className="board-view__stat-label">Listas</span>
          </div>
          <div className="board-view__stat">
            <span className="board-view__stat-value">{totalRooms - readyRooms}</span>
            <span className="board-view__stat-label">Pendientes</span>
          </div>
          <div className="board-view__stat board-view__stat--total">
            <span className="board-view__stat-value">{totalRooms}</span>
            <span className="board-view__stat-label">Total</span>
          </div>
        </div>
      </div>

      {/* Status summary bar */}
      <div className="board-view__summary">
        {columns.map((col) => (
          <div key={col.id} className="board-view__summary-item">
            <span
              className="board-view__summary-dot"
              style={{ background: STATUS_COLORS[col.id] }}
            />
            <span className="board-view__summary-label">{STATUS_LABELS[col.id]}</span>
            <span
              className="board-view__summary-count"
              style={{ color: STATUS_COLORS[col.id] }}
            >
              {col.cards.length}
            </span>
          </div>
        ))}
      </div>

      {/* Board columns */}
      <div className="board-view__board">
        {columns.map((col) => (
          <BoardColumn
            key={col.id}
            column={col}
            onStatusChange={handleStatusChange}
            currentUser={currentUser}
          />
        ))}
      </div>
    </div>
  );
}
