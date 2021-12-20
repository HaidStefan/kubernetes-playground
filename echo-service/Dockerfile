FROM golang:1.17-alpine

WORKDIR /app
COPY go.mod ./
COPY *.go ./
RUN go build -o /echo-service

# ENTRYPOINT ["go", "run", "/echo-service"]
ENTRYPOINT [ "/echo-service" ]