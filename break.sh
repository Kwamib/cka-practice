#!/usr/bin/env bash
# break.sh: break the practice cluster the way the exam does, then fix it.
#
#   ./break.sh list       show the tickets (symptoms only)
#   ./break.sh 3          break something for ticket 3
#   ./break.sh undo 3     put ticket 3 back the way it was, if you're stuck
#
# Run it from this folder on your own computer, with the cluster up.
# Try not to read past this line before you've solved a ticket: on the exam,
# all you get is the symptom.
set -euo pipefail
cd "$(dirname "$0")"

ticket() {
  case "$1" in
    1) echo "worker1 is NotReady. Make it Ready, and make sure it stays Ready after a reboot." ;;
    2) echo "worker2 is NotReady, and new pods that land there never start. Fix the node so the fix survives a reboot." ;;
    3) echo "kubectl stopped working on cp1. Get the cluster's API back." ;;
    4) echo "New pods stay Pending forever, on every node. Find out why and fix it." ;;
    5) echo "worker2 is NotReady again, but containerd is running this time. Fix it." ;;
    *) return 1 ;;
  esac
}

node_for() {
  case "$1" in
    1) echo worker1 ;;
    2|5) echo worker2 ;;
    3|4) echo cp1 ;;
  esac
}

# What each ticket does on its node. Backups go in /root/.break so undo works.
break_cmds() {
  case "$1" in
    1) cat <<'EOS'
systemctl disable --now kubelet >/dev/null 2>&1
EOS
    ;;
    2) cat <<'EOS'
systemctl disable --now containerd >/dev/null 2>&1
EOS
    ;;
    3) cat <<'EOS'
mkdir -p /root/.break
f=/etc/kubernetes/manifests/kube-apiserver.yaml
cp "$f" /root/.break/kube-apiserver.yaml
sed -i 's#--etcd-servers=https://127.0.0.1:2379#--etcd-servers=https://127.0.0.1:2380#' "$f"
EOS
    ;;
    4) cat <<'EOS'
mkdir -p /root/.break
f=/etc/kubernetes/manifests/kube-scheduler.yaml
cp "$f" /root/.break/kube-scheduler.yaml
sed -i 's#--kubeconfig=/etc/kubernetes/scheduler.conf#--kubeconfig=/etc/kubernetes/scheduler.config#' "$f"
EOS
    ;;
    5) cat <<'EOS'
mkdir -p /root/.break
f=$(systemctl show -p DropInPaths --value kubelet | tr ' ' '\n' | grep 10-kubeadm.conf)
cp "$f" /root/.break/10-kubeadm.conf
echo "$f" > /root/.break/10-kubeadm.path
sed -i 's#^ExecStart=/usr/bin/kubelet #ExecStart=/usr/local/bin/kubelet #' "$f"
systemctl daemon-reload
systemctl restart kubelet || true
EOS
    ;;
  esac
}

undo_cmds() {
  case "$1" in
    1) echo 'systemctl enable --now kubelet' ;;
    2) echo 'systemctl enable --now containerd; systemctl restart kubelet' ;;
    3) echo 'cp /root/.break/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml' ;;
    4) echo 'cp /root/.break/kube-scheduler.yaml /etc/kubernetes/manifests/kube-scheduler.yaml' ;;
    5) echo 'cp /root/.break/10-kubeadm.conf "$(cat /root/.break/10-kubeadm.path)"; systemctl daemon-reload; systemctl restart kubelet' ;;
  esac
}

on_node() {
  # Send the commands as base64, so no quoting gets mangled on the way.
  local node=$1 cmds=$2 b64
  b64=$(printf '%s\n' "$cmds" | base64 | tr -d '\n')
  vagrant ssh "$node" -c "echo $b64 | base64 -d | sudo bash" 2>/dev/null
}

case "${1:-}" in
  list)
    for n in 1 2 3 4 5; do echo "Ticket $n: $(ticket $n)"; done
    ;;
  undo)
    n=${2:-}; ticket "$n" >/dev/null || { echo "Usage: ./break.sh undo 1-5"; exit 1; }
    on_node "$(node_for "$n")" "$(undo_cmds "$n")"
    echo "Ticket $n undone. Give the cluster a minute, then check with: k get nodes; k get pods -n kube-system"
    ;;
  [1-5])
    n=$1
    on_node "$(node_for "$n")" "$(break_cmds "$n")"
    echo "Ticket $n: $(ticket "$n")"
    echo "Symptoms can take up to a minute to show. Start your timer, and work from cp1, as on the exam."
    ;;
  *)
    echo "Usage: ./break.sh list | 1-5 | undo 1-5"
    exit 1
    ;;
esac
