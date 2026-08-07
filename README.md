# Termux-QEMU-VM-Manager
一款基于 dialog 图形弹窗的 Termux QEMU 虚拟机一键管理脚本，纯 Bash 编写，**无需 Root**。
支持 ARM64 / x86_64 双架构虚拟机，可视化配置磁盘、镜像、内存、CPU、VNC、网络；自动校验依赖、固件完整性，一键保存/加载多套虚拟机配置，内置磁盘校验、**虚拟机独立日志**、进程清理等实用功能

## 核心特性
### 架构支持
1. aarch64(ARM64)
- 原生 virt,gic-version=3 主板，virtio-gpu-pci 高性能显卡
- 系统自带 edk2-aarch64 UEFI 固件，支持自定义 vars.fd
- 一键生成 64M 空白 UEFI vars.fd，自动跟随磁盘/ISO 同名同目录
- CPU 可选 max(自动最优) / cortex-a76 ARM 专用型号

2. x86_64(AMD64)
- 双主板自由切换：pc(i440fx Legacy BIOS，安装系统首选) / q35(UEFI OVMF)
- pc 主板强制 cirrus-vga 兼容显卡，杜绝黑屏；q35 使用 virtio-vga
- q35 主板依赖 OVMF_CODE + OVMF_VARS，支持自定义外置固件文件
- CPU 默认 qemu64

### Dialog 全图形可视化操作
1. 文件选择器：选取 qcow2 磁盘 / ISO 镜像 / ARM64 vars.fd / x86 OVMF 固件
2. 一键新建 qcow2 磁盘：可选 10G/20G/30G/40G/50G/60G/80G/100G
3. UEFI vars 生成工具，自动和当前磁盘/镜像同目录同名
4. 硬件可视化配置：CPU型号、内存(1024M~3072M)、CPU核心(1~4核)、虚拟显卡
5. VNC 全套设置：监听地址(127.0.0.1 / 0.0.0.0)、显示编号0-9、最长8位访问密码
6. 网络配置：user NAT(无Root可用) / tap桥接(需要Root)、自定义双DNS、SSH端口转发
7. 配置持久化：多套虚拟机硬件参数完整保存/加载
8. qcow2 磁盘完整性校验、实时查看虚拟机专属运行日志

### 自动化检测与容错机制
1. 程序启动自动 POST 环境自检
   - 检测 dialog、qemu-system-aarch64、qemu-system-x86_64 二进制
   - 测试 QEMU 程序可用性，校验系统内置 ARM/x86 UEFI 固件存在性
   - 缺失依赖/损坏组件自动执行 pkg 更新重装修复
2. ARM64 UEFI 固件大小校验，识别损坏固件并给出修复指令
3. 启动虚拟机前检测后台残留 QEMU 进程，可一键全部杀死，避免磁盘占用锁
4. 全局错误捕获 trap，程序崩溃自动记录报错行号+错误码写入全局日志
5. 路径智能检测：磁盘/ISO 存放在 /storage/emulated/0 时自动弹出性能提示弹窗
6. 弹窗配色极简：仅红色加粗标题用于警示，其余文字默认黑白，视觉清爽

### 性能与备份提示弹窗逻辑
- 只要选中的虚拟磁盘或 ISO 在内部共享存储，每次进入主菜单自动弹出提示框
- 建议迁移至 $HOME 私有目录大幅提升读写速度
- 重要风险提醒：卸载 Termux 会清空 $HOME 全部文件，虚拟机文件提前备份至 /storage/emulated/0/VM_Backup/

## 环境依赖
脚本内置自动修复，首次运行缺失组件会自动安装；手动安装命令：
```bash
pkg update && pkg install dialog qemu-system-aarch64 qemu-system-x86_64-headless -y
