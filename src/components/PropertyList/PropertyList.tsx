import type { Property } from "../../types";
import "./PropertyList.css";

interface PropertyListProps {
  properties: Property[];
  onSelectProperty: (property: Property) => void;
}

const PROPERTY_COLORS: Record<string, string> = {
  "prop-fn13": "#6366f1",
  "prop-madrid-rio": "#0ea5e9",
  "prop-romeo": "#ec4899",
  "prop-julieta": "#f59e0b",
  "prop-moroto": "#10b981",
};

export function PropertyList({ properties, onSelectProperty }: PropertyListProps) {
  return (
    <div className="property-list">
      <header className="property-list__header">
        <div className="property-list__header-content">
          <h1 className="property-list__title">🏠 Gestión de Propiedades</h1>
          <p className="property-list__subtitle">
            Selecciona una propiedad para ver el estado de sus habitaciones
          </p>
        </div>
      </header>

      <main className="property-list__main">
        <div className="property-list__grid">
          {properties.map((property) => (
            <PropertyCard
              key={property.id}
              property={property}
              color={PROPERTY_COLORS[property.id] ?? "#6b7280"}
              onSelect={() => onSelectProperty(property)}
            />
          ))}
        </div>
      </main>
    </div>
  );
}

interface PropertyCardProps {
  property: Property;
  color: string;
  onSelect: () => void;
}

function PropertyCard({ property, color, onSelect }: PropertyCardProps) {
  return (
    <button className="property-card" onClick={onSelect} aria-label={`Ver ${property.name}`}>
      <div className="property-card__color-bar" style={{ background: color }} />

      {property.imageUrl && (
        <div className="property-card__image-wrapper">
          <img
            src={property.imageUrl}
            alt={property.name}
            className="property-card__image"
            loading="lazy"
          />
        </div>
      )}

      <div className="property-card__body">
        <div className="property-card__header">
          <span
            className="property-card__code"
            style={{ background: color + "22", color }}
          >
            {property.code}
          </span>
          <span className="property-card__rooms">
            {property.totalRooms} hab.
          </span>
        </div>

        <h2 className="property-card__name">{property.name}</h2>

        {property.address && (
          <p className="property-card__address">📍 {property.address}</p>
        )}

        <div className="property-card__cta" style={{ color }}>
          Ver tablero →
        </div>
      </div>
    </button>
  );
}
