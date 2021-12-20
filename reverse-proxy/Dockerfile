FROM golang:1.17-alpine

WORKDIR /app
COPY go.mod ./
COPY *.go ./
RUN go build -o /reverse-proxy

ENTRYPOINT [ "/reverse-proxy" ]