#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "$1"; }

log "${CYAN}▶▶▶ 自动安装 BBRPlus DKMS 模块 + 启用 bbrplus 拥塞算法 ◀◀◀${NC}"
log "${GREEN}当前系统内核：$(uname -r)${NC}"

log "${CYAN}[1/7] 安装依赖：dkms、编译工具、内核头等...${NC}"
apt update -y
apt install -y dkms build-essential linux-headers-$(uname -r) wget unzip

log "${CYAN}[2/7] 清理旧 BBRPlus 模块（如存在）...${NC}"
dkms remove -m tcp_bbrplus -v 0.1 --all >/dev/null 2>&1 || true
rm -rf /usr/src/tcp_bbrplus-0.1

log "${CYAN}[3/7] 下载并解压源码...${NC}"
TMP=$(mktemp -d)
wget -qO "$TMP/tcp_bbrplus.zip" https://github.com/KozakaiAya/TCP_BBR/archive/refs/heads/master.zip
rm -rf /usr/src/tcp_bbrplus-0.1
unzip -q "$TMP/tcp_bbrplus.zip" -d /usr/src/
mv /usr/src/TCP_BBR-master /usr/src/tcp_bbrplus-0.1
rm -rf "$TMP"

log "${CYAN}[4/7] 生成 DKMS 配置...${NC}"
cat << 'EOF' > /usr/src/tcp_bbrplus-0.1/dkms.conf
PACKAGE_NAME="tcp_bbrplus"
PACKAGE_VERSION="0.1"
MAKE[0]="make -C ./code tcp_bbrplus.ko"
BUILT_MODULE_NAME[0]="tcp_bbrplus"
DEST_MODULE_LOCATION[0]="/kernel/net/ipv4/"
AUTOINSTALL="yes"
EOF

log "${CYAN}[5/7] 添加 & 构建 & 安装模块...${NC}"
dkms add -m tcp_bbrplus -v 0.1
dkms build -m tcp_bbrplus -v 0.1
dkms install -m tcp_bbrplus -v 0.1

log "${CYAN}[6/7] 加载模块 & 写入 sysctl...${NC}"
modprobe tcp_bbrplus || true
grep -q "net.ipv4.tcp_congestion_control.*tcp_bbrplus" /etc/sysctl.conf || cat >> /etc/sysctl.conf <<EOF2

net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = tcp_bbrplus
EOF2
sysctl -p

log "${CYAN}[7/7] 校验安装结果...${NC}"
if sysctl net.ipv4.tcp_congestion_control | grep -qE "bbrplus"; then
  log "${GREEN}✅ 安装成功，当前拥塞控制 = $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')${NC}"
  log "${CYAN}建议重启系统使内核完全生效：sudo reboot${NC}"
else
  log "${RED}❌ 安装失败，当前拥塞控制 = $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')${NC}"
  exit 1
fi
