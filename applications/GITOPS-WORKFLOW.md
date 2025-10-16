# GitOps Workflow - Crossplane com ArgoCD

## 🔄 Arquitetura Completa

```
┌─────────────────────────────────────────────────────────────────┐
│                         Git Repositories                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ crossplane-  │  │  platform-   │  │ environments │          │
│  │   system     │  │     apis     │  │              │          │
│  │              │  │              │  │  dev/claims/ │          │
│  │ - install/   │  │ - xrds/      │  │ prod/claims/ │          │
│  │ - providers/ │  │ - compositions│  │ hlm/claims/  │          │
│  │ - configs/   │  │              │  │              │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Git Pull
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                         ArgoCD                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Wave 0:  crossplane-core                                       │
│           └→ Deployment, RBAC                                   │
│                                                                  │
│  Wave 1:  crossplane-providers                                  │
│           ├→ AWS Providers (EC2, RDS, S3, VPC, IAM)            │
│           ├→ GCP Providers (Compute, SQL, Storage)             │
│           └→ Azure Providers (Compute, DB, Storage, Network)   │
│                                                                  │
│  Wave 2:  provider-configs                                      │
│           ├→ AWS ProviderConfig                                │
│           ├→ GCP ProviderConfig                                │
│           └→ Azure ProviderConfig                              │
│                                                                  │
│  Wave 3-5: platform-apis                                        │
│           ├→ XRDs (Database, Bucket, Network)                  │
│           └→ Compositions (AWS, GCP, Azure variants)           │
│                                                                  │
│  Wave 10: environment-dev                                       │
│           └→ Dev Claims                                         │
│                                                                  │
│  Wave 10: environment-prod                                      │
│           └→ Prod Claims                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Apply
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Namespace: crossplane-system                                   │
│  ├─ Crossplane Core                                            │
│  ├─ AWS Providers                                              │
│  ├─ GCP Providers                                              │
│  └─ Azure Providers                                            │
│                                                                  │
│  Namespace: dev                                                 │
│  ├─ Database Claims                                            │
│  ├─ Bucket Claims                                              │
│  └─ Network Claims                                             │
│                                                                  │
│  Namespace: prod                                                │
│  ├─ Database Claims                                            │
│  ├─ Bucket Claims                                              │
│  └─ Network Claims                                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Provision
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Cloud Providers                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   AWS                    GCP                    Azure           │
│  ┌──────┐             ┌──────┐              ┌──────┐          │
│  │ RDS  │             │Cloud │              │Azure │          │
│  │      │             │ SQL  │              │  DB  │          │
│  └──────┘             └──────┘              └──────┘          │
│  ┌──────┐             ┌──────┐              ┌──────┐          │
│  │  S3  │             │Cloud │              │Blob  │          │
│  │      │             │Storage│             │Storage│         │
│  └──────┘             └──────┘              └──────┘          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Developer Workflow

### **Criar Nova Database em Dev**

```bash
# 1. Clone o repositório environments
git clone https://github.com/samuelBarreto/environments.git
cd environments

# 2. Crie o claim
cat > dev/claims/my-new-db.yaml <<EOF
apiVersion: platform.example.com/v1alpha1
kind: Database
metadata:
  name: my-new-db
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

# 3. Commit e Push
git add dev/claims/my-new-db.yaml
git commit -m "feat: add my-new-db to dev"
git push origin main

# 4. Aguarde ArgoCD sincronizar (30s-1min)
# Ou force sync:
argocd app sync environment-dev

# 5. Acompanhe criação
kubectl get database my-new-db -n dev -w

# 6. Quando Ready, pegue credenciais
kubectl get secret my-new-db-connection -n dev -o yaml
```

### **Promover para Produção**

```bash
# 1. Ajustar configurações para prod
cp dev/claims/my-new-db.yaml prod/claims/

# 2. Editar prod/claims/my-new-db.yaml
vim prod/claims/my-new-db.yaml
# Mudar:
#   - namespace: dev → prod
#   - size: small → large
#   - storageGB: 20 → 100
#   - highAvailability: false → true
#   - environment: dev → prod
#   - costCenter: CC-DEVELOPMENT → CC-PRODUCTION

# 3. Commit via Pull Request
git checkout -b promote-my-new-db-prod
git add prod/claims/my-new-db.yaml
git commit -m "feat: promote my-new-db to production"
git push origin promote-my-new-db-prod

# 4. Criar PR no GitHub
# 5. Review e Approval
# 6. Merge para main
# 7. ArgoCD aplica automaticamente
```

## 🔄 Continuous Deployment Flow

```
Developer                Git Repository           ArgoCD              Kubernetes          Cloud
    │                         │                      │                    │                 │
    │  1. git commit          │                      │                    │                 │
    ├────────────────────────>│                      │                    │                 │
    │                         │                      │                    │                 │
    │  2. git push            │                      │                    │                 │
    ├────────────────────────>│                      │                    │                 │
    │                         │                      │                    │                 │
    │                         │  3. Poll (30s)       │                    │                 │
    │                         │<─────────────────────┤                    │                 │
    │                         │                      │                    │                 │
    │                         │  4. Detect Change    │                    │                 │
    │                         ├─────────────────────>│                    │                 │
    │                         │                      │                    │                 │
    │                         │                      │  5. kubectl apply  │                 │
    │                         │                      ├───────────────────>│                 │
    │                         │                      │                    │                 │
    │                         │                      │                    │  6. Provision   │
    │                         │                      │                    ├────────────────>│
    │                         │                      │                    │                 │
    │                         │                      │                    │  7. Resource    │
    │                         │                      │                    │     Ready       │
    │                         │                      │                    │<────────────────┤
    │                         │                      │                    │                 │
    │  8. Notification        │                      │                    │                 │
    │<────────────────────────┼──────────────────────┼────────────────────┤                 │
    │                         │                      │                    │                 │
```

## 📁 Repository Structure

### **environments Repository**

```
environments/
├── .github/
│   └── workflows/
│       ├── validate-dev.yaml      # Valida claims de dev
│       ├── validate-prod.yaml     # Valida claims de prod
│       └── promote-to-prod.yaml   # Workflow de promoção
│
├── dev/
│   └── claims/
│       ├── api-database.yaml
│       ├── api-storage.yaml
│       └── cache-database.yaml
│
├── prod/
│   └── claims/
│       ├── api-database.yaml      # Configurações prod
│       └── api-storage.yaml
│
├── hlm/                            # Homologação/Staging
│   └── claims/
│       └── api-database.yaml
│
└── README.md
```

## 🎯 Branch Strategies

### **Strategy 1: Single Branch (Simples)**

```
main
├── dev/claims/
├── prod/claims/
└── staging/claims/
```

**Pros:**
- ✅ Simples de gerenciar
- ✅ Histórico unificado
- ✅ Fácil comparar ambientes

**Cons:**
- ❌ Todos ambientes sempre em sync
- ❌ Difícil testar mudanças isoladamente

### **Strategy 2: Environment Branches (Avançado)**

```
dev ────────────────> staging ────────────> prod
 │                        │                    │
 └─ dev/claims/          └─ dev/claims/       └─ dev/claims/
                            staging/claims/       prod/claims/
```

**Workflow:**
1. Desenvolver em `dev` branch
2. Merge `dev` → `staging` quando estável
3. Testar em staging
4. Merge `staging` → `prod` com aprovação

**Pros:**
- ✅ Isolamento entre ambientes
- ✅ Testar mudanças em staging primeiro
- ✅ Rollback fácil

**Cons:**
- ❌ Mais complexo
- ❌ Precisa sincronizar branches

### **Strategy 3: GitFlow (Produção)**

```
main (prod)
  │
  ├─ release/v1.0.0
  │    └─ staging
  │
  ├─ feature/new-database
  │    └─ dev
  │
  └─ hotfix/critical-fix
       └─ prod
```

## 🔐 Security & Governance

### **1. Pull Request Requirements (Prod)**

```yaml
# .github/workflows/validate-prod.yaml
name: Validate Production Claims

on:
  pull_request:
    paths:
      - 'prod/claims/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Validate YAML
        run: |
          # Validate syntax
          yamllint prod/claims/
          
      - name: Check Labels
        run: |
          # Ensure governance labels
          
      - name: Policy Check
        run: |
          # OPA/Conftest validation
          
      - name: Cost Estimation
        run: |
          # Estimate cloud costs
```

### **2. RBAC**

```yaml
# Developers: Podem criar claims em dev
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developers-claim-creators
  namespace: dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: crossplane-claim-creator
subjects:
- kind: Group
  name: developers

---
# Platform Team: Full access
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-team-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: crossplane-platform-admin
subjects:
- kind: Group
  name: platform-team
```

### **3. RBAC e Permissões**

```bash
# Ver ClusterRoles configurados
kubectl get clusterroles | grep crossplane

# Ver permissões
# Prod: 20 DBs, 50 Buckets
```

## 📊 Monitoring & Observability

### **ArgoCD Notifications**

```yaml
# argocd-notifications-cm
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  
  template.app-deployed: |
    message: |
      {{.app.metadata.name}} deployed to {{.context.environment}}
      Revision: {{.app.status.sync.revision}}
  
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
```

### **Metrics**

```bash
# Claims por ambiente
kubectl get database,bucket -n dev --no-headers | wc -l
kubectl get database,bucket -n prod --no-headers | wc -l

# Status
kubectl get database -A -o json | jq '.items[] | {name:.metadata.name, ready:.status.conditions[] | select(.type=="Ready") | .status}'
```

## 🚨 Troubleshooting

### **Claim não sincroniza**

```bash
# 1. Verificar Application
kubectl get app environment-dev -n argocd

# 2. Ver logs do ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# 3. Forçar sync
argocd app sync environment-dev --force --prune
```

### **Permission Denied**

```bash
# Verificar AppProject
kubectl get appproject platform -n argocd -o yaml

# Adicionar namespace se necessário (já feito)
```

---

**Próximos Passos:**
1. Configurar GitHub Actions para validação
2. Implementar approval process para prod
3. Adicionar cost tracking
4. Configurar alertas e notificações

