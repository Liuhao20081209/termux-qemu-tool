markdown
  
# Termux QEMU VM Manager 图形化虚拟机管理脚本

## 一、项目概述
### 1. 脚本简介
`termux-qemu-tool.sh` 是一套完全基于 `bash + dialog` 开发的终端图形化 QEMU 虚拟机一键管理工具，专门适配 Android 手机 Termux ARM64 原生环境。
- 无需手动记忆、拼接超长复杂的 QEMU 启动参数；
- 同时支持 **aarch64(ARM64)**、**x86_64(AMD64)** 两种架构虚拟机；
- 非 Root 权限完整可用，仅网桥 tap 网络需要 Root；
- 集成磁盘管理、UEFI 固件、VNC 远程桌面、端口转发、快照、日志、权限修复、文件迁移全套功能；
- 内置环境自检、依赖自动安装、固件完整性校验、异常弹窗报错提示。

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
 
 
2. 各依赖包作用说明
 
依赖包 作用 
 dialog  终端图形界面核心组件，负责绘制所有菜单、弹窗、输入框 
 qemu-system-aarch64-headless  ARM64 架构 QEMU 主程序，用于运行原生 ARM64 虚拟机 
 qemu-system-x86_64-headless  x86_64 架构 QEMU 主程序，用于运行 PC 虚拟机 
 qemu-utils  提供 qemu-img 工具，用于创建、校验、快照、格式转换磁盘 
 termux-api （可选） 用于部分扩展功能，如震动提示、通知、剪贴板 
 openssh （可选） 提供 ssh 客户端，用于连接虚拟机转发端口 
 
3. UEFI 固件说明
 
脚本使用的固件默认来自 Termux QEMU 包，路径如下：
 
架构 CODE 固件 VARS 固件 
aarch64  $PREFIX/share/qemu/edk2-aarch64-code.fd  由用户自行生成 
x86_64  $PREFIX/share/qemu/edk2-x86_64-code.fd   $PREFIX/share/qemu/edk2-x86_64-vars.fd  
 
用户也可以在主菜单手动指定自定义 OVMF 固件路径。
 
 
 
三、虚拟机启动参数说明
 
1. 全局参数
 
参数 说明 
架构 选择 aarch64 或 x86_64 
主板 pc（i440fx）或 q35（UEFI） 
CPU 型号 max / cortex-a76 / qemu64 
核心数 1 / 2 / 3 / 4 
内存 1024 / 1536 / 2048 / 3072 MB 
显卡 ramfb / virtio-gpu-pci / cirrus-vga 
声卡 none / ac97 
附加磁盘数量 动态显示当前已挂载的附加磁盘数 
 
2. 主板对照说明
 
主板 特性 推荐用途 
pc（i440fx） 传统 BIOS，无 OVMF 限制 安装新系统首选 
q35 UEFI 主板，需要 OVMF 固件 启动已装好 UEFI 的系统 
 
3. 显卡对照说明
 
显卡 兼容性 性能 
ramfb 极高 一般 
virtio-gpu-pci 高 好 
cirrus-vga 仅 pc 主板可用 一般 
 
4. 声卡对照说明
 
声卡 说明 
none 无声音，Termux 环境下推荐 
ac97 兼容声卡，需要音频后端支持 
 
5. 网络参数说明
 
参数 说明 
user NAT 模式，无需 root，适合日常使用 
tap 桥接模式，需要 root 
DNS1 / DNS2 自定义主备 DNS 
SSH 端口 主机转发端口到虚拟机的 22 端口 
 
6. VNC 参数说明
 
参数 说明 
监听地址 127.0.0.1 或 0.0.0.0 
显示编号 0 到 9，对应端口 5900 + 编号 
密码 最长 8 位，留空表示无密码 
 
 
 
四、磁盘与镜像管理
 
1. 磁盘格式支持
 
格式 说明 
qcow2 主推格式，支持快照、压缩、加密 
raw / img / bin 直接使用，性能好但无快照 
 
2. 磁盘操作
 
操作 说明 
选择主磁盘 从文件选择器中选择任意磁盘文件 
新建 qcow2 可选容量 10G / 20G / 30G / 40G / 50G / 60G / 80G / 100G 
附加多磁盘 可挂载多个额外磁盘镜像 
校验磁盘 使用 qemu-img check 检查磁盘完整性 
 
3. 磁盘保存路径建议
 
路径 优点 缺点 
 /storage/emulated/0/  可与其他 App 互通，卸载 Termux 数据不丢失 读写较慢 
 $HOME/qemu/  读写快，性能好 卸载 Termux 会清空私有目录 
 
脚本会在主菜单中弹出性能提示，提醒用户磁盘保存位置。
 
 
 
五、快照管理说明
 
仅支持 qcow2 主磁盘。
 
操作 对应命令 
创建快照  qemu-img snapshot -c 快照名 磁盘  
恢复快照  qemu-img snapshot -a 快照名 磁盘  
删除快照  qemu-img snapshot -d 快照名 磁盘  
列出快照  qemu-img snapshot -l 磁盘  
 
快照要求磁盘未被 QEMU 进程占用，否则会失败。
 
 
 
六、配置保存与读取
 
1. 保存配置
 
- 保存路径： $HOME/vm_profiles/<配置名>.conf 
- 保存字段：架构、主板、CPU、核心、内存、显卡、声卡、磁盘、附加磁盘、ISO、UEFI 固件、VNC、网络、DNS、SSH 端口、自定义参数
 
2. 读取配置
 
- 从  $HOME/vm_profiles  目录读取所有  .conf  文件
- 选择一个配置文件后直接覆盖当前内存中的参数
 
3. 多虚拟机切换
可以为每个虚拟机保存一个配置文件，使用时通过读取配置一键切换。
 
 
 
七、自定义 QEMU 参数
 
1. 入口：主菜单选择 ARG，进入“自定义 QEMU 追加参数”。
2. 使用方式：输入的内容会以空格拆分为参数数组，追加到 QEMU 命令末尾。
 
示例：
 
text
  
-device usb-host,vendorid=0x1234,productid=0x5678
 
 
或
 
text
  
-cpu host -smp 4 -m 4096
 
 
3. 注意事项
 
- 参数格式必须符合 QEMU 官方规范
- 错误参数会导致启动失败
- 建议仅在熟悉 QEMU 参数时使用
 
 
 
八、在线更新与版本管理
 
远程版本文件地址
 
text
  
https://raw.githubusercontent.com/Liuhao20081209/termux-qemu-tool/main/version
 
 
哈希校验文件地址
 
text
  
https://raw.githubusercontent.com/Liuhao20081209/termux-qemu-tool/main/sha256sum.txt
 
 
脚本下载地址
 
text
  
https://raw.githubusercontent.com/Liuhao20081209/termux-qemu-tool/main/termux-qemu-tool.sh
 
 
更新流程
 
1. 读取远程 version 与本地版本比较
2. 远程更高则询问是否下载
3. 下载前备份当前脚本为  .bak.<版本号> 
4. 下载 sha256sum.txt 与新脚本
5. 校验哈希，若不一致则拒绝更新
6. 替换脚本并提示是否立即重启
 
更新失败处理
 
情况 处理 
无法连接服务器 提示跳过更新，继续使用当前版本 
远程版本格式异常 提示跳过更新 
哈希校验失败 拒绝更新，保留旧版本 
下载得到空文件 拒绝更新 
 
 
 
九、日志与错误排查
 
1. 日志位置
 
日志 路径 
全局日志  $HOME/qemu-run.log  
虚拟机日志 与磁盘同目录，文件名与磁盘同名，扩展名  .sys_log  
 
2. 查看日志
 
主菜单选择 R，进入日志查看界面。
 
3. 错误码速查表
 
错误码 含义 
 EXIT_OK=0  正常退出 
 EXIT_USER_CANCEL=1  用户取消 
 EXIT_MISS_DEPEND=2  依赖缺失 
 EXIT_FILE_MISS=3  文件缺失 
 EXIT_FILE_CORRUPT=4  文件损坏 
 EXIT_QEMU_FAIL=5  QEMU 启动失败 
 EXIT_INVALID_PARAM=6  参数非法 
 
 
 
十、常见问题 FAQ
 
1. 启动时提示依赖缺失
选择菜单中的自动修复，脚本会执行：
 
bash
  
pkg update && pkg install dialog qemu-system-aarch64-headless qemu-system-x86_64-headless qemu-utils -y
 
 
2. QEMU 启动就退出
 
- 检查磁盘路径是否正确
- 检查 UEFI 固件是否存在
- 查看日志定位参数错误
 
3. VNC 无法连接
 
- 确认监听地址与显示编号正确
- 若使用 0.0.0.0，需要保证网络可达
- 若设置了密码，连接时需要输入
 
4. 快照创建失败
 
- 确认主磁盘是 qcow2 格式
- 确认磁盘没有被 QEMU 进程占用
 
5. x86_64 虚拟机运行缓慢
 
- x86_64 属于软件模拟，性能受限于设备 CPU
- 可降低内存或核心数
- 优先使用 aarch64 原生架构
 
6. 磁盘放在内部存储后读写很慢
 
- 建议移动到  $HOME/qemu/ 
- 脚本会提示这一点
- 注意卸载 Termux 会清空私有目录
 
7. 提示固件损坏
 
bash
  
pkg reinstall qemu-system-aarch64-headless
pkg reinstall qemu-system-x86_64-headless
 
 
8. VNC 密码最多几位
最长 8 位，超过会提示重新输入。
 
 
 
十一、已知限制
 
- tap 网络模式需要 root
- 声卡在 Termux 环境下基本不可用
- 快照仅支持 qcow2
- VNC 密码最长 8 位
- x86_64 为软件模拟，性能有限
- 脚本本身不包含 QEMU 二进制，必须通过 Termux 软件包提供
- 多磁盘数量越多，内存与 CPU 占用越大
 
 
 
十二、安全建议
 
- 不要从非官方来源下载脚本与固件
- 更新时会校验 SHA‑256，请保持开启
- 不要把 VNC 监听设为 0.0.0.0 而不设密码
- 不要把重要数据放在 Termux 私有目录
- 公共网络下不要使用 tap 网络模式
 
 
 
十三、免责声明
 
本项目仅供学习与个人使用。使用虚拟机运行任何系统时，请遵守当地法律法规与软件许可协议。作者不对因使用本工具导致的任何数据丢失、设备损坏或法律问题负责。
 
 
 
十四、项目地址
 
text
  
https://github.com/Liuhao20081209/termux-qemu-tool
 
 
plaintext
  

直接复制整块代码框全部内容，保存为 `README.md` 上传到GitHub仓库即可。