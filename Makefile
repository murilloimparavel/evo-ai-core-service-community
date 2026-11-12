.PHONY: setup dev run install db-setup db-migrate db-seed db-reset migrate-up migrate-down migrate-create migrate-force db-create db-drop build clean tidy help

include .env

# Variables (edit as needed)
DB_URL = postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=$(DB_SSLMODE)
DB_URL_ADMIN = postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/postgres?sslmode=$(DB_SSLMODE)
DB_URL_WITH_CUSTOM_SCHEMA = postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=$(DB_SSLMODE)&x-migrations-table=evo_core_schema_community_migrations
MIGRATIONS_DIR = migrations
MIGRATION_COUNT ?= 1
MIGRATE_VERSION ?= v4.19.1

# =============================================================================
# PADRÃO PADRONIZADO - COMANDOS PRINCIPAIS
# =============================================================================

# Setup completo do projeto (install + db-setup)
setup: install db-setup
	@echo "✅ Setup completo concluído!"

# Instalar dependências e ferramentas
install:
	@echo "📦 Instalando dependências Go..."
	go mod tidy
	go mod download
	@echo "🔧 Instalando golang-migrate..."
	@if ! command -v migrate &> /dev/null; then \
		echo "Instalando golang-migrate..."; \
		go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@$(MIGRATE_VERSION); \
	else \
		echo "golang-migrate já está instalado"; \
	fi
	@echo "✅ Instalação concluída!"

# Rodar em modo desenvolvimento
dev:
	@echo "🔧 Iniciando EvoAI Core Service em modo desenvolvimento..."
	go run -race cmd/api/main.go -dev

# Rodar em modo produção
run:
	@echo "🚀 Iniciando EvoAI Core Service em modo produção..."
	go run cmd/api/main.go

# Setup do banco de dados (create + migrate)
db-setup: db-create migrate-up
	@echo "✅ Banco de dados configurado!"

# Rodar migrações pendentes
db-migrate: migrate-up

# Rodar seeds (não implementado no core service)
db-seed:
	@echo "⚠️  Seeds não implementados no EvoAI Core Service"

# Resetar banco completo (drop + create + migrate)
db-reset: db-drop db-create migrate-up
	@echo "✅ Banco de dados resetado!"

# Tidy the dependencies
tidy:
	go mod tidy

# Clean up generated files and binaries
clean:
	rm -rf bin/

# =============================================================================
# COMANDOS DE MIGRAÇÃO (PADRÃO PADRONIZADO)
# =============================================================================

# Rodar migrações pendentes
migrate-up:
	@echo "🚀 Rodando migrações pendentes..."
	@echo "📋 Usando tabela de migrações customizada: evo_core_schema_community_migrations"
	migrate -database "$(DB_URL_WITH_CUSTOM_SCHEMA)" -path $(MIGRATIONS_DIR) up
	@echo "✅ Migrações aplicadas!"

# Reverter última migração
migrate-down:
	@echo "⬇️  Revertendo última migração..."
	migrate -database "$(DB_URL_WITH_CUSTOM_SCHEMA)" -path $(MIGRATIONS_DIR) down $(MIGRATION_COUNT)
	@echo "✅ Migração revertida!"

# Criar nova migração (uso: make migrate-create NAME=nome_da_migracao)
migrate-create:
	@if [ -z "$(NAME)" ]; then \
		echo "❌ NAME é obrigatório. Use: make migrate-create NAME=nome_da_migracao"; \
		exit 1; \
	fi
	@echo "📝 Criando nova migração: $(NAME)..."
	migrate create -ext sql -dir $(MIGRATIONS_DIR) -seq $(NAME)
	@echo "✅ Migração criada!"

# Run force migrations (migrate-force will migrate up to the last migration) (pass MIGRATION_COUNT=number: make migrate-force MIGRATION_COUNT=1)
migrate-force:
	@echo "Running EvoAI Core migrations..."
	@echo "🚀 Using custom migrations table: evo_core_schema_community_migrations"
	@if [ -z "$(MIGRATION_COUNT)" ]; then \
		echo "❌ MIGRATION_COUNT is required. Use: make migrate-force MIGRATION_COUNT=1"; \
		exit 1; \
	fi
	migrate -database "$(DB_URL_WITH_CUSTOM_SCHEMA)" -path $(MIGRATIONS_DIR) force $(MIGRATION_COUNT)
	@echo "✅ EvoAI migrations completed!"

# Database management commands
db-create:
	@echo "Checking database $(DB_NAME)..."
	@if [ "$(DB_NAME)" = "evolution_production" ] || [ "$(DB_NAME)" = "evolution_development" ]; then \
		echo "⚠️  Using Evolution database. Make sure Evolution is set up first!"; \
		psql "$(DB_URL)" -c "SELECT 1" >/dev/null 2>&1 && echo "✅ Database $(DB_NAME) is accessible" || echo "❌ Cannot access $(DB_NAME). Make sure Evolution database exists!"; \
	else \
		echo "Creating database $(DB_NAME)..."; \
		psql "$(DB_URL_ADMIN)" -c "CREATE DATABASE $(DB_NAME);" || echo "Database may already exist"; \
		echo "✅ Database $(DB_NAME) created or already exists"; \
	fi

db-drop:
	@echo "Dropping database $(DB_NAME)..."
	@echo "⚠️  This will permanently delete all data in $(DB_NAME)"
	@read -p "Are you sure? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	@psql "$(DB_URL_ADMIN)" -c "DROP DATABASE IF EXISTS $(DB_NAME);"
	@echo "✅ Database $(DB_NAME) dropped"

# Complete database reset (drop, create, migrate)
db-reset: db-drop db-create migrate-up
	@echo "✅ Database reset completed successfully!"

# Setup database from scratch
db-setup: db-create migrate-up
	@echo "✅ Database setup completed successfully!"

# =============================================================================
# COMANDOS ADICIONAIS
# =============================================================================


# Build the application
build:
	go build -o bin/app cmd/api/main.go

# Tidy the dependencies
tidy:
	go mod tidy

# Clean up generated files and binaries
clean:
	rm -rf bin/

# =============================================================================
# HELP
# =============================================================================

help: ## Mostrar ajuda com todos os comandos
	@echo "EvoAI Core Service - Makefile Commands"
	@echo ""
	@echo "🚀 Quick Start (PADRÃO PADRONIZADO):"
	@echo "  make setup          - Setup completo (install + db-setup)"
	@echo "  make dev            - Rodar em modo desenvolvimento"
	@echo "  make run            - Rodar em modo produção"
	@echo ""
	@echo "📦 Setup & Installation:"
	@echo "  make install        - Instalar dependências e ferramentas"
	@echo "  make setup          - Setup completo (install + db-setup)"
	@echo ""
	@echo "🗄️ Database Management (PADRÃO PADRONIZADO):"
	@echo "  make db-setup       - Setup inicial do banco (create + migrate)"
	@echo "  make db-migrate     - Rodar migrações pendentes"
	@echo "  make db-seed        - Rodar seeds (não implementado)"
	@echo "  make db-reset       - Resetar banco completo"
	@echo ""
	@echo "🔄 Migrations (PADRÃO PADRONIZADO):"
	@echo "  make migrate-up     - Rodar migrações pendentes"
	@echo "  make migrate-down   - Reverter última migração"
	@echo "  make migrate-create NAME=nome - Criar nova migração"
	@echo ""
	@echo "🛠️ Development:"
	@echo "  make build          - Build da aplicação"
	@echo "  make tidy           - Organizar módulos Go"
	@echo "  make clean          - Limpar arquivos gerados"
