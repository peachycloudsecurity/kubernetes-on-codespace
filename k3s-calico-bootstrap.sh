#!/usr/bin/env bash
set -euo pipefail

WORKDIR="$(pwd)"
LOG_FILE="/tmp/k3s.log"

echo "[+] Working directory: ${WORKDIR}"

echo "[+] Installing k3s (if not already installed)"
if ! command -v k3s >/dev/null 2>&1; then
  curl -sfL https://get.k3s.io | sh -
else
  echo "[+] k3s already installed, skipping install"
fi

echo "[+] Stopping any existing k3s processes"
sudo systemctl stop k3s 2>/dev/null || true
sudo k3s-killall.sh 2>/dev/null || true
sudo pkill -9 k3s 2>/dev/null || true
sleep 5

echo "[+] Unmounting containerd mounts"
sudo umount $(mount | grep '/run/k3s' | awk '{print $3}' | tac) 2>/dev/null || true
sleep 2

echo "[+] Cleaning previous k3s state"
sudo rm -rf /var/lib/rancher/k3s 2>/dev/null || true
sudo rm -rf /run/k3s 2>/dev/null || true

echo "[+] Writing k3s config (native snapshotter + Calico CNI)"
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml > /dev/null << 'EOF'
snapshotter: "native"
write-kubeconfig-mode: "644"
flannel-backend: "none"
disable-network-policy: true
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
EOF

echo "[+] Starting k3s server with Calico CNI"
sudo k3s server > "${LOG_FILE}" 2>&1 &

# ---- VALIDATION 1: k3s process / API started ----
echo "[+] Waiting for k3s process to start"
timeout=120
until grep -q "k3s is up and running" "${LOG_FILE}" 2>/dev/null; do
  sleep 2
  timeout=$((timeout - 2))
  if [ "$timeout" -le 0 ]; then
    echo "[!] k3s failed to start (log signal not seen)"
    tail -50 "${LOG_FILE}"
    exit 1
  fi
done

echo "[+] Exporting KUBECONFIG"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
if ! grep -q "KUBECONFIG=/etc/rancher/k3s/k3s.yaml" ~/.bashrc 2>/dev/null; then
  echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> ~/.bashrc
fi

echo "[+] Ensuring kubectl uses k3s"
sudo ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl

# ---- INSTALL CALICO CNI ----
echo "[+] Installing Calico CNI"
sudo k3s kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml

echo "[+] Waiting for Tigera operator to be ready"
sleep 10
sudo k3s kubectl wait --for=condition=Ready pod -l k8s-app=tigera-operator -n tigera-operator --timeout=120s

echo "[+] Creating Calico installation resource"
sudo k3s kubectl create -f - << 'EOF'
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: 10.42.0.0/16
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
EOF

# ---- VALIDATION 2: Calico pods ready ----
echo "[+] Waiting for Calico pods to become Ready"
timeout=180
until sudo k3s kubectl get pods -n calico-system 2>/dev/null | grep -q "Running"; do
  sleep 5
  timeout=$((timeout - 5))
  if [ "$timeout" -le 0 ]; then
    echo "[!] Calico pods did not become Ready"
    sudo k3s kubectl get pods -n calico-system || true
    exit 1
  fi
done

echo "[+] Waiting for all Calico pods to be Ready"
sudo k3s kubectl wait --for=condition=Ready pod --all -n calico-system --timeout=180s

# ---- VALIDATION 3: node actually Ready ----
echo "[+] Waiting for node to become Ready"
timeout=120
until sudo k3s kubectl get nodes 2>/dev/null | grep -q " Ready "; do
  sleep 3
  timeout=$((timeout - 3))
  if [ "$timeout" -le 0 ]; then
    echo "[!] Node did not become Ready"
    sudo k3s kubectl get nodes || true
    tail -50 "${LOG_FILE}"
    exit 1
  fi
done

echo "[+] Verifying cluster and Calico installation"
sudo k3s kubectl get nodes
sudo k3s kubectl get ns
sudo k3s kubectl get pods -n calico-system

echo "[+] Verifying NetworkPolicy API is available"
sudo k3s kubectl api-resources | grep networkpolicies

echo "[✓] k3s + Calico bootstrap completed successfully"
echo "[✓] NetworkPolicy enforcement is now enabled"
