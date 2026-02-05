#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

CLUSTER="lab"
IMAGE="nginx-custom:v1"

red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)

log() { echo "${green}[$(date +%H:%M:%S)]${reset} $1"; }
error() { echo "${red}[ERREUR]${reset} $1"; exit 1; }

log "🚀 Image-to-Cluster - Automatisation complète"

# 1️⃣ INSTALL TOOLS (ignore yarnpkg warnings)
log "📦 Installation outils..."
sudo apt-get update -qq 2>/dev/null || true
sudo apt-get install -y wget gpg lsof unzip curl software-properties-common || true


# Packer HashiCorp (avec sudo)
wget -qO- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null


sudo apt-get update -qq 2>/dev/null || true
sudo apt-get install -y packer || error "Packer install failed"

sudo apt-get install -y ansible || true
ansible-galaxy collection install kubernetes.core --force > /dev/null 2>&1 || true
python3 -m pip install --user --upgrade kubernetes PyYAML jsonpatch > /dev/null 2>&1 || true

packer version | head -1 && log "✅ Outils OK"

# 2️⃣ PACKER (tes fichiers repo)
log "🏗️  Build $IMAGE..."
[ -f packer/nginx.pkr.hcl ] || error "packer/nginx.pkr.hcl manquant"
packer init packer/
packer build packer/
docker images | grep -q "nginx-custom" || error "Image nginx-custom manquante"
IMAGE_ID=$(docker images --format "{{.ID}}" nginx-custom | head -1)
log "✅ Image OK: nginx-custom ($IMAGE_ID)"

# 3️⃣ K3D
log "📦 K3d $CLUSTER..."
k3d cluster create $CLUSTER --agents 2 || true
k3d image import $IMAGE -c $CLUSTER

# 4️⃣ ANSIBLE (tes manifests)
log "🚀 Ansible..."
[ -f ansible/deploy.yml ] || error "ansible/deploy.yml manquant"
ansible-playbook ansible/deploy.yml || error "Ansible failed"

# 5️⃣ TEST
log "🧪 Status..."
kubectl get deploy,po,svc -n default || error "kubectl failed"

# Port-forward
sudo lsof -ti:8082 | xargs -r kill -9 2>/dev/null || true
kubectl port-forward svc/nginx-custom 8082:80 -n default &
sleep 4

if curl -s -m 5 http://localhost:8082 | grep -q "html"; then
  log "✅ ${green}SUCCESS !${reset} http://localhost:8082"
  curl -s http://localhost:8082 | head -15
else
  log "⚠️  Port-forward OK, ouvre http://localhost:8082"
fi

log "🎉 ${green}TERMINÉ${reset}"
echo "🌐 http://localhost:8082"
