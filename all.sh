#!/bin/bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log() {
  echo -e "$1"
}

log "${CYAN}[1/9] 检测系统和内核版本...${NC}"
KERNEL_VER=$(uname -r)
log "${GREEN}当前内核版本: $KERNEL_VER${NC}"

read -p "是否继续安装 BBRPlus 并优化网络？[Y/N]: " confirm
if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
  log "${RED}已取消。${NC}"
  exit 1
fi

log "${CYAN}[2/9] 安装依赖包...${NC}"
apt update -y
apt install -y wget curl ca-certificates gnupg dkms build-essential linux-headers-$(uname -r)

log "${CYAN}[3/9] 下载 BBRPlus 模块源码...${NC}"
mkdir -p /usr/src/tcp_bbrplus-0.1
cd /usr/src/tcp_bbrplus-0.1

cat << 'EOF' > tcp_bbrplus.c
#include <linux/module.h>
#include <net/tcp.h>

static struct tcp_congestion_ops tcp_bbrplus;

static int __init bbrplus_register(void)
{
    return tcp_register_congestion_control(&tcp_bbrplus);
}

static void __exit bbrplus_unregister(void)
{
    tcp_unregister_congestion_control(&tcp_bbrplus);
}

module_init(bbrplus_register);
module_exit(bbrplus_unregister);

MODULE_AUTHOR("LUCKYUNDEADKING");
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("tcp_bbrplus congestion control");
EOF

cat << 'EOF' > Makefile
obj-m := tcp_bbrplus.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
EOF

log "${CYAN}[4/9] 创建 DKMS 配置...${NC}"
cat << EOF > /usr/src/tcp_bbrplus-0.1/dkms.conf
PACKAGE_NAME="tcp_bbrplus"
PACKAGE_VERSION="0.1"
CLEAN="make clean"
MAKE="make -j1 KERNELRELEASE=${KERNELVER}"
BUILT_MODULE_NAME[0]="tcp_bbrplus"
DEST_MODULE_LOCATION[0]="/updates"
AUTOINSTALL="yes"
EOF

log "${CYAN}[5/9] 添加 DKMS 模块...${NC}"
dkms remove -m tcp_bbrplus -v 0.1 --all >/dev/null 2>&1 || true
dkms add -m tcp_bbrplus -v 0.1
dkms build -m tcp_bbrplus -v 0.1
dkms install -m tcp_bbrplus -v 0.1

log "${CYAN}[6/9] 配置 sysctl 启用 BBRPlus...${NC}"
sed -i '/net\.core\.default_qdisc/d' /etc/sysctl.conf
sed -i '/net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf

cat <<EOF >> /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=tcp_bbrplus
EOF

sysctl -p

log "${CYAN}[7/9] 检查是否安装成功...${NC}"
if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -qE "bbrplus|tcp_bbrplus"; then
  log "${GREEN}✅ 安装成功，当前算法：$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')${NC}"
else
  log "${RED}❌ 安装失败，当前算法：$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')${NC}"
  exit 1
fi

log "${CYAN}[8/9] 建议现在重启系统：sudo reboot${NC}"
