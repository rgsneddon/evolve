#!/usr/bin/env bash
# Install Grok Build CLI + Evolve laptop toolchain on Ubuntu/Debian or Arch.
# Safe to re-run. Does not touch Windows disks.
set -euo pipefail

log() { printf '%s %s\n' "$(date -Iseconds)" "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

detect_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf '%s\n' "${ID:-unknown}"
  else
    printf 'unknown\n'
  fi
}

install_base_ubuntu() {
  sudo apt-get update
  sudo apt-get install -y \
    curl ca-certificates git unzip xz-utils \
    build-essential clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libstdc++-12-dev \
    openssh-client
}

install_base_arch() {
  sudo pacman -Syu --needed --noconfirm \
    curl ca-certificates git unzip xz \
    base-devel clang cmake ninja pkgconf \
    gtk3 openssh
}

install_grok() {
  if need_cmd grok; then
    log "grok already on PATH: $(command -v grok)"
    grok --version || true
    return 0
  fi
  log "installing Grok Build CLI"
  curl -fsSL https://x.ai/cli/install.sh | bash
  export PATH="${HOME}/.grok/bin:${PATH}"
  if ! need_cmd grok; then
    if [[ -x "${HOME}/.grok/bin/grok" ]]; then
      # login shells pick this up next time
      if ! grep -q '\.grok/bin' "${HOME}/.bashrc" 2>/dev/null; then
        printf '\nexport PATH="$HOME/.grok/bin:$PATH"\n' >> "${HOME}/.bashrc"
      fi
      if [[ -f "${HOME}/.zshrc" ]] && ! grep -q '\.grok/bin' "${HOME}/.zshrc"; then
        printf '\nexport PATH="$HOME/.grok/bin:$PATH"\n' >> "${HOME}/.zshrc"
      fi
    fi
  fi
  hash -r || true
  if [[ -x "${HOME}/.grok/bin/grok" ]]; then
    "${HOME}/.grok/bin/grok" --version || true
  else
    grok --version
  fi
}

print_next() {
  cat <<'EOF'

Grok is ready on this Linux box.

  export PATH="$HOME/.grok/bin:$PATH"
  grok          # first run opens the browser / device login
  grok login    # if you need to sign in again

Evolve 4.1.12 laptop work (same tag as Windows/Mac):

  git clone https://github.com/rgsneddon/evolve.git
  cd evolve
  grok          # then: build Linux/Arch packages onto v4.1.12

Do not create v4.1.12-linux. Attach to the existing tag:
  pwsh ./scripts/upload_release_assets.ps1 -Version 4.1.12
  # or gh release upload v4.1.12 --repo rgsneddon/evolve --clobber <files>

Windows disk (this PC) is usually visible after you mount NTFS, e.g.:
  lsblk
  sudo mkdir -p /mnt/windows
  sudo mount -t ntfs3 /dev/nvme0n1p3 /mnt/windows   # check lsblk first
  # guide copy: /mnt/windows/Users/rgsne/Desktop/linux-usb-guide/

EOF
}

main() {
  if [[ "$(id -u)" -eq 0 ]]; then
    echo "run as your user, not root (script will sudo)" >&2
    exit 1
  fi
  local id
  id="$(detect_os)"
  log "os=$id"
  case "$id" in
    ubuntu|debian|linuxmint|pop)
      install_base_ubuntu
      ;;
    arch|endeavouros|manjaro|garuda)
      install_base_arch
      ;;
    *)
      echo "unknown distro '$id' — install curl git, then: curl -fsSL https://x.ai/cli/install.sh | bash" >&2
      ;;
  esac
  install_grok
  print_next
}

main "$@"
