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

# 分隔线函数
print_separator() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# 标题函数
print_title() {
    clear
    echo -e "${BG_BLUE}${WHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BG_BLUE}${WHITE}                    VPS 自动化部署脚本                    ${NC}"
    echo -e "${BG_BLUE}${WHITE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# 成功消息
print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

# 错误消息
print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

# 信息消息
print_info() {
    echo -e "  ${BLUE}➜${NC} $1"
}

# 警告消息
print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要以root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查系统
check_system() {
    print_info "检测系统信息..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    print_success "系统: $OS $VER"
    
    # 检查系统架构
    ARCH=$(uname -m)
    if [[ $ARCH != "x86_64" && $ARCH != "aarch64" ]]; then
        print_warning "非标准架构: $ARCH，某些功能可能受限"
    fi
}

# 更新系统包
update_system() {
    print_title
    echo -e "${CYAN}步骤 1: 更新系统包${NC}"
    print_separator
    
    print_info "正在更新包列表..."
    
    if command -v apt &> /dev/null; then
        apt update
        if [ $? -eq 0 ]; then
            print_success "包列表更新成功"
            
            print_info "正在升级已安装的包..."
            apt upgrade -y
            apt autoremove -y
            apt autoclean
            print_success "系统更新完成"
        fi
    elif command -v yum &> /dev/null; then
        yum update -y
        if [ $? -eq 0 ]; then
            print_success "系统更新完成"
        fi
    elif command -v dnf &> /dev/null; then
        dnf update -y
        if [ $? -eq 0 ]; then
            print_success "系统更新完成"
        fi
    else
        print_error "不支持的包管理器"
        return 1
    fi
    
    echo ""
    read -p "按 Enter 键继续..."
}

# 安装Docker
install_docker() {
    print_title
    echo -e "${CYAN}步骤 2: 安装 Docker${NC}"
    print_separator
    
    # 检查Docker是否已安装
    if command -v docker &> /dev/null; then
        print_success "Docker 已安装"
        docker --version
    else
        print_info "正在安装 Docker..."
        
        # 根据系统选择安装方法
        if command -v apt &> /dev/null; then
            # Ubuntu/Debian
            apt update
            apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt update
            apt install -y docker-ce docker-ce-cli containerd.io
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
            print_error "不支持的包管理器"
            return 1
        fi
        
        # 启动并启用Docker
        systemctl start docker
        systemctl enable docker
        
        # 将当前用户加入docker组（如果存在非root用户）
        if [ ! -z "$SUDO_USER" ]; then
            usermod -aG docker $SUDO_USER
            print_info "已将用户 $SUDO_USER 加入 docker 组"
            print_warning "需要重新登录才能生效"
        fi
        
        # 验证安装
        if docker --version &> /dev/null; then
            print_success "Docker 安装成功"
            docker --version
        else
            print_error "Docker 安装失败"
            return 1
        fi
    fi
    
    echo ""
    read -p "按 Enter 键继续..."
}

# 安装Docker Compose
install_docker_compose() {
    print_title
    echo -e "${CYAN}步骤 3: 安装 Docker Compose${NC}"
    print_separator
    
    # 检查Docker Compose是否已安装
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose 已安装"
        docker-compose --version
    else
        print_info "正在安装 Docker Compose..."
        
        # 获取最新版本
        COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        
        if [ -z "$COMPOSE_VERSION" ]; then
            COMPOSE_VERSION="v2.20.0"  # 备用版本
        fi
        
        # 下载并安装
        ARCH=$(uname -m)
        if [ "$ARCH" = "aarch64" ]; then
            ARCH="aarch64"
        elif [ "$ARCH" = "x86_64" ]; then
            ARCH="x86_64"
        else
            ARCH="x86_64"  # 默认
        fi
        
        curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$ARCH" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        
        # 验证安装
        if docker-compose --version &> /dev/null; then
            print_success "Docker Compose 安装成功"
            docker-compose --version
        else
            print_error "Docker Compose 安装失败"
            return 1
        fi
    fi
    
    echo ""
    read -p "按 Enter 键继续..."
}

# 显示容器选择菜单
show_container_menu() {
    print_title
    echo -e "${CYAN}步骤 4: 选择要安装的容器${NC}"
    print_separator
    
    echo -e "${YELLOW}可用容器列表:${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} Frp 服务器 (frps) - 内网穿透服务器端"
    echo -e "${GREEN}2.${NC} 微信代理 (ddsderek/wxchat:latest) - 微信网页版代理"
    echo -e "${GREEN}3.${NC} 安装以上所有容器"
    echo -e "${RED}4.${NC} 跳过容器安装"
    echo ""
    print_separator
}

# 安装frps容器
install_frps() {
    print_info "正在安装 Frp 服务器..."
    
    # 创建frps配置目录
    FRPS_DIR="/opt/frps"
    mkdir -p $FRPS_DIR
    
    # 创建frps配置文件
    cat > $FRPS_DIR/frps.toml << EOF
# frps 配置文件
bindPort = 7000
vhostHTTPPort = 8080
vhostHTTPSPort = 8443
dashboardPort = 7500
dashboardUser = "admin"
dashboardPwd = "admin123"
token = "$(openssl rand -hex 16)"

# 日志配置
log.level = "info"
log.maxDays = 3
log.to = "console"

# 其他配置
subdomainHost = "example.com"
tlsOnly = false
EOF
    
    # 创建docker-compose文件
    cat > $FRPS_DIR/docker-compose.yml << EOF
version: '3'

services:
  frps:
    image: snowdreamtech/frps:latest
    container_name: frps
    restart: always
    ports:
      - "7000:7000"     # 绑定端口
      - "7500:7500"     # 控制面板端口
      - "8080:8080"     # HTTP端口
      - "8443:8443"     # HTTPS端口
    volumes:
      - ./frps.toml:/etc/frp/frps.toml
    command: ["-c", "/etc/frp/frps.toml"]
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF
    
    # 启动frps容器
    cd $FRPS_DIR
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "Frp 服务器安装完成！"
        echo ""
        echo -e "${CYAN}配置信息:${NC}"
        echo -e "  服务器地址: $(curl -s ifconfig.me)"
        echo -e "  控制面板: http://$(curl -s ifconfig.me):7500"
        echo -e "  用户名: admin"
        echo -e "  密码: admin123"
        echo -e "  Token: $(grep 'token =' $FRPS_DIR/frps.toml | cut -d'"' -f2)"
        echo ""
        print_warning "请及时修改默认密码和Token！"
    else
        print_error "Frp 服务器安装失败"
    fi
}

# 安装微信代理容器
install_wxchat() {
    print_info "正在安装微信代理..."
    
    # 创建wxchat配置目录
    WXCHAT_DIR="/opt/wxchat"
    mkdir -p $WXCHAT_DIR
    
    # 创建docker-compose文件
    cat > $WXCHAT_DIR/docker-compose.yml << EOF
version: '3'

services:
  wxchat:
    image: ddsderek/wxchat:latest
    container_name: wxchat
    restart: always
    ports:
      - "8081:80"     # Web界面端口
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./data:/app/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF
    
    # 创建nginx代理配置文件（可选）
    cat > $WXCHAT_DIR/nginx-proxy.conf << EOF
# 可选：Nginx反向代理配置
# 可以复制到 /etc/nginx/conf.d/ 目录下
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    # 启动wxchat容器
    cd $WXCHAT_DIR
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "微信代理安装完成！"
        echo ""
        echo -e "${CYAN}访问信息:${NC}"
        echo -e "  Web界面: http://$(curl -s ifconfig.me):8081"
        echo ""
        print_info "配置文件位置: $WXCHAT_DIR"
    else
        print_error "微信代理安装失败"
    fi
}

# 安装选择的容器
install_containers() {
    while true; do
        show_container_menu
        
        read -p "$(echo -e "${YELLOW}请选择 (1-4): ${NC}")" choice
        
        case $choice in
            1)
                print_info "您选择了: Frp 服务器"
                install_frps
                break
                ;;
            2)
                print_info "您选择了: 微信代理"
                install_wxchat
                break
                ;;
            3)
                print_info "您选择了: 安装所有容器"
                install_frps
                echo ""
                install_wxchat
                break
                ;;
            4)
                print_info "跳过容器安装"
                break
                ;;
            *)
                print_error "无效选择，请重新输入"
                sleep 2
                ;;
        esac
    done
}

# 显示系统信息
show_system_info() {
    print_title
    echo -e "${CYAN}系统信息概览${NC}"
    print_separator
    
    echo -e "${YELLOW}系统信息:${NC}"
    echo -e "  OS: $(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || uname -om)"
    echo -e "  内核: $(uname -r)"
    echo -e "  架构: $(uname -m)"
    echo -e "  IP地址: $(curl -s ifconfig.me)"
    
    echo ""
    echo -e "${YELLOW}Docker 信息:${NC}"
    if command -v docker &> /dev/null; then
        echo -e "  版本: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        echo -e "  容器数: $(docker ps -q | wc -l) 个运行中"
    else
        echo -e "  Docker: 未安装"
    fi
    
    echo ""
    echo -e "${YELLOW}已安装的容器:${NC}"
    if command -v docker &> /dev/null; then
        if [ $(docker ps -q | wc -l) -gt 0 ]; then
            docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | while read line; do
                echo -e "  $line"
            done
        else
            echo -e "  暂无运行中的容器"
        fi
    fi
    
    echo ""
    print_separator
}

# 显示主菜单
show_main_menu() {
    print_title
    echo -e "${CYAN}主菜单${NC}"
    print_separator
    
    echo -e "${GREEN}1.${NC} 更新系统包"
    echo -e "${GREEN}2.${NC} 安装 Docker"
    echo -e "${GREEN}3.${NC} 安装 Docker Compose"
    echo -e "${GREEN}4.${NC} 安装容器"
    echo -e "${GREEN}5.${NC} 查看系统信息"
    echo -e "${GREEN}6.${NC} 一键安装全部"
    echo -e "${RED}0.${NC} 退出"
    echo ""
    print_separator
}

# 一键安装全部
install_all() {
    print_title
    echo -e "${CYAN}一键安装全部${NC}"
    print_separator
    
    print_info "开始一键安装所有组件..."
    echo ""
    
    update_system
    echo ""
    
    install_docker
    echo ""
    
    install_docker_compose
    echo ""
    
    print_info "即将进入容器安装选择..."
    sleep 2
    install_containers
    echo ""
    
    show_system_info
    
    print_success "所有组件安装完成！"
    read -p "按 Enter 键返回主菜单..."
}

# 主函数
main() {
    check_root
    check_system
    
    while true; do
        show_main_menu
        
        read -p "$(echo -e "${YELLOW}请选择操作 (0-6): ${NC}")" choice
        
        case $choice in
            1)
                update_system
                ;;
            2)
                install_docker
                ;;
            3)
                install_docker_compose
                ;;
            4)
                install_containers
                ;;
            5)
                show_system_info
                read -p "按 Enter 键返回主菜单..."
                ;;
            6)
                install_all
                ;;
            0)
                print_title
                echo -e "${GREEN}感谢使用 VPS 部署脚本！${NC}"
                echo ""
                echo -e "安装的容器管理命令:"
                echo -e "  ${CYAN}查看容器状态:${NC} docker ps"
                echo -e "  ${CYAN}查看frps日志:${NC} docker logs frps"
                echo -e "  ${CYAN}查看wxchat日志:${NC} docker logs wxchat"
                echo -e "  ${CYAN}重启frps:${NC} cd /opt/frps && docker-compose restart"
                echo -e "  ${CYAN}重启wxchat:${NC} cd /opt/wxchat && docker-compose restart"
                echo ""
                print_separator
                exit 0
                ;;
            *)
                print_error "无效选择，请重新输入"
                sleep 2
                ;;
        esac
    done
}

# 运行主函数
main
