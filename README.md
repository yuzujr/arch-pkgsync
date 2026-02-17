# arch-pkgsync
用于导出和恢复 Arch Linux 软件包清单（`pacman` + `AUR/yay`）。
`pkglists` 下是我的CachyOS系统的包清单，自用。

## 功能
- 导出官方仓库显式安装包到 `pkglists/pacman-explicit.txt`
- 导出外来包（通常是 AUR）到 `pkglists/aur.txt`
- 按清单恢复时仅安装缺失包，不升级已安装包

## 目录结构
```text
.
├── update_pkglist.sh
├── restore_packages.sh
└── pkglists/
    ├── pacman-explicit.txt
    └── aur.txt
```

## 用法
1. 更新包清单

```bash
bash update_pkglist.sh
```

2. 先试跑恢复（不实际安装）

```bash
bash restore_packages.sh --dry-run
```

3. 执行恢复

```bash
bash restore_packages.sh
```

## 环境变量
- `PKGDIR`
  - 自定义清单目录（默认：`./pkglists`）
  - `update_pkglist.sh` 和 `restore_packages.sh` 都会读取该变量
