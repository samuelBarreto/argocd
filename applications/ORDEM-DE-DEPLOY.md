# Ordem de Deploy das Applications

## 📊 Sync Waves Configuradas:

```
┌──────────────────────────────────────────────────────────────┐
│  Wave 1: Cloud Providers                                     │
├──────────────────────────────────────────────────────────────┤
│  ✅ 00-crossplane-providers.yaml                             │
│     └─ Instala Providers AWS, Azure, GCP                    │
│        Aguarda: Providers HEALTHY=True                       │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 1 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 2: Provider Configurations                             │
├──────────────────────────────────────────────────────────────┤
│  ✅ 01-aws-provider-configs.yaml                             │
│     └─ Configura credenciais e ProviderConfigs              │
│        Aguarda: ProviderConfigs criados                      │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 2 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 3: Platform APIs                                       │
├──────────────────────────────────────────────────────────────┤
│  ✅ 02-platform-apis.yaml                                    │
│     └─ XRDs (Database, Network, Bucket)                     │
│     └─ Compositions (templates de infraestrutura)           │
│        Aguarda: XRDs e Compositions criados                  │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 3 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 4: Governance Resources                               │
├──────────────────────────────────────────────────────────────┤
│  ✅ 03-governance-namespaces.yaml                            │
│  ✅ 04-governance-rbac.yaml                                  │
│     └─ Namespaces (dev, hlm, prod)                         │
│     └─ RBAC Roles                                           │
│        Aguarda: Recursos criados                             │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 4 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 5: Development Environment                            │
├──────────────────────────────────────────────────────────────┤
│  ✅ 05-environment-dev.yaml                                  │
│     └─ Claims de desenvolvimento                            │
│        (Databases, Networks, Buckets)                        │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 5 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 6: Homologation Environment                           │
├──────────────────────────────────────────────────────────────┤
│  ✅ 06-environment-hml.yaml                                  │
│     └─ Claims de homologação                                │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 6 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 7: Production Environment                             │
├──────────────────────────────────────────────────────────────┤
│  ✅ 07-environment-prod.yaml                                 │
│     └─ Claims de produção                                   │
│        (Apenas após dev e hml testados!)                    │
└──────────────────────────────────────────────────────────────┘
```

## ⏱️ Tempo Estimado de Deploy:

| Wave | App | Tempo Estimado | Acumulado |
|------|-----|----------------|-----------|
| 1 | Providers | 3-5 min | 5 min |
| 2 | Provider Configs | 30 seg | 5.5 min |
| 3 | Platform APIs | 1 min | 6.5 min |
| 4 | Governance | 1 min | 7.5 min |
| 5 | Dev Environment | 5-10 min | 17.5 min |
| 6 | HML Environment | 5-10 min | 27.5 min |
| 7 | Prod Environment | 5-10 min | 37.5 min |

**Total**: ~30-40 minutos para deploy completo (após Crossplane instalado)

## 📋 Pré-requisitos Manuais

Antes de executar o ArgoCD, você deve instalar manualmente:

### 1. Crossplane Core
```bash
# Instalar Crossplane via Helm
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

helm install crossplane \
  --namespace crossplane-system \
  --create-namespace \
  crossplane-stable/crossplane \
  --wait

# Verificar instalação
kubectl get pods -n crossplane-system
kubectl get crds | grep crossplane
```

### 2. ArgoCD
```bash
# Instalar ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verificar instalação
kubectl get pods -n argocd

# Obter senha inicial (opcional)
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 🔍 Verificar Ordem de Deploy:

```bash
# Ver waves de todas as apps
kubectl get applications -n argocd \
  -o custom-columns=\
NAME:.metadata.name,\
WAVE:.metadata.annotations."argocd\.argoproj\.io/sync-wave",\
SYNC:.status.sync.status,\
HEALTH:.status.health.status \
  --sort-by=.metadata.annotations."argocd\.argoproj\.io/sync-wave"

# Resultado esperado:
# NAME                      WAVE   SYNC     HEALTH
# crossplane-providers      1      Synced   Healthy
# aws-provider-configs      2      Synced   Healthy
# platform-apis             3      Synced   Healthy
# governance-namespaces     4      Synced   Healthy
# governance-rbac           4      Synced   Healthy
# environment-dev           5      Syncing  Progressing
# environment-hml           6      OutOfSync Missing
# environment-prod          7      OutOfSync Missing
```

## 🎬 Comportamento do ArgoCD:

### Com Sync Waves:
1. ArgoCD cria TODAS as apps de uma vez
2. Mas sync acontece **na ordem das waves**
3. Aguarda wave anterior completar antes de iniciar próxima
4. Se wave anterior falhar, próximas não executam

### Exemplo Timeline:

```
00:00 - Bootstrap aplicado
00:01 - 7 Applications criadas (todas aparecem no ArgoCD UI)
00:01 - Wave 1 inicia sync (providers)
00:05 - Wave 1 completa (Providers HEALTHY)
00:05 - Wave 2 inicia sync (configs)
00:06 - Wave 2 completa
00:06 - Wave 3 inicia sync (platform-apis)
00:07 - Wave 3 completa (XRDs disponíveis)
00:07 - Wave 4 inicia sync (governance)
00:08 - Wave 4 completa
00:08 - Wave 5 inicia sync (environment-dev)
00:18 - Wave 5 completa (Claims dev criadas)
00:18 - Wave 6 inicia sync (environment-hml)
00:28 - Wave 6 completa
00:28 - Wave 7 inicia sync (environment-prod)
00:38 - Wave 7 completa ✅ TUDO PRONTO!
```

## 🚀 Como Usar:

```bash
# 1. Instalar pré-requisitos (Crossplane + ArgoCD)
# Ver seção "Pré-requisitos Manuais" acima

# 2. Criar o projeto da plataforma
kubectl apply -f argocd/projects/platform-project.yaml

# 3. Aplicar bootstrap
kubectl apply -f argocd/bootstrap/bootstrap-app.yaml

# 4. Watch na ordem
kubectl get applications -n argocd -w

# Você verá as apps sendo criadas e synced uma de cada vez!
```

## ✅ Está Configurado Corretamente!

Suas applications **JÁ ESTÃO** com sync waves e vão executar **UMA POR VEZ** na ordem correta! 🎉

Nada mais a fazer após instalar os pré-requisitos, só aplicar o bootstrap e assistir a mágica acontecer!

## 🔧 Troubleshooting

### Providers não ficam HEALTHY
```bash
# Verificar logs do provider
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws

# Verificar se as credenciais estão corretas
kubectl get secret -n crossplane-system aws-creds
```

### Claims ficam em Pending
```bash
# Verificar evento do claim
kubectl describe bucket -n dev <bucket-name>

# Verificar se o XRD existe
kubectl get xrd

# Verificar se a Composition existe
kubectl get composition
```

### ArgoCD não progride para próxima wave
```bash
# Ver detalhes da application
kubectl describe application -n argocd <app-name>

# Ver eventos
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Forçar sync se necessário
argocd app sync <app-name>
```
