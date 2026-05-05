import { Component, type ReactNode } from "react";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AppShell } from "@/components/AppShell";
import { PropertiesPage } from "@/pages/PropertiesPage";
import { BoardPage } from "@/pages/BoardPage";
import { TodoPage } from "@/pages/TodoPage";
import { ArchivePage } from "@/pages/ArchivePage";
import { SettingsPage } from "@/pages/SettingsPage";
import { Toaster } from "@/components/Toast";
import { ConfirmDialogRoot } from "@/components/ConfirmDialog";

class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null };
  static getDerivedStateFromError(error: Error) { return { error }; }
  render() {
    if (this.state.error) {
      const err = this.state.error as Error;
      return (
        <div className="min-h-screen flex flex-col items-center justify-center p-8 bg-red-50 text-red-900">
          <h1 className="text-xl font-bold mb-2">Error de la aplicación</h1>
          <pre className="text-xs bg-white border border-red-200 rounded-xl p-4 max-w-2xl w-full overflow-auto whitespace-pre-wrap">
            {err.message}{"\n\n"}{err.stack}
          </pre>
          <button
            onClick={() => { localStorage.clear(); window.location.reload(); }}
            className="mt-6 px-6 py-2 bg-red-600 text-white rounded-xl font-semibold hover:bg-red-700"
          >
            Limpiar datos y recargar
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

export default function App() {
  return (
    <ErrorBoundary>
    <BrowserRouter>
      <AppShell>
        <Routes>
          <Route path="/"                        element={<PropertiesPage />} />
          <Route path="/properties/:id/board"    element={<BoardPage />} />
          <Route path="/todo"                    element={<TodoPage />} />
          <Route path="/archive"                 element={<ArchivePage />} />
          <Route path="/settings"                element={<SettingsPage />} />
        </Routes>
      </AppShell>
      <Toaster />
      <ConfirmDialogRoot />
    </BrowserRouter>
    </ErrorBoundary>
  );
}
