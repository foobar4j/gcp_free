#!/bin/sh

# ==============================================================================
#
#          一键初始化Google Cloud (GCP) 等云服务器脚本
#
#   功能:
#   1. 开启 root 用户密码登录 SSH。
#   2. 安装 1Panel 管理面板。
#   3. 配置 Docker 镜像源和 dae 网桥。
#   4. 安装 x-ui-yg 脚本，用于科学上网。
#   5. init_gcp.sh 脚本更新。
#
#   作者:   基于用户需求生成的 AI 脚本
#   版本:   1.3
#   更新地址: https://github.com/foobar-ai/gcp_free
#
# ==============================================================================

# 定义彩色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 脚本信息
SCRIPT_VERSION="1.3"
SCRIPT_URL="https://raw.githubusercontent.com/foobar-ai/gcp_free/master/init_gcp.sh"

# ==================== 功能函数 ====================

# 1. 开启 SSH Root 登录
configure_ssh() {
    printf "${GREEN}--- 配置 Root 用户 SSH 登录 ---${NC}\n"
    {
        # 使用 sed 命令修改 sshd_config 文件，更安全可靠
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
    } > /dev/null 2>&1
    echo "配置文件 /etc/ssh/sshd_config 修改完成。"

    # 重启 SSH 服务
    echo "正在重启 SSH 服务..."
    if command -v systemctl > /dev/null 2>&1; then
        systemctl restart sshd
    else
        /etc/init.d/ssh restart
    fi
    echo "SSH 服务已重启。"

    # 设置 root 密码
    printf "${YELLOW}接下来，请为 root 用户设置一个安全的登录密码:${NC}\n"
    
    PASSWORD_SET_SUCCESS=false
    while [ "$PASSWORD_SET_SUCCESS" = false ]; do
        if passwd root; then
            PASSWORD_SET_SUCCESS=true
            printf "${GREEN}Root 密码设置成功！现在你可以通过 SSH 客户端使用 root 和新密码登录。${NC}\n"
        else
            printf "${RED}密码设置失败，请重试。${NC}\n"
            printf "是否跳过设置 root 密码? (y/n) [默认 n]: "
            read SKIP_PASSWORD
            case "$SKIP_PASSWORD" in
                [yY]|[yY][eE][sS])
                    printf "${YELLOW}已跳过设置 root 密码。${NC}\n"
                    PASSWORD_SET_SUCCESS=true
                    ;;
            esac
        fi
    done
    echo
    printf "按回车键返回菜单..."
    read DUMMY
}

# 2. 安装 1Panel
install_1panel() {
    printf "${GREEN}--- 安装 1Panel 管理面板 ---${NC}\n"
    printf "${YELLOW}--> 正在安装 1Panel...${NC}\n"
    bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)"
    echo
    printf "按回车键返回菜单..."
    read DUMMY
}

# 3. 配置 Docker 和 dae
configure_docker_dae() {
    printf "${GREEN}--- 配置 Docker 镜像源和 dae 网桥 ---${NC}\n"

    # 检查 Docker 是否已安装
    if ! command -v docker > /dev/null 2>&1; then
        printf "${YELLOW}警告: 未检测到 Docker，跳过配置。${NC}\n"
        printf "${YELLOW}如需使用 Docker，请先安装 Docker 后手动配置。${NC}\n"
    else
        printf "${GREEN}检测到 Docker 已安装。${NC}\n"

        # 配置 Docker 镜像源
        DOCKER_DAEMON_CONFIG="/etc/docker/daemon.json"

        # 确保 /etc/docker 目录存在
        if [ ! -d "/etc/docker" ]; then
            printf "${YELLOW}创建 /etc/docker 目录...${NC}\n"
            mkdir -p /etc/docker
        fi

        if [ -f "$DOCKER_DAEMON_CONFIG" ]; then
            printf "${YELLOW}检测到已存在 $DOCKER_DAEMON_CONFIG，备份中...${NC}\n"
            cp "$DOCKER_DAEMON_CONFIG" "${DOCKER_DAEMON_CONFIG}.bak"
        fi

        # 创建或更新 Docker 配置文件
        cat > "$DOCKER_DAEMON_CONFIG" << 'EOF'
{
  "registry-mirrors": ["http://mirror.gcr.io"]
}
EOF

        printf "${GREEN}Docker 镜像源已配置为 http://mirror.gcr.io${NC}\n"

        # 重启 Docker 服务
        printf "${YELLOW}--> 正在重启 Docker 服务...${NC}\n"
        systemctl restart docker

        if [ $? -eq 0 ]; then
            printf "${GREEN}Docker 服务重启成功。${NC}\n"
        else
            printf "${RED}Docker 服务重启失败。${NC}\n"
        fi

        # 检查并配置 dae（如果存在）
        if systemctl is-active --quiet dae; then
            printf "${YELLOW}检测到 dae 服务正在运行，正在配置 Docker 网桥...${NC}\n"

            # 获取所有 Docker 网桥接口
            DOCKER_BRIDGES=$(ip a | grep -E '^[0-9]+: (docker|br-)' | awk -F': ' '{print $2}' | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')

            if [ -n "$DOCKER_BRIDGES" ]; then
                DAE_CONFIG="/usr/local/etc/dae/config.dae"

                if [ -f "$DAE_CONFIG" ]; then
                    printf "${YELLOW}检测到 dae 配置文件，正在更新...${NC}\n"
                    
                    # 备份配置
                    cp "$DAE_CONFIG" "${DAE_CONFIG}.bak"

                    # 更新 lan_interface 配置
                    if grep -q "^lan_interface:" "$DAE_CONFIG"; then
                        sed -i "s/^lan_interface:.*/lan_interface: $DOCKER_BRIDGES/" "$DAE_CONFIG"
                    else
                        printf "${YELLOW}在配置文件中添加 lan_interface 配置...${NC}\n"
                        echo "lan_interface: $DOCKER_BRIDGES" >> "$DAE_CONFIG"
                    fi
                    printf "${YELLOW}Docker 网桥列表: $DOCKER_BRIDGES${NC}\n"

                    # 重启 dae 服务
                    printf "${YELLOW}--> 正在重启 dae 服务以应用配置...${NC}\n"
                    systemctl restart dae
                    
                    # 检查重启是否成功
                    if systemctl is-active --quiet dae; then
                        printf "${GREEN}dae 服务重启成功，Docker 网桥 ($DOCKER_BRIDGES) 已配置。${NC}\n"
                    else
                        printf "${RED}错误: dae 服务重启失败！正在还原配置文件...${NC}\n"
                        # 还原备份
                        mv "${DAE_CONFIG}.bak" "$DAE_CONFIG"
                        
                        printf "${RED}=====================================================${NC}\n"
                        printf "${RED}dae 启动失败，已还原配置。请检查以下日志：${NC}\n"
                        printf "${RED}=====================================================${NC}\n"
                        # 打印 dae 最近的错误日志
                        journalctl -xeu dae.service --no-pager -n 20
                        printf "${RED}=====================================================${NC}\n"
                    fi
                else
                    printf "${YELLOW}未找到 dae 配置文件，跳过配置。${NC}\n"
                fi
            else
                printf "${YELLOW}未检测到 Docker 网桥接口。${NC}\n"
            fi
        else
            printf "${YELLOW}dae 服务未运行，跳过配置。${NC}\n"
        fi
    fi
    echo
    printf "按回车键返回菜单..."
    read DUMMY
}

# 4. 安装 x-ui-yg
install_xui() {
    printf "${GREEN}--- 安装 x-ui-yg 科学上网脚本 ---${NC}\n"
    printf "${YELLOW}--> 正在执行 x-ui-yg 安装脚本...${NC}\n"
    printf "${YELLOW}安装过程将是交互式的，请根据提示进行操作。${NC}\n"
    
    # 下载脚本到临时文件并执行，以兼容 sh 并支持交互
    curl -o /tmp/xui_install.sh -Ls https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh
    if [ $? -eq 0 ]; then
        bash /tmp/xui_install.sh
        rm -f /tmp/xui_install.sh
    else
        printf "${RED}下载 x-ui-yg 脚本失败。${NC}\n"
    fi
    
    echo
    printf "按回车键返回菜单..."
    read DUMMY
}

# 5. 脚本更新
update_script() {
    printf "${YELLOW}--> 正在检查更新...${NC}\n"

    # 下载远程脚本到临时文件
    TEMP_SCRIPT=$(mktemp)
    if ! curl -fsSL "$SCRIPT_URL" -o "$TEMP_SCRIPT"; then
        printf "${RED}错误: 无法下载远程脚本，请检查网络连接。${NC}\n"
        rm -f "$TEMP_SCRIPT"
        # 如果是命令行参数调用，直接退出
        if [ "$1" = "exit_on_error" ]; then exit 1; fi
        return 1
    fi

    # 提取远程版本号
    REMOTE_VERSION=$(grep "^#   版本:" "$TEMP_SCRIPT" | awk '{print $3}')

    # 比较版本
    if [ "$REMOTE_VERSION" = "$SCRIPT_VERSION" ]; then
        printf "${GREEN}当前已是最新版本 v${SCRIPT_VERSION}。${NC}\n"
        rm -f "$TEMP_SCRIPT"
        # 如果是命令行参数调用，直接退出
        if [ "$1" = "exit_on_error" ]; then exit 0; fi
        printf "按回车键返回菜单..."
        read DUMMY
        return 0
    fi

    printf "${YELLOW}发现新版本: v${REMOTE_VERSION} (当前: v${SCRIPT_VERSION})${NC}\n"
    printf "是否更新到最新版本? (y/n) [默认 y]: "
    read UPDATE_CONFIRM
    # 默认 y
    if [ -z "$UPDATE_CONFIRM" ]; then UPDATE_CONFIRM="y"; fi

    case "$UPDATE_CONFIRM" in
        [yY]|[yY][eE][sS])
            # 获取当前脚本路径
            CURRENT_SCRIPT="$0"

            # 备份当前脚本
            cp "$CURRENT_SCRIPT" "${CURRENT_SCRIPT}.bak"
            printf "${YELLOW}已备份当前脚本到 ${CURRENT_SCRIPT}.bak${NC}\n"

            # 替换脚本
            cp "$TEMP_SCRIPT" "$CURRENT_SCRIPT"
            chmod +x "$CURRENT_SCRIPT"

            printf "${GREEN}脚本已更新到 v${REMOTE_VERSION}！${NC}\n"
            printf "${YELLOW}请重新运行脚本: sh $CURRENT_SCRIPT${NC}\n"
            rm -f "$TEMP_SCRIPT"
            exit 0
            ;;
        *)
            printf "${YELLOW}已取消更新。${NC}\n"
            ;;
    esac

    rm -f "$TEMP_SCRIPT"
    printf "按回车键返回菜单..."
    read DUMMY
}

# ==================== 主逻辑 ====================

# 检查命令行参数
if [ "$1" = "--update" ] || [ "$1" = "-u" ]; then
    update_script "exit_on_error"
    exit 0
fi

# 检查权限和环境
clear
# 检查是否通过管道执行
# POSIX sh 下检查管道比较复杂，这里简化检查
if [ -z "$TERM" ] || [ "$TERM" = "dumb" ]; then
    # 尝试判断 stdin 是否是终端
    if [ ! -t 0 ]; then
        printf "${RED}警告: 检测到脚本可能通过管道方式执行。${NC}\n"
        printf "${YELLOW}这种方式无法交互式设置 root 密码。${NC}\n"
        printf "${YELLOW}请使用以下方式重新运行脚本:${NC}\n"
        printf "${GREEN}  curl -O ${SCRIPT_URL} && sudo sh init_gcp.sh${NC}\n"
        echo
        exit 1
    fi
fi

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
   printf "${RED}错误: 此脚本必须以 root 用户身份运行。${NC}\n"
   printf "${YELLOW}请尝试使用 'sudo sh $0' 或切换到 root 用户后执行。${NC}\n"
   exit 1
fi

# 主循环
while true; do
    clear
    printf "${GREEN}=====================================================${NC}\n"
    printf "${GREEN}     云服务器一键初始化脚本 v${SCRIPT_VERSION}       ${NC}\n"
    printf "${GREEN}=====================================================${NC}\n"
    printf "${YELLOW}作者: foobar-ai${NC}\n"
    printf "${YELLOW}项目: https://github.com/foobar-ai/gcp_free${NC}\n"
    echo
    echo "  1. 开启 Root 用户 SSH 登录"
    echo "  2. 安装 1Panel 管理面板"
    echo "  3. 配置 Docker 镜像源和 dae 网桥"
    echo "  4. 安装 x-ui-yg 科学上网脚本"
    echo "  5. 更新本脚本"
    echo "  6. 退出"
    echo
    printf "${GREEN}=====================================================${NC}\n"
    printf "请输入选项 [1-6]: "
    read CHOICE

    case "$CHOICE" in
        1)
            configure_ssh
            ;;
        2)
            install_1panel
            ;;
        3)
            configure_docker_dae
            ;;
        4)
            install_xui
            ;;
        5)
            update_script
            ;;
        6)
            printf "${GREEN}退出脚本。感谢使用！${NC}\n"
            exit 0
            ;;
        *)
            printf "${RED}无效的选项，请重新输入。${NC}\n"
            sleep 1
            ;;
    esac
done