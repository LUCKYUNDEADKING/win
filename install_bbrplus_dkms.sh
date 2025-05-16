#!/bin/bash
# 一键安装 BBRPlus DKMS 模块（改用 ZIP，无需克隆 Git）
set -e

echo "======== 开始安装 BBRPlus（DKMS 模块化，无需切换内核） ========"

read -p "是否继续安装 BBRPlus DKMS 模块？[Y/N]: " confirm
if [[ $confirm != "Y" && $confirm != "y" ]]; then
    echo "操作取消"
    exit 1
fi

# 安装依赖
echo "[1/6] 安装编译依赖和 unzip..."
sudo apt update
sudo apt install -y dkms build-essential linux-headers-$(uname -r) unzip wget

# 下载并解压源码
echo "[2/6] 下载 BBRPlus 源码 ZIP..."
TMPDIR=$(mktemp -d)
wget -O "$TMPDIR/bbrplus.zip" \
  https://github.com/linhuangy/BBrPlus-DKMS/archive/refs/heads/main.zip

echo "[3/6] 解压源码到 /usr/src/bbrplus-0.1..."
sudo rm -rf /usr/src/bbrplus-0.1
sudo unzip -q "$TMPDIR/bbrplus.zip" -d /usr/src/
sudo mv /usr/src/BBrPlus-DKMS-main /usr/src/bbrplus-0.1
rm -rf "$TMPDIR"

# 添加到 DKMS
echo "[4/6] 添加到 DKMS..."
sudo dkms add -m bbrplus -v 0.1

# 编译并安装模块
echo "[5/6] 编译并安装 BBRPlus 模块..."
sudo dkms build -m bbrplus -v 0.1
sudo dkms install -m bbrplus -v 0.1

# 加载模块
echo "[6/6] 加载 BBRPlus 模块并配置 sysctl..."
sudo modprobe tcp_bbrplus
sudo tee -a /etc/sysctl.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbrplus
EOF
sudo sysctl -p

echo "======== 安装完成！当前拥塞控制算法：$(sysctl net.ipv4.tcp_congestion_control) ========"
