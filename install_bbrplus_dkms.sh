#!/bin/bash
# 一键安装 BBRPlus DKMS 模块（Ubuntu 22.04，无需切换内核）
set -e

echo "======== 开始安装 BBRPlus DKMS 模块（基于 hrimfaxi/tcp_bbr_modules） ========"

read -p "是否继续安装？[Y/N]: " confirm
if [[ $confirm != "Y" && $confirm != "y" ]]; then
  echo "操作已取消"
  exit 1
fi

# 1. 安装依赖
echo "[1/6] 安装依赖包 dkms, build-essential, linux-headers, unzip, wget ..."
sudo apt update
sudo apt install -y dkms build-essential linux-headers-$(uname -r) unzip wget

# 2. 下载并解压源码 ZIP
echo "[2/6] 下载源码 ZIP..."
TMPDIR=$(mktemp -d)
wget -qO "$TMPDIR/tcp_bbr_modules.zip" \
  https://github.com/hrimfaxi/tcp_bbr_modules/archive/refs/heads/main.zip

echo "[3/6] 解压到 /usr/src/tcp_bbrplus-0.1 ..."
sudo rm -rf /usr/src/tcp_bbrplus-0.1
sudo unzip -q "$TMPDIR/tcp_bbr_modules.zip" -d /usr/src/
sudo mv /usr/src/tcp_bbr_modules-main /usr/src/tcp_bbrplus-0.1
rm -rf "$TMPDIR"

# 3. 添加到 DKMS
echo "[4/6] dkms add 模块..."
sudo dkms add -m tcp_bbrplus -v 0.1

# 4. 编译并安装
echo "[5/6] dkms build && install 模块..."
sudo dkms build -m tcp_bbrplus -v 0.1
sudo dkms install -m tcp_bbrplus -v 0.1

# 5. 加载模块并配置 sysctl
echo "[6/6] 加载模块 tcp_bbrplus 并配置加速参数..."
sudo modprobe tcp_bbrplus
sudo tee -a /etc/sysctl.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbrplus
EOF
sudo sysctl -p

echo -e "\n\033[1;32m安装完成！当前拥塞控制算法：\033[0m$(sysctl net.ipv4.tcp_congestion_control)"
echo "如果一切正常，你已成功启用 BBRPlus，无需切换内核。"
