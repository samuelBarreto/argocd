# Ordem de Deploy das Applications

## 📊 Sync Waves Configuradas:

```
┌──────────────────────────────────────────────────────────────┐
│  Wave 0: Infraestrutura Base                                 │
├──────────────────────────────────────────────────────────────┤
│  ✅ 01-crossplane-core.yaml                                  │
│     └─ Instala Crossplane (Helm chart ou manifests)         │
│        Aguarda: Pods crossplane ficarem Ready                │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 0 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 1: Cloud Providers                                     │
├──────────────────────────────────────────────────────────────┤
│  ✅ 02-crossplane-providers.yaml                             │
│     └─ Instala Providers AWS, Azure, GCP                    │
│        Aguarda: Providers HEALTHY=True                       │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 1 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 2: Provider Configurations                             │
├──────────────────────────────────────────────────────────────┤
│  ✅ 03-aws-provider-configs.yaml                             │
│  ✅ 03-azure-provider-configs.yaml                           │
│     └─ Configura credenciais e ProviderConfigs              │
│        Aguarda: ProviderConfigs criados                      │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 2 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 3: Platform APIs                                       │
├──────────────────────────────────────────────────────────────┤
│  ✅ 04-platform-apis.yaml                                    │
│     └─ XRDs (Database, Network, Bucket)                     │
│     └─ Compositions (templates de infraestrutura)           │
│        Aguarda: XRDs e Compositions criados                  │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 3 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 4: Governance & Security                               │
├──────────────────────────────────────────────────────────────┤
│  ✅ 05-governance.yaml                                       │
│     └─ OPA Policies                                         │
│     └─ RBAC Roles                                           │
│        Aguarda: Policies ativas                              │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 4 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 5: Development Environment                            │
├──────────────────────────────────────────────────────────────┤
│  ✅ 07-environment-dev.yaml                                  │
│     └─ Claims de desenvolvimento                            │
│        (Databases, Networks, Buckets)                        │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 10 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 6: Homologation Environment                           │
├──────────────────────────────────────────────────────────────┤
│  ✅ 08-environment-hml.yaml                                  │
│     └─ Claims de homologação                                │
└──────────────────────────────────────────────────────────────┘
                           │
                           ↓ (aguarda wave 11 terminar)
┌──────────────────────────────────────────────────────────────┐
│  Wave 7: Production Environment                             │
├──────────────────────────────────────────────────────────────┤
│  ✅ 09-environment-prod.yaml                                 │
│     └─ Claims de produção                                   │
│        (Apenas após dev e hml testados!)                    │
└──────────────────────────────────────────────────────────────┘
```

## ⏱️ Tempo Estimado de Deploy:

| Wave | App | Tempo Estimado | Acumulado |
|------|-----|----------------|-----------|
| 0 | Crossplane Core | 2-3 min | 3 min |
| 1 | Providers | 3-5 min | 8 min |
| 2 | Provider Configs | 30 seg | 8.5 min |
| 3 | Platform APIs | 1 min | 9.5 min |
| 4 | Governance | 1-2 min | 11.5 min |
| 5 | Dev Environment | 5-10 min | 21.5 min |
| 6 | HML Environment | 5-10 min | 31.5 min |
| 7 | Prod Environment | 5-10 min | 41.5 min |

**Total**: ~35-45 minutos para deploy completo

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

# Resultado:
# NAME                      WAVE   SYNC     HEALTH
# crossplane-core           0      Synced   Healthy
# crossplane-providers      1      Synced   Healthy
# aws-provider-configs      2      Synced   Healthy
# azure-provider-configs    2      Synced   Healthy
# platform-apis             3      Synced   Healthy
# governance                4      Synced   Healthy
# environment-dev           5     Syncing  Progressing
# environment-hml           6     OutOfSync Missing
# environment-prod          7     OutOfSync Missing
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
00:01 - 8 Applications criadas (todas aparecem no ArgoCD UI)
00:01 - Wave 0 inicia sync (crossplane-core)
00:03 - Wave 0 completa (Crossplane Healthy)
00:03 - Wave 1 inicia sync (providers)
00:08 - Wave 1 completa (Providers HEALTHY)
00:08 - Wave 2 inicia sync (configs)
00:09 - Wave 2 completa
00:09 - Wave 3 inicia sync (platform-apis)
00:10 - Wave 3 completa (XRDs disponíveis)
00:10 - Wave 4 inicia sync (governance)
00:12 - Wave 4 completa
00:12 - Wave 5 inicia sync (environment-dev)
00:22 - Wave 5 completa (Claims dev criadas)
00:22 - Wave 6 inicia sync (environment-hml)
00:32 - Wave 6 completa
00:32 - Wave 7 inicia sync (environment-prod)
00:42 - Wave 7 completa ✅ TUDO PRONTO!
```

## 🚀 Como Usar:

```bash
# 1. Aplicar bootstrap
kubectl apply -f argocd/bootstrap/bootstrap-app.yaml

# 2. Watch na ordem
kubectl get applications -n argocd -w

# Você verá as apps sendo criadas e synced uma de cada vez!
```

## ✅ Está Configurado Corretamente!

Suas applications **JÁ ESTÃO** com sync waves e vão executar **UMA POR VEZ** na ordem correta! 🎉

Nada mais a fazer, só aplicar o bootstrap e assistir a mágica acontecer!

