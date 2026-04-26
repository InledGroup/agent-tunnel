#!/bin/bash
# install-tunnel.sh - Cross-platform installer for Agent Tunnel
# Works on macOS, Linux, and Windows (Git Bash/WSL)

REPO_URL="https://github.com/InledGroup/agent-tunnel.git" # Ajusta si la URL cambia
TARGET_DIR="agent-tunnel"

# Colores para la terminal
CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${CYAN}[Agent Tunnel]${NC} Initiating one-click setup..."

# 1. Verificar requisitos mínimos
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed."
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "Error: node (Node.js) is not installed."
    exit 1
fi

# 2. Clonar o actualizar
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${CYAN}[Agent Tunnel]${NC} Cloning repository into $TARGET_DIR..."
    git clone "$REPO_URL" "$TARGET_DIR"
else
    echo -e "${CYAN}[Agent Tunnel]${NC} Directory $TARGET_DIR already exists. Updating..."
    cd "$TARGET_DIR" && git pull && cd ..
fi

# 3. Entrar y preparar ejecución
cd "$TARGET_DIR"
chmod +x start-bridge.sh 2>/dev/null || true # Ignorar error en Windows nativo si falla chmod

# 4. Lanzar el Bridge
# Gracias a nuestra corrección, este script instalará las dependencias automáticamente
echo -e "${GREEN}[Agent Tunnel]${NC} Setup complete. Launching Bridge and installing dependencies..."
./start-bridge.sh
