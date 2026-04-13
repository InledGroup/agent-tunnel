#!/bin/bash
# remote-exec.sh
# Executes commands on remote target via SSH, but only if the bridge session is active.

# 1. Utility functions
_gemini_parse_json() {
    node -e "
try {
    const fs = require('fs');
    const content = process.argv[1];
    const key = process.argv[2];
    let data;
    if (content.startsWith('{') || content.startsWith('[')) {
        data = JSON.parse(content);
    } else {
        data = JSON.parse(fs.readFileSync(content, 'utf8'));
    }
    
    let val = data;
    for (const part of key.split('.')) {
        if (val && typeof val === 'object') {
            val = val[part];
        } else {
            val = '';
            break;
        }
    }
    if (val && typeof val === 'object') {
        console.log(JSON.stringify(val));
    } else {
        console.log(val || '');
    }
} catch (e) {}
" "$1" "$2"
}

_gemini_normalize_path() {
    local p="$1"
    p=$(echo "$p" | tr -s '/')
    [[ "$p" != "/" ]] && p="${p%/}"
    echo "$p"
}

# --- DETECCIÓN DE CONFIGURACIÓN ---
CURRENT_DIR=$(_gemini_normalize_path "$(pwd)")
CONFIGS_DIR="$HOME/.gemini-bridge/configs"

# Intentar obtener sesiones activas del servidor para resolver ambigüedades
SESSIONS_JSON=$(curl -s --max-time 2 http://127.0.0.1:3456/api/sessions 2>/dev/null)
CURL_EXIT=$?

MATCHED_CONFIG=""

# Prioridad 0: Si ya tenemos una sesión forzada por variables de entorno, la usamos directamente
if [[ -n "$GEMINI_BRIDGE_SESSION" && -f "$CONFIGS_DIR/${GEMINI_BRIDGE_SESSION}.json" ]]; then
    MATCHED_CONFIG="$CONFIGS_DIR/${GEMINI_BRIDGE_SESSION}.json"
else
    # Prioridad 1: Buscar si el directorio actual coincide con alguna config guardada
    MATCHED_CONFIGS=()
    for f in "$CONFIGS_DIR"/*.json; do
        [ -e "$f" ] || continue
        LP=$(_gemini_parse_json "$f" local_path)
        LP=$(_gemini_normalize_path "$LP")
        if [[ -n "$LP" && "$CURRENT_DIR" == "$LP"* ]]; then
            MATCHED_CONFIGS+=("$f")
        fi
    done

    if [[ ${#MATCHED_CONFIGS[@]} -eq 1 ]]; then
        MATCHED_CONFIG="${MATCHED_CONFIGS[0]}"
    elif [[ ${#MATCHED_CONFIGS[@]} -gt 1 ]]; then
        # Ambigüedad: Intentar resolver con el servidor si está activo
        if [[ $CURL_EXIT -eq 0 && -n "$SESSIONS_JSON" ]]; then
            for conf in "${MATCHED_CONFIGS[@]}"; do
                S_NAME=$(basename "$conf" .json)
                VALID_S=$(echo "$S_NAME" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9_-]//g')
                ACTIVE_VAL=$(_gemini_parse_json "$SESSIONS_JSON" "activeSsh.$VALID_S")
                if [[ -n "$ACTIVE_VAL" && "$ACTIVE_VAL" != "null" ]]; then
                    MATCHED_CONFIG="$conf"
                    break
                fi
            done
        fi
        
        # Si después de consultar al servidor sigue habiendo ambigüedad o no se resolvió
        if [[ -z "$MATCHED_CONFIG" ]]; then
             echo -e "⚠️  \\x1b[33m[Agent Tunnel] Ambiguous configurations for this path:\\x1b[0m"
             for conf in "${MATCHED_CONFIGS[@]}"; do
                 echo "  - $(basename "$conf" .json)"
             done
             echo -e "\\x1b[33mPlease start the Bridge server and activate one, or delete the old config.\\x1b[0m"
             echo -e "⚙️  Executing locally..."
             eval "$@"
             exit $?
        fi
    fi
fi

# --- LOGICA DE EXCLUSION ---
if [[ -n "$MATCHED_CONFIG" ]]; then
    EXCLUDED=$(_gemini_parse_json "$MATCHED_CONFIG" excluded_commands)
    MODE=$(_gemini_parse_json "$MATCHED_CONFIG" exclude_mode)
    CMD_STR="$*"
    
    if [[ -n "$EXCLUDED" ]]; then
        IFS=',' read -ra ADDR <<< "$EXCLUDED"
        for item in "${ADDR[@]}"; do
            item=$(echo "$item" | xargs)
            [[ -z "$item" ]] && continue
            if [[ "$MODE" == "exact" ]]; then
                if [[ "$CMD_STR" == "$item" ]]; then
                    echo -e "⚙️  \\x1b[33m[Agent Tunnel] Excluded command (Exact match):\\x1b[0m Executing locally..."
                    eval "$@"
                    exit $?
                fi
            else
                if [[ "$CMD_STR" == "$item"* ]]; then
                    echo -e "⚙️  \\x1b[33m[Agent Tunnel] Excluded command (Prefix match):\\x1b[0m Executing locally..."
                    eval "$@"
                    exit $?
                fi
            fi
        done
    fi
fi

if [[ -n "$MATCHED_CONFIG" ]]; then
    HOST=$(_gemini_parse_json "$MATCHED_CONFIG" host)
    PORT=$(_gemini_parse_json "$MATCHED_CONFIG" port)
    USER=$(_gemini_parse_json "$MATCHED_CONFIG" user)
    REMOTE_ROOT=$(_gemini_parse_json "$MATCHED_CONFIG" remote_path)
    SESSION_NAME=$(basename "$MATCHED_CONFIG" .json)
    LOCAL_ROOT=$(_gemini_parse_json "$MATCHED_CONFIG" local_path)
else
    # Fallback a variables de entorno si no hay match por directorio
    HOST="${GEMINI_BRIDGE_HOST}"
    PORT="${GEMINI_BRIDGE_PORT}"
    USER="${GEMINI_BRIDGE_USER}"
    LOCAL_ROOT="${GEMINI_BRIDGE_PROJECT_ROOT}"
    REMOTE_ROOT="${GEMINI_BRIDGE_REMOTE_ROOT}"
    SESSION_NAME="${GEMINI_BRIDGE_SESSION}"
fi
PORT="${PORT:-22}"

# 2. VERIFICACIÓN DE SESIÓN ACTIVA
IS_ACTIVE="false"
STATUS_MSG=""

if [[ -n "$SESSION_NAME" ]]; then
    VALID_SESSION=$(echo "$SESSION_NAME" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9_-]//g')
    
    if [[ $CURL_EXIT -eq 0 && -n "$SESSIONS_JSON" ]]; then
        ACTIVE_VAL=$(_gemini_parse_json "$SESSIONS_JSON" "activeSsh.$VALID_SESSION")
        if [[ -n "$ACTIVE_VAL" && "$ACTIVE_VAL" != "null" ]]; then
            IS_ACTIVE="true"
        else
            STATUS_MSG="Tunnel '$SESSION_NAME' is explicitly disabled in Bridge server."
        fi
    else
        if [[ -f "$CONFIGS_DIR/${SESSION_NAME}.json" ]]; then
            IS_ACTIVE="true"
            [[ $CURL_EXIT -ne 0 ]] && STATUS_MSG="Bridge server not responding. Running '$SESSION_NAME' in Standalone Mode."
        fi
    fi
fi

if [[ "$IS_ACTIVE" == "false" ]]; then
    [[ -n "$STATUS_MSG" ]] && echo -e "⚠️  \\x1b[33m[Agent Tunnel]\\x1b[0m $STATUS_MSG"
    echo -e "⚙️  Executing locally..."
    eval "$@"
    exit $?
fi

[[ -n "$STATUS_MSG" ]] && echo -e "📡 \\x1b[36m[Agent Tunnel]\\x1b[0m $STATUS_MSG"

# 3. Preparar comando remoto
LOCAL_ROOT=$(_gemini_normalize_path "${LOCAL_ROOT:-$CURRENT_DIR}")
REMOTE_ROOT=$(_gemini_normalize_path "${REMOTE_ROOT:-/}")
RELATIVE_PATH="${CURRENT_DIR#$LOCAL_ROOT}"
[[ "$RELATIVE_PATH" != /* && -n "$RELATIVE_PATH" ]] && RELATIVE_PATH="/$RELATIVE_PATH"
FINAL_REMOTE_PATH=$(_gemini_normalize_path "${REMOTE_ROOT}${RELATIVE_PATH}")
COMMAND="$*"

# 4. Log al servidor de forma segura
LOG_PAYLOAD=$(node -e "
const data = { type: 'command', cmd: process.argv[1], path: process.argv[2] };
console.log(JSON.stringify(data));
" "$COMMAND" "$FINAL_REMOTE_PATH")
curl -s -X POST -H "Content-Type: application/json" -d "$LOG_PAYLOAD" http://127.0.0.1:3456/api/log > /dev/null

# 5. Ejecución remota vía SSH
SSH_KEY="$HOME/.ssh/id_ed25519_bridge"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
[ -f "$SSH_KEY" ] && SSH_OPTS="$SSH_OPTS -i $SSH_KEY"

if [[ "$GEMINI_BRIDGE_HAS_MUTAGEN" == "true" ]]; then
    SSH_CMD="mkdir -p \"$FINAL_REMOTE_PATH\" && cd \"$FINAL_REMOTE_PATH\" && $COMMAND"
else
    SSH_CMD="cd \"$FINAL_REMOTE_PATH\" 2>/dev/null || cd ~; $COMMAND"
fi

OUTPUT=$(ssh $SSH_OPTS -p "$PORT" "$USER@$HOST" "$SSH_CMD" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 255 ]]; then
    echo -e "❌ \\x1b[31m[Agent Tunnel] SSH Connection Error:\\x1b[0m\n$OUTPUT"
    echo -e "\\x1b[33mFalling back to local execution...\\x1b[0m"
    eval "$@"
    exit $?
fi

# 6. Log del resultado de forma segura
RESULT_PAYLOAD=$(node -e "
let exit_code;
try {
    exit_code = parseInt(process.argv[2]);
} catch (e) {
    exit_code = 1;
}
const data = { type: 'result', cmd: process.argv[1], exit_code: exit_code, output: process.argv[3] };
console.log(JSON.stringify(data));
" "$COMMAND" "$EXIT_CODE" "$OUTPUT")
curl -s -X POST -H "Content-Type: application/json" -d "$RESULT_PAYLOAD" http://127.0.0.1:3456/api/log > /dev/null

echo "$OUTPUT"
exit $EXIT_CODE
