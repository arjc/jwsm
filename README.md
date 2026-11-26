# Jibesh Web Server Monk (JWSM) v2.1

A small Bash CLI and guided setup tool for Debian-based Linux machines. JWSM configures Nginx to serve a website on a loopback-only port and can use Tailscale Funnel to publish it over HTTPS.

> **Public exposure warning:** Tailscale Funnel can make your website reachable by anyone on the internet. Review the content you are serving before running `jib pub`.

## Supported systems

Debian, Ubuntu, Linux Mint and Debian-derived distributions with `apt`. The installer itself is user-local and does not require root. Server configuration uses `sudo`.

## Install

After publishing this repository with GitHub Pages at `https://arjc.github.io/jwsm/`:

```bash
curl -fsSL https://arjc.github.io/jwsm/install.sh -o /tmp/jwsm-install.sh
less /tmp/jwsm-install.sh
bash /tmp/jwsm-install.sh
```

The installer asks before proceeding, downloads `scripts/jib` and `scripts/setup.sh`, checks their Bash syntax, and installs them under:

- `~/.local/bin/jib`
- `~/.local/lib/jwsm/`
- `~/.config/jwsm/config`

If needed, refresh your shell:

```bash
source ~/.bashrc
```

## First setup

```bash
jib setup
```

The wizard:
1. Detects a Debian-based distribution.
2. Asks for a website root (default `/var/www/html`) and local port (default `8080`).
3. Offers to install Nginx if it is missing.
4. Writes `/etc/nginx/conf.d/jwsm.conf` with a loopback-only listener at `127.0.0.1:8080` (or your selected port).
5. Offers to open Tailscale's official Linux installation guide if Tailscale is missing.
6. Optionally records a Git repository for deployments.

It does **not** install Tailscale automatically, authenticate a Tailscale account, or publish the server automatically.

## Commands

```text
jib                 Open interactive menu
jib setup           Run setup wizard
jib install nginx   Offer to install Nginx
jib install tailscale  Show official Tailscale installation guidance
jib pub              Enable Tailscale Funnel after explicit confirmation
jib stop             Disable HTTPS Funnel on port 443
jib status           Show Nginx and Tailscale status
jib update           Pull and deploy configured Git repository
jib config           Show current configuration
jib doctor           Run basic diagnostics
jib uninstall        Remove Jib only; leaves Nginx/Tailscale/site files intact
```

## How publishing works

JWSM configures Nginx to listen on `127.0.0.1:<port>` rather than taking over port 80. This avoids clashing with an existing default Nginx site. When you run `jib pub`, Jib invokes:

```bash
tailscale funnel --bg http://127.0.0.1:8080
```

The local port must match your configured `WEB_PORT`. Tailscale Funnel has account, policy and HTTPS prerequisites; see the official [Funnel documentation](https://tailscale.com/kb/1223/funnel/).

To authenticate a newly installed Tailscale client:

```bash
sudo tailscale up
```

Then check:

```bash
tailscale status
tailscale funnel status
jib doctor
```

## Git deployment

If you configure a repository during setup, `jib update` clones or fast-forward-pulls its configured branch, then offers to synchronize the working tree into the website root using `rsync`.

The deployment excludes `.git/` and `/public/`. It uses `rsync --delete`, so files in the website root that are not in the repository may be deleted. Review the destination carefully before confirming.

Install Git and rsync if needed:

```bash
sudo apt install git rsync
```

## GitHub Pages deployment

1. Create a GitHub repository named `jwsm`.
2. Add `install.sh`, `README.md`, and the `scripts/` directory at the repository root.
3. In the repository, open **Settings → Pages**.
4. Under **Build and deployment**, choose **Deploy from a branch**.
5. Select branch `main` and folder `/ (root)`, then save.
6. Wait for GitHub Pages to publish the site.
7. Verify these URLs in a browser:
   - `https://arjc.github.io/jwsm/install.sh`
   - `https://arjc.github.io/jwsm/scripts/jib`
   - `https://arjc.github.io/jwsm/scripts/setup.sh`
8. Test the installer on a disposable Debian/Ubuntu VM before recommending it to others.

The public install command is:

```bash
curl -fsSL https://arjc.github.io/jwsm/install.sh -o /tmp/jwsm-install.sh && bash /tmp/jwsm-install.sh
```

If your GitHub Pages URL or repository name differs, set `JWSM_BASE_URL` before running the installer:

```bash
JWSM_BASE_URL="https://YOUR-USER.github.io/YOUR-REPO" bash /tmp/jwsm-install.sh
```

## Security and operational notes

- Do not run the installer with `sudo`; Jib is installed into the invoking user's home directory.
- Nginx configuration is installed under `/etc/nginx/conf.d/jwsm.conf`; setup tests the full Nginx configuration before reloading.
- The JWSM Nginx listener is loopback-only. Tailscale Funnel is the intended public entry point.
- `jib stop` disables Funnel's HTTPS service on port 443. If you use Funnel for another service on this machine, check its configuration first.
- The setup script writes a simple Nginx server block. It does not configure PHP, reverse proxies, TLS certificates outside Tailscale, firewalls, DNS, or application runtimes.
- The current version supports static website hosting. Treat directory listing as public disclosure: only place files in `/public/` that you intend to publish.
- The installer downloads scripts over HTTPS but does not yet verify signed releases or checksums. For production distribution, add release checksums/signatures and pin downloads to tagged releases.
- Always inspect scripts before executing them. Tailscale installation should be performed using the official instructions at https://tailscale.com/download/linux.
