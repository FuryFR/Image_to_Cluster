#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Variables
CLUSTER="lab"
IMAGE="nginx-custom:v1"
PORT=8082

# Couleurs
red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)

log() { echo "${green}[$(date +%H:%M:%S)]${reset} $1"; }
error() { echo "${red}[ERREUR]${reset} $1"; exit 1; }

log "Image-to-Cluster - Automatisation complète"

# 1. INSTALLATION OUTILS
log "Verification outils..."
sudo apt-get update -qq 2>/dev/null || true
sudo apt-get install -y wget gpg lsof unzip curl software-properties-common apt-transport-https ca-certificates || true

# Packer
if ! command -v packer &> /dev/null; then
    wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
    sudo apt-get update -qq 2>/dev/null || true
    sudo apt-get install -y packer
fi

# K3d
if ! command -v k3d &> /dev/null; then
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash >/dev/null
fi

# Kubectl
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# Ansible
sudo apt-get install -y ansible || true
ansible-galaxy collection install kubernetes.core --force > /dev/null 2>&1 || true
python3 -m pip install --user --upgrade kubernetes PyYAML jsonpatch > /dev/null 2>&1 || true

log "Outils OK"

# 2. PACKER
log "Build image $IMAGE..."
packer init packer/
packer build packer/
if ! docker images | grep -q "nginx-custom"; then
    error "Image non trouvee"
fi

# 3. K3D
log "Cluster K3d..."
if k3d cluster list | grep -q "$CLUSTER"; then
    log "ℹCluster existe deja"
else
    k3d cluster create $CLUSTER --agents 2 --port "${PORT}:80@loadbalancer" >/dev/null
fi
k3d image import $IMAGE -c $CLUSTER

# 4. ANSIBLE
log "Deploiement Ansible..."
ansible-playbook ansible/deploy.yml

# --- CORRECTION ICI : FORCER LE REDEMARRAGE ---
log "Force update du Pod..."
kubectl rollout restart deployment nginx-custom -n default
kubectl rollout status deployment/nginx-custom -n default --timeout=60s
# ----------------------------------------------

# 5. TEST
log "Verification..."
# Nettoyage port 8082
sudo lsof -ti:${PORT} | xargs -r kill -9 2>/dev/null || true

# Port-forward background
kubectl port-forward svc/nginx-custom ${PORT}:80 -n default >/dev/null 2>&1 &
PID_PF=$!
sleep 5

if curl -s -m 5 http://localhost:${PORT} | grep -q "html"; then
    log "SUCCESS ! http://localhost:${PORT}"
    curl -s http://localhost:${PORT} | head -10
else
    log "Echec curl local. Verifiez manuellement http://localhost:${PORT}"
    log "Note: Sur Codespaces, verifiez que le port ${PORT} est public."
fi

# Cleanup
disown $PID_PF 2>/dev/null || true
kill $PID_PF 2>/dev/null || true

log "TERMINÉ"
