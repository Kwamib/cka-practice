#!/usr/bin/env bash
# Prepares one machine to be a Kubernetes node, the way the kubeadm docs
# describe: swap off, two kernel modules, three network settings, containerd
# as the container runtime, and kubeadm, kubelet and kubectl at one pinned
# version. It does not run kubeadm init or join: that's the lesson.
#
# The cluster starts at Kubernetes v1.36, one minor version behind the exam,
# so a later lesson can upgrade it for real.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
K8S_MINOR="v1.36"

echo "== swap off (the kubelet won't start with swap on)"
swapoff -a
sed -i '/\sswap\s/ s/^#*/#/' /etc/fstab

echo "== kernel modules for container networking"
cat > /etc/modules-load.d/k8s.conf <<'MODS'
overlay
br_netfilter
MODS
modprobe overlay
modprobe br_netfilter

echo "== network settings: let bridged traffic through iptables, and forward packets"
cat > /etc/sysctl.d/k8s.conf <<'SYSCTL'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
SYSCTL
sysctl --system >/dev/null

echo "== containerd, with the systemd cgroup driver the kubelet expects (and bash-completion, which kubectl's Tab completion needs)"
apt-get update -qq
apt-get install -y -qq apt-transport-https ca-certificates curl gpg containerd bash-completion >/dev/null
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd >/dev/null
cat > /etc/crictl.yaml <<'CRICTL'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
CRICTL

echo "== kubeadm, kubelet and kubectl ${K8S_MINOR}, held at that version"
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -qq
apt-get install -y -qq kubelet kubeadm kubectl >/dev/null
apt-mark hold kubelet kubeadm kubectl >/dev/null
systemctl enable kubelet >/dev/null

echo "== ready: $(hostname) has $(kubeadm version -o short), containerd $(containerd --version | awk '{print $3}')"
echo "   The kubelet restarts every few seconds until this node joins a cluster. That's normal."
