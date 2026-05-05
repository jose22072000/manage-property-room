import { create } from "zustand";

type ToastItem = { id: string; message: string; link?: { label: string; href: string } };

type ToastState = {
  toasts: ToastItem[];
  addToast: (message: string, link?: { label: string; href: string }) => void;
  removeToast: (id: string) => void;
};

export const useToastStore = create<ToastState>()((set) => ({
  toasts: [],

  addToast(message, link?) {
    const id = Math.random().toString(36).slice(2);
    set((s) => ({ toasts: [...s.toasts, { id, message, link }] }));
    setTimeout(() => {
      set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) }));
    }, 3000);
  },

  removeToast(id) {
    set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) }));
  },
}));
