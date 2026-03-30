#!/bin/bash

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
except Exception as e:
    # sys.stderr.write(f'Error: {e}\\n')
    pass
" "$1" "$2"
}

_gemini_normalize_path() {
    local p="$1"
    p=$(echo "$p" | tr -s '/')
    [[ "$p" != "/" ]] && p="${p%/}"
    echo "$p"
}

# Test JSON Parsing
echo '{"local_path": "/home/user/project", "host": "example.com"}' > test.json
echo "Test 1 (File): $(_gemini_parse_json test.json local_path)"
echo "Test 2 (String): $(_gemini_parse_json '{"a": "b"}' a)"
echo "Test 3 (Nested): $(_gemini_parse_json '{"a": {"b": "c"}}' a.b)"

# Test Normalization
echo "Test 4 (Path): $(_gemini_normalize_path "/foo/bar//baz/")"
echo "Test 5 (Root): $(_gemini_normalize_path "/")"

rm test.json
