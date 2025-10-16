# 📋 Changelog - ArgoCD Applications

## 2025-10-16 - Simplificação e Renomeação

### 🔄 Arquivos Renomeados

| Antigo | Novo | Descrição |
|--------|------|-----------|
| `02-crossplane-providers.yaml` | `00-crossplane-providers.yaml` | Providers AWS/Azure/GCP |
| `03-aws-provider-configs.yaml` | `01-aws-provider-configs.yaml` | Configurações AWS |
| `04-platform-apis.yaml` | `02-platform-apis.yaml` | XRDs e Compositions |
| `08-governance-namespaces.yaml` | `03-governance-namespaces.yaml` | Namespaces (dev, hlm, prod) |
| `10-governance-rbac.yaml` | `04-governance-rbac.yaml` | ClusterRoles e RBAC |
| `07-environment-dev.yaml` | `05-environment-dev.yaml` | Claims de desenvolvimento |
| `08-environment-hml.yaml` | `06-environment-hml.yaml` | Claims de homologação |
| `09-environment-prod.yaml` | `07-environment-prod.yaml` | Claims de produção |

### ❌ Arquivos Removidos

- **`01-crossplane-core.yaml`** - Instalação do Crossplane agora é **manual via Helm**
- **`06-governance-gatekeeper.yaml`** - OPA Gatekeeper removido (simplificação)
- **`07-governance-policies.yaml`** - Políticas do Gatekeeper removidas

### ✨ Motivação

1. **Numeração Limpa**: Começar de 00 facilita a organização e futuras adições
2. **Instalação Manual**: Crossplane e ArgoCD são instalados manualmente para melhor controle
3. **Simplificação**: Removida a complexidade do Gatekeeper, focando em governança básica (namespaces + RBAC)
4. **Clareza**: Sync waves mais simples e diretas (1-7 ao invés de 0, 1, 2, 3, 4, 7, 8, 9, 10)

### 📊 Nova Ordem de Deploy

```
Wave 1: 00-crossplane-providers.yaml      (Providers)
Wave 2: 01-aws-provider-configs.yaml      (Credenciais)
Wave 3: 02-platform-apis.yaml             (XRDs + Compositions)
Wave 4: 03-governance-namespaces.yaml     (Namespaces)
        04-governance-rbac.yaml            (RBAC)
Wave 5: 05-environment-dev.yaml           (Claims Dev)
Wave 6: 06-environment-hml.yaml           (Claims HML)
Wave 7: 07-environment-prod.yaml          (Claims Prod)
```

### 📝 Documentação Atualizada

- ✅ `argocd/README.md` - Guia principal atualizado
- ✅ `argocd/SETUP-SIMPLIFICADO.md` - Quick start atualizado
- ✅ `argocd/SYNC-WAVES-GUIDE.md` - Guia de sync waves atualizado
- ✅ `argocd/applications/ORDEM-DE-DEPLOY.md` - Ordem de deploy atualizada
- ✅ `argocd/applications/README-ENVIRONMENTS.md` - Guia de environments atualizado
- ✅ `argocd/applications/ENVIRONMENTS-APPS.md` - Documentação de apps atualizada
- ✅ `argocd/projects/platform-project.yaml` - Projeto atualizado (sem Gatekeeper)
- ✅ `docs/quickstart/QUICKSTART-GITOPS.md` - Quickstart atualizado
- ✅ `docs/project/PROJECT-STRUCTURE.md` - Estrutura do projeto atualizada

### 🚀 Impacto

**Antes:**
- 10 arquivos de application (01-10)
- Instalação automática do Crossplane via ArgoCD
- OPA Gatekeeper e políticas complexas
- Sync waves: 0, 1, 2, 3, 4, 7, 8, 9, 10

**Depois:**
- 8 arquivos de application (00-07)
- Instalação manual do Crossplane (mais controle)
- Governança simplificada (namespaces + RBAC)
- Sync waves: 1, 2, 3, 4, 5, 6, 7

### ⚠️ Breaking Changes

Se você já tinha um setup funcionando:

1. **Crossplane**: Precisa ser instalado manualmente antes do ArgoCD
2. **Gatekeeper**: Não será mais instalado automaticamente
3. **Nomes de arquivos**: Todos os arquivos foram renomeados
4. **Referências Git**: Atualize seus repositórios com os novos nomes

### 🔄 Como Migrar

```bash
# 1. Instalar Crossplane manualmente
helm install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane --wait

# 2. Instalar ArgoCD manualmente
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. Aplicar os novos arquivos
kubectl apply -f argocd/projects/platform-project.yaml
kubectl apply -f argocd/bootstrap/bootstrap-app.yaml
```

### 📞 Suporte

Se encontrar problemas após a migração, consulte:
- `argocd/SETUP-SIMPLIFICADO.md` - Guia rápido
- `argocd/README.md` - Documentação completa
- `argocd/applications/ORDEM-DE-DEPLOY.md` - Troubleshooting

---

**Data**: 16 de Outubro de 2025  
**Versão**: 2.0.0  
**Tipo**: Breaking Change

