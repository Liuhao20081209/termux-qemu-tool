# Termux QEMU VM Manager 图形化虚拟机管理脚本
## 一、项目概述
### 1. 脚本简介
`termux-qemu-tool.sh` 是一套完全基于 `bash + dialog` 开发的终端图形化 QEMU 虚拟机一键管理工具，专门适配 Android 手机 Termux ARM64 原生环境。
- 无需手动记忆、拼接超长复杂的 QEMU 启动参数；
- 同时支持 **aarch64(ARM64)**、**x86_64(AMD64)** 两种架构虚拟机；
- 非 Root 权限完整可用，仅网桥 tap 网络需要 Root；
- 集成磁盘管理、UEFI 固件、VNC 远程桌面、端口转发、快照、日志、权限修复、文件迁移全套功能；
- 内置环境自检、依赖自动安装、固件完整性校验、异常弹窗报错提示

### 2. 文件目录自动创建
脚本首次运行会自动生成以下工作目录，无需手动新建：
| 目录路径 | 用途说明 |
|--------|--------|
| `$HOME/vm_profiles` | 虚拟机配置文件存放目录，保存所有自定义硬件参数 `.conf` |
| `$HOME/qemu` | 虚拟机私有文件目录，推荐存放 qcow2 磁盘、UEFI vars.fd 固件 |
| `$HOME/qemu-run.log` | 全局总运行日志 |
| `/tmp/qemu-monitor.sock` | QEMU 调试监控通道套接字 |
| `/tmp/snap.tmp` | 快照临时缓存文件 |

### 3. 错误码定义（脚本内置）
| 错误码 | 含义 | 一键修复命令 |
|--------|------|------------|
| `EXIT_OK=0` | 程序正常退出 | - |
| `EXIT_USER_CANCEL=1` | 用户手动取消操作 | - |
| `EXIT_MISS_DEPEND=2` | 缺少运行依赖包 | `pkg update && pkg install dialog qemu-system-aarch64-headless qemu-system-x86_64-headless qemu-utils -y` |
| `EXIT_FILE_MISS=3` | 关键文件缺失（固件/镜像/磁盘） | 检查文件路径，重装对应 qemu 包 |
| `EXIT_FILE_CORRUPT=4` | UEFI固件损坏 / qcow2磁盘损坏 | `qemu-img check -r all 磁盘路径` 或 `pkg reinstall qemu-system-xxx-headless` |
| `EXIT_QEMU_FAIL=5` | QEMU 进程启动失败 | 查看运行日志排查参数、文件权限 |
| `EXIT_INVALID_PARAM=6` | 硬件参数非法（内存/端口/显卡不兼容） | 在菜单重新调整硬件配置 |

---

## 二、完整依赖说明 & 一键安装命令
### 1. 全部依赖包安装指令
脚本启动自检时如果检测到缺失工具，会弹窗提示执行下面这条完整安装命令：
```bash
pkg update && pkg install dialog qemu-system-aarch64-headless qemu-system-x86_64-headless qemu-utils -y
