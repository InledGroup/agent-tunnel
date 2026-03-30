#!/bin/bash
# remote-exec.sh
# Improved version: Uses environment variables from activate.sh when available.

# 1. Obtener configuración (Priorizar entorno, fallback a búsqueda manual)
HOST="${GEMINI_BRIDGE_HOST}"
USER="${GEMINI_BRIDGE_USER}"
LOCAL_ROOT="${GEMINI_BRIDGE_PROJECT_ROOT}"

if [[ -z "$HOST" || -z "$LOCAL_ROOT" ]]; then
    # Fallback: Buscar en configs si no hay variables de entorno
    CONFIGS_DIR="$HOME/.gemini-bridge/configs"
    CURRENT_DIR=$(pwd)
    for f in "$CONFIGS_DIR"/*.json; do
        [ -e "$f" ] || continue
        LP=$(grep '"local_path":' "$f" | sed -E 's/.*"local_path": "(.*)".*/\1/')
        if [[ "$CURRENT_DIR" == "$LP"* ]]; then
            HOST=$(grep '"host":' "$f" | sed -E 's/.*"host": "(.*)".*/\1/')
            USER=$(grep '"user":' "$f" | sed -E 's/.*"user": "(.*)".*/\1/')
            REMOTE_ROOT=$(grep '"remote_path":' "$f" | sed -E 's/.*"remote_path": "(.*)".*/\1/')
            LOCAL_ROOT="$LP"
            break
        fi
    done
fi

# Intentar obtener REMOTE_ROOT si no lo tenemos (fallback a /)
if [ -z "$REMOTE_ROOT" ]; then
    REMOTE_ROOT="/"
fi

# 2. Safety check: If vital info is missing, execute locally
if [[ -z "$HOST" || -z "$USER" ]]; then
    eval "$@"
    exit $?
fi

# 3. Mapeo de rutas
CURRENT_DIR=$(pwd)
RELATIVE_PATH="${CURRENT_DIR#$LOCAL_ROOT}"
# Asegurar que no hay barras dobles al principio
FINAL_REMOTE_PATH="${REMOTE_ROOT}${RELATIVE_PATH}"
FINAL_REMOTE_PATH=$(echo "$FINAL_REMOTE_PATH" | sed 's#//#/#g')

# 4. Comando final
COMMAND="$*"

# 5. Log al servidor local del bridge
curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"type\":\"command\",\"cmd\":\"$COMMAND\",\"path\":\"$FINAL_REMOTE_PATH\"}" \
    http://localhost:3456/api/log > /dev/null

# 6. Ejecución remota vía SSH
SSH_KEY="$HOME/.ssh/id_ed25519_bridge"
# Opciones universales optimizadas
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Si la llave existe, la usamos
if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

# Si Mutagen está desactivado, NO intentamos crear directorios (para evitar problemas en ROMs/Routers)
if [ "${GEMINI_BRIDGE_HAS_MUTAGEN}" == "true" ]; then
    SSH_CMD="mkdir -p \"$FINAL_REMOTE_PATH\" && cd \"$FINAL_REMOTE_PATH\" && $COMMAND"
else
    # En modo SSH-only, intentamos CD pero no forzamos creación. Si falla el CD, ejecutamos en el CWD remoto por defecto.
    SSH_CMD="cd \"$FINAL_REMOTE_PATH\" 2>/dev/null || cd ~; $COMMAND"
fi

OUTPUT=$(ssh $SSH_OPTS "$USER@$HOST" "$SSH_CMD" 2>&1)
EXIT_CODE=$?

# 7. Log del resultado
node -e "
const http = require('http');
const data = JSON.stringify({
    type: 'result',
    cmd: process.argv[1],
    exit_code: parseInt(process.argv[2]),
    output: process.argv[3]
});
const req = http.request({
    hostname: 'localhost', port: 3456, path: '/api/log', method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) }
});
req.on('error', () => {}); req.write(data); req.end();
" "$COMMAND" "$EXIT_CODE" "$OUTPUT"

echo "$OUTPUT"
exit $EXIT_CODE
