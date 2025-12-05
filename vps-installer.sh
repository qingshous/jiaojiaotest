#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BG_BLUE='\033[44m'
BG_GREEN='\033[42m'
BG_RED='\033[41m'
BG_YELLOW='\033[43m'

# 清屏函数
clear_screen() {
 clear
}

# 打印分隔线
print_separator() {
 echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
}

# 打印标题
print_title() {
 echo -e "
${BG_BLUE}${WHITE}════════════════════════════════════════════════════════════${NC}"
 echo -e "${BG_BLUE}${WHITE} VPS 容器化部署工具 v1.1 ${NC}"
 echo -e "${BG_BLUE}${WHITE}════════════════════════════════════════════════════════════${NC}
"
}

# 打印成功消息
print_success() {
 echo -e "${GREEN}✓ $1${NC}"
}

# 打印错误消息
print_error() {
 echo -e "${RED}✗✗ $1${NC}"
}

# 打印信息消息
print_info() {
 echo -e "${BLUE}➤➤ $1${NC}"
}

# 打印警告消息
print_warning() {
 echo -e "${YELLOW}⚠ $1${NC}"
}

# 等待用户按键
press_any_key() {
 echo -e "
${YELLOW}按任意键继续...${NC}"
 read -n 1 -s
}

# 检查是否以root运行
check_root() {
 if [[ $EUID -ne 0 ]]; then
 print_error "此脚本必须以root权限运行！"
 echo -e "${YELLOW}请使用: sudo ./$(basename $0)${NC}"
 exit 1
 fi
}

# 更新系统包
update_system() {
 print_info "正在更新系统包..."
 print_separator
 
 if command -v apt-get &> /dev/null; then
 apt-get update
 if [ $? -eq 0 ]; then
 apt-get upgrade -y
 apt-get autoremove -y
 apt-get clean
 print_success "系统更新完成！"
 else
 print_error "更新失败，请检查网络连接！"
 return 1
 fi
 elif command -v yum &> /dev/null; then
 yum update -y
 yum clean all
 print_success "系统更新完成！"
 elif command -v dnf &> /dev/null; then
 dnf update -y
 dnf clean all
 print_success "系统更新完成！"
 else
 print_error "不支持的包管理器！"
 return 1
 fi
 return 0
}

# 安装Docker
install_docker() {
 print_info "正在安装Docker..."
 print_separator
 
 # 检查Docker是否已安装
 if command -v docker &> /dev/null; then
 docker_version=$(docker --version | cut -d ' ' -f 3 | tr -d ',')
 print_success "Docker 已安装 (版本: $docker_version)"
 return 0
 fi
 
 # 根据系统选择安装方式
 if command -v apt-get &> /dev/null; then
 # Ubuntu/Debian
 apt-get install -y \
 apt-transport-https \
 ca-certificates \
 curl \
 gnupg \
 lsb-release
 
 # 添加Docker官方GPG密钥
 mkdir -p /etc/apt/keyrings
 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
 gpg --dearmor -o /etc/apt/keyrings/docker.gpg
 
 # 设置存储库
 echo \
 "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
 https://download.docker.com/linux/ubuntu \
 $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
 
 apt-get update
 apt-get install -y docker-ce docker-ce-cli containerd.io
 
 elif command -v yum &> /dev/null; then
 # CentOS/RHEL
 yum install -y yum-utils
 yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
 yum install -y docker-ce docker-ce-cli containerd.io
 
 elif command -v dnf &> /dev/null; then
 # Fedora
 dnf -y install dnf-plugins-core
 dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
 dnf install -y docker-ce docker-ce-cli containerd.io
 else
 print_error "不支持的包管理器！"
 return 1
 fi
 
 # 启动并启用Docker服务
 systemctl start docker
 systemctl enable docker
 
 # 将当前用户添加到docker组（可选）
 if [ ! -z "$SUDO_USER" ]; then
 usermod -aG docker $SUDO_USER
 print_info "已将用户 $SUDO_USER 添加到docker组"
 print_warning "需要重新登录或重启才能使更改生效"
 fi
 
 # 验证安装
 if docker --version &> /dev/null; then
 docker_version=$(docker --version | cut -d ' ' -f 3 | tr -d ',')
 print_success "Docker 安装成功！(版本: $docker_version)"
 return 0
 else
 print_error "Docker 安装失败！"
 return 1
 fi
}

# 安装Docker Compose (可选，保留但不强制使用)
install_docker_compose() {
 print_info "正在安装Docker Compose..."
 print_separator
 
 # 检查是否已安装
 if command -v docker-compose &> /dev/null; then
 compose_version=$(docker-compose --version | cut -d ' ' -f 3 | tr -d ',')
 print_success "Docker Compose 已安装 (版本: $compose_version)"
 return 0
 fi
 
 # 安装Docker Compose
 if command -v apt-get &> /dev/null; then
 # 安装docker-compose-plugin
 apt-get install -y docker-compose-plugin
 if docker compose version &> /dev/null; then
 # 创建符号链接确保兼容性
 ln -sf /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
 else
 # 手动安装旧版本
 curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
 -o /usr/local/bin/docker-compose
 chmod +x /usr/local/bin/docker-compose
 fi
 else
 # 手动安装
 COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
 curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
 -o /usr/local/bin/docker-compose
 chmod +x /usr/local/bin/docker-compose
 fi
 
 # 验证安装
 if docker-compose --version &> /dev/null; then
 compose_version=$(docker-compose --version | cut -d ' ' -f 3 | tr -d ',')
 print_success "Docker Compose 安装成功！(版本: $compose_version)"
 return 0
 else
 print_error "Docker Compose 安装失败！"
 return 1
 fi
}

# 显示主菜单
show_main_menu() {
 clear_screen
 print_title
 
 echo -e "${CYAN}┌┌────────────────────────────────────────────────────────────┐┐${NC}"
 echo -e "${CYAN}│${WHITE} 主菜单 ${CYAN}│${NC}"
 echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
 echo -e "${CYAN}│${GREEN} 1.${WHITE} 更新系统包 ${CYAN}│${NC}"
 echo -e "${CYAN}│${GREEN} 2.${WHITE} 安装 Docker ${CYAN}│${NC}"
 echo -e "${CYAN}│${GREEN} 3.${WHITE} 安装 Docker Compose (可选) ${CYAN}│${NC}"
 echo -e "${CYAN}│${GREEN} 4.${WHITE} 安装容器 ${CYAN}│${NC}"
 echo -e "${CYAN}│${GREEN} 5.${WHITE} 查看已安装容器 ${CYAN}│${NC}"
 echo -e "${CYAN}│${GREEN} 6.${WHITE} 一键安装所有组件 ${CYAN}│${NC}"
 echo -e "${CYAN}│${GREEN} 7.${WHITE} 退出 ${CYAN}│${NC}"
 echo -e "${CYAN}└└────────────────────────────────────────────────────────────┘┘${NC}"
 
 echo -e "
${YELLOW}════════════════════════════════════════════════════════════${NC}"
 echo -e "${WHITE}当前状态:${NC}"
 
 # 显示当前组件状态
 if command -v docker &> /dev/null; then
 echo -e " ${GREEN}✓ Docker 已安装${NC}"
 else
 echo -e " ${RED}✗✗ Docker 未安装${NC}"
 fi
 
 if command -v docker-compose &> /dev/null; then
 echo -e " ${GREEN}✓ Docker Compose 已安装${NC}"
 else
 echo -e " ${RED}✗✗ Docker Compose 未安装${NC}"
 fi
 
 echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
 
 echo -e "
${PURPLE}请选择操作 [1-7]: ${NC}"
 read -p "> " main_choice
}

# 显示容器菜单
show_container_menu() {
 clear_screen
 print_title
 
 echo -e "${CYAN}┌┌────────────────────────────────────────────────────────────┐┐${NC}"
 echo -e "${CYAN}│${WHITE} 容器安装菜单 ${CYAN}│${NC}"
 echo -e "${CYAN}├────────────────────────────────────────────────────────────┤${NC}"
 echo -e "${CYAN}│${GREEN} 1.${WHITE} Frp 服务器 (frps) ${CYAN}│${NC}"
 echo -e "${CYAN}│${YELLOW} └└─ 高性能反向代理服务器 ${CYAN}│${NC}"
 echo -e "${CYAN}│${GREEN} 2.${WHITE} 微信代理 (wxchat) ${CYAN}│${NC}"
 echo -e "${CYAN}│${YELLOW} └└─ 微信网页版代理服务 ${CYAN}│${NC}"
 echo -e "${CYAN}│${GREEN} 3.${WHITE} 同时安装 Frp 和微信代理 ${CYAN}│${NC}"
 echo -e "${CYAN}│${GREEN} 4.${WHITE} 返回主菜单 ${CYAN}│${NC}"
 echo -e "${CYAN}└└────────────────────────────────────────────────────────────┘┘${NC}"
 
 echo -e "
${PURPLE}请选择要安装的容器 [1-4]: ${NC}"
 read -p "> " container_choice
}

# 检查并停止/删除现有容器
stop_existing_container() {
 local container_name=$1
 if docker ps -a | grep -q $container_name; then
 print_info "发现已存在的容器 $container_name，正在停止并删除..."
 docker stop $container_name >/dev/null 2>&1
 docker rm $container_name >/dev/null 2>&1
 print_success "容器 $container_name 已停止并删除"
 fi
}

# 安装Frp服务器 - 使用docker run
install_frps() {
 print_info "正在安装 Frp 服务器..."
 print_separator
 
 # 创建配置目录
 FRP_DIR="/opt/frp"
 CONFIG_FILE="$FRP_DIR/frps.ini"
 
 mkdir -p $FRP_DIR
 
 # 询问Frp配置
 echo -e "
${CYAN}配置 Frp 服务器${NC}"
 echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
 
 read -p "请输入绑定的端口 [默认: 7000]: " BIND_PORT
 BIND_PORT=${BIND_PORT:-7000}
 
 read -p "请输入Web管理界面端口 [默认: 7500]: " DASHBOARD_PORT
 DASHBOARD_PORT=${DASHBOARD_PORT:-7500}
 
 read -p "请输入Web管理界面用户名 [默认: admin]: " DASHBOARD_USER
 DASHBOARD_USER=${DASHBOARD_USER:-admin}
 
 read -p "请输入Web管理界面密码 [默认: admin123]: " DASHBOARD_PWD
 DASHBOARD_PWD=${DASHBOARD_PWD:-admin123}
 
 read -p "请输入token密钥 [默认: $(openssl rand -hex 16)]: " TOKEN
 TOKEN=${TOKEN:-$(openssl rand -hex 16)}
 
 # 创建Frp配置文件
 cat > $CONFIG_FILE << EOF
[common]
bind_port = $BIND_PORT
dashboard_port = $DASHBOARD_PORT
dashboard_user = $DASHBOARD_USER
dashboard_pwd = $DASHBOARD_PWD
token = $TOKEN
EOF
 
 # 停止并删除现有容器
 stop_existing_container "frps"
 
 # 使用docker run启动Frp容器
 print_info "正在启动 Frp 容器..."
 docker run -d \
 --name frps \
 --restart always \
 -p $BIND_PORT:$BIND_PORT \
 -p $BIND_PORT:$BIND_PORT/udp \
 -p $DASHBOARD_PORT:$DASHBOARD_PORT \
 -v $CONFIG_FILE:/etc/frp/frps.ini \
 -e TZ=Asia/Shanghai \
 snowdreamtech/frps:latest
 
 if [ $? -eq 0 ]; then
 print_success "Frp 服务器安装完成！"
 echo -e "
${GREEN}════════════════════════════════════════════════════════════${NC}"
 echo -e "${WHITE}Frp 服务器配置信息：${NC}"
 echo -e "${CYAN}服务端口:${WHITE} $BIND_PORT${NC}"
 echo -e "${CYAN}管理地址:${WHITE} http://你的服务器IP:$DASHBOARD_PORT${NC}"
 echo -e "${CYAN}用户名:${WHITE} $DASHBOARD_USER${NC}"
 echo -e "${CYAN}密码:${WHITE} $DASHBOARD_PWD${NC}"
 echo -e "${CYAN}Token:${WHITE} $TOKEN${NC}"
 echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
 else
 print_error "Frp 服务器启动失败！"
 fi
 
 press_any_key
}

# 安装微信代理 - 使用docker run
install_wxchat() {
 print_info "正在安装微信代理..."
 print_separator
 
 # 创建配置目录
 WXCHAT_DIR="/opt/wxchat"
 mkdir -p $WXCHAT_DIR/data
 
 # 询问端口配置
 echo -e "
${CYAN}配置微信代理${NC}"
 echo -e "${YELLOW}════════════════════════════════════════════════════════════${NC}"
 
 read -p "请输入外部访问端口 [默认: 15680]: " HOST_PORT
 HOST_PORT=${HOST_PORT:-15680}
 
 # 停止并删除现有容器
 stop_existing_container "wxchat"
 
 # 使用docker run启动微信代理容器
 print_info "正在启动微信代理容器..."
 docker run -d \
 --name wxchat \
 --restart always \
 -p $HOST_PORT:80 \
 -e TZ=Asia/Shanghai \
 -v $WXCHAT_DIR/data:/app/data \
 ddsderek/wxchat:latest
 
 if [ $? -eq 0 ]; then
 print_success "微信代理安装完成！"
 echo -e "
${GREEN}════════════════════════════════════════════════════════════${NC}"
 echo -e "${WHITE}微信代理配置信息：${NC}"
 echo -e "${CYAN}访问地址:${WHITE} http://你的服务器IP:$HOST_PORT${NC}"
 echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
 else
 print_error "微信代理启动失败！"
 print_info "尝试检查日志..."
 docker logs wxchat 2>/dev/null || echo "无法获取容器日志"
 fi
 
 press_any_key
}

# 查看已安装容器
show_containers() {
 clear_screen
 print_title
 
 print_info "正在运行的容器："
 print_separator
 
 if docker ps --format "table {{.Names}} {{.Image}} {{.Ports}} {{.Status}}" 2>/dev/null; then
 echo -e "
${GREEN}✓ 容器列表获取成功${NC}"
 else
 print_error "没有正在运行的容器或Docker未运行"
 fi
 
 echo -e "
${YELLOW}════════════════════════════════════════════════════════════${NC}"
 print_info "所有容器（包括已停止的）："
 print_separator
 
 if docker ps -a --format "table {{.Names}} {{.Image}} {{.Ports}} {{.Status}}" 2>/dev/null; then
 echo -e "
${GREEN}✓ 完整容器列表获取成功${NC}"
 fi
 
 press_any_key
}

# 一键安装所有组件 - 使用docker run
install_all() {
 print_info "开始一键安装所有组件..."
 print_separator
 
 # 更新系统
 update_system
 if [ $? -ne 0 ]; then
 print_warning "系统更新失败，继续安装其他组件..."
 fi
 
 # 安装Docker
 install_docker
 if [ $? -ne 0 ]; then
 print_error "Docker安装失败，停止安装！"
 press_any_key
 return
 fi
 
 # 安装Frp服务器（使用默认配置）
 print_info "正在安装Frp服务器（使用默认配置）..."
 FRP_DIR="/opt/frp"
 mkdir -p $FRP_DIR
 
 cat > "$FRP_DIR/frps.ini" << EOF
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin123
token = $(openssl rand -hex 16)
EOF
 
 # 停止并删除现有容器
 stop_existing_container "frps"
 
 # 使用docker run启动Frp容器
 docker run -d \
 --name frps \
 --restart always \
 -p 7000:7000 \
 -p 7000:7000/udp \
 -p 7500:7500 \
 -v $FRP_DIR/frps.ini:/etc/frp/frps.ini \
 -e TZ=Asia/Shanghai \
 snowdreamtech/frps:latest
 
 if [ $? -eq 0 ]; then
 print_success "Frp服务器安装完成！"
 else
 print_error "Frp服务器启动失败！"
 fi
 
 # 安装微信代理
 print_info "正在安装微信代理..."
 WXCHAT_DIR="/opt/wxchat"
 mkdir -p $WXCHAT_DIR/data
 
 # 停止并删除现有容器
 stop_existing_container "wxchat"
 
 # 使用docker run启动微信代理容器
 docker run -d \
 --name wxchat \
 --restart always \
 -p 15680:80 \
 -e TZ=Asia/Shanghai \
 -v $WXCHAT_DIR/data:/app/data \
 ddsderek/wxchat:latest
 
 if [ $? -eq 0 ]; then
 print_success "微信代理安装完成！"
 else
 print_error "微信代理启动失败！"
 print_info "尝试检查日志..."
 docker logs wxchat 2>/dev/null || echo "无法获取容器日志"
 fi
 
 echo -e "
${BG_GREEN}${WHITE}════════════════════════════════════════════════════════════${NC}"
 echo -e "${BG_GREEN}${WHITE} 所有组件安装完成！ ${NC}"
 echo -e "${BG_GREEN}${WHITE}════════════════════════════════════════════════════════════${NC}"
 echo -e "
${WHITE}安装的服务信息：${NC}"
 echo -e "${CYAN}1. Frp服务器：${NC}"
 echo -e " 端口: 7000"
 echo -e " 管理界面: http://你的IP:7500"
 echo -e " 用户名: admin"
 echo -e " 密码: admin123"
 echo -e "
${CYAN}2. 微信代理：${NC}"
 echo -e " 访问地址: http://你的IP:15680"
 echo -e "
${YELLOW}请及时修改默认密码！${NC}"
 
 press_any_key
}

# 主程序
main() {
 # 检查root权限
 check_root
 
 # 显示欢迎信息
 clear_screen
 echo -e "${PURPLE}"
 echo " _ ___ ____ "
 echo " | | / _ / ___| "
 echo " | | | | | \___ \\"
 echo " | |_| |_| |___) |"
 echo " \___/\___/|____/ "
 echo -e "${NC}"
 print_title
 
 echo -e "${WHITE}欢迎使用VPS容器化部署工具！${NC}"
 echo -e "${YELLOW}本脚本将帮助您快速部署以下服务：${NC}"
 echo -e "${CYAN}• 系统更新${NC}"
 echo -e "${CYAN}• Docker 和 Docker Compose${NC}"
 echo -e "${CYAN}• Frp 服务器${NC}"
 echo -e "${CYAN}• 微信代理${NC}"
 echo -e ""
 echo -e "${GREEN}版本 1.1 - 使用 Docker Run 直接运行容器${NC}"
 
 press_any_key
 
 while true; do
 show_main_menu
 
 case $main_choice in
 1)
 update_system
 press_any_key
 ;;
 2)
 install_docker
 press_any_key
 ;;
 3)
 install_docker_compose
 press_any_key
 ;;
 4)
 while true; do
 show_container_menu
 case $container_choice in
 1)
 install_frps
 ;;
 2)
 install_wxchat
 ;;
 3)
 install_frps
 install_wxchat
 ;;
 4)
 break
 ;;
 *)
 print_error "无效选择，请重新输入！"
 sleep 2
 ;;
 esac
 done
 ;;
 5)
 show_containers
 ;;
 6)
 install_all
 ;;
 7)
 clear_screen
 echo -e "
${GREEN}════════════════════════════════════════════════════════════${NC}"
 echo -e "${GREEN}感谢使用VPS容器化部署工具！${NC}"
 echo -e "${GREEN}再见！${NC}"
 echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}
"
 exit 0
 ;;
 *)
 print_error "无效选择，请重新输入！"
 sleep 2
 ;;
 esac
 done
}

# 运行主程序
main "$@"
