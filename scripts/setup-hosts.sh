#!/bin/bash
# 配置本地 hosts 文件，支持域名访问微服务

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录并定位项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 配置文件路径
CONFIG_FILE="$PROJECT_ROOT/config.json"
HOSTS_FILE="/etc/hosts"

# 检查依赖
if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}错误: 缺少 jq，请先安装 (brew install jq)${NC}"
    exit 1
fi

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}错误: 找不到配置文件 $CONFIG_FILE${NC}"
    exit 1
fi

# 读取配置文件，提取并标准化所有域名（支持逗号分隔、支持 http/https 前缀）
DOMAINS=$(jq -r '
  [
    (.go_services // {} | to_entries[]? | .value.domain // empty),
    (.frontend_services // {} | to_entries[]? | .value.domain // empty)
  ]
  | .[]
' "$CONFIG_FILE" \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | sed 's#^http://##' \
    | sed 's#^https://##' \
    | sed 's#/.*$##' \
    | sed 's/:.*$//' \
    | sed '/^$/d' \
    | sort -u)

if [ -z "$DOMAINS" ]; then
    echo -e "${YELLOW}没有找到配置的域名${NC}"
    exit 0
fi

# 检查是否有 sudo 权限
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo -e "${YELLOW}需要 sudo 权限来修改 /etc/hosts${NC}"
    echo "请输入密码以继续："
    exec sudo bash "$0" "$@"
fi

# 显示标题（在获取 sudo 权限后）
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}配置本地域名解析${NC}"
echo -e "${BLUE}======================================${NC}"

# 显示将要添加的域名
echo -e "${YELLOW}发现以下域名配置：${NC}"
echo "$DOMAINS" | while read -r domain; do
    echo "  - $domain"
done

# 检查是否已经存在 Tilt 域名配置的标记
MARKER_START="# Tilt domains start"
MARKER_END="# Tilt domains end"

if grep -q "$MARKER_START" "$HOSTS_FILE"; then
    echo -e "${YELLOW}检测到已存在的 Tilt 域名配置，将先删除旧配置${NC}"
    # 删除旧的配置
    sudo sed -i.temp "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE"
    rm -f "$HOSTS_FILE.temp"
fi

# 添加新的域名配置
echo "" | sudo tee -a "$HOSTS_FILE" > /dev/null
echo "$MARKER_START" | sudo tee -a "$HOSTS_FILE" > /dev/null
echo "# Tilt 微服务域名配置 - 添加于 $(date)" | sudo tee -a "$HOSTS_FILE" > /dev/null
echo "127.0.0.1 localhost" | sudo tee -a "$HOSTS_FILE" > /dev/null

echo "$DOMAINS" | while read -r domain; do
    if [ -n "$domain" ]; then
        echo "127.0.0.1 $domain" | sudo tee -a "$HOSTS_FILE" > /dev/null
        echo -e "${GREEN}✓ 添加域名: $domain${NC}"
    fi
done

echo "$MARKER_END" | sudo tee -a "$HOSTS_FILE" > /dev/null

echo ""
echo -e "${GREEN}✅ 配置完成！${NC}"

# 清除 DNS 缓存（macOS）
echo ""
echo -e "${YELLOW}清除 DNS 缓存...${NC}"
case "$(sw_vers -productVersion | cut -d. -f1)" in
    12|13|14|15)
        # macOS Monterey (12) 及更新版本
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder
        ;;
    *)
        # 早期 macOS 版本
        sudo killall -HUP mDNSResponder
        ;;
esac
echo -e "${GREEN}✓ DNS 缓存已清除${NC}"

echo ""
echo -e "${BLUE}现在可以通过以下域名访问服务：${NC}"
echo "$DOMAINS" | while read -r domain; do
    echo "  - http://$domain"
done

echo ""
echo -e "${YELLOW}测试域名解析：${NC}"
echo "$DOMAINS" | while read -r domain; do
    if [ -n "$domain" ]; then
        # 使用 grep 检查 ping 输出中是否包含 127.0.0.1
        if ping -c 1 -W 1 "$domain" 2>/dev/null | grep -q "127.0.0.1"; then
            echo -e "  ${GREEN}✓${NC} $domain -> 127.0.0.1"
        else
            echo -e "  ${RED}✗${NC} $domain 解析失败"
        fi
    fi
done
