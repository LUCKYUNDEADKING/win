#!/usr/bin/env bash
# bbrplus.sh — 自动检测、安装、启用 BBRPlus 算法

# 定义颜色
Red='\033[0;31m'; Green='\033[0;32m'; Yellow='\033[0;33m'; GreenPrefix='\033[32m'; RedPrefix='\033[31m'; FontSuffix='\033[0m'
Info="${GreenPrefix}[信息]${FontSuffix}"; Error="${RedPrefix}[错误]${FontSuffix}"

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo -e "${Error} 请使用 root 用户运行脚本！" >&2
    exit 1
fi

# 检测系统类型和版本
OS=""
if [ -f /etc/redhat-release ]; then
    OS="CentOS"
    VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release 2>/dev/null || rpm -q --queryformat '%{VERSION}' redhat-release 2>/dev/null)
elif [ -f /etc/debian_version ]; then
    if grep -qi ubuntu /etc/os-release; then
        OS="Ubuntu"
    else
        OS="Debian"
    fi
    VERSION=$(lsb_release -sr 2>/dev/null || cat /etc/debian_version)
else
    OS=$(uname -s)
    VERSION=$(uname -r)
fi
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "${Error} 不支持 x86_64 以外的系统！" >&2
    exit 1
fi

# 功能函数：检测 BBRPlus 状态
check_bbrplus() {
    cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [ "$cc" = "bbrplus" ]; then
        echo -e "${Info} 当前已启用 BBRPlus (算法: ${Green}$cc${FontSuffix})。"
    else
        echo -e "${Info} 当前拥塞控制算法: ${Green}$cc${FontSuffix} (BBRPlus 未启用)。"
    fi
}

# 功能函数：安装 BBRPlus 内核 (以 5.10 LTS 为例)
install_bbrplus_kernel() {
    echo -e "${Info} 开始安装 BBRPlus 内核..."
    if [[ "$OS" = "Debian" || "$OS" = "Ubuntu" ]]; then
        # 示例：从 GitHub 下载 .deb 包并安装
        # 注意替换为实际的内核版本和下载地址
        KVER="5.10.212-bbrplus"
        wget -qO linux-headers.deb "https://github.com/UJX6N/bbrplus-5.10/releases/download/$KVER/linux-headers_${KVER}_amd64.deb"
        wget -qO linux-image.deb "https://github.com/UJX6N/bbrplus-5.10/releases/download/$KVER/linux-image-${KVER}_amd64.deb"
        dpkg -i linux-image.deb linux-headers.deb
    elif [[ "$OS" = "CentOS" ]]; then
        # 示例：从 GitHub 下载 RPM 并安装
        KVER="5.10.212-bbrplus"
        wget -qO kernel-c7.rpm "https://github.com/UJX6N/bbrplus-5.10/releases/download/$KVER/kernel-${KVER}-el7.x86_64.rpm"
        wget -qO kernel-headers-c7.rpm "https://github.com/UJX6N/bbrplus-5.10/releases/download/$KVER/kernel-headers-${KVER}-el7.x86_64.rpm"
        yum install -y kernel-c7.rpm kernel-headers-c7.rpm
    else
        echo -e "${Error} 无法识别系统类型: $OS" >&2
        return 1
    fi
    echo -e "${Info} BBRPlus 内核安装完成，请重启系统以生效。"
    read -p "是否立即重启? [Y/n]: " yn
    [ -z "$yn" ] && yn="y"
    if [[ $yn =~ ^[Yy]$ ]]; then
        echo -e "${Info} 系统重启中..."
        reboot
    fi
}

# 功能函数：启用 BBRPlus 拥塞控制
enable_bbrplus() {
    echo -e "${Info} 启用 BBRPlus 拥塞控制算法..."
    sysctl_file="/etc/sysctl.conf"
    grep -q "tcp_congestion_control" $sysctl_file || echo "net.ipv4.tcp_congestion_control=bbrplus" >> $sysctl_file
    grep -q "default_qdisc" $sysctl_file || echo "net.core.default_qdisc=fq" >> $sysctl_file
    sysctl -p > /dev/null 2>&1
    echo -e "${Info} 参数已写入 ${Green}$sysctl_file${FontSuffix} 并加载。"
    sysctl net.ipv4.tcp_congestion_control
    echo -e "${Info} BBRPlus 启用完成。"
}

# 功能函数：配置 Grub 默认启动内核
configure_grub() {
    echo -e "${Info} 配置 GRUB 默认启动内核..."
    if [[ "$OS" == "CentOS" ]]; then
        grub2-mkconfig -o /boot/grub2/grub.cfg
    else
        update-grub 2>/dev/null || update-grub2 2>/dev/null
    fi
    echo -e "${Info} GRUB 配置已更新。"
}

# 显示主菜单
while true; do
    echo -e "\n${GreenPrefix}========= BBRPlus 安装与配置脚本 =========${FontSuffix}"
    echo "1. 检查 BBRPlus 状态"
    echo "2. 安装 BBRPlus 内核 (5.10)"
    echo "3. 启用 BBRPlus 算法"
    echo "4. 配置 sysctl 参数 (启用 BBRPlus)"
    echo "5. 配置 GRUB 默认内核"
    echo "0. 退出脚本"
    read -p "请输入选项数字并回车: " choice
    case "$choice" in
        1) check_bbrplus ;;
        2) install_bbrplus_kernel ;;
        3) enable_bbrplus ;;
        4) enable_bbrplus ;;  # 第3项和第4项在此脚本中功能相同
        5) configure_grub ;;
        0) echo -e "${Info} 退出脚本。"; break ;;
        *) echo -e "${Error} 无效选项，请重新输入！" ;;
    esac
done

