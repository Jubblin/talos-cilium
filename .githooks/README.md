# Git Hooks

This directory contains git hooks that run pre-commit checks using Docker containers.

## Setup

### Quick Start

Run the installation script to set up the git hooks:

```bash
./.githooks/install.sh
```

This will:

- Install the pre-commit hook in `.git/hooks/`
- Make all necessary scripts executable
- Configure git to use these hooks

### Requirements

- **Docker**: The pre-commit hooks run in containers
  - Make sure Docker is installed and running
  - The hook will check and warn if Docker is not available

### What Gets Checked

The pre-commit hook will automatically run these checks:

1. **YAML Validation**
   - Trailing whitespace
   - End of file fixers
   - YAML syntax validation
   - YAML formatting (yamlfmt)

2. **Markdown Linting**
   - Markdown formatting and style checks
   - Auto-fixing enabled

3. **Shell Script Linting**
   - ShellCheck for bash/sh scripts

4. **Custom Validations**
   - Versions file format validation
   - Ensures `CILIUM_VERSION` and `TETRAGON_VERSION` are properly formatted

## Usage

### Automatic (Recommended)

Once installed, the hooks run automatically on every commit:

```bash
git add .
git commit -m "your commit message"
# Hooks run automatically here
```

### Manual

Run checks manually on all files:

```bash
./.githooks/run-pre-commit.sh --all-files
```

Run checks on specific files:

```bash
./.githooks/run-pre-commit.sh --files file1.yaml file2.yaml
```

### Bypassing Hooks

If you need to bypass the hooks (not recommended):

```bash
git commit --no-verify -m "your commit message"
```

## How It Works

1. **Container-Based**: All checks run inside Docker containers
   - No need to install pre-commit or its dependencies locally
   - Consistent environment across all developers
   - Uses the `mkenney/pre-commit:latest` Docker image

2. **Pre-Commit Configuration**: `.pre-commit-config.yaml` defines all checks
   - You can customize which checks to run
   - Add or remove hooks as needed

3. **Git Hook**: `.git/hooks/pre-commit` calls `run-pre-commit.sh`
   - Runs the container with mounted repository
   - Preserves user permissions

## Troubleshooting

### Docker Not Running

If you see an error about Docker not running:

```bash
# Start Docker Desktop (macOS)
open -a Docker

# Or start Docker daemon (Linux)
sudo systemctl start docker
```

### Permission Issues

If you encounter permission issues:

```bash
# Make scripts executable
chmod +x .githooks/*.sh
```

### Skipping Specific Hooks

To skip specific hooks, set the `SKIP` environment variable:

```bash
SKIP=yamlfmt git commit -m "skip yamlfmt"
```

### Updating Hooks

To update the pre-commit hooks configuration:

1. Edit `.pre-commit-config.yaml`
2. Re-run the checks to test: `./.githooks/run-pre-commit.sh --all-files`

## Files

- `install.sh` - Installs the git hooks
- `run-pre-commit.sh` - Runs pre-commit in a Docker container
- `validate-versions.sh` - Custom validator for the versions file
- `README.md` - This file

## Configuration Files

- `.pre-commit-config.yaml` - Pre-commit hooks configuration
- `.markdownlint.yaml` - Markdown linting rules
- `.yamlfmt` - YAML formatting rules
