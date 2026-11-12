# Build stage
FROM golang:1.26.11-alpine3.24@sha256:ae52b5bc6ed045a9ed26ab03dc19327a802a9cc9aa8b27ed57f5c6b60579b0bb AS builder

WORKDIR /app

# Instala dependências do sistema
RUN apk add --no-cache git

# Instala uma versão fixa do golang-migrate para manter builds reproduzíveis.
RUN go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@v4.20.1

# Copia os arquivos de dependência (inclui o modfile community)
COPY go.mod go.sum go.community.mod go.community.sum ./

# Baixa as dependências usando o modfile COMMUNITY — sem o require/replace do
# evo-enterprise-licensing-go (que só o build tag `enterprise` usa e aponta pra
# ../evo-crm-enterprise, inexistente num build standalone).
RUN go mod download -modfile=go.community.mod

# Copia o código fonte
COPY . .

# Compila a aplicação (build community, sem o SDK enterprise)
RUN CGO_ENABLED=0 GOOS=linux go build -modfile=go.community.mod -o /app/main ./cmd/api

# Debug: Verifica se o binário foi criado
RUN ls -la /app/main

# Final stage
FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

WORKDIR /app

# Instala ca-certificates para HTTPS requests
RUN apk --no-cache add ca-certificates

# Copia o binário compilado do stage anterior
COPY --from=builder /app/main ./main

# Copia o migrate do builder
COPY --from=builder /go/bin/migrate ./migrate

# Copia as migrations
COPY migrations ./migrations

# Copia o script de inicialização
COPY entrypoint.sh ./entrypoint.sh

# Debug: Lista arquivos no diretório
RUN ls -la /app/

# Torna os binários e script executáveis
RUN chmod +x ./main ./migrate ./entrypoint.sh

# Debug: Verifica se os arquivos existem e suas permissões
RUN ls -la ./main ./migrate ./entrypoint.sh

# Expõe a porta da aplicação
EXPOSE 5555

# Executa o script de inicialização
CMD ["./entrypoint.sh"]
