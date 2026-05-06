package config

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	Port        string
	Env         string
	DBDriver    string
	DBDSN       string
	JWTSecret   string
	JWTTTL      time.Duration
	CORSOrigins []string
}

func Load() (*Config, error) {
	_ = godotenv.Load() // optional .env

	ttlStr := getEnv("JWT_TTL", "24h")
	ttl, err := time.ParseDuration(ttlStr)
	if err != nil {
		return nil, fmt.Errorf("invalid JWT_TTL %q: %w", ttlStr, err)
	}

	c := &Config{
		Port:        getEnv("PORT", "8080"),
		Env:         getEnv("ENV", "dev"),
		DBDriver:    getEnv("DB_DRIVER", "sqlite"),
		DBDSN:       getEnv("DB_DSN", "./data/app.db"),
		JWTSecret:   getEnv("JWT_SECRET", ""),
		JWTTTL:      ttl,
		CORSOrigins: splitCSV(getEnv("CORS_ORIGINS", "*")),
	}
	if c.JWTSecret == "" {
		return nil, fmt.Errorf("JWT_SECRET is required")
	}
	if c.DBDriver != "sqlite" {
		return nil, fmt.Errorf("unsupported DB_DRIVER %q (only 'sqlite' supported for now)", c.DBDriver)
	}
	return c, nil
}

func getEnv(k, def string) string {
	if v, ok := os.LookupEnv(k); ok && v != "" {
		return v
	}
	return def
}

func splitCSV(s string) []string {
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
