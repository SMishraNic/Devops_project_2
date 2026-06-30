#!/bin/bash

set -e

echo "======================================"
echo " Kubernetes Worker Node Installation"
echo "======================================"

# Disable Swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Load Modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Kernel Parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF

sudo sysctl --system

##########################################
# Install Containerd
##########################################

sudo apt update
sudo apt install -y containerd apt-transport-https curl ca-certificates gpg

sudo mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

##########################################
# Install Kubernetes
##########################################

sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
gpg --dearmor | \
sudo tee /etc/apt/keyrings/kubernetes-apt-keyring.gpg >/dev/null

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | \
sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

sudo apt install -y kubelet kubeadm kubectl

sudo apt-mark hold kubelet kubeadm kubectl

echo ""
echo "=================================="
echo "Worker Node Installation Completed"
echo "=================================="

echo ""
echo "Run the kubeadm join command generated on the master node."