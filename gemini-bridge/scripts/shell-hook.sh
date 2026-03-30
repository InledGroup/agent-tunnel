# Gemini Bridge - Shell Integration
# Autor: Gemini CLI

_gemini_bridge_check_path() {
    # Si tenemos las variables de entorno de activate.sh, confiamos en ellas
    if [[ -n "$GEMINI_BRIDGE_HOST" && -n "$GEMINI_BRIDGE_PROJECT_ROOT" ]]; then
        if [[ "$(pwd)" == "$GEMINI_BRIDGE_PROJECT_ROOT"* ]]; then
            return 0
        fi
    fi

    # Fallback a búsqueda manual en configs si no se usó activate.sh
    local CONFIGS_DIR="$HOME/.gemini-bridge/configs"
    local CURRENT_DIR=$(pwd)
    if [[ ! -d "$CONFIGS_DIR" ]]; then return 1; fi

    for f in "$CONFIGS_DIR"/*.json; do
        [ -e "$f" ] || continue
        local LP=$(grep -o '"local_path": "[^"]*' "$f" | head -1 | cut -d'"' -f4)
        if [[ "$CURRENT_DIR" == "$LP"* ]]; then
            return 0
        fi
    done
    return 1
}

# Para Zsh (Mac)
if [ -n "$ZSH_VERSION" ]; then
    gemini-bridge-accept-line() {
        # Evitar recursividad si el comando ya contiene el wrapper
        if [[ "$BUFFER" == *"remote-exec.sh"* ]]; then
            zle .accept-line
            return
        fi

        # Ignorar comandos básicos o de navegación
        if [[ -z "$BUFFER" || "$BUFFER" == cd* || "$BUFFER" == "exit" || "$BUFFER" == "pwd" || "$BUFFER" == "ls" ]]; then
            zle .accept-line
            return
        fi

        if _gemini_bridge_check_path; then
            # Usar la variable de entorno del ejecutor absoluto definida en activate.sh
            local EXEC_PATH="${GEMINI_BRIDGE_REMOTE_EXEC}"
            
            # Si por algún motivo no está la variable, no podemos interceptar con seguridad
            if [[ -n "$EXEC_PATH" && -f "$EXEC_PATH" ]]; then
                BUFFER="$EXEC_PATH $BUFFER"
            fi
        fi
        zle .accept-line
    }
    # Solo interceptamos si no se ha hecho ya para evitar duplicados al re-activar
    if ! zle -l accept-line | grep -q gemini-bridge-accept-line; then
        zle -N accept-line gemini-bridge-accept-line
    fi
    echo -e "🚀 \\x1b[32mGemini Bridge\\x1b[0m Hook Zsh activo. Comandos en este directorio irán al remoto."
fi
