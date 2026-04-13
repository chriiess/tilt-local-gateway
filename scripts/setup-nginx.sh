#!/bin/bash
# 配置 sudoers 以允许 nginx 无密码运行
# 只需要运行一次

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}配置 Nginx 监听端口 80${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# 获取当前用户名
CURRENT_USER=$(whoami)
SUDOERS_D_FILE="/etc/sudoers.d/tilt-nginx-${CURRENT_USER}"

# 查找 nginx 路径
NGINX_PATH=$(which nginx 2>/dev/null || echo "")

if [ -z "$NGINX_PATH" ]; then
    # 尝试常见位置
    for path in /usr/local/bin/nginx /usr/bin/nginx /opt/homebrew/bin/nginx; do
        if [ -x "$path" ]; then
            NGINX_PATH="$path"
            break
        fi
    done
fi

if [ -z "$NGINX_PATH" ]; then
    echo -e "${RED}错误: 找不到 nginx${NC}"
    echo "请先安装 nginx: brew install nginx"
    exit 1
fi

echo -e "${GREEN}找到 nginx: $NGINX_PATH${NC}"
echo -e "${GREEN}当前用户: $CURRENT_USER${NC}"
echo ""

# 检查是否已经配置
if [ -f "$SUDOERS_D_FILE" ] && sudo grep -q "$CURRENT_USER.*$NGINX_PATH" "$SUDOERS_D_FILE" 2>/dev/null; then
    echo -e "${YELLOW}sudoers 已经配置过 nginx 无密码权限${NC}"
    echo "无需重复配置"
    exit 0
fi

# 需要 sudo 权限来修改 sudoers
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}需要 sudo 权限来配置 sudoers${NC}"
    echo "请输入密码以继续："
    echo ""
fi

# 创建临时 sudoers 文件
TEMP_SUDOERS=$(mktemp)
echo -e "${YELLOW}正在配置 sudoers...${NC}"

# 添加 sudoers 规则到临时文件
echo "# Tilt nginx 配置 - 添加于 $(date)" > "$TEMP_SUDOERS"
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: $NGINX_PATH" >> "$TEMP_SUDOERS"

# 验证 sudoers 语法
if ! sudo visudo -c -f "$TEMP_SUDOERS" 2>/dev/null; then
    echo -e "${RED}✗ sudoers 语法验证失败${NC}"
    rm -f "$TEMP_SUDOERS"
    exit 1
fi

# 添加到 /etc/sudoers.d
echo ""
echo -e "${YELLOW}将以下内容写入 $SUDOERS_D_FILE：${NC}"
cat "$TEMP_SUDOERS"
echo ""

# 使用 sudoers.d 安全地添加配置
if ! sudo install -m 440 "$TEMP_SUDOERS" "$SUDOERS_D_FILE"; then
    echo -e "${RED}✗ 配置 sudoers 失败${NC}"
    rm -f "$TEMP_SUDOERS"
    exit 1
fi

# 清理临时文件
rm -f "$TEMP_SUDOERS"

echo -e "${GREEN}✓ sudoers 配置成功！${NC}"
echo ""
echo -e "${BLUE}现在 nginx 可以使用 sudo 运行，无需输入密码${NC}"
echo ""
echo -e "${YELLOW}验证：${NC}"
sudo grep "$CURRENT_USER.*$NGINX_PATH" "$SUDOERS_D_FILE" || echo "  配置已添加"
echo ""
echo -e "${GREEN}配置完成！现在可以运行 ./devmesh up 启动服务${NC}"
echo ""
echo -e "${YELLOW}如需删除配置，请运行：${NC}"
echo "  sudo rm -f \"$SUDOERS_D_FILE\""
