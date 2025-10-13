# 🚀 Applications para Environments - Quick Start

## ✅ Arquivos Criados

### Applications Individuais
1. ✅ `07-environment-dev.yaml` - Application para dev/claims/
2. ✅ `08-environment-prod.yaml` - Application para prod/claims/

### ApplicationSet
3. ✅ `environments-appset.yaml` - Gerencia dev, prod e hlm automaticamente

### Documentação
4. ✅ `ENVIRONMENTS-APPS.md` - Guia completo de uso
5. ✅ `GITOPS-WORKFLOW.md` - Workflows e arquitetura

## 🎯 Repositórios Necessários

Você precisa ter esses repositórios no GitHub:

| Repositório | URL | Conteúdo |
|------------|-----|----------|
| **environments** | https://github.com/samuelBarreto/environments.git | Claims por ambiente |
| **crossplane-system** | https://github.com/samuelBarreto/crossplane-system.git | Core, Providers |
| **platform-apis** | https://github.com/samuelBarreto/platform-apis.git | XRDs, Compositions |
| **governance** | https://github.com/samuelBarreto/governance.git | Policies, RBAC |

## 📁 Estrutura do Repositório Environments

```bash
# Criar estrutura
mkdir -p environments/{dev,prod,hlm}/claims
cd environments

# Copiar claims existentes
cp ../crossplane/environments/dev/claims/*.yaml dev/claims/
cp ../crossplane/environments/prod/claims/*.yaml prod/claims/

# Git
git init
git add .
git commit -m "feat: initial claims"
git remote add origin https://github.com/samuelBarreto/environments.git
git push -u origin main
```

## 🚀 Deploy - Escolha uma Opção

### **Opção 1: Applications Individuais** (Recomendado)

```bash
# Aplicar
kubectl apply -f argocd/applications/07-environment-dev.yaml
kubectl apply -f argocd/applications/08-environment-prod.yaml

# Verificar
kubectl get applications -n argocd | grep environment
```

**Resultado:**
```
NAME              SYNC STATUS   HEALTH STATUS
environment-dev   Synced        Healthy
environment-prod  Synced        Healthy
```

### **Opção 2: ApplicationSet** (Avançado)

```bash
# Aplicar
kubectl apply -f argocd/applicationsets/environments-appset.yaml

# Verificar
kubectl get applicationsets -n argocd
kubectl get applications -n argocd | grep environment
```

**Resultado:**
```
NAME              SYNC STATUS   HEALTH STATUS
environment-dev   Synced        Healthy
environment-prod  Synced        Healthy
environment-hlm   Synced        Healthy
```

## 🔄 Como Usar (GitOps Workflow)

### 1. **Criar um Novo Claim**

```bash
# Clone
git clone https://github.com/samuelBarreto/environments.git
cd environments

# Criar claim
cat > dev/claims/my-database.yaml <<EOF
apiVersion: platform.example.com/v1alpha1
kind: Database
metadata:
  name: my-database
  namespace: dev
  labels:
    environment: dev
    team: backend
  annotations:
    owner: you@example.com
spec:
  engine: postgresql
  engineVersion: "15"
  size: small
  storageGB: 20
  environment: dev
  costCenter: CC-DEVELOPMENT
  owner: you@example.com
EOF

# Commit e Push
git add dev/claims/my-database.yaml
git commit -m "feat: add my-database to dev"
git push origin main
```

### 2. **ArgoCD Sincroniza Automaticamente**

```bash
# Espere 30s-1min ou force sync
argocd app sync environment-dev

# Acompanhe
kubectl get database my-database -n dev -w
```

### 3. **Obter Credenciais**

```bash
# Aguarde ficar Ready
kubectl wait --for=condition=Ready database/my-database -n dev --timeout=600s

# Pegue credenciais
kubectl get secret my-database-connection -n dev -o yaml
```

### 4. **Deletar Claim**

```bash
# Remover do Git
git rm dev/claims/my-database.yaml
git commit -m "chore: remove my-database"
git push origin main

# ArgoCD deleta automaticamente (prune: true)
```

## 🌿 Branch Strategies

### **Single Branch (Simples)**
```yaml
targetRevision: main  # Todos ambientes usam main
```

### **Multiple Branches (Avançado)**
```yaml
# Dev
targetRevision: dev

# Prod
targetRevision: prod
```

## 🔍 Troubleshooting

### Application OutOfSync

```bash
# Ver diferenças
argocd app diff environment-dev

# Sync manual
argocd app sync environment-dev
```

### Claim não provisiona

```bash
# 1. Verificar Application
kubectl describe app environment-dev -n argocd

# 2. Verificar Claim
kubectl describe database my-database -n dev

# 3. Ver eventos
kubectl get events -n dev --sort-by='.lastTimestamp'

# 4. Logs Crossplane
kubectl logs -n crossplane-system -l app=crossplane --tail=50
```

## 📊 Monitoramento

```bash
# Ver todas Applications
kubectl get applications -n argocd -l layer=workloads

# Ver Claims por namespace
kubectl get database,bucket,network -n dev
kubectl get database,bucket,network -n prod

# Status de ResourceQuotas
kubectl get resourcequota -A
```

## 🎯 Próximos Passos

1. ✅ Criar repositório `environments` no GitHub
2. ✅ Copiar claims existentes para o repo
3. ✅ Aplicar ArgoCD Project atualizado
4. ✅ Aplicar Applications ou ApplicationSet
5. ✅ Testar criar/deletar claims via Git

## 📚 Documentação Completa

- 📖 [ENVIRONMENTS-APPS.md](./ENVIRONMENTS-APPS.md) - Guia detalhado
- 🔄 [GITOPS-WORKFLOW.md](./GITOPS-WORKFLOW.md) - Workflows e arquitetura
- 📘 [ArgoCD Docs](https://argo-cd.readthedocs.io/)

---

**Dúvidas?** Veja a documentação completa ou abra uma issue!


