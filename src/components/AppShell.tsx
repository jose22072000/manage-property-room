import type { ReactNode } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { Icon } from "@iconify/react";
import { UserSelector } from "./UserSelector";
import { BottomNav } from "./BottomNav";
import { useBoardStore } from "@/store/boardStore";
import { useConfirmStore } from "@/store/confirmStore";

export function AppShell({ children }: { children: ReactNode }) {
  const location  = useLocation();
  const navigate  = useNavigate();
  const resetAll  = useBoardStore((s) => s.resetAll);
  const ask       = useConfirmStore((s) => s.ask);

  const isBoardPage    = location.pathname.includes("/board");
  const isArchivePage  = location.pathname === "/archive";
  const isTodoPage     = location.pathname === "/todo";
  const isSettingsPage = location.pathname === "/settings";

  async function handleReset() {
    const ok = await ask({
      message: "¿Resetear todos los datos?",
      description: "Se borrarán los cambios y el historial.",
      confirmLabel: "Resetear",
      danger: true,
    });
    if (ok) {
      resetAll();
      window.location.reload();
    }
  }

  return (
    <div className="h-dvh flex flex-col bg-gray-50 overflow-hidden">
      {/* ── Header ── */}
      <header className="bg-white border-b border-gray-200 shadow-sm sticky top-0 z-30">
        <div className="max-w-screen-2xl mx-auto px-4 h-14 flex items-center gap-3">
          {/* Back button on sub-pages */}
          {(isBoardPage || isArchivePage || isTodoPage || isSettingsPage) && (
            <button
              onClick={() => navigate(-1)}
              className="p-1.5 -ml-1 rounded-xl hover:bg-gray-100 text-gray-400 hover:text-gray-700 transition-colors shrink-0 md:hidden"
            >
              <Icon icon="mdi:arrow-left" width={22} />
            </button>
          )}

          {/* Logo */}
          <Link
            to="/"
            className="flex items-center gap-2 font-bold text-gray-900 hover:text-blue-600 transition-colors shrink-0"
          >
            <Icon icon="mdi:home-city-outline" className="text-blue-600" width={24} />
            <span className="hidden sm:block text-sm">Gestión de Propiedades</span>
          </Link>

          {/* Desktop nav links */}
          <nav className="hidden md:flex items-center gap-1 ml-4">
            <Link
              to="/"
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
                location.pathname === "/" ? "bg-blue-50 text-blue-600" : "text-gray-500 hover:text-gray-800 hover:bg-gray-100"
              }`}
            >
              Propiedades
            </Link>
            <Link
              to="/todo"
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors flex items-center gap-1.5 ${
                location.pathname === "/todo" ? "bg-blue-50 text-blue-600" : "text-gray-500 hover:text-gray-800 hover:bg-gray-100"
              }`}
            >
              <Icon icon="mdi:clipboard-list-outline" width={16} />
              Por hacer
            </Link>
            <Link
              to="/archive"
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors flex items-center gap-1.5 ${
                location.pathname === "/archive" ? "bg-blue-50 text-blue-600" : "text-gray-500 hover:text-gray-800 hover:bg-gray-100"
              }`}
            >
              <Icon icon="mdi:archive-outline" width={16} />
              Archivo
            </Link>
            <Link
              to="/settings"
              className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors flex items-center gap-1.5 ${
                location.pathname === "/settings" ? "bg-blue-50 text-blue-600" : "text-gray-500 hover:text-gray-800 hover:bg-gray-100"
              }`}
            >
              <Icon icon="mdi:cog-outline" width={16} />
              Configuración
            </Link>
          </nav>

          {/* Spacer */}
          <div className="flex-1" />

          {/* Reset */}
          <button
            onClick={handleReset}
            className="hidden md:flex items-center gap-1.5 text-xs text-gray-400 hover:text-red-500 transition-colors px-2 py-1"
            title="Resetear datos mock"
          >
            <Icon icon="mdi:refresh" width={15} />
            Resetear
          </button>

          {/* User selector */}
          <UserSelector />
        </div>
      </header>

      {/* ── Content ── */}
      <main className={isBoardPage
        ? "flex-1 min-h-0 overflow-hidden flex flex-col"
        : "flex-1 min-h-0 overflow-y-auto pb-16 md:pb-0"
      }>{children}</main>

      {/* ── Mobile bottom nav ── */}
      <BottomNav />
    </div>
  );
}
