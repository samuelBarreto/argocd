# Governance Setup - ArgoCD Applications

## 📋 Estrutura de Applications

O Governance foi dividido em **5 Applications** com **Sync Waves** para garantir a ordem correta:

```
Wave 0: governance-gatekeeper    → Instala OPA Gatekeeper
  ↓
Wave 1: governance-policies      → ConstraintTemplates + Constraints
  ↓
Wave 2: governance-namespaces    → Cria namespaces (dev, hlm, prod)
  ↓
Wave 3: governance-quotas        → ResourceQuotas por namespace
  ↓
Wave 4: governance-rbac          → ClusterRoles e permissões
```

---

## 🚀 Como Aplicar

### Opção 1: Aplicar todas de uma vez

```bash
# Aplicar todas as applications de governance
kubectl apply -f argocd/applications/06-governance-gatekeeper.yaml
kubectl apply -f argocd/applications/07-governance-policies.yaml
kubectl apply -f argocd/applications/08-governance-namespaces.yaml
kubectl apply -f argocd/applications/09-governance-quotas.yaml
kubectl apply -f argocd/applications/10-governance-rbac.yaml

# Monitorar
kubectl get applications -n argocd | grep governance
```

### Opção 2: Via Bootstrap (App of Apps)

Se estiver usando o bootstrap, apenas adicione as applications ao bootstrap e ele criará tudo automaticamente.

---

## ⚙️ Configuração Necessária

### 1. Criar Repositório Git

Você precisa criar o repositório: `https://github.com/samuelBarreto/governance.git`

**Estrutura do repositório:**
```
governance/
├── policies/           # ConstraintTemplates e Constraints
│   ├── require-labels.yaml
│   ├── require-cost-center.yaml
│   ├── restrict-cloud-regions.yaml
│   └── prevent-public-resources.yaml
├── namespaces/         # Definições de namespaces
│   ├── namespace-dev.yaml
│   ├── namespace-hlm.yaml
│   └── namespace-prod.yaml
├── quotas/             # ResourceQuotas
│   ├── resource-quotas-dev.yaml
│   ├── resource-quotas-hlm.yaml
│   └── resource-quotas-prod.yaml
└── rbac/               # ClusterRoles
    └── crossplane-viewer-role.yaml
```

### 2. Atualizar repoURL

Em cada arquivo de application (`06-` até `10-`), atualize:

```yaml
source:
  repoURL: https://github.com/SEU_USUARIO/governance.git  # <-- ALTERAR
  targetRevision: main
```

---

## 🔍 Sync Waves Explicadas

| Wave | Application | Descrição | Aguarda |
|------|-------------|-----------|---------|
| **0** | `governance-gatekeeper` | Instala CRDs do Gatekeeper | Pods Ready |
| **1** | `governance-policies` | Cria ConstraintTemplates | 10s delay |
| **2** | `governance-namespaces` | Cria namespaces | - |
| **3** | `governance-quotas` | Aplica quotas nos namespaces | Namespaces existirem |
| **4** | `governance-rbac` | Configura permissões | - |

### Por que Sync Waves?

**Sem Sync Waves:**
```
❌ ResourceQuota aplicado antes do namespace existir
❌ Constraint aplicado antes do ConstraintTemplate
❌ Tudo falha!
```

**Com Sync Waves:**
```
✅ Ordem garantida automaticamente
✅ Retry automático se falhar
✅ Dependências respeitadas
```

---

## 🎯 Verificação

Após aplicar, verifique:

```bash
# 1. Ver applications
kubectl get applications -n argocd | grep governance

# 2. Ver Gatekeeper
kubectl get pods -n gatekeeper-system

# 3. Ver ConstraintTemplates
kubectl get constrainttemplates

# 4. Ver Constraints
kubectl get constraints

# 5. Ver Namespaces
kubectl get namespaces dev hlm prod

# 6. Ver ResourceQuotas
kubectl get resourcequota -A

# 7. Ver RBAC
kubectl get clusterrole | grep crossplane
```

**Status esperado:**
```
NAME                         SYNC STATUS   HEALTH STATUS
governance-gatekeeper        Synced        Healthy
governance-policies          Synced        Healthy
governance-namespaces        Synced        Healthy
governance-quotas            Synced        Healthy
governance-rbac              Synced        Healthy
```

---

## 🧪 Testar Policies

```bash
# Tentar criar pod SEM labels obrigatórias (deve FALHAR)
kubectl run test-bad --image=nginx -n dev

# Criar pod COM labels obrigatórias (deve PASSAR)
kubectl run test-good --image=nginx \
  --labels="environment=dev,cost-center=engineering,managed-by=test" \
  -n dev
```

---

## 🗑️ Remover Tudo

```bash
# Deletar applications (ArgoCD remove os recursos)
kubectl delete -f argocd/applications/10-governance-rbac.yaml
kubectl delete -f argocd/applications/09-governance-quotas.yaml
kubectl delete -f argocd/applications/08-governance-namespaces.yaml
kubectl delete -f argocd/applications/07-governance-policies.yaml
kubectl delete -f argocd/applications/06-governance-gatekeeper.yaml
```

---

## 📝 Customização

### Adicionar nova policy

1. Criar arquivo em `governance/policies/nova-policy.yaml`
2. Fazer commit e push no Git
3. ArgoCD aplica automaticamente (se auto-sync estiver ativo)

### Modificar quotas

1. Editar arquivo em `governance/quotas/`
2. Commit e push
3. ArgoCD sincroniza automaticamente

---

## ⚠️ Notas Importantes

1. **Gatekeeper é obrigatório** - Sem ele, nada funciona
2. **Ordem importa** - Use sempre as Sync Waves
3. **Aguardar Gatekeeper** - Pode levar 1-2 min para ficar pronto
4. **ConstraintTemplates** - Precisam de ~10s para processar
5. **Namespaces** - `prune: false` para evitar deleção acidental

