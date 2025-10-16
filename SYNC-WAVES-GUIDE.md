# Guia de Sync Waves - Ordem de Deployment no ArgoCD

## 🎯 O que são Sync Waves?

Sync Waves controlam a **ordem** em que o ArgoCD cria resources/applications. Números menores são criados primeiro.

## 📊 Ordem Atual Configurada:

```
Wave 1:  Providers                 (00-crossplane-providers.yaml)
  │      └─ Aguarda providers instalarem e ficarem HEALTHY
  ↓
Wave 2:  Provider Configs          (01-aws-provider-configs.yaml)
  │      └─ Configura credenciais AWS
  ↓
Wave 3:  Platform APIs             (02-platform-apis.yaml)
  │      └─ XRDs e Compositions
  ↓
Wave 4:  Governance                (03-governance-namespaces.yaml, 04-governance-rbac.yaml)
  │      └─ Namespaces e RBAC
  ↓
Wave 5: Environment Dev           (05-environment-dev.yaml)
  │      └─ Claims do ambiente dev
  ↓
Wave 6: Environment HML           (06-environment-hml.yaml)
  │      └─ Claims do ambiente hlm
  ↓
Wave 7: Environment Prod          (07-environment-prod.yaml)
         └─ Claims do ambiente prod
```

## 🔧 Como Configurar Sync Waves:

### Adicionar annotation na Application:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"  # Número da wave
```

### Números Recomendados:

- **Wave 1-4**: Componentes de plataforma (Providers, Configs, APIs, Governance)
- **Wave 5-7**: Ambientes e claims (Dev, HML, Prod)

## ⏱️ Sync com Espera (Recomendado)

Para garantir que cada app **espere a anterior terminar completamente**:

### Opção 1: Desabilitar Auto-Sync (Controle Total)

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: false  # Desabilitar auto-sync
```

**Como usar:**
```bash
# Sync manual na ordem
argocd app sync crossplane-core --wait
argocd app sync crossplane-providers --wait
argocd app sync aws-provider-configs --wait
argocd app sync platform-apis --wait
argocd app sync governance --wait
argocd app sync environment-dev --wait
```

### Opção 2: Sync Waves com SuccessfulSync Hook

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/hook: Skip  # Pula hooks
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    - ApplyOutOfSyncOnly=true  # Só aplica se out-of-sync
```

### Opção 3: Health Checks (Aguarda ficar Healthy)

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 10  # Múltiplas tentativas
      backoff:
        duration: 30s  # Espera mais tempo
        factor: 2
        maxDuration: 10m  # Máximo 10 min entre tentativas
```

## 📝 Configuração Recomendada por App:

### 01-crossplane-core.yaml
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 10s
        maxDuration: 3m
```

### 00-crossplane-providers.yaml
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    retry:
      limit: 10  # Mais tentativas para providers
      backoff:
        duration: 30s  # Mais tempo entre tentativas
        maxDuration: 10m
```

### 01-aws-provider-configs.yaml
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  syncPolicy:
    automated:
      prune: false  # NÃO deletar configs por segurança!
      selfHeal: true
```

### 02-platform-apis.yaml
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 03-governance-namespaces.yaml e 04-governance-rbac.yaml
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "4"
spec:
  syncPolicy:
    automated:
      prune: true  # false para namespaces (segurança)
      selfHeal: true
```

### 05-environment-dev.yaml
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 🎬 Como o ArgoCD Processa:

```
ArgoCD vê bootstrap-app
  │
  ├─ Cria todas as apps de uma vez
  │
  ├─ Mas sync respeitando waves:
  │
  ├─ Wave 1: Sync crossplane-providers
  │   └─ Aguarda ficar Healthy/Synced
  │   
  ├─ Wave 2: Sync provider-configs
  │   └─ Aguarda ficar Synced
  │   
  ├─ Wave 3: Sync platform-apis
  │   └─ Aguarda XRDs ficarem established
  │   
  ├─ Wave 4: Sync governance (namespaces + rbac)
  │   └─ Aguarda ficar Synced
  │   
  └─ Waves 5-7: Sync environments (dev, hml, prod)
      └─ Aguarda cada wave terminar antes da próxima
```

## ⏰ Controle de Timing:

### Para forçar espera entre waves:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  syncPolicy:
    retry:
      limit: 20  # Muitas tentativas
      backoff:
        duration: 30s  # 30 segundos entre tentativas
        maxDuration: 15m  # Tenta por até 15 minutos
```

## 🔍 Monitorar Sync em Tempo Real:

```bash
# Ver ordem de sync
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,WAVE:.metadata.annotations."argocd\.argoproj\.io/sync-wave",SYNC:.status.sync.status,HEALTH:.status.health.status

# Watch em tempo real
watch 'kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,WAVE:.metadata.annotations."argocd\.argoproj\.io/sync-wave",SYNC:.status.sync.status,HEALTH:.status.health.status'

# Logs do sync
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f
```

## 💡 Best Practices:

### ✅ DO:
- Use waves espaçadas (0, 1, 2, 4, 5, 6) para facilitar inserir novas apps
- Desabilite auto-sync para apps críticas
- Use retry com backoff adequado
- Agrupe apps relacionadas na mesma wave

### ❌ DON'T:
- Não use waves muito próximas (0, 1, 2, 3...) sem espaço
- Não faça auto-sync de tudo sem teste
- Não use wave muito alta (>100) sem necessidade

## 🎯 Exemplo Prático de Uso:

```bash
# 1. Aplicar bootstrap (cria todas as apps)
kubectl apply -f argocd/bootstrap/bootstrap-app.yaml

# 2. Ver apps sendo criadas na ordem
kubectl get applications -n argocd -w

# Você verá:
# crossplane-core          Wave 0   Syncing
# crossplane-core          Wave 0   Synced
# crossplane-providers     Wave 1   Syncing  ← Só inicia após wave 0
# crossplane-providers     Wave 1   Synced
# aws-provider-configs     Wave 2   Syncing  ← Só inicia após wave 1
# ...
```

## 🔄 Forçar Sync Manual (Controle Total):

Se quiser controle absoluto:

```yaml
# Todas as apps: syncPolicy.automated = null (sem auto-sync)
spec:
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    # Sem automated! Sync manual apenas
```

**Depois sync manualmente:**

```bash
# 1. Core
argocd app sync crossplane-core --wait

# 2. Providers (só após core healthy)
argocd app sync crossplane-providers --wait

# 3. Configs
argocd app sync aws-provider-configs --wait

# 4. Platform APIs
argocd app sync platform-apis --wait

# 5. Governance
argocd app sync governance --wait

# 6. Environments
argocd app sync environment-dev --wait
argocd app sync environment-hml --wait
argocd app sync environment-prod --wait
```

## 📊 Comparação de Métodos:

| Método | Controle | Automação | Complexidade | Uso |
|--------|----------|-----------|--------------|-----|
| **Sync Waves** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ | Recomendado |
| **Manual Sync** | ⭐⭐⭐⭐⭐ | ⭐ | ⭐ | Dev/Debug |
| **Sem Waves** | ⭐ | ⭐⭐⭐⭐⭐ | ⭐ | Não recomendado |

## 🎉 Recomendação:

**Use Sync Waves** como já configurado! É o melhor equilíbrio entre automação e controle.

Wave 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7

Cada wave só inicia **após a anterior terminar**! 🎯

Quer que eu atualize todos os arquivos com as sync waves otimizadas?
