# Environment Applications - ArgoCD

Aplicações ArgoCD para gerenciar Claims do Crossplane por ambiente usando o repositório [environments](https://github.com/samuelBarreto/environments.git).

## 📁 Estrutura do Repositório Environments

```
environments/
├── dev/
│   └── claims/
│       ├── example-database.yaml
│       └── example-bucket.yaml
├── prod/
│   └── claims/
│       └── example-database.yaml
└── hlm/
    └── claims/
```

## 🎯 Duas Abordagens

### **Opção 1: Applications Individuais** (Mais Controle)

Crie uma Application para cada ambiente:

```yaml
# 05-environment-dev.yaml
# 06-environment-hml.yaml
# 07-environment-prod.yaml
```

**Vantagens:**
- ✅ Controle granular por ambiente
- ✅ Sync policies diferentes por ambiente
- ✅ Fácil de entender e debugar

**Aplicar:**
```bash
kubectl apply -f argocd/applications/05-environment-dev.yaml
kubectl apply -f argocd/applications/06-environment-hml.yaml
kubectl apply -f argocd/applications/07-environment-prod.yaml
```

---

### **Opção 2: ApplicationSet** (Automação)

Use um ApplicationSet para gerar Applications automaticamente:

```yaml
# applicationsets/environments-appset.yaml
```

**Vantagens:**
- ✅ Um arquivo gerencia todos os ambientes
- ✅ Fácil adicionar novos ambientes
- ✅ Suporte a branches diferentes por ambiente

**Aplicar:**
```bash
kubectl apply -f argocd/applicationsets/environments-appset.yaml
```

## 🌿 Estratégias de Branches

### **Branch Única (Recomendado para começar)**

```yaml
# Todos ambientes usam a mesma branch
- environment: dev
  branch: main
  
- environment: prod
  branch: main
```

### **Branches Separadas (Produção Avançada)**

```yaml
# Cada ambiente tem sua branch
- environment: dev
  branch: dev
  
- environment: prod
  branch: prod
```

**Workflow:**
1. Desenvolver em `dev` branch
2. Testar no ambiente dev
3. Merge para `main` ou `staging`
4. Merge para `prod` quando aprovado

## 📋 Como Usar

### 1. **Preparar o Repositório**

```bash
# Clonar o repositório environments
git clone https://github.com/samuelBarreto/environments.git
cd environments

# Estrutura necessária
mkdir -p dev/claims prod/claims hlm/claims

# Adicionar claims de exemplo
cp ../crossplane/environments/dev/claims/*.yaml dev/claims/
cp ../crossplane/environments/prod/claims/*.yaml prod/claims/

# Commit e push
git add .
git commit -m "feat: add initial claims"
git push origin main
```

### 2. **Aplicar ArgoCD Project Atualizado**

```bash
kubectl apply -f argocd/projects/platform-project.yaml
```

### 3. **Escolher Abordagem**

**Opção A: Applications Individuais**
```bash
kubectl apply -f argocd/applications/05-environment-dev.yaml
kubectl apply -f argocd/applications/06-environment-hml.yaml
kubectl apply -f argocd/applications/07-environment-prod.yaml
```

**Opção B: ApplicationSet**
```bash
kubectl apply -f argocd/applicationsets/environments-appset.yaml
```

### 4. **Verificar Applications**

```bash
# Listar applications
kubectl get applications -n argocd

# Ver detalhes
kubectl describe application environment-dev -n argocd

# Via ArgoCD CLI
argocd app list
argocd app get environment-dev
```

## 🔄 GitOps Workflow

### **Criar um Novo Claim**

```bash
# 1. Editar/criar claim no Git
cd environments/dev/claims/
cat > new-database.yaml <<EOF
apiVersion: platform.example.com/v1alpha1
kind: Database
metadata:
  name: new-app-db
  namespace: dev
  labels:
    environment: dev
    team: backend-team
  annotations:
    owner: team@example.com
spec:
  engine: postgresql
  engineVersion: "15"
  size: small
  storageGB: 20
  environment: dev
  costCenter: CC-DEVELOPMENT
  owner: team@example.com
EOF

# 2. Commit e Push
git add new-database.yaml
git commit -m "feat: add new-app-db to dev"
git push origin main

# 3. ArgoCD sincroniza automaticamente (automated: true)
# Ou sincronize manualmente:
argocd app sync environment-dev
```

### **Promover de Dev → Prod**

```bash
# 1. Testar em dev primeiro
kubectl get database new-app-db -n dev
kubectl describe database new-app-db -n dev

# 2. Copiar para prod (com ajustes)
cp dev/claims/new-database.yaml prod/claims/
# Editar: mudar namespace, size, etc.

# 3. Commit
git add prod/claims/new-database.yaml
git commit -m "feat: promote new-app-db to production"
git push origin main

# 4. ArgoCD aplica automaticamente
```

### **Deletar um Claim**

```bash
# 1. Remover do Git
git rm dev/claims/old-database.yaml
git commit -m "chore: remove old-database from dev"
git push origin main

# 2. ArgoCD remove automaticamente (prune: true)
```

## ⚙️ Configurações Importantes

### **Sync Policy**

```yaml
syncPolicy:
  automated:
    prune: true       # ✅ Remove recursos deletados do Git
    selfHeal: true    # ✅ Corrige drift automaticamente
```

### **Ignore Differences**

```yaml
ignoreDifferences:
- group: platform.example.com
  kind: Database
  jsonPointers:
  - /status  # Ignora mudanças em status (Crossplane gerencia)
```

### **Sync Waves**

```yaml
annotations:
  argocd.argoproj.io/sync-wave: "10"  # Depois de platform-apis (wave 5)
```

**Ordem de Deploy:**
1. Wave 0: Crossplane Core
2. Wave 1: Providers
3. Wave 2: Provider Configs
4. Wave 3-5: Platform APIs (XRDs, Compositions)
5. **Wave 10: Environment Claims** ← Aqui

## 🔍 Troubleshooting

### Application OutOfSync

```bash
# Ver diferenças
argocd app diff environment-dev

# Forçar sync
argocd app sync environment-dev --force
```

### Claim não cria recurso

```bash
# 1. Verificar se Application está Synced
kubectl get app environment-dev -n argocd

# 2. Verificar Claim no cluster
kubectl get database -n dev

# 3. Ver eventos do Claim
kubectl describe database my-db -n dev

# 4. Ver logs do Crossplane
kubectl logs -n crossplane-system -l app=crossplane
```

### Project permission denied

```bash
# Verificar se namespace está permitido
kubectl get appproject platform -n argocd -o yaml

# Adicionar namespace se necessário (já feito no platform-project.yaml)
```

## 📊 Monitoramento

### **Ver todos os Claims**

```bash
# Dev
kubectl get database,bucket,network -n dev

# Prod
kubectl get database,bucket,network -n prod

# Todos
kubectl get database,bucket,network -A
```

### **Status de Sincronização**

```bash
# Via kubectl
kubectl get applications -n argocd -l layer=workloads

# Via ArgoCD CLI
argocd app list --selector layer=workloads

# Dashboard
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080
```

## 🎯 Best Practices

1. ✅ **Use Git como source of truth**
   - Sempre faça mudanças via Git, não kubectl apply direto

2. ✅ **Branch strategy**
   - Dev: desenvolvimento ativo
   - Main/Staging: pré-produção
   - Prod: produção (protegida)

3. ✅ **Pull Requests**
   - Crie PRs para mudanças em prod
   - Review antes de merge
   - Use GitHub Actions para validar YAMLs

4. ✅ **Separação de ambientes**
   - Cada ambiente tem seu próprio namespace
   - RBAC apropriado
   - Isolamento de recursos

5. ✅ **Versionamento**
   - Use tags semânticas (v1.0.0)
   - targetRevision pode apontar para tag específica

## 📚 Próximos Passos

1. Configurar GitHub Actions para validar Claims
2. Adicionar testes de policy (OPA/Gatekeeper)
3. Implementar approval gates para prod
4. Configurar notificações (Slack, Teams)
5. Adicionar métricas e dashboards

---

**Documentação relacionada:**
- [ArgoCD Applications](https://argo-cd.readthedocs.io/en/stable/user-guide/application-specification/)
- [ApplicationSets](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [Crossplane Claims](https://docs.crossplane.io/latest/concepts/claims/)

