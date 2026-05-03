import { useState } from "react";
import type { Property } from "./types";
import { mockProperties } from "./data/mockProperties";
import { PropertyList } from "./components/PropertyList/PropertyList";
import { BoardView } from "./components/Board/BoardView";
import "./App.css";

// Simulated logged-in user – replace with real auth in the next phase
const CURRENT_USER = "María García";

type AppView =
  | { page: "properties" }
  | { page: "board"; property: Property };

function App() {
  const [view, setView] = useState<AppView>({ page: "properties" });

  function handleSelectProperty(property: Property) {
    setView({ page: "board", property });
  }

  function handleBack() {
    setView({ page: "properties" });
  }

  if (view.page === "board") {
    return (
      <BoardView
        propertyId={view.property.id}
        propertyName={view.property.name}
        onBack={handleBack}
        currentUser={CURRENT_USER}
      />
    );
  }

  return (
    <PropertyList
      properties={mockProperties}
      onSelectProperty={handleSelectProperty}
    />
  );
}

export default App;
