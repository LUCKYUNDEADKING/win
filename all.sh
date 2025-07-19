bash <(cat << 'EOF'
#!/bin/bash
set -euo pipefail

GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
NC="\033[0m"

log(){ echo -e "$1"; }

log "${CYAN}▶▶▶ 一键：清理旧模块 → 安装 BBRPlus DKMS → NGINX 优化 ◀◀◀${NC}"
log "当前内核：$(uname -r)"

# 1. 安装依赖
log "${GREEN}[1/9] 安装依赖...${NC}"
sudo apt update -y
sudo apt install -y dkms build-essential linux-headers-$(uname -r) wget unzip nginx

# 2. 清理旧模块
log "${GREEN}[2/9] 清理旧 DKMS 模块（如存在）...${NC}"
if dkms status | grep -q tcp_bbrplus; then
  sudo dkms remove tcp_bbrplus/0.1 --all || true
  sudo rm -rf /usr/src/tcp_bbrplus-0.1
  log "${YELLOW}旧模块已卸载${NC}"
else
  log "${GREEN}无旧模块，跳过${NC}"
fi

# 3. 下载源码
log "${GREEN}[3/9] 下载源码...${NC}"
TMP=\$(mktemp -d)
wget -qO "\$TMP/tcp_bbrplus.zip" https://github.com/KozakaiAya/TCP_BBR/archive/refs/heads/master.zip

# 4. 解压源码
log "${GREEN}[4/9] 解压源码...${NC}"
sudo rm -rf /usr/src/tcp_bbrplus-0.1
sudo unzip -q "\$TMP/tcp_bbrplus.zip" -d /usr/src/
sudo mv /usr/src/TCP_BBR-master /usr/src/tcp_bbrplus-0.1
rm -rf "\$TMP"

# 5. 写入 dkms.conf
log "${GREEN}[5/9] 写入 dkms.conf...${NC}"
sudo tee /usr/src/tcp_bbrplus-0.1/dkms.conf > /dev/null << 'EOD'
PACKAGE_NAME="tcp_bbrplus"
PACKAGE_VERSION="0.1"
MAKE[0]="make -C ./code tcp_bbrplus.ko"
BUILT_MODULE_NAME[0]="tcp_bbrplus"
DEST_MODULE_LOCATION[0]="/kernel/net/ipv4/"
AUTOINSTALL="yes"
EOD

# 6. 添加并编译安装
log "${GREEN}[6/9] 添加 & 构建 & 安装 DKMS 模块...${NC}"
sudo dkms add -m tcp_bbrplus -v 0.1
sudo dkms build -m tcp_bbrplus -v 0.1
sudo dkms install -m tcp_bbrplus -v 0.1

# 7. 加载模块 & 配置 sysctl
log "${GREEN}[7/9] 加载模块 & 配置 sysctl...${NC}"
sudo modprobe tcp_bbrplus || true
if ! grep -q "net.ipv4.tcp_congestion_control.*tcp_bbrplus" /etc/sysctl.conf; then
  sudo tee -a /etc/sysctl.conf > /dev/null << 'EOD2'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = tcp_bbrplus
EOD2
fi
sudo sysctl -p

# 8. NGINX 优化
log "${GREEN}[8/9] 配置 NGINX(gzip + Cloudflare IP)...${NC}"
sudo tee /etc/nginx/conf.d/optim.conf > /dev/null << 'EOD3'
server {
    listen 80 default_server;
    server_name _;
    location / { root /var/www/html; index index.html; }
    gzip on; gzip_types text/plain application/xml application/javascript text/css application/json;
    gzip_vary on; gzip_min_length 1024;
    set_real_ip_from 103.21.244.0/22; set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22; set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14; set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 131.0.72.0/22; set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 162.158.0.0/15; set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 173.245.48.0/20; set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 190.93.240.0/20; set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17; real_ip_header CF-Connecting-IP;
}
EOD3
sudo systemctl restart nginx

# 9. 完成校验
log "${GREEN}[9/9] 安装检查...${NC}"
if sysctl net.ipv4.tcp_congestion_control | grep -q tcp_bbrplus; then
  log "${GREEN}✅ 安装成功，已启用 tcp_bbrplus${NC}"
else
  log "${RED}❌ 安装失败，当前：$(sysctl net.ipv4.tcp_congestion_control)${NC}"
  exit 1
fi

log "${CYAN}建议重启：sudo reboot${NC}"
EOF
