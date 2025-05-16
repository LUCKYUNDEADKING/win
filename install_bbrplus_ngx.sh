
#!/bin/bash

echo -e "\033[1;36m======== BBRPlus + NGINX + Cloudflare 优化安装脚本 ========\033[0m"
echo -e "\033[1;32m[信息] 当前系统内核版本：$(uname -r)\033[0m"

read -p "是否继续安装 BBRPlus 并配置 NGINX 优化？[Y/N]: " confirm
if [[ $confirm != "Y" && $confirm != "y" ]]; then
    echo "操作取消。"
    exit 1
fi

# Step 1: 备份 grub 配置
echo "[备份] 当前 grub 默认配置..."
cp /etc/default/grub /etc/default/grub.bak

# Step 2: 下载 BBRPlus 内核
echo "[下载] BBRPlus 5.10.127 内核..."
wget -O linux-image-5.10.127-bbrplus.deb https://github.com/chiakge/Linux-NetSpeed/releases/download/v2022.06.06/linux-image-5.10.127-bbrplus_1.0_amd64.deb

if [[ ! -f linux-image-5.10.127-bbrplus.deb ]]; then
    echo "[错误] 内核下载失败，请检查网络或链接。"
    exit 1
fi

# Step 3: 安装内核
echo "[安装] 内核中..."
dpkg -i linux-image-5.10.127-bbrplus.deb

# Step 4: 更新 grub
echo "[更新] grub..."
update-grub

# Step 5: 设置 TCP 拥塞算法为 bbrplus
echo "[配置] TCP 加速参数..."
cat << EOF2 | tee -a /etc/sysctl.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbrplus
EOF2

sysctl -p

# Step 6: 安装 NGINX
echo "[安装] NGINX..."
apt update && apt install -y nginx

# Step 7: 优化 NGINX 配置
echo "[优化] NGINX..."
cat << EOF3 > /etc/nginx/conf.d/optim.conf
server {
    listen 80 default_server;
    server_name _;
    location / {
        root /var/www/html;
        index index.html;
    }

    gzip on;
    gzip_types text/plain application/xml application/javascript text/css application/json;
    gzip_vary on;
    gzip_min_length 1024;

    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 131.0.72.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    real_ip_header CF-Connecting-IP;
}
EOF3

systemctl restart nginx

# Step 8: 显示验证信息
echo -e "\n\033[1;34m[完成] 所有操作已执行，请输入以下命令验证：\033[0m"
echo -e "1. uname -r"
echo -e "2. sysctl net.ipv4.tcp_congestion_control"
echo -e "3. nginx -v"
echo -e "\033[1;33m请执行 sudo reboot 重启系统以应用新内核。\033[0m"
