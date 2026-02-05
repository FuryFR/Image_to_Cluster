# Automatisation de Déploiement K3d (Packer + Ansible)

Ce projet permet de déployer automatiquement un cluster Kubernetes léger (**K3d**) et d'y orchestrer une application **Nginx personnalisée**.

L'ensemble du pipeline (installation des outils, build de l'image, création du cluster et déploiement) est entièrement automatisé via un script Bash, rendant l'environnement reproductible instantanément dans **GitHub Codespaces**.

## Architecture du projet

Le pipeline exécute les étapes suivantes de manière séquentielle :
1.  **Préparation de l'environnement** : Installation automatique de `kubectl`, `k3d`, `Packer` et `Ansible`.
2.  **Infrastructure** : Création d'un cluster Kubernetes local via **K3d**.
3.  **Build** : Création d'une image Docker immuable (`nginx-custom:v1`) avec **Packer**, intégrant une page HTML personnalisée.
4.  **Distribution** : Import direct de l'image dans le registre du cluster K3d (sans passer par un Docker Hub).
5.  **Déploiement** : Orchestration des ressources Kubernetes (Deployment + Service) via un playbook **Ansible**.


## Structure des fichiers
```bash
.
├── deploy.sh              # 🚀 Script d'automatisation principal (Master Script)
├── Architecture_cible.png # Schéma de l'architecture
├── ansible
│   └── deploy.yml         # Playbook Ansible pour orchestrer Kubernetes
├── k8s
│   ├── deployment.yaml    # Définition du Deployment (Pods Nginx)
│   └── service.yaml       # Définition du Service (ClusterIP)
├── packer
│   └── nginx.pkr.hcl      # Template Packer pour builder l'image Docker
└── index.html             # Page web personnalisée injectée dans l'image
```


## Démarrage Rapide (Quick Start)

1. Lancer l'environnement
Ouvrez ce dépôt dans un GitHub Codespace.

2. Exécuter le déploiement
Lancez le script d'automatisation à la racine du projet. Il s'occupe de tout (installation des dépendances, fix des dépôts, build et deploy).

```bash
chmod +x deploy.sh
./deploy.sh
```

3. Vérifier le fonctionnement
Une fois le script terminé, l'application tourne dans le cluster.

Pour y accéder depuis votre machine ou le navigateur du Codespace, effectuez un port-forward :

```bash
kubectl port-forward svc/nginx-custom 8080:80
```

Ouvrez ensuite votre navigateur ou utilisez curl :

URL : http://localhost:8080

Résultat attendu : Votre page index.html personnalisée s'affiche.