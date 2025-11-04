# Git Hooks

This directory contains git hooks that run pre-commit checks locally.

## Setup

### Quick Start

#### Step 1: Install pre-commit (first time only)

```bash
# Using pip
pip install pre-commit

# Or using Homebrew (macOS)
brew install pre-commit
```

#### Step 2: Install the git hooks

```bash
make install-hooks
# or
./.githooks/install.sh
```

This will:

- Install the pre-commit hook in `.git/hooks/`
- Make all necessary scripts executable
- Configure git to use these hooks
- Install all hook dependencies defined in `.pre-commit-config.yaml`

### Requirements

- **pre-commit**: The pre-commit tool must be installed locally
  - Install via pip: `pip install pre-commit`
  - Or via Homebrew: `brew install pre-commit`
  - The hook will check and warn if pre-commit is not available
- **Python**: Required for pre-commit (Python 3.7+)
- **Dependencies**: Pre-commit will automatically install hook dependencies
  (yamlfmt, markdownlint, shellcheck, etc.) on first run

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

1. **Local Execution**: All checks run locally using pre-commit
   - Pre-commit manages hook dependencies automatically
   - Each hook runs in its own isolated environment (virtual environments for Python hooks)
   - Dependencies are cached and reused across runs
   - Hooks are defined in `.pre-commit-config.yaml`

2. **Pre-Commit Configuration**: `.pre-commit-config.yaml` defines all checks
   - You can customize which checks to run
   - Add or remove hooks as needed
   - Pre-commit downloads and installs hook dependencies on first run

3. **Git Hook**: `.git/hooks/pre-commit` calls `run-pre-commit.sh`
   - Script checks for pre-commit installation
   - Runs pre-commit with the configured hooks
   - Automatically installs hooks if not already installed

## Troubleshooting

### Pre-commit Not Installed

If you see an error about pre-commit not being installed:

```bash
# Install using pip
pip install pre-commit

# Or using Homebrew (macOS)
brew install pre-commit

# Then re-run the install script
make install-hooks
```

### Hook Dependencies Not Installed

If hooks fail due to missing dependencies, pre-commit will automatically install
them on first run. You can also manually install them:

```bash
# Install all hook dependencies
pre-commit install-hooks
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

- `install.sh` - Installs the git hooks using pre-commit
- `run-pre-commit.sh` - Runs pre-commit locally
- `validate-versions.sh` - Custom validator for the versions file
- `build-precommit-image.sh` - Builds Docker image (optional, for CI/CD)
- `README.md` - This file

## Configuration Files

- `.pre-commit-config.yaml` - Pre-commit hooks configuration
- `.markdownlint.yaml` - Markdown linting rules
- `.yamlfmt` - YAML formatting rules
