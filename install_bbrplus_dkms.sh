#!/bin/bash
# 一键安装 BBRPlus DKMS 模块（Ubuntu 22.04）
set -e

echo "======== 开始安装 BBRPlus（基于 DKMS，无需切换内核） ========"

read -p "是否继续安装 BBRPlus DKMS 模块？[Y/N]: " confirm
if [[ $confirm != "Y" && $confirm != "y" ]]; then
    echo "操作取消"
    exit 1
fi

# 更新软件源并安装编译依赖
echo "[1/6] 安装编译依赖..."
sudo apt update
sudo apt install -y dkms build-essential git linux-headers-$(uname -r)

# 克隆 BBRPlus DKMS 源码
echo "[2/6] 下载 BBRPlus DKMS 源码..."
sudo rm -rf /usr/src/bbrplus-0.1
sudo git clone https://github.com/linhuangy/BBrPlus-DKMS.git /usr/src/bbrplus-0.1

# 添加到 DKMS
echo "[3/6] 添加到 DKMS..."
sudo dkms add -m bbrplus -v 0.1

# 编译并安装模块
echo "[4/6] 编译并安装 BBRPlus 模块..."
sudo dkms build -m bbrplus -v 0.1
sudo dkms install -m bbrplus -v 0.1

# 加载模块
echo "[5/6] 加载 BBRPlus 模块..."
sudo modprobe tcp_bbrplus

# 配置系统 TCP 参数
echo "[6/6] 配置 sysctl 优化..."
sudo tee -a /etc/sysctl.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbrplus
EOF

sudo sysctl -p

echo "======== 安装完成！当前拥塞控制算法：$(sysctl net.ipv4.tcp_congestion_control) ========"
