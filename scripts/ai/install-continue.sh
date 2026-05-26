#!/usr/bin/env bash
# Install Continue.dev — open-source AI assistant for VS Code / VSCodium / Neovim
set -euo pipefail

CONTINUE_VERSION="${1:-latest}"
INSTALL_DIR="${2:-$HOME/.local/share/continue}"

echo "Installing Continue.dev ($CONTINUE_VERSION)..."
echo ""

# Detect editor
EDITOR=""
if command -v code &>/dev/null; then
  EDITOR="vscode"
elif command -v vscodium &>/dev/null; then
  EDITOR="vscodium"
elif command -v nvim &>/dev/null; then
  EDITOR="neovim"
fi

case "$EDITOR" in
  vscode)
    echo "Install VS Code extension:"
    echo "  code --install-extension continue.continue"
    code --install-extension continue.continue 2>/dev/null || {
      echo "  Trying marketplace URL..."
      open "https://marketplace.visualstudio.com/items?itemName=continue.continue" 2>/dev/null || true
    }
    ;;
  vscodium)
    echo "Install VSCodium extension:"
    echo "  vscodium --install-extension continue.continue"
    vscodium --install-extension continue.continue 2>/dev/null || {
      echo "  Download from: https://github.com/continuedev/continue/releases"
    }
    ;;
  neovim)
    echo "Install continue.nvim:"
    echo "  Add to ~/.config/nvim:"
    echo '  { "github.com/continuedev/continue.nvim" }'
    ;;
  *)
    echo "No supported editor found (VS Code / VSCodium / Neovim)."
    echo "Install Continue.dev manually: https://docs.continue.dev/install"
    ;;
esac

# Config example with Ollama
CONFIG_DIR="$HOME/.continue"
if [[ ! -d "$CONFIG_DIR" ]]; then
  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_DIR/config.json" << 'CONFIGEOF'
{
  "models": [
    {
      "title": "Qwen 2.5 Coder",
      "provider": "ollama",
      "model": "qwen2.5-coder:7b"
    },
    {
      "title": "Llama 3.2",
      "provider": "ollama",
      "model": "llama3.2:3b"
    },
    {
      "title": "Codellama",
      "provider": "ollama",
      "model": "codellama:7b"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Qwen 2.5 Coder",
    "provider": "ollama",
    "model": "qwen2.5-coder:7b"
  }
}
CONFIGEOF
  echo "Created config: $CONFIG_DIR/config.json (Ollama models)"
fi

echo ""
echo "Continue.dev installed! Config: $CONFIG_DIR/config.json"
echo "Docs: https://docs.continue.dev"
