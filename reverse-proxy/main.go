package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
)

var (
	listenFlag  = flag.String("listen", ":8080", "address and port to listen")
	addressFlag = flag.String("address", "", "address and port to listen")

	stdoutW = os.Stdout
	stderrW = os.Stderr
)

func main() {
	flag.Parse()

	// Validation
	if *addressFlag == "" {
		fmt.Fprintln(stderrW, "Missing -address option!")
		os.Exit(127)
	}

	remote, err := url.Parse(*addressFlag)
	if err != nil {
		panic(err)
	}

	handler := func(p *httputil.ReverseProxy) func(http.ResponseWriter, *http.Request) {
		return func(w http.ResponseWriter, r *http.Request) {
			log.Println(r.URL)
			r.Host = remote.Host
			w.Header().Set("X-Ben", "Rad")
			p.ServeHTTP(w, r)
		}
	}

	proxy := httputil.NewSingleHostReverseProxy(remote)
	http.HandleFunc("/", handler(proxy))
	err = http.ListenAndServe(*listenFlag, nil)
	if err != nil {
		panic(err)
	}
}
