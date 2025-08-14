#!/usr/bin/env bash
# 更新 pacman/paru 包清单 + 快照 pacman 配置
# 生成：
#   pkglists/pacman-explicit.txt
#   pkglists/aur.txt
#   pacman/pacman.conf
#   pacman/mirrorlist
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${DOTFILES_PKGDIR:-$SCRIPT_DIR/pkglists}"
PACMAN_DIR="${DOTFILES_PACMANDIR:-$SCRIPT_DIR/pacman}"

mkdir -p "$OUT_DIR" "$PACMAN_DIR"

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

# 备份 pacman 配置
SRC_PACMAN_CONF="/etc/pacman.conf"
SRC_MIRRORLIST="/etc/pacman.d/mirrorlist"

if [[ -r "$SRC_PACMAN_CONF" ]]; then
  cp -f "$SRC_PACMAN_CONF" "$PACMAN_DIR/pacman.conf"
fi
if [[ -r "$SRC_MIRRORLIST" ]]; then
  cp -f "$SRC_MIRRORLIST" "$PACMAN_DIR/mirrorlist"
fi

echo "✔ 已更新："
echo "  - $PACMAN_FILE"
echo "  - $AUR_FILE"
echo "  - $PACMAN_DIR/pacman.conf"
echo "  - $PACMAN_DIR/mirrorlist"
