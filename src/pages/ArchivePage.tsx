import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Icon } from "@iconify/react";
import { useBoardStore } from "@/store/boardStore";
import { useToastStore } from "@/store/toastStore";
import { useConfirmStore } from "@/store/confirmStore";
import { mockProperties } from "@/mocks/mockProperties";
import { cn } from "@/lib/utils";

function formatDate(iso: string) {
  return new Date(iso).toLocaleDateString("es-ES", {
    weekday: "long", year: "numeric", month: "long", day: "numeric",
  });
}
function formatTime(iso: string) {
  return new Date(iso).toLocaleTimeString("es-ES", { hour: "2-digit", minute: "2-digit" });
}

const PRIORITY_COLORS: Record<string, string> = {
  HIGH:   "bg-red-100 text-red-600",
  NORMAL: "bg-yellow-100 text-yellow-600",
  LOW:    "bg-green-100 text-green-600",
};

export function ArchivePage() {
  const navigate      = useNavigate();
  const archivedCards = useBoardStore((s) => s.archivedCards);
  const addToast      = useToastStore((s) => s.addToast);
  const resetAll      = useBoardStore((s) => s.resetAll);
  const ask           = useConfirmStore((s) => s.ask);

  const [activePropertyId, setActivePropertyId] = useState<string | "all">("all");

  // Properties that actually have archived cards
  const propertiesWithCards = useMemo(() => {
    const ids = new Set(archivedCards.map((c) => c.propertyId));
    return mockProperties.filter((p) => ids.has(p.id));
  }, [archivedCards]);

  // Filter by selected property
  const filtered = useMemo(() => {
    const base = activePropertyId === "all"
      ? archivedCards
      : archivedCards.filter((c) => c.propertyId === activePropertyId);
    return [...base].sort((a, b) => new Date(b.archivedAt).getTime() - new Date(a.archivedAt).getTime());
  }, [archivedCards, activePropertyId]);

  // Group by property, then by day within each property
  const byProperty = useMemo(() => {
    if (activePropertyId !== "all") {
      // Single property: group by day only
      const byDay: Record<string, typeof filtered> = {};
      filtered.forEach((c) => {
        const day = new Date(c.archivedAt).toLocaleDateString("es-ES");
        if (!byDay[day]) byDay[day] = [];
        byDay[day].push(c);
      });
      const prop = mockProperties.find((p) => p.id === activePropertyId);
      return [{ propertyId: activePropertyId, propertyName: prop?.name ?? activePropertyId, byDay }];
    }
    // All: group by property, then by day
    const propMap: Record<string, typeof filtered> = {};
    filtered.forEach((c) => {
      if (!propMap[c.propertyId]) propMap[c.propertyId] = [];
      propMap[c.propertyId].push(c);
    });
    return Object.entries(propMap).map(([propertyId, cards]) => {
      const byDay: Record<string, typeof filtered> = {};
      cards.forEach((c) => {
        const day = new Date(c.archivedAt).toLocaleDateString("es-ES");
        if (!byDay[day]) byDay[day] = [];
        byDay[day].push(c);
      });
      const prop = mockProperties.find((p) => p.id === propertyId);
      return { propertyId, propertyName: prop?.name ?? propertyId, byDay };
    });
  }, [filtered, activePropertyId]);

  return (
    <div className="max-w-screen-md mx-auto px-4 py-6 pb-28 md:pb-8">
      {/* Header */}
      <div className="flex items-center gap-3 mb-5">
        <button
          onClick={() => navigate(-1)}
          className="p-2 rounded-xl hover:bg-gray-100 text-gray-400 hover:text-gray-700 transition-colors"
        >
          <Icon icon="mdi:arrow-left" width={20} />
        </button>
        <div className="flex-1 min-w-0">
          <h1 className="text-xl font-bold text-gray-900">Archivo</h1>
          <p className="text-xs text-gray-400">{archivedCards.length} tarjeta{archivedCards.length !== 1 ? "s" : ""} archivada{archivedCards.length !== 1 ? "s" : ""}</p>
        </div>
        {archivedCards.length > 0 && (
          <button
            onClick={async () => {
              const ok = await ask({
                message: "¿Borrar todo el historial?",
                description: "Esta acción no se puede deshacer.",
                confirmLabel: "Borrar todo",
                danger: true,
              });
              if (ok) { resetAll(); addToast("Historial borrado"); setActivePropertyId("all"); }
            }}
            className="text-xs text-gray-400 hover:text-red-500 transition-colors px-2 py-1"
          >
            Borrar todo
          </button>
        )}
      </div>

      {/* Property tabs */}
      {archivedCards.length > 0 && (
        <div className="flex gap-2 overflow-x-auto pb-1 mb-5 scrollbar-hide">
          <TabBtn active={activePropertyId === "all"} onClick={() => setActivePropertyId("all")}>
            Todas ({archivedCards.length})
          </TabBtn>
          {propertiesWithCards.map((p) => {
            const count = archivedCards.filter((c) => c.propertyId === p.id).length;
            return (
              <TabBtn key={p.id} active={activePropertyId === p.id} onClick={() => setActivePropertyId(p.id)}>
                {p.name} ({count})
              </TabBtn>
            );
          })}
        </div>
      )}

      {archivedCards.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-20 text-gray-300">
          <Icon icon="mdi:archive-outline" width={72} />
          <p className="mt-4 text-sm font-medium">No hay tarjetas archivadas</p>
          <p className="text-xs mt-1 text-gray-300">Archiva tarjetas desde el tablero</p>
        </div>
      ) : filtered.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 text-gray-300">
          <Icon icon="mdi:archive-search-outline" width={48} />
          <p className="mt-3 text-sm">Sin resultados para esta propiedad</p>
        </div>
      ) : (
        <div className="space-y-8">
          {byProperty.map(({ propertyId, propertyName, byDay }) => (
            <div key={propertyId}>
              {/* Property header — only shown in "all" view */}
              {activePropertyId === "all" && (
                <div className="flex items-center gap-2.5 mb-3">
                  <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white text-[10px] font-bold shrink-0">
                    {propertyName.slice(0, 2).toUpperCase()}
                  </div>
                  <h2 className="text-base font-bold text-gray-800">{propertyName}</h2>
                  <span className="text-xs text-gray-400 bg-gray-100 rounded-full px-2 py-0.5">
                    {Object.values(byDay).flat().length} tarjeta{Object.values(byDay).flat().length !== 1 ? "s" : ""}
                  </span>
                  <div className="flex-1 h-px bg-gray-100" />
                </div>
              )}

              {/* Days within this property */}
              <div className="space-y-4">
                {Object.entries(byDay).map(([day, dayCards]) => (
                  <div key={day}>
                    <div className="flex items-center gap-2 mb-2">
                      <Icon icon="mdi:calendar-month-outline" className="text-gray-300" width={14} />
                      <span className="text-xs font-semibold text-gray-400 capitalize">
                        {formatDate(dayCards[0].archivedAt)}
                      </span>
                      <span className="text-[10px] text-gray-300 bg-gray-50 rounded-full px-1.5">{dayCards.length}</span>
                    </div>
                    <div className="space-y-2">
                      {dayCards.map((card) => (
                        <div
                          key={`${card.id}-${card.archivedAt}`}
                          className="bg-white border border-gray-100 rounded-xl p-3 flex items-center gap-3 hover:border-gray-200 transition-colors"
                        >
                          {/* Icon */}
                          <div className="w-9 h-9 rounded-xl bg-gray-100 flex items-center justify-center text-xs font-bold text-gray-500 shrink-0">
                            {card.roomCode ?? card.title.slice(0, 2).toUpperCase()}
                          </div>
                          {/* Main info */}
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 flex-wrap">
                              <span className="text-sm font-semibold text-gray-900 truncate">
                                {card.roomCode ?? card.title}
                              </span>
                              {card.priority && card.priority !== "NORMAL" && (
                                <span className={cn("text-[10px] font-medium px-1.5 py-0.5 rounded-full", PRIORITY_COLORS[card.priority])}>
                                  {card.priority === "HIGH" ? "Alta" : "Baja"}
                                </span>
                              )}
                            </div>
                            <div className="flex items-center gap-3 mt-0.5 flex-wrap">
                              {card.cleanedBy && (
                                <span className="text-[11px] text-gray-400 flex items-center gap-1">
                                  <Icon icon="mdi:broom" width={10} />
                                  {card.cleanedBy}
                                </span>
                              )}
                              {card.archivedBy && (
                                <span className="text-[11px] text-gray-400 flex items-center gap-1">
                                  <Icon icon="mdi:archive-arrow-down-outline" width={10} />
                                  {card.archivedBy}
                                </span>
                              )}
                              {card.customFields?.cobrar && (
                                <span className="text-[11px] text-green-600 flex items-center gap-1 font-medium">
                                  <Icon icon="mdi:currency-eur" width={10} />
                                  {card.customFields.cobrar}
                                </span>
                              )}
                            </div>
                          </div>
                          {/* Time */}
                          <div className="text-xs text-gray-300 shrink-0 tabular-nums">
                            {formatTime(card.archivedAt)}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function TabBtn({ children, active, onClick }: { children: React.ReactNode; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "shrink-0 px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors whitespace-nowrap",
        active ? "bg-blue-500 text-white shadow-sm" : "bg-gray-100 text-gray-600 hover:bg-gray-200"
      )}
    >
      {children}
    </button>
  );
}
