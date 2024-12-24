#!/bin/bash

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

# 检查是否为root用户
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：${PLAIN} 必须使用root用户运行此脚本！\n" && exit 1

# 检查系统类型
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
fi

install_iptables() {
    if [[ ${release} == "centos" ]]; then
        echo -e "${RED}错误：${PLAIN} 此脚本暂时只支持Debian/Ubuntu系统！"
        exit 1
    fi
    
    # 检查是否已安装iptables-persistent
    if dpkg -l | grep -qw iptables-persistent; then
        echo -e "${YELLOW}iptables-persistent 已经安装！${PLAIN}"
    else
        echo -e "${GREEN}正在安装 iptables-persistent...${PLAIN}"
        # 预配置iptables-persistent，避免安装时的交互提示
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
        echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
        apt-get update
        apt-get install -y iptables-persistent
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}iptables-persistent 安装成功！${PLAIN}"
        else
            echo -e "${RED}iptables-persistent 安装失败！${PLAIN}"
            exit 1
        fi
    fi

    # 获取用户输入的IP地址
    while true; do
        read -p "请输入需要允许访问53端口的IP地址: " custom_ip
        # 验证IP地址格式
        if [[ $custom_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            break
        else
            echo -e "${RED}错误：请输入有效的IP地址！${PLAIN}"
        fi
    done

    # 添加iptables规则
    echo -e "${GREEN}正在添加iptables规则...${PLAIN}"
    iptables -I INPUT -s $custom_ip -p udp --dport 53 -j ACCEPT
    
    # 确保/etc/iptables目录存在
    mkdir -p /etc/iptables
    
    # 保存规则到文件
    echo -e "${GREEN}正在保存iptables规则...${PLAIN}"
    iptables-save > /etc/iptables/rules.v4
    
    # 最后执行iptables-save
    iptables-save
    
    echo -e "${GREEN}配置完成！${PLAIN}"
    echo -e "已添加规则：允许IP ${YELLOW}${custom_ip}${PLAIN} 访问53端口"
}

# 执行安装函数
install_iptables 
