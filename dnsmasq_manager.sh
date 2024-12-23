#!/bin/bash

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

# 检查是否为root用户
[[ $EUID -ne 0 ]] && echo -e "${RED}错误：${PLAIN} 必须使用root用户运行此脚本！\n" && exit 1

# 系统检测
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

# 安装Dnsmasq
install_dnsmasq() {
    if [[ ${release} == "centos" ]]; then
        yum install -y dnsmasq
    else
        apt-get update
        apt-get install -y dnsmasq
    fi

    # 配置DNS服务器
    configure_dns
    
    # 配置resolv.conf
    configure_resolv
    
    # 启动服务
    if [[ ${release} == "centos" ]]; then
        systemctl enable dnsmasq
        systemctl start dnsmasq
    else
        systemctl enable dnsmasq
        systemctl start dnsmasq
    fi
    
    echo -e "${GREEN}Dnsmasq 安装并配置完成！${PLAIN}"
}

# 配置DNS服务器
configure_dns() {
    echo -e "${GREEN}配置DNS服务器${PLAIN}"
    echo "----------------"
    echo -e "${YELLOW}提示：对于每个流媒体服务，您可以：${PLAIN}"
    echo -e "1. 输入解锁DNS服务器地址来配置分流"
    echo -e "2. 直接回车使用系统默认DNS"
    echo "----------------"
    
    echo -e "\n1. Netflix DNS设置"
    read -p "请输入Netflix解锁DNS地址 [回车使用默认DNS]: " netflix_dns
    
    echo -e "\n2. Disney+ DNS设置"
    read -p "请输入Disney+解锁DNS地址 [回车使用默认DNS]: " disney_dns
    
    echo -e "\n3. Bahamut DNS设置"
    read -p "请输入Bahamut解锁DNS地址 [回车使用默认DNS]: " bahamut_dns
    
    echo -e "\n4. OpenAI DNS设置"
    read -p "请输入OpenAI解锁DNS地址 [回车使用默认DNS]: " openai_dns
    
    echo -e "\n5. Discovery+ DNS设置"
    read -p "请输入Discovery+解锁DNS地址 [回车使用默认DNS]: " discovery_dns
    
    echo -e "\n6. CBS DNS设置"
    read -p "请输入CBS解锁DNS地址 [回车使用默认DNS]: " cbs_dns
    
    # 备份原配置
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
    
    # 基础配置
    cat > /etc/dnsmasq.conf <<EOF
# 基础配置
port=53
domain-needed
bogus-priv
no-resolv
no-poll
server=8.8.8.8
server=8.8.4.4
cache-size=2048

EOF

    # Netflix配置
    if [[ ! -z "$netflix_dns" ]]; then
        cat >> /etc/dnsmasq.conf <<EOF
# Netflix
server=/fast.com/${netflix_dns}
server=/netflix.ca/${netflix_dns}
server=/netflix.com/${netflix_dns}
server=/netflix.net/${netflix_dns}
server=/netflixinvestor.com/${netflix_dns}
server=/netflixtechblog.com/${netflix_dns}
server=/nflxext.com/${netflix_dns}
server=/nflximg.com/${netflix_dns}
server=/nflximg.net/${netflix_dns}
server=/nflxsearch.net/${netflix_dns}
server=/nflxso.net/${netflix_dns}
server=/nflxvideo.net/${netflix_dns}

EOF
    fi

    # Disney+配置
    if [[ ! -z "$disney_dns" ]]; then
        cat >> /etc/dnsmasq.conf <<EOF
# Disney+
server=/disney.asia/${disney_dns}
server=/disney.be/${disney_dns}
server=/disney.bg/${disney_dns}
server=/disney.ca/${disney_dns}
server=/disney.ch/${disney_dns}
server=/disney.co.il/${disney_dns}
server=/disney.co.jp/${disney_dns}
server=/disney.co.kr/${disney_dns}
server=/disney.co.th/${disney_dns}
server=/disney.co.uk/${disney_dns}
server=/disney.co.za/${disney_dns}
server=/disney.com/${disney_dns}
server=/disney.com.au/${disney_dns}
server=/disney.com.br/${disney_dns}
server=/disney.com.hk/${disney_dns}
server=/disney.com.tw/${disney_dns}
server=/disney.cz/${disney_dns}
server=/disney.de/${disney_dns}
server=/disney.dk/${disney_dns}
server=/disney.es/${disney_dns}
server=/disney.fi/${disney_dns}
server=/disney.fr/${disney_dns}
server=/disney.gr/${disney_dns}
server=/disney.hu/${disney_dns}
server=/disney.id/${disney_dns}
server=/disney.in/${disney_dns}
server=/disney.io/${disney_dns}
server=/disney.it/${disney_dns}
server=/disney.my/${disney_dns}
server=/disney.nl/${disney_dns}
server=/disney.no/${disney_dns}
server=/disney.ph/${disney_dns}
server=/disney.pl/${disney_dns}
server=/disney.pt/${disney_dns}
server=/disney.ro/${disney_dns}
server=/disney.ru/${disney_dns}
server=/disney.se/${disney_dns}
server=/disney.sg/${disney_dns}
server=/20thcenturystudios.com.au/${disney_dns}
server=/20thcenturystudios.com.br/${disney_dns}
server=/20thcenturystudios.jp/${disney_dns}
server=/adventuresbydisney.com/${disney_dns}
server=/babble.com/${disney_dns}
server=/babyzone.com/${disney_dns}
server=/bamgrid.com/${disney_dns}
server=/beautyandthebeastmusical.co.uk/${disney_dns}
server=/dilcdn.com/${disney_dns}
server=/disney-asia.com/${disney_dns}
server=/disney-discount.com/${disney_dns}
server=/disney-plus.net/${disney_dns}
server=/disney-portal.my.onetrust.com/${disney_dns}
server=/disney-studio.com/${disney_dns}
server=/disney-studio.net/${disney_dns}
server=/disney.my.sentry.io/${disney_dns}
server=/disneyadsales.com/${disney_dns}
server=/disneyarena.com/${disney_dns}
server=/disneyaulani.com/${disney_dns}
server=/disneybaby.com/${disney_dns}
server=/disneycareers.com/${disney_dns}
server=/disneychannelonstage.com/${disney_dns}
server=/disneychannelroadtrip.com/${disney_dns}
server=/disneycruisebrasil.com/${disney_dns}
server=/disneyenconcert.com/${disney_dns}
server=/disneyiejobs.com/${disney_dns}
server=/disneyinflight.com/${disney_dns}
server=/disneyinternational.com/${disney_dns}
server=/disneyinternationalhd.com/${disney_dns}
server=/disneyjunior.com/${disney_dns}
server=/disneyjuniortreataday.com/${disney_dns}
server=/disneylatino.com/${disney_dns}
server=/disneymagicmoments.co.il/${disney_dns}
server=/disneymagicmoments.co.uk/${disney_dns}
server=/disneymagicmoments.co.za/${disney_dns}
server=/disneymagicmoments.de/${disney_dns}
server=/disneymagicmoments.es/${disney_dns}
server=/disneymagicmoments.fr/${disney_dns}
server=/disneymagicmoments.gen.tr/${disney_dns}
server=/disneymagicmoments.gr/${disney_dns}
server=/disneymagicmoments.it/${disney_dns}
server=/disneymagicmoments.pl/${disney_dns}
server=/disneymagicmomentsme.com/${disney_dns}
server=/disneyme.com/${disney_dns}
server=/disneymeetingsandevents.com/${disney_dns}
server=/disneymovieinsiders.com/${disney_dns}
server=/disneymusicpromotion.com/${disney_dns}
server=/disneynewseries.com/${disney_dns}
server=/disneynow.com/${disney_dns}
server=/disneypeoplesurveys.com/${disney_dns}
server=/disneyplus.bn5x.net/${disney_dns}
server=/disneyplus.com/${disney_dns}
server=/disneyplus.com.ssl.sc.omtrdc.net/${disney_dns}
server=/disneyredirects.com/${disney_dns}
server=/disneysrivieraresort.com/${disney_dns}
server=/disneystore.com/${disney_dns}
server=/disneystreaming.com/${disney_dns}
server=/disneysubscription.com/${disney_dns}
server=/disneytickets.co.uk/${disney_dns}
server=/disneyturkiye.com.tr/${disney_dns}
server=/disneytvajobs.com/${disney_dns}
server=/disneyworld-go.com/${disney_dns}
server=/dssott.com/${disney_dns}
server=/go-disneyworldgo.com/${disney_dns}
server=/go.com/${disney_dns}
server=/mickey.tv/${disney_dns}
server=/moviesanywhere.com/${disney_dns}
server=/nomadlandmovie.ch/${disney_dns}
server=/playmation.com/${disney_dns}
server=/shopdisney.com/${disney_dns}
server=/shops-disney.com/${disney_dns}
server=/sorcerersarena.com/${disney_dns}
server=/spaindisney.com/${disney_dns}
server=/star-brasil.com/${disney_dns}
server=/star-latam.com/${disney_dns}
server=/starwars.com/${disney_dns}
server=/starwarsgalacticstarcruiser.com/${disney_dns}
server=/starwarskids.com/${disney_dns}
server=/streamingdisney.net/${disney_dns}
server=/thestationbymaker.com/${disney_dns}
server=/thisispolaris.com/${disney_dns}
server=/watchdisneyfe.com/${disney_dns}

EOF
    fi

    # Bahamut配置
    if [[ ! -z "$bahamut_dns" ]]; then
        cat >> /etc/dnsmasq.conf <<EOF
# Bahamut
server=/bahamut.akamaized.net/${bahamut_dns}
server=/bahamut.com.tw/${bahamut_dns}
server=/gamer.com.tw/${bahamut_dns}

EOF
    fi

    # OpenAI配置
    if [[ ! -z "$openai_dns" ]]; then
        cat >> /etc/dnsmasq.conf <<EOF
# OpenAI
server=/ai.com/${openai_dns}
server=/chatgpt.com/${openai_dns}
server=/chat.com/${openai_dns}
server=/oaistatic.com/${openai_dns}
server=/oaiusercontent.com/${openai_dns}
server=/openai.com/${openai_dns}
server=/sora.com/${openai_dns}

EOF
    fi

    # Discovery+配置
    if [[ ! -z "$discovery_dns" ]]; then
        cat >> /etc/dnsmasq.conf <<EOF
# Discovery+
server=/content-ause1-ur-discovery1.uplynk.com/${discovery_dns}
server=/disco-api.com/${discovery_dns}
server=/discoveryplus.com/${discovery_dns}

EOF
    fi

    # CBS配置
    if [[ ! -z "$cbs_dns" ]]; then
        cat >> /etc/dnsmasq.conf <<EOF
# CBS
server=/cbs.com/${cbs_dns}
server=/cbscorporation.com/${cbs_dns}
server=/cbsi.com/${cbs_dns}
server=/cbsi.video/${cbs_dns}
server=/cbsiam.com/${cbs_dns}
server=/cbsig.net/${cbs_dns}
server=/cbsimg.net/${cbs_dns}
server=/cbsinteractive.com/${cbs_dns}
server=/cbsistatic.com/${cbs_dns}
server=/cbsivideo.com/${cbs_dns}
server=/cbsnews.com/${cbs_dns}
server=/cbspressexpress.com/${cbs_dns}
server=/cbssports.com/${cbs_dns}
server=/cbsstatic.com/${cbs_dns}
server=/cbssvideo.com/${cbs_dns}
server=/viacbs.com/${cbs_dns}
server=/viacom.com/${cbs_dns}
server=/viacomcbs.com/${cbs_dns}
server=/viacomcbspressexpress.com/${cbs_dns}
server=/paramount.com/${cbs_dns}
server=/amlg.io/${cbs_dns}
server=/cbsaavideo.com/${cbs_dns}
server=/mtvnservices.com/${cbs_dns}
server=/paramountplus.com/${cbs_dns}
server=/pplusstatic.com/${cbs_dns}
address=/cbsi.live.ott.irdeto.com/${cbs_dns}
address=/cbsplaylistserver.aws.syncbak.com/${cbs_dns}
address=/cbsservice.aws.syncbak.com/${cbs_dns}
address=/link.theplatform.com/${cbs_dns}
EOF
    fi
    
    systemctl restart dnsmasq
    echo -e "${GREEN}DNS配置已更新！${PLAIN}"
    echo -e "已配置的DNS服务器："
    [[ ! -z "$netflix_dns" ]] && echo -e "Netflix DNS: ${YELLOW}${netflix_dns}${PLAIN}"
    [[ ! -z "$disney_dns" ]] && echo -e "Disney+ DNS: ${YELLOW}${disney_dns}${PLAIN}"
    [[ ! -z "$bahamut_dns" ]] && echo -e "Bahamut DNS: ${YELLOW}${bahamut_dns}${PLAIN}"
    [[ ! -z "$openai_dns" ]] && echo -e "OpenAI DNS: ${YELLOW}${openai_dns}${PLAIN}"
    [[ ! -z "$discovery_dns" ]] && echo -e "Discovery+ DNS: ${YELLOW}${discovery_dns}${PLAIN}"
    [[ ! -z "$cbs_dns" ]] && echo -e "CBS DNS: ${YELLOW}${cbs_dns}${PLAIN}"
}

# 配置resolv.conf
configure_resolv() {
    # 备份原始resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.bak

    # 检查NetworkManager
    if systemctl is-active NetworkManager >/dev/null 2>&1; then
        # 配置NetworkManager使用dnsmasq
        if [ ! -d "/etc/NetworkManager/conf.d" ]; then
            mkdir -p /etc/NetworkManager/conf.d
        fi
        cat > /etc/NetworkManager/conf.d/dnsmasq.conf <<EOF
[main]
dns=dnsmasq
EOF
        systemctl restart NetworkManager
    fi

    # 配置resolv.conf使用本地DNS
    cat > /etc/resolv.conf <<EOF
# Generated by dnsmasq installer
nameserver 127.0.0.1
EOF

    # 防止resolv.conf被覆盖
    chattr +i /etc/resolv.conf

    echo -e "${GREEN}DNS解析已配置为使用本地Dnsmasq服务器${PLAIN}"
}

# 恢复resolv.conf
restore_resolv() {
    # 移除resolv.conf的不可修改属性
    chattr -i /etc/resolv.conf 2>/dev/null
    
    # 如果有备份，则恢复
    if [ -f "/etc/resolv.conf.bak" ]; then
        mv /etc/resolv.conf.bak /etc/resolv.conf
    else
        # 如果没有备份，使用公共DNS
        cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    fi

    # 如果使用NetworkManager，恢复其配置
    if [ -f "/etc/NetworkManager/conf.d/dnsmasq.conf" ]; then
        rm -f /etc/NetworkManager/conf.d/dnsmasq.conf
        systemctl restart NetworkManager
    fi

    echo -e "${GREEN}DNS配置已恢复${PLAIN}"
}

# 卸载Dnsmasq
uninstall_dnsmasq() {
    if [[ ${release} == "centos" ]]; then
        systemctl stop dnsmasq
        systemctl disable dnsmasq
        yum remove -y dnsmasq
    else
        systemctl stop dnsmasq
        systemctl disable dnsmasq
        apt-get remove -y dnsmasq
    fi
    
    # 恢复resolv.conf
    restore_resolv
    
    rm -rf /etc/dnsmasq.conf*
    echo -e "${GREEN}Dnsmasq 已完全卸载！${PLAIN}"
}

# 查看状态
check_status() {
    systemctl status dnsmasq
}

# 重启服务
restart_service() {
    systemctl restart dnsmasq
    echo -e "${GREEN}Dnsmasq 服务已重启！${PLAIN}"
}

# 主菜单
show_menu() {
    echo -e "
  ${GREEN}Dnsmasq 管理脚本${PLAIN}
  ----------------
  ${GREEN}1.${PLAIN} 安装 Dnsmasq
  ${GREEN}2.${PLAIN} 卸载 Dnsmasq
  ${GREEN}3.${PLAIN} 查看状态
  ${GREEN}4.${PLAIN} 重��服务
  ${GREEN}5.${PLAIN} 配置DNS服务器
  ${GREEN}0.${PLAIN} 退出脚本
  ----------------"
    echo && read -p "请输入选择 [0-5]: " num
    
    case "${num}" in
        0) exit 0
        ;;
        1) install_dnsmasq
        ;;
        2) uninstall_dnsmasq
        ;;
        3) check_status
        ;;
        4) restart_service
        ;;
        5) configure_dns
        ;;
        *) echo -e "${RED}请输入正确的数字 [0-5]${PLAIN}"
        ;;
    esac
}

# 显示主菜单
show_menu 