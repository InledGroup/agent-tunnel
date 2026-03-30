#!/bin/bash
# start-bridge.sh
# Lanza el Configurador Web del Bridge.

echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Starting Development Mode..."

# 1. Levantar el Backend (API) en el puerto 3456
node gemini-bridge/server.js &
BACKEND_PID=$!

# 2. Instalar dependencias si no están (solo la primera vez)
cd gemini-bridge/frontend
if [ ! -d "node_modules" ]; then
    echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Installing frontend dependencies..."
    npm install --silent
fi

# 3. Levantar Astro en el puerto 4321
npm run dev -- --port 4321 &
FRONTEND_PID=$!

cd ../..

# Instrucciones en consola
echo -e "\x1b[33m--------------------------------------------------\x1b[0m"
echo -e "🚀 \x1b[1mFRONTEND:\x1b[0m \x1b[4mhttp://localhost:4321\x1b[0m (Hot Reload ACTIVE)"
echo -e "🔌 \x1b[1mBACKEND:\x1b[0m  http://localhost:3456 (API & Logs)"
echo -e "\x1b[33m--------------------------------------------------\x1b[0m"

# Capturar señal de cierre para matar ambos
trap "kill $BACKEND_PID $FRONTEND_PID" EXIT
wait

