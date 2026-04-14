# Gemini Bridge - Shell Integration
# Autor: Gemini CLI

# Variable para control manual
export GEMINI_BRIDGE_ENABLED="true"

# 1. Utility functions (Robust Parsing)
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

tunnel-off() {
    export GEMINI_BRIDGE_ENABLED="false"
    echo -e "⏸️  \\x1b[33mGemini Bridge\\x1b[0m: Intercepción desactivada. Comandos locales activos."
}

tunnel-on() {
    export GEMINI_BRIDGE_ENABLED="true"
    echo -e "🚀 \\x1b[32mGemini Bridge\\x1b[0m: Intercepción reactivada. Comandos irán al remoto."
}

_gemini_bridge_check_path() {
    # 1. Control manual
    [[ "$GEMINI_BRIDGE_ENABLED" == "false" ]] && return 1
    
    # 2. Si se ha borrado activate.sh (Stop en web) o el directorio de config
    # Esta es la señal de DESACTIVACIÓN DEFINITIVA
    [[ -n "$GEMINI_BRIDGE_PROJECT_ROOT" && ! -f "$GEMINI_BRIDGE_PROJECT_ROOT/activate.sh" ]] && return 1

    local CURRENT_DIR=$(_gemini_normalize_path "$(pwd)")

    # 3. Comprobar si estamos en el proyecto activo (vía env)
    if [[ -n "$GEMINI_BRIDGE_HOST" && -n "$GEMINI_BRIDGE_PROJECT_ROOT" ]]; then
        local ROOT=$(_gemini_normalize_path "$GEMINI_BRIDGE_PROJECT_ROOT")
        if [[ "$CURRENT_DIR" == "$ROOT" || "$CURRENT_DIR" == "$ROOT"/* ]]; then
             # Verificar si el config .json existe para este proyecto
             # Si no hay config, se desactiva
             if [[ -f "$HOME/.gemini-bridge/configs/${GEMINI_BRIDGE_SESSION}.json" ]]; then
                 return 0
             fi
        fi
    fi

    # 4. Fallback manual: buscar en configs (Modo sin variables de entorno)
    local CONFIGS_DIR="$HOME/.gemini-bridge/configs"
    [[ ! -d "$CONFIGS_DIR" ]] && return 1
    for f in "$CONFIGS_DIR"/*.json; do
        [ -e "$f" ] || continue
        local LP=$(_gemini_parse_json "$f" local_path)
        LP=$(_gemini_normalize_path "$LP")
        [[ -n "$LP" ]] && [[ "$CURRENT_DIR" == "$LP" || "$CURRENT_DIR" == "$LP"/* ]] && return 0
    done
    return 1
}

_gemini_is_excluded() {
    local cmd="$1"
    local session="$GEMINI_BRIDGE_SESSION"
    [[ -z "$session" ]] && return 1

    local CONFIG_FILE="$HOME/.gemini-bridge/configs/${session}.json"
    [[ ! -f "$CONFIG_FILE" ]] && return 1

    local EXCLUDED=$(_gemini_parse_json "$CONFIG_FILE" excluded_commands)
    local MODE=$(_gemini_parse_json "$CONFIG_FILE" exclude_mode)
    [[ -z "$EXCLUDED" ]] && return 1

    # Convertir lista separada por comas en un array, manejando espacios alrededor de las comas
    local clean_excluded=$(echo "$EXCLUDED" | sed 's/[[:space:]]*,[[:space:]]*/,/g' | xargs)
    IFS=',' read -ra ADDR <<< "$clean_excluded"
    for item in "${ADDR[@]}"; do
        [[ -z "$item" ]] && continue

        if [[ "$MODE" == "exact" ]]; then
            [[ "$cmd" == "$item" ]] && return 0
        else
            # Prefix mode (default)
            [[ "$cmd" == "$item"* ]] && return 0
        fi
    done
    return 1
}

# --- ZSH HOOK ---
if [ -n "$ZSH_VERSION" ]; then
    gemini-bridge-accept-line() {
        local first_word="${${(z)BUFFER}[1]}"

        # NO interceptar si es un comando de control, el ejecutor o activación
        if [[ "$first_word" == "tunnel-on" || "$first_word" == "tunnel-off" || "$first_word" == "source" || "$first_word" == "." || "$BUFFER" == *"remote-exec.sh"* ]]; then
            zle .accept-line
            return
        fi

        # Ignorar navegación básica (ls ya no se ignora por petición del usuario)
        if [[ -z "$BUFFER" || "$first_word" == "cd" || "$first_word" == "exit" ]]; then
            zle .accept-line
            return
        fi

        # Comprobar exclusiones configuradas por el usuario
        if _gemini_is_excluded "$BUFFER"; then
            zle .accept-line
            return
        fi

        if _gemini_bridge_check_path; then
            local EXEC_PATH="${GEMINI_BRIDGE_REMOTE_EXEC:-$HOME/.gemini-bridge/bin/remote-exec.sh}"
            [[ -f "$EXEC_PATH" ]] && BUFFER="$EXEC_PATH $BUFFER"
        fi
        zle .accept-line
    }
    zle -N accept-line gemini-bridge-accept-line
    echo -e "🚀 \x1b[32mGemini Bridge\x1b[0m Hook Zsh activo. (Comandos: tunnel-off / tunnel-on)"
fi

# --- BASH HOOK ---
if [ -n "$BASH_VERSION" ]; then
    _gemini_bridge_bash_hook() {
        # Evitar recursión y comandos de control
        [[ "$BASH_COMMAND" == *"remote-exec.sh"* ]] && return
        [[ "$BASH_COMMAND" == "tunnel-on" ]] && return
        [[ "$BASH_COMMAND" == "tunnel-off" ]] && return
        [[ "$BASH_COMMAND" == "source "* ]] && return
        [[ "$BASH_COMMAND" == ". "* ]] && return

        local first_word=$(echo "$BASH_COMMAND" | awk '{print $1}')
        [[ -z "$first_word" || "$first_word" == "cd" || "$first_word" == "exit" ]] && return

        # Comprobar exclusiones configuradas por el usuario
        if _gemini_is_excluded "$BASH_COMMAND"; then
            return
        fi

        if _gemini_bridge_check_path; then

             local EXEC_PATH="${GEMINI_BRIDGE_REMOTE_EXEC:-$HOME/.gemini-bridge/bin/remote-exec.sh}"
             if [[ -f "$EXEC_PATH" ]]; then
                 # Ejecutar remotamente y cancelar ejecución local
                 "$EXEC_PATH" "$BASH_COMMAND"
                 return 1
             fi
        fi
    }
    # extdebug permite que el retorno 1 de un trap DEBUG aborte el comando
    shopt -s extdebug
    trap '_gemini_bridge_bash_hook' DEBUG
    echo -e "🚀 \\x1b[32mGemini Bridge\\x1b[0m Hook Bash activo. (Comandos: tunnel-off / tunnel-on)"
fi
