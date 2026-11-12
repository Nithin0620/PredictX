.PHONY: help install dev build test lint typecheck format format-check clean \
	chain chain-fork deploy-local contracts-deps contracts-test indexer-dev

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

install: ## Install all workspace dependencies
	pnpm install

dev: ## Run all dev servers (turbo)
	pnpm dev

build: ## Build all packages
	pnpm build

test: ## Run all tests
	pnpm test

lint: ## Lint the workspace
	pnpm lint

typecheck: ## Type-check all packages
	pnpm typecheck

format: ## Format with Prettier
	pnpm format

format-check: ## Check formatting without writing
	pnpm format:check

clean: ## Remove build artifacts
	pnpm clean

# --- Contracts / chain ------------------------------------------------------
chain: ## Start a local Anvil chain (deterministic accounts, chain id 31337)
	anvil --chain-id 31337

chain-fork: ## Fork Base Sepolia locally (requires BASE_SEPOLIA_RPC_URL)
	anvil --chain-id 31337 --fork-url $${BASE_SEPOLIA_RPC_URL}

deploy-local: ## Deploy the placeholder contract to local Anvil
	pnpm --filter @predictx/contracts deploy:local

contracts-deps: ## Install pinned Foundry deps into packages/contracts/lib
	forge install --root packages/contracts foundry-rs/forge-std@v1.17.0 --no-git --shallow
	forge install --root packages/contracts OpenZeppelin/openzeppelin-contracts@v5.7.0 --no-git --shallow

contracts-test: ## Run contract tests with the heavier CI profile
	pnpm --filter @predictx/contracts test:ci

indexer-dev: ## Run the blockchain indexer in watch mode (Phase 15)
	@echo "Phase 15: add indexer dev command here"
