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
if [ "${STUB_OMNI_ERROR:-0}" = 1 ]; then
  echo "rpc error: code = Unavailable desc = connection refused (key ${OMNI_SERVICE_ACCOUNT_KEY:-})" >&2
  exit 1
fi
case "$*" in
  "--version") echo "omnictl version stub" ;;
  "get cluster -o yaml")
    if [ "${STUB_BIG:-0}" = 1 ]; then
      i=0; while [ "$i" -lt 3000 ]; do printf -- '---\nmetadata:\n  id: other-cluster-%s\n  namespace: default\n  labels: {a: b}\n' "$i"; i=$((i + 1)); done
    fi
    printf -- '---\nmetadata:\n  id: other-cluster\n'
    if [ "${STUB_CLUSTER_EXISTS:-0}" = 1 ]; then printf -- '---\nmetadata:\n  id: e2e-test\n'; fi ;;
  "get machineclass "*) if [ "${STUB_NO_MC:-0}" = 1 ]; then echo "not found" >&2; exit 1; fi; echo "metadata: {id: $3}" ;;
  "get talosversion -o yaml"|"get talosversions -o yaml")
    case "${STUB_TALOS:-ok}" in
      ok) printf 'metadata:\n  id: 1.14.6\nspec:\n  version: 1.14.6\n  compatible_kubernetes_versions: [1.35.2, 1.36.2, v1.36.6, 1.37.2]\n---\nmetadata:\n  id: 1.11.2\nspec:\n  version: 1.11.2\n  compatible_kubernetes_versions: [1.33.0, 1.34.1]\n' ;;
      no136) printf 'spec:\n  version: 1.14.6\n  compatible_kubernetes_versions: [1.35.0, 1.37.2]\n' ;;
      camel) printf 'spec:\n  version: v1.14.6\n  compatibleKubernetesVersions: [1.36.3]\n' ;;
      unknown) printf 'spec:\n  something: else\n' ;;
      bigunknown) i=0; while [ "$i" -lt 400 ]; do printf -- '---\nspec:\n  something: else-%s\n  more: [a, b, c, d, e, f, g, h]\n' "$i"; i=$((i + 1)); done ;;
      big) i=0; while [ "$i" -lt 400 ]; do printf -- '---\nspec:\n  version: 1.%s.0\n  compatible_kubernetes_versions: [1.30.0, 1.31.0, 1.32.0]\n' "$i"; i=$((i + 1)); done
           printf -- '---\nspec:\n  version: 1.14.6\n  compatible_kubernetes_versions: [1.35.2, 1.36.6]\n' ;;
    esac ;;
  "get kubernetesversion -o yaml") printf 'spec:\n  version: 1.33.4\n' ;;
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
has "$T/out" "Talos v1.14.6 with Kubernetes v1.36.6 offered" "dry-run resolved latest 1.36.x" "dry-run did not validate default versions"
lacks "$T/out" dummy "key not in output" "key leaked to output"

run "dry-run without credentials" 0 env -u OMNI_SERVICE_ACCOUNT_KEY "$S" --dry-run
only_reads "dry-run offline"; no_writes "dry-run offline"
has "$T/out" "^SKIPPED" "offline Omni reads SKIPPED" "offline Omni reads not SKIPPED"

run "dry-run, cluster exists" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_CLUSTER_EXISTS=1 "$S" --dry-run
no_writes "dry-run exists"
run "dry-run, machine class missing" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_NO_MC=1 "$S" --dry-run

run "dry-run, other omnictl error shows real message" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_OMNI_ERROR=1 "$S" --dry-run
has "$T/out" "Unavailable desc = connection refused" "other error: actual omnictl message shown" "other error: message not shown"
lacks "$T/out" "cannot tell" "other error: no vague message" "other error: vague message"
lacks "$T/out" "key dummy" "other error: key redacted" "other error: key leaked"
run "dry-run, no K8s 1.36.x offered fails clearly" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_TALOS=no136 "$S" --dry-run
has "$T/out" "Omni offers no Kubernetes 1.36.x for Talos v1.14.6" "not offered: clear message" "not offered: unclear message"
has "$T/out" "1.14.6: 1.35.0 1.37.2" "not offered: offered versions listed" "not offered: offered versions not listed"
run "dry-run, unknown resource fields dump raw" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_TALOS=unknown "$S" --dry-run
has "$T/out" "something: else" "unknown fields: raw resource printed" "unknown fields: raw not printed"
run "dry-run, camelCase fields and v prefix" 0 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_TALOS=camel "$S" --dry-run
has "$T/out" "Talos v1.14.6 with Kubernetes v1.36.3 offered" "camelCase validated" "camelCase not validated"
run "TALOS_VERSION override not offered fails" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy TALOS_VERSION=9.9.9 "$S" --dry-run
run "K8S_VERSION not offered for Talos is rejected (no fallback)" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy K8S_VERSION=1.33.0 "$S" --dry-run
run "valid overrides accepted" 0 env OMNI_SERVICE_ACCOUNT_KEY=dummy TALOS_VERSION=1.11.2 K8S_VERSION=1.34.1 "$S" --dry-run
has "$T/out" "Talos v1.11.2 with Kubernetes v1.34.1 offered" "override honoured" "override ignored"
run "preflight, no 1.36.x offered" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_TALOS=no136 "$S" --preflight
has "$T/out" "^FAIL" "preflight shows FAIL line" "preflight no FAIL line"

# SIGPIPE regressions: huge multi-document output from omnictl must never end the script silently.
run "preflight with huge cluster list" 0 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_BIG=1 "$S" --preflight
has "$T/out" "^PASS .*cluster e2e-test does not exist" "huge list: results printed" "huge list: results missing"
run "preflight with huge talosversion list" 0 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_TALOS=big "$S" --preflight
has "$T/out" "Talos v1.14.6 with Kubernetes v1.36.6 offered" "huge talosversion: resolved" "huge talosversion: not resolved"
run "preflight with huge unknown-field resource exits 1 with output" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_TALOS=bigunknown "$S" --preflight
has "$T/out" "unknown resource fields" "huge unknown: FAIL line printed" "huge unknown: FAIL line missing"
has "$T/out" "failed" "huge unknown: summary printed" "huge unknown: summary missing"
lacks "$T/out" "step .* failed (exit" "huge unknown: no unexpected trap error" "huge unknown: script died unexpectedly"
run "dry-run with huge unknown-field resource exits 1 with output" 1 env OMNI_SERVICE_ACCOUNT_KEY=dummy STUB_TALOS=bigunknown "$S" --dry-run
has "$T/out" "unknown resource fields" "huge unknown dry-run: FAIL line printed" "huge unknown dry-run: FAIL line missing"

# A genuinely unexpected failure (here: the render inputs are missing, so `cp -R` fails) is never silent.
mkdir -p "$T/broken/scripts"
cp "$ROOT/scripts/e2e-omni.sh" "$T/broken/scripts/"
run "unexpected failure prints step name" 1 env -u OMNI_SERVICE_ACCOUNT_KEY "$T/broken/scripts/e2e-omni.sh" --dry-run
has "$T/out" 'ERROR: step "repo consistency' "crash: error line with step name" "crash: silent exit"

run "--debug prints step markers, no key" 0 env OMNI_SERVICE_ACCOUNT_KEY=dummy "$S" --preflight --debug
has "$T/out" "\[debug\] step: Omni reads" "debug: step markers" "debug: no step markers"
has "$T/out" "\[debug\] omnictl get exit 0" "debug: omnictl exit codes" "debug: no exit codes"
lacks "$T/out" "dummy" "debug: key not printed" "debug: key leaked"

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
