#!/bin/bash

# ==============================================================================
#
#          一键初始化Google Cloud (GCP) 等云服务器脚本
#
#   功能:
#   1. 开启 root 用户密码登录 SSH。
#   2. 可选安装 1Panel 管理面板。
#   3. 可选安装 x-ui-yg 脚本，用于科学上网。
#
#   作者:   基于用户需求生成的 AI 脚本
#   版本:   1.1
#
# ==============================================================================

# 定义彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- 步骤 0: 检查权限和环境 ---
clear
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}     欢迎使用云服务器一键初始化脚本 v1.1       ${NC}"
echo -e "${GREEN}=====================================================${NC}"
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