#!/usr/bin/env bash
# 更新 pacman/paru 包清单
# 生成：
#   pkglists/pacman-explicit.txt  —— 手动安装的官方仓库包（不含 AUR）
#   pkglists/aur.txt              —— AUR/“外来”包（由 paru/手工安装的）
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${DOTFILES_PKGDIR:-$SCRIPT_DIR/pkglists}"
mkdir -p "$OUT_DIR"

timestamp="$(date +%Y%m%d-%H%M%S)"
PACMAN_FILE="$OUT_DIR/pacman-explicit.txt"
AUR_FILE="$OUT_DIR/aur.txt"

# 备份旧清单
[[ -f "$PACMAN_FILE" ]] && cp -f "$PACMAN_FILE" "$PACMAN_FILE.bak.$timestamp"
[[ -f "$AUR_FILE" ]] && cp -f "$AUR_FILE" "$AUR_FILE.bak.$timestamp"

# 导出（去重 & 排序，便于审阅 diff）
# pacman -Qqen 仅导出“显式安装”的本地（非外来）包
pacman -Qqen | sort -u > "$PACMAN_FILE"

# pacman -Qqem 导出“外来包”（一般即 AUR 包）
pacman -Qqem | sort -u > "$AUR_FILE"

# 在文件头加上生成信息（注释行，不影响恢复脚本）
{
  sed -i "1i# generated: $(date -Iseconds) on host: $(hostname)" "$PACMAN_FILE"
  sed -i "1i# generated: $(date -Iseconds) on host: $(hostname)" "$AUR_FILE"
} || true

echo "✔ 已更新："
echo "  - $PACMAN_FILE"
echo "  - $AUR_FILE"
