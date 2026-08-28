.DEFAULT_GOAL := help

.PHONY: help up up-build down ps test integration-test check build images format FORCE

help:
	@echo "Janus repository commands"
	@echo "  make up                 Start backend and frontend in Docker"
	@echo "  make up-build           Build and start backend and frontend in Docker"
	@echo "  make down               Stop frontend and backend (data volumes stay intact)"
	@echo "  make ps                 Show backend and frontend Compose services"
	@echo "  make test               Run backend unit tests and frontend tests"
	@echo "  make integration-test   Run backend Docker-dependent integration tests"
	@echo "  make check              Run backend and frontend verification"
	@echo "  make build              Build backend and frontend"
	@echo "  make images             Build backend and frontend Docker images"
	@echo "  make format             Apply backend Kotlin formatting"
	@echo "  make backend-<target>    Delegate a target to backend/Makefile"
	@echo "  make frontend-<target>   Delegate a target to frontend/Makefile"

up:
	$(MAKE) -C backend up
	$(MAKE) -C frontend up

up-build:
	$(MAKE) -C backend up-build
	$(MAKE) -C frontend up-build

down:
	$(MAKE) -C frontend down
	$(MAKE) -C backend down

ps:
	$(MAKE) -C backend ps
	$(MAKE) -C frontend ps

test:
	$(MAKE) -C backend test
	$(MAKE) -C frontend test

integration-test:
	$(MAKE) -C backend integration-test

check:
	$(MAKE) -C backend check
	$(MAKE) -C frontend check

build:
	$(MAKE) -C backend build
	$(MAKE) -C frontend build

images:
	$(MAKE) -C backend image
	$(MAKE) -C frontend image

format:
	$(MAKE) -C backend format

backend-%: FORCE
	$(MAKE) -C backend $*

frontend-%: FORCE
	$(MAKE) -C frontend $*

FORCE:
