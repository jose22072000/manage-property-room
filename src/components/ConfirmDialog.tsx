import { useConfirmStore } from "@/store/confirmStore";
import { cn } from "@/lib/utils";

export function ConfirmDialogRoot() {
  const { open, message, description, confirmLabel, cancelLabel, danger, respond } =
    useConfirmStore();

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center p-4"
      style={{ backgroundColor: "rgba(0,0,0,0.4)", backdropFilter: "blur(3px)" }}
      onMouseDown={(e) => { if (e.target === e.currentTarget) respond(false); }}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-sm flex flex-col"
        style={{ animation: "confirmIn 0.15s ease-out" }}
      >
        {/* Body */}
        <div className="px-6 pt-6 pb-4">
          <p className="text-base font-semibold text-gray-900 leading-snug">{message}</p>
          {description && (
            <p className="text-sm text-gray-500 mt-1.5 leading-relaxed">{description}</p>
          )}
        </div>

        {/* Divider */}
        <div className="h-px bg-gray-100 mx-1" />

        {/* Actions */}
        <div className="flex gap-2.5 px-6 py-4 justify-end">
          <button
            autoFocus
            onClick={() => respond(false)}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors"
          >
            {cancelLabel ?? "Cancelar"}
          </button>
          <button
            onClick={() => respond(true)}
            className={cn(
              "px-4 py-2 text-sm font-semibold text-white rounded-xl transition-colors",
              danger
                ? "bg-red-500 hover:bg-red-600 active:bg-red-700"
                : "bg-blue-500 hover:bg-blue-600 active:bg-blue-700"
            )}
          >
            {confirmLabel ?? "Aceptar"}
          </button>
        </div>
      </div>

      <style>{`
        @keyframes confirmIn {
          from { opacity: 0; transform: scale(0.94) translateY(8px); }
          to   { opacity: 1; transform: scale(1) translateY(0); }
        }
      `}</style>
    </div>
  );
}
