#!/bin/bash
# 一键编译安装 5.15 内核并打 BBRPlus 补丁脚本 (适用于 Ubuntu 22.04+)
# 执行前请确认网络正常，磁盘空间充足（至少5G），root权限运行

set -e

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
NC="\033[0m"

echo -e "${GREEN}开始编译安装 5.15 内核 + BBRPlus 补丁...${NC}"

KERNEL_VERSION="5.15.70"  # 可以根据需要调整，5.15 最新小版本
KERNEL_NAME="linux-$KERNEL_VERSION"
WORKDIR="/usr/src/$KERNEL_NAME"
PATCH_URL="https://raw.githubusercontent.com/ylx2016/BBRPlus/master/bbrplus-5.15.patch"

# 安装依赖
echo -e "${GREEN}安装编译依赖...${NC}"
apt update
apt install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev bc wget

cd /usr/src

# 下载内核源码
if [ ! -d "$WORKDIR" ]; then
  echo -e "${GREEN}下载 Linux $KERNEL_VERSION 源码...${NC}"
  wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz
  tar -xf linux-$KERNEL_VERSION.tar.xz
fi

cd $WORKDIR

# 下载并应用 BBRPlus 补丁
echo -e "${GREEN}下载并应用 BBRPlus 补丁...${NC}"
wget -O bbrplus.patch $PATCH_URL
patch -p1 < bbrplus.patch

# 使用当前配置为基础
echo -e "${GREEN}复制当前内核配置...${NC}"
cp /boot/config-$(uname -r) .config

# 自动配置菜单
yes "" | make oldconfig

# 开始编译内核和模块
echo -e "${GREEN}开始编译内核，请耐心等待...${NC}"
make -j$(nproc)

echo -e "${GREEN}安装内核模块...${NC}"
make modules_install

echo -e "${GREEN}安装内核...${NC}"
make install

# 更新 grub 引导
echo -e "${GREEN}更新 grub 引导...${NC}"
update-grub

# 设置默认启动最新内核
echo -e "${GREEN}设置 grub 默认启动新内核...${NC}"
latest_index=$(grep -P "^menuentry '" /boot/grub/grub.cfg | grep -n "$KERNEL_VERSION" | cut -d: -f1)
if [ -z "$latest_index" ]; then
  echo -e "${RED}未找到新内核 grub 启动项，默认启动项不变${NC}"
else
  grub_set_index=$((latest_index - 1))
  grub-set-default $grub_set_index
  echo -e "${GREEN}默认启动项设置为第 $grub_set_index 项，内核版本 $KERNEL_VERSION${NC}"
fi

echo -e "${YELLOW}内核编译安装完成，请重启系统后执行以下命令验证：${NC}"
echo -e "${YELLOW}  uname -r${NC}"
echo -e "${YELLOW}  cat /proc/sys/net/ipv4/tcp_available_congestion_control${NC}"
echo -e "${YELLOW}  sudo sysctl -w net.core.default_qdisc=fq${NC}"
echo -e "${YELLOW}  sudo sysctl -w net.ipv4.tcp_congestion_control=bbrplus${NC}"

echo -e "${YELLOW}现在重启系统？(Y/n): ${NC}"
read ans
ans=${ans:-Y}
if [[ "$ans" =~ ^[Yy]$ ]]; then
  reboot
else
  echo -e "${GREEN}请手动重启系统以应用新内核。${NC}"
fi
