#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'

# 获取系统当前 DNS
get_system_dns() {
    if [ -f /etc/resolv.conf ]; then
        local system_dns=$(grep -m1 "nameserver" /etc/resolv.conf | awk '{print $2}')
        if [ -n "$system_dns" ]; then
            echo "$system_dns"
            return
        fi
    fi
    echo "119.29.29.29"  # 如果无法获取系统 DNS，则使用默认值
}

# 检查是否为root用户
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}错误：请使用 root 用户运行此脚本！${PLAIN}"
        exit 1
    fi
}

# 检查系统架构
check_arch() {
    case "$(uname -m)" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *)
            echo -e "${RED}错误：不支持的系统架构！${PLAIN}"
            exit 1
            ;;
    esac
}

# 检查并安装依赖
install_dependencies() {
    echo -e "${GREEN}正在安装依赖...${PLAIN}"
    if command -v apt &>/dev/null; then
        apt update
        apt install -y wget unzip curl
    elif command -v yum &>/dev/null; then
        yum install -y wget unzip curl
    else
        echo -e "${RED}错误：不支持的包管理器！${PLAIN}"
        exit 1
    fi
}

# 安装 MosDNS
install_mosdns() {
    echo -e "${GREEN}正在安装 MosDNS...${PLAIN}"
    
    # 创建目录
    mkdir -p /etc/mosdns

    # 下载最新版本
    local LATEST_VERSION=$(curl -s https://api.github.com/repos/IrineSistiana/mosdns/releases/latest | grep "tag_name" | cut -d'"' -f4)
    wget -O mosdns.zip "https://github.com/IrineSistiana/mosdns/releases/download/${LATEST_VERSION}/mosdns-linux-${ARCH}.zip"
    unzip mosdns.zip
    mv mosdns /usr/local/bin/
    chmod +x /usr/local/bin/mosdns
    rm -f mosdns.zip

    # 下载 geosite.dat
    echo -e "${GREEN}正在下载 geosite.dat...${PLAIN}"
    wget -O /etc/mosdns/geosite.dat https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat
}

# 配置 MosDNS
configure_mosdns() {
    local hk_dns="$1"
    local la_dns="$2"
    local default_dns="$3"

    echo -e "${GREEN}正在配置 MosDNS...${PLAIN}"
    cat > /etc/mosdns/config.yaml << EOF
log:
  level: info
  file: "/var/log/mosdns.log"

data_providers:
  - tag: geosite
    file: ./geosite.dat
    auto_reload: true

plugins:
  # 默认 DNS
  - tag: forward_default
    type: forward
    args:
      upstream:
        - addr: ${default_dns}

  # 香港解锁 DNS
  - tag: forward_hk
    type: forward
    args:
      upstream:
        - addr: ${hk_dns}

  # 洛杉矶解锁 DNS
  - tag: forward_la
    type: forward
    args:
      upstream:
        - addr: ${la_dns}

  # 主要逻辑
  - tag: main_sequence
    type: sequence
    args:
      exec:
        # 香港解锁服务
        - matches: 
            - "query geosite:netflix"
            - "query geosite:disney"
            - "query geosite:bahamut"
          exec: forward_hk
        # 洛杉矶解锁服务
        - matches:
            - "query geosite:openai"
            - "query geosite:discoveryplus"
            - "query geosite:cbs"
          exec: forward_la
        # 其他域名使用默认 DNS
        - matches_all: []
          exec: forward_default

servers:
  - listen: 127.0.0.1:53
    protocol: udp
    entry: main_sequence
EOF
}

# 创建系统服务
create_service() {
    echo -e "${GREEN}正在创建系统服务...${PLAIN}"
    cat > /etc/systemd/system/mosdns.service << EOF
[Unit]
Description=MosDNS
After=network.target

[Service]
Type=simple
WorkingDirectory=/etc/mosdns
ExecStart=/usr/local/bin/mosdns start -d /etc/mosdns
Restart=on-failure

[Install]
WantedBy=multi-user.default.target
EOF

    systemctl daemon-reload
    systemctl enable mosdns
    systemctl start mosdns
}

# 配置系统 DNS
configure_system_dns() {
    echo -e "${GREEN}正在配置系统 DNS...${PLAIN}"
    
    # 备份原始配置
    if [ -f /etc/resolv.conf ]; then
        cp /etc/resolv.conf /etc/resolv.conf.backup
        echo -e "${GREEN}已备份原始 DNS 配置到 /etc/resolv.conf.backup${PLAIN}"
    fi

    # 修改 DNS 配置
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    
    # 防止被覆盖
    chattr +i /etc/resolv.conf
}

# 创建更新脚本
create_update_script() {
    echo -e "${GREEN}正在创建更新脚本...${PLAIN}"
    cat > /usr/local/bin/update-mosdns.sh << EOF
#!/bin/bash
cd /etc/mosdns
wget https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat -O geosite.dat.new
if [ \$? -eq 0 ]; then
    mv geosite.dat.new geosite.dat
    systemctl restart mosdns
    echo "Updated successfully at \$(date)"
else
    echo "Update failed at \$(date)"
    rm -f geosite.dat.new
fi
EOF

    chmod +x /usr/local/bin/update-mosdns.sh
    
    # 添加到 crontab
    (crontab -l 2>/dev/null; echo "0 0 * * 0 /usr/local/bin/update-mosdns.sh") | crontab -
}

# 主函数
main() {
    clear
    echo -e "${GREEN}MosDNS 安装脚本${PLAIN}"
    echo -e "${GREEN}支持：${PLAIN}"
    echo -e "${GREEN}香港节点解锁：Netflix、Disney+、巴哈姆特${PLAIN}"
    echo -e "${GREEN}洛杉矶节点解锁：OpenAI、Discovery+、CBS${PLAIN}"
    echo "------------------------"
    
    check_root
    check_arch

    # 获取系统当前 DNS
    local current_dns=$(get_system_dns)
    
    # 获取用户输入的 DNS 服务器地址
    while true; do
        read -p "请输入香港解锁 DNS 服务器地址: " hk_dns
        if [[ -n "$hk_dns" ]]; then
            break
        else
            echo -e "${RED}错误：DNS 地址不能为空${PLAIN}"
        fi
    done

    while true; do
        read -p "请输入洛杉矶解锁 DNS 服务器地址: " la_dns
        if [[ -n "$la_dns" ]]; then
            break
        else
            echo -e "${RED}错误：DNS 地址不能为空${PLAIN}"
        fi
    done

    read -p "请输入默认 DNS 服务器地址 [默认: ${current_dns}]: " default_dns
    default_dns=${default_dns:-${current_dns}}
    
    install_dependencies
    install_mosdns
    configure_mosdns "$hk_dns" "$la_dns" "$default_dns"
    create_service
    configure_system_dns
    create_update_script
    
    echo -e "${GREEN}MosDNS 安装完成！${PLAIN}"
    echo -e "${GREEN}系统 DNS 已设置为使用 MosDNS${PLAIN}"
    echo -e "${GREEN}原系统 DNS 配置已备份到 /etc/resolv.conf.backup${PLAIN}"
    echo -e "${GREEN}当前使用的 DNS 服务器：${PLAIN}"
    echo -e "${GREEN}香港解锁 DNS：${hk_dns}${PLAIN}"
    echo -e "${GREEN}洛杉矶解锁 DNS：${la_dns}${PLAIN}"
    echo -e "${GREEN}默认 DNS：${default_dns}${PLAIN}"
    echo -e "${YELLOW}提示：如需恢复原始 DNS 配置，请执行：${PLAIN}"
    echo -e "${YELLOW}chattr -i /etc/resolv.conf && cp /etc/resolv.conf.backup /etc/resolv.conf${PLAIN}"
}

main