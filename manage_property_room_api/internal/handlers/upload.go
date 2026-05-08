package handlers

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"
	"github.com/jose/manage_property_room_api/internal/httpx"
)

// UploadHandler handles file uploads for property images.
type UploadHandler struct {
	UploadDir string // absolute path where files are saved
	BaseURL   string // public URL prefix, e.g. "http://host:8080"
}

const maxUploadSize = 5 << 20 // 5 MB

// Upload accepts multipart/form-data with field "file" and saves it to disk.
func (h *UploadHandler) Upload(w http.ResponseWriter, r *http.Request) {
	if err := r.ParseMultipartForm(maxUploadSize); err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "file too large or invalid"); return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "missing 'file' field"); return
	}
	defer file.Close()

	// Validate content type
	contentType := header.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "image/") {
		httpx.WriteError(w, http.StatusBadRequest, "BAD_REQUEST", "only image files are allowed"); return
	}

	// Determine extension
	ext := filepath.Ext(header.Filename)
	if ext == "" {
		switch contentType {
		case "image/jpeg":
			ext = ".jpg"
		case "image/png":
			ext = ".png"
		case "image/webp":
			ext = ".webp"
		default:
			ext = ".bin"
		}
	}

	// Ensure upload directory exists
	if err := os.MkdirAll(h.UploadDir, 0o755); err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "INTERNAL", "cannot create upload dir"); return
	}

	filename := uuid.NewString() + ext
	dst, err := os.Create(filepath.Join(h.UploadDir, filename))
	if err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "INTERNAL", "cannot save file"); return
	}
	defer dst.Close()

	if _, err := io.Copy(dst, file); err != nil {
		httpx.WriteError(w, http.StatusInternalServerError, "INTERNAL", "write error"); return
	}

	url := fmt.Sprintf("%s/static/%s", strings.TrimRight(h.BaseURL, "/"), filename)
	httpx.WriteJSON(w, http.StatusCreated, map[string]string{"url": url})
}
