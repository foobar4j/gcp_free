#!/bin/bash

# ==============================================================================
#
#          一键初始化Google Cloud (GCP) 等云服务器脚本
#
#   功能:
#   1. 开启 root 用户密码登录 SSH。
#   2. 可选安装 1Panel 管理面板。
#   3. 可选安装 x-ui-yg 脚本，用于科学上网。
#   4. init_gcp.sh 脚本更新。
#
#   作者:   基于用户需求生成的 AI 脚本
#   版本:   1.2
#   更新地址: https://github.com/foobar4j/gcp_free
#
# ==============================================================================

# 定义彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 脚本信息
SCRIPT_VERSION="1.2"
SCRIPT_URL="https://raw.githubusercontent.com/foobar4j/gcp_free/main/init_gcp.sh"

# 自更新函数
update_script() {
    echo -e "${YELLOW}--> 正在检查更新...${NC}"

    # 下载远程脚本到临时文件
    TEMP_SCRIPT=$(mktemp)
    if ! curl -fsSL "$SCRIPT_URL" -o "$TEMP_SCRIPT"; then
        echo -e "${RED}错误: 无法下载远程脚本，请检查网络连接。${NC}"
        rm -f "$TEMP_SCRIPT"
        exit 1
    fi

    # 提取远程版本号
    REMOTE_VERSION=$(grep "^#   版本:" "$TEMP_SCRIPT" | awk '{print $3}')

    # 比较版本
    if [ "$REMOTE_VERSION" = "$SCRIPT_VERSION" ]; then
        echo -e "${GREEN}当前已是最新版本 v${SCRIPT_VERSION}。${NC}"
        rm -f "$TEMP_SCRIPT"
        exit 0
    fi

    echo -e "${YELLOW}发现新版本: v${REMOTE_VERSION} (当前: v${SCRIPT_VERSION})${NC}"
    read -p "是否更新到最新版本? (y/n) [默认 y]: " UPDATE_CONFIRM
    UPDATE_CONFIRM=${UPDATE_CONFIRM:-y}

    if [[ "$UPDATE_CONFIRM" =~ ^[yY](es)?$ ]]; then
        # 获取当前脚本路径
        CURRENT_SCRIPT="$0"

        # 备份当前脚本
        cp "$CURRENT_SCRIPT" "${CURRENT_SCRIPT}.bak"
        echo -e "${YELLOW}已备份当前脚本到 ${CURRENT_SCRIPT}.bak${NC}"

        # 替换脚本
        cp "$TEMP_SCRIPT" "$CURRENT_SCRIPT"
        chmod +x "$CURRENT_SCRIPT"

        echo -e "${GREEN}脚本已更新到 v${REMOTE_VERSION}！${NC}"
        echo -e "${YELLOW}请重新运行脚本: bash $CURRENT_SCRIPT${NC}"
    else
        echo -e "${YELLOW}已取消更新。${NC}"
    fi

    rm -f "$TEMP_SCRIPT"
    exit 0
}

# 检查命令行参数
if [ "$1" = "--update" ] || [ "$1" = "-u" ]; then
    update_script
fi

# --- 步骤 0: 检查权限和环境 ---
clear
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}     欢迎使用云服务器一键初始化脚本 v${SCRIPT_VERSION}       ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo
echo -e "${YELLOW}提示: 使用 '$0 --update' 或 '$0 -u' 可更新脚本到最新版本${NC}"
echo

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED}错误: 此脚本必须以 root 用户身份运行。${NC}"
   echo -e "${YELLOW}请尝试使用 'sudo bash $0' 或切换到 root 用户后执行。${NC}"
   exit 1
fi

# 更新软件包列表
echo -e "${YELLOW}--> 正在更新系统软件包列表 (apt update)...${NC}"
apt update > /dev/null 2>&1
echo -e "${GREEN}软件包列表更新完成。${NC}"
echo

# 安装必要工具
echo -e "${YELLOW}--> 正在安装 curl, wget, sudo 等基础工具...${NC}"
apt install -y curl wget sudo > /dev/null 2>&1
echo -e "${GREEN}基础工具安装完成。${NC}"
echo

# --- 步骤 1: 开启 Root 用户 SSH 密码登录 ---
echo -e "${GREEN}--- 步骤 1/3: 配置 Root 用户 SSH 登录 ---${NC}"
{
    # 使用 sed 命令修改 sshd_config 文件，更安全可靠
    # 允许 root 登录
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    # 开启密码认证
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
} &> /dev/null
echo -e "配置文件 /etc/ssh/sshd_config 修改完成。"

# 重启 SSH 服务，自动判断系统类型
echo -e "正在重启 SSH 服务..."
if command -v systemctl &> /dev/null; then
    systemctl restart sshd
else
    /etc/init.d/ssh restart
fi
echo -e "SSH 服务已重启。"

# 设置 root 密码
echo -e "${YELLOW}接下来，请为 root 用户设置一个安全的登录密码:${NC}"
passwd root
echo -e "${GREEN}Root 密码设置成功！现在你可以通过 SSH 客户端使用 root 和新密码登录。${NC}"
echo

# --- 步骤 2: 安装服务器管理面板 ---
echo -e "${GREEN}--- 步骤 2/3: 安装服务器管理面板 ---${NC}"
read -p "是否需要安装 1Panel 管理面板? (y/n) [默认 n]: " INSTALL_PANEL

if [[ "$INSTALL_PANEL" =~ ^[yY](es)?$ ]]; then
    echo -e "${YELLOW}--> 正在安装 1Panel...${NC}"
    bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)"
else
    echo -e "${YELLOW}已跳过安装管理面板。${NC}"
fi
echo

# --- 步骤 3: 安装 x-ui-yg 脚本 ---
echo -e "${GREEN}--- 步骤 3/3: 安装科学上网管理脚本 ---${NC}"
read -p "是否需要安装 x-ui-yg 管理脚本? (y/n) [默认 n]: " INSTALL_XUI

if [[ "$INSTALL_XUI" =~ ^[yY](es)?$ ]]; then
    echo -e "${YELLOW}--> 正在执行 x-ui-yg 安装脚本...${NC}"
    echo -e "${YELLOW}安装过程将是交互式的，请根据提示进行操作。${NC}"
    bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh)
else
    echo -e "${YELLOW}已跳过安装 x-ui-yg。${NC}"
fi
echo

# --- 结束 ---
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}          🎉 恭喜！服务器初始化完成！ 🎉             ${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo
echo -e "操作摘要:"
echo -e "1. ${GREEN}Root 登录已开启${NC}，你可以使用新设置的密码通过 SSH 客户端（如 Putty, iTerm2）登录。"
echo -e "2. 如果安装了 1Panel，请根据上面打印出的 ${YELLOW}面板地址、用户名和密码${NC} 访问。"
echo -e "3. 如果安装了 x-ui-yg，请根据安装提示访问管理面板。"
echo
echo -e "${YELLOW}重要提示: 如果你安装了任何需要开放端口的服务（如 1Panel），请务必在云服务商（GCP, Azure等）的防火墙/安全组规则中放行相应的端口！${NC}"
echo