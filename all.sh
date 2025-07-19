#!/bin/bash
set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

function log() {
  echo -e "${GREEN}[INFO] $1${NC}"
}
function error() {
  echo -e "${RED}[ERROR] $1${NC}"
  exit 1
}

# 1. 安装必要依赖
log "更新系统并安装必要依赖..."
sudo apt update
sudo apt install -y build-essential dkms linux-headers-$(uname -r) wget

# 2. 下载高版本 BBRPlus 内核包 (6.4.16-bbrplus)
KERNEL_VER="6.4.16-bbrplus"
BASE_URL="https://github.com/UJX6N/bbrplus-6.x_stable/releases/download/${KERNEL_VER}"

KERNEL_IMG="linux-image-${KERNEL_VER}-amd64.deb"
KERNEL_HEADERS="linux-headers-${KERNEL_VER}-amd64.deb"

log "下载内核包 ${KERNEL_IMG} ..."
wget -q --show-progress -O "$KERNEL_IMG" "${BASE_URL}/${KERNEL_IMG}" || error "下载内核包失败"

log "下载内核头文件包 ${KERNEL_HEADERS} ..."
wget -q --show-progress -O "$KERNEL_HEADERS" "${BASE_URL}/${KERNEL_HEADERS}" || error "下载头文件包失败"

# 3. 安装内核和头文件
log "安装内核包..."
sudo dpkg -i "$KERNEL_IMG" || error "内核包安装失败"

log "安装内核头文件包..."
sudo dpkg -i "$KERNEL_HEADERS" || error "内核头文件安装失败"

# 4. 更新 grub
log "更新 grub 配置..."
sudo update-grub

# 5. 设置默认拥塞控制算法为 bbrplus
log "设置默认 TCP 拥塞控制算法为 bbrplus..."
sudo sysctl -w net.core.default_qdisc=fq
sudo sysctl -w net.ipv4.tcp_congestion_control=tcp_bbrplus

# 6. 校验当前生效算法
current_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
if [ "$current_cc" == "tcp_bbrplus" ]; then
  log "成功启用 TCP 拥塞控制算法 tcp_bbrplus！"
else
  error "启用 tcp_bbrplus 失败，当前算法为 $current_cc"
fi

log "安装完成。请重启系统以启用新内核：sudo reboot"
