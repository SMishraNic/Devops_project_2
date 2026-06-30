#!/bin/bash

set -e

echo "======================================"
echo " Kubernetes Master Node Installation"
echo "======================================"

# Disable Swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Load Kernel Modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configure Kernel Parameters
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

##########################################
# Initialize Cluster
##########################################

MASTER_IP=$(hostname -I | awk '{print $1}')

sudo kubeadm init \
--pod-network-cidr=10.244.0.0/16 \
--apiserver-advertise-address=$MASTER_IP

##########################################
# Configure kubectl
##########################################

mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config

##########################################
# Install Calico Network Plugin
##########################################

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

echo ""
echo "===================================="
echo "Cluster Initialized Successfully"
echo "===================================="

echo ""
echo "Run the below command on worker nodes:"
echo ""

kubeadm token create --print-join-command