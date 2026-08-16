#!/data/data/com.termux/files/usr/bin/bash
EXIT_OK=0
EXIT_USER_CANCEL=1
EXIT_MISS_DEPEND=2
EXIT_FILE_MISS=3
EXIT_FILE_CORRUPT=4
EXIT_QEMU_FAIL=5
EXIT_INVALID_PARAM=6
STORAGE_ROOT="/storage/emulated/0"
CONF_DIR="$HOME/vm_profiles"
GLOBAL_LOG="$HOME/qemu-run.log"
mkdir -p "$CONF_DIR"
BACKTITLE="QEMU VM Manager for Termux "
UEFI_CODE="$PREFIX/share/qemu/edk2-aarch64-code.fd"
SYS_X86_OVMF_CODE="$PREFIX/share/qemu/edk2-x86_64-code.fd"
SYS_X86_OVMF_VARS="$PREFIX/share/qemu/edk2-x86_64-vars.fd"
X86_OVMF_CODE=""
X86_OVMF_VARS=""
TARGET_ARCH="x86_64"
MACHINE="pc"
CPU="qemu64"
SMP=2
MEM=2048
GPU="cirrus-vga"
HDA=""
CDROM=""
UEFI_VARS=""
VNC_LISTEN_ADDR="127.0.0.1"
VNC_DISPLAY="0"
VNC_PASSWD=""
NET_MODE="user"
DNS_MAIN="223.5.5.5"
DNS_ALT="8.8.8.8"
SSH_FORWARD_PORT="2222"
error_handler() {
    local ret=$?
    local line=$1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CRASH！行号:$line 返回码:$ret" >> "$GLOBAL_LOG"
    dialog --backtitle "$BACKTITLE" --title "运行异常" --msgbox "程序发生错误
错误代码: $ret
出错行号: $line
日志查看：$GLOBAL_LOG" 14 64
    exit $ret
}
trap 'error_handler $LINENO' ERR
msgbox(){
    dialog --backtitle "$BACKTITLE" --title "提示" --msgbox "$1" 9 58 || true
}
select_qcow2_disk(){
    local start_path="$STORAGE_ROOT"
    while true; do
        local sel
        sel=$(dialog --backtitle "$BACKTITLE" --title "选择虚拟磁盘(*.qcow2)" --fselect "$start_path" 17 66 2>&1 >/dev/tty)
        [ -z "$sel" ] && echo "" && return
        if [ -d "$sel" ]; then
            start_path="$sel"
            continue
        fi
        if [[ "$sel" == *.qcow2 ]]; then
            echo "$sel"
            return
        else
            msgbox "仅允许选择后缀为.qcow2的磁盘文件"
        fi
    done
}
select_iso_file(){
    local start_path="$STORAGE_ROOT"
    while true; do
        local sel
        sel=$(dialog --backtitle "$BACKTITLE" --title "选择镜像*.iso" --fselect "$start_path" 17 66 2>&1 >/dev/tty)
        [ -z "$sel" ] && echo "" && return
        if [ -d "$sel" ]; then
            start_path="$sel"
            continue
        fi
        if [[ "$sel" == *.iso ]]; then
            echo "$sel"
            return
        else
            msgbox "仅允许选择后缀为.iso的系统镜像"
        fi
    done
}
get_vm_log_path(){
    if [[ -n "$HDA" && -f "$HDA" ]]; then
        local disk_dir=$(dirname "$HDA")
        local disk_name=$(basename "$HDA" .qcow2)
        echo "${disk_dir}/${disk_name}.sys_log"
    else
        echo "$GLOBAL_LOG"
    fi
}
env_check_text() {
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
    clear
    echo -e "${CYAN}======================================================${RESET}"
    echo -e "${BOLD}          QEMU VIRTUAL MACHINE MANAGER POST           ${RESET}"
    echo -e "${CYAN}======================================================${RESET}"
    sleep 0.4
    local required_bin=("dialog" "qemu-system-aarch64" "qemu-system-x86_64" "qemu-img")
    local required_pkgs=("dialog" "qemu-system-aarch64-headless" "qemu-system-x86_64-headless" "qemu-utils")
    local missing=()
    local broken=()
    echo -e "${BLUE}Step 1: Detecting executables...${RESET}"
    for bin in "${required_bin[@]}"; do
        echo -n "  $bin ............................ "
        if ! command -v "$bin" &>/dev/null; then
            echo -e "[${RED}NOT FOUND${RESET}]"
            missing+=("$bin")
        else
            echo -e "[${GREEN}OK${RESET}]"
        fi
        sleep 0.15
    done
    echo ""
    echo -e "${BLUE}Step 2: Testing QEMU functionality...${RESET}"
    for bin in qemu-system-aarch64 qemu-system-x86_64; do
        if command -v "$bin" &>/dev/null; then
            echo -n "  Testing $bin --version ............. "
            if timeout 2 "$bin" --version &>/dev/null; then
                echo -e "[${GREEN}OK${RESET}]"
            else
                echo -e "[${RED}FAILED${RESET}]"
                broken+=("$bin")
            fi
        fi
        sleep 0.15
    done
    echo ""
    echo -e "${BLUE}Step 3: Checking firmware files...${RESET}"
    echo -n "  ARM64 UEFI (edk2-aarch64-code.fd) ... "
    if [[ -f "$PREFIX/share/qemu/edk2-aarch64-code.fd" ]]; then
        echo -e "[${GREEN}OK${RESET}]"
    else
        echo -e "[${YELLOW}NOT FOUND${RESET}]"
        missing+=("edk2-aarch64-code.fd")
    fi
    echo -n "  x86_64 OVMF (edk2-x86_64-code.fd) ... "
    if [[ -f "$PREFIX/share/qemu/edk2-x86_64-code.fd" ]]; then
        echo -e "[${GREEN}OK${RESET}]"
    else
        echo -e "[${YELLOW}NOT FOUND${RESET}]"
        missing+=("edk2-x86_64-code.fd")
    fi
    echo ""
    echo -e "${CYAN}======================================================${RESET}"
    if [[ ${#missing[@]} -eq 0 && ${#broken[@]} -eq 0 ]]; then
        echo -e "${GREEN}POST COMPLETE: All components ready.${RESET}"
        echo -e "${GREEN}Launching graphical interface...${RESET}"
        sleep 0.8
        return 0
    fi
    echo -e "${YELLOW} Issues detected:${RESET}"
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "  ${RED}Missing: ${missing[*]}${RESET}"
    fi
    if [[ ${#broken[@]} -gt 0 ]]; then
        echo -e "  ${RED}Broken/Corrupted: ${broken[*]}${RESET}"
    fi
    echo ""
    read -p "尝试修复这些问题? [y/n] " opt
    if [[ "$opt" != "y" && "$opt" != "Y" ]]; then
        echo -e "${RED}取消修复，程序退出${RESET}"
        exit $EXIT_MISS_DEPEND
    fi
    echo ""
    echo -e "${BLUE}Updating software repository index...${RESET}"
    pkg update >/dev/null 2>&1
    if [[ ${#missing[@]} -gt 0 || ${#broken[@]} -gt 0 ]]; then
        echo -e "${BLUE}Reinstalling QEMU packages to fix issues...${RESET}"
        pkg install "${required_pkgs[@]}" -y
    fi
    echo ""
    echo -e "${BLUE}Step 4: Verify repair results...${RESET}"
    local still_broken=()
    for bin in "${required_bin[@]}"; do
        echo -n "  $bin ............................ "
        if ! command -v "$bin" &>/dev/null; then
            echo -e "[${RED}FAILED${RESET}]"
            still_broken+=("$bin")
        else
            echo -e "[${GREEN}OK${RESET}]"
        fi
        sleep 0.15
    done
    echo -n "  ARM64 UEFI 固件 ................... "
    if [[ -f "$PREFIX/share/qemu/edk2-aarch64-code.fd" ]]; then
        echo -e "[${GREEN}OK${RESET}]"
    else
        echo -e "[${RED}FAILED${RESET}]"
        still_broken+=("edk2-aarch64-code.fd")
    fi
    echo -n "  x86_64 OVMF 固件 .................. "
    if [[ -f "$PREFIX/share/qemu/edk2-x86_64-code.fd" ]]; then
        echo -e "[${GREEN}OK${RESET}]"
    else
        echo -e "[${RED}FAILED${RESET}]"
        still_broken+=("edk2-x86_64-code.fd")
    fi
    if [[ ${#still_broken[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}[ERROR]: 仍然存在问题: ${still_broken[*]}${RESET}"
        echo -e "${YELLOW}请手动检查并修复:${RESET}"
        echo -e "${BOLD}pkg update && pkg install ${required_pkgs[*]} -y${RESET}"
        echo -e "${YELLOW}或重新安装 Termux 的 QEMU 包${RESET}"
        exit $EXIT_MISS_DEPEND
    fi
    echo ""
    echo -e "${GREEN}All issues resolved.${RESET}"
    echo -e "${GREEN}Starting manager...${RESET}"
    sleep 1
}
create_qcow2_disk(){
local CAP_SEL
CAP_SEL=$(dialog --backtitle "$BACKTITLE" --title "新建虚拟磁盘" --radiolist \
"设置虚拟磁盘最大容量 [空格键选中，回车确认]
磁盘自动创建在iso同目录且同名，无iso则手动选路径" 22 76 10 \
"10G" "10 GB" OFF \
"20G" "20 GB" ON \
"30G" "30 GB" OFF \
"40G" "40 GB" OFF \
"50G" "50 GB" OFF \
"60G" "60 GB" OFF \
"80G" "80 GB" OFF \
"100G" "100 GB" OFF \
2>&1 >/dev/tty) || true
[ -z "$CAP_SEL" ] && return
if [[ -z "$CDROM" ]]; then
    local SAVE_DIR
    SAVE_DIR=$(dialog --backtitle "$BACKTITLE" --title "选择磁盘保存目录" --fselect "$STORAGE_ROOT" 17 66 2>&1 >/dev/tty)
    [[ -z "$SAVE_DIR" ]] && return
    DISK_PATH="$SAVE_DIR/disk.qcow2"
else
    ISO_DIR=$(dirname "$CDROM")
    ISO_BN=$(basename "$CDROM" .iso)
    DISK_PATH="${ISO_DIR}/${ISO_BN}.qcow2"
fi
if [ -f "$DISK_PATH" ];then
    dialog --backtitle "$BACKTITLE" --title "文件冲突" --yesno \
"目标文件已存在，覆盖会清空所有数据，确定继续？
$DISK_PATH" 14 66 || true
    [ $? -ne 0 ] && return
fi
qemu-img create -f qcow2 "$DISK_PATH" "$CAP_SEL" >/dev/null 2>&1
HDA="$DISK_PATH"
msgbox "虚拟磁盘创建完成且已选中
路径：$DISK_PATH
最大容量上限：$CAP_SEL"
}
create_empty_vars_fd(){
local ARCH_TAG="$1"
local FD_DIR FD_BN FD_PATH
if [[ -n "$HDA" ]]; then
    FD_DIR=$(dirname "$HDA")
    FD_BN=$(basename "$HDA" .qcow2)
elif [[ -n "$CDROM" ]]; then
    FD_DIR=$(dirname "$CDROM")
    FD_BN=$(basename "$CDROM" .iso)
else
    local SAVE_DIR
    SAVE_DIR=$(dialog --backtitle "$BACKTITLE" --title "选择vars.fd保存目录" --fselect "$STORAGE_ROOT" 17 66 2>&1 >/dev/tty)
    [[ -z "$SAVE_DIR" ]] && return
    FD_DIR="$SAVE_DIR"
    FD_BN="uefi_vars_$ARCH_TAG"
fi
FD_PATH="${FD_DIR}/${FD_BN}.fd"
if [ -f "$FD_PATH" ];then
    dialog --backtitle "$BACKTITLE" --title "文件冲突" --yesno \
"目标文件已存在，覆盖会清除全部UEFI配置，确认继续？
$FD_PATH" 14 66 || true
    [ $? -ne 0 ] && return
fi
qemu-img create -f raw "$FD_PATH" 64M >/dev/null 2>&1
if [[ "$ARCH_TAG" == "aarch64" ]]; then
    UEFI_VARS="$FD_PATH"
    msgbox "ARM64 vars.fd 创建成功并自动选中
路径：$FD_PATH"
elif [[ "$ARCH_TAG" == "x86_64" ]]; then
    X86_OVMF_VARS="$FD_PATH"
    msgbox "x86 OVMF_VARS.fd 创建成功并自动选中
路径：$FD_PATH"
fi
}
check_qemu_running(){
if pgrep -f qemu-system >/dev/null 2>&1;then
    dialog --backtitle "$BACKTITLE" --title "提示" --yesno \
"检测到后台QEMU进程，继续启动易磁盘锁，强制杀掉全部QEMU进程？" 14 66 || true
    if [ $? -eq 0 ];then
        pkill -f qemu-system
        sleep 1
        msgbox "已清理全部QEMU后台进程"
    fi
fi
}
check_uefi_firmware(){
    if [[ "$TARGET_ARCH" == "aarch64" ]]; then
        if [ ! -f "$UEFI_CODE" ]; then
            msgbox "[Error] ARM64 UEFI固件缺失
修复命令：pkg reinstall qemu-system-aarch64-headless"
            return $EXIT_FILE_MISS
        fi
        local CODE_SIZE
        CODE_SIZE=$(stat -c%s "$UEFI_CODE")
        if [[ $CODE_SIZE -lt 62914560 || $CODE_SIZE -gt 73400320 ]]; then
            msgbox "[Error] ARM64 UEFI固件损坏"
            return $EXIT_FILE_CORRUPT
        fi
        if [[ -n "$UEFI_VARS" && ! -f "$UEFI_VARS" ]]; then
            msgbox "[Error] ARM64 vars.fd 文件不存在"
            return $EXIT_FILE_MISS
        fi
    fi
    if [[ "$TARGET_ARCH" == "x86_64" ]]; then
        if [[ "$MACHINE" == "pc" ]];then
            return $EXIT_OK
        fi
        local USE_X86_CODE USE_X86_VARS
        if [[ -n "$X86_OVMF_CODE" && -f "$X86_OVMF_CODE" ]]; then
            USE_X86_CODE="$X86_OVMF_CODE"
        else
            USE_X86_CODE="$SYS_X86_OVMF_CODE"
        fi
        if [[ -n "$X86_OVMF_VARS" && -f "$X86_OVMF_VARS" ]]; then
            USE_X86_VARS="$X86_OVMF_VARS"
        else
            USE_X86_VARS="$SYS_X86_OVMF_VARS"
        fi
        if [ ! -f "$USE_X86_CODE" ]; then
            msgbox "[Error] x86 OVMF_CODE缺失，重启脚本自动安装qemu-x86_64-headless包修复"
            return $EXIT_FILE_MISS
        fi
        if [ ! -f "$USE_X86_VARS" ]; then
            msgbox "[Error] x86 OVMF_VARS不存在，可按F生成空白vars文件"
            return $EXIT_FILE_MISS
        fi
    fi
    return $EXIT_OK
}
choose_arch(){
    local SEL
    SEL=$(dialog --backtitle "$BACKTITLE" --title "选择CPU架构" --radiolist \
"镜像架构必须匹配，ARM64原生推荐，x86_64支持pc/q35双主板" 14 62 3 \
"aarch64" "ARM64 原生架构 [自带UEFI固件]" OFF \
"x86_64" "AMD64 x86模拟 [支持pc/q35主板]" ON \
2>&1 >/dev/tty) || true
    [ -z "$SEL" ] && return
    TARGET_ARCH="$SEL"
    if [[ "$TARGET_ARCH" == "aarch64" ]];then
        MACHINE="virt,gic-version=3"
        GPU="virtio-gpu-pci"
        X86_OVMF_CODE=""
        X86_OVMF_VARS=""
        CPU="max"
    else
        MACHINE="pc"
        GPU="cirrus-vga"
        UEFI_VARS=""
        CPU="qemu64"
        if [[ -f "$SYS_X86_OVMF_CODE" && -f "$SYS_X86_OVMF_VARS" ]];then
            X86_OVMF_CODE="$SYS_X86_OVMF_CODE"
            X86_OVMF_VARS="$SYS_X86_OVMF_VARS"
        fi
    fi
    msgbox "架构切换完成，硬件参数自动重置适配"
}
choose_x86_machine(){
    if [[ "$TARGET_ARCH" != "x86_64" ]];then
        msgbox "仅x86_64架构支持切换主板"
        return
    fi
    local SEL
    SEL=$(dialog --backtitle "$BACKTITLE" --title "x86主板选择" --radiolist \
"pc=i440fx传统BIOS，无OVMF固件限制，适合系统安装
q35=UEFI主板，需要OVMF固件，已装好UEFI系统使用" 16 66 2 \
"pc" "i440fx Legacy BIOS [安装系统首选]" ON \
"q35" "q35 UEFI主板 [启动系统首选]" OFF \
2>&1 >/dev/tty) || true
    [ -z "$SEL" ] && return
    MACHINE="$SEL"
    if [[ "$MACHINE" == "pc" ]];then
        GPU="cirrus-vga"
    else
        GPU="virtio-vga"
    fi
    msgbox "主板切换完成，显卡自动适配"
}
choose_cpu(){
    local SEL
    SEL=$(dialog --backtitle "$BACKTITLE" --title "CPU型号" --radiolist \
"max自动适配最优，cortex-a76仅ARM可用" 14 62 3 \
"max" "max 自动适配（首选）" ON \
"cortex-a76" "cortex-a76 ARM专用" OFF \
"qemu64" "qemu64 x86专用" OFF \
2>&1 >/dev/tty) || true
    [ -z "$SEL" ] && return
    CPU="$SEL"
}
choose_memory(){
    local SEL
    SEL=$(dialog --backtitle "$BACKTITLE" --title "分配内存 MB" --radiolist \
"不得超过设备可用RAM的50%" 14 56 3 \
"1024" "1024 MB" OFF \
"1536" "1536 MB" OFF \
"2048" "2048 MB [默认]" ON \
"3072" "3072 MB" OFF \
2>&1 >/dev/tty) || true
    [ -z "$SEL" ] && return
    MEM="$SEL"
}
choose_smp(){
    local SEL
    SEL=$(dialog --backtitle "$BACKTITLE" --title "CPU核心数" --radiolist \
"核心过多会导致性能下降，1-2核最稳" 14 56 4 \
"1" "1 核" OFF \
"2" "2 核（推荐）" ON \
"3" "3 核" OFF \
"4" "4 核" OFF \
2>&1 >/dev/tty) || true
    [ -z "$SEL" ] && return
    SMP="$SEL"
}
choose_gpu(){
    local SEL
    if [[ "$TARGET_ARCH" == "x86_64" && "$MACHINE" == "pc" ]];then
        SEL=$(dialog --backtitle "$BACKTITLE" --title "显卡" --radiolist \
"pc主板仅cirrus-vga兼容，其他显卡可能导致黑屏" 14 56 1 \
"cirrus-vga" "cirrus-vga 兼容模式(强制)" ON \
2>&1 >/dev/tty) || true
    else
        SEL=$(dialog --backtitle "$BACKTITLE" --title "虚拟显卡(Graphics)" --radiolist \
"ramfb [兼容]，virtio-gpu [性能]" 14 56 2 \
"ramfb" "ramfb [兼容]" ON \
"virtio-gpu-pci" "virtio-gpu-pci [性能]" OFF \
2>&1 >/dev/tty) || true
    fi
    [ -z "$SEL" ] && return
    GPU="$SEL"
}
select_x86_ovmf_code(){
    local path
    path=$(dialog --backtitle "$BACKTITLE" --title "自定义x86 OVMF_CODE.fd" --fselect "$STORAGE_ROOT" 17 66 2>&1 >/dev/tty)
    if [[ -n "$path" ]]; then
        X86_OVMF_CODE="$path"
        MACHINE="q35"
        GPU="virtio-vga"
        msgbox "已使用自定义OVMF_CODE，自动切换q35主板"
    fi
}
select_x86_ovmf_vars(){
    local path
    path=$(dialog --backtitle "$BACKTITLE" --title "自定义x86 OVMF_VARS.fd" --fselect "$STORAGE_ROOT" 17 66 2>&1 >/dev/tty)
    [[ -n "$path" ]] && X86_OVMF_VARS="$path" && msgbox "已使用自定义OVMF_VARS覆盖系统固件"
}
vnc_setting_menu(){
while true; do
    local SEL
    SEL=$(dialog --backtitle "$BACKTITLE" --title "VNC配置" --menu \
"当前：地址=$VNC_LISTEN_ADDR 显示:$VNC_DISPLAY 密码:${VNC_PASSWD:-无}" 16 68 8 \
"1" "监听地址(127.0.0.1/0.0.0.0)" \
"2" "修改VNC端口号(0=5900)" \
"3" "设置VNC访问密码(最长8位数)" \
"0" "返回上级菜单" 2>&1 >/dev/tty) || true
    case "$SEL" in
    1)
        local TMP
        TMP=$(dialog --backtitle "$BACKTITLE" --title "设置监听地址" --inputbox "仅允许127.0.0.1 / 0.0.0.0" 9 52 "$VNC_LISTEN_ADDR" 2>&1 >/dev/tty) || true
        if [[ "$TMP" == "127.0.0.1" || "$TMP" == "0.0.0.0" ]]; then
            VNC_LISTEN_ADDR="$TMP"
            msgbox "监听地址已更新"
        else
            msgbox "地址格式错误"
        fi
    ;;
    2)
        local TMP
        TMP=$(dialog --backtitle "$BACKTITLE" --title "设置显示编号" --inputbox "0~9数字" 9 52 "$VNC_DISPLAY" 2>&1 >/dev/tty) || true
        if [[ "$TMP" =~ ^[0-9]$ ]]; then
            VNC_DISPLAY="$TMP"
            msgbox "显示编号更新为:$VNC_DISPLAY"
        else
            msgbox "仅允许0-9数字"
        fi
    ;;
    3)
        local TMP
        TMP=$(dialog --backtitle "$BACKTITLE" --title "设置VNC密码" --inputbox "最长8位，留空无密码" 9 52 "$VNC_PASSWD" 2>&1 >/dev/tty) || true
        if [[ ${#TMP} -le 8 ]]; then
            VNC_PASSWD="$TMP"
            msgbox "VNC密码已保存"
        else
            msgbox "密码不能超过8位，设置失败"
        fi
    ;;
    0) break ;;
    esac
done
}
network_setting_menu(){
while true; do
    local SEL
    SEL=$(dialog --backtitle "$BACKTITLE" --title "网络配置" --menu \
"非root仅支持user NAT模式" 18 72 10 \
"1" "切换网卡模式 user / tap" \
"2" "主DNS服务器" \
"3" "备用DNS服务器" \
"4" "修改SSH主机转发端口" \
"0" "返回上级菜单" 2>&1 >/dev/tty) || true
    case "$SEL" in
    1)
        local MODE_SEL
        MODE_SEL=$(dialog --backtitle "$BACKTITLE" --title "网卡模式" --radiolist \
"tap网络桥接模式需要Root权限" 12 60 2 \
"user" "User NAT 普通用户可用" ON \
"tap" "Tap 网桥 需要Root" OFF 2>&1 >/dev/tty) || true
        [ -z "$MODE_SEL" ] && continue
        NET_MODE="$MODE_SEL"
        msgbox "网卡模式:$NET_MODE"
    ;;
    2)
        local TMP
        TMP=$(dialog --backtitle "$BACKTITLE" --title "主DNS" --inputbox "输入DNS IP" 9 52 "$DNS_MAIN" 2>&1 >/dev/tty) || true
        [ -n "$TMP" ] && DNS_MAIN="$TMP"
        msgbox "主DNS已更新"
    ;;
    3)
        local TMP
        TMP=$(dialog --backtitle "$BACKTITLE" --title "备用DNS" --inputbox "输入DNS IP" 9 52 "$DNS_ALT" 2>&1 >/dev/tty) || true
        [ -n "$TMP" ] && DNS_ALT="$TMP"
        msgbox "备用DNS已更新"
    ;;
    4)
        local TMP
        TMP=$(dialog --backtitle "$BACKTITLE" --title "SSH转发端口" --inputbox "大于1024数字" 9 52 "$SSH_FORWARD_PORT" 2>&1 >/dev/tty) || true
        if [[ "$TMP" =~ ^[0-9]+$ && "$TMP" -gt 1024 ]]; then
            SSH_FORWARD_PORT="$TMP"
            msgbox "转发端口:$SSH_FORWARD_PORT"
        else
            msgbox "端口必须大于1024"
        fi
    ;;
    0) break ;;
    esac
done
}
save_config(){
    local NAME
    NAME=$(dialog --backtitle "$BACKTITLE" --title "保存配置文件" --inputbox "输入配置名称" 9 48 2>&1 >/dev/tty) || true
    [ -z "$NAME" ] && return
    local CONF_PATH="$CONF_DIR/$NAME.conf"
    cat > "$CONF_PATH" <<CFG
TARGET_ARCH=$TARGET_ARCH
MACHINE=$MACHINE
CPU=$CPU
SMP=$SMP
MEM=$MEM
GPU=$GPU
HDA=$HDA
CDROM=$CDROM
UEFI_VARS=$UEFI_VARS
UEFI_CODE=$UEFI_CODE
X86_OVMF_CODE=$X86_OVMF_CODE
X86_OVMF_VARS=$X86_OVMF_VARS
VNC_LISTEN_ADDR=$VNC_LISTEN_ADDR
VNC_DISPLAY=$VNC_DISPLAY
VNC_PASSWD=$VNC_PASSWD
NET_MODE=$NET_MODE
DNS_MAIN=$DNS_MAIN
DNS_ALT=$DNS_ALT
SSH_FORWARD_PORT=$SSH_FORWARD_PORT
CFG
    msgbox "配置已保存：$NAME"
}
load_config(){
    local FILES=()
    local LIST=()
    local IDX=1
    while IFS= read -r -d '' f;do
        FILES+=("$f")
        LIST+=("$IDX" "$(basename "$f" .conf)")
        IDX=$((IDX+1))
    done < <(find "$CONF_DIR" -maxdepth 1 -name "*.conf" -print0 | sort -z)
    if [[ ${#FILES[@]} -eq 0 ]];then
        msgbox "无已保存配置"
        return
    fi
    local SEL_IDX
    SEL_IDX=$(dialog --backtitle "$BACKTITLE" --title "加载配置" --menu "选择存档配置" 15 56 8 "${LIST[@]}" 2>&1 >/dev/tty) || true
    [ -z "$SEL_IDX" ] && return
    source "${FILES[$((SEL_IDX-1))]}"
    msgbox "配置已加载"
}
build_cmd(){
    CMD=()
    BOOT_ORDER=()
    if [[ "$TARGET_ARCH" == "x86_64" ]];then
        if [[ -n "$CDROM" && -f "$CDROM" ]];then
            BOOT_ORDER=("-boot" "order=dc")
        else
            BOOT_ORDER=("-boot" "order=cd")
        fi
    else
        BOOT_ORDER=()
    fi
    if [[ "$TARGET_ARCH" == "aarch64" ]];then
        check_uefi_firmware
        if [ $? -ne $EXIT_OK ];then
            return 1
        fi
        CMD=(qemu-system-aarch64)
        CMD+=(-M "$MACHINE" -cpu "$CPU")
        [[ ${#BOOT_ORDER[@]} -gt 0 ]] && CMD+=("${BOOT_ORDER[@]}")
        CMD+=(-drive "if=pflash,format=raw,readonly=on,file=$UEFI_CODE")
        [ -n "$UEFI_VARS" ] && CMD+=(-drive "if=pflash,format=raw,file=$UEFI_VARS")
    else
        CMD=(qemu-system-x86_64)
        CMD+=(-M "$MACHINE" -cpu "$CPU")
        [[ ${#BOOT_ORDER[@]} -gt 0 ]] && CMD+=("${BOOT_ORDER[@]}")
        CMD+=(-accel tcg,thread=multi)
        CMD+=(-display none)
        if [[ "$MACHINE" == "q35" ]]; then
            check_uefi_firmware
            if [ $? -ne $EXIT_OK ];then
                return 1
            fi
            local USE_X86_CODE USE_X86_VARS
            if [[ -n "$X86_OVMF_CODE" && -f "$X86_OVMF_CODE" ]]; then
                USE_X86_CODE="$X86_OVMF_CODE"
            else
                USE_X86_CODE="$SYS_X86_OVMF_CODE"
            fi
            if [[ -n "$X86_OVMF_VARS" && -f "$X86_OVMF_VARS" ]]; then
                USE_X86_VARS="$X86_OVMF_VARS"
            else
                USE_X86_VARS="$SYS_X86_OVMF_VARS"
            fi
            CMD+=(-drive "if=pflash,format=raw,readonly=on,file=$USE_X86_CODE")
            CMD+=(-drive "if=pflash,format=raw,size=32M,file=$USE_X86_VARS")
        fi
    fi
    CMD+=(
        -smp "$SMP"
        -m "$MEM"
        -device "$GPU"
        -device qemu-xhci
        -device usb-kbd
        -device usb-tablet
        -serial mon:stdio
    )
    [ -n "$HDA" ] && CMD+=(-drive "file=$HDA,if=virtio")
    [ -n "$CDROM" ] && CMD+=(-cdrom "$CDROM")
    local DNS_STR="dns=${DNS_MAIN},dns=${DNS_ALT}"
    local FWD_STR="hostfwd=tcp::${SSH_FORWARD_PORT}-:22"
    if [[ "$NET_MODE" == "user" ]]; then
        CMD+=(-netdev "user,id=net0,$FWD_STR,$DNS_STR")
        CMD+=(-device virtio-net-pci,netdev=net0)
    else
        CMD+=(-netdev "tap,id=net0" -device virtio-net-pci,netdev=net0)
    fi
    local VNC_FULL="${VNC_LISTEN_ADDR}:${VNC_DISPLAY}"
    if [[ -n "$VNC_PASSWD" ]]; then
        VNC_FULL+=",password"
    fi
    CMD+=(-vnc "$VNC_FULL")
    return 0
}
start_vm(){
    check_qemu_running
    if [[ -z "$HDA" ]];then
        msgbox "先选择或新建qcow2虚拟磁盘"
        return
    fi
    if [[ "$TARGET_ARCH" == "aarch64" && -z "$UEFI_VARS" ]];then
        dialog --backtitle "$BACKTITLE" --title "提示" --yesno "ARM64未设置vars.fd，BIOS设置无法保存，是否继续？" 14 64 || true
        [ $? -ne 0 ] && return
    fi
    build_cmd
    if [ $? -ne 0 ];then
        return
    fi
    local VM_LOG=$(get_vm_log_path)
    dialog --backtitle "$BACKTITLE" --title "启动确认" --yesno "参数预览
架构(Arch):$TARGET_ARCH 主板(Type):$MACHINE 内存(RAM):${MEM}M 核心(Cores):$SMP 显卡(Graphics):$GPU
VNC:$VNC_LISTEN_ADDR:$VNC_DISPLAY
日志(Log)：$VM_LOG
串口控制台(tty)：当前Termux终端窗口
确认启动？" 20 76 || true
    [ $? -ne 0 ] && return
    > "$VM_LOG"
    clear
    echo "=========================================================="
    echo "           QEMU 虚拟机运行终端"
    echo " VNC地址：$VNC_LISTEN_ADDR:$VNC_DISPLAY "
    echo " 串口日志：此窗口 | 日志文件位置：$VM_LOG"
    echo " 终止虚拟机：在另一窗口执行 pkill qemu（可能会导致进程误杀）"
    echo "             建议使用 kill -9 [PID] 进行针对性操作"
    echo "=========================================================="
    echo "时间：$(date '+%Y-%m-%d %H:%M:%S')" >> "$VM_LOG"
    echo "命令：${CMD[*]}" >> "$VM_LOG"
    echo "==========================================================" >> "$VM_LOG"
    "${CMD[@]}" 2>&1 | tee "$VM_LOG"
    echo -e "\nQEMU进程已终止"
    echo "\n"
    read -n1 -p "按任意键返回主页面"
}
check_qcow2(){
    if [[ -z "$HDA" ]];then
        msgbox "先选择虚拟磁盘文件（*.qcow2）"
        return
    fi
    clear
    echo "正在校验镜像完整性：$HDA"
    qemu-img check "$HDA"
    read -n1 -p "校验完成，按任意键返回"
}
view_log(){
    local VM_LOG=$(get_vm_log_path)
    dialog --backtitle "$BACKTITLE" --title "运行日志" --tailbox "$VM_LOG" 21 72
}
main_menu(){
    while true;do
        DISK_PREVIEW=$(basename "$HDA" 2>/dev/null)
        ISO_PREVIEW=$(basename "$CDROM" 2>/dev/null)
        A_VARS_PREVIEW=$(basename "$UEFI_VARS" 2>/dev/null)
        X_CODE_PREVIEW=$(basename "$X86_OVMF_CODE" 2>/dev/null)
        X_VARS_PREVIEW=$(basename "$X86_OVMF_VARS" 2>/dev/null)
        local need_warning=0
        local warning_msg=""
        if [[ -n "$HDA" && "$HDA" =~ ^/storage/emulated/0 ]]; then
            need_warning=1
            warning_msg="${warning_msg}\n• 虚拟磁盘: ${HDA}"
        fi
        if [[ -n "$CDROM" && "$CDROM" =~ ^/storage/emulated/0 ]]; then
            need_warning=1
            warning_msg="${warning_msg}\n• ISO镜像: ${CDROM}"
        fi
        if [[ $need_warning -eq 1 ]]; then
            dialog --backtitle "$BACKTITLE" \
            --title "性能优化建议" \
            --colors \
            --msgbox "\Z1\Zb检测到所需文件位于内部存储\Zn
            \Zb建议：将文件移动至Termux私有目录以提升读写性能
[$HOME/]
文件迁移后虚拟机读写速度更快
\Z1\Zb[重要风险提醒]\Zn
卸载Termux会直接清空私有目录[/data/data/com.termux]内全部内容，
虚拟磁盘、配置文件将会永久丢失！
重要资料务必提前备份到内部存储[/storage/emulated/0/]
[按回车键继续]" 24 76 || true
        fi
        local MENU_ITEMS=()
        MENU_ITEMS+=(
            "1" "切换架构 aarch64/x86_64"
        )
        if [[ "$TARGET_ARCH" == "x86_64" ]];then
            MENU_ITEMS+=("1a" "切换x86主板 pc(i440fx)/q35")
        fi
        MENU_ITEMS+=(
            "2" "选择 qcow2 虚拟磁盘 [图形界面]"
            "D" "新建 qcow2 虚拟磁盘"
            "3" "选择 iso 安装镜像 [图形界面]"
        )
        if [[ "$TARGET_ARCH" == "aarch64" ]]; then
            MENU_ITEMS+=("4" "选择 ARM64 UEFI vars.fd [图形界面]")
        fi
        MENU_ITEMS+=("F" "生成空白UEFI vars.fd [与磁盘/ISO同名]")
        if [[ "$TARGET_ARCH" == "x86_64" ]]; then
            MENU_ITEMS+=(
                "5" "自定义x86 OVMF_CODE.fd [图形界面]"
                "6" "自定义x86 OVMF_VARS.fd [图形界面]"
            )
        fi
        MENU_ITEMS+=(
            "7" "虚拟CPU型号"
            "8" "设置分配RAM"
            "9" "CPU核心数"
            "0" "虚拟显卡"
            "N" "网络"
            "V" "VNC连接"
            "S" "保存当前配置"
            "L" "读取已有配置"
            "C" "校验虚拟磁盘文件 [*.qcow2]"
            "R" "查看Qemu日志"
            "RUN" "按当前配置启动虚拟机"
            "EXIT" "退出工具"
        )
        local OPT
        OPT=$(dialog --backtitle "$BACKTITLE" --title "主菜单" \
        --menu "当前配置
    架构(Arch):$TARGET_ARCH 主板(Type):$MACHINE CPU:$CPU 核心(Cores):$SMP 内存(RAM):${MEM}M 显卡(Graphics):$GPU
    磁盘(Disk):${DISK_PREVIEW:-无} iso(CDROM):${ISO_PREVIEW:-无}
    ARM64 VARS:${A_VARS_PREVIEW:-无}
    x86 OVMF CODE:${X_CODE_PREVIEW:-系统内置} OVMF VARS:${X_VARS_PREVIEW:-系统内置}
    VNC:$VNC_LISTEN_ADDR:$VNC_DISPLAY 网络:$NET_MODE SSH端口:$SSH_FORWARD_PORT" 36 104 22 \
        "${MENU_ITEMS[@]}" 2>&1 >/dev/tty) || true
        case "$OPT" in
        1) choose_arch ;;
        1a) choose_x86_machine ;;
        2) HDA=$(select_qcow2_disk) ;;
        D) create_qcow2_disk ;;
        3) CDROM=$(select_iso_file) ;;
        4) [[ "$TARGET_ARCH" == "aarch64" ]] && UEFI_VARS=$(dialog --backtitle "$BACKTITLE" --title "选择ARM64 UEFI vars.fd" --fselect "$STORAGE_ROOT" 17 66 2>&1 >/dev/tty) ;;
        F) create_empty_vars_fd "$TARGET_ARCH" ;;
        5) [[ "$TARGET_ARCH" == "x86_64" ]] && select_x86_ovmf_code ;;
        6) [[ "$TARGET_ARCH" == "x86_64" ]] && select_x86_ovmf_vars ;;
        7) choose_cpu ;;
        8) choose_memory ;;
        9) choose_smp ;;
        0) choose_gpu ;;
        N) network_setting_menu ;;
        V) vnc_setting_menu ;;
        S) save_config ;;
        L) load_config ;;
        C) check_qcow2 ;;
        R) view_log ;;
        RUN) start_vm ;;
        EXIT) clear;exit $EXIT_OK ;;
        esac
    done
}
env_check_text
main_menu
