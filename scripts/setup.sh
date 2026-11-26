#!/usr/bin/env bash
# Jibesh Web Server Monk setup wizard v2.1
set -Eeuo pipefail

VERSION="2.1"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jwsm"
CONFIG_FILE="${CONFIG_DIR}/config"
BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
CYAN=$'\033[36m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'

box() {
  printf "\n${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}\n"
  printf "${CYAN}║${RESET}  ${BOLD}%-54s${RESET}${CYAN}║${RESET}\n" "$1"
  printf "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}\n"
}
say() { printf "  %s\n" "$*"; }
ok() { printf "  ${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${RESET} %s\n" "$*"; }
confirm() {
  local answer
  read -r -p "  $1 [y/N] " answer || true
  [[ "$answer" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]
}
need_debian() {
  [[ -r /etc/os-release ]] || { say "Cannot identify this OS."; exit 1; }
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}" in
    debian|ubuntu|linuxmint|pop|raspbian|zorin|elementary) return ;;
    *) case " ${ID_LIKE:-} " in *" debian "*) return ;; esac ;;
  esac
  say "Jib setup currently supports Debian-based distributions only."
  exit 1
}
install_nginx_if_needed() {
  if command -v nginx >/dev/null 2>&1; then ok "Nginx detected."; return; fi
  warn "Nginx is not installed."
  if confirm "Install Nginx using APT now?"; then
    sudo apt-get update
    sudo apt-get install -y nginx
    sudo systemctl enable --now nginx
  else
    say "Install it later with: sudo apt install nginx"
    return 1
  fi
}
tailscale_if_needed() {
  if command -v tailscale >/dev/null 2>&1; then ok "Tailscale detected."; return; fi
  warn "Tailscale is not installed."
  say "Official installation guide: https://tailscale.com/download/linux"
  say "After installing, connect this machine with: sudo tailscale up"
  if confirm "Open the official Tailscale download page?"; then
    if command -v xdg-open >/dev/null 2>&1; then xdg-open "https://tailscale.com/download/linux" >/dev/null 2>&1 &
    else say "Visit https://tailscale.com/download/linux"; fi
  fi
}
main() {
  need_debian
  mkdir -p "$CONFIG_DIR"
  box "JIBESH SERVER SETUP WIZARD"
  say "This wizard prepares Nginx and Tailscale integration."
  say "It will not publish your server without a separate confirmation."
  printf "\n"

  local web_root web_port git_repo git_branch
  web_root="/var/www/html"
  web_port="8080"
  git_repo=""
  git_branch="main"

  read -r -p "  Website directory [${web_root}]: " input_root || true
  [[ -n "${input_root:-}" ]] && web_root="$input_root"
  read -r -p "  Local Nginx port [${web_port}]: " input_port || true
  [[ -n "${input_port:-}" ]] && web_port="$input_port"
  [[ "$web_port" =~ ^[0-9]+$ ]] && (( web_port >= 1024 && web_port <= 65535 )) || { say "Choose a port between 1024 and 65535."; exit 1; }
  [[ "$web_root" = /* ]] || { say "Website directory must be an absolute path."; exit 1; }

  if [[ ! -d "$web_root" ]]; then
    if confirm "Create ${web_root}?"; then sudo mkdir -p "$web_root"; else say "Website directory is required."; exit 1; fi
  fi

  printf "\n"
  if ! install_nginx_if_needed; then
    warn "Skipping Nginx configuration because Nginx is unavailable."
  else
    # Use a loopback-only listener to avoid colliding with an existing default
    # website on port 80. Funnel forwards public HTTPS to this local port.
    if sudo ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${web_port}$"; then
      say "Port ${web_port} appears to be in use. Choose another port and rerun jib setup."
      exit 1
    fi
    local site_tmp
    site_tmp="$(mktemp)"
    cat > "$site_tmp" <<NGINX
server {
    listen 127.0.0.1:${web_port};
    server_name localhost;

    root ${web_root};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /public/ {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
NGINX
    sudo install -m 0644 "$site_tmp" /etc/nginx/conf.d/jwsm.conf
    rm -f "$site_tmp"
    if sudo nginx -t; then
      sudo systemctl enable --now nginx
      sudo systemctl reload nginx
      ok "Nginx configured on 127.0.0.1:${web_port}."
    else
      sudo rm -f /etc/nginx/conf.d/jwsm.conf
      say "Nginx configuration test failed; the Jib config was removed."
      exit 1
    fi
  fi

  printf "\n"
  tailscale_if_needed

  printf "\n"
  if confirm "Configure Git-based deployment (optional)?"; then
    read -r -p "  Git repository URL: " git_repo || true
    read -r -p "  Git branch [main]: " git_branch_input || true
    [[ -n "${git_branch_input:-}" ]] && git_branch="$git_branch_input"
  fi

  cat > "${CONFIG_FILE}.tmp" <<CONFIG
# Jibesh Web Server Monk configuration
JWSM_VERSION="${VERSION}"
WEB_ROOT="${web_root}"
WEB_PORT="${web_port}"
GIT_REPO="${git_repo}"
GIT_BRANCH="${git_branch}"
CONFIG
  chmod 0600 "${CONFIG_FILE}.tmp"
  mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

  box "SETUP SUMMARY"
  ok "Website root: ${web_root}"
  ok "Nginx local listener: 127.0.0.1:${web_port}"
  if command -v tailscale >/dev/null 2>&1; then
    say "Tailscale: installed (authentication may still be required)"
    if ! tailscale status >/dev/null 2>&1; then
      warn "Connect this machine with: sudo tailscale up"
    fi
  else
    warn "Tailscale: not installed yet"
  fi
  if [[ -n "$git_repo" ]]; then ok "Git deployment configured."; else say "Git deployment: not configured"; fi
  printf "\n"
  say "When Nginx and Tailscale are ready:"
  say "  jib doctor"
  say "  jib status"
  say "  jib pub"
  say "Publishing is a separate, explicit action. Funnel can make your site public."
  printf "\n"
  say "May your server never go down."
}
main "$@"
