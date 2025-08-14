#!/usr/bin/env bash
# 从 pkglists 清单恢复 pacman/paru 包（只装缺的，不升级已装）
# 恢复顺序：
#   1) 覆盖 /etc/pacman.conf 与 /etc/pacman.d/mirrorlist（若仓库提供）
#   2) pacman -Sy；如配置了 [archlinuxcn]，先装 archlinuxcn-keyring
#   3) 安装 paru（优先仓库，其次 AUR 回退）
#   4) 只安装缺失的官方包 & AUR 包
# 用法：
#   bash restore_packages.sh
#   bash restore_packages.sh --dry-run
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIST_DIR="${DOTFILES_PKGDIR:-$SCRIPT_DIR/pkglists}"
CONF_DIR="${DOTFILES_PACMANDIR:-$SCRIPT_DIR/pacman}"

PACMAN_FILE="$LIST_DIR/pacman-explicit.txt"
AUR_FILE="$LIST_DIR/aur.txt"

clean_list() {
  sed -e 's/#.*$//' -e 's/^[[:space:]]\+//' -e '/^[[:space:]]*$/d' "$1"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

apply_pacman_configs() {
  local src_conf="$CONF_DIR/pacman.conf"
  local src_mirror="$CONF_DIR/mirrorlist"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"

  if [[ -f "$src_conf" ]]; then
    echo "→ 应用 pacman.conf"
    sudo install -m 644 -o root -g root "$src_conf" /etc/pacman.conf
  fi
  if [[ -f "$src_mirror" ]]; then
    echo "→ 应用 mirrorlist"
    sudo install -m 644 -o root -g root "$src_mirror" /etc/pacman.d/mirrorlist
  fi
}

install_paru_if_missing() {
  if has_cmd paru; then
    return 0
  fi
  echo "ℹ 未检测到 paru，优先尝试通过仓库安装"
  sudo pacman -Sy

  # 如配置了 archlinuxcn，先装 keyring 以避免签名错误
  if grep -qs '^\s*\[archlinuxcn\]' /etc/pacman.conf; then
    sudo pacman -S --needed --noconfirm archlinuxcn-keyring || true
  fi

  if pacman -Si paru >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm paru && return 0
  fi

  echo "↻ 仓库无 paru，回退到 AUR 构建"
  sudo pacman -S --needed --noconfirm base-devel git
  tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
  git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
  (cd "$tmpdir/paru" && makepkg -si --noconfirm)
}

install_from_pacman_list() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "⚠ 未找到 $f，跳过 pacman 官方包恢复"; return 0
  fi
  echo "→ 同步 pacman 包"
  mapfile -t pkgs < <(clean_list "$f")
  local missing=()
  for p in "${pkgs[@]}"; do
    [[ -z "$p" ]] && continue
    if pacman -Qi "$p" >/dev/null 2>&1; then
      echo "  ✓ 已安装，跳过：$p"
    else
      missing+=("$p")
    fi
  done
  if ((${#missing[@]}==0)); then
    echo "  ✓ 官方仓库：没有缺失的包"; return 0
  fi
  if (( DRY_RUN )); then
    echo "  将安装（官方仓库）："; printf '    %s\n' "${missing[@]}"
  else
    sudo pacman -S --needed -- "${missing[@]}"
  fi
}

install_from_aur_list() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "ℹ 未找到 $f，如无 AUR 需求可忽略"; return 0
  fi
  install_paru_if_missing
  echo "→ 同步 AUR 包"
  mapfile -t pkgs < <(clean_list "$f")
  local missing=()
  for p in "${pkgs[@]}"; do
    [[ -z "$p" ]] && continue
    if pacman -Qi "$p" >/dev/null 2>&1; then
      echo "  ✓ 已安装，跳过：$p"
    else
      missing+=("$p")
    fi
  done
  if ((${#missing[@]}==0)); then
    echo "  ✓ AUR：没有缺失的包"; return 0
  fi
  if (( DRY_RUN )); then
    echo "  将安装（AUR）："; printf '    %s\n' "${missing[@]}"
  else
    paru -S --needed -- "${missing[@]}"
  fi
}

# 主流程
echo "==> 使用清单目录：$LIST_DIR"
echo "==> 尝试应用仓库 pacman 配置：$CONF_DIR"
apply_pacman_configs
echo "==> 尝试获取paru"
install_paru_if_missing
echo "==> 开始按清单恢复包"
install_from_pacman_list "$PACMAN_FILE"
install_from_aur_list "$AUR_FILE"
echo "✔ 完成"
