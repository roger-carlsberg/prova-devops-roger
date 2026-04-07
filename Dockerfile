FROM golang:1.21 AS builder

WORKDIR /app

COPY . .

RUN go mod init devops/prova || true
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o myapp main.go

FROM alpine:3.20

RUN adduser -D appuser

WORKDIR /app

COPY --from=builder /app/myapp .

USER appuser

EXPOSE 8080

CMD ["./myapp"]
