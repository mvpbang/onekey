#!/bin/bash
set -euo pipefail

echo "=== Alibaba Cloud Linux 3.x Docker‑CE 一键安装 (VPC 网络) ==="
echo "开始时间：$(date '+%Y-%m-%d %H:%M:%S')"

# 1. 添加 Docker‑CE 仓库
echo "[1/5] 添加 Docker‑CE repo"
dnf config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

echo "[2/5] 替换为 VPC 内网镜像地址"
sed -i 's#https://mirrors.aliyun.com#http://mirrors.cloud.aliyuncs.com#g' /etc/yum.repos.d/docker-ce.repo

# 2. 安装 Docker‑CE 及相关组件
echo "[3/5] 安装 Docker"
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 3. 系统性能调优
echo "[4/5] 配置内核与网络优化参数"
SYSCTL_FILE="/etc/sysctl.d/51-container-optimized.conf"
if [[ -f "$SYSCTL_FILE" ]]; then
    echo "  => $SYSCTL_FILE 已存在，跳过写入"
else
    cat <<'EOF' > "$SYSCTL_FILE"
# container‑Optimized Default Parameters
kernel.softlockup_panic = 1
kernel.pid_max = 4194303
kernel.softlockup_all_cpu_backtrace = 1
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_thresh2 = 1024
net.ipv4.tcp_wmem = 4096 12582912 16777216
net.ipv4.tcp_rmem = 4096 12582912 16777216
net.ipv4.ip_forward = 1
net.ipv4.tcp_max_syn_backlog = 8096
net.core.netdev_max_backlog = 16384
net.bridge.bridge-nf-call-iptables = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.somaxconn = 32768
fs.file-max = 2097152
fs.inotify.max_queued_events = 16384
fs.inotify.max_user_instances = 16384
fs.inotify.max_user_watches = 524288
vm.max_map_count = 262144
user.max_user_namespaces = 0
EOF
    sysctl --system
fi

# 4. 优化 daemon.json 配置
echo "[5/5] 写入 daemon.json 优化配置"
mkdir -p /etc/docker
cat <<'EOF' > /etc/docker/daemon.json
{
  "bip": "172.32.200.1/23",
  "fixed-cidr": "172.32.200.1/23",
  "default-address-pools": [
    {
      "base": "172.32.210.1/21",
      "size": 28
    }
  ],
  "registry-mirrors": ["https://jnxt8d8b.mirror.aliyuncs.com"],
  "insecure-registries": ["127.0.0.1"],
  "max-concurrent-downloads": 10,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "1024m",
    "max-file": "3"
  }
}
EOF

# 启动并启用 Docker
echo "启动并设置 Docker 开机自启"
systemctl enable --now docker

echo "Docker 安装完成，当前 Docker 信息："
docker info

echo "结束时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo "=== 完成 ==="
