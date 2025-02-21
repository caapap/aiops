#!/bin/sh
# 通用安装脚本模板
# 使用方法：复制此模板并修改以下变量和函数来适配你的安装需求

###################
# 1. 基础配置部分 #
###################

set -eu

# 颜色定义
red="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 1 || :) 2>&-)"
green="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 2 || :) 2>&-)"
gray="$( (/usr/bin/tput setaf 8 || :) 2>&-)"
plain="$( (/usr/bin/tput sgr0 || :) 2>&-)"

# 安装配置（根据需要修改）
APP_NAME="your-app"                      # 应用名称
INSTALL_DIR="/opt/$APP_NAME"            # 安装目录
BACKUP_DIR="${INSTALL_DIR}_backup"      # 备份目录
CONFIG_DIR="/etc/$APP_NAME"             # 配置目录
SERVICE_NAME="$APP_NAME"                # 服务名称
PACKAGE_NAME="./$APP_NAME.tgz"          # 安装包名称

###################
# 2. 工具函数部分 #
###################

# 状态输出函数
status() { echo ">>> $*" >&2; }
error() { echo "${red}ERROR:${plain} $*"; exit 1; }
warning() { echo "${red}WARNING:${plain} $*"; }

# 命令检查函数
available() { command -v $1 >/dev/null; }
require() {
    local MISSING=''
    for TOOL in $*; do
        if ! available $TOOL; then
            MISSING="$MISSING $TOOL"
        fi
    done
    echo $MISSING
}

# 清理函数
TEMP_DIR=$(mktemp -d)
cleanup() { 
    stop_progress "success" >/dev/null 2>&1 || true
    rm -rf $TEMP_DIR
}
trap cleanup EXIT INT TERM

# 系统检查函数
check_system() {
    # 检查操作系统
    [ "$(uname -s)" = "Linux" ] || error 'This script is intended to run on Linux only.'

    # 检查架构
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) error "Unsupported architecture: $ARCH" ;;
    esac

    # 检查权限
    SUDO=
    if [ "$(id -u)" -ne 0 ]; then
        if ! available sudo; then
            error "This script requires superuser permissions. Please re-run as root."
        fi
        SUDO="sudo"
    fi
}

########################
# 3. 进度显示函数部分 #
########################

# 进度追踪变量
TOTAL_STEPS=0
CURRENT_STEP=0
FIRST_LINE_PRINTED=false

# 进度动画函数
start_progress() {
    local msg="$1"
    CURRENT_STEP=$((CURRENT_STEP + 1))
    
    # 如果是第一次，打印头部状态行
    if [ "$FIRST_LINE_PRINTED" = false ]; then
        echo "[+] Running $TOTAL_STEPS/$TOTAL_STEPS" >&2
        FIRST_LINE_PRINTED=true
    fi
    
    # 显示当前任务状态
    echo -n " ⠿ ${msg} ${gray}Starting${plain}" >&2
    tput civis # 隐藏光标
    START_TIME=$(date +%s)
    
    # 启动动画
    progress_pid=$$
    (
        i=1
        chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
        while kill -0 $progress_pid 2>/dev/null; do
            # 计算当前耗时
            current_time=$(date +%s)
            elapsed=$((current_time - START_TIME))
            # 更新当前任务状态和耗时
            printf "\r ⠿ %-30s ${gray}Starting${plain} ${chars:i++%${#chars}:1}${gray}%25.1fs${plain}" "$msg" "$elapsed" >&2
            sleep 0.1
        done
    ) &
    progress_animation_pid=$!
}

stop_progress() {
    local result=$1  # 'success' 或 'fail'
    local msg="$2"
    if [ -n "${progress_animation_pid:-}" ]; then
        kill $progress_animation_pid 2>/dev/null || true
        wait $progress_animation_pid 2>/dev/null || true
        
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        echo -ne "\r\033[K" >&2
        if [ "$result" = "success" ]; then
            printf " ⠿ %-30s ${green}Done${plain}${gray}%25.1fs${plain}\n" "$msg" "$DURATION" >&2
        else
            printf " ⠿ %-30s ${red}Failed${plain}${gray}%25.1fs${plain}\n" "$msg" "$DURATION" >&2
        fi
        
        if [ $CURRENT_STEP -eq $TOTAL_STEPS ]; then
            echo -ne "\033[$(($TOTAL_STEPS + 1))A\r\033[K[+] Running $TOTAL_STEPS/$TOTAL_STEPS\n" >&2
            echo -ne "\033[${TOTAL_STEPS}B" >&2
        fi
        
        tput cnorm
        unset progress_animation_pid
    fi
}

#######################
# 4. 安装函数部分    #
#######################

# 预安装检查
pre_install_check() {
    # 检查安装包
    [ -f "$PACKAGE_NAME" ] || error "Installation package not found: $PACKAGE_NAME"
    
    # 检查是否已安装
    if [ -d "$INSTALL_DIR" ]; then
        UPGRADE_MODE=true
        status "Detected existing installation, running in upgrade mode"
    fi
}

# 备份函数
backup_existing() {
    if [ "$UPGRADE_MODE" = true ]; then
        local backup_path="${BACKUP_DIR}_$(date +%Y%m%d_%H%M%S)"
        status "Backing up current installation to $backup_path"
        $SUDO cp -r "$INSTALL_DIR" "$backup_path"
        echo "$backup_path"  # 返回备份路径
    fi
}

# 创建目录
create_directories() {
    start_progress "Creating directories"
    $SUDO mkdir -p "$INSTALL_DIR"
    $SUDO mkdir -p "$CONFIG_DIR"
    stop_progress "success" "Directory creation"
}

# 解压安装包
extract_package() {
    start_progress "Installing package"
    $SUDO tar -xzf "$PACKAGE_NAME" -C "$INSTALL_DIR" >/dev/null 2>&1
    stop_progress "success" "Package installation"
}

# 配置服务
configure_service() {
    start_progress "Configuring service"
    # 在这里添加服务配置逻辑
    stop_progress "success" "Service configuration"
}

# 设置权限
set_permissions() {
    start_progress "Setting permissions"
    $SUDO chown -R root:root "$INSTALL_DIR"
    $SUDO chmod 755 "$INSTALL_DIR"
    stop_progress "success" "Permissions set"
}

# 启动服务
start_service() {
    if available systemctl; then
        start_progress "Starting service"
        $SUDO systemctl daemon-reload
        $SUDO systemctl enable "$SERVICE_NAME"
        $SUDO systemctl restart "$SERVICE_NAME"
        stop_progress "success" "Service started"
    fi
}

#######################
# 5. 主安装流程      #
#######################

main() {
    # 设置步骤总数（根据实际使用的步骤修改）
    TOTAL_STEPS=5  # 目录创建、包安装、服务配置、权限设置、服务启动
    
    # 系统检查
    check_system
    
    # 预安装检查
    pre_install_check
    
    # 执行安装步骤
    create_directories
    extract_package
    configure_service
    set_permissions
    start_service
    
    # 完成提示
    echo
    status "${green}Installation complete!${plain}"
    status "$APP_NAME is installed at: $INSTALL_DIR"
    status "Configuration is located at: $CONFIG_DIR"
}

# 执行主函数
main 