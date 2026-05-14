.PHONY: dev infra migrate-up migrate-down run test build clean

# Clean all 3 projects (backend, frontend, alexa-skill)
clean:
	@echo "Cleaning backend..."
	cd backend && rm -rf bin/ tmp/ vendor/
	@echo "Cleaning frontend..."
	cd frontend && fvm flutter clean 2>/dev/null || rm -rf build/ .dart_tool/ .flutter-plugins .flutter-plugins-dependencies
	@echo "Cleaning alexa-skill..."
	cd alexa-skill && rm -rf node_modules/ lambda/node_modules/ .build/
	@echo "All clean!"

# Start infrastructure (Postgres, Redis, Adminer)
infra:
	docker-compose up -d

infra-down:
	docker-compose down

# Run backend
run:
	cd backend && go run ./cmd/server

# Run with hot reload (requires air: go install github.com/air-verse/air@latest)
dev:
	cd backend && air

# Database migrations
migrate-up:
	cd backend && go run ./cmd/migrate up

migrate-down:
	cd backend && go run ./cmd/migrate down

# Tests
test:
	cd backend && go test ./...

# Build
build:
	cd backend && go build -o bin/server ./cmd/server

# Flutter
flutter-run:
	cd frontend && flutter run

flutter-build-apk:
	cd frontend && flutter build apk

flutter-build-ios:
	cd frontend && flutter build ios
