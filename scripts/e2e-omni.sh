#!/usr/bin/env bash
# E2E test: create a disposable Omni cluster from patches/pinode.yaml on Proxmox
# machine classes, run health checks, print a summary path, tear the cluster down.
# Run locally (not CI). Requires: omnictl, kubectl, yq, make.
#
# Usage: OMNI_SERVICE_ACCOUNT_KEY=... scripts/e2e-omni.sh [--dry-run | --preflight]
#   (none)       real run: creates and tears down a cluster
#   --dry-run    everything read-only: repo checks, template render + offline validate and, if
#                OMNI_SERVICE_ACCOUNT_KEY is set, Omni reads. Never creates/changes/deletes anything.
#   --preflight  ONLY the Omni reads (needs OMNI_SERVICE_ACCOUNT_KEY); implies read-only.
# Env: OMNI_ENDPOINT CLUSTER_NAME MACHINE_CLASS_CP MACHINE_CLASS_WORKER WORKER_COUNT
#      TALOS_VERSION K8S_VERSION KEEP_CLUSTER
#
# omnictl commands/flags were checked against `omnictl --help` (v1.13.2).
# UNVERIFIED (no Omni access when written; marked "UNVERIFIED" inline):
#   - wording/exit code of `omnictl get cluster <name>` when the cluster is absent
#   - TalosVersion resource name and its compatible_kubernetes_versions field
#   - MachineClass resource name for `omnictl get machineclass`
#   - `omnictl cluster template diff` is treated as read-only: its --help only says it
#     queries and compares resources; it was not run against Omni.
# Read-only omnictl subcommands used before a real run: get, cluster template validate|diff, --version.
set -euo pipefail

DRY_RUN=0
PREFLIGHT=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --preflight) PREFLIGHT=1; DRY_RUN=1 ;; # --preflight --dry-run == --preflight
    *) echo "usage: $0 [--dry-run | --preflight]" >&2; exit 2 ;;
  esac
done

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export OMNI_ENDPOINT="${OMNI_ENDPOINT:-https://omni.ad.bonkie.net}"
CLUSTER_NAME="${CLUSTER_NAME:-e2e-talos-cilium-$(date +%Y%m%d%H%M%S)}"
MACHINE_CLASS_CP="${MACHINE_CLASS_CP:-proxmox-small}"
MACHINE_CLASS_WORKER="${MACHINE_CLASS_WORKER:-proxmox-medium}"
WORKER_COUNT="${WORKER_COUNT:-0}"
TALOS_VERSION="${TALOS_VERSION:-v1.14.6}"
K8S_VERSION="${K8S_VERSION:-}" # default: latest ${K8S_MINOR}.x that Omni offers for TALOS_VERSION
K8S_MINOR=1.36
KEEP_CLUSTER="${KEEP_CLUSTER:-0}"
CP_COUNT=3 # machine-set size lives only in the template; the repo preflight needs no count

die() { echo "ERROR: $*" >&2; exit 1; }

HAVE_CREDS=0
if [ -n "${OMNI_SERVICE_ACCOUNT_KEY:-}" ]; then
  HAVE_CREDS=1
  export OMNI_SERVICE_ACCOUNT_KEY
fi
if [ "$HAVE_CREDS" = 0 ] && { [ "$DRY_RUN" = 0 ] || [ "$PREFLIGHT" = 1 ]; }; then
  die "OMNI_SERVICE_ACCOUNT_KEY must be set in the environment"
fi

# Step table. Statuses: DONE (executed, ok), FAIL (executed, failed), SKIPPED, WOULD-RUN.
STEPS=()
fail_count=0
step() { # step STATUS name [detail]
  STEPS+=("$1|$2|${3:-}")
  [ "$1" != FAIL ] || fail_count=$((fail_count + 1))
}
print_steps() {
  local row status name detail
  for row in "${STEPS[@]}"; do
    IFS='|' read -r status name detail <<<"$row"
    if [ "$PREFLIGHT" = 1 ]; then
      [ "$status" = DONE ] && status=PASS
      printf '%-5s %s%s\n' "$status" "$name" "${detail:+ ($detail)}"
    else
      printf '%-12s %s%s\n' "$status" "$name" "${detail:+ ($detail)}"
    fi
  done
}
finish_if_failed() {
  if [ "$fail_count" -gt 0 ]; then
    echo
    print_steps
    cat "$OUT/details.txt"
    echo "$fail_count check(s) failed" >&2
    exit 1
  fi
}

# WORK holds the template, repo copy and kubeconfig and is always removed.
# OUT holds only the summary (no secrets) and is kept so its path can be printed.
WORK=$(mktemp -d)
OUT=$(mktemp -d)
chmod 700 "$WORK"
: > "$OUT/details.txt"
created=0
cleanup() {
  local rc=$?
  if [ "$created" = 1 ] && [[ "$CLUSTER_NAME" == e2e-* ]] && [ "$KEEP_CLUSTER" != 1 ]; then
    echo "Tearing down $CLUSTER_NAME..."
    omnictl cluster delete "$CLUSTER_NAME" || echo "WARNING: teardown failed; delete $CLUSTER_NAME manually in Omni" >&2
  elif [ "$created" = 1 ]; then
    echo "KEEP_CLUSTER=1: leaving $CLUSTER_NAME in place"
  fi
  rm -rf "$WORK"
  return $rc
}
trap 'rm -rf "$WORK"' EXIT # replaced by cleanup only after the cluster is created (real run)

check_inputs() {
  [[ "$CLUSTER_NAME" =~ ^e2e-[a-z0-9-]+$ ]] || die "CLUSTER_NAME must match ^e2e-[a-z0-9-]+\$"
  [[ "$WORKER_COUNT" =~ ^[0-9]+$ ]] || die "WORKER_COUNT must be a number"
  [[ "$MACHINE_CLASS_CP" =~ ^[a-z0-9-]+$ ]] || die "MACHINE_CLASS_CP must match ^[a-z0-9-]+\$"
  [[ "$MACHINE_CLASS_WORKER" =~ ^[a-z0-9-]+$ ]] || die "MACHINE_CLASS_WORKER must match ^[a-z0-9-]+\$"
  [[ "${TALOS_VERSION#v}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "TALOS_VERSION must look like v1.14.6"
  [ -z "$K8S_VERSION" ] || [[ "${K8S_VERSION#v}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "K8S_VERSION must look like v1.36.6"
  step DONE "input validation"
}

check_tools() {
  local t v
  for t in omnictl kubectl yq make; do
    if ! command -v "$t" >/dev/null 2>&1; then
      step FAIL "tool $t" "not installed"
      continue
    fi
    case "$t" in
      omnictl) v=$(omnictl --version 2>&1 | head -n1) || v=unknown ;;
      kubectl) v=$(kubectl version --client 2>&1 | head -n1) || v=unknown ;;
      yq) v=$(yq --version 2>&1 | head -n1) || v=unknown ;;
      *) v=$(make --version 2>&1 | head -n1) || v=unknown ;;
    esac
    step DONE "tool $t" "$v"
  done
}

# Copy the render inputs to a temp dir so the working tree is never touched.
check_repo() {
  local r="$WORK/repo"
  mkdir -p "$r"
  cp -R "$REPO_ROOT/cilium" "$REPO_ROOT/flux-operator" "$REPO_ROOT/patches" "$REPO_ROOT/Makefile" "$r/"
  if (cd "$r" && make render-pinode >/dev/null 2>&1) && diff -q "$r/patches/pinode.yaml" "$REPO_ROOT/patches/pinode.yaml" >/dev/null; then
    step DONE "patches/pinode.yaml matches make render-pinode"
  else
    step FAIL "patches/pinode.yaml matches make render-pinode" "run make render-pinode and commit"
  fi
  local d
  for d in cilium flux-operator; do
    if kubectl kustomize "$REPO_ROOT/$d" >/dev/null 2>&1; then step DONE "kubectl kustomize $d"; else step FAIL "kubectl kustomize $d"; fi
  done
}

# Replace the service-account key in text before showing omnictl output.
redact() {
  local t
  t=$(cat)
  if [ -n "${OMNI_SERVICE_ACCOUNT_KEY:-}" ]; then t=${t//"$OMNI_SERVICE_ACCOUNT_KEY"/[REDACTED]}; fi
  printf '%s\n' "$t"
}

# One line per Talos version Omni offers: "<talos>|<k8s> <k8s> ..." (leading v stripped).
# Tolerates snake_case and camelCase field names and a missing spec.version (falls back to the id).
offered_table() { # offered_table <omnictl yaml>
  printf '%s\n' "$1" | yq -r '
    ((.spec.version // .metadata.id) | sub("^v"; "")) + "|" +
    (((.spec.compatible_kubernetes_versions // .spec.compatibleKubernetesVersions // []) | map(sub("^v"; ""))) | join(" "))'
}

# True if the offered table lists TALOS_VERSION with K8S_VERSION.
pair_offered() { # pair_offered <table>
  local t ks v
  while IFS='|' read -r t ks; do
    [ "$t" = "${TALOS_VERSION#v}" ] || continue
    for v in $ks; do
      [ "$v" != "${K8S_VERSION#v}" ] || return 0
    done
  done <<<"$1"
  return 1
}

# Highest ${K8S_MINOR}.x offered for TALOS_VERSION; prints nothing if none.
latest_k8s_for_talos() { # latest_k8s_for_talos <table>
  local t ks v best=""
  while IFS='|' read -r t ks; do
    [ "$t" = "${TALOS_VERSION#v}" ] || continue
    for v in $ks; do
      [[ "$v" =~ ^${K8S_MINOR//./\\.}\.[0-9]+$ ]] || continue
      best=$(printf '%s\n%s\n' "$best" "$v" | sort -V | tail -n1)
    done
  done <<<"$1"
  [ -z "$best" ] || echo "$best"
}

# Omni reads only: get / list. Output may contain machine class YAML (no secrets).
omni_reads() {
  local out tv table mc ids kv
  # Listing clusters doubles as the connectivity/auth check and avoids parsing a not-found error.
  if ! out=$(omnictl get cluster -o yaml 2>&1); then
    step FAIL "Omni reachable and authenticated" "$OMNI_ENDPOINT: $(redact <<<"$out" | head -n3 | tr '\n' ' ')"
    return
  fi
  step DONE "Omni reachable and authenticated" "$OMNI_ENDPOINT"
  if ! ids=$(printf '%s\n' "$out" | yq -r '.metadata.id' 2>&1); then
    step FAIL "cluster $CLUSTER_NAME does not exist" "cannot parse cluster list: $(redact <<<"$ids" | head -n2 | tr '\n' ' ')"
  elif grep -Fxq -- "$CLUSTER_NAME" <<<"$ids"; then
    step FAIL "cluster $CLUSTER_NAME does not exist" "already exists; a real run would refuse"
  else
    step DONE "cluster $CLUSTER_NAME does not exist"
  fi
  for mc in "$MACHINE_CLASS_CP" "$MACHINE_CLASS_WORKER"; do
    # UNVERIFIED-by-script, confirmed by an owner run: resource name `machineclass`
    if out=$(omnictl get machineclass "$mc" -o yaml 2>&1); then
      { echo "machine class $mc:"; echo "$out"; } >> "$OUT/details.txt"
      step DONE "machine class $mc exists" "YAML printed below"
    else
      step FAIL "machine class $mc exists" "$(redact <<<"$out" | head -n2 | tr '\n' ' ')"
    fi
  done

  if ! tv=$(omnictl get talosversion -o yaml 2>&1) && ! tv=$(omnictl get talosversions -o yaml 2>&1); then
    step FAIL "resolve Talos/Kubernetes versions" "cannot list Talos versions: $(redact <<<"$tv" | head -n2 | tr '\n' ' ')"
    return
  fi
  if ! table=$(offered_table "$tv" 2>&1) || ! grep -q '|[0-9]' <<<"$table"; then
    {
      echo "Talos versions: could not find compatible Kubernetes versions in the resource. Raw output (first 60 lines):"
      redact <<<"$tv" | head -n60
    } >> "$OUT/details.txt"
    step FAIL "resolve Talos/Kubernetes versions" "unknown resource fields; raw talosversion output below, set TALOS_VERSION and K8S_VERSION to override"
    return
  fi
  { echo "Talos versions offered by Omni (talos: kubernetes versions):"; printf "%s\n" "${table//|/: }"; } >> "$OUT/details.txt"
  if kv=$(omnictl get kubernetesversion -o yaml 2>/dev/null); then
    { echo "Kubernetes versions offered by Omni:"; printf '%s\n' "$kv" | yq -r '(.spec.version // .metadata.id)' 2>/dev/null | tr '\n' ' '; echo; } >> "$OUT/details.txt"
  fi
  TALOS_VERSION="v${TALOS_VERSION#v}"
  if [ -z "$K8S_VERSION" ]; then
    K8S_VERSION=$(latest_k8s_for_talos "$table")
    if [ -z "$K8S_VERSION" ]; then
      step FAIL "resolve Talos/Kubernetes versions" "Omni offers no Kubernetes $K8S_MINOR.x for Talos $TALOS_VERSION; see the offered versions below and set TALOS_VERSION/K8S_VERSION (no fallback to another minor)"
      return
    fi
  fi
  K8S_VERSION="v${K8S_VERSION#v}"
  # The pair must be offered exactly: the Talos version exists and lists this Kubernetes version.
  # No fallback to another version; the offered table is in the details below.
  if ! pair_offered "$table"; then
    step FAIL "resolve Talos/Kubernetes versions" "Omni does not offer Talos $TALOS_VERSION with Kubernetes $K8S_VERSION; see the offered versions below and set TALOS_VERSION/K8S_VERSION"
  else
    step DONE "Talos $TALOS_VERSION with Kubernetes $K8S_VERSION offered by Omni"
  fi
}

render_template() {
  cp "$REPO_ROOT/patches/pinode.yaml" "$WORK/pinode.yaml"
  cat > "$WORK/template.yaml" <<YAML
kind: Cluster
name: ${CLUSTER_NAME}
talos:
  version: ${TALOS_VERSION}
kubernetes:
  version: ${K8S_VERSION}
patches:
  - name: pinode
    file: pinode.yaml
---
kind: ControlPlane
machineClass:
  name: ${MACHINE_CLASS_CP}
  size: ${CP_COUNT}
YAML
  if [ "$WORKER_COUNT" -gt 0 ]; then
    cat >> "$WORK/template.yaml" <<YAML
---
kind: Workers
machineClass:
  name: ${MACHINE_CLASS_WORKER}
  size: ${WORKER_COUNT}
YAML
  fi
}

# Guard against a template that silently drops a machine set.
assert_machine_set() { # assert_machine_set kind class size
  local t="$WORK/template.yaml"
  if ! grep -q "^kind: $1\$" "$t" || ! grep -q "name: $2\$" "$t" || ! grep -q "size: $3\$" "$t"; then
    die "rendered template is missing the $1 machine set ($2 x $3)"
  fi
}

check_template() {
  if [ -z "$TALOS_VERSION" ] || [ -z "$K8S_VERSION" ]; then
    step SKIPPED "template render + offline validate" "Talos/Kubernetes versions unresolved"
    return
  fi
  render_template
  assert_machine_set ControlPlane "$MACHINE_CLASS_CP" "$CP_COUNT"
  if [ "$WORKER_COUNT" -gt 0 ]; then assert_machine_set Workers "$MACHINE_CLASS_WORKER" "$WORKER_COUNT"; fi
  # Offline: validates the template structure and the pinode.yaml file reference.
  if omnictl cluster template validate -f "$WORK/template.yaml" --allowed-dir "$WORK" >/dev/null 2>&1; then
    step DONE "omnictl cluster template validate (offline)"
  else
    step FAIL "omnictl cluster template validate (offline)"
  fi
}

# ---- preflight: only the Omni reads ----
if [ "$PREFLIGHT" = 1 ]; then
  check_inputs
  command -v omnictl >/dev/null || die "missing tool: omnictl"
  command -v yq >/dev/null || die "missing tool: yq"
  step SKIPPED "server-side template diff" "needs a rendered template; run --dry-run with credentials"
  omni_reads
  print_steps
  cat "$OUT/details.txt"
  [ "$fail_count" -eq 0 ] || { echo "$fail_count check(s) failed" >&2; exit 1; }
  exit 0
fi

# ---- read-only phase (dry-run and real run) ----
check_inputs
check_tools
finish_if_failed
check_repo
if [ "$HAVE_CREDS" = 1 ]; then
  omni_reads
else
  TALOS_VERSION="v${TALOS_VERSION#v}"
  K8S_VERSION="${K8S_VERSION:-$K8S_MINOR.0}"
  K8S_VERSION="v${K8S_VERSION#v}"
  step SKIPPED "Omni reads (connectivity, cluster absent, machine classes, versions offered)" \
    "no credentials; $TALOS_VERSION / $K8S_VERSION not checked against Omni (placeholder unless overridden)"
fi
check_template
if [ "$DRY_RUN" = 1 ] && [ "$HAVE_CREDS" = 1 ]; then
  # `template diff` only queries and compares (per --help); UNVERIFIED against a live Omni.
  if omnictl cluster template diff -f "$WORK/template.yaml" --allowed-dir "$WORK" >/dev/null 2>&1; then
    step DONE "omnictl cluster template diff (server-side preview)"
  else
    step FAIL "omnictl cluster template diff (server-side preview)"
  fi
elif [ "$DRY_RUN" = 1 ]; then
  step SKIPPED "omnictl cluster template diff (server-side preview)" "no credentials"
fi

if [ "$DRY_RUN" = 1 ]; then
  step WOULD-RUN "omnictl cluster template sync, then arm teardown"
  step WOULD-RUN "wait for cluster ready; fetch service-account kubeconfig"
  step WOULD-RUN "kubectl checks: nodes, Cilium, kube-proxy, cilium-config, stability, connectivity, Flux"
  step WOULD-RUN "delete installer ClusterRoleBindings and assert gone"
  step WOULD-RUN "omnictl cluster delete $CLUSTER_NAME (teardown)"
  if [ -f "$WORK/template.yaml" ]; then
    echo "--- rendered template ---"
    cat "$WORK/template.yaml"
    echo
  fi
  [ ! -s "$OUT/details.txt" ] || { cat "$OUT/details.txt"; echo; }
  echo "--- steps (dry-run: nothing was created, changed or deleted) ---"
  print_steps
  [ "$fail_count" -eq 0 ] || { echo "$fail_count check(s) failed" >&2; exit 1; }
  exit 0
fi
finish_if_failed

SUMMARY="$OUT/summary.txt"
: > "$SUMMARY"
fails=0
record() { # record PASS|FAIL name
  echo "$1 $2" | tee -a "$SUMMARY"
  [ "$1" = PASS ] || fails=$((fails + 1))
}
check() { # check name cmd...
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then record PASS "$name"; else record FAIL "$name"; fi
}

{
  echo "cluster: $CLUSTER_NAME  talos: $TALOS_VERSION  kubernetes: $K8S_VERSION  workers: $WORKER_COUNT"
  cat "$OUT/details.txt"
} >> "$SUMMARY"

omnictl cluster template sync -f "$WORK/template.yaml" --allowed-dir "$WORK"
created=1
trap cleanup EXIT

if omnictl cluster template status -f "$WORK/template.yaml" --allowed-dir "$WORK" --wait 30m >/dev/null 2>&1; then
  record PASS "cluster ready"
else
  record FAIL "cluster ready"
fi

export KUBECONFIG="$WORK/kubeconfig"
# A service-account kubeconfig avoids the interactive OIDC login.
omnictl kubeconfig "$KUBECONFIG" -c "$CLUSTER_NAME" --service-account --user e2e-test --merge=false --force >/dev/null \
  || die "could not fetch kubeconfig"
chmod 600 "$KUBECONFIG"
k() { kubectl --request-timeout=60s "$@"; }

want_nodes=$((CP_COUNT + WORKER_COUNT))
check "nodes Ready" k wait --for=condition=Ready nodes --all --timeout=15m
if [ "$(k get nodes -o name | wc -l)" -eq "$want_nodes" ]; then record PASS "node count $want_nodes"; else record FAIL "node count $want_nodes"; fi

check "cilium-install Job Complete (not Failed)" k -n kube-system wait --for=condition=complete job/cilium-install --timeout=20m
check "cilium DaemonSet rolled out" k -n kube-system rollout status ds/cilium --timeout=5m
check "cilium-operator Available" k -n kube-system wait --for=condition=available deploy/cilium-operator --timeout=5m
if k -n kube-system get ds kube-proxy >/dev/null 2>&1; then record FAIL "kube-proxy absent"; else record PASS "kube-proxy absent"; fi
cfg=$(k -n kube-system get cm cilium-config \
  -o go-template='{{index .data "kube-proxy-replacement"}} {{index .data "k8s-service-host"}} {{index .data "k8s-service-port"}}' 2>/dev/null || true)
if [ "$cfg" = "true localhost 7445" ]; then record PASS "cilium-config: kube-proxy replacement + KubePrism"; else record FAIL "cilium-config ($cfg)"; fi

check "flux-operator-install Job Complete" k -n flux-system wait --for=condition=complete job/flux-operator-install --timeout=10m
check "flux-operator Deployment Available" k -n flux-system wait --for=condition=available deploy/flux-operator --timeout=5m
check "FluxInstance CRD exists" k get crd fluxinstances.fluxcd.controlplane.io
check "fluxinstance-apply Job Complete" k -n flux-system wait --for=condition=complete job/fluxinstance-apply --timeout=10m
check "FluxInstance flux Ready" k -n flux-system wait --for=condition=Ready fluxinstance/flux --timeout=10m

echo "waiting 10 min for the stability check..."
sleep 600
bad=0
for ns in kube-system flux-system; do
  # the sops-decrypt pod waits for the manual sops-age Secret, so it is excluded
  n=$(k -n "$ns" get pods --no-headers 2>/dev/null | grep -v 'sops-decrypt' | grep -cE 'CrashLoopBackOff|Pending' || true)
  bad=$((bad + n))
done
if [ "$bad" -eq 0 ]; then record PASS "no CrashLoopBackOff/Pending after 10 min"; else record FAIL "no CrashLoopBackOff/Pending after 10 min ($bad)"; fi

# Connectivity: 3 replicas spread over hosts, ClusterIP + NodePort, DNS, cross-node.
k create namespace e2e-net >/dev/null
k apply -n e2e-net -f - >/dev/null <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: web}
spec:
  replicas: 3
  selector: {matchLabels: {app: web}}
  template:
    metadata: {labels: {app: web}}
    spec:
      topologySpreadConstraints:
        - {maxSkew: 1, topologyKey: kubernetes.io/hostname, whenUnsatisfiable: DoNotSchedule, labelSelector: {matchLabels: {app: web}}}
      containers:
        - name: web
          image: registry.k8s.io/e2e-test-images/agnhost:2.53
          args: [netexec, --http-port=8080]
          ports: [{containerPort: 8080}]
---
apiVersion: v1
kind: Service
metadata: {name: web-cip}
spec: {selector: {app: web}, ports: [{port: 80, targetPort: 8080}]}
---
apiVersion: v1
kind: Service
metadata: {name: web-np}
spec: {type: NodePort, selector: {app: web}, ports: [{port: 80, targetPort: 8080, nodePort: 30080}]}
YAML
check "test Deployment available" k -n e2e-net rollout status deploy/web --timeout=5m
nodes_used=$(k -n e2e-net get pods -l app=web -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l)
if [ "$nodes_used" -ge 2 ]; then record PASS "pods spread over >=2 nodes ($nodes_used)"; else record FAIL "pods spread over >=2 nodes ($nodes_used)"; fi
if [ "$WORKER_COUNT" -gt 0 ]; then
  workers=$(k get nodes -l '!node-role.kubernetes.io/control-plane' -o name | wc -l)
  if [ "$workers" -eq "$WORKER_COUNT" ]; then record PASS "worker node(s) joined"; else record FAIL "worker node(s) joined"; fi
fi
node_ip=$(k get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
check "DNS, ClusterIP and NodePort from a client pod" \
  k -n e2e-net run client --rm -i --restart=Never --image=registry.k8s.io/e2e-test-images/agnhost:2.53 --command -- \
  /bin/sh -c "nslookup kubernetes.default.svc.cluster.local && wget -qO- -T 5 http://web-cip/hostname && wget -qO- -T 5 http://$node_ip:30080/hostname"
k delete namespace e2e-net --wait=false >/dev/null

k delete clusterrolebinding cilium-installer flux-operator-installer >/dev/null 2>&1 || true
if k get clusterrolebinding cilium-installer >/dev/null 2>&1 || k get clusterrolebinding flux-operator-installer >/dev/null 2>&1; then
  record FAIL "installer ClusterRoleBindings removed"
else
  record PASS "installer ClusterRoleBindings removed"
fi

echo "Summary: $SUMMARY ($fails failure(s))"
[ "$fails" -eq 0 ]
