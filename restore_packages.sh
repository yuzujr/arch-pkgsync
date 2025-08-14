#!/usr/bin/env bash
# 从 pkglists 清单恢复 pacman/paru 包（只装缺的，不升级已装）
# 用法：
#   bash restore_packages.sh            # 正常恢复（不升级已装）
#   bash restore_packages.sh --dry-run  # 仅预览将要安装的包
set -euo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIST_DIR="${DOTFILES_PKGDIR:-$SCRIPT_DIR/pkglists}"

PACMAN_FILE="$LIST_DIR/pacman-explicit.txt"
AUR_FILE="$LIST_DIR/aur.txt"

clean_list() {
  # 过滤空行与注释行
  sed -e 's/#.*$//' -e 's/^[[:space:]]\+//' -e '/^[[:space:]]*$/d' "$1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

install_paru_if_missing() {
  if ! need_cmd paru; then
    echo "ℹ 未检测到 paru，开始安装（需要 base-devel & git）"
    sudo pacman -Sy --needed --noconfirm base-devel git
    tmpdir="$(mktemp -d)"
    trap 'rm -rf "$tmpdir"' EXIT
    git clone https://aur.archlinux.org/paru.git "$tmpdir/paru"
    (cd "$tmpdir/paru" && makepkg -si --noconfirm)
  fi
}

install_from_pacman_list() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "⚠ 未找到 $f，跳过 pacman 官方包恢复"
    return 0
  fi

  echo "→ 同步 pacman 包（官方仓库，仅安装缺失项）"
  mapfile -t pkgs < <(clean_list "$f")
  # 仅挑出“本机未安装”的包
  missing=()
  for p in "${pkgs[@]}"; do
    [[ -z "$p" ]] && continue
    if pacman -Qi "$p" >/dev/null 2>&1; then
      echo "  ✓ 已安装，跳过：$p"
    else
      missing+=("$p")
    fi
  done

  if ((${#missing[@]}==0)); then
    echo "  ✓ 官方仓库：没有缺失的包"
    return 0
  fi

  if (( DRY_RUN )); then
    echo "  将安装（官方仓库）："
    printf '    %s\n' "${missing[@]}"
  else
    # 不加 -u：不主动升级已装包；仅安装缺失项及其必要依赖
    sudo pacman -S --needed -- "${missing[@]}"
  fi
}

install_from_aur_list() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    echo "ℹ 未找到 $f，如无 AUR 需求可忽略"
    return 0
  fi

  install_paru_if_missing
  echo "→ 同步 AUR 包（仅安装缺失项）"
  mapfile -t pkgs < <(clean_list "$f")
  missing=()
  for p in "${pkgs[@]}"; do
    [[ -z "$p" ]] && continue
    if pacman -Qi "$p" >/dev/null 2>&1; then
      echo "  ✓ 已安装，跳过：$p"
    else
      missing+=("$p")
    fi
  done

  if ((${#missing[@]}==0)); then
    echo "  ✓ AUR：没有缺失的包"
    return 0
  fi

  if (( DRY_RUN )); then
    echo "  将安装（AUR）："
    printf '    %s\n' "${missing[@]}"
  else
    # 不加 -u：不主动升级已装包；paru 会为缺失包解决依赖
    paru -S --needed -- "${missing[@]}"
  fi
}

# 主流程
echo "==> 使用清单目录：$LIST_DIR"
install_from_pacman_list "$PACMAN_FILE"
install_from_aur_list "$AUR_FILE"
echo "✔ 完成"
