# Configuração ArgoCD - Estrutura e Setup

## 📂 Estrutura da Pasta `argocd/`

```
argocd/
├── bootstrap/                      # 🚀 Ponto de entrada (App of Apps)
│   └── bootstrap-app.yaml          # Aplica TODAS as outras applications
│
├── projects/                       # 🔐 Separação de permissões
│   ├── platform-project.yaml       # Projeto para Platform Team
│   └── tenant-project.yaml         # Projeto para Developers
│
├── applications/                   # 📦 Declaração de cada componente
│   ├── 02-crossplane-providers.yaml # Instala Providers (AWS, Azure, GCP)
│   ├── 03-aws-provider-configs.yaml # Configura credenciais AWS
│   ├── 04-platform-apis.yaml       # Instala XRDs e Compositions
│   ├── 07-environment-dev.yaml     # Claims de desenvolvimento
│   ├── 08-environment-hml.yaml     # Claims de homologação
│   ├── 08-governance-namespaces.yaml # Namespaces (dev, hlm, prod)
│   ├── 09-environment-prod.yaml    # Claims de produção
│   └── 10-governance-rbac.yaml     # RBAC roles
│
└── applicationsets/                # 🔄 Multi-tenant/Multi-env
    └── environment-claims.yaml     # Deploy claims por ambiente
```

## 🎯 Como Funciona (App of Apps Pattern)

```
┌─────────────────────────────────────────────────────────┐
│  1. Você aplica APENAS o bootstrap                      │
│     kubectl apply -f argocd/bootstrap/bootstrap-app.yaml│
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│  2. Bootstrap App cria todas as outras Applications     │
│     (lê argocd/applications/*.yaml)                     │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌──────────────┐ ┌──────────┐ ┌────────────┐
│  Providers   │ │ Provider │ │Platform    │
│ (AWS/Azure)  │ │ Configs  │ │  APIs      │
└──────────────┘ └──────────┘ └────────────┘
```

## 🚀 Setup Completo - Passo a Passo

### 📋 Pré-requisitos

```bash
# 1. Cluster Kubernetes rodando
kubectl cluster-info

# 2. kubectl configurado
kubectl config current-context
```

### 1️⃣ Instalar Crossplane (MANUAL)

```bash
# Instalar via Helm
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  crossplane-stable/crossplane \
  --wait

# Verificar instalação
kubectl get pods -n crossplane-system
kubectl wait --for=condition=Ready pods --all -n crossplane-system --timeout=300s

# Verificar CRDs
kubectl get crds | grep crossplane
```

### 2️⃣ Instalar ArgoCD (MANUAL)

```bash
# Criar namespace
kubectl create namespace argocd

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar pods ficarem Ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Obter senha inicial (admin)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward para acessar UI (opcional)
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

### 3️⃣ Aplicar AppProjects (Separação de Permissões)

```bash
# Aplicar projetos
kubectl apply -f argocd/projects/platform-project.yaml
kubectl apply -f argocd/projects/tenant-project.yaml

# Verificar
kubectl get appproject -n argocd

# Output esperado:
# NAME       AGE
# platform   10s
# tenant     10s
```

**O que isso faz:**
- `platform`: Acesso total para Platform Team
- `tenant`: Acesso restrito para Developers

### 4️⃣ Aplicar Bootstrap (App of Apps)

```bash
# IMPORTANTE: Editar bootstrap-app.yaml primeiro!
# Alterar repoURL para seu repositório Git

# Aplicar bootstrap
kubectl apply -f argocd/bootstrap/bootstrap-app.yaml

# Verificar criação
kubectl get application -n argocd

# Output esperado:
# NAME                    SYNC STATUS   HEALTH STATUS
# crossplane-bootstrap    Synced        Healthy
```

### 5️⃣ Aguardar Apps Serem Criadas

```bash
# Watch todas as applications
kubectl get applications -n argocd -w

# Após ~30 segundos, você verá:
# crossplane-bootstrap          Synced        Healthy
# crossplane-providers         OutOfSync     Missing
# aws-provider-configs         OutOfSync     Missing
# platform-apis                OutOfSync     Missing
# governance-namespaces        OutOfSync     Missing
# governance-rbac              OutOfSync     Missing
# environment-dev              OutOfSync     Missing
# environment-hml              OutOfSync     Missing
# environment-prod             OutOfSync     Missing
```

**Pressione Ctrl+C** quando ver as apps aparecerem.

### 6️⃣ Entender a Ordem de Deploy (Sync Waves)

As applications são deployadas nesta ordem automática:

```
Wave 1: Providers (AWS, Azure, GCP)
  ↓ (aguarda providers ficarem HEALTHY)
Wave 2: Provider Configs (Credenciais)
  ↓ (aguarda configs serem criados)
Wave 3: Platform APIs (XRDs + Compositions)
  ↓ (aguarda XRDs ficarem established)
Wave 4: Governance (Namespaces + RBAC)
  ↓ (aguarda recursos serem criados)
Wave 5: Environment Dev (Claims de desenvolvimento)
  ↓
Wave 6: Environment HML (Claims de homologação)
  ↓
Wave 7: Environment Prod (Claims de produção)
```

### 7️⃣ Monitorar Deploy

```bash
# Ver status de todas as apps com suas waves
kubectl get applications -n argocd \
  -o custom-columns=\
NAME:.metadata.name,\
WAVE:.metadata.annotations."argocd\.argoproj\.io/sync-wave",\
SYNC:.status.sync.status,\
HEALTH:.status.health.status \
  --sort-by=.metadata.annotations."argocd\.argoproj\.io/sync-wave"

# Ver detalhes de uma app específica
kubectl describe application crossplane-providers -n argocd

# Ver sync status detalhado
kubectl get applications -n argocd -o json | \
  jq -r '.items[] | "\(.metadata.name): \(.status.sync.status) - \(.status.health.status)"'
```

## 🖥️ Acessar ArgoCD UI

### Opção 1: Port Forward (rápido para testar)

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Abrir browser em: https://localhost:8080
# Username: admin
# Password: (obtido no passo 2)
```

### Opção 2: Via Ingress (produção)

Se você configurou um ingress:

```bash
# Ver URL do ingress
kubectl get ingress argocd-server -n argocd

# Acessar via browser usando o ADDRESS mostrado
```

## 📊 Via ArgoCD CLI (opcional)

```bash
# Instalar ArgoCD CLI
# Windows (chocolatey):
choco install argocd-cli

# Linux/Mac:
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login localhost:8080

# Listar applications
argocd app list

# Ver detalhes
argocd app get crossplane-providers

# Sync manual (se necessário)
argocd app sync crossplane-providers

# Ver logs
argocd app logs crossplane-providers
```

## 🔍 Verificação Completa

### Verificar Applications

```bash
# Todas as apps devem estar Synced e Healthy
kubectl get applications -n argocd

# Exemplo de output esperado após 10-15 min:
# NAME                      SYNC      HEALTH
# crossplane-bootstrap      Synced    Healthy
# crossplane-providers     Synced    Healthy
# aws-provider-configs     Synced    Healthy
# platform-apis            Synced    Healthy
# governance-namespaces    Synced    Healthy
# governance-rbac          Synced    Healthy
# environment-dev          Synced    Healthy
```

### Verificar Crossplane

```bash
# Pods do Crossplane
kubectl get pods -n crossplane-system

# Providers instalados e HEALTHY
kubectl get providers

# Output esperado:
# NAME                   INSTALLED   HEALTHY   PACKAGE                               AGE
# provider-aws           True        True      xpkg.upbound.io/upbound/provider-aws  5m

# XRDs disponíveis
kubectl get xrd

# Output esperado:
# NAME                              ESTABLISHED   OFFERED   AGE
# xbuckets.platform.example.com     True          True      3m
# xdatabases.platform.example.com   True          True      3m
# xnetworks.platform.example.com    True          True      3m

# Compositions disponíveis
kubectl get composition

# Output esperado:
# NAME                                 XR-KIND    XR-APIVERSION                     AGE
# xbuckets.aws.platform.example.com    XBucket    platform.example.com/v1alpha1    3m
```

### Verificar Governance

```bash
# Namespaces criados
kubectl get namespaces | grep -E 'dev|hlm|prod'

# RBAC configurado
kubectl get clusterroles | grep crossplane

# Output esperado:
# crossplane-viewer
# crossplane-platform-admin
# crossplane-claim-creator
```

## 🔄 Fluxo de Trabalho GitOps

### Como Fazer Mudanças

```bash
# 1. Editar arquivos localmente
# Exemplo: adicionar novo claim
vim environments/dev/claims/my-new-bucket.yaml

# 2. Commit e push
git add .
git commit -m "Add new bucket claim"
git push origin main

# 3. ArgoCD detecta mudança automaticamente (< 3 min)
# Ou force sync:
argocd app sync environment-dev

# 4. Verificar aplicação
kubectl get bucket -n dev
```

### Adicionar Nova Application

1. **Criar arquivo** em `argocd/applications/`:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-new-app
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: platform
  source:
    repoURL: https://github.com/samuelBarreto/crossplane-platform.git
    targetRevision: main
    path: path/to/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

2. **Commit e push**:

```bash
git add argocd/applications/my-new-app.yaml
git commit -m "Add new application"
git push
```

3. **ArgoCD detecta e cria automaticamente** (via bootstrap app)

## 🐛 Troubleshooting

### App não sincroniza

```bash
# Ver detalhes do erro
kubectl describe application crossplane-providers -n argocd

# Ver logs do application controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100

# Force refresh
argocd app get crossplane-providers --refresh

# Force sync
argocd app sync crossplane-providers --force
```

### App fica em "OutOfSync"

```bash
# Ver o que está diferente
argocd app diff crossplane-providers

# Auto-sync não habilitado?
kubectl patch application crossplane-providers -n argocd \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

### Provider não instala

```bash
# Verificar se Crossplane está rodando
kubectl get pods -n crossplane-system

# Verificar events do provider
kubectl get events -n crossplane-system --sort-by='.lastTimestamp'

# Verificar logs do Crossplane
kubectl logs -n crossplane-system -l app=crossplane --tail=50

# Verificar configuração do provider
kubectl describe provider provider-aws
```

### Claims ficam em Pending

```bash
# Verificar se XRD existe
kubectl get xrd

# Verificar se Composition existe
kubectl get composition

# Verificar se ProviderConfig está configurado
kubectl get providerconfig

# Ver detalhes do claim
kubectl describe bucket -n dev <bucket-name>

# Ver eventos
kubectl get events -n dev --sort-by='.lastTimestamp'
```

## 📚 Estrutura Detalhada dos Arquivos

### bootstrap/bootstrap-app.yaml

**Propósito**: App of Apps - Cria todas as outras applications

**Key Points**:
- `source.path: applications` - Lê todos os YAMLs da pasta applications
- `automated: true` - Sincroniza automaticamente
- `prune: true` - Remove recursos deletados do Git
- `selfHeal: true` - Corrige drift

### projects/*.yaml

**Propósito**: Separação de permissões e recursos

**platform-project.yaml**:
- Acesso total para Platform Team
- Pode criar recursos cluster-scoped
- Gerencia Crossplane, Providers, APIs

**tenant-project.yaml**:
- Acesso restrito para Developers
- Apenas resources namespace-scoped
- Apenas criar Claims

### applications/*.yaml

**Propósito**: Declaração de cada componente da plataforma

**Padrão**:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "N"  # Ordem de deploy
spec:
  project: platform  # Qual projeto
  source:
    path: caminho/no/repo  # Onde estão os manifests
  syncPolicy:
    automated: {}  # Auto-sync
```

### applicationsets/*.yaml

**Propósito**: Gerar múltiplas applications dinamicamente

**environment-claims.yaml**:
- Cria uma app para cada ambiente (dev, hlm, prod)
- Sync automático de claims por ambiente
- Multi-tenant ready

## 🎯 Comandos Úteis

```bash
# Status geral
kubectl get applications -n argocd

# Status com waves
kubectl get applications -n argocd \
  -o custom-columns=NAME:.metadata.name,WAVE:.metadata.annotations."argocd\.argoproj\.io/sync-wave",SYNC:.status.sync.status,HEALTH:.status.health.status \
  --sort-by=.metadata.annotations."argocd\.argoproj\.io/sync-wave"

# Sync todas as apps
argocd app sync -l app.kubernetes.io/instance=crossplane-bootstrap

# Ver histórico de sync
argocd app history crossplane-providers

# Rollback
argocd app rollback crossplane-providers

# Delete application (mantém recursos)
kubectl delete application crossplane-providers -n argocd

# Delete application (remove recursos)
argocd app delete crossplane-providers --cascade
```

## 🔐 Best Practices

1. ✅ **Use App of Apps** - Gerencia tudo de um ponto
2. ✅ **Use Sync Waves** - Controla ordem de deploy
3. ✅ **Use Projects** - Separa permissões
4. ✅ **Enable Auto-Sync** - GitOps verdadeiro
5. ✅ **Enable Self-Heal** - Corrige drift automaticamente
6. ✅ **Enable Prune** - Remove recursos órfãos
7. ✅ **Use Git como Source of Truth** - Nunca aplique `kubectl apply` manualmente (exceto para Crossplane e ArgoCD)
8. ✅ **Instale Crossplane e ArgoCD manualmente** - São os únicos componentes que precisam de instalação manual

## 📝 Resumo da Instalação

1. **Manual (uma vez)**:
   - Instalar Crossplane via Helm
   - Instalar ArgoCD
   - Aplicar Projects
   - Aplicar Bootstrap

2. **Automático (via ArgoCD)**:
   - Providers
   - Provider Configs
   - Platform APIs
   - Governance
   - Environments

## 🆘 Precisa de Ajuda?

- **Logs do ArgoCD**: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100`
- **Events**: `kubectl get events -n argocd --sort-by='.lastTimestamp'`
- **ArgoCD UI**: Melhor forma de debugar visualmente
- **Docs**: https://argo-cd.readthedocs.io/

---

**Resumo**: 
1. Instale Crossplane e ArgoCD manualmente
2. Execute `kubectl apply -f argocd/projects/`
3. Execute `kubectl apply -f argocd/bootstrap/bootstrap-app.yaml` 
4. ArgoCD cuida do resto! 🚀
