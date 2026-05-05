import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Icon } from "@iconify/react";
import { useBoardStore, EMPTY_COLS, EMPTY_CARDS } from "@/store/boardStore";
import { cn } from "@/lib/utils";

const COLORS = ["bg-blue-500", "bg-purple-500", "bg-emerald-500", "bg-orange-500", "bg-rose-500"];

export function TodoPage() {
  const navigate = useNavigate();
  const { properties, columns, cards, loadProperties, loadProperty } = useBoardStore();

  useEffect(() => {
    if (properties.length === 0) loadProperties();
  }, [properties.length, loadProperties]);

  useEffect(() => {
    properties.forEach((p) => loadProperty(p.id));
  }, [properties, loadProperty]);

  // Flatten all cards for totals
  const { totalPending, totalUrgent } = (() => {
    let pending = 0, urgent = 0;
    for (const p of properties) {
      const cols = columns[p.id] ?? EMPTY_COLS;
      for (const col of cols) {
        const colCards = cards[col.id] ?? EMPTY_CARDS;
        for (const c of colCards) {
          if (!c.isDone) {
            pending++;
            if (c.priority === "HIGH" || c.hasNextDayCheckin) urgent++;
          }
        }
      }
    }
    return { totalPending: pending, totalUrgent: urgent };
  })();

  return (
    <div className="px-4 py-6 pb-28 md:pb-8">
      <div className="mb-6">
        <h1 className="text-xl font-bold text-gray-900">Por hacer</h1>
        <div className="flex items-center gap-3 mt-1 flex-wrap">
          <span className="text-sm text-gray-500">
            {totalPending} tarjeta{totalPending !== 1 ? "s" : ""} pendiente{totalPending !== 1 ? "s" : ""}
          </span>
          {totalUrgent > 0 && (
            <span className="flex items-center gap-1 text-xs font-bold text-red-600 bg-red-50 px-2 py-0.5 rounded-full">
              <Icon icon="mdi:alert-circle" width={12} />
              {totalUrgent} urgente{totalUrgent !== 1 ? "s" : ""}
            </span>
          )}
        </div>
      </div>

      {totalPending === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-green-400">
          <Icon icon="mdi:check-circle" width={72} />
          <p className="text-xs text-gray-400 mt-1">Todas las tarjetas estan completadas</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {properties.map((property, i) => {
            const cols      = columns[property.id] ?? EMPTY_COLS;
            let done = 0, total = 0;
            const pendingCards: import("@/types/domain").Card[] = [];
            for (const col of cols) {
              const colCards = cards[col.id] ?? EMPTY_CARDS;
              total += colCards.length;
              for (const c of colCards) {
                if (c.isDone) done++;
                else pendingCards.push(c);
              }
            }
            const urgentCards = pendingCards.filter((c) => c.priority === "HIGH" || c.hasNextDayCheckin);
            const normalCards = pendingCards.filter((c) => !(c.priority === "HIGH" || c.hasNextDayCheckin));
            const pct = total > 0 ? Math.round((done / total) * 100) : 100;

            return (
              <div key={property.id} className="bg-white border border-gray-200 rounded-2xl overflow-hidden shadow-sm">
                <button
                  onClick={() => navigate(`/properties/${property.id}/board`)}
                  className="w-full flex items-center gap-3 px-4 pt-4 pb-3 hover:bg-gray-50 transition-colors group"
                >
                  <div className={cn("w-9 h-9 rounded-xl flex items-center justify-center text-white font-bold text-xs shrink-0", COLORS[i % COLORS.length])}>
                    {property.code.slice(0, 2).toUpperCase()}
                  </div>
                  <div className="flex-1 text-left min-w-0">
                    <div className="font-bold text-gray-900 group-hover:text-blue-600 text-sm transition-colors">{property.name}</div>
                    <div className="flex items-center gap-2 mt-0.5">
                      <div className="h-1.5 w-24 bg-gray-100 rounded-full overflow-hidden">
                        <div className="h-full bg-green-500 rounded-full transition-all" style={{ width: `${pct}%` }} />
                      </div>
                      <span className="text-[10px] text-gray-400">{done}/{total} listas</span>
                    </div>
                  </div>
                  <div className="flex items-center gap-1.5 shrink-0">
                    {urgentCards.length > 0 && (
                      <span className="flex items-center gap-0.5 bg-red-100 text-red-600 text-[10px] font-bold px-1.5 py-0.5 rounded-full">
                        <Icon icon="mdi:alert-circle" width={10} />
                        {urgentCards.length}
                      </span>
                    )}
                    {pendingCards.length === 0 && <Icon icon="mdi:check-circle" className="text-green-500" width={18} />}
                    <Icon icon="mdi:open-in-new" className="text-gray-300 group-hover:text-blue-400 transition-colors" width={15} />
                  </div>
                </button>

                {pendingCards.length === 0 ? (
                  <div className="px-4 pb-3 text-xs text-green-600 flex items-center gap-1.5 border-t border-gray-50">
                    <Icon icon="mdi:check-circle" width={12} />
                    Todo listo en esta propiedad
                  </div>
                ) : (
                  <div className="border-t border-gray-100">
                    {urgentCards.length > 0 && (
                      <div className="px-4 py-2.5 bg-red-50/60">
                        <div className="flex items-center gap-1.5 text-[10px] font-semibold text-red-400 uppercase tracking-wide mb-2">
                          <Icon icon="mdi:alert-circle" width={11} />
                          Urgente
                        </div>
                        <div className="space-y-1.5">
                          {urgentCards.map((card) => (
                            <div key={card.id} className="flex items-center gap-2.5 bg-white border border-red-100 rounded-xl px-3 py-2">
                              <Icon icon="mdi:alert-circle" className="text-red-500 shrink-0" width={14} />
                              <span className="font-bold text-red-700 text-sm">{card.roomCode ?? card.title}</span>
                              {card.checkinDate && (
                                <span className="text-[10px] text-red-400 ml-auto shrink-0">
                                  {new Date(card.checkinDate + "T00:00:00").toLocaleDateString("es-ES", { day: "numeric", month: "short" })}
                                </span>
                              )}
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                    {normalCards.length > 0 && (
                      <div className="px-4 py-2.5">
                        {urgentCards.length > 0 && (
                          <div className="text-[10px] font-semibold text-gray-400 uppercase tracking-wide mb-2">Pendientes</div>
                        )}
                        <div className="space-y-1.5">
                          {normalCards.map((card) => (
                            <div key={card.id} className="flex items-center gap-2.5 bg-gray-50 rounded-xl px-3 py-2">
                              <div className="w-2 h-2 rounded-full bg-gray-300 shrink-0" />
                              <span className="font-semibold text-gray-800 text-sm">{card.roomCode ?? card.title}</span>
                              {card.assignedTo && (
                                <span className="text-xs text-gray-400 ml-auto truncate">{card.assignedTo.split(" ")[0]}</span>
                              )}
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
