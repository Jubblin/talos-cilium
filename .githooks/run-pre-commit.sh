#!/usr/bin/env bash
# Run pre-commit locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running pre-commit checks locally...${NC}"

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo -e "${RED}Error: pre-commit is not installed${NC}"
    echo "Please install pre-commit:"
    echo "  pip install pre-commit"
    echo "  or"
    echo "  brew install pre-commit"
    echo ""
    echo "Then run: make install-hooks"
    exit 1
fi

# Get the git root directory
GIT_ROOT=$(git rev-parse --show-toplevel)

# Change to git root directory
cd "$GIT_ROOT"

# Run pre-commit
pre-commit run --hook-stage pre-commit "$@"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All pre-commit checks passed${NC}"
else
    echo -e "${RED}✗ Pre-commit checks failed${NC}"
    echo "Please fix the issues above and try again"
fi

exit $EXIT_CODE
