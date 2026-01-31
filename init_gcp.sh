#!/bin/bash

# ==============================================================================
#
#          一键初始化Google Cloud (GCP) 等云服务器脚本
#
#   功能:
#   1. 开启 root 用户密码登录 SSH（必选）。
#   2. 安装并配置 Docker（必选）。
#   3. 安装 1Panel 管理面板（可选）。
#   4. 安装 x-ui-yg 脚本，用于科学上网（可选）。
#   5. init_gcp.sh 脚本更新（可选）。
#
#   作者:   基于用户需求生成的 AI 脚本
#   版本:   1.2
#   更新地址: https://github.com/foobar-ai/gcp_free
#
# ==============================================================================

# 定义彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 脚本信息
SCRIPT_VERSION="1.2"
SCRIPT_URL="https://raw.githubusercontent.com/foobar-ai/gcp_free/master/init_gcp.sh"

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

# 检查是否通过管道执行（curl ... | bash）
if [ "$0" = "bash" ] || [ "$0" = "/bin/bash" ] || [ "$0" = "/usr/bin/bash" ]; then
    echo -e "${RED}警告: 检测到脚本通过管道方式执行。${NC}"
    echo -e "${YELLOW}这种方式无法交互式设置 root 密码。${NC}"
    echo -e "${YELLOW}请使用以下方式重新运行脚本:${ ${NC}"
    echo -e "${GREEN}  curl -O ${SCRIPT_URL} && sudo bash init_gcp.sh${NC}"
    echo
    exit 1
fi

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

PASSWORD_SET_SUCCESS=false
while [ "$PASSWORD_SET_SUCCESS" = false ]; do
    if passwd root; then
        PASSWORD_SET_SUCCESS=true
        echo -e "${GREEN}Root 密码设置成功！现在你可以通过 SSH 客户端使用 root 和新密码登录。${NC}"
    else
        echo -e "${RED}密码设置失败，请重试。${NC}"
        read -p "是否跳过设置 root 密码? (y/n) [默认 n]: " SKIP_PASSWORD
        if [[ "$SKIP_PASSWORD" =~ ^[yY](es)?$ ]]; then
            echo -e "${YELLOW}已跳过设置 root 密码。${NC}"
            PASSWORD_SET_SUCCESS=true
        fi
    fi
done
echo

# --- 步骤 2: 安装并配置 Docker ---
echo -e "${GREEN}--- 步骤 2/4: 安装并配置 Docker ---${NC}"

# 检查是否已安装 Docker
if command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker 已安装，跳过安装步骤。${NC}"
else
    echo -e "${YELLOW}--> 正在安装 Docker...${NC}"

    # 安装 Docker
    curl -fsSL https://get.docker.com | bash

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Docker 安装成功。${NC}"
    else
        echo -e "${RED}Docker 安装失败，请检查网络连接。${NC}"
        exit 1
    fi
fi

# 配置 Docker 镜像源
DOCKER_DAEMON_CONFIG="/etc/docker/daemon.json"
if [ -f "$DOCKER_DAEMON_CONFIG" ]; then
    echo -e "${YELLOW}检测到已存在 $DOCKER_DAEMON_CONFIG，备份中...${NC}"
    cp "$DOCKER_DAEMON_CONFIG" "${DOCKER_DAEMON_CONFIG}.bak"
fi

# 创建或更新 Docker 配置文件
cat > "$DOCKER_DAEMON_CONFIG" << 'EOF'
{
  "registry-mirrors": ["http://mirror.gcr.io"]
}
EOF

echo -e "${GREEN}Docker 镜像源已配置为 http://mirror.gcr.io${NC}"

# 重启 Docker 服务
echo -e "${YELLOW}--> 正在重启 Docker 服务...${NC}"
systemctl restart docker

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Docker 服务重启成功。${NC}"
else
    echo -e "${RED}Docker 服务重启失败。${NC}"
fi

# 检查并配置 dae（如果存在）
if systemctl is-active --quiet dae; then
    echo -e "${YELLOW}检测到 dae 服务正在运行，正在配置 Docker 网桥...${NC}"

    # 获取所有 Docker 网桥接口
    DOCKER_BRIDGES=$(ip a | grep -E '^[0-9]+: (docker|br-)' | awk -F': ' '{print $2}' | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')

    if [ -n "$DOCKER_BRIDGES" ]; then
        DAE_CONFIG="/usr/local/etc/dae/config.dae"

        if [ -f "$DAE_CONFIG" ]; then
            echo -e "${YELLOW}检测到 dae 配置文件，正在更新...${NC}"
            cp "$DAE_CONFIG" "${DAE_CONFIG}.bak"

            # 更新 lan_interface 配置
            if grep -q "^lan_interface:" "$DAE_CONFIG"; then
                sed -i "s/^lan_interface:.*/lan_interface: $DOCKER_BRIDGES/" "$DAE_CONFIG"
            else
                echo -e "${YELLOW}在配置文件中添加 lan_interface 配置...${NC}"
                echo "lan_interface: $DOCKER_BRIDGES" >> "$DAE_CONFIG"
            fi

            # 重启 dae 服务
            systemctl restart dae
            echo -e "${GREEN}dae 服务已重启，Docker 网桥 ($DOCKER_BRIDGES) 已配置。${NC}"
        else
            echo -e "${YELLOW}未找到 dae 配置文件，跳过配置。${NC}"
        fi
    else
        echo -e "${YELLOW}未检测到 Docker 网桥接口。${NC}"
    fi
else
    echo -e "${YELLOW}dae 服务未运行，跳过配置。${NC}"
fi
echo

# --- 步骤 3: 安装服务器管理面板 ---
echo -e "${GREEN}--- 步骤 3/4: 安装服务器管理面板 ---${NC}"
read -p "是否需要安装 1Panel 管理面板? (y/n) [默认 n]: " INSTALL_PANEL

if [[ "$INSTALL_PANEL" =~ ^[yY](es)?$ ]]; then
    echo -e "${YELLOW}--> 正在安装 1Panel...${NC}"
    bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)"
else
    echo -e "${YELLOW}已跳过安装管理面板。${NC}"
fi
echo

# --- 步骤 4: 安装 x-ui-yg 脚本 ---
echo -e "${GREEN}--- 步骤 4/4: 安装科学上网管理脚本 ---${NC}"
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
echo -e "2. ${GREEN}Docker 已安装并配置${NC}，镜像源已设置为 http://mirror.gcr.io。"
echo -e "3. 如果安装了 1Panel，请根据上面打印出的 ${YELLOW}面板地址、用户名和密码${NC} 访问。"
echo -e "4. 如果安装了 x-ui-yg，请根据安装提示访问管理面板。"
echo
echo -e "${YELLOW}重要提示: 如果你安装了任何需要开放端口的服务（如 1Panel），请务必在云服务商（GCP, Azure等）的防火墙/安全组规则中放行相应的端口！${NC}"
echo