#!/bin/bash
# start-bridge.sh
# Lanza el Configurador Web del Bridge.

echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Starting Development Mode..."

echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Cleaning up ports 3456 & 4321..."
lsof -ti :3456,4321 | xargs kill -9 2>/dev/null || true

# 1. Verificar versión de Node.js
REQUIRED_NODE="22.12.0"
CURRENT_NODE=$(node -v | cut -d'v' -f2)

function version_ge() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

if ! version_ge "$CURRENT_NODE" "$REQUIRED_NODE"; then
    echo -e "⚠️  \x1b[33m[Gemini Bridge] Warning: Node.js $CURRENT_NODE detected. Astro requires >=$REQUIRED_NODE.\x1b[0m"
    echo -e "Si el frontend falla, por favor actualiza Node.js."
fi

# 2. Instalar dependencias del Backend si faltan o están incompletas
# Comprobamos si ssh2 es cargable, no solo si el directorio existe
if ! node -e "require('ssh2')" 2>/dev/null; then
    echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Critical module 'ssh2' missing. Installing backend dependencies..."
    cd gemini-bridge && npm install && cd ..
fi

# 3. Instalar dependencias del Frontend si faltan
if [ ! -d "gemini-bridge/frontend/node_modules" ]; then
    echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Installing frontend dependencies (Astro, etc.)..."
    cd gemini-bridge/frontend && npm install && cd ../..
fi

# 3. Levantar el Backend (API) en el puerto 3456
echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Starting Backend (Node.js)..."
node gemini-bridge/server.js &
BACKEND_PID=$!

# 4. Levantar Astro en el puerto 4321
echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Starting Frontend (Astro)..."
cd gemini-bridge/frontend
npm run dev -- --port 4321 &
FRONTEND_PID=$!

cd ../..

# Instrucciones en consola
echo -e "\x1b[33m--------------------------------------------------\x1b[0m"
echo -e "🚀 \x1b[1mFRONTEND:\x1b[0m \x1b[4mhttp://localhost:4321\x1b[0m (Hot Reload ACTIVE)"
echo -e "🔌 \x1b[1mBACKEND:\x1b[0m  http://localhost:3456 (API & Logs)"
echo -e "\x1b[33m--------------------------------------------------\x1b[0m"

# Capturar señal de cierre para matar ambos
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null" EXIT
wait

