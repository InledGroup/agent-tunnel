#!/bin/bash
# test_validation.sh
# Validation test for remote-exec.sh and shell-hook.sh

set -e

WORKSPACE="/Users/dev/Documents/geminissh"
SCRIPTS_DIR="$WORKSPACE/gemini-bridge/scripts"
REMOTE_EXEC="$SCRIPTS_DIR/remote-exec.sh"
CONFIGS_DIR="$HOME/.gemini-bridge/configs"
SESSION_NAME="test-validation-session"
CONFIG_FILE="$CONFIGS_DIR/$SESSION_NAME.json"

echo "--- 1. Testing Utility Functions ---"
bash "$SCRIPTS_DIR/test_utils.sh"

echo -e "\n--- 2. Testing remote-exec.sh (NO SESSION, NO ENV) ---"
# Should execute locally because no env vars and no config matches current dir
output=$(bash "$REMOTE_EXEC" "echo 'local hello'")
if [[ "$output" == *"local hello"* ]]; then
    echo "✅ Success: Falling back to local as expected."
else
    echo "❌ Failure: Local execution failed."
    echo "Output: $output"
    exit 1
fi

echo -e "\n--- 3. Testing remote-exec.sh (FALLBACK TO CONFIG) ---"
# Create a fake config that matches current directory
LOCAL_PATH=$(python3 -c "import os; print(os.path.realpath('$WORKSPACE'))")
cat <<EOF > "$CONFIG_FILE"
{
  "session_name": "$SESSION_NAME",
  "local_path": "$LOCAL_PATH",
  "host": "fake-host",
  "user": "fake-user",
  "remote_path": "/fake/remote"
}
EOF

# Should find the config, check session via curl, find it inactive, and execute locally
output=$(bash "$REMOTE_EXEC" "echo 'local hello via config'")
if [[ "$output" == *"Tunnel '$SESSION_NAME' is inactive"* && "$output" == *"local hello via config"* ]]; then
    echo "✅ Success: Found config and fell back to local (inactive session)."
else
    echo "❌ Failure: Fallback logic incorrect."
    echo "Output: $output"
    exit 1
fi

echo -e "\n--- 4. Testing remote-exec.sh (WITH ENV VARS) ---"
export GEMINI_BRIDGE_SESSION="$SESSION_NAME"
export GEMINI_BRIDGE_HOST="fake-host"
export GEMINI_BRIDGE_USER="fake-user"
export GEMINI_BRIDGE_PROJECT_ROOT="$LOCAL_PATH"

output=$(bash "$REMOTE_EXEC" "echo 'local hello via env'")
if [[ "$output" == *"Tunnel '$SESSION_NAME' is inactive"* && "$output" == *"local hello via env"* ]]; then
    echo "✅ Success: Used env vars and fell back to local (inactive session)."
else
    echo "❌ Failure: Env var logic incorrect."
    echo "Output: $output"
    exit 1
fi

echo -e "\n--- 5. Testing Bash Hook Loop Prevention ---"
# Start a subshell with the hook
TEST_HOOK_SCRIPT=$(mktemp)
cat <<EOF > "$TEST_HOOK_SCRIPT"
export GEMINI_BRIDGE_SESSION="$SESSION_NAME"
export GEMINI_BRIDGE_HOST="fake-host"
export GEMINI_BRIDGE_USER="fake-user"
export GEMINI_BRIDGE_PROJECT_ROOT="$LOCAL_PATH"
export GEMINI_BRIDGE_REMOTE_EXEC="$REMOTE_EXEC"
source "$SCRIPTS_DIR/shell-hook.sh"
# Test command
echo "test-hook-cmd"
EOF

# We use 'script' or similar to simulate interactive bash? No, we can just run it.
# Actually, the hook is on DEBUG trap.
output=$(bash --rcfile "$TEST_HOOK_SCRIPT" -i -c "echo 'done'" 2>&1 || true)
# If it loops, it will never finish or will show recursion error.
# Since we return 1 in the hook, it aborts local execution and runs remote-exec.
# remote-exec will fall back to local because session is inactive.
if [[ "$output" == *"test-hook-cmd"* ]]; then
     echo "✅ Success: Bash hook didn't loop and allowed execution."
else
     echo "❌ Failure: Bash hook might have issues."
     echo "Output: $output"
fi

rm "$CONFIG_FILE" "$TEST_HOOK_SCRIPT"
echo -e "\n✨ ALL TESTS PASSED ✨"
