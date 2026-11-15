.PHONY: setup setup-backend setup-flutter test test-backend test-flutter lint lint-backend lint-flutter format format-backend format-flutter dev-backend dev-flutter docker-up docker-down clean help

# =============================================================================
# Stemly — Developer Commands
# =============================================================================
# Run `make help` to see all available commands.
# On Windows, use Git Bash or WSL to run make.

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------

setup: setup-backend setup-flutter ## Install all dependencies

setup-backend: ## Install backend dependencies
	cd backend && uv sync --extra dev
	@test -f backend/.env || (cp backend/.env.example backend/.env && echo "Created backend/.env — fill in your values")

setup-flutter: ## Install Flutter dependencies
	cd stemly_app && flutter pub get

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------

test: test-backend test-flutter ## Run all tests

test-backend: ## Run backend tests with coverage
	cd backend && uv run pytest -v --cov=. --cov-report=term-missing

test-flutter: ## Run Flutter tests
	cd stemly_app && flutter test

# -----------------------------------------------------------------------------
# Linting
# -----------------------------------------------------------------------------

lint: lint-backend lint-flutter ## Run all linters

lint-backend: ## Lint backend (black + flake8)
	cd backend && uv run black --check .
	cd backend && uv run flake8 . --max-line-length=120 --count --statistics

lint-flutter: ## Lint Flutter (analyze + format check)
	cd stemly_app && flutter analyze --no-fatal-infos
	cd stemly_app && dart format --set-exit-if-changed .

# -----------------------------------------------------------------------------
# Formatting
# -----------------------------------------------------------------------------

format: format-backend format-flutter ## Auto-format all code

format-backend: ## Format backend with black
	cd backend && uv run black .

format-flutter: ## Format Flutter with dart format
	cd stemly_app && dart format .

# -----------------------------------------------------------------------------
# Development Servers
# -----------------------------------------------------------------------------

dev-backend: ## Start backend with auto-reload
	cd backend && uv run uvicorn main:app --host 0.0.0.0 --port 8080 --reload

dev-flutter: ## Run Flutter app in debug mode
	cd stemly_app && flutter run

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------

docker-up: ## Start MongoDB + backend via Docker Compose
	docker compose up -d

docker-down: ## Stop Docker services
	docker compose down

docker-logs: ## Tail Docker service logs
	docker compose logs -f

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

clean: ## Clean build artifacts
	cd stemly_app && flutter clean
	find backend -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	rm -rf backend/.pytest_cache backend/.mypy_cache
