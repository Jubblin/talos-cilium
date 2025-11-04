#!/usr/bin/env bash
# Build the pre-commit Docker image

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

IMAGE_NAME="talos-cilium/pre-commit"
IMAGE_TAG="latest"

echo -e "${YELLOW}Building pre-commit Docker image...${NC}"

cd "$PROJECT_ROOT"

docker build \
    -f Dockerfile.precommit \
    -t "$IMAGE_NAME:$IMAGE_TAG" \
    .

echo -e "${GREEN}✓ Successfully built $IMAGE_NAME:$IMAGE_TAG${NC}"
echo ""
echo "To use this image, update .githooks/run-pre-commit.sh:"
echo "  PRECOMMIT_IMAGE=\"$IMAGE_NAME:$IMAGE_TAG\""
