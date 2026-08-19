#!/bin/bash

# SMS Agent 一键部署脚本 (多架构支持 & 参数化配置)
# 包含：Redis 安装、自动识别 amd64/arm64、二进制文件下载、Systemd 服务配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "使用方法: sudo ./install.sh [选项]"
    echo ""
    echo "选项:"
    echo "  --db-user    MySQL 用户名 (安装时必填)"
    echo "  --db-pass    MySQL 密码 (安装时必填)"
    echo "  --db-name    MySQL 数据库名 (安装时必填)"
    echo "  --db-host    MySQL 地址 (默认: 127.0.0.1)"
    echo "  --db-port    MySQL 端口 (默认: 3306)"
    echo "  --http-port  Agent 状态监控端口 (默认: 8080)"
    echo "  --agent-id   自定义 Agent ID (默认: 主机名-架构)"
    echo "  --mem-limit  限制程序最大内存使用，如 128M, 512M (默认: 不限制)"
    echo "  --cpu-limit  限制 CPU 使用率，如 50% (表示限制使用半个核)"
    echo "  --skip-redis 跳过 Redis 安装"
    echo "  --update     仅更新二进制文件并重启服务"
    echo "  --uninstall  卸载 SMS Agent"
    exit 1
}

# 默认参数
DB_HOST="127.0.0.1"
DB_PORT="3306"
HTTP_PORT="8080"
AGENT_ID=""
MEM_LIMIT=""
CPU_LIMIT=""
SKIP_REDIS=false
UPDATE_ONLY=false
UNINSTALL=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --db-user) DB_USER="$2"; shift 2 ;;
    --db-pass) DB_PASS="$2"; shift 2 ;;
    --db-name) DB_NAME="$2"; shift 2 ;;
    --db-host) DB_HOST="$2"; shift 2 ;;
    --db-port) DB_PORT="$2"; shift 2 ;;
    --http-port) HTTP_PORT="$2"; shift 2 ;;
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --mem-limit) MEM_LIMIT="$2"; shift 2 ;;
    --cpu-limit) CPU_LIMIT="$2"; shift 2 ;;
    --skip-redis) SKIP_REDIS=true; shift ;;
    --update) UPDATE_ONLY=true; shift ;;
    --uninstall) UNINSTALL=true; shift ;;
    *) usage ;;
  esac
done

# 1. 检查权限
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请以 root 权限运行此脚本 (使用 sudo)${NC}"
  exit 1
fi

# 2. 处理卸载逻辑
if [ "$UNINSTALL" = true ]; then
    echo -e "${YELLOW}正在卸载 SMS Agent...${NC}"
    systemctl stop sms_agent || true
    systemctl disable sms_agent || true
    rm -f /etc/systemd/system/sms_agent.service
    systemctl daemon-reload
    rm -rf /opt/sms_agent
    echo -e "${GREEN}卸载完成！${NC}"
    exit 0
fi

# 3. 识别系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)  BINARY_ARCH="amd64" ;;
    aarch64) BINARY_ARCH="arm64" ;;
    arm64)   BINARY_ARCH="arm64" ;;
    *) echo -e "${RED}不支持的架构: $ARCH${NC}"; exit 1 ;;
esac
echo -e "${YELLOW}检测到系统架构: $ARCH -> 使用二进制版本: $BINARY_ARCH${NC}"

APP_DIR="/opt/sms_agent"
REPO="SharkMesh/sharksms"

# 4. 处理更新逻辑
if [ "$UPDATE_ONLY" = true ]; then
    if [ ! -f "$APP_DIR/sms_agent" ]; then
        echo -e "${RED}错误: 未检测到已安装的 SMS Agent，请先进行完整安装。${NC}"
        exit 1
    fi
    echo -e "${YELLOW}正在更新 SMS Agent...${NC}"
    
    LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep "browser_download_url.*linux-$BINARY_ARCH" | cut -d '"' -f 4)
    if [ -z "$LATEST_RELEASE_URL" ]; then
        echo -e "${RED}未能找到最新发布版本${NC}"
        exit 1
    fi

    systemctl stop sms_agent || true
    curl -L -o "$APP_DIR/sms_agent" "$LATEST_RELEASE_URL"
    chmod +x "$APP_DIR/sms_agent"
    systemctl restart sms_agent
    
    echo -e "${GREEN}更新成功并已重启服务！${NC}"
    systemctl status sms_agent --no-pager
    exit 0
fi

# 5. 完整安装逻辑 - 校验必填项
if [[ -z "$DB_USER" || -z "$DB_PASS" || -z "$DB_NAME" ]]; then
    echo -e "${RED}错误: 缺少必填参数 --db-user, --db-pass 或 --db-name${NC}"
    usage
fi

# 6. 安装 Redis
if [ "$SKIP_REDIS" = false ]; then
    echo -e "${YELLOW}正在安装 Redis...${NC}"
    if command -v apt-get >/dev/null; then
      apt-get update
      apt-get install -y redis-server
    elif command -v yum >/dev/null; then
      yum install -y epel-release
      yum install -y redis
    else
      echo -e "${RED}不支持的包管理器，请手动安装 Redis${NC}"
      exit 1
    fi

    systemctl enable redis
    systemctl start redis
    echo -e "${GREEN}Redis 安装并启动成功${NC}"
else
    echo -e "${YELLOW}跳过 Redis 安装步骤${NC}"
fi

# 7. 创建应用目录
mkdir -p $APP_DIR
cd $APP_DIR

# 8. 下载二进制文件
echo -e "${YELLOW}正在从 $REPO 下载最新 $BINARY_ARCH 版本...${NC}"

LATEST_RELEASE_URL=$(curl -s https://api.github.com/repos/$REPO/releases/latest | grep "browser_download_url.*linux-$BINARY_ARCH" | cut -d '"' -f 4)

if [ -z "$LATEST_RELEASE_URL" ]; then
  echo -e "${RED}未能找到最新发布版本，请确认公开仓库是否有 Release 产物${NC}"
  exit 1
fi

curl -L -o sms_agent $LATEST_RELEASE_URL
chmod +x sms_agent

# 9. 写入 .env 配置文件
echo -e "${YELLOW}生成配置文件...${NC}"
if [ -z "$AGENT_ID" ]; then
    AGENT_ID="$(hostname)-$(uname -m)"
fi

# 创建非 root 用户运行程序
if ! id "sms_agent" &>/dev/null; then
    useradd -r -s /usr/sbin/nologin sms_agent
fi
chown -R sms_agent:sms_agent $APP_DIR

cat > .env <<EOF
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASS
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_DATABASE=$DB_NAME
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
REDIS_PASSWORD=
HTTP_PORT=$HTTP_PORT
AGENT_ID=$AGENT_ID
EOF

# 构建资源限制和安全沙箱配置
RESOURCE_CONF=""
if [ -n "$MEM_LIMIT" ]; then
    # Go 的 GOMEMLIMIT 需要特定的单位格式 (B, KiB, MiB, GiB)
    # 并且不识别单字母 G/M，必须转换
    GO_MEM_LIMIT=$MEM_LIMIT
    if [[ $MEM_LIMIT =~ ^([0-9]+)G$ ]]; then
        GO_MEM_LIMIT="${BASH_REMATCH[1]}GiB"
    elif [[ $MEM_LIMIT =~ ^([0-9]+)M$ ]]; then
        GO_MEM_LIMIT="${BASH_REMATCH[1]}MiB"
    fi

    RESOURCE_CONF="$RESOURCE_CONF
MemoryLimit=$MEM_LIMIT
MemoryMax=$MEM_LIMIT
Environment=GOMEMLIMIT=$GO_MEM_LIMIT"
fi

if [ -n "$CPU_LIMIT" ]; then
    RESOURCE_CONF="$RESOURCE_CONF
CPUQuota=$CPU_LIMIT"
fi

cat > /etc/systemd/system/sms_agent.service <<EOF
[Unit]
Description=SMS Agent Service ($BINARY_ARCH)
After=network.target redis.target

[Service]
Type=simple
User=sms_agent
Group=sms_agent
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/sms_agent
Restart=always
RestartSec=5

# 资源限制
$RESOURCE_CONF

# 安全沙箱 (Sandbox)
NoNewPrivileges=yes
PrivateTmp=yes
DeviceAllow=/dev/null rw
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$APP_DIR
CapabilityBoundingSet=
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sms_agent
systemctl restart sms_agent

echo -e "${GREEN}==== 部署成功 ====${NC}"
echo -e "${YELLOW}服务状态：${NC}"
systemctl status sms_agent --no-pager
echo -e "${YELLOW}查看日志：${NC} journalctl -u sms_agent -f"