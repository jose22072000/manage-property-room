import { useState } from "react";
import type { RoomCard as RoomCardType, RoomStatus } from "../../types";
import { COLUMN_DEFINITIONS, STATUS_COLORS, STATUS_LABELS } from "../../data/mockBoardData";
import "./RoomCard.css";

interface RoomCardProps {
  card: RoomCardType;
  onStatusChange: (cardId: string, newStatus: RoomStatus, updatedFields?: Partial<RoomCardType>) => void;
  currentUser?: string;
}

const PRIORITY_COLORS: Record<string, string> = {
  LOW: "#6b7280",
  NORMAL: "#3b82f6",
  HIGH: "#ef4444",
};

const PRIORITY_LABELS: Record<string, string> = {
  LOW: "Baja",
  NORMAL: "Normal",
  HIGH: "Alta",
};

export function RoomCard({ card, onStatusChange, currentUser = "Usuario" }: RoomCardProps) {
  const [showMenu, setShowMenu] = useState(false);

  const statusColor = STATUS_COLORS[card.status];

  function handleStatusSelect(newStatus: RoomStatus) {
    const now = new Date().toISOString();
    const updatedFields: Partial<RoomCardType> = { status: newStatus };

    if (newStatus === "READY") {
      updatedFields.markedReadyBy = currentUser;
      updatedFields.markedReadyAt = now;
      updatedFields.cleanedBy = updatedFields.cleanedBy ?? card.cleanedBy ?? currentUser;
      updatedFields.cleanedAt = updatedFields.cleanedAt ?? card.cleanedAt ?? now;
    }

    onStatusChange(card.id, newStatus, updatedFields);
    setShowMenu(false);
  }

  function formatDate(iso?: string) {
    if (!iso) return null;
    const d = new Date(iso);
    return d.toLocaleString("es-ES", {
      day: "2-digit",
      month: "2-digit",
      year: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  return (
    <div
      className={`room-card room-card--${card.status.toLowerCase()}`}
      style={{ borderLeft: `4px solid ${statusColor}` }}
    >
      {/* Card header */}
      <div className="room-card__header">
        <span className="room-card__code">{card.roomCode}</span>
        {card.priority && (
          <span
            className="room-card__priority"
            style={{ color: PRIORITY_COLORS[card.priority] }}
            title={`Prioridad: ${PRIORITY_LABELS[card.priority]}`}
          >
            {card.priority === "HIGH" ? "▲" : card.priority === "LOW" ? "▼" : "●"}
          </span>
        )}
      </div>

      {/* Card title */}
      <p className="room-card__title">{card.title}</p>

      {/* Notes */}
      {card.notes && <p className="room-card__notes">{card.notes}</p>}

      {/* Assigned to */}
      {card.assignedTo && (
        <p className="room-card__meta">
          <span className="room-card__meta-icon">👤</span> {card.assignedTo}
        </p>
      )}

      {/* READY info */}
      {card.status === "READY" && card.markedReadyAt && (
        <div className="room-card__ready-info">
          <p className="room-card__meta">
            <span className="room-card__meta-icon">✅</span>{" "}
            <strong>Lista desde:</strong> {formatDate(card.markedReadyAt)}
          </p>
          {card.markedReadyBy && (
            <p className="room-card__meta">
              <span className="room-card__meta-icon">👤</span>{" "}
              <strong>Marcada por:</strong> {card.markedReadyBy}
            </p>
          )}
        </div>
      )}

      {/* Status change button */}
      <div className="room-card__footer">
        <div className="room-card__status-wrapper">
          <button
            className="room-card__status-btn"
            style={{ background: statusColor }}
            onClick={() => setShowMenu((v) => !v)}
            aria-label="Cambiar estado"
          >
            {STATUS_LABELS[card.status]} ▾
          </button>

          {showMenu && (
            <div className="room-card__status-menu">
              {COLUMN_DEFINITIONS.filter((col) => col.id !== card.status).map((col) => (
                <button
                  key={col.id}
                  className="room-card__status-menu-item"
                  style={{ "--item-color": col.color } as React.CSSProperties}
                  onClick={() => handleStatusSelect(col.id)}
                >
                  <span
                    className="room-card__status-dot"
                    style={{ background: col.color }}
                  />
                  {col.title}
                </button>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Overlay to close menu */}
      {showMenu && (
        <div
          className="room-card__overlay"
          onClick={() => setShowMenu(false)}
        />
      )}
    </div>
  );
}
