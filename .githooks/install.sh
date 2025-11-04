#!/usr/bin/env bash
# Install git hooks to use pre-commit locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing git hooks...${NC}"

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo -e "${RED}Error: pre-commit is not installed${NC}"
    echo "Please install pre-commit first:"
    echo "  pip install pre-commit"
    echo "  or"
    echo "  brew install pre-commit"
    exit 1
fi

# Get the git root directory
GIT_ROOT=$(git rev-parse --show-toplevel)
HOOKS_DIR="$GIT_ROOT/.git/hooks"

# Change to git root directory
cd "$GIT_ROOT"

# Make sure hooks directory exists
mkdir -p "$HOOKS_DIR"

# Make scripts executable
chmod +x "$GIT_ROOT/.githooks/run-pre-commit.sh"
chmod +x "$GIT_ROOT/.githooks/validate-versions.sh"

# Create pre-commit hook that calls our wrapper script
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/usr/bin/env bash
# Git pre-commit hook that runs pre-commit locally

set -e

# Get the git root directory
GIT_ROOT=$(git rev-parse --show-toplevel)

# Run the local pre-commit script
exec "$GIT_ROOT/.githooks/run-pre-commit.sh"
EOF

# Make the hook executable
chmod +x "$HOOKS_DIR/pre-commit"

# Install pre-commit hook dependencies (this downloads hook repos and tools)
pre-commit install-hooks

echo -e "${GREEN}✓ Git hooks installed successfully${NC}"
echo ""
echo "The pre-commit hook will now run automatically before each commit."
echo "It will execute pre-commit checks locally using the installed pre-commit tool."
echo ""
echo "To bypass the hooks (not recommended), use: git commit --no-verify"
echo "To run checks manually: .githooks/run-pre-commit.sh --all-files"
