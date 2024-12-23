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

blue() {
    echo -e "\033[34m$1\033[0m"
}

green() {
    echo -e "\033[32m$1\033[0m"
}

red() {
    echo -e "\034[31m$1\033[0m"
}

yellow() {
    echo -e "\033[33m$1\033[0m"
}

while getopts ":I:M:EX:P:" optname; do
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

MediaUnlockTest_BBCiPLAYER() {
    local tmpresult=$(curl $useNIC $usePROXY $xForward --user-agent "${UA_Browser}" -${1} ${ssll} -fsL --max-time 10 "https://open.live.bbc.co.uk/mediaselector/6/select/version/2.0/mediaset/pc/vpid/bbc_one_london/format/json/jsfunc/JS_callbacks0" 2>&1)
    if [ "${tmpresult}" = "000" ]; then
        echo -n -e "\r BBC iPLAYER:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    if [ -n "$tmpresult" ]; then
        result=$(echo $tmpresult | grep 'geolocation')
        if [ -n "$result" ]; then
            echo -n -e "\r BBC iPLAYER:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
            modifyJsonTemplate 'BBC_result' 'No'
        else
            echo -n -e "\r BBC iPLAYER:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
            modifyJsonTemplate 'BBC_result' 'Yes'
        fi
    else
        echo -n -e "\r BBC iPLAYER:\t\t\t\t${Font_Red}Failed${Font_Suffix}\n"
        modifyJsonTemplate 'BBC_result' 'Unknow'
    fi
}

MediaUnlockTest_MyTVSuper() {
    local result=$(curl $useNIC $usePROXY $xForward -s -${1} --max-time 10 "https://www.mytvsuper.com/api/auth/getSession/self/" 2>&1 | python -m json.tool 2>/dev/null | grep 'region' | awk '{print $2}')

    if [[ "$result" == "1" ]]; then
        echo -n -e "\r MyTVSuper:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        modifyJsonTemplate 'MyTVSuper_result' 'Yes'
        return
    else
        echo -n -e "\r MyTVSuper:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'MyTVSuper_result' 'No'
        return
    fi

    echo -n -e "\r MyTVSuper:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
    modifyJsonTemplate 'MyTVSuper_result' 'Unknow'
    return

}

MediaUnlockTest_BilibiliHKMCTW() {
    local randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)"
    # 尝试获取成功的结果
    local result=$(curl $useNIC $usePROXY $xForward --user-agent "${UA_Browser}" -${1} -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=18281381&cid=29892777&qn=0&type=&otype=json&ep_id=183799&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1)
    if [[ "$result" != "curl"* ]]; then
        local result="$(echo "${result}" | python -m json.tool 2>/dev/null | grep '"code"' | head -1 | awk '{print $2}' | cut -d ',' -f1)"
        if [ "${result}" = "0" ]; then
            echo -n -e "\r BiliBili Hongkong/Macau/Taiwan:\t${Font_Green}Yes${Font_Suffix}\n"
            modifyJsonTemplate 'BilibiliHKMCTW_result' 'Yes'
        elif [ "${result}" = "-10403" ]; then
            echo -n -e "\r BiliBili Hongkong/Macau/Taiwan:\t${Font_Red}No${Font_Suffix}\n"
            modifyJsonTemplate 'BilibiliHKMCTW_result' 'No'
        else
            echo -n -e "\r BiliBili Hongkong/Macau/Taiwan:\t${Font_Red}Failed${Font_Suffix} ${Font_SkyBlue}(${result})${Font_Suffix}\n"
            modifyJsonTemplate 'BilibiliHKMCTW_result' 'Unknow'
        fi
    else
        echo -n -e "\r BiliBili Hongkong/Macau/Taiwan:\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'BilibiliHKMCTW_result' 'Unknow'
    fi
}

MediaUnlockTest_BilibiliTW() {
    local randsession="$(cat /dev/urandom | head -n 32 | md5sum | head -c 32)"
    # 尝试获取成功的结果
    local result=$(curl $useNIC $usePROXY $xForward --user-agent "${UA_Browser}" -${1} -fsSL --max-time 10 "https://api.bilibili.com/pgc/player/web/playurl?avid=50762638&cid=100279344&qn=0&type=&otype=json&ep_id=268176&fourk=1&fnver=0&fnval=16&session=${randsession}&module=bangumi" 2>&1)
    if [[ "$result" != "curl"* ]]; then
        local result="$(echo "${result}" | python -m json.tool 2>/dev/null | grep '"code"' | head -1 | awk '{print $2}' | cut -d ',' -f1)"
        if [ "${result}" = "0" ]; then
            echo -n -e "\r Bilibili Taiwan Only:\t\t\t${Font_Green}Yes${Font_Suffix}\n"
            modifyJsonTemplate 'BilibiliTW_result' 'Yes'
        elif [ "${result}" = "-10403" ]; then
            echo -n -e "\r Bilibili Taiwan Only:\t\t\t${Font_Red}No${Font_Suffix}\n"
            modifyJsonTemplate 'BilibiliTW_result' 'No'
        else
            echo -n -e "\r Bilibili Taiwan Only:\t\t\t${Font_Red}Failed${Font_Suffix} ${Font_SkyBlue}(${result})${Font_Suffix}\n"
            modifyJsonTemplate 'BilibiliTW_result' 'Unknow'
        fi
    else
        echo -n -e "\r Bilibili Taiwan Only:\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'BilibiliTW_result' 'Unknow'
    fi
}

MediaUnlockTest_AbemaTV_IPTest() {
    #
    local tempresult=$(curl $useNIC $usePROXY $xForward --user-agent "${UA_Dalvik}" -${1} -fsL --write-out %{http_code} --max-time 10 "https://api.abema.io/v1/ip/check?device=android" 2>&1)
    if [[ "$tempresult" == "000" ]]; then
        echo -n -e "\r Abema.TV:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        return
    fi

    result=$(curl $useNIC $usePROXY $xForward --user-agent "${UA_Dalvik}" -${1} -fsL --max-time 10 "https://api.abema.io/v1/ip/check?device=android" 2>&1 | python -m json.tool 2>/dev/null | grep isoCountryCode | awk '{print $2}' | cut -f2 -d'"')
    if [ -n "$result" ]; then
        if [[ "$result" == "JP" ]]; then
            echo -n -e "\r Abema.TV:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
            modifyJsonTemplate 'AbemaTV_result' 'Yes'
        else
            echo -n -e "\r Abema.TV:\t\t\t\t${Font_Yellow}Oversea Only${Font_Suffix}\n"
            modifyJsonTemplate 'AbemaTV_result' 'Yes' 'Oversea Only'
        fi
    else
        echo -n -e "\r Abema.TV:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'AbemaTV_result' 'No'
    fi
}

MediaUnlockTest_Netflix() {
    local result1=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://www.netflix.com/title/81280792" 2>&1)

    if [[ "$result1" == "404" ]]; then
        modifyJsonTemplate 'Netflix_result' 'No' 'Originals Only'
        echo -n -e "\r Netflix:\t\t\t\t${Font_Yellow}Originals Only${Font_Suffix}\n"
        return
    elif [[ "$result1" == "403" ]]; then
        echo -n -e "\r Netflix:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'Netflix_result' 'No'
        return
    elif [[ "$result1" == "200" ]]; then
        local region=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -fs --max-time 10 --write-out %{redirect_url} --output /dev/null "https://www.netflix.com/title/80018499" 2>&1 | cut -d '/' -f4 | cut -d '-' -f1 | tr [:lower:] [:upper:])
        if [[ ! -n "$region" ]]; then
            region="US"
        fi
        echo -n -e "\r Netflix:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        modifyJsonTemplate 'Netflix_result' 'Yes' "${region}"
        return
    elif [[ "$result1" == "000" ]]; then
        echo -n -e "\r Netflix:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'Netflix_result' 'Unknow'
        return
    fi
}

MediaUnlockTest_DisneyPlus() {
    local PreAssertion=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/devices" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -H "content-type: application/json; charset=UTF-8" -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' 2>&1)
    if [[ "$PreAssertion" == "curl"* ]] && [[ "$1" == "6" ]]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}IPv6 Not Support${Font_Suffix}\n"
        return
    elif [[ "$PreAssertion" == "curl"* ]]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'Unknow'
        return
    fi

    local assertion=$(echo $PreAssertion | python -m json.tool 2>/dev/null | grep assertion | cut -f4 -d'"')
    local PreDisneyCookie=$(echo "$Media_Cookie" | sed -n '1p')
    local disneycookie=$(echo $PreDisneyCookie | sed "s/DISNEYASSERTION/${assertion}/g")
    local TokenContent=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -s --max-time 10 -X POST "https://disney.api.edge.bamgrid.com/token" -H "authorization: Bearer ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycookie" 2>&1)
    local isBanned=$(echo $TokenContent | python -m json.tool 2>/dev/null | grep 'forbidden-location')
    local is403=$(echo $TokenContent | grep '403 ERROR')

    if [ -n "$isBanned" ] || [ -n "$is403" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        return
    fi

    local fakecontent=$(echo "$Media_Cookie" | sed -n '8p')
    local refreshToken=$(echo $TokenContent | python -m json.tool 2>/dev/null | grep 'refresh_token' | awk '{print $2}' | cut -f2 -d'"')
    local disneycontent=$(echo $fakecontent | sed "s/ILOVEDISNEY/${refreshToken}/g")
    local tmpresult=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -X POST -sSL --max-time 10 "https://disney.api.edge.bamgrid.com/graph/v1/device/graphql" -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" -d "$disneycontent" 2>&1)
    local previewcheck=$(curl $useNIC $usePROXY $xForward -${1} -s -o /dev/null -L --max-time 10 -w '%{url_effective}\n' "https://disneyplus.com" | grep preview)
    local isUnabailable=$(echo $previewcheck | grep 'unavailable')
    local region=$(echo $tmpresult | python -m json.tool 2>/dev/null | grep 'countryCode' | cut -f4 -d'"')
    local inSupportedLocation=$(echo $tmpresult | python -m json.tool 2>/dev/null | grep 'inSupportedLocation' | awk '{print $2}' | cut -f1 -d',')

    if [[ "$region" == "JP" ]]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Green}Yes (Region: JP)${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'Yes' 'JP'
        return
    elif [ -n "$region" ] && [[ "$inSupportedLocation" == "false" ]] && [ -z "$isUnabailable" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Yellow}Available For [Disney+ $region] Soon${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        return
    elif [ -n "$region" ] && [ -n "$isUnavailable" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        return
    elif [ -n "$region" ] && [[ "$inSupportedLocation" == "true" ]]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Green}Yes (Region: $region)${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'Yes' "${region}"
        return
    elif [ -z "$region" ]; then
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'No'
        return
    else
        echo -n -e "\r Disney+:\t\t\t\t${Font_Red}Failed${Font_Suffix}\n"
        modifyJsonTemplate 'DisneyPlus_result' 'Unknow'
        return
    fi

}

MediaUnlockTest_YouTube_Premium() {
    local tmpresult=$(curl $useNIC $usePROXY $xForward --user-agent "${UA_Browser}" -${1} --max-time 10 -sSL -H "Accept-Language: en" -b "YSC=BiCUU3-5Gdk; CONSENT=YES+cb.20220301-11-p0.en+FX+700; GPS=1; VISITOR_INFO1_LIVE=4VwPMkB7W5A; PREF=tz=Asia.Shanghai; _gcl_au=1.1.1809531354.1646633279" "https://www.youtube.com/premium" 2>&1)

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
    # 等待DNS生效
    sleep 3
    
    # 先尝试解析域名
    local dns_result=$(dig +short discoveryplus.com)
    if [ -z "$dns_result" ]; then
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Red}Failed (DNS Resolution)${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'Unknow'
        return
    }

    # 使用多个检测点
    local tmpresult1=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -sL --max-time 10 "https://us.discoveryplus.com/")
    local tmpresult2=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -sL --max-time 10 "https://www.discoveryplus.com/")
    
    if [ -z "$tmpresult1" ] && [ -z "$tmpresult2" ]; then
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'Unknow'
        return
    fi

    local tmpresult="$tmpresult1$tmpresult2"
    
    # 检查是否被阻止
    local isBlocked=$(echo "$tmpresult" | grep -i 'unavailable-in-your-region\|not-available-in-your-region\|geo-restriction\|page-not-available\|region-blocked')
    if [ -n "$isBlocked" ]; then
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'No'
        return
    fi

    # 检查区域信息
    local region=$(echo "$tmpresult" | grep -oE '"region":\s*"[A-Z]{2}"' | cut -d'"' -f4)
    if [ -n "$region" ]; then
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Green}Yes (Region: ${region})${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'Yes' "${region}"
        return
    fi

    # 检查是否有 Discovery+ 特征内容
    if echo "$tmpresult" | grep -qi 'discovery+\|discoveryplus\|dplus'; then
        echo -n -e "\r Discovery+:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        modifyJsonTemplate 'DiscoveryPlus_result' 'Yes'
        return
    fi

    echo -n -e "\r Discovery+:\t\t\t\t${Font_Red}Failed (Unknown)${Font_Suffix}\n"
    modifyJsonTemplate 'DiscoveryPlus_result' 'Unknow'
}

MediaUnlockTest_ParamountPlus() {
    local result=$(curl $useNIC $usePROXY $xForward -${1} ${ssll} -s -o /dev/null -L --max-time 10 -w '%{url_effective}\n' "https://www.paramountplus.com/" 2>&1 | grep 'intl')

    if [ -n "$result" ]; then
        echo -n -e "\r Paramount+:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'ParamountPlus_result' 'No'
        return
    elif [ -z "$result" ]; then
        echo -n -e "\r Paramount+:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        modifyJsonTemplate 'ParamountPlus_result' 'Yes'
        return
    fi

    echo -n -e "\r Paramount+:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
    modifyJsonTemplate 'ParamountPlus_result' 'Unknow'
    return
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

MediaUnlockTest_BahamutAnime() {
    local result=$(curl $useNIC $usePROXY $xForward -${1} --user-agent "${UA_Browser}" -fsL --write-out %{http_code} --output /dev/null --max-time 10 "https://ani.gamer.com.tw/ajax/token.php?adID=89422&sn=14667" 2>&1)
    
    if [[ "$result" == "000" ]]; then
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Red}Failed (Network Connection)${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'Unknow'
        return
    fi
    
    if [[ "$result" == "403" ]]; then
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Red}No${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'No'
        return
    elif [[ "$result" == "200" ]]; then
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Green}Yes${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'Yes'
        return
    else
        echo -n -e "\r Bahamut Anime:\t\t\t\t${Font_Red}Failed (Unexpected Result: $result)${Font_Suffix}\n"
        modifyJsonTemplate 'BahamutAnime_result' 'Unknow'
        return
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
    "OpenAI": "OpenAI_result",
    "DiscoveryPlus": "DiscoveryPlus_result",
    "ParamountPlus": "ParamountPlus_result",
    "BahamutAnime": "BahamutAnime_result"
}' > /root/media_test_tpl.json
}

modifyJsonTemplate() {
    key_word=$1
    result=$2
    region=$3

    if [[ "$3" == "" ]]; then
        sed -i "s#${key_word}#${result}#g" /root/media_test_tpl.json
    else
        sed -i "s#${key_word}#${result} (${region})#g" /root/media_test_tpl.json
    fi
}

main() {
    echo
    checkOS
    checkCPU
    checkDependencies
    checkConfig
    getDNSConfig
    runCheck
    checkData
    setCronTask
    postData
    restoreDNS
    printInfo
}

setCronTask() {
    while true; do
        echo -e "$(green) 是否设置定时检测任务?"
        echo "[1] 1小时"
        echo "[2] 2小时"
        echo "[3] 3小时"
        echo "[4] 4小时"
        echo "[5] 6小时"
        echo "[6] 8小时"
        echo "[7] 12小时"
        echo "[8] 24小时"
        echo
        read -p "$(blue) 请选择检测频率并输入序号 (例如: 1):" time_interval_id

        # 检查是否为空输入
        if [[ -z "${time_interval_id}" ]]; then
            echo -e "$(red) 输入不能为空，请输入1-8之间的数字"
            continue
        fi

        if ! [[ "${time_interval_id}" =~ ^[1-8]$ ]]; then
            echo -e "$(red) 输入错误，请输入1-8之间的数字"
            continue
        fi

        # 检查是否已经存在定时任务
        existing_task=$(crontab -l 2>/dev/null | grep "csm.sh" || true)
        
        # 如果已存在定时任务，询问是否覆盖
        if [[ -n "${existing_task}" ]]; then
            echo -e "$(yellow) 检测到已存在定时任务，是否覆盖?"
            read -p "$(blue) 请输入 y 确认覆盖，输入其他则跳过:" confirm
            if [[ "${confirm}" != "y" ]]; then
                echo -e "$(green) 保留现有定时任务，跳过设置"
                return
            fi
        fi

        # 下载脚本文件
        if [[ ! -f "/root/csm.sh" ]]; then
            echo -e "$(green) 正在下载脚本到 /root/csm.sh 用于定时任务..."
            curl -Ls https://raw.githubusercontent.com/q42602736/check-stream-media/main/csm.sh -o /root/csm.sh
            chmod +x /root/csm.sh
        fi

        if [[ "${time_interval_id}" == "5" ]];then
            time_interval=6
        elif [[ "${time_interval_id}" == "6" ]];then
            time_interval=8
        elif [[ "${time_interval_id}" == "7" ]];then
            time_interval=12
        elif [[ "${time_interval_id}" == "8" ]];then
            time_interval=24
        else
            time_interval=$time_interval_id
        fi

        # 创建新的crontab文件
        touch /root/crontab.list
        
        # 如果存在现有的crontab，则保存到文件中
        crontab -l >/root/crontab.list 2>/dev/null || true
        
        # 添加完整路径和日志输出
        echo "0 */${time_interval} * * * export CRONRUN=1; /bin/bash /root/csm.sh > /root/csm.log 2>&1" >>/root/crontab.list
        
        # 安装新的crontab
        crontab /root/crontab.list
        
        # 清理临时文件
        rm -f /root/crontab.list
        
        echo -e "$(green) 定时任务添加成功"
        echo -e "$(green) 您可以在 /root/csm.log 查看日志"
        break
    done
}

checkConfig() {
    getConfig() {
        read -p "$(blue) 请输入面板地址 (例如: https://demo.sspanel.org):" panel_address
        read -p "$(blue) 请输入mu key:" mu_key
        read -p "$(blue) 请输入节点ID:" node_id

        if [[ "${panel_address}" = "" ]] || [[ "${mu_key}" = "" ]];then
            echo -e "$(red) 请完成所有必要的参数输入"
            exit
        fi

        curl -s "${panel_address}/mod_mu/nodes?key=${mu_key}" | grep "invalid" > /dev/null
        if [[ "$?" = "0" ]];then
            echo -e "$(red) 网站地址或mukey错误，请重试"
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
        echo -e "$(red) 配置文件丢失"
        exit
    fi
    if [[ ! -e "/root/media_test_tpl.json" ]];then
        echo -e "$(red) 检测报告丢失"
        exit
    fi

    panel_address=$(sed -n 1p /root/.csm.config)
    mu_key=$(sed -n 2p /root/.csm.config)
    node_id=$(sed -n 3p /root/.csm.config)

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
    echo -e "${green_start}本脚本用于检测流媒体解锁的代码全部来自开源项目 https://github.com/lmc999/RegionRestrictionCheck，开源协议为 AGPL-3.0。按照开源许可要求，本脚本同样开源。感谢原作者 @lmc999 以及为该项目提交 pull request 的所有人的贡献。${color_end}"
    echo
    echo -e "${green_start}项目地址: https://github.com/iamsaltedfish/check-stream-media${color_end}"
    echo -e "${green_start}版本: 2023-08-07 v.2.0.1${color_end}"
    echo -e "${green_start}作者: @iamsaltedfish${color_end}"
}

# 在文件开头添加 UUID 生成函数
gen_uuid() {
    od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
}

getDNSConfig() {
    # 检查是否是定时任务运行
    if [[ -n "${CRONRUN}" ]]; then
        echo -e "$(green) 正在以定时任务方式运行，检查已保存的DNS配置..."
        for service in netflix disney youtube openai discovery paramount bahamut; do
            if [[ -f "/root/.csm.dns.${service}" ]]; then
                dns_server=$(cat "/root/.csm.dns.${service}")
                if [[ -n "${dns_server}" ]]; then
                    echo -e "$(green) 使用已保存的${service}的DNS服务器: ${dns_server}"
                fi
            fi
        done
        return
    fi

    # 询问各个服务的DNS
    read -p "$(blue "请输入用于Netflix解锁检测的DNS服务器地址 (直接回车使用系统默认DNS): ")" netflix_dns
    if [[ -n "${netflix_dns}" ]]; then
        echo "${netflix_dns}" > /root/.csm.dns.netflix
        echo -e "$(green) Netflix DNS服务器已设置为: ${netflix_dns}"
    else
        echo -e "$(green) Netflix检测将使用系统默认DNS服务器"
        rm -f /root/.csm.dns.netflix
    fi

    read -p "$(blue "请输入用于Disney+解锁检测的DNS服务器地址 (直接回车使用系统默认DNS): ")" disney_dns
    if [[ -n "${disney_dns}" ]]; then
        echo "${disney_dns}" > /root/.csm.dns.disney
        echo -e "$(green) Disney+ DNS服务器已设置为: ${disney_dns}"
    else
        echo -e "$(green) Disney+检测将使用系统默认DNS服务器"
        rm -f /root/.csm.dns.disney
    fi

    read -p "$(blue "请输入用于YouTube Premium解锁检测的DNS服务器地址 (直接回车使用系统默认DNS): ")" youtube_dns
    if [[ -n "${youtube_dns}" ]]; then
        echo "${youtube_dns}" > /root/.csm.dns.youtube
        echo -e "$(green) YouTube Premium DNS服务器已设置为: ${youtube_dns}"
    else
        echo -e "$(green) YouTube Premium检测将使用系统默认DNS服务器"
        rm -f /root/.csm.dns.youtube
    fi

    read -p "$(blue "请输入用于OpenAI解锁检测的DNS服务器地址 (直接回车使用系统默认DNS): ")" openai_dns
    if [[ -n "${openai_dns}" ]]; then
        echo "${openai_dns}" > /root/.csm.dns.openai
        echo -e "$(green) OpenAI DNS服务器已设置为: ${openai_dns}"
    else
        echo -e "$(green) OpenAI检测将使用系统默认DNS服务器"
        rm -f /root/.csm.dns.openai
    fi

    read -p "$(blue "请输入用于Discovery+解锁检测的DNS服务器地址 (直接回车使用系统默认DNS): ")" discovery_dns
    if [[ -n "${discovery_dns}" ]]; then
        echo "${discovery_dns}" > /root/.csm.dns.discovery
        echo -e "$(green) Discovery+ DNS服务器已设置为: ${discovery_dns}"
    else
        echo -e "$(green) Discovery+检测将使用系统默认DNS服务器"
        rm -f /root/.csm.dns.discovery
    fi

    read -p "$(blue "请输入用于Paramount+解锁检测的DNS服务器地址 (直接回车使用系统默认DNS): ")" paramount_dns
    if [[ -n "${paramount_dns}" ]]; then
        echo "${paramount_dns}" > /root/.csm.dns.paramount
        echo -e "$(green) Paramount+ DNS服务器已设置为: ${paramount_dns}"
    else
        echo -e "$(green) Paramount+检测将使用系统默认DNS服务器"
        rm -f /root/.csm.dns.paramount
    fi

    read -p "$(blue "请输入用于巴哈姆特动画疯解锁检测的DNS服务器地址 (直接回车使用系统默认DNS): ")" bahamut_dns
    if [[ -n "${bahamut_dns}" ]]; then
        echo "${bahamut_dns}" > /root/.csm.dns.bahamut
        echo -e "$(green) 巴哈姆特动画疯 DNS服务器已设置为: ${bahamut_dns}"
    else
        echo -e "$(green) 巴哈姆特动画疯检测将使用系统默认DNS服务器"
        rm -f /root/.csm.dns.bahamut
    fi
}

setDNSForTest() {
    local service=$1
    
    # 保存当前DNS配置
    cp /etc/resolv.conf /etc/resolv.conf.backup

    # 根据服务设置相应的DNS
    if [[ -f "/root/.csm.dns.${service}" ]]; then
        dns_server=$(cat "/root/.csm.dns.${service}")
        if [[ -n "${dns_server}" ]]; then
            echo -e "$(green) 正在为 ${service} 设置DNS: ${dns_server}"
            echo "nameserver ${dns_server}" > /etc/resolv.conf
        fi
    fi
}

restoreDNS() {
    if [[ -f "/etc/resolv.conf.backup" ]]; then
        mv /etc/resolv.conf.backup /etc/resolv.conf
    fi
}

runCheck() {
    createJsonTemplate
    
    # OpenAI检测
    setDNSForTest "openai"
    OpenAiUnlockTest
    restoreDNS
    
    # Netflix检测
    setDNSForTest "netflix"
    MediaUnlockTest_Netflix 4
    restoreDNS
    
    # Disney+检测
    setDNSForTest "disney"
    MediaUnlockTest_DisneyPlus 4
    restoreDNS
    
    # YouTube Premium检测
    setDNSForTest "youtube"
    MediaUnlockTest_YouTube_Premium 4
    restoreDNS

    # Discovery+检测
    setDNSForTest "discovery"
    MediaUnlockTest_DiscoveryPlus 4
    restoreDNS

    # Paramount+检测
    setDNSForTest "paramount"
    MediaUnlockTest_ParamountPlus 4
    restoreDNS

    # 巴哈姆特动画疯检测
    setDNSForTest "bahamut"
    MediaUnlockTest_BahamutAnime 4
    restoreDNS
}

checkData() {
    counter=0
    max_check_num=3
    cat /root/media_test_tpl.json | grep "_result" > /dev/null
    until [ $? != '0' ]  || [[ ${counter} -ge ${max_check_num} ]]
    do
        sleep 1
        runCheck > /dev/null
        echo -e "\033[33m数据有误，正在第 ${counter} 次重新测试...${Font_Suffix}"
        counter=$(expr ${counter} + 1)
    done
}

main
