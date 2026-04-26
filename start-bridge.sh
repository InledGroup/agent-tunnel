#!/bin/bash
# start-bridge.sh
# Lanza el Configurador Web del Bridge.

echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Starting Development Mode..."

echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Cleaning up ports 3456 & 4321..."
lsof -ti :3456,4321 | xargs kill -9 2>/dev/null || true

# 1. Instalar dependencias del Backend si faltan
if [ ! -d "gemini-bridge/node_modules" ]; then
    echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Installing backend dependencies (ssh2, etc.)..."
    cd gemini-bridge && npm install --silent && cd ..
fi

# 2. Instalar dependencias del Frontend si faltan
if [ ! -d "gemini-bridge/frontend/node_modules" ]; then
    echo -e "\x1b[36m[Gemini Bridge]\x1b[0m Installing frontend dependencies (Astro, etc.)..."
    cd gemini-bridge/frontend && npm install --silent && cd ../..
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

