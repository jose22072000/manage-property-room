import { create } from "zustand";
import { persist } from "zustand/middleware";
import type {
  Property,
  Column,
  ColumnColor,
  ColumnConfig,
  Card,
  ArchivedCard,
  Comment,
  ActivityEvent,
} from "@/types/domain";
import { roomsService } from "@/services/roomsService";
import { seedDefaultColumns, seedPropertyCards } from "@/services/cardsService";

// ── Stable empty refs (never create in selectors) ────────────────────────────
export const EMPTY_COLS: Column[]         = [];
export const EMPTY_CARDS: Card[]          = [];
export const EMPTY_COMMENTS: Comment[]    = [];
export const EMPTY_ACTIVITY: ActivityEvent[] = [];

function uid() {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

function actEvent(
  cardId: string,
  type: ActivityEvent["type"],
  message: string
): ActivityEvent {
  return { id: uid(), cardId, type, message, createdAt: new Date().toISOString() };
}

type BoardState = {
  properties: Property[];
  // Keyed by propertyId
  columns:  Record<string, Column[]>;
  // Keyed by columnId
  cards:    Record<string, Card[]>;
  archivedCards: ArchivedCard[];
  // Keyed by cardId
  comments: Record<string, Comment[]>;
  activity: Record<string, ActivityEvent[]>;

  // Bootstrap
  loadProperties: () => Promise<void>;
  loadProperty:   (propertyId: string) => void;

  // Column actions
  addColumn:          (propertyId: string, title: string, color?: ColumnColor) => void;
  renameColumn:       (columnId: string, title: string) => void;
  setColumnColor:     (columnId: string, color: ColumnColor) => void;
  moveColumn:         (columnId: string, toPosition: number) => void;
  archiveColumn:      (columnId: string, userName: string) => void;
  archiveAllCardsIn:  (columnId: string, userName: string) => void;
  copyColumn:              (columnId: string) => void;
  copyColumnToProperty:    (columnId: string, targetPropertyId: string) => void;
  updateColumnDescription: (columnId: string, description: string) => void;
  updateColumnFields:      (columnId: string, fieldIds: string[] | undefined) => void;
  updateColumnConfig:      (columnId: string, patch: Partial<ColumnConfig>) => void;

  // Card actions
  addCard:      (card: Omit<Card, "id" | "position" | "createdAt" | "isDone">, userName: string) => void;
  updateCard:   (cardId: string, patch: Partial<Card>) => void;
  moveCard:     (cardId: string, toColumnId: string, userName: string) => void;
  toggleCardDone: (cardId: string, userName: string) => void;
  archiveCard:  (cardId: string, userName: string) => void;
  addComment:   (cardId: string, text: string, user: { name: string; initials: string }) => void;

  resetAll: () => void;
};

export const useBoardStore = create<BoardState>()(
  persist(
    (set, get) => ({
      properties:   [],
      columns:      {},
      cards:        {},
      archivedCards: [],
      comments:     {},
      activity:     {},

      // ── Bootstrap ──────────────────────────────────────────────────────────
      async loadProperties() {
        const properties = await roomsService.listProperties();
        set({ properties });
      },

      loadProperty(propertyId) {
        const state = get();
        if (state.columns[propertyId]?.length) return; // already loaded
        const cols  = seedDefaultColumns(propertyId);
        const cards = seedPropertyCards(propertyId, cols);

        // Build cards record keyed by columnId
        const cardsByCol: Record<string, Card[]> = {};
        cols.forEach((c) => { cardsByCol[c.id] = []; });
        cards.forEach((card) => {
          if (!cardsByCol[card.columnId]) cardsByCol[card.columnId] = [];
          cardsByCol[card.columnId].push(card);
        });

        set((s) => ({
          columns: { ...s.columns, [propertyId]: cols },
          cards:   { ...s.cards,   ...cardsByCol },
        }));
      },

      // ── Column actions ─────────────────────────────────────────────────────
      addColumn(propertyId, title, color = "blue") {
        const cols = get().columns[propertyId] ?? [];
        const col: Column = {
          id: `${propertyId}__col-${uid()}`,
          propertyId,
          title,
          color,
          position: cols.length,
        };
        set((s) => ({
          columns: { ...s.columns, [propertyId]: [...(s.columns[propertyId] ?? []), col] },
          cards:   { ...s.cards,   [col.id]: [] },
        }));
      },

      renameColumn(columnId, title) {
        set((s) => {
          const propertyId = columnId.split("__")[0];
          return {
            columns: {
              ...s.columns,
              [propertyId]: (s.columns[propertyId] ?? []).map((c) =>
                c.id === columnId ? { ...c, title } : c
              ),
            },
          };
        });
      },

      updateColumnDescription(columnId, description) {
        set((s) => {
          const propertyId = columnId.split("__")[0];
          return {
            columns: {
              ...s.columns,
              [propertyId]: (s.columns[propertyId] ?? []).map((c) =>
                c.id === columnId ? { ...c, description: description.trim() || undefined } : c
              ),
            },
          };
        });
      },

      updateColumnFields(columnId, fieldIds) {
        set((s) => {
          const propertyId = columnId.split("__")[0];
          return {
            columns: {
              ...s.columns,
              [propertyId]: (s.columns[propertyId] ?? []).map((c) =>
                c.id === columnId ? { ...c, fieldIds } : c
              ),
            },
          };
        });
      },

      updateColumnConfig(columnId, patch) {
        set((s) => {
          const propertyId = columnId.split("__")[0];
          return {
            columns: {
              ...s.columns,
              [propertyId]: (s.columns[propertyId] ?? []).map((c) =>
                c.id === columnId ? { ...c, columnConfig: { ...c.columnConfig, ...patch } } : c
              ),
            },
          };
        });
      },

      setColumnColor(columnId, color) {
        set((s) => {
          const propertyId = columnId.split("__")[0];
          return {
            columns: {
              ...s.columns,
              [propertyId]: (s.columns[propertyId] ?? []).map((c) =>
                c.id === columnId ? { ...c, color } : c
              ),
            },
          };
        });
      },

      moveColumn(columnId, toPosition) {
        set((s) => {
          const propertyId = columnId.split("__")[0];
          const cols = [...(s.columns[propertyId] ?? [])];
          const fromIdx = cols.findIndex((c) => c.id === columnId);
          if (fromIdx === -1) return s;
          const [col] = cols.splice(fromIdx, 1);
          const clampedPos = Math.max(0, Math.min(toPosition, cols.length));
          cols.splice(clampedPos, 0, col);
          return {
            columns: {
              ...s.columns,
              [propertyId]: cols.map((c, i) => ({ ...c, position: i })),
            },
          };
        });
      },

      archiveColumn(columnId, userName) {
        set((s) => {
          const propertyId = columnId.split("__")[0];
          const colCards   = s.cards[columnId] ?? [];
          const now        = new Date().toISOString();
          const archived: ArchivedCard[] = colCards.map((c) => ({
            ...c, archivedAt: now, archivedBy: userName,
          }));
          const newCards = { ...s.cards };
          delete newCards[columnId];
          return {
            columns: {
              ...s.columns,
              [propertyId]: (s.columns[propertyId] ?? []).filter((c) => c.id !== columnId),
            },
            cards: newCards,
            archivedCards: [...s.archivedCards, ...archived],
          };
        });
      },

      archiveAllCardsIn(columnId, userName) {
        set((s) => {
          const colCards = s.cards[columnId] ?? [];
          const now = new Date().toISOString();
          const archived: ArchivedCard[] = colCards.map((c) => ({
            ...c, archivedAt: now, archivedBy: userName,
          }));
          return {
            cards: { ...s.cards, [columnId]: [] },
            archivedCards: [...s.archivedCards, ...archived],
          };
        });
      },

      copyColumn(columnId) {
        set((s) => {
          const propertyId = columnId.split("__")[0];
          const cols = s.columns[propertyId] ?? [];
          const src = cols.find((c) => c.id === columnId);
          if (!src) return s;
          const newColId = `${propertyId}__col-${uid()}`;
          const srcCards = s.cards[columnId] ?? [];
          const newCards: Card[] = srcCards.map((card, i) => ({
            ...card,
            id: `card-${uid()}`,
            columnId: newColId,
            position: i,
            createdAt: new Date().toISOString(),
          }));
          const newCol: Column = { ...src, id: newColId, title: `${src.title} (copia)`, position: cols.length };
          return {
            columns: { ...s.columns, [propertyId]: [...cols, newCol] },
            cards:   { ...s.cards, [newColId]: newCards },
          };
        });
      },

      copyColumnToProperty(columnId, targetPropertyId) {
        set((s) => {
          const srcPropertyId = columnId.split("__")[0];
          const srcCols = s.columns[srcPropertyId] ?? [];
          const src = srcCols.find((c) => c.id === columnId);
          if (!src) return s;
          const destCols = s.columns[targetPropertyId] ?? [];
          const newColId = `${targetPropertyId}__col-${uid()}`;
          // Copy column structure (no cards) into target property
          const newCol: Column = {
            ...src,
            id: newColId,
            propertyId: targetPropertyId,
            position: destCols.length,
          };
          return {
            columns: { ...s.columns, [targetPropertyId]: [...destCols, newCol] },
          };
        });
      },

      // ── Card actions ───────────────────────────────────────────────────────
      addCard(cardData, userName) {
        const col    = get().cards[cardData.columnId] ?? [];
        const newCard: Card = {
          ...cardData,
          id:        `card-${uid()}`,
          position:  col.length,
          createdAt: new Date().toISOString(),
          isDone:    false,
        };
        const evt = actEvent(newCard.id, "created", `${userName} añadió esta tarjeta`);
        set((s) => ({
          cards: {
            ...s.cards,
            [cardData.columnId]: [...(s.cards[cardData.columnId] ?? []), newCard],
          },
          activity: {
            ...s.activity,
            [newCard.id]: [evt],
          },
        }));
      },

      updateCard(cardId, patch) {
        set((s) => {
          const newCards = { ...s.cards };
          for (const colId of Object.keys(newCards)) {
            const idx = newCards[colId].findIndex((c) => c.id === cardId);
            if (idx !== -1) {
              newCards[colId] = newCards[colId].map((c) =>
                c.id === cardId ? { ...c, ...patch } : c
              );
              break;
            }
          }
          return { cards: newCards };
        });
      },

      moveCard(cardId, toColumnId, userName) {
        set((s) => {
          // Find source column
          let fromColId = "";
          let card: Card | undefined;
          for (const colId of Object.keys(s.cards)) {
            const found = s.cards[colId].find((c) => c.id === cardId);
            if (found) { fromColId = colId; card = found; break; }
          }
          if (!card || fromColId === toColumnId) return s;

          // Find column titles for activity
          const propertyId = toColumnId.split("__")[0];
          const cols = s.columns[propertyId] ?? [];
          const fromTitle = cols.find((c) => c.id === fromColId)?.title ?? fromColId;
          const toTitle   = cols.find((c) => c.id === toColumnId)?.title ?? toColumnId;
          const evt = actEvent(cardId, "moved", `${userName} movió de "${fromTitle}" a "${toTitle}"`);

          const updatedCard: Card = { ...card, columnId: toColumnId, position: (s.cards[toColumnId] ?? []).length };
          return {
            cards: {
              ...s.cards,
              [fromColId]: s.cards[fromColId].filter((c) => c.id !== cardId),
              [toColumnId]: [...(s.cards[toColumnId] ?? []), updatedCard],
            },
            activity: { ...s.activity, [cardId]: [...(s.activity[cardId] ?? []), evt] },
          };
        });
      },

      toggleCardDone(cardId, userName) {
        set((s) => {
          const newCards = { ...s.cards };
          let toggled = false;
          for (const colId of Object.keys(newCards)) {
            const idx = newCards[colId].findIndex((c) => c.id === cardId);
            if (idx !== -1) {
              const card = newCards[colId][idx];
              const nowDone = !card.isDone;
              const patch: Partial<Card> = { isDone: nowDone };
              if (nowDone) { patch.cleanedAt = new Date().toISOString(); patch.cleanedBy = userName; }
              newCards[colId] = newCards[colId].map((c) => c.id === cardId ? { ...c, ...patch } : c);
              toggled = true;
              break;
            }
          }
          if (!toggled) return s;
          const card = Object.values(newCards).flat().find((c) => c.id === cardId);
          const evtType: ActivityEvent["type"] = card?.isDone ? "done" : "undone";
          const evtMsg = card?.isDone
            ? `${userName} marcó como hecho`
            : `${userName} desmarcó como hecho`;
          const evt = actEvent(cardId, evtType, evtMsg);
          return {
            cards: newCards,
            activity: { ...s.activity, [cardId]: [...(s.activity[cardId] ?? []), evt] },
          };
        });
      },

      archiveCard(cardId, userName) {
        set((s) => {
          let archived: ArchivedCard | null = null;
          const newCards = { ...s.cards };
          for (const colId of Object.keys(newCards)) {
            const card = newCards[colId].find((c) => c.id === cardId);
            if (card) {
              archived = { ...card, archivedAt: new Date().toISOString(), archivedBy: userName };
              newCards[colId] = newCards[colId].filter((c) => c.id !== cardId);
              break;
            }
          }
          if (!archived) return s;
          return { cards: newCards, archivedCards: [...s.archivedCards, archived] };
        });
      },

      addComment(cardId, text, user) {
        const comment: Comment = {
          id:             `cmt-${uid()}`,
          cardId,
          author:         user.name,
          authorInitials: user.initials,
          text,
          createdAt:      new Date().toISOString(),
        };
        const evt = actEvent(cardId, "commented", `${user.name} comentó`);
        set((s) => ({
          comments: { ...s.comments, [cardId]: [...(s.comments[cardId] ?? []), comment] },
          activity: { ...s.activity, [cardId]: [...(s.activity[cardId] ?? []), evt] },
        }));
      },

      resetAll() {
        set({ properties: [], columns: {}, cards: {}, archivedCards: [], comments: {}, activity: {} });
      },
    }),
    {
      name: "pmr-board-v3",
    }
  )
);