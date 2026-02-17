#!/usr/bin/env bash
# 从 pkglists 清单恢复 pacman/yay 包（只装缺的，不升级已装）
# 恢复顺序：
#   1) 只安装缺失的官方包
#   2) 只安装缺失的 AUR 包（需要时再安装 yay）
# 用法：
#   bash restore_packages.sh
#   bash restore_packages.sh --dry-run
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIST_DIR="${PKGDIR:-$SCRIPT_DIR/pkglists}"

PACMAN_FILE="$LIST_DIR/pacman-explicit.txt"
AUR_FILE="$LIST_DIR/aur.txt"
declare -A INSTALLED_SET=()

clean_list() {
  sed -e 's/#.*$//' -e 's/^[[:space:]]\+//' -e '/^[[:space:]]*$/d' "$1"
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

refresh_installed_set() {
  local p
  INSTALLED_SET=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && INSTALLED_SET["$p"]=1
  done < <(pacman -Qq)
}

is_installed() {
  local pkg="$1"
  [[ -n "${INSTALLED_SET[$pkg]:-}" ]]
}

install_yay_if_missing() {
  if has_cmd yay; then
    return 0
  fi
  echo "ℹ 未检测到 yay，优先尝试通过仓库安装"
  sudo pacman -Sy

  if pacman -Si yay >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm yay && return 0
  fi

  echo "↻ 仓库无 yay，回退到 AUR 构建"
  sudo pacman -S --needed --noconfirm base-devel git
  tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
  git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (cd "$tmpdir/yay" && makepkg -si --noconfirm)
}

install_from_pacman_list() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "⚠ 未找到 $f，跳过 pacman 官方包恢复"; return 0
  fi
  echo "→ 同步 pacman 包"
  refresh_installed_set
  mapfile -t pkgs < <(clean_list "$f")
  local missing=()
  local total=0
  local installed=0
  for p in "${pkgs[@]}"; do
    [[ -z "$p" ]] && continue
    ((++total))
    if is_installed "$p"; then
      ((++installed))
    else
      missing+=("$p")
    fi
  done
  echo "  ℹ 清单共 ${total} 个，已安装 ${installed} 个，缺失 ${#missing[@]} 个"
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
  echo "→ 同步 AUR 包"
  refresh_installed_set
  mapfile -t pkgs < <(clean_list "$f")
  local missing=()
  local total=0
  local installed=0
  for p in "${pkgs[@]}"; do
    [[ -z "$p" ]] && continue
    ((++total))
    if is_installed "$p"; then
      ((++installed))
    else
      missing+=("$p")
    fi
  done
  echo "  ℹ 清单共 ${total} 个，已安装 ${installed} 个，缺失 ${#missing[@]} 个"
  if ((${#missing[@]}==0)); then
    echo "  ✓ AUR：没有缺失的包"; return 0
  fi
  if (( DRY_RUN )); then
    echo "  将安装（AUR）："; printf '    %s\n' "${missing[@]}"
  else
    install_yay_if_missing
    yay -S --needed -- "${missing[@]}"
  fi
}

# 主流程
echo "==> 使用清单目录：$LIST_DIR"
echo "==> 开始按清单恢复包"
install_from_pacman_list "$PACMAN_FILE"
install_from_aur_list "$AUR_FILE"
echo "✔ 完成"
