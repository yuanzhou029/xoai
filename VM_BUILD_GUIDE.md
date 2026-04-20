# Home Assistant OS 虚拟机编译快速指南

## 环境要求

- **系统**: Ubuntu 22.04 LTS / Debian 11+ (64位)
- **CPU**: 4核心以上
- **内存**: 8GB+ (推荐 16GB)
- **磁盘**: 50GB+ 可用空间
- **网络**: 稳定连接

---

## 完整安装流程（一键复制）

### 步骤 1: 配置系统软件源（Debian Testing）

```bash
cat <<EOF | sudo tee /etc/apt/sources.list
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free
EOF
```

### 步骤 2: 安装基础依赖

```bash
sudo apt update && sudo apt install -y \
    build-essential bc bison flex libssl-dev make \
    libc6-dev libncurses-dev \
    cpio file git unzip rsync wget curl python3 python3-dev python3-pip \
    texinfo help2man automake autoconf libtool pkg-config \
    bzip2 pigz graphviz jq qemu-utils skopeo \
    apt-transport-https ca-certificates gnupg lsb-release
```

### 步骤 3: 安装 Docker

```bash
# 创建密钥目录并下载 Docker GPG 密钥
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加 Docker APT 源（使用 bookworm）
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新并安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 配置 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
```

### 步骤 4: 从 GitHub 拉取项目

```bash
git clone https://github.com/yuanzhou029/xoai.git ~/operating-system
cd ~/operating-system
git submodule update --init --recursive
```

### 步骤 5: 编译项目

```bash
# 查看可用编译目标
make help

# 配置编译目标（选择其一）
make generic_x86_64-config  # 通用 x86_64（推荐用于虚拟机测试）
# 或
make ova-config             # OVA 虚拟机镜像

# 开始编译
make -j$(nproc)
```

---

## 一键完整安装脚本

**复制以下全部内容直接执行：**

```bash
# 步骤 1: 配置软件源
cat <<EOF | sudo tee /etc/apt/sources.list
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free
EOF

# 步骤 2: 安装基础依赖
sudo apt update && sudo apt install -y \
    build-essential bc bison flex libssl-dev make \
    libc6-dev libncurses-dev \
    cpio file git unzip rsync wget curl python3 python3-dev python3-pip \
    texinfo help2man automake autoconf libtool pkg-config \
    bzip2 pigz graphviz jq qemu-utils skopeo \
    apt-transport-https ca-certificates gnupg lsb-release

# 步骤 3: 安装 Docker
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# 步骤 4: 拉取项目
git clone https://github.com/yuanzhou029/xoai.git ~/operating-system
cd ~/operating-system
git submodule update --init --recursive

# 步骤 5: 配置并编译
make generic_x86_64-config
make -j$(nproc)
```

---

## 编译监控

```bash
# 实时查看编译日志
tail -f output/build/buildroot.log

# 查看当前编译进度
ls -lh output/build/

# 编译完成后查看输出
ls -lh output/images/
```

---

## 常见问题

### 磁盘空间不足

```bash
make clean        # 清理中间文件
make distclean    # 完全清理
```

### 网络下载慢

```bash
# 使用国内镜像（编辑 buildroot/.config）
BR2_KERNEL_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/kernel/"
BR2_GNU_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/gnu/"
```

### 权限问题

```bash
sudo chown -R $USER:$USER output/
sudo chmod 666 /var/run/docker.sock
```

### Docker 权限问题

```bash
# 如果 docker 命令提示权限不足
newgrp docker
# 或重新登录
```

---

## 编译时间

- **首次编译**: 2-4 小时
- **增量编译**: 10-30 分钟

---

## 输出文件

- `output/images/haos_*.img.gz` - 系统镜像
- `output/images/haos_*.ova` - OVA 虚拟机镜像

---

## 编译目标说明

| 目标 | 说明 | 适用场景 |
|------|------|----------|
| `generic_x86_64` | 通用 x86_64 系统 | 虚拟机测试 |
| `ova` | OVA 虚拟机镜像 | VirtualBox/VMware |
| `rpi4_64` | Raspberry Pi 4 (64位) | 树莓派 4 |
| `rpi5_64` | Raspberry Pi 5 (64位) | 树莓派 5 |
| `generic_aarch64` | 通用 ARM64 系统 | ARM 设备 |

---

## Docker 编译（可选）

```bash
docker build -t haos-builder .
docker run -it --rm \
    -v $(pwd):/build \
    -v $(pwd)/output:/build/output \
    haos-builder \
    make generic_x86_64
```
