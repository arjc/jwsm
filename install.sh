#!/usr/bin/env bash
# Jibesh Web Server Monk v2.1 installer
set -Eeuo pipefail

VERSION="2.1"
BASE_URL="${JWSM_BASE_URL:-https://arjc.github.io/jwsm}"
INSTALL_BIN="${HOME}/.local/bin"
INSTALL_LIB="${HOME}/.local/lib/jwsm"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jwsm"

BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
CYAN=$'\033[36m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'

box() {
  local title="$1"
  printf "\n${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}\n"
  printf "${CYAN}║${RESET}  ${BOLD}%-54s${RESET}${CYAN}║${RESET}\n" "$title"
  printf "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}\n"
}
say() { printf "  %s\n" "$*"; }
die() { printf "\n${RED}  ERROR:${RESET} %s\n" "$*" >&2; exit 1; }
confirm() {
  local answer
  read -r -p "  $1 [y/N] " answer || true
  [[ "$answer" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}

[[ "${EUID}" -ne 0 ]] || die "Please run this installer as your normal user, not with sudo."
[[ -n "${HOME:-}" ]] || die "HOME is not set."
command -v curl >/dev/null 2>&1 || die "curl is required. Install it with: sudo apt install curl"

box "JIBESH WEB SERVER MONK  v${VERSION}"
say "Your server. Your rules. Your internet."
printf "\n"
say "Wanna install Jibesh Web Server Monk v${VERSION}?"
printf "\n"
say "[Y] Yes, install Jib"
say "[N] No, exit"
printf "\n"
confirm "Continue with installation?" || { say "Installation cancelled. Stay curious, monk."; exit 0; }

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    debian|ubuntu|linuxmint|pop|raspbian|zorin|elementary) ;;
    *)
      case " ${ID_LIKE:-} " in
        *" debian "*) ;;
        *) die "This release supports Debian-based distributions. Detected: ${PRETTY_NAME:-unknown}" ;;
      esac
      ;;
  esac
else
  die "Cannot identify this operating system."
fi

mkdir -p "$INSTALL_BIN" "$INSTALL_LIB" "$CONFIG_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

download() {
  local remote="$1" dest="$2"
  say "Downloading ${remote}..."
  curl --fail --silent --show-error --location \
    --proto '=https' --tlsv1.2 \
    "${BASE_URL}/${remote}" -o "${dest}" ||
    die "Could not download ${remote} from ${BASE_URL}. Check the GitHub Pages deployment."
}

download "scripts/jib" "$tmp/jib"
download "scripts/setup.sh" "$tmp/setup.sh"

bash -n "$tmp/jib" || die "The downloaded jib CLI failed its Bash syntax check."
bash -n "$tmp/setup.sh" || die "The downloaded setup wizard failed its Bash syntax check."

install -m 0755 "$tmp/jib" "$INSTALL_BIN/jib"
install -m 0644 "$tmp/setup.sh" "$INSTALL_LIB/setup.sh"

cat > "${CONFIG_DIR}/config" <<'CONFIG'
# Jibesh Web Server Monk configuration
JWSM_VERSION="2.1"
WEB_ROOT="/var/www/html"
WEB_PORT="8080"
GIT_REPO=""
GIT_BRANCH="main"
CONFIG
chmod 0600 "${CONFIG_DIR}/config"

if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.profile" 2>/dev/null; then
  printf '\n# Jibesh Web Server Monk\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "${HOME}/.profile"
fi
if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "${HOME}/.bashrc" 2>/dev/null; then
  printf '\n# Jibesh Web Server Monk\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "${HOME}/.bashrc"
fi

box "INSTALLATION COMPLETE"
say "Jib v${VERSION} has been installed."
say "Executable : ${INSTALL_BIN}/jib"
say "Config     : ${CONFIG_DIR}/config"
say "Library    : ${INSTALL_LIB}"
printf "\n"
say "Next step: run this command to configure your server:"
printf "\n    ${BOLD}jib setup${RESET}\n\n"
if [[ ":$PATH:" != *":${INSTALL_BIN}:"* ]]; then
  say "Your current shell may not know the new PATH yet."
  say "Run:  source ~/.bashrc"
fi
say "Nginx and Tailscale are NOT installed automatically."
say "Jib setup will detect missing dependencies and ask before offering installation."
printf "\n"
say "May your server never go down."
