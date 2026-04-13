package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

type response struct {
	Service string `json:"service"`
	Message string `json:"message"`
	Path    string `json:"path"`
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(response{
		Service: "go-hello",
		Message: "Hello from Tilt demo backend",
		Path:    r.URL.Path,
	})
}

func healthHandler(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "18081"
	}

	http.HandleFunc("/api/hello/", helloHandler)
	http.HandleFunc("/healthz", healthHandler)

	addr := ":" + port
	log.Printf("go-hello listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
