#!/bin/bash

# 创建基础 DNS 配置
cat > /tmp/dns_config.json << EOF
{
  "servers": [
    "1.1.1.1",
    "8.8.8.8",
    "localhost"
  ],
  "tag": "dns_inbound"
}
EOF

# 定义服务数组
declare -A services=(
    ["Netflix"]="unlock1.afeicloud.de|geosite:netflix"
    ["Disney+"]="unlock1.afeicloud.de|geosite:disneyg"
    ["巴哈姆特动画疯"]="unlock1.afeicloud.de|geosite:bahamut"
    ["Paramount+"]="unlock2.afeicloud.de|geosite:cbs"
    ["OpenAI"]="unlock2.afeicloud.de|geosite:openai"
    ["Discovery+"]="unlock2.afeicloud.de|geosite:discoveryplus"
)

# 临时文件用于构建 JSON
temp_file="/tmp/dns_config.json"

# 遍历服务并询问
for service in "${!services[@]}"; do
    IFS='|' read -r server geosite <<< "${services[$service]}"
    
    read -p "是否添加 $service 解锁支持？(y/n): " answer
    if [ "${answer,,}" = "y" ]; then
        # 使用 jq 添加新的服务器配置
        jq --arg server "$server" \
           --arg geosite "$geosite" \
           '.servers += [{
               "address": $server,
               "port": 53,
               "domains": [$geosite]
           }]' "$temp_file" > "$temp_file.tmp" && mv "$temp_file.tmp" "$temp_file"
        
        echo "已添加 $service 解锁支持"
    fi
done

# 创建目录并移动配置文件
mkdir -p /etc/XrayR
mv "$temp_file" /etc/XrayR/dns.json

echo "配置已保存到 /etc/XrayR/dns.json"

# 显示最终配置内容
echo "当前配置内容："
cat /etc/XrayR/dns.json 