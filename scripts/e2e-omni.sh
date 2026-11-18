#!/usr/bin/env bash
# E2E test: create a disposable Omni cluster from patches/pinode.yaml on Proxmox
# machine classes, run health checks, print a summary path, tear the cluster down.
# Run locally (not CI). Requires: omnictl, kubectl, yq.
#
# Usage: OMNI_SERVICE_ACCOUNT_KEY=... scripts/e2e-omni.sh [--dry-run]
# Env: OMNI_ENDPOINT CLUSTER_NAME MACHINE_CLASS_CP MACHINE_CLASS_WORKER WORKER_COUNT
#      TALOS_VERSION K8S_VERSION KEEP_CLUSTER
#
# omnictl commands/flags were checked against `omnictl --help` (v1.13.2).
# UNVERIFIED (no Omni access when written; marked "UNVERIFIED" inline):
#   - wording/exit code of `omnictl get cluster <name>` when the cluster is absent
#   - TalosVersion resource name and its compatible_kubernetes_versions field
#   - MachineClass resource name for `omnictl get machineclass`
set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export OMNI_ENDPOINT="${OMNI_ENDPOINT:-https://omni.ad.bonkie.net}"
CLUSTER_NAME="${CLUSTER_NAME:-e2e-talos-cilium-$(date +%Y%m%d%H%M%S)}"
MACHINE_CLASS_CP="${MACHINE_CLASS_CP:-proxmox-small}"
MACHINE_CLASS_WORKER="${MACHINE_CLASS_WORKER:-proxmox-medium}"
WORKER_COUNT="${WORKER_COUNT:-0}"
TALOS_VERSION="${TALOS_VERSION:-}"
K8S_VERSION="${K8S_VERSION:-}"
KEEP_CLUSTER="${KEEP_CLUSTER:-0}"
CP_COUNT=3 # machine-set size lives only in the template; the repo preflight needs no count

die() { echo "ERROR: $*" >&2; exit 1; }

[[ "$CLUSTER_NAME" =~ ^e2e-[a-z0-9-]+$ ]] || die "CLUSTER_NAME must match ^e2e-[a-z0-9-]+\$"
[[ "$WORKER_COUNT" =~ ^[0-9]+$ ]] || die "WORKER_COUNT must be a number"
for t in omnictl kubectl yq; do command -v "$t" >/dev/null || die "missing tool: $t"; done
if [ "$DRY_RUN" = 0 ]; then
  [ -n "${OMNI_SERVICE_ACCOUNT_KEY:-}" ] || die "OMNI_SERVICE_ACCOUNT_KEY must be set in the environment"
  export OMNI_SERVICE_ACCOUNT_KEY
fi

# WORK holds the template and kubeconfig and is always removed.
# OUT holds only the summary (no secrets) and is kept so its path can be printed.
WORK=$(mktemp -d)
OUT=$(mktemp -d)
chmod 700 "$WORK"
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
trap 'rm -rf "$WORK"' EXIT # replaced by cleanup only after the cluster is created

# Pick a Talos/K8s pair supporting Kubernetes 1.34 unless both are given.
resolve_versions() {
  if [ "$DRY_RUN" = 1 ]; then
    TALOS_VERSION="${TALOS_VERSION:-v1.11.0}"
    K8S_VERSION="${K8S_VERSION:-v1.34.0}"
    echo "(dry-run) versions not resolved from Omni; using ${TALOS_VERSION} / ${K8S_VERSION}"
  elif [ -z "$TALOS_VERSION" ] || [ -z "$K8S_VERSION" ]; then
    # UNVERIFIED: resource type `talosversion` and field spec.compatible_kubernetes_versions
    local tv pick
    tv=$(omnictl get talosversion -o yaml) || die "cannot list Talos versions from Omni"
    pick=$(printf '%s\n' "$tv" \
      | yq -r 'select(.spec.compatible_kubernetes_versions[] | test("^1\\.34\\.")) | .spec.version' \
      | sed 's/^v//' | sort -V | tail -n1) || true
    [ -n "$pick" ] || die "no Talos version in Omni supports Kubernetes 1.34"
    TALOS_VERSION="${TALOS_VERSION:-$pick}"
    K8S_VERSION="${K8S_VERSION:-$(printf '%s\n' "$tv" \
      | yq -r "select(.spec.version == \"$pick\" or .spec.version == \"v$pick\") | .spec.compatible_kubernetes_versions[]" \
      | sed 's/^v//' | grep '^1\.34\.' | sort -V | tail -n1)}"
  fi
  [[ "$TALOS_VERSION" == v* ]] || TALOS_VERSION="v$TALOS_VERSION"
  [[ "$K8S_VERSION" == v* ]] || K8S_VERSION="v$K8S_VERSION"
  [[ "$K8S_VERSION" =~ ^v1\.34\.[0-9]+$ ]] || die "K8S_VERSION must be 1.34.x (got '$K8S_VERSION')"
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

resolve_versions
render_template
# Offline: validates the template structure and the pinode.yaml file reference.
omnictl cluster template validate -f "$WORK/template.yaml" --allowed-dir "$WORK"

# Guard against a template that silently drops a machine set.
assert_machine_set() { # assert_machine_set kind class size
  local t="$WORK/template.yaml"
  if ! grep -q "^kind: $1\$" "$t" || ! grep -q "name: $2\$" "$t" || ! grep -q "size: $3\$" "$t"; then
    die "rendered template is missing the $1 machine set ($2 x $3)"
  fi
}
assert_machine_set ControlPlane "$MACHINE_CLASS_CP" "$CP_COUNT"
if [ "$WORKER_COUNT" -gt 0 ]; then assert_machine_set Workers "$MACHINE_CLASS_WORKER" "$WORKER_COUNT"; fi

if [ "$DRY_RUN" = 1 ]; then
  echo "--- rendered template ---"
  cat "$WORK/template.yaml"
  cat <<PLAN

--- planned steps (dry-run: nothing was sent to Omni) ---
1. refuse if cluster ${CLUSTER_NAME} already exists
2. omnictl cluster template sync, then arm teardown (cluster delete) unless KEEP_CLUSTER=1
3. wait for the cluster to be ready; fetch a service-account kubeconfig into a temp dir
4. checks: nodes Ready, cilium-install Job Complete, Cilium DaemonSet, no kube-proxy, cilium-config,
   10 min stability, DNS/ClusterIP/NodePort/cross-node connectivity, Flux operator Jobs and FluxInstance
5. delete installer ClusterRoleBindings and assert they are gone
6. print summary path; tear down
PLAN
  exit 0
fi

# Refuse to touch an existing cluster. UNVERIFIED: wording of `get` for a missing cluster.
if out=$(omnictl get cluster "$CLUSTER_NAME" -o yaml 2>&1); then
  die "cluster $CLUSTER_NAME already exists; refusing"
elif ! grep -qi "not found" <<<"$out"; then
  die "cannot determine whether $CLUSTER_NAME exists (Omni unreachable or auth failed)"
fi

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
  echo "machine class $MACHINE_CLASS_CP:"
  omnictl get machineclass "$MACHINE_CLASS_CP" -o yaml 2>&1 || true # UNVERIFIED resource name
  if [ "$WORKER_COUNT" -gt 0 ]; then
    echo "machine class $MACHINE_CLASS_WORKER:"
    omnictl get machineclass "$MACHINE_CLASS_WORKER" -o yaml 2>&1 || true
  fi
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
