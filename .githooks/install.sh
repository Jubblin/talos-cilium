#!/usr/bin/env bash
# Install git hooks to use pre-commit from container

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing git hooks...${NC}"

# Get the git root directory
GIT_ROOT=$(git rev-parse --show-toplevel)
HOOKS_DIR="$GIT_ROOT/.git/hooks"

# Make sure hooks directory exists
mkdir -p "$HOOKS_DIR"

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/usr/bin/env bash
# Git pre-commit hook that runs pre-commit from container

set -e

# Get the git root directory
GIT_ROOT=$(git rev-parse --show-toplevel)

# Run the containerized pre-commit script
exec "$GIT_ROOT/.githooks/run-pre-commit.sh"
EOF

# Make hooks executable
chmod +x "$HOOKS_DIR/pre-commit"
chmod +x "$GIT_ROOT/.githooks/run-pre-commit.sh"
chmod +x "$GIT_ROOT/.githooks/validate-versions.sh"

echo -e "${GREEN}✓ Git hooks installed successfully${NC}"
echo ""
echo "The pre-commit hook will now run automatically before each commit."
echo "It will execute pre-commit checks in a Docker container."
echo ""
echo "To bypass the hooks (not recommended), use: git commit --no-verify"
echo "To run checks manually: .githooks/run-pre-commit.sh --all-files"

