import { Link, useLocation } from "react-router-dom";
import { Icon } from "@iconify/react";
import { cn } from "@/lib/utils";

const navItems = [
  { to: "/",        icon: "mdi:home-outline",            activeIcon: "mdi:home",             label: "Inicio"    },
  { to: "/todo",    icon: "mdi:clipboard-list-outline",  activeIcon: "mdi:clipboard-list",   label: "Por hacer" },
  { to: "/archive", icon: "mdi:archive-outline",         activeIcon: "mdi:archive",          label: "Archivo"   },
  { to: "/settings", icon: "mdi:cog-outline",            activeIcon: "mdi:cog",              label: "Config"    },
];

export function BottomNav() {
  const location = useLocation();

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-30 bg-white border-t border-gray-200 safe-bottom md:hidden">
      <div className="flex h-16">
        {navItems.map(({ to, icon, activeIcon, label }) => {
          const isActive =
            to === "/" ? location.pathname === "/" : location.pathname.startsWith(to);
          return (
            <Link
              key={to}
              to={to}
              className={cn(
                "flex-1 flex flex-col items-center justify-center gap-0.5 text-[11px] font-medium transition-colors",
                isActive ? "text-blue-600" : "text-gray-400"
              )}
            >
              <Icon icon={isActive ? activeIcon : icon} width={24} />
              {label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
