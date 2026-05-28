#!/usr/bin/env bash
# Install Model Context Protocol (MCP) servers
# MCP стандарт 2025-2026 для интеграции AI с инструментами
set -euo pipefail

echo "Installing MCP servers..."
echo ""

# Filesystem MCP server
if command -v npx &>/dev/null; then
  echo "[1/3] @modelcontextprotocol/server-filesystem"
  npx -y @modelcontextprotocol/server-filesystem --help &>/dev/null && \
    echo "  OK: filesystem MCP server available via npx" || \
    echo "  WARNING: filesystem MCP server install failed"

  echo "[2/3] @modelcontextprotocol/server-github"
  npx -y @modelcontextprotocol/server-github --help &>/dev/null && \
    echo "  OK: github MCP server available via npx" || \
    echo "  WARNING: github MCP server install failed"
else
  echo "npx not found — install Node.js first"
  exit 1
fi

# Brave Search MCP server
echo "[3/3] @modelcontextprotocol/server-brave-search"
npx -y @modelcontextprotocol/server-brave-search --help &>/dev/null && \
  echo "  OK: brave-search MCP server available via npx" || \
  echo "  WARNING: brave-search MCP server install failed"

echo ""
echo "MCP servers installed! Available via npx:"
echo "  npx -y @modelcontextprotocol/server-filesystem <dirs...>"
echo "  npx -y @modelcontextprotocol/server-github"
echo "  npx -y @modelcontextprotocol/server-brave-search"
echo ""
echo "Add to opencode config (~/.opencode.jsonc):"
echo '  "mcpServers": {'
echo '    "filesystem": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path"] },'
echo '    "github": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-github"] }'
echo '  }'
