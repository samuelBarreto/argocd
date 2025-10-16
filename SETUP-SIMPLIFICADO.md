# 🚀 Setup Simplificado do ArgoCD

## 📝 O que foi simplificado?

✅ **Removido do ArgoCD**:
- Instalação do Crossplane (agora é manual via Helm)
- OPA Gatekeeper e políticas (simplificação da governança)

✅ **O que o ArgoCD gerencia agora**:
- Providers do Crossplane (AWS, Azure, GCP)
- Configurações dos Providers (credenciais)
- Platform APIs (XRDs e Compositions)
- Governança básica (Namespaces e RBAC)
- Environments (Claims de dev, hml, prod)

---

## 🎯 Instalação em 3 Passos

### 1️⃣ Instalar Crossplane (Manual)

```bash
# Adicionar repo do Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Instalar Crossplane
helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  crossplane-stable/crossplane \
  --wait

# Verificar
kubectl get pods -n crossplane-system
kubectl wait --for=condition=Ready pods --all -n crossplane-system --timeout=300s
```

### 2️⃣ Instalar ArgoCD (Manual)

```bash
# Criar namespace
kubectl create namespace argocd

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Obter senha do admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### 3️⃣ Aplicar GitOps (Automático)

```bash
# 1. Aplicar projetos
kubectl apply -f argocd/projects/platform-project.yaml

# 2. IMPORTANTE: Editar bootstrap-app.yaml antes!
#    Alterar repoURL para seu repositório Git

# 3. Aplicar bootstrap (App of Apps)
kubectl apply -f argocd/bootstrap/bootstrap-app.yaml

# 4. Assistir a mágica acontecer
kubectl get applications -n argocd -w
```

---

## 📊 Ordem de Deploy (Sync Waves)

```
Wave 1: Providers (AWS, Azure, GCP)
  ↓ 3-5 minutos (aguarda HEALTHY)
Wave 2: Provider Configs (Credenciais)
  ↓ 30 segundos
Wave 3: Platform APIs (XRDs + Compositions)
  ↓ 1 minuto
Wave 4: Governance (Namespaces + RBAC)
  ↓ 30 segundos
Wave 5: Environment Dev
  ↓ 5-10 minutos
Wave 6: Environment HML
  ↓ 5-10 minutos
Wave 7: Environment Prod
  ↓ 5-10 minutos

Total: ~30-40 minutos após Crossplane instalado
```

---

## 📁 Arquivos do ArgoCD

| Arquivo | Wave | Descrição |
|---------|------|-----------|
| `00-crossplane-providers.yaml` | 1 | Instala providers AWS/Azure/GCP |
| `01-aws-provider-configs.yaml` | 2 | Configura credenciais AWS |
| `02-platform-apis.yaml` | 3 | XRDs (Bucket, Database, Network) |
| `03-governance-namespaces.yaml` | 4 | Namespaces (dev, hlm, prod) |
| `04-governance-rbac.yaml` | 4 | ClusterRoles e permissões |
| `05-environment-dev.yaml` | 5 | Claims de desenvolvimento |
| `06-environment-hml.yaml` | 6 | Claims de homologação |
| `07-environment-prod.yaml` | 7 | Claims de produção |

---

## ✅ Verificação Rápida

```bash
# 1. Verificar applications
kubectl get applications -n argocd

# Esperado: Todas Synced e Healthy após ~40 min

# 2. Verificar providers
kubectl get providers

# Esperado:
# NAME           INSTALLED   HEALTHY   AGE
# provider-aws   True        True      10m

# 3. Verificar XRDs
kubectl get xrd

# Esperado:
# NAME                              ESTABLISHED   OFFERED   AGE
# xbuckets.platform.example.com     True          True      5m
# xdatabases.platform.example.com   True          True      5m
# xnetworks.platform.example.com    True          True      5m

# 4. Verificar claims (exemplo)
kubectl get bucket -n dev
```

---

## 🔧 Troubleshooting Rápido

### Provider não fica HEALTHY

```bash
# Ver logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws --tail=50

# Ver detalhes
kubectl describe provider provider-aws
```

### Claim fica em Pending

```bash
# Ver eventos
kubectl describe bucket -n dev <nome-do-bucket>

# Verificar se XRD existe
kubectl get xrd | grep bucket

# Verificar se Composition existe
kubectl get composition | grep bucket
```

### Application OutOfSync

```bash
# Ver diferenças
argocd app diff <app-name>

# Forçar sync
argocd app sync <app-name> --force

# Ver logs
argocd app logs <app-name>
```

---

## 🎯 Próximos Passos

Após tudo instalado:

1. **Acessar ArgoCD UI**:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Abrir: https://localhost:8080
# User: admin
# Pass: (obtida no passo 2)
```

2. **Criar seu primeiro bucket**:
```bash
kubectl apply -f - <<EOF
apiVersion: platform.example.com/v1alpha1
kind: Bucket
metadata:
  name: my-first-bucket
  namespace: dev
spec:
  environment: dev
  costCenter: ENGINEERING
  owner: seu-email@example.com
  storageClass: standard
  publicAccess: false
  encryption:
    enabled: true
EOF
```

3. **Verificar criação**:
```bash
# Ver claim
kubectl get bucket -n dev my-first-bucket

# Ver bucket S3 real criado
kubectl get bucket.s3.aws.upbound.io
```

---

## 📚 Documentação Completa

- **README Principal**: `argocd/README.md`
- **Ordem de Deploy**: `argocd/applications/ORDEM-DE-DEPLOY.md`
- **Sync Waves**: `argocd/SYNC-WAVES-GUIDE.md`
- **Quickstart Manual**: `docs/quickstart/QUICKSTART-MANUAL.md`
- **Quickstart GitOps**: `docs/quickstart/QUICKSTART-GITOPS.md`

---

## 🎉 Resumo

**Antes**: 
- Instalar Crossplane via ArgoCD
- Instalar Gatekeeper via ArgoCD
- Configurar políticas complexas
- ~1h de setup

**Agora**:
- Instalar Crossplane e ArgoCD manualmente (5 min)
- ArgoCD gerencia o resto automaticamente (35 min)
- Total: ~40 minutos
- Menos complexo, mais fácil de debugar

**Comando único após instalação manual**:
```bash
kubectl apply -f argocd/bootstrap/bootstrap-app.yaml
```

E pronto! 🚀

