#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
NC="\033[0m"

function echo_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}
function echo_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}
function echo_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# 检查root
if [ "$EUID" -ne 0 ]; then
  echo_error "请用root权限运行脚本"
  exit 1
fi

arch=$(uname -m)
if [[ "$arch" != "x86_64" ]]; then
  echo_error "仅支持 x86_64 架构"
  exit 1
fi

os=""
if [[ -f /etc/debian_version ]]; then
  if grep -qi ubuntu /etc/os-release; then
    os="ubuntu"
  else
    os="debian"
  fi
elif [[ -f /etc/centos-release ]]; then
  os="centos"
else
  echo_error "不支持的系统"
  exit 1
fi

echo_info "检测到系统: $os, 架构: $arch"

current_kernel=$(uname -r)
echo_info "当前内核版本: $current_kernel"

if [[ "$current_kernel" == *bbrplus* ]]; then
  echo_info "当前已是 BBRPlus 内核"
else
  echo_warn "当前内核不是 BBRPlus，将安装 BBRPlus 内核"
fi

# 下载和安装内核
if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
  echo_info "下载并安装 BBRPlus 内核(debian/ubuntu)"
  cd /tmp || exit
  wget -q --show-progress https://github.com/ylx2016/Linux-NetSpeed/raw/master/bbrplus/debian-kernel/linux-image-5.10.0-0.bpo.8-amd64.deb
  dpkg -i linux-image-5.10.0-0.bpo.8-amd64.deb
  update-grub
  grub-set-default 0
elif [[ "$os" == "centos" ]]; then
  echo_info "下载并安装 BBRPlus 内核(centos)"
  cd /tmp || exit
  wget -q --show-progress https://github.com/ylx2016/Linux-NetSpeed/raw/master/bbrplus/centos-kernel/kernel-ml-5.10.78-1.el7.elrepo.x86_64.rpm
  yum install -y kernel-ml-5.10.78-1.el7.elrepo.x86_64.rpm
  grub2-set-default 0
  grub2-mkconfig -o /boot/grub2/grub.cfg
else
  echo_error "暂不支持该系统"
  exit 1
fi

echo_info "设置 sysctl 参数启用 BBRPlus"
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
  echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
fi
if ! grep -q "net.ipv4.tcp_congestion_control=bbrplus" /etc/sysctl.conf; then
  echo "net.ipv4.tcp_congestion_control=bbrplus" >> /etc/sysctl.conf
fi
sysctl -p

echo_warn "即将重启系统以应用内核和参数，重启后请重新运行本脚本查看状态"

read -p "是否现在重启？(Y/n): " ans
ans=${ans:-Y}
if [[ "$ans" =~ ^[Yy]$ ]]; then
  reboot
else
  echo_info "请手动重启后再运行脚本检查状态"
fi

