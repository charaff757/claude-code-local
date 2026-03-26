#!/bin/bash
# Claude Code — Local AI (runs on your Mac, no cloud)
# Double-click to launch
# Uses TurboQuant llama-server for 4.9x KV cache compression

CLAUDE_BIN="/Users/dtribe/.local/bin/claude"
PROXY="/Users/dtribe/.local/claude-local-proxy/proxy.py"
LLAMA_SERVER="/Users/dtribe/llama-cpp-turboquant/build/bin/llama-server"
MODEL="$HOME/local_llms/models/qwen122b-parts/Qwen3.5-122B-A10B-Q4_K_M-00001-of-00003.gguf"

# Start llama-server with TurboQuant if not running
if ! lsof -i :8090 >/dev/null 2>&1; then
  "$LLAMA_SERVER" \
    -m "$MODEL" \
    -ngl 99 -c 4096 -fa on \
    --cache-type-k turbo3 --cache-type-v turbo3 \
    -np 1 --host 127.0.0.1 --port 8090 >/tmp/llama-server.log 2>&1 &
  echo "  Loading model (41 tok/s with TurboQuant)..."
  while ! curl -s http://localhost:8090/health 2>/dev/null | grep -q "ok"; do
    sleep 2
  done
fi

# Start proxy in TurboQuant mode if not running
if ! lsof -i :4000 >/dev/null 2>&1; then
  PROXY_BACKEND=turbo python3 "$PROXY" >/dev/null 2>&1 &
  sleep 2
fi

clear
echo ""
echo "  → Claude Code with LOCAL AI (Qwen 3.5 122B)"
echo "  → TurboQuant: 4.9x cache compression, 41 tok/s"
echo "  → Running on your M5 Max — no cloud, no API fees"
echo ""

ANTHROPIC_BASE_URL=http://localhost:4000 \
ANTHROPIC_API_KEY=sk-local \
exec "$CLAUDE_BIN" --model claude-sonnet-4-6
