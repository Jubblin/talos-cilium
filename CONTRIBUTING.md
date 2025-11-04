# Contributing to talos-cilium

Thank you for contributing to this project! This guide will help you get started.

## Prerequisites

- Docker installed and running
- Git

## Getting Started

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/talos-cilium.git
cd talos-cilium
```

### 2. Install pre-commit hooks

Run the installation script to set up containerized git hooks:

```bash
make install-hooks
# or
./.githooks/install.sh
```

This will automatically run quality checks before each commit.

### 3. Make your changes

Edit the files as needed. The following will be checked automatically:

- YAML files will be validated and formatted
- Markdown files will be linted
- Shell scripts will be checked with shellcheck
- The `versions` file format will be validated

## Making Commits

### Automatic checks (recommended)

Simply commit as usual:

```bash
git add .
git commit -m "feat: add new feature"
```

The pre-commit hooks will run automatically in a Docker container. If any issues are found, they will be auto-fixed when
possible, or you'll be prompted to fix them.

### Manual checks

Run checks before committing:

```bash
# Check all files
make pre-commit-all

# Check only staged files
make pre-commit

# Lint markdown documentation only
make lint-markdown
```

### Bypassing hooks (not recommended)

If you need to bypass the hooks:

```bash
git commit --no-verify -m "your message"
```

## Commit Message Convention

While not strictly enforced, we recommend following conventional commits:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `chore:` - Maintenance tasks
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests

Examples:

```bash
git commit -m "feat: add support for Cilium 1.18"
git commit -m "fix: correct YAML indentation in cluster-patch"
git commit -m "docs: update README with new examples"
git commit -m "chore: update Tetragon to 1.5.0"
```

## Updating Versions

The `versions` file contains the versions of Cilium and Tetragon:

```text
CILIUM_VERSION=1.17.6
TETRAGON_VERSION=1.4.1
```

**Automated Updates:**

- A GitHub Action runs daily to check for new releases
- When new versions are found, a PR is automatically created
- Review and merge the PR to update versions

**Manual Updates:**

1. Edit the `versions` file
2. Update the version numbers (format: `X.Y.Z`)
3. Commit the changes
4. The pre-commit hook will validate the format

## Testing Your Changes

### Test the pre-commit hooks

```bash
# Test on all files
./.githooks/run-pre-commit.sh --all-files

# Test on specific files
./.githooks/run-pre-commit.sh --files versions README.md
```

### Verify YAML files

```bash
# If you've made changes to YAML files, you can manually validate them
docker run --rm -v "$(pwd):/src" -w /src mkenney/pre-commit:latest run check-yaml --all-files
```

## Troubleshooting

### Docker issues

If you see Docker-related errors:

1. Make sure Docker Desktop is running
2. Verify Docker is accessible: `docker info`
3. Try pulling the pre-commit image manually:

   ```bash
   docker pull mkenney/pre-commit:latest
   ```

### Hook not running

If the hook doesn't run automatically:

1. Verify it's installed: `ls -la .git/hooks/pre-commit`
2. Check it's executable: `chmod +x .git/hooks/pre-commit`
3. Reinstall: `make install-hooks`

### Pre-commit errors

If pre-commit reports errors:

1. Read the error message carefully
2. Many issues are auto-fixed - just re-stage the files and commit again
3. For manual fixes, edit the files as indicated
4. Run `make pre-commit` to verify your fixes

## Project Structure

```text
talos-cilium/
├── .github/
│   └── workflows/          # GitHub Actions workflows
│       ├── update-versions.yml   # Auto-update versions
│       ├── cilium-helm.yml       # Generate Cilium templates
│       └── tetragon-helm.yml     # Generate Tetragon templates
├── .githooks/              # Git hooks (container-based)
│   ├── install.sh         # Hook installer
│   ├── run-pre-commit.sh  # Container runner
│   └── validate-versions.sh     # Version validator
├── templates/              # Generated Helm templates
│   ├── cilium/
│   │   ├── latest -> {VERSION}/  # Symlink to current version
│   │   └── {VERSION}/     # Versioned Cilium templates
│   └── tetragon/
│       ├── latest -> {VERSION}/  # Symlink to current version
│       └── {VERSION}/     # Versioned Tetragon templates
├── flux-controller/        # Flux controller configs
├── includes/              # Reusable YAML includes
├── *.yaml                 # Talos patches
├── versions               # Version tracking
└── README.md              # Main documentation
```

### Generated Templates

When workflows run, Helm templates are generated and organized in versioned directories with `latest` symlinks:

- `templates/cilium/{VERSION}/` - Contains all Cilium template variants for that version
- `templates/cilium/latest` - Symlink pointing to the current version
- `templates/tetragon/{VERSION}/` - Contains all Tetragon template variants for that version
- `templates/tetragon/latest` - Symlink pointing to the current version

**How `latest` symlinks work:**

- Workflows automatically update the `latest` symlink when generating new templates
- Talos patches reference `latest/` URLs for automatic version updates
- Specific versions remain accessible for pinning or rollback scenarios

This structure allows tracking templates across versions, automatic updates via symlinks, and easy comparison between releases.

## Need Help?

- Check the [README.md](README.md) for general information
- See [.githooks/README.md](.githooks/README.md) for hook details
- Review [.github/workflows/README.md](.github/workflows/README.md) for workflow setup
- Open an issue if you encounter problems

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b my-feature`
3. Make your changes
4. Ensure pre-commit checks pass
5. Commit with descriptive messages
6. Push to your fork
7. Open a pull request

Your PR will be reviewed, and feedback may be provided. Thank you for contributing!
