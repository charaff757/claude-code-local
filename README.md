# Claude Code Local — Run AI Coding Agents Entirely On Your Mac

Run Claude Code with a 122 billion parameter AI model on Apple Silicon. No cloud. No API fees. No data leaves your machine.

Now with **Google's TurboQuant** — 4.9x KV cache compression at full speed.

```
You → Claude Code → Local Proxy → llama-server (TurboQuant) → Qwen 3.5 122B → Apple Silicon GPU
```

## Why This Exists

Claude Code is the best AI coding agent available. But it requires an internet connection and an API subscription. This project bridges that gap — it lets you run Claude Code powered by a local model when you're offline, want privacy, or just don't want to pay per token.

**What you get:**
- Full Claude Code experience (Cowork, projects, tools, file editing) powered by local AI
- 122B parameter model generating production-quality code at **41 tokens/second**
- TurboQuant KV cache compression — **4.9x smaller cache, no quality loss**
- Chrome DevTools Protocol (CDP) browser control — your real browser, not a sandbox
- Everything runs on-device. Your code never touches a server.

## Benchmarks — Qwen 3.5 122B on M5 Max (128 GB)

### TurboQuant vs Baseline

| Cache Type | Compression | Speed | Coding Task |
|------------|-------------|-------|-------------|
| q8_0 (baseline) | 2.0x | 43.7 tok/s | 11.4s |
| **turbo3 (TurboQuant)** | **4.9x** | **41.0 tok/s** | **11.2s** |

94% of baseline speed at 2.4x better compression. The real win is long context — turbo3's smaller cache means coding sessions stay fast where baseline would choke.

### Before TurboQuant (via Ollama)

| Test | Speed | Result |
|------|-------|--------|
| Code generation | 30.3 tok/s | Correct |
| Claude Code end-to-end | ~30 tok/s | Correct |

### After TurboQuant (via llama-server)

| Test | Speed | Result |
|------|-------|--------|
| Code generation | **41.0 tok/s** | Correct |
| Claude Code end-to-end | **~41 tok/s** | Correct |

**37% faster** than the Ollama setup, with 4.9x cache compression on top.

## Requirements

- **Mac with Apple Silicon** (M1 Pro/Max or later recommended)
- **Memory requirements:**
  - 122B model: 96+ GB unified memory (M2/M3/M4/M5 Max or Ultra)
  - 35B MoE model: 32+ GB (Pro-tier Macs)
  - Smaller models: 8+ GB (any Apple Silicon Mac)
- **Claude Code** installed (`npm install -g @anthropic-ai/claude-code`)
- **cmake** for building llama.cpp (`brew install cmake`)

## Quick Start

### 1. Build llama-server with TurboQuant

```bash
git clone https://github.com/TheTom/llama-cpp-turboquant.git
cd llama-cpp-turboquant
git checkout feature/turboquant-kv-cache
cmake -B build -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

### 2. Download a model

```bash
# 122B (71 GB — needs 96+ GB RAM)
# This is a 3-part GGUF from HuggingFace:
mkdir -p ~/local_llms/models/qwen122b
cd ~/local_llms/models/qwen122b
BASE="https://huggingface.co/unsloth/Qwen3.5-122B-A10B-GGUF/resolve/main/Q4_K_M"
curl -L -C - --retry 10 -o part1.gguf "$BASE/Qwen3.5-122B-A10B-Q4_K_M-00001-of-00003.gguf"
curl -L -C - --retry 10 -o part2.gguf "$BASE/Qwen3.5-122B-A10B-Q4_K_M-00002-of-00003.gguf"
curl -L -C - --retry 10 -o part3.gguf "$BASE/Qwen3.5-122B-A10B-Q4_K_M-00003-of-00003.gguf"
```

### 3. Start llama-server with TurboQuant

```bash
./llama-cpp-turboquant/build/bin/llama-server \
  -m ~/local_llms/models/qwen122b/part1.gguf \
  -ngl 99 -c 4096 -fa on \
  --cache-type-k turbo3 --cache-type-v turbo3 \
  -np 1 --host 127.0.0.1 --port 8090
```

### 4. Start the proxy

```bash
python3 proxy/proxy.py &
```

### 5. Launch Claude Code

```bash
ANTHROPIC_BASE_URL=http://localhost:4000 \
ANTHROPIC_API_KEY=sk-local \
claude --model claude-sonnet-4-6
```

### Or: Double-click the launcher

Copy `launchers/Claude Local.command` to your Desktop. Double-click it. It auto-starts llama-server, the proxy, and Claude Code.

## Architecture

```
Claude Code                    Proxy (:4000)              llama-server (:8090)
    |                           |                              |
    |-- Anthropic Messages ---->|                              |
    |                           |-- OpenAI Chat Completions -->|
    |                           |                              | (TurboQuant turbo3
    |                           |                              |  4.9x KV compression)
    |                           |<-- Response -----------------|
    |                           |   (strips <think> tags,      |
    |                           |    extracts clean content)    |
    |<-- Anthropic response ----|                              |
```

**The proxy** translates between Claude Code's Anthropic API and llama-server's OpenAI API. It also handles Qwen 3.5's "thinking" mode — extracting clean answers from the model's internal reasoning.

**TurboQuant** compresses the KV cache (the model's conversation memory) by 4.9x using Google's PolarQuant + Walsh-Hadamard rotation algorithm. This means longer conversations stay fast.

## What is TurboQuant?

[TurboQuant](https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/) (ICLR 2026) is Google's algorithm for compressing LLM KV caches. It's different from model weight quantization (like Q4_K_M):

- **Model quantization** (Q4_K_M) shrinks the model file — applied once at download time
- **KV cache quantization** (TurboQuant) shrinks the conversation memory — applied during every inference

Both work together. Your model is Q4_K_M (weight compression) running with turbo3 (KV cache compression). Double compression, zero quality loss.

| | Without TurboQuant | With TurboQuant |
|---|---|---|
| KV cache at 32K context | ~8 GB | ~1.6 GB |
| Long conversation speed | Degrades | Stays fast |
| Max practical context | ~8K tokens | ~40K+ tokens |

## Browser Control (CDP)

Two browser control options, each serving different use cases:

| Tool | Browser | Use Case |
|------|---------|----------|
| **chrome-devtools-mcp** (CDP) | Your real Brave/Chrome | Logged-in tasks, real sessions |
| **playwright** (sandboxed) | Isolated instance | Automated jobs, scraping |

CDP controls your actual browser — already logged into GitHub, Shopify, Vercel, whatever. No re-authenticating every session.

Setup: Launch Brave with `--remote-debugging-port=9222` or visit `brave://inspect/#remote-debugging`.

## Using With Claude Max

This setup complements a Claude Max subscription:

- **Online:** Claude Code with Anthropic's API (fastest, most capable)
- **Offline/Private:** Double-click `Claude Local` for local AI (41 tok/s, fully private)
- **From your phone:** Use Dispatch or iMessage to control either mode remotely

## Project Structure

```
├── proxy/
│   └── proxy.py              # Anthropic ↔ OpenAI API translator (zero deps)
├── launchers/
│   ├── Claude Local.command   # Double-click launcher (TurboQuant + Claude Code)
│   └── Browser Agent.command  # Browser automation launcher
├── scripts/
│   ├── download-and-import.sh # GGUF model downloader
│   ├── persistent-download.sh # Auto-retry model puller
│   └── start-mlx-server.sh   # MLX server (alternative backend)
├── setup.sh                   # One-command installer
├── docs/
│   ├── BENCHMARKS.md          # Full benchmark results
│   └── TWITTER-THREAD.md      # Social media content
└── README.md
```

## Security

Every dependency in this project was audited before use:

- **Proxy** — our code, zero dependencies, 150 lines of Python
- **llama-server** — compiled from source (llama.cpp fork)
- **TurboQuant** — audited: zero network calls, zero file access, only numpy + scipy
- **No pip packages from strangers** — we removed LiteLLM after supply chain concerns

The model runs entirely on your hardware. No telemetry, no phone-home, no data exfiltration.

## Credits

Built on:
- [Claude Code](https://claude.ai/claude-code) by Anthropic
- [llama.cpp](https://github.com/ggerganov/llama.cpp) + [TurboQuant fork](https://github.com/TheTom/llama-cpp-turboquant) by TheTom
- [TurboQuant](https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/) algorithm by Google Research (ICLR 2026)
- [Qwen 3.5](https://qwenlm.github.io/) by Alibaba
- [chrome-devtools-mcp](https://github.com/anthropics/chrome-devtools-mcp) for CDP browser control
- Tested on Apple M5 Max with 128 GB unified memory

## License

MIT
