# 🔐 Governance Applications - Ordem de Criação

## 📊 Visão Geral

```
┌─────────────────────────────────────────────────────┐
│  SYNC WAVE 0 - governance-gatekeeper                │
│  ├─ Instala OPA Gatekeeper                          │
│  ├─ CRDs: ConstraintTemplate, Constraints           │
│  └─ Aguarda: Pods Ready (1-2 min)                   │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  SYNC WAVE 1 - governance-policies                  │
│  ├─ ConstraintTemplates (define policies)           │
│  ├─ Constraints (aplica policies)                   │
│  └─ Aguarda: 10s para processar templates          │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  SYNC WAVE 2 - governance-namespaces                │
│  ├─ Namespace: dev                                  │
│  ├─ Namespace: hlm                                  │
│  └─ Namespace: prod                                 │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│  SYNC WAVE 3 - governance-rbac                      │
│  ├─ ClusterRole: crossplane-viewer                  │
│  ├─ ClusterRole: crossplane-platform-admin          │
│  └─ ClusterRole: crossplane-claim-creator           │
└─────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

```bash
# 1. Aplicar todas as applications
kubectl apply -f argocd/applications/06-governance-gatekeeper.yaml
kubectl apply -f argocd/applications/07-governance-policies.yaml
kubectl apply -f argocd/applications/08-governance-namespaces.yaml
kubectl apply -f argocd/applications/10-governance-rbac.yaml

# 2. Monitorar progresso
watch kubectl get applications -n argocd

# 3. Verificar (após 2-3 min)
kubectl get constrainttemplates
kubectl get namespaces
```

---

## 📁 Arquivos Criados

| Arquivo | Wave | Descrição |
|---------|------|-----------|
| `06-governance-gatekeeper.yaml` | 0 | Instala OPA Gatekeeper |
| `07-governance-policies.yaml` | 1 | Policies de governança |
| `08-governance-namespaces.yaml` | 2 | Cria namespaces |
| `10-governance-rbac.yaml` | 3 | ClusterRoles |

---

## ✅ Checklist de Configuração

- [ ] Criar repositório Git: `https://github.com/SEU_USUARIO/governance.git`
- [ ] Copiar conteúdo de `governance/` para o repo
- [ ] Atualizar `repoURL` em todos os arquivos `06-` a `10-`
- [ ] Fazer commit e push do governance repo
- [ ] Aplicar applications no ArgoCD
- [ ] Aguardar sync completo (2-3 min)
- [ ] Verificar status: `kubectl get apps -n argocd`
- [ ] Testar policies criando recursos

---

## 📖 Documentação Completa

Ver: `GOVERNANCE-SETUP.md` para detalhes completos

