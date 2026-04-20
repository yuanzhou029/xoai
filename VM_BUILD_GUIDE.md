# Home Assistant OS 虚拟机编译完整指导手册

> **最后更新**: 2026-04-20
> **项目仓库**: https://github.com/yuanzhou029/xoai.git
> **文档版本**: v2.0

---

## 目录

1. [环境要求](#环境要求)
2. [完整安装流程](#完整安装流程)
3. [一键安装脚本](#一键安装脚本)
4. [编译监控](#编译监控)
5. [常见问题解决](#常见问题解决)
6. [编译目标说明](#编译目标说明)
7. [输出文件说明](#输出文件说明)

---

## 环境要求

### 硬件要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| **系统** | Ubuntu 22.04 / Debian 11+ (64位) | Debian Testing (trixie) |
| **CPU** | 4 核心 | 8 核心以上 |
| **内存** | 8 GB | 16 GB |
| **磁盘** | 50 GB | 100 GB SSD |
| **网络** | 稳定连接 | 100 Mbps+ |

### 软件要求

- Git 2.30+
- Docker 20.10+
- GCC 10+
- Make 4.3+

---

## 完整安装流程

### 系统基础配置
# 更新包列表并安装sudo
apt update

apt upgrade -y

apt install -y sudo

sudo usermod -aG sudo hass


### 步骤 1: 配置系统软件源（Debian Testing）

**说明**: 使用清华大学镜像源加速软件包下载。

```bash
cat <<EOF | sudo tee /etc/apt/sources.list
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free
EOF
```

### 步骤 2: 安装基础依赖

**说明**: 安装编译所需的所有工具链和依赖包。

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

**说明**: Docker 用于构建容器镜像，必须从官方源安装。

**重要**: Debian Testing 不被 Docker 官方支持，需使用 `bookworm` (Debian 12 Stable) 作为基础。

```bash
# 3.1 创建密钥目录
sudo install -m 0755 -d /etc/apt/keyrings

# 3.2 下载 Docker GPG 密钥
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 3.3 添加 Docker APT 源（使用 bookworm）
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3.4 更新并安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 3.5 配置 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker

# 3.6 将当前用户加入 docker 组
sudo usermod -aG docker $USER
sudo chmod a+r /etc/apt/keyrings/docker.gpg
# 3.7 使组权限立即生效
newgrp docker
```

**验证 Docker 安装**:

```bash
docker --version
# 预期输出: Docker version 29.4.0, build 9d7ad9f
```

### 步骤 4: 从 GitHub 拉取项目

**说明**: 从 GitHub 仓库克隆项目并初始化所有子模块。

```bash
# 4.1 克隆项目
git clone https://github.com/yuanzhou029/xoai.git ~/operating-system

# 4.2 进入项目目录
cd ~/operating-system

# 4.3 初始化并更新所有子模块（包括 Buildroot）
git submodule update --init --recursive
```

### 步骤 5: 创建缓存目录

**说明**: Buildroot 需要 `/cache` 目录存储下载的源码包。

**重要**: 此步骤必须执行，否则编译会因权限问题失败。

```bash
# 5.1 创建缓存目录
sudo mkdir -p /cache

# 5.2 设置权限
sudo chown -R $USER:$USER /cache
```

### 步骤 6: 配置编译目标

**说明**: 选择要编译的目标平台。

```bash
# 6.1 查看可用编译目标
make help

# 6.2 配置编译目标（选择其一）
# 选项 A: 通用 x86_64（推荐用于虚拟机测试）
make generic_x86_64-config

# 选项 B: OVA 虚拟机镜像（用于 VirtualBox/VMware）
make ova-config

# 选项 C: Raspberry Pi 4
make rpi4_64-config

# 选项 D: Raspberry Pi 5
make rpi5_64-config
```

**预期输出**:

```
Run 'make <target>' to build a target image.
Run 'make <target>-config' to configure buildroot for a target.

Supported targets: generic_aarch64 generic_x86_64 green khadas_vim3 odroid_c2 odroid_c4 odroid_m1 odroid_m1s odroid_n2 ova rpi3_64 rpi4_64 rpi5_64 yellow

Unknown Makefile targets fall back to Buildroot make - for details run 'make buildroot-help'
```

### 步骤 7: 开始编译

**说明**: 使用多核并行编译加速构建过程。

**方式 A: 前台编译（可看到实时输出）**:

```bash
make -j$(nproc)
```

**方式 B: 后台编译（推荐，使用 nohup）**:

```bash
# 启动后台编译
nohup make -j$(nproc) > build.log 2>&1 &

# 查看进程
ps aux | grep make

# 实时查看日志
tail -f build.log
```

---

## 一键安装脚本

**说明**: 复制以下全部内容直接执行，完成从系统配置到开始编译的全过程。

```bash
#!/bin/bash
set -e

echo "=== 步骤 1: 配置软件源 ==="
cat <<EOF | sudo tee /etc/apt/sources.list
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security trixie-security main contrib non-free
EOF

echo "=== 步骤 2: 安装基础依赖 ==="
sudo apt update && sudo apt install -y \
    build-essential bc bison flex libssl-dev make \
    libc6-dev libncurses-dev \
    cpio file git unzip rsync wget curl python3 python3-dev python3-pip \
    texinfo help2man automake autoconf libtool pkg-config \
    bzip2 pigz graphviz jq qemu-utils skopeo \
    apt-transport-https ca-certificates gnupg lsb-release

echo "=== 步骤 3: 安装 Docker ==="
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

echo "=== 步骤 4: 拉取项目 ==="
git clone https://github.com/yuanzhou029/xoai.git ~/operating-system
cd ~/operating-system
git submodule update --init --recursive

echo "=== 步骤 5: 创建缓存目录 ==="
sudo mkdir -p /cache
sudo chown -R $USER:$USER /cache

echo "=== 步骤 6: 配置编译目标 ==="
make ova-config

echo "=== 步骤 7: 开始编译 ==="
echo "编译将在后台运行，日志输出到 build.log"
nohup make -j$(nproc) > build.log 2>&1 &

echo "=== 安装完成 ==="
echo "使用 'tail -f build.log' 查看编译进度"
```

---

## 编译监控

### 实时查看编译日志

```bash
# 方式 A: 查看自定义日志文件
tail -f build.log

# 方式 B: 查看 Buildroot 官方日志
tail -f output/build/buildroot.log
```

### 查看编译进度

```bash
# 查看当前正在编译的包
ls -lh output/build/

# 查看已下载的源码包
ls -lh /cache/

# 查看编译进程
ps aux | grep make
```

### 编译完成后查看输出

```bash
# 查看输出文件
ls -lh output/images/

# 验证 OVA 文件
file output/images/haos_*.ova

# 查看 OVA 文件大小
du -h output/images/haos_*.ova
```

---

## 常见问题解决

### 问题 1: 磁盘空间不足

**症状**: 编译过程中提示 "No space left on device"

**解决方案**:

```bash
# 清理编译中间文件
make clean

# 完全清理（包括配置）
make distclean

# 清理缓存
rm -rf /cache/*
```

### 问题 2: 网络下载慢

**症状**: 下载源码包速度很慢或超时

**解决方案**:

```bash
# 使用国内镜像（编辑 output/.config）
# 添加或修改以下配置：
BR2_KERNEL_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/kernel/"
BR2_GNU_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/gnu/"
BR2_LUA_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/lua/"

# 重新配置并编译
make olddefconfig
make -j$(nproc)
```

### 问题 3: 权限问题

**症状**: "Permission denied" 或 "cannot create directory"

**解决方案**:

```bash
# 修复输出目录权限
sudo chown -R $USER:$USER output/

# 修复缓存目录权限
sudo chown -R $USER:$USER /cache/

# 修复 Docker socket 权限
sudo chmod 666 /var/run/docker.sock
```

### 问题 4: Docker 权限问题

**症状**: "permission denied while trying to connect to the Docker daemon"

**解决方案**:

```bash
# 方式 A: 使组权限立即生效
newgrp docker

# 方式 B: 重新登录
logout
# 然后重新登录

# 方式 C: 使用 sudo
sudo docker ...
```

### 问题 5: 子模块初始化失败

**症状**: "fatal: not a git repository" 或子模块目录为空

**解决方案**:

```bash
# 重新初始化子模块
git submodule deinit -f --all
git submodule update --init --recursive
```

### 问题 6: Makefile 目标不显示

**症状**: `make help` 只显示 "configs" 而不是所有目标

**解决方案**:

```bash
# 拉取最新修复
git pull origin main

# 重新配置
make distclean
make ova-config
```

---

## 编译目标说明

| 目标 | 架构 | 说明 | 适用场景 |
|------|------|------|----------|
| `generic_x86_64` | x86_64 | 通用 x86_64 系统 | 虚拟机测试、物理机 |
| `ova` | x86_64 | OVA 虚拟机镜像 | VirtualBox、VMware |
| `generic_aarch64` | ARM64 | 通用 ARM64 系统 | ARM 服务器、开发板 |
| `rpi3_64` | ARM64 | Raspberry Pi 3 (64位) | 树莓派 3 |
| `rpi4_64` | ARM64 | Raspberry Pi 4 (64位) | 树莓派 4 |
| `rpi5_64` | ARM64 | Raspberry Pi 5 (64位) | 树莓派 5 |
| `odroid_c2` | ARM64 | ODROID-C2 | ODROID 开发板 |
| `odroid_c4` | ARM64 | ODROID-C4 | ODROID 开发板 |
| `odroid_n2` | ARM64 | ODROID-N2 | ODROID 开发板 |
| `odroid_m1` | ARM64 | ODROID-M1 | ODROID 开发板 |
| `odroid_m1s` | ARM64 | ODROID-M1S | ODROID 开发板 |
| `khadas_vim3` | ARM64 | Khadas VIM3 | Khadas 开发板 |
| `green` | ARM64 | Green 设备 | 绿联设备 |
| `yellow` | ARM64 | Yellow 设备 | 黄色设备 |

---

## 输出文件说明

### 编译输出位置

```
output/images/
├── haos_ova-*.ova          # OVA 虚拟机镜像（ova 目标）
├── haos_generic-x86_64-*.img.gz  # 系统镜像（generic_x86_64 目标）
├── haos_rpi4-64-*.img.gz   # Raspberry Pi 4 镜像
└── ...
```

### 文件类型说明

| 文件类型 | 说明 | 使用方式 |
|----------|------|----------|
| `.ova` | OVA 虚拟机镜像 | 导入 VirtualBox/VMware |
| `.img.gz` | 压缩的系统镜像 | 解压后写入 SD 卡或磁盘 |
| `.vmdk` | VMware 磁盘镜像 | 直接用于 VMware |
| `.vdi` | VirtualBox 磁盘镜像 | 直接用于 VirtualBox |

### 使用 OVA 镜像

**VirtualBox**:

```bash
# 导入 OVA
VBoxManage import output/images/haos_ova-*.ova

# 或通过 GUI: 文件 -> 导入虚拟电脑
```

**VMware**:

```bash
# 通过 GUI: 文件 -> 打开 -> 选择 OVA 文件
```

### 使用 IMG 镜像

**写入 SD 卡**:

```bash
# 解压
gunzip haos_rpi4-64-*.img.gz

# 写入 SD 卡（替换 /dev/sdX 为实际设备）
sudo dd if=haos_rpi4-64-*.img of=/dev/sdX bs=4M status=progress
sync
```

---

## 编译时间参考

| 阶段 | 时间 | 说明 |
|------|------|------|
| **首次编译** | 2-4 小时 | 下载所有源码包并编译 |
| **增量编译** | 10-30 分钟 | 仅重新编译修改的部分 |
| **清理后编译** | 1-2 小时 | 不重新下载源码包 |

**影响因素**:
- CPU 核心数（更多核心 = 更快）
- 网络速度（首次编译需下载大量源码）
- 磁盘速度（SSD 比 HDD 快 2-3 倍）

---

## 高级配置

### 使用 Docker 容器编译

**说明**: 在 Docker 容器中进行编译，保持环境隔离。

```bash
# 构建编译容器
docker build -t haos-builder .

# 运行编译
docker run -it --rm \
    -v $(pwd):/build \
    -v $(pwd)/output:/build/output \
    -v /cache:/cache \
    haos-builder \
    make generic_x86_64
```

### 并行编译优化

**说明**: 根据硬件配置调整并行编译参数。

```bash
# 使用所有 CPU 核心
make -j$(nproc)

# 使用 8 个并行任务（适用于 8 核 CPU）
make -j8

# 使用 CPU 核心数的 1.5 倍（适用于 I/O 密集型任务）
make -j$(($(nproc) * 3 / 2))
```

### 编译特定组件

**说明**: 仅编译某个组件，而不是整个系统。

```bash
# 仅编译 Linux 内核
make linux-rebuild

# 仅编译某个包
make <package-name>-rebuild

# 进入配置菜单
make menuconfig
```

---

## 故障排除

### 编译失败诊断

**步骤 1**: 查看错误日志

```bash
# 查看最后的错误信息
tail -100 build.log

# 查看特定包的构建日志
tail -100 output/build/<package-name>/.stamp_build
```

**步骤 2**: 检查磁盘空间

```bash
df -h
```

**步骤 3**: 检查内存使用

```bash
free -h
```

**步骤 4**: 检查编译进程

```bash
ps aux | grep make
```

### 常见错误代码

| 错误代码 | 说明 | 解决方案 |
|----------|------|----------|
| `error 1` | 一般性错误 | 查看详细日志 |
| `error 2` | Makefile 错误 | 检查 Makefile 语法 |
| `error 137` | 内存不足 | 增加内存或减少并行数 |
| `error 139` | 段错误 | 检查工具链版本 |

---

## 附录

### 项目结构

```
operating-system/
├── buildroot/              # Buildroot 主目录（子模块）
├── buildroot-external/     # 外部配置和包
│   ├── configs/           # 编译目标配置
│   ├── board/             # 板级支持包
│   └── package/           # 自定义包
├── output/                 # 编译输出目录
│   ├── build/             # 构建中间文件
│   ├── images/            # 最终镜像文件
│   └── host/              # 主机工具
├── Makefile               # 项目 Makefile
└── VM_BUILD_GUIDE.md      # 本文档
```

### 相关链接

- [Home Assistant 官方文档](https://www.home-assistant.io/)
- [Buildroot 官方文档](https://buildroot.org/downloads/manual/manual.html)
- [Home Assistant OS 开发文档](https://developers.home-assistant.io/docs/operating-system/)
- [项目 GitHub 仓库](https://github.com/yuanzhou029/xoai)

---

**文档结束**

如有问题，请参考"常见问题解决"章节或查看项目 GitHub Issues。
