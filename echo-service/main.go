package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"
)

var (
	listenFlag  = flag.String("listen", ":5678", "address and port to listen")
	textFlag    = flag.String("text", "", "text to put on the webpage")
	nodeFlag    = flag.String("node", "", "value for node-cookie")
	versionFlag = flag.Bool("version", false, "display version information")

	// stdoutW and stderrW are for overriding in test.
	stdoutW = os.Stdout
	stderrW = os.Stderr
)

func main() {
	flag.Parse()

	// Asking for the version?
	if *versionFlag {
		fmt.Fprintln(stderrW, "1.0.0")
		os.Exit(0)
	}

	// Validation
	if *textFlag == "" {
		fmt.Fprintln(stderrW, "Missing -text option!")
		os.Exit(127)
	}

	// Validation
	if *nodeFlag == "" {
		fmt.Fprintln(stderrW, "Missing -node option! (Values: blue |")
		os.Exit(127)
	}

	args := flag.Args()
	if len(args) > 0 {
		fmt.Fprintln(stderrW, "Too many arguments!")
		os.Exit(127)
	}

	// Flag gets printed as a page
	mux := http.NewServeMux()
	mux.HandleFunc("/", httpLog(stdoutW, withAppHeaders(httpEcho(*textFlag, *nodeFlag))))

	// Health endpoint
	mux.HandleFunc("/health", withAppHeaders(httpHealth()))

	server := &http.Server{
		Addr:    *listenFlag,
		Handler: mux,
	}
	serverCh := make(chan struct{})
	go func() {
		log.Printf("[INFO] server is listening on %s\n", *listenFlag)
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("[ERR] server exited with: %s", err)
		}
		close(serverCh)
	}()

	signalCh := make(chan os.Signal, 1)
	signal.Notify(signalCh, os.Interrupt)

	// Wait for interrupt
	<-signalCh

	log.Printf("[INFO] received interrupt, shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("[ERR] failed to shutdown server: %s", err)
	}

	// If we got this far, it was an interrupt, so don't exit cleanly
	os.Exit(2)
}

func httpEcho(responseValue string, nodeValue string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		expiration := time.Now().Add(365 * 24 * time.Hour)
		cookie := http.Cookie{Name: "node", Value: nodeValue, Expires: expiration}
		http.SetCookie(w, &cookie)
		fmt.Fprintln(w, responseValue)
	}
}

func httpHealth() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, `{"status":"ok"}`)
	}
}
