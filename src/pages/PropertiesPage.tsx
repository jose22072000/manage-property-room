import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Icon } from "@iconify/react";
import { useBoardStore, EMPTY_COLS, EMPTY_CARDS } from "@/store/boardStore";
import { getPropertyGradient } from "@/lib/propertyVisuals";
import { cn } from "@/lib/utils";

export function PropertiesPage() {
  const navigate    = useNavigate();
  const { properties, columns, cards, loadProperties } = useBoardStore();

  useEffect(() => {
    if (properties.length === 0) loadProperties();
  }, [properties.length, loadProperties]);

  return (
    <div className="px-4 pt-5 pb-24 max-w-3xl mx-auto">
      <h1 className="text-xl font-bold text-gray-900 mb-1">Tableros</h1>
      <p className="text-sm text-gray-400 mb-6">Selecciona una propiedad para ver su tablero</p>

      <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
        {properties.map((p) => {
          const cols      = columns[p.id] ?? EMPTY_COLS;
          let done = 0, total = 0;
          for (const col of cols) {
            const colCards = cards[col.id] ?? EMPTY_CARDS;
            total += colCards.length;
            done  += colCards.filter((c) => c.isDone).length;
          }
          const gradient = getPropertyGradient(p.id);
          const hasData  = cols.length > 0;

          return (
            <button
              key={p.id}
              onClick={() => navigate(`/properties/${p.id}/board`)}
              className={cn(
                "relative h-36 rounded-2xl overflow-hidden shadow-md",
                "hover:scale-[1.03] hover:shadow-xl transition-all duration-200 text-left",
                gradient
              )}
            >
              {/* Dark overlay */}
              <div className="absolute inset-0 bg-black/35" />

              {/* Star icon top-right */}
              <div className="absolute top-3 right-3">
                <Icon icon="mdi:star-outline" className="text-white/60" width={18} />
              </div>

              {/* Content */}
              <div className="absolute bottom-0 left-0 right-0 p-3">
                <p className="font-bold text-white text-sm leading-tight drop-shadow">
                  {p.name}
                </p>
                {hasData && total > 0 && (
                  <p className="text-white/70 text-[11px] mt-0.5">
                    {done}/{total} listas
                  </p>
                )}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}
