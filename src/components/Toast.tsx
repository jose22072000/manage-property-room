import { Link } from "react-router-dom";
import { useToastStore } from "@/store/toastStore";

function ToastItem({
  id,
  message,
  link,
}: {
  id: string;
  message: string;
  link?: { label: string; href: string };
}) {
  const removeToast = useToastStore((s) => s.removeToast);

  return (
    <div
      onClick={() => removeToast(id)}
      className="flex items-center gap-3 bg-gray-900 text-white text-sm px-4 py-2.5 rounded-xl shadow-xl cursor-pointer select-none"
      style={{ animation: "slideUp 0.2s ease-out" }}
    >
      <span className="text-green-400 text-base leading-none">✓</span>
      <span className="flex-1">{message}</span>
      {link && (
        <Link
          to={link.href}
          onClick={(e) => { e.stopPropagation(); removeToast(id); }}
          className="text-blue-400 hover:text-blue-300 font-semibold text-xs shrink-0 underline-offset-2 hover:underline"
        >
          {link.label} →
        </Link>
      )}
    </div>
  );
}

export function Toaster() {
  const toasts = useToastStore((s) => s.toasts);

  return (
    <>
      <style>{`
        @keyframes slideUp {
          from { opacity: 0; transform: translateY(12px); }
          to   { opacity: 1; transform: translateY(0); }
        }
      `}</style>
      <div className="fixed bottom-5 right-5 flex flex-col gap-2 z-50 pointer-events-none">
        {toasts.map((t) => (
          <div key={t.id} className="pointer-events-auto">
            <ToastItem id={t.id} message={t.message} link={t.link} />
          </div>
        ))}
      </div>
    </>
  );
}
