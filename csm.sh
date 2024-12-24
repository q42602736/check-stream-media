#!/bin/bash
shopt -s expand_aliases
Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_SkyBlue="\033[36m"
Font_White="\033[37m"
Font_Suffix="\033[0m"

# 添加日志相关变量
LOG_FILE="/root/media_unlock.log"
DEBUG=true

# DNS配置文件
UNLOCK_CONFIG_FILE="/root/.unlock_config"

# 解锁配置函数
configureUnlock() {
    # 如果指定了跳过配置且配置文件存在，则跳过
    if [[ "$SKIP_CONFIG" == "1" ]] && [[ -f "$UNLOCK_CONFIG_FILE" ]]; then
        return
    fi

    if [[ ! -f "$UNLOCK_CONFIG_FILE" ]]; then
        echo "流媒体解锁 DNS 配置"
        echo "----------------------------------------"
        echo "请为每个流媒体服务设置解锁 DNS 服务器地址"
        echo "支持以下格式："
        echo "1. IPv4 地址，例如: 1.1.1.1"
        echo "2. DNS服务器域名，例如: dns.example.com"
        echo "回车使用系统默认 DNS"
        echo "----------------------------------------"
        echo

        # 先收集所有��入
        read -p "Netflix 解锁 DNS [回车使用系统默认]: " netflix_dns
        read -p "Disney+ 解锁 DNS [回车使用系统默认]: " disney_dns
        read -p "Bahamut 动画疯解锁 DNS [回车使用系统默认]: " bahamut_dns
        read -p "Discovery+ 解锁 DNS [回车使用系统默认]: " discovery_dns
        read -p "Paramount+ 解锁 DNS [回车使用系统默认]: " paramount_dns
        read -p "OpenAI (ChatGPT) 解锁 DNS [回车使用系统默认]: " openai_dns
        read -p "YouTube Premium 解锁 DNS [回车使用系统默认]: " youtube_dns

        echo
        echo "正在生成配置文件..."

        # 创建临时配置文件
        cat > "${UNLOCK_CONFIG_FILE}.tmp" << EOF
NETFLIX_ADDR="$netflix_dns"
DISNEY_ADDR="$disney_dns"
BAHAMUT_ADDR="$bahamut_dns"
DISCOVERY_ADDR="$discovery_dns"
PARAMOUNT_ADDR="$paramount_dns"
OPENAI_ADDR="$openai_dns"
YOUTUBE_ADDR="$youtube_dns"
EOF

        # 检查编码并转换
        iconv -f UTF-8 -t UTF-8 "${UNLOCK_CONFIG_FILE}.tmp" > "$UNLOCK_CONFIG_FILE" 2>/dev/null
        if [ $? -eq 0 ]; then
            rm -f "${UNLOCK_CONFIG_FILE}.tmp"
            echo "DNS 配置已保存到: $UNLOCK_CONFIG_FILE"
            echo "如需修改配置，请删除该文件重新运行脚本"
            echo "提示: rm -f $UNLOCK_CONFIG_FILE"
            echo
        else
            mv "${UNLOCK_CONFIG_FILE}.tmp" "$UNLOCK_CONFIG_FILE"
            echo "DNS 配置已保存（未进行编码转换）"
            echo "如需修改配置，请删除该文件后重新运行脚本"
            echo "提示: rm -f $UNLOCK_CONFIG_FILE"
            echo
        fi
    fi
}

# 获取指定服务的解锁地址
getUnlockAddr() {
    local service=$1
    if [[ -f "$UNLOCK_CONFIG_FILE" ]]; then
        source "$UNLOCK_CONFIG_FILE"
        case $service in
            "netflix")
                echo "$NETFLIX_ADDR"
                ;;
            "disney")
                echo "$DISNEY_ADDR"
                ;;
            "youtube")
                echo "$YOUTUBE_ADDR"
                ;;
            "discovery")
                echo "$DISCOVERY_ADDR"
                ;;
            "paramount")
                echo "$PARAMOUNT_ADDR"
                ;;
            "bahamut")
                echo "$BAHAMUT_ADDR"
                ;;
            "openai")
                echo "$OPENAI_ADDR"
                ;;
        esac
    fi
}

# 使用指定的DNS进行解析
resolveDomain() {
    local domain=$1
    local dns_server=$2
    
    if [[ -n "$dns_server" ]]; then
        # 使用指定的DNS服���器解析域名
        result=$(dig @$dns_server $domain +short +timeout=2 +tries=2)
        if [[ -n "$result" ]]; then
            # 获取最后一个A记录（跳过CNAME）
            local ip=$(echo "$result" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | tail -n 1)
            if [[ -n "$ip" ]]; then
                echo "$ip"
                log "INFO" "使用DNS $dns_server 解析 $domain 结果: $ip"
                return 0
            fi
        fi
        log "ERROR" "使用DNS $dns_server 解析 $domain 失败"
        return 1
    fi
    return 1
}

# 测试DNS解析并设置解析参数
testDNSAndSetXFF() {
    local service=$1
    local domain=$2
    local dns_server=$(getUnlockAddr "$service")
    
    if [[ -n "$dns_server" ]]; then
        log "INFO" "正在使用DNS服务器: $dns_server"
        # 使用DNS服务器解析域名
        local resolved_ip=$(dig @$dns_server $domain +short +timeout=2 +tries=2 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)
        if [[ -n "$resolved_ip" ]]; then
            log "INFO" "域名 $domain 解析成功，IP: $resolved_ip"
            # 设置curl的resolve参数
            useResolve="--resolve ${domain}:443:${resolved_ip} --resolve ${domain}:80:${resolved_ip}"
            xForward="--header X-Forwarded-For:$resolved_ip"
            return 0
        else
            log "ERROR" "域名 $domain 解析失败，DNS服务器: $dns_server"
            useResolve=""
            xForward=""
            return 1
        fi
    else
        # 使用系统默认DNS
        log "INFO" "使用系统默认DNS服务器"
        useResolve=""
        xForward=""
        return 0
    fi
}

# 清理函数
cleanup() {
    # 恢复原始DNS设置
    if [[ -f "/etc/resolv.conf.bak" ]]; then
        cp /etc/resolv.conf.bak /etc/resolv.conf
        rm -f /etc/resolv.conf.bak
    fi
}

# 日志函数
log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
        
        # 如果日志文件大于10MB，则进行轮转
        if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null) -gt 10485760 ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            touch "$LOG_FILE"
        fi
    fi
}

while getopts ":I:M:EX:P:SC" optname; do
    case "$optname" in
    "I")
        iface="$OPTARG"
        useNIC="--interface $iface"
        ;;
    "M")
        if [[ "$OPTARG" == "4" ]]; then
            NetworkType=4
        elif [[ "$OPTARG" == "6" ]]; then
            NetworkType=6
        fi
        ;;
    "E")
        language="e"
        ;;
    "X")
        XIP="$OPTARG"
        xForward="--header X-Forwarded-For:$XIP"
        ;;
    "P")
        proxy="$OPTARG"
        usePROXY="-x $proxy"
        ;;
    "S")
        # 跳过配置
        SKIP_CONFIG=1
        ;;
    "C")
        # 仅配置
        CONFIG_ONLY=1
        ;;
    ":")
        echo "Unknown error while processing options"
        exit 1
        ;;
    esac

done

if [ -z "$iface" ]; then
    useNIC=""
fi

if [ -z "$XIP" ]; then
    xForward=""
fi

if [ -z "$proxy" ]; then
    usePROXY=""
elif [ -n "$proxy" ]; then
    NetworkType=4
fi

if ! mktemp -u --suffix=RRC &>/dev/null; then
    is_busybox=1
fi

UA_Browser="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36"
UA_Dalvik="Dalvik/2.1.0 (Linux; U; Android 9; ALP-AL00 Build/HUAWEIALP-AL00)"
Media_Cookie=$(curl -s --retry 3 --max-time 10 "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/cookies")
IATACode=$(curl -s --retry 3 --max-time 10 "https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/reference/IATACode.txt")
WOWOW_Cookie=$(echo "$Media_Cookie" | awk 'NR==3')
TVer_Cookie="Accept: application/json;pk=BCpkADawqM0_rzsjsYbC1k1wlJLU4HiAtfzjxdUmfvvLUQB-Ax6VA-p-9wOEZbCEm3u95qq2Y1CQQW1K9tPaMma9iAqUqhpISCmyXrgnlpx9soEmoVNuQpiyGsTpePGumWxSs1YoKziYB6Wz"

# 颜色函数
red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}
green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue() {
    echo -e "\033[34m\033[01m$1\033[0m"
}

countRunTimes() {
    if [ "$is_busybox" == 1 ]; then
        count_file=$(mktemp)
    else
        count_file=$(mktemp --suffix=RRC)
    fi
    RunTimes=$(curl -s --max-time 10 "https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fcheck.unclock.media&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=visit&edge_flat=false" >"${count_file}")
    TodayRunTimes=$(cat "${count_file}" | tail -3 | head -n 1 | awk '{print $5}')
    TotalRunTimes=$(($(cat "${count_file}" | tail -3 | head -n 1 | awk '{print $7}') + 2527395))
}
countRunTimes

checkOS() {
    ifTermux=$(echo $PWD | grep termux)
    ifMacOS=$(uname -a | grep Darwin)
    
    if [ -n "$ifTermux" ]; then
        os_version=Termux
        is_termux=1
    elif [ -n "$ifMacOS" ]; then
        os_version=MacOS
        is_macos=1
    else
        os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
    fi

    if [[ "$os_version" == "2004" ]] || [[ "$os_version" == "10" ]] || [[ "$os_version" == "11" ]]; then
        is_windows=1
        ssll="-k --ciphers DEFAULT@SECLEVEL=1"
    fi

    if [ "$(which apt 2>/dev/null)" ]; then
        InstallMethod="apt"
        is_debian=1
    elif [ "$(which dnf 2>/dev/null)" ] || [ "$(which yum 2>/dev/null)" ]; then
        InstallMethod="yum"
        is_redhat=1
    elif [[ "$os_version" == "Termux" ]]; then
        InstallMethod="pkg"
    elif [[ "$os_version" == "MacOS" ]]; then
        InstallMethod="brew"
    fi
}

checkCPU() {
    CPUArch=$(uname -m)
    if [[ "$CPUArch" == "aarch64" ]]; then
        arch=_arm64
    elif [[ "$CPUArch" == "i686" ]]; then
        arch=_i686
    elif [[ "$CPUArch" == "arm" ]]; then
        arch=_arm
    elif [[ "$CPUArch" == "x86_64" ]] && [ -n "$ifMacOS" ]; then
        arch=_darwin
    fi
}

checkDependencies() {

    # os_detail=$(cat /etc/os-release 2> /dev/null)

    if ! command -v python &>/dev/null; then
        if command -v python3 &>/dev/null; then
            alias python="python3"
        else
            if [ "$is_debian" == 1 ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                $InstallMethod update >/dev/null 2>&1
                $InstallMethod install python -y >/dev/null 2>&1
            elif [ "$is_redhat" == 1 ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                if [[ "$os_version" -gt 7 ]]; then
                    $InstallMethod makecache >/dev/null 2>&1
                    $InstallMethod install python3 -y >/dev/null 2>&1
                    alias python="python3"
                else
                    $InstallMethod makecache >/dev/null 2>&1
                    $InstallMethod install python -y >/dev/null 2>&1
                fi

            elif [ "$is_termux" == 1 ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                $InstallMethod update -y >/dev/null 2>&1
                $InstallMethod install python -y >/dev/null 2>&1

            elif [ "$is_macos" == 1 ]; then
                echo -e "${Font_Green}Installing python${Font_Suffix}"
                $InstallMethod install python
            fi
        fi
    fi

    if ! command -v dig &>/dev/null; then
        if [ "$is_debian" == 1 ]; then
            echo -e "${Font_Green}Installing dnsutils${Font_Suffix}"
            $InstallMethod update >/dev/null 2>&1
            $InstallMethod install dnsutils -y >/dev/null 2>&1
        elif [ "$is_redhat" == 1 ]; then
            echo -e "${Font_Green}Installing bind-utils${Font_Suffix}"
            $InstallMethod makecache >/dev/null 2>&1
            $InstallMethod install bind-utils -y >/dev/null 2>&1
        elif [ "$is_termux" == 1 ]; then
            echo -e "${Font_Green}Installing dnsutils${Font_Suffix}"
            $InstallMethod update -y >/dev/null 2>&1
            $InstallMethod install dnsutils -y >/dev/null 2>&1
        elif [ "$is_macos" == 1 ]; then
            echo -e "${Font_Green}Installing bind${Font_Suffix}"
            $InstallMethod install bind
        fi
    fi

    if [ "$is_macos" == 1 ]; then
        if ! command -v md5sum &>/dev/null; then
            echo -e "${Font_Green}Installing md5sha1sum${Font_Suffix}"
            $InstallMethod install md5sha1sum
        fi
    fi

}
checkDependencies

local_ipv4=$(curl $useNIC $usePROXY -4 -s --max-time 10 api64.ipify.org)
local_ipv4_asterisk=$(awk -F"." '{print $1"."$2".*.*"}' <<<"${local_ipv4}")
local_ipv6=$(curl $useNIC -6 -s --max-time 20 api64.ipify.org)
local_ipv6_asterisk=$(awk -F":" '{print $1":"$2":"$3":*:*"}' <<<"${local_ipv6}")
local_isp4=$(curl $useNIC -s -4 --max-time 10 --user-agent "${UA_Browser}" "https://api.ip.sb/geoip/${local_ipv4}" | grep organization | cut -f4 -d '"')
local_isp6=$(curl $useNIC -s -6 --max-time 10 --user-agent "${UA_Browser}" "https://api.ip.sb/geoip/${local_ipv6}" | grep organization | cut -f4 -d '"')

ShowRegion() {
    echo -e "${Font_Yellow} ---${1}---${Font_Suffix}"
}

###########################################
#                                         #
#           required check item           #
#                                         #
###########################################

MediaUnlockTest_Netflix() {
    log "INFO" "正在检测 Netflix 解锁情况..."
    
    # 测试DNS和设置解析参数
    testDNSAndSetXFF "netflix" "www.netflix.com"
    if [[ $? != 0 ]]; then
        log "ERROR" "Netflix DNS解析失败"
        echo -n -e "\r Netflix:\t\t\t\t${Font_Red}DNS解析失败${Font_Suffix}\n"
        return
    fi
    
    log "INFO" "使用 X-Forwarded-For: $(echo $xForward | cut -d':' -f2)"
    local result1=$(curl $useNIC $usePROXY $useResolve $xForward -${1} --user-agent "${UA_Browser}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81280792" 2>&1)
    log "DEBUG" "Netflix 检测状态码: ${result1}"

    if [[ "$result1" == "404" ]]; then
        log "INFO" "Netflix 仅解锁自制"
        modifyJsonTemplate 'Netflix_result' 'No' 'Originals Only'
        echo -n -e "\r Netflix:\t\t\t\t${Font_Yellow}Originals Only${Font_Suffix}\n"
        return
    elif [[ "$result1" == "403" ]]; then
        log "INFO" "Netflix 未解锁"
        echo -n -e "\r Netflix:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'Netflix_result' 'No'
        return
    elif [[ "$result1" == "200" ]]; then
        local region=$(curl $useNIC $usePROXY $useResolve $xForward -${1} --user-agent "${UA_Browser}" -fs --max-time 10 --write-out %{redirect_url} --output /dev/null "https://www.netflix.com/title/80018499" 2>&1 | cut -d '/' -f4 | cut -d '-' -f1 | tr [:lower:] [:upper:])
        log "DEBUG" "Netflix 解锁区域: ${region:-US}"
        if [[ ! -n "$region" ]]; then
            region="US"
        fi
        echo -n -e "\r Netflix:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        modifyJsonTemplate 'Netflix_result' 'Yes' "${region}"
        return
    elif [[ "$result1" == "000" ]]; then
        log "ERROR" "Netflix 网络连接失败"
        echo -n -e "\r Netflix:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'Netflix_result' 'Unknow'
        return
    fi
}

MediaUnlockTest_DisneyPlus() {
    local result=$(curl $useNIC $usePROXY $xForward -${1} -I --max-time 10 "https://www.disneyplus.com" 2>&1)
    
    if [[ "$result" == "curl"* ]]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'Unknow'
        return
    fi
    
    local status_code=$(echo "$result" | grep -E "^HTTP.*" | awk '{print $2}')
    # 提取区域代码，支持任何两字母的国家/地区代码
    local region=$(echo "$result" | grep -i "x-dss-country" | sed -n 's/.*x-dss-country=\([A-Z][A-Z]\).*/\1/Ip')
    
    if [[ "$status_code" == "200" ]]; then
        if [[ -n "$region" ]]; then
            echo -n -e "\r Disney+:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
            modifyJsonTemplate 'DisneyPlus_result' 'Yes' "${region}"
        else
            echo -n -e "\r Disney+:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
            modifyJsonTemplate 'DisneyPlus_result' 'Yes'
        fi
        return
    else
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        return
    fi
}

MediaUnlockTest_YouTube_Premium() {
    testDNSAndSetXFF "youtube" "www.youtube.com"
    local tmpresult=$(curl $useNIC $usePROXY $useResolve $xForward --user-agent "${UA_Browser}" -${1} --max-time 10 -sSL -H "Accept-Language: en" -b "YSC=BiCUU3-5Gdk; CONSENT=YES+cb.20220301-11-p0.en+FX+700; GPS=1; VISITOR_INFO1_LIVE=4VwPMkB7W5A; PREF=tz=Asia.Shanghai; _gcl_au=1.1.1809531354.1646633279" "https://www.youtube.com/premium" 2>&1)

    if [[ "$tmpresult" == "curl"* ]]; then
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'YouTube_Premium_result' 'Unknow'
        return
    fi

    local isCN=$(echo $tmpresult | grep 'www.google.cn')
    if [ -n "$isCN" ]; then
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}No${Font_Suffix} ${Font_Green} (Region: CN)${Font_Suffix} \n"
        modifyJsonTemplate 'YouTube_Premium_result' 'No' 'CN'
        return
    fi
    local isNotAvailable=$(echo $tmpresult | grep 'Premium is not available in your country')
    local region=$(echo $tmpresult | grep "countryCode" | sed 's/.*"countryCode"//' | cut -f2 -d'"')
    local isAvailable=$(echo $tmpresult | grep '/month')

    if [ -n "$isNotAvailable" ]; then
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}No${Font_Suffix} \n"
        modifyJsonTemplate 'YouTube_Premium_result' 'No'
        return
    elif [ -n "$isAvailable" ] && [ -n "$region" ]; then
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Green}Yes (Region: $region)${Font_Suffix}\n"
        modifyJsonTemplate 'YouTube_Premium_result' 'Yes' "${region}"
        return
    elif [ -z "$region" ] && [ -n "$isAvailable" ]; then
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        modifyJsonTemplate 'YouTube_Premium_result' 'Yes'
        return
    else
        echo -n -e "\r YouTube Premium:\t\t\t${Font_Red}Failed${Font_Suffix}\n"
        modifyJsonTemplate 'YouTube_Premium_result' 'Unknow'
    fi
}

MediaUnlockTest_DiscoveryPlus() {
    if [ "${1}" == "6" ]; then
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Red}IPv6 Not Support${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'No' 'IPv6 Not Support'
        return
    fi
    
    local tmpresult=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -sS -o /dev/null -L --max-time 10 -w '%{url_effective}\n' "https://www.discoveryplus.com/" 2>&1)
    
    if [[ "${tmpresult}" == "curl"* ]]; then
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'Unknow'
        return
    fi
    
    local isBlocked=$(echo "${tmpresult}" | grep 'geo-not-available')
    local region=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -sS --max-time 10 "https://www.discoveryplus.com/de-DE" 2>&1 | grep 'country":' | sed 's/.*"country"://g' | cut -f1 -d',' | cut -f2 -d'"')
    
    if [ -n "$isBlocked" ] || [[ "${region}" == "null" ]]; then
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'No'
        return
    elif [ -n "$region" ]; then
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'Yes' "${region}"
        return
    else
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'Yes'
        return
    fi
}

MediaUnlockTest_ParamountPlus() {
    testDNSAndSetXFF "paramount" "www.paramountplus.com"
    local tmpresult=$(curl $useNIC $usePROXY $useResolve $xForward -${1} --user-agent "${UA_Browser}" -sL --max-time 10 "https://www.paramountplus.com/" 2>&1)
    
    if [[ "$tmpresult" == "curl"* ]]; then
        echo -n -e "\r Paramount+:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'ParamountPlus_result' 'Unknow'
        return
    fi
    
    if [[ "$tmpresult" == *"geo-availability"* ]]; then
        echo -n -e "\r Paramount+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'ParamountPlus_result' 'No'
        return
    else
        local region=$(curl $useNIC $usePROXY $useResolve $xForward -${1} --user-agent "${UA_Browser}" -sI --max-time 10 "https://www.paramountplus.com/" 2>&1 | grep 'country' | cut -d'=' -f2 | tr -d '"' | tr '[:lower:]' '[:upper:]')
        echo -n -e "\r Paramount+:\t\t\t\t${Font_Green}Yes (Region: ${region:-US})${Font_Suffix}\n"
        modifyJsonTemplate 'ParamountPlus_result' 'Yes' "${region:-US}"
        return
    fi
}

MediaUnlockTest_BahamutAnime() {
    log "INFO" "正在检测 Bahamut Anime 解锁情况..."
    
    # 测试DNS和设置解析参数
    testDNSAndSetXFF "bahamut" "ani.gamer.com.tw"
    log "INFO" "使用的请求参数: useNIC=$useNIC, usePROXY=$usePROXY, useResolve=$useResolve, xForward=$xForward"
    
    # 创建临时 cookie 文件
    local cookie_file="/tmp/bahamut_cookie.txt"
    rm -f $cookie_file
    
    # 第一步：获取设备ID
    log "INFO" "开始获取设备ID..."
    local device_result=$(curl $useNIC $usePROXY $useResolve $xForward -${1} \
        --user-agent "${UA_Browser}" \
        -sL --max-time 10 \
        -c $cookie_file \
        "https://ani.gamer.com.tw/ajax/getdeviceid.php" 2>&1)
    
    log "DEBUG" "设备ID请求响应: ${device_result}"
    
    if [[ "$device_result" == "curl"* ]]; then
        log "ERROR" "获取设备ID失败，网络错误: ${device_result}"
        rm -f $cookie_file
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'Unknow'
        return
    fi
    
    local deviceid=$(echo "$device_result" | grep -o '"deviceid":"[^"]*"' | cut -d'"' -f4)
    if [[ -z "$deviceid" ]]; then
        log "ERROR" "无法获取设备ID"
        rm -f $cookie_file
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Red}Failed (Device ID Error)${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'Unknow'
        return
    fi
    
    log "INFO" "获取到设备ID: ${deviceid}"
    
    # 第二步：尝试获取视频令牌
    log "INFO" "开始获取视频令牌..."
    local sn="14667"  # 测试用的动画 ID
    local token_url="https://ani.gamer.com.tw/ajax/token.php?adID=89422&sn=${sn}&device=${deviceid}"
    log "DEBUG" "请求令牌URL: ${token_url}"
    
    local token_result=$(curl $useNIC $usePROXY $useResolve $xForward -${1} \
        --user-agent "${UA_Browser}" \
        -b $cookie_file \
        -sL --max-time 10 \
        "${token_url}" 2>&1)
    
    log "DEBUG" "视频令牌请求响应: ${token_result}"
    
    # 第三步：请求主页面获取地区信息
    log "INFO" "开始获取地区信息..."
    local main_result=$(curl $useNIC $usePROXY $useResolve $xForward -${1} \
        --user-agent "${UA_Browser}" \
        -b $cookie_file \
        -sL --max-time 10 \
        -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7" \
        -H "Accept-Language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7" \
        -H "Cache-Control: max-age=0" \
        "https://ani.gamer.com.tw/" 2>&1)
    
    # 清理 cookie 文件
    rm -f $cookie_file
    
    if [[ "$token_result" == "curl"* ]] || [[ "$main_result" == "curl"* ]]; then
        log "ERROR" "网络请求失败"
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'Unknow'
        return
    fi
    
    if [[ "$token_result" == *"error"* ]]; then
        local error_code=$(echo "$token_result" | grep -o '"code":[0-9]*' | cut -d':' -f2)
        local error_message=$(echo "$token_result" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        log "INFO" "Bahamut Anime 未解锁，错误代码: ${error_code}, 错误信息: ${error_message}"
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'No'
        return
    fi
    
    if [[ "$token_result" == *"animeSn"* ]] || [[ "$token_result" == *"sn"* ]]; then
        local region=$(echo "$main_result" | grep -o 'data-region="[^"]*"' | cut -d'"' -f2)
        [[ -z "$region" ]] && region="TW"
        log "INFO" "Bahamut Anime 解锁成功，区域: ${region}"
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'Yes' "${region}"
        return
    else
        log "INFO" "Bahamut Anime 未解锁，响应数据异常"
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'No'
        return
    fi
}

###
 # @Author: Vincent Young
 # @Date: 2023-02-09 17:39:59
 # @LastEditors: Vincent Young
 # @LastEditTime: 2023-02-15 20:54:40
 # @FilePath: /OpenAI-Checker/openai.sh
 # @Telegram: https://t.me/missuo
 #
 # Copyright © 2023 by Vincent, All Rights Reserved.
###

OpenAiUnlockTest()
{
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    PLAIN='\033[0m'
    BLUE="\033[36m"

    SUPPORT_COUNTRY=(AL DZ AD AO AG AR AM AU AT AZ BS BD BB BE BZ BJ BT BA BW BR BG BF CV CA CL CO KM CR HR CY DK DJ DM DO EC SV EE FJ FI FR GA GM GE DE GH GR GD GT GN GW GY HT HN HU IS IN ID IQ IE IL IT JM JP JO KZ KE KI KW KG LV LB LS LR LI LT LU MG MW MY MV ML MT MH MR MU MX MC MN ME MA MZ MM NA NR NP NL NZ NI NE NG MK NO OM PK PW PA PG PE PH PL PT QA RO RW KN LC VC WS SM ST SN RS SC SL SG SK SI SB ZA ES LK SR SE CH TH TG TO TT TN TR TV UG AE US UY VU ZM BO BN CG CZ VA FM MD PS KR TW TZ TL GB)
    echo
    echo -e "${BLUE}OpenAI Access Checker. Made by Vincent${PLAIN}"
    echo -e "${BLUE}https://github.com/missuo/OpenAI-Checker${PLAIN}"
    #echo "-------------------------------------"
    if [[ $(curl -sS https://chat.openai.com/ -I | grep "text/plain") != "" ]]
    then
        echo "Your IP is BLOCKED!"
    else
        #echo -e "[IPv4]"
        # check4=`ping 1.1.1.1 -c 1 2>&1`;
        # if [[ "$check4" != *"received"* ]] && [[ "$check4" != *"transmitted"* ]];then
        #     echo -e "\033[34mIPv4 is not supported on the current host. Skip...\033[0m";
        #     modifyJsonTemplate 'OpenAI_result' 'Unknow'
        # else
            # local_ipv4=$(curl -4 -s --max-time 10 api64.ipify.org)
            #local_ipv4=$(curl -4 -sS https://chat.openai.com/cdn-cgi/trace | grep "ip=" | awk -F= '{print $2}')
            #local_isp4=$(curl -s -4 --max-time 10  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv4}" | grep organization | cut -f4 -d '"')
            #local_asn4=$(curl -s -4 --max-time 10  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv4}" | grep asn | cut -f8 -d ',' | cut -f2 -d ':')
            #echo -e "${BLUE}Your IPv4: ${local_ipv4} - ${local_isp4}${PLAIN}"
            iso2_code4=$(curl -4 -sS https://chat.openai.com/cdn-cgi/trace | grep "loc=" | awk -F= '{print $2}')
            found=0
            for country in "${SUPPORT_COUNTRY[@]}"
            do
                if [[ "${country}" == "${iso2_code4}" ]];
                then
                    echo -e "${BLUE}Your IP supports access to OpenAI. Region: ${iso2_code4}${PLAIN}"
                    modifyJsonTemplate 'OpenAI_result' 'Yes' "${iso2_code4}"
                    found=1
                    break
                fi
            done

            if [[ $found -eq 0 ]];
            then
                echo -e "${RED}Region: ${iso2_code4}. Not support OpenAI at this time.${PLAIN}"
                modifyJsonTemplate 'OpenAI_result' 'No'
            fi
        # fi
    fi
}

###########################################
#                                         #
#   sspanel unlock check function code    #
#                                         #
###########################################

createJsonTemplate() {
    echo '{
    "YouTube": "YouTube_Premium_result",
    "Netflix": "Netflix_result",
    "DisneyPlus": "DisneyPlus_result",
    "DiscoveryPlus": "DiscoveryPlus_result",
    "ParamountPlus": "ParamountPlus_result",
    "BahamutAnime": "BahamutAnime_result",
    "OpenAI": "OpenAI_result"
}' > /root/media_test_tpl.json
}

modifyJsonTemplate() {
    key_word=$1
    result=$2
    region=$3

    # 检查文件是否存在，如果不存在则创建
    if [[ ! -f "/root/media_test_tpl.json" ]]; then
        createJsonTemplate
    fi

    if [[ "$3" == "" ]]; then
        sed -i "s#${key_word}#${result}#g" /root/media_test_tpl.json
    else
        sed -i "s#${key_word}#${result} (${region})#g" /root/media_test_tpl.json
    fi
}

setCronTask() {
    addTask() {
        execution_time_interval=$1
        execution_time_unit=$2

        crontab -l >/root/crontab.list 2>/dev/null
        if [[ "$execution_time_unit" == "minute" ]]; then
            echo "*/${execution_time_interval} * * * * /bin/bash /root/csm.sh -S" >>/root/crontab.list
            green "定时任务添加成功！每 ${execution_time_interval} 分钟自动执行一次检测"
        else
            echo "0 */${execution_time_interval} * * * /bin/bash /root/csm.sh -S" >>/root/crontab.list
            green "定时任务添加成功！每 ${execution_time_interval} 小时自动执行一次检测"
        fi
        crontab /root/crontab.list
        rm -rf /root/crontab.list
    }

    crontab -l | grep "csm.sh" >/dev/null
    if [[ "$?" != "0" ]]; then
        echo "设置自动检测任务"
        echo "----------------------------------------"
        echo "请选择检测频率："
        echo "[1] 每 1 分钟"
        echo "[2] 每 1 小时"
        echo "[3] 每 2 小时"
        echo "[4] 每 3 小时"
        echo "[5] 每 4 小时"
        echo "[6] 每 6 小时"
        echo "[7] 每 8 小时"
        echo "[8] 每 12 小时"
        echo "[9] 每 24 小时"
        echo "[0] 不设置定时任务"
        echo "----------------------------------------"
        echo
        read -p "请输入数字 [0-9]: " time_interval_id

        case "${time_interval_id}" in
            0)
                green "已跳过定时任务设置"
                return
                ;;
            1)
                addTask 1 "minute"
                ;;
            2)
                addTask 1 "hour"
                ;;
            3)
                addTask 2 "hour"
                ;;
            4)
                addTask 3 "hour"
                ;;
            5)
                addTask 4 "hour"
                ;;
            6)
                addTask 6 "hour"
                ;;
            7)
                addTask 8 "hour"
                ;;
            8)
                addTask 12 "hour"
                ;;
            9)
                addTask 24 "hour"
                ;;
            *)
                red "输入错误，请输入 0-9 之间的数字"
                exit 1
                ;;
        esac
    else
        yellow "定时任务已存在，无需修改请先手动删除"
        yellow "删除命令: crontab -l | grep -v csm.sh | crontab -"
    fi
}

checkConfig() {
    getConfig() {
        read -p "请输入面板地址 (例如: https://demo.sspanel.org): " panel_address
        read -p "请输入节点密钥 (mu_key): " mu_key
        read -p "请输入节点ID: " node_id

        if [[ "${panel_address}" = "" ]] || [[ "${mu_key}" = "" ]];then
            red "请填写所有必需的参数"
            exit
        fi

        curl -s "${panel_address}/mod_mu/nodes?key=${mu_key}" | grep "invalid" > /dev/null
        if [[ "$?" = "0" ]];then
            red "面板地址或密钥错误，请重新输入"
            exit
        fi

        echo "${panel_address}" > /root/.csm.config
        echo "${mu_key}" >> /root/.csm.config
        echo "${node_id}" >> /root/.csm.config
    }

    if [[ ! -e "/root/.csm.config" ]];then
        getConfig
    fi
}

postData() {
    if [[ ! -e "/root/.csm.config" ]];then
        echo -e "$(red) 缺少配置文件"
        exit
    fi
    if [[ ! -e "/root/media_test_tpl.json" ]];then
        echo -e "$(red) 缺少检测报告文件"
        exit
    fi

    panel_address=$(sed -n 1p /root/.csm.config)
    mu_key=$(sed -n 2p /root/.csm.config)
    node_id=$(sed -n 3p /root/.csm.config)

    # 检查文件是否为空
    if [[ ! -s "/root/media_test_tpl.json" ]]; then
        log "ERROR" "检测报告文件为空，重新创建"
        createJsonTemplate
        runCheck
    fi

    curl -s -X POST -d "content=$(cat /root/media_test_tpl.json | base64 | xargs echo -n | sed 's# ##g')" "${panel_address}/mod_mu/media/save_report?key=${mu_key}&node_id=${node_id}" > /root/.csm.response
    if [[ "$(cat /root/.csm.response)" != "ok" ]];then
        curl -s -X POST -d "content=$(cat /root/media_test_tpl.json | base64 | xargs echo -n | sed 's# ##g')" "${panel_address}/mod_mu/media/saveReport?key=${mu_key}&node_id=${node_id}" > /root/.csm.response
    fi

    rm -rf /root/media_test_tpl.json /root/.csm.response
}

printInfo() {
    green_start='\033[32m'
    color_end='\033[0m'

    echo
    echo -e "${green_start}流媒体解锁检测已完成${color_end}"
    echo -e "${green_start}日志文件路径：${LOG_FILE}${color_end}"
    if [[ -f "$UNLOCK_CONFIG_FILE" ]]; then
        echo -e "${green_start}DNS配置文件路径：${UNLOCK_CONFIG_FILE}${color_end}"
    fi
    echo
}

runCheck() {
    log "INFO" "开始执行流媒体解锁检测"
    # 确保在开始检测前创建模板文件
    createJsonTemplate
    MediaUnlockTest_Netflix 4
    MediaUnlockTest_DisneyPlus 4
    MediaUnlockTest_DiscoveryPlus 4
    MediaUnlockTest_ParamountPlus 4
    MediaUnlockTest_BahamutAnime 4
    OpenAiUnlockTest
    MediaUnlockTest_YouTube_Premium 4
    log "INFO" "流媒体解锁检测完成"
}

checkData() {
    counter=0
    max_check_num=3
    log "INFO" "开始检查数据完整性"
    
    # 检查文件是否存在
    if [[ ! -f "/root/media_test_tpl.json" ]]; then
        log "ERROR" "检测报告文件不存在，重新创建"
        createJsonTemplate
        runCheck
        return
    fi
    
    cat /root/media_test_tpl.json | grep "_result" > /dev/null
    until [ $? != '0' ]  || [[ ${counter} -ge ${max_check_num} ]]
    do
        sleep 1
        log "WARN" "数据异常，第 ${counter} 次重新检测"
        createJsonTemplate  # 重新创建模板
        runCheck > /dev/null
        echo -e "\033[33m数据异常，正在行第 ${counter} 次重新检测...${Font_Suffix}"
        counter=$(expr ${counter} + 1)
    done
    log "INFO" "数据完整性检查完成"
}

main() {
    echo
    log "INFO" "脚本开始执行"
    
    # 检查并创建日志目录
    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
        log "INFO" "创建日志文件"
    fi
    
    # 设置出时清理操作
    trap cleanup EXIT
    
    # 如果是仅配置模式
    if [[ "$CONFIG_ONLY" == "1" ]]; then
        rm -f "$UNLOCK_CONFIG_FILE"  # 删除现有配置
        configureUnlock  # 重新配置
        green "配置完成"
        exit 0
    fi
    
    checkOS
    checkCPU
    checkDependencies
    configureUnlock
    # 只在非跳过配置模式下设置定时任务
    if [[ "$SKIP_CONFIG" != "1" ]]; then
        setCronTask
    fi
    checkConfig
    runCheck
    checkData
    postData
    printInfo
    
    log "INFO" "脚本执行完成"
}

main
