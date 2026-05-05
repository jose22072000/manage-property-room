import { useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { Icon } from "@iconify/react";
import { useBoardStore, EMPTY_COLS, EMPTY_CARDS } from "@/store/boardStore";
import { Board } from "@/components/board/Board";

export function BoardPage() {
  const { id: propertyId } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { properties, columns, cards, loadProperties, loadProperty } = useBoardStore();

  useEffect(() => {
    if (properties.length === 0) loadProperties();
  }, [properties.length, loadProperties]);

  useEffect(() => {
    if (propertyId) loadProperty(propertyId);
  }, [propertyId, loadProperty]);


  if (!propertyId) return null;

  const property = properties.find((p) => p.id === propertyId);
  const cols     = columns[propertyId] ?? EMPTY_COLS;
  const isLoading = !columns[propertyId];

  // Count done cards across all columns
  let doneCount  = 0;
  let totalCards = 0;
  for (const col of cols) {
    const colCards = cards[col.id] ?? EMPTY_CARDS;
    totalCards += colCards.length;
    doneCount  += colCards.filter((c) => c.isDone).length;
  }

  return (
    <div className="h-full flex flex-col overflow-hidden">
      {/* Page header */}
      <div className="flex items-center gap-3 px-4 pt-4 pb-3 shrink-0">
        <button
          onClick={() => navigate("/")}
          className="hidden md:flex items-center gap-1.5 text-sm text-gray-400 hover:text-gray-900 transition-colors"
        >
          <Icon icon="mdi:arrow-left" width={16} />
          Propiedades
        </button>
        <div className="hidden md:block w-px h-4 bg-gray-200" />
        <div>
          <h1 className="text-lg font-bold text-gray-900 leading-tight">
            {property?.name ?? propertyId}
          </h1>
          <p className="text-xs text-gray-400">
            {doneCount} de {totalCards} tarjetas completadas
          </p>
        </div>
      </div>

      {isLoading ? (
        <div className="flex flex-col items-center justify-center flex-1 text-gray-300 gap-2">
          <Icon icon="mdi:loading" className="animate-spin" width={28} />
          <span className="text-sm">Cargando tablero...</span>
        </div>
      ) : (
        <div className="flex-1 min-h-0 px-4 pb-4">
          <Board propertyId={propertyId} />
        </div>
      )}
    </div>
  );
}
