#!/bin/bash
# Script de setup completo do ArgoCD e Crossplane
# Uso: bash argocd/COMANDOS-SETUP.sh

set -e  # Exit on error

echo "🚀 Setup ArgoCD + Crossplane Platform"
echo "======================================"
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para verificar comando
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 instalado"
        return 0
    else
        echo -e "${RED}✗${NC} $1 não encontrado"
        return 1
    fi
}

# Função para aguardar recursos
wait_for_resource() {
    local resource=$1
    local namespace=$2
    local timeout=${3:-300}
    
    echo "⏳ Aguardando $resource em $namespace..."
    kubectl wait --for=condition=Ready $resource -n $namespace --timeout=${timeout}s
}

echo "📋 Verificando pré-requisitos..."
check_command kubectl || { echo "Instale kubectl primeiro!"; exit 1; }
check_command git || { echo "Instale git primeiro!"; exit 1; }

echo ""
echo "🔍 Verificando cluster Kubernetes..."
if kubectl cluster-info &> /dev/null; then
    CURRENT_CONTEXT=$(kubectl config current-context)
    echo -e "${GREEN}✓${NC} Conectado ao cluster: $CURRENT_CONTEXT"
else
    echo -e "${RED}✗${NC} Não conectado a nenhum cluster!"
    exit 1
fi

echo ""
read -p "❓ Deseja continuar com o setup? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelado."
    exit 0
fi

# ====================
# 1. INSTALAR ARGOCD
# ====================
echo ""
echo "1️⃣ Instalando ArgoCD..."

if kubectl get namespace argocd &> /dev/null; then
    echo -e "${YELLOW}⚠${NC} Namespace argocd já existe"
    read -p "   Pular instalação do ArgoCD? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SKIP_ARGOCD=true
    fi
fi

if [ "$SKIP_ARGOCD" != "true" ]; then
    # Criar namespace
    kubectl create namespace argocd 2>/dev/null || true
    
    # Instalar ArgoCD
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Aguardar pods
    echo "⏳ Aguardando ArgoCD ficar pronto (pode levar 2-3 minutos)..."
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
    
    echo -e "${GREEN}✓${NC} ArgoCD instalado com sucesso!"
else
    echo -e "${YELLOW}⚠${NC} Pulando instalação do ArgoCD"
fi

# ====================
# 2. OBTER SENHA ADMIN
# ====================
echo ""
echo "2️⃣ Obtendo credenciais ArgoCD..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

if [ -n "$ARGOCD_PASSWORD" ]; then
    echo -e "${GREEN}✓${NC} Senha obtida!"
    echo ""
    echo "   📝 Credenciais ArgoCD:"
    echo "   Username: admin"
    echo "   Password: $ARGOCD_PASSWORD"
    echo ""
else
    echo -e "${YELLOW}⚠${NC} Não foi possível obter senha automaticamente"
    echo "   Execute: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
fi

# ====================
# 3. APLICAR PROJECTS
# ====================
echo ""
echo "3️⃣ Aplicando AppProjects..."
kubectl apply -f argocd/projects/

if kubectl get appproject platform -n argocd &> /dev/null; then
    echo -e "${GREEN}✓${NC} AppProjects criados"
else
    echo -e "${RED}✗${NC} Erro ao criar AppProjects"
    exit 1
fi

# ====================
# 4. APLICAR BOOTSTRAP
# ====================
echo ""
echo "4️⃣ Aplicando Bootstrap Application (App of Apps)..."
kubectl apply -f argocd/bootstrap/bootstrap-app.yaml

echo "⏳ Aguardando bootstrap app ser criado..."
sleep 5

if kubectl get application crossplane-bootstrap -n argocd &> /dev/null; then
    echo -e "${GREEN}✓${NC} Bootstrap application criado"
else
    echo -e "${RED}✗${NC} Erro ao criar bootstrap application"
    exit 1
fi

# ====================
# 5. AGUARDAR APPS
# ====================
echo ""
echo "5️⃣ Aguardando ArgoCD criar applications..."
echo "⏳ Isso pode levar alguns segundos..."

for i in {1..30}; do
    APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
    if [ "$APP_COUNT" -gt 1 ]; then
        break
    fi
    sleep 2
done

echo ""
echo "📊 Applications criadas:"
kubectl get applications -n argocd

# ====================
# 6. PORT FORWARD
# ====================
echo ""
echo "6️⃣ Configurando acesso ao ArgoCD..."
read -p "❓ Deseja iniciar port-forward para acessar ArgoCD UI? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🌐 Iniciando port-forward..."
    echo "   ArgoCD UI estará disponível em: https://localhost:8080"
    echo ""
    echo "   📝 Credenciais:"
    echo "   Username: admin"
    echo "   Password: $ARGOCD_PASSWORD"
    echo ""
    echo "   ⚠️  Pressione Ctrl+C para parar o port-forward"
    echo ""
    
    kubectl port-forward svc/argocd-server -n argocd 8080:443
else
    echo ""
    echo "Para acessar ArgoCD UI depois, execute:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
fi

# ====================
# 7. RESUMO
# ====================
echo ""
echo "✅ Setup Completo!"
echo "=================="
echo ""
echo "📊 Status:"
kubectl get applications -n argocd
echo ""
echo "🔗 Links Úteis:"
echo "   - ArgoCD UI: https://localhost:8080 (via port-forward)"
echo "   - Username: admin"
echo "   - Password: $ARGOCD_PASSWORD"
echo ""
echo "📚 Próximos Passos:"
echo "   1. Acessar ArgoCD UI"
echo "   2. Verificar sync das applications"
echo "   3. Aguardar Crossplane instalar (~10 min)"
echo "   4. Configurar credenciais cloud (AWS/Azure/GCP)"
echo ""
echo "🆘 Troubleshooting:"
echo "   - Ver apps: kubectl get applications -n argocd"
echo "   - Logs: kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller"
echo "   - Sync manual: argocd app sync <app-name>"
echo ""

