#!/bin/bash
# remote-exec.sh
# Executes commands on remote target via SSH, but only if the bridge session is active.

# 1. Utility functions
_gemini_parse_json() {
    python3 -c "
import sys, json
try:
    content = sys.argv[1]
    key = sys.argv[2]
    if content.startswith('{') or content.startswith('['):
        data = json.loads(content)
    else:
        with open(content, 'r') as f:
            data = json.load(f)
    
    val = data
    for part in key.split('.'):
        if isinstance(val, dict):
            val = val.get(part, '')
        else:
            val = ''
            break
    if isinstance(val, (dict, list)):
        print(json.dumps(val))
    else:
        print(val)
except Exception:
    pass
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

# Prioridad 1: Buscar si el directorio actual coincide con alguna config guardada
MATCHED_CONFIG=""
for f in "$CONFIGS_DIR"/*.json; do
    [ -e "$f" ] || continue
    LP=$(_gemini_parse_json "$f" local_path)
    LP=$(_gemini_normalize_path "$LP")
    if [[ -n "$LP" && "$CURRENT_DIR" == "$LP"* ]]; then
        MATCHED_CONFIG="$f"
        break
    fi
done

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
    USER=$(_gemini_parse_json "$MATCHED_CONFIG" user)
    REMOTE_ROOT=$(_gemini_parse_json "$MATCHED_CONFIG" remote_path)
    SESSION_NAME=$(basename "$MATCHED_CONFIG" .json)
    LOCAL_ROOT=$(_gemini_parse_json "$MATCHED_CONFIG" local_path)
else
    # Fallback a variables de entorno si no hay match por directorio
    HOST="${GEMINI_BRIDGE_HOST}"
    USER="${GEMINI_BRIDGE_USER}"
    LOCAL_ROOT="${GEMINI_BRIDGE_PROJECT_ROOT}"
    REMOTE_ROOT="${GEMINI_BRIDGE_REMOTE_ROOT}"
    SESSION_NAME="${GEMINI_BRIDGE_SESSION}"
fi

# 2. VERIFICACIÓN DE SESIÓN ACTIVA
IS_ACTIVE="false"
STATUS_MSG=""

if [[ -n "$SESSION_NAME" ]]; then
    VALID_SESSION=$(echo "$SESSION_NAME" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9_-]//g')
    
    SESSIONS_JSON=$(curl -s --max-time 2 http://127.0.0.1:3456/api/sessions 2>/dev/null)
    CURL_EXIT=$?

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
LOG_PAYLOAD=$(python3 -c "
import sys, json
data = {'type': 'command', 'cmd': sys.argv[1], 'path': sys.argv[2]}
print(json.dumps(data))
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

OUTPUT=$(ssh $SSH_OPTS "$USER@$HOST" "$SSH_CMD" 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -eq 255 ]]; then
    echo -e "❌ \\x1b[31m[Agent Tunnel] SSH Connection Error:\\x1b[0m\n$OUTPUT"
    echo -e "\\x1b[33mFalling back to local execution...\\x1b[0m"
    eval "$@"
    exit $?
fi

# 6. Log del resultado de forma segura
RESULT_PAYLOAD=$(python3 -c "
import sys, json
try:
    exit_code = int(sys.argv[2])
except:
    exit_code = 1
data = {'type': 'result', 'cmd': sys.argv[1], 'exit_code': exit_code, 'output': sys.argv[3]}
print(json.dumps(data))
" "$COMMAND" "$EXIT_CODE" "$OUTPUT")
curl -s -X POST -H "Content-Type: application/json" -d "$RESULT_PAYLOAD" http://127.0.0.1:3456/api/log > /dev/null

echo "$OUTPUT"
exit $EXIT_CODE
