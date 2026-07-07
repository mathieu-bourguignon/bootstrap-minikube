# Bootstrap Minikube - Enhanced DevOps Platform

> Fork amélioré du bootstrap Minikube original avec CI/CD complète, sécurité réseau, rate limiting, et optimisation des performances en utilisnat load testing itératif.

## 🎯 Améliorations Apportées

Ce fork ajoute les fonctionnalités suivantes au bootstrap original :

### 1. CI/CD & Image Registry (GitHub Actions)
- **Workflow complet** : `.github/workflows/ci-cd.yml` build et push vers GitHub Container Registry (GHCR)
- **Tagging intelligent** : Images taguées avec le SHA du commit (`sha-xxxxx`) + tag `latest` pour traçabilité
- **Trivy vulnerability scanning** : Scan automatique des images Docker pour détecter les vulnérabilités CRITICAL/HIGH
- **Secrets sécurisés** : `ghcr-credentials` créé manuellement via `kubectl create secret`

### 2. GitOps (ArgoCD)
- **Applications ArgoCD** pointent vers ce fork (branche `argocd`)
- **Auto-sync activé** avec prune et self-heal pour reconciliation automatique
- **`pullPolicy: Always`** pour consommer les images GHCR à chaque déploiement
- **Correction du problème initial** : ArgoCD pointait vers le repo original au lieu du fork

### 3. Sécurité Réseau
- **Network Policies** : Isolation stricte du trafic API
  - Ingress : uniquement depuis le namespace `istio-system` (Istio Ingress Gateway)
  - Egress : uniquement vers Postgres (5432), Redis (6379), et DNS (53)
  - Note : Minikube utilise `kindnet` qui ne supporte pas les Network Policies, mais les manifeskts sont corrects et fonctionnels avec Calico oCilium en prod
- **Istio Rate Limiting** : Protection contre les pics de charge
  - Limite de 20 requêtes/seconde par pod via `EnvoyFilter`
  - Réponse HTTP 429 (Too Many Requests) avec header personnalisé `x-local-ratelimit: true`
  - Application au niveau du sidecar Istio pour isolation granulaire

### 4. Performance & Reliability
- **Startup probes** : Tolérance de 5 minutes pour initialization lente (sidecar Istio + connexion DB/Redis)
- **Probes optimisées** : Délais augmentés pour éviter les restarts prématurés
  - Liveness : `initialDelaySeconds: 30s` (au lieu de 10s)
  - Readiness : `initialDelaySeconds: 20s` (au lieu de 5s)
- **Code optimisé** : `MAX_DELAY_SECONDS` configurable via variable d'environnement (réduit de 2s à 200ms)
- **HPA tuné** : Configuration conservatrice pour éviter la surcharge
  - `maxReplicas: 3` (au lieu de 5)
  - `averageUtilization: 70%` (au lieu de 50%)
  - `stabilizationWindowSeconds: 60s` pour éviter le scaling thrashing

### 5. Load Testing Itératif (voir `LOAD_TEST_REPORT.md`)
Démarche d'ingénierie itérative avec 4 cycles de test-analyse-correction :

| Test | Modifications | Succès | HTTP 500 | HTTP 503 | P95 Latency |
|------|---------------|--------|----------|----------|-------------|
| #1 Baseline | Aucun | 24% | 3% | 73% | 2.4s |
| #2 Probes fixes | StartupProbe + délais | 59% | 3% | 31% | 6.6s |
| #3 Code+HPA | Delay réduit + HPA tuné | 58% | 11% | 31% | 5.9s |
| #4 Rate Limit | Istio EnvoyFilter | **65%** | **0%** ✅ | 31% | 7.1s |

**Résultat final** : Taux de succès amélioré de **24% à 65%**, erreurs HTTP 500 complètement éliminées.

## 🚀 Démarrage Rapide

### Prérequis
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Docker](https://docs.docker.com/get-docker/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Node.js 22+](https://nodejs.org/) (pour Artillery)

### Installation

```bash
# 1. Cloner le repo
git clone https://github.com/AmelGannoun/bootstrap-minikube.git
cd bootstrap-minikube

# 2. Lancer le bootstrap (Minikube, Istio, ArgoCD, monitoring)
chmod +x bootstrap.sh
./bootstrap.sh

# 3. Créer le secret GHCR (remplacer par votre token)
export GITHUB_TOKEN="ghp_votre_token_ici"
kubectl create secret docker-registry ghcr-credentials \
  --docker-server=ghcr.io \
  --docker-username=VOTRE_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  --namespace=default

# 4. Mettre à jour ArgoCD pour pointer vers votre fork
export USERNAME="votre_username_github"
kubectl patch application hello-minikube -n argocd --type='json' \
  -p="[{'op': 'replace', 'path': '/spec/source/repoURL', 'value': 'https://github.com/${USERNAME}/bootstrap-minikube.git'}]"
kubectl patch application python-api -n argocd --type='json' \
  -p="[{'op': 'replace', 'path': '/spec/source/repoURL', 'value': 'https://github.com/${USERNAME}/bootstrap-minikube.git'}]"
kubectl patch application platform-routing -n argocd --type='json' \
  -p="[{'op': 'replace', 'path': '/spec/source/repoURL', 'value': 'https://github.com/${USERNAME}/bootstrap-minikube.git'}]"

# 5. Accéder aux services
minikube tunnel 