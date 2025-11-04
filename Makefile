.PHONY: help install-hooks pre-commit pre-commit-all lint-markdown clean

help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

install-hooks: ## Install git hooks for pre-commit
	@./.githooks/install.sh

pre-commit: ## Run pre-commit checks on staged files
	@./.githooks/run-pre-commit.sh

pre-commit-all: ## Run pre-commit checks on all files
	@./.githooks/run-pre-commit.sh --all-files

lint-markdown: ## Run markdownlint on all documentation files
	@echo "Running markdownlint on documentation..."
	@docker run --rm -v "$$(pwd):/src" -w /src \
		ghcr.io/igorshubovych/markdownlint-cli:latest \
		--fix README.md CONTRIBUTING.md \
		.github/AUTOMATION.md .github/INDEX.md \
		.github/workflows/README.md .githooks/README.md
	@echo "✓ Markdown linting complete"

clean: ## Clean up temporary files
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -delete
	@echo "✓ Cleaned up temporary files"

