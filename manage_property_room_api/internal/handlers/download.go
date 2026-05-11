package handlers

import (
	"net/http"
	"os"
	"path/filepath"
)

// DownloadHandler serves downloadable app binaries.
type DownloadHandler struct {
	DownloadDir string // absolute path, e.g. /data/downloads
}

// AppAPK serves the Android APK from DownloadDir/app-release.apk.
func (h *DownloadHandler) AppAPK(w http.ResponseWriter, r *http.Request) {
	h.serveFile(w, r,
		filepath.Join(h.DownloadDir, "app-release.apk"),
		"application/vnd.android.package-archive",
		"manage-property-room.apk",
	)
}

// AppIPA serves the iOS IPA from DownloadDir/app-release.ipa.
// For OTA installation place an enterprise-signed IPA here.
func (h *DownloadHandler) AppIPA(w http.ResponseWriter, r *http.Request) {
	h.serveFile(w, r,
		filepath.Join(h.DownloadDir, "app-release.ipa"),
		"application/octet-stream",
		"manage-property-room.ipa",
	)
}

func (h *DownloadHandler) serveFile(w http.ResponseWriter, r *http.Request, path, contentType, filename string) {
	info, err := os.Stat(path)
	if err != nil || info.IsDir() {
		http.Error(w, "File not available", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Content-Disposition", `attachment; filename="`+filename+`"`)
	w.Header().Set("Cache-Control", "no-store")
	http.ServeFile(w, r, path)
}
