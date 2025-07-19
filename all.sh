#!/bin/bash

# 颜色定义
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

log() {
  echo -e "$1"
}

log "${BLUE}======= BBRPlus 一键安装脚本 =======${NC}"

# 0. 权限检查
if [[ $EUID -ne 0 ]]; then
  log "${RED}请使用 root 权限运行此脚本！${NC}"
  exit 1
fi

# 1. 显示内核版本
log "${YELLOW}[1/9] 当前内核版本：$(uname -r)${NC}"

# 2. 下载内核
log "${YELLOW}[2/9] 正在下载 BBRPlus 内核（5.10.127）...${NC}"
wget -O linux-image-bbrplus.deb https://github.com/chiakge/Linux-NetSpeed/releases/download/v2022.06.06/linux-image-5.10.127-bbrplus_1.0_amd64.deb

if [[ ! -f linux-image-bbrplus.deb ]]; then
  log "${RED}❌ 下载失败，退出。${NC}"
  exit 1
fi

# 3. 安装内核
log "${YELLOW}[3/9] 安装新内核...${NC}"
dpkg -i linux-image-bbrplus.deb

# 4. 更新 grub 引导
log "${YELLOW}[4/9] 更新 grub...${NC}"
update-grub

# 5. 设置 sysctl 配置
log "${YELLOW}[5/9] 配置 sysctl 启用 bbrplus...${NC}"
sysctl_conf="/etc/sysctl.d/99-bbrplus.conf"
cat > $sysctl_conf <<EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbrplus
EOF

sysctl -p $sysctl_conf

# 6. 设置启动参数检测（可选）
log "${YELLOW}[6/9] 检查是否写入配置...${NC}"
grep bbrplus $sysctl_conf

# 7. 安装完成提示
log "${YELLOW}[7/9] 安装完成，检查 TCP 拥塞算法...${NC}"
current_algo=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')
log "${YELLOW}当前算法：$current_algo${NC}"

# 8. 校验是否成功
log "${YELLOW}[8/9] 校验结果...${NC}"
if [[ "$current_algo" == "bbrplus" ]]; then
  log "${GREEN}✅ 安装成功，BBRPlus 已启用${NC}"
else
  log "${RED}❌ 安装失败，当前拥塞控制算法为 $current_algo${NC}"
  exit 1
fi

# 9. 重启提示
log "${BLUE}[9/9] 请执行 ${YELLOW}sudo reboot${BLUE} 重启以使用新内核${NC}"
