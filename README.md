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
│   ├── 01-crossplane-core.yaml     # Instala Crossplane
│   ├── 02-crossplane-providers.yaml # Instala Providers (AWS, Azure, GCP)
│   ├── 03-provider-configs.yaml    # Configura credenciais
│   ├── 04-platform-apis.yaml       # Instala XRDs e Compositions
│   ├── 05-governance.yaml          # Instala Policies
│   └── 06-argocd-ingress.yaml      # Expõe ArgoCD (opcional)
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
│ Crossplane   │ │Providers │ │Platform    │
│   Core       │ │          │ │  APIs      │
└──────────────┘ └──────────┘ └────────────┘
```

## 🚀 Setup Completo - Passo a Passo

### 📋 Pré-requisitos

```bash
# 1. Cluster Kubernetes rodando
kubectl cluster-info

# 2. ArgoCD instalado
kubectl get pods -n argocd

# 3. kubectl configurado
kubectl config current-context
```

### 1️⃣ Instalar ArgoCD (se não estiver instalado)

```bash
# Criar namespace
kubectl create namespace argocd

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar pods ficarem Ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Obter senha inicial
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

kubectl port-forward -n argocd svc/argocd-server 8080:443
```

### 2️⃣ Aplicar AppProjects (Separação de Permissões)

```bash
# Aplicar projetos
kubectl apply -f argocd/projects/

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

### 3️⃣ Aplicar Bootstrap (App of Apps)

```bash
# Este é o ÚNICO comando manual necessário!
kubectl apply -f argocd/bootstrap/bootstrap-app.yaml

# Verificar criação
kubectl get application -n argocd

# Output esperado:
# NAME                    SYNC STATUS   HEALTH STATUS
# crossplane-bootstrap    Synced        Healthy
```

### 4️⃣ Aguardar Apps Serem Criadas

```bash
# Watch todas as applications
kubectl get applications -n argocd -w

# Após ~30 segundos, você verá:
# crossplane-bootstrap          Synced        Healthy
# crossplane-core              Synced        Progressing
# crossplane-providers         OutOfSync     Missing
# provider-configs             OutOfSync     Missing
# platform-apis                OutOfSync     Missing
# governance-policies          OutOfSync     Missing
```

**Pressione Ctrl+C** quando ver as apps aparecerem.

### 5️⃣ Entender a Ordem de Deploy (Sync Waves)

As applications são deployadas nesta ordem automática:

```
Wave 0: ArgoCD Ingress (se configurado)
  ↓
Wave 1: Crossplane Core
  ↓
Wave 2: Providers (AWS, Azure, GCP)
  ↓
Wave 3: Provider Configs (Credenciais)
  ↓
Wave 4: Platform APIs (XRDs + Compositions)
  ↓
Wave 5: Governance (Policies, Quotas, RBAC)
  ↓
Wave 10-12: Environment Claims (dev, hlm, prod)
```

### 6️⃣ Monitorar Deploy

```bash
# Ver status de todas as apps
kubectl get applications -n argocd

# Ver detalhes de uma app específica
kubectl describe application crossplane-core -n argocd

# Ver sync status
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
# Password: (do passo 1)
```

### Opção 2: Via Ingress (produção)

Se você configurou o ingress (arquivo 06-argocd-ingress.yaml):

```bash
# Ver URL do ALB
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
argocd app get crossplane-core

# Sync manual (se necessário)
argocd app sync crossplane-core

# Ver logs
argocd app logs crossplane-core
```

## 🔍 Verificação Completa

### Verificar Applications

```bash
# Todas as apps devem estar Synced e Healthy
kubectl get applications -n argocd

# Exemplo de output esperado após 10-15 min:
# NAME                      SYNC      HEALTH
# crossplane-bootstrap      Synced    Healthy
# crossplane-core          Synced    Healthy
# crossplane-providers     Synced    Healthy
# provider-configs         Synced    Healthy
# platform-apis            Synced    Healthy
# governance-policies      Synced    Healthy
```

### Verificar Crossplane

```bash
# Pods do Crossplane
kubectl get pods -n crossplane-system

# Providers instalados
kubectl get providers

# XRDs disponíveis
kubectl get xrd

# Compositions disponíveis
kubectl get composition
```

### Verificar Governance

```bash
# Policies instaladas
kubectl get constrainttemplates

# Constraints aplicados
kubectl get constraints

# Resource quotas
kubectl get resourcequota -A
```

## 🔄 Fluxo de Trabalho GitOps

### Como Fazer Mudanças

```bash
# 1. Editar arquivos localmente
# Exemplo: adicionar novo provider
vim crossplane-system/providers/provider-aws.yaml

# 2. Commit e push
git add .
git commit -m "Add new AWS provider"
git push origin main

# 3. ArgoCD detecta mudança automaticamente (< 3 min)
# Ou force sync:
argocd app sync crossplane-providers

# 4. Verificar aplicação
kubectl get providers
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
    argocd.argoproj.io/sync-wave: "10"
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
kubectl describe application crossplane-core -n argocd

# Ver logs do application controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Force refresh
argocd app get crossplane-core --refresh

# Force sync
argocd app sync crossplane-core --force
```

### App fica em "OutOfSync"

```bash
# Ver o que está diferente
argocd app diff crossplane-core

# Auto-sync não habilitado?
kubectl patch application crossplane-core -n argocd \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
```

### Provider não instala

```bash
# Verificar se Crossplane está rodando
kubectl get pods -n crossplane-system

# Verificar events
kubectl get events -n crossplane-system --sort-by='.lastTimestamp'

# Verificar logs do Crossplane
kubectl logs -n crossplane-system -l app=crossplane
```

## 📚 Estrutura Detalhada dos Arquivos

### bootstrap/bootstrap-app.yaml

**Propósito**: App of Apps - Cria todas as outras applications

**Key Points**:
- `source.path: argocd/applications` - Lê todos os YAMLs dessa pasta
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

# Sync todas as apps
argocd app sync -l app.kubernetes.io/instance=crossplane-bootstrap

# Ver histórico de sync
argocd app history crossplane-core

# Rollback
argocd app rollback crossplane-core

# Delete application (mantém recursos)
kubectl delete application crossplane-core -n argocd

# Delete application (remove recursos)
argocd app delete crossplane-core --cascade
```

## 🔐 Best Practices

1. ✅ **Use App of Apps** - Gerencia tudo de um ponto
2. ✅ **Use Sync Waves** - Controla ordem de deploy
3. ✅ **Use Projects** - Separa permissões
4. ✅ **Enable Auto-Sync** - GitOps verdadeiro
5. ✅ **Enable Self-Heal** - Corrige drift automaticamente
6. ✅ **Enable Prune** - Remove recursos órfãos
7. ✅ **Use Git como Source of Truth** - Nunca aplique `kubectl apply` manualmente

## 🆘 Precisa de Ajuda?

- **Logs do ArgoCD**: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`
- **Events**: `kubectl get events -n argocd --sort-by='.lastTimestamp'`
- **ArgoCD UI**: Melhor forma de debugar visualmente
- **Docs**: https://argo-cd.readthedocs.io/

---

**Resumo**: Você só precisa rodar `kubectl apply -f argocd/bootstrap/bootstrap-app.yaml` e o ArgoCD cuida do resto! 🚀

