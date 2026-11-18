#!/usr/bin/env bash
# Offline tests for scripts/e2e-omni.sh using stub omnictl/kubectl that record every call.
# Proves --dry-run and --preflight only call read/validate subcommands and never write.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir "$T/bin"
REAL_KUBECTL=$(command -v kubectl)

cat > "$T/bin/omnictl" <<'STUB'
#!/bin/sh
echo "omnictl $*" >> "$STUB_CALLS"
case "$*" in
  "--version") echo "omnictl version stub" ;;
  "get cluster") exit 0 ;;
  "get cluster "*)
    if [ "${STUB_CLUSTER_EXISTS:-0}" = 1 ]; then echo "name: x"; exit 0; fi
    echo "resource not found" >&2; exit 1 ;;
  "get machineclass "*) [ "${STUB_NO_MC:-0}" = 1 ] && { echo "not found" >&2; exit 1; }; echo "metadata: {id: $3}" ;;
  "get talosversion"*)
    printf 'spec:\n  version: 1.11.2\n  compatible_kubernetes_versions: [1.33.0, 1.34.0, 1.34.1]\n---\nspec:\n  version: 1.10.0\n  compatible_kubernetes_versions: [1.32.0]\n' ;;
  "cluster template validate"*|"cluster template diff"*) ;;
  *) echo "unexpected omnictl call: $*" >&2; exit 99 ;;
esac
STUB
cat > "$T/bin/kubectl" <<STUB
#!/bin/sh
echo "kubectl \$*" >> "\$STUB_CALLS"
case "\$1" in kustomize|version) exec "$REAL_KUBECTL" "\$@" ;; esac
echo "unexpected kubectl call: \$*" >&2; exit 99
STUB
chmod +x "$T/bin/omnictl" "$T/bin/kubectl"

fails=0
has() { # has file pattern okmsg badmsg
  if grep -q -- "$2" "$1"; then ok "$3"; else bad "$4"; fi
}
lacks() { # lacks file pattern okmsg badmsg
  if grep -q -- "$2" "$1"; then bad "$4"; else ok "$3"; fi
}
ok() { echo "ok   - $1"; }
bad() { echo "FAIL - $1"; fails=$((fails + 1)); }
run() { # run name expected_rc args... (env supplied by caller)
  local name=$1 want=$2
  shift 2
  : > "$T/calls"
  set +e
  STUB_CALLS="$T/calls" PATH="$T/bin:$PATH" CLUSTER_NAME=e2e-test "$@" > "$T/out" 2>&1
  local rc=$?
  set -e
  if [ "$rc" = "$want" ]; then ok "$name (exit $rc)"; else bad "$name: exit $rc, wanted $want"; sed 's/^/    /' "$T/out"; fi
}
no_writes() {
  if grep -Eq 'omnictl (cluster template (sync|delete)|cluster delete|kubeconfig|apply|delete|edit)|kubectl (apply|create|delete|get|wait|run|rollout)' "$T/calls"; then
    bad "$1: a write/cluster call was made"; cat "$T/calls"
  else ok "$1: no write or cluster calls"; fi
}
only_reads() {
  if grep -vE '^omnictl (--version|get |cluster template (validate|diff) )|^kubectl (kustomize|version)' "$T/calls" | grep -q .; then
    bad "$1: non-read call recorded"; cat "$T/calls"
  else ok "$1: only read/validate calls"; fi
}
S="$ROOT/scripts/e2e-omni.sh"

run "dry-run with credentials" 0 env OMNI_SERVICE_ACCOUNT_KEY=dummy "$S" --dry-run
no_writes dry-run; only_reads dry-run
has "$T/calls" "omnictl get machineclass proxmox-small" "dry-run read machine class" "dry-run read machine class missing"
has "$T/calls" "cluster template diff" "dry-run ran template diff" "dry-run did not run template diff"
has "$T/out" "talos v1.11.2, kubernetes v1.34.1" "dry-run resolved versions" "dry-run did not resolve versions"
lacks "$T/out" dummy "key not in output" "key leaked to output"

run "dry-run without credentials" 0 env -u OMNI_SERVICE_ACCOUNT_KEY "$S" --dry-run
only_reads "dry-run offline"; no_writes "dry-run offline"
has "$T/out" "^SKIPPED" "offline Omni reads SKIPPED" "offline Omni reads not SKIPPED"

run "dry-run, cluster exists" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_CLUSTER_EXISTS=1 "$S" --dry-run
no_writes "dry-run exists"
run "dry-run, machine class missing" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_NO_MC=1 "$S" --dry-run

run "preflight with credentials" 0 env OMNI_SERVICE_ACCOUNT_KEY=dummy "$S" --preflight
only_reads preflight; no_writes preflight
lacks "$T/calls" "template validate" "preflight: no template validation" "preflight validated a template"
lacks "$T/calls" kubectl "preflight: no repo renders" "preflight ran kubectl"
run "preflight --dry-run equals preflight" 0 env OMNI_SERVICE_ACCOUNT_KEY=dummy "$S" --preflight --dry-run
run "preflight without credentials fails fast" 1 env -u OMNI_SERVICE_ACCOUNT_KEY "$S" --preflight
if [ -s "$T/calls" ]; then bad "preflight without credentials made calls"; else ok "preflight without credentials made no calls"; fi
run "preflight, cluster exists" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_CLUSTER_EXISTS=1 "$S" --preflight
run "real run without credentials fails fast" 1 env -u OMNI_SERVICE_ACCOUNT_KEY "$S"
run "real run refuses existing cluster before any write" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_CLUSTER_EXISTS=1 "$S"
no_writes "real run refusal"

if [ "$fails" -ne 0 ]; then echo "$fails test(s) failed"; exit 1; fi
echo "all tests passed"
