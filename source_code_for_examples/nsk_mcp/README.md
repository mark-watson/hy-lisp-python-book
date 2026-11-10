# NSK MCP Server and Client in Hy

This example exposes the NSK knowledge graph engine from `../nsk-neural-symbolic-graph` as a Model Context Protocol (MCP) server over stdio, using JSON-RPC 2.0 (specification revision `2025-11-25`). It includes a pure in-memory JSON-RPC dispatcher, a security policy layer (deny-by-default tool allowlist, path-traversal defense, result limits, timeouts, and stderr JSONL audit logging), and a stdio client written in Hy.

## Project Structure

```
nsk_mcp/
├── data/
│   ├── authors.log       <- Seed facts and forward-chaining rules
│   └── extra_facts.sexp  <- Additional facts loaded via load-facts tool
├── nsk_path.hy           <- Adds ../nsk-neural-symbolic-graph to sys.path
├── policy.hy             <- ToolPolicy: allowlist, path checks, limits, audit log
├── server.hy             <- Pure JSON-RPC 2.0 dispatcher + stdio transport
├── client.hy             <- StdioMcpClient + end-to-end demo script
├── test_mcp.hy           <- 13 pytest tests (in-memory + subprocess stdio)
├── conftest.py           <- Pytest hook for collecting test_*.hy files
└── pyproject.toml        <- Project dependencies (hy, pytest)
```

## Prerequisites

- [uv](https://docs.astral.sh/uv/) package manager
- No external API keys, network access, or Ollama daemon required

## Running the Demo and Server

```bash
uv sync

# Run the client demo (spawns server.hy over stdio)
uv run hy client.hy

# Run the MCP server directly over stdio
uv run hy server.hy
```

## Running the Tests

```bash
uv run pytest -q
```
