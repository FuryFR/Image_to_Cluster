#!/usr/bin/env bash
set -euo pipefail

# Couleurs pour les logs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# ==========================
# 1) Installation des dépendances système
# ==========================
log_info "Installation des dépendances système..."
sudo apt-get update -qq
sudo apt-get install -y curl wget ca-certificates gnupg lsb-release python3 python3-pip ansible > /dev/null 2>&1
log_success "Dépendances système installées"

# ==========================
# 2) Installation de kubectl
# ==========================
log_info "Installation de kubectl..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" 2>/dev/null
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl
log_success "kubectl $(kubectl version --client --short 2>/dev/null | awk '{print $3}') installé"

# ==========================
# 3) Installation de k3d
# ==========================
log_info "Installation de k3d..."
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash > /dev/null 2>&1
log_success "k3d $(k3d version | grep 'k3d version' | awk '{print $3}') installé"

# ==========================
# 4) Fix du dépôt Yarn + installation de Packer
# ==========================
log_info "Configuration du dépôt HashiCorp..."
wget -qO - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null

log_warning "Désactivation du dépôt Yarn (clé GPG manquante)..."
sudo mv /etc/apt/sources.list.d/yarn.list /etc/apt/sources.list.d/yarn.list.disabled 2>/dev/null || true

log_info "Installation de Packer..."
sudo apt-get update -qq
sudo apt-get install -y packer > /dev/null 2>&1
log_success "Packer $(packer version | head -n1 | awk '{print $2}') installé"

# ==========================
# 5) Installation des dépendances Python + Ansible
# ==========================
log_info "Installation des modules Python (kubernetes, PyYAML, jsonpatch)..."
python3 -m pip install --user -U kubernetes PyYAML jsonpatch > /dev/null 2>&1

log_info "Installation de la collection Ansible kubernetes.core..."
ansible-galaxy collection install kubernetes.core > /dev/null 2>&1
ANSIBLE_K8S_VERSION=$(ansible-galaxy collection list | grep -E '^kubernetes\.core' | awk '{print $2}')
log_success "Collection kubernetes.core ${ANSIBLE_K8S_VERSION} installée"

# ==========================
# 6) Création du cluster K3d
# ==========================
log_info "Création du cluster K3d 'lab'..."
if k3d cluster list | grep -q '^lab'; then
    log_warning "Cluster 'lab' existe déjà, suppression..."
    k3d cluster delete lab > /dev/null 2>&1
fi

k3d cluster create lab > /dev/null 2>&1
k3d kubeconfig merge lab --kubeconfig-switch-context > /dev/null 2>&1
log_success "Cluster K3d 'lab' créé et configuré"

kubectl get nodes
echo ""

# ==========================
# 7) Build de l'image Docker avec Packer
# ==========================
log_info "Build de l'image nginx-custom:v1 avec Packer..."
cd packer
packer init nginx.pkr.hcl > /dev/null 2>&1
packer build nginx.pkr.hcl
cd ..
log_success "Image nginx-custom:v1 buildée"

docker images | grep nginx-custom
echo ""

# ==========================
# 8) Import de l'image dans K3d
# ==========================
log_info "Import de l'image nginx-custom:v1 dans le cluster K3d..."
k3d image import nginx-custom:v1 -c lab
log_success "Image importée dans K3d"

# ==========================
# 9) Déploiement via Ansible
# ==========================
log_info "Déploiement de l'application via Ansible..."
cd ansible
ansible-playbook deploy.yml
cd ..
log_success "Déploiement Ansible terminé"

echo ""
kubectl get deploy nginx-custom
echo ""
kubectl get pods -l app=nginx-custom -o wide
echo ""
kubectl get svc nginx-custom
echo ""

# ==========================
# 10) Instructions finales
# ==========================
log_success "✅ Déploiement terminé avec succès !"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Pour tester l'application :${NC}"
echo ""
echo -e "  ${YELLOW}Terminal 1 :${NC}"
echo -e "    kubectl port-forward svc/nginx-custom 8080:80"
echo ""
echo -e "  ${YELLOW}Terminal 2 :${NC}"
echo -e "    curl http://localhost:8080"
echo ""
echo -e "${BLUE}Ou dans l'onglet 'Ports' de Codespaces, forward le port 8080${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
