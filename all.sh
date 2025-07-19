#!/bin/bash
set -e

GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

REPO="UJX6N/bbrplus-6.x_stable"

function log() {
  echo -e "${GREEN}[INFO] $1${NC}"
}
function error() {
  echo -e "${RED}[ERROR] $1${NC}"
  exit 1
}

log "安装依赖..."
sudo apt update
sudo apt install -y wget curl jq dkms build-essential linux-headers-$(uname -r)

log "获取GitHub最新发布版本..."
LATEST_VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | jq -r .tag_name)
if [ -z "$LATEST_VERSION" ]; then
  error "无法获取最新版本号"
fi
log "最新版本：$LATEST_VERSION"

BASE_URL="https://github.com/$REPO/releases/download/$LATEST_VERSION"

KERNEL_IMG="linux-image-${LATEST_VERSION}-amd64.deb"
KERNEL_HEADERS="linux-headers-${LATEST_VERSION}-amd64.deb"

log "下载内核包 $KERNEL_IMG"
wget -q --show-progress -O "$KERNEL_IMG" "$BASE_URL/$KERNEL_IMG" || error "下载内核包失败"

log "下载内核头文件包 $KERNEL_HEADERS"
wget -q --show-progress -O "$KERNEL_HEADERS" "$BASE_URL/$KERNEL_HEADERS" || error "下载内核头文件包失败"

log "安装内核包..."
sudo dpkg -i "$KERNEL_IMG" || error "安装内核包失败"

log "安装内核头文件包..."
sudo dpkg -i "$KERNEL_HEADERS" || error "安装内核头文件包失败"

log "更新grub..."
sudo update-grub

log "设置默认TCP拥塞控制为bbrplus..."
sudo sysctl -w net.core.default_qdisc=fq
sudo sysctl -w net.ipv4.tcp_congestion_control=tcp_bbrplus

current_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
if [ "$current_cc" == "tcp_bbrplus" ]; then
  log "成功启用 TCP 拥塞控制算法 tcp_bbrplus！"
else
  error "启用 tcp_bbrplus 失败，当前算法为 $current_cc"
fi

log "完成，建议重启以应用新内核：sudo reboot"
