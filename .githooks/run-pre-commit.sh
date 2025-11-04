#!/usr/bin/env bash
# Run pre-commit from a container

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Docker image to use for pre-commit
PRECOMMIT_IMAGE="mkenney/pre-commit:latest"

echo -e "${YELLOW}Running pre-commit checks in container...${NC}"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    echo "Please install Docker to use container-based pre-commit hooks"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    echo "Please start Docker and try again"
    exit 1
fi

# Get the git root directory
GIT_ROOT=$(git rev-parse --show-toplevel)

# Run pre-commit in container
docker run --rm \
    -v "$GIT_ROOT:/src" \
    -w /src \
    --user "$(id -u):$(id -g)" \
    "$PRECOMMIT_IMAGE" \
    run --hook-stage pre-commit "$@"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ All pre-commit checks passed${NC}"
else
    echo -e "${RED}✗ Pre-commit checks failed${NC}"
    echo "Please fix the issues above and try again"
fi

exit $EXIT_CODE

