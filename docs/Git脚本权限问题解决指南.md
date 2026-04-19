# Git 脚本权限问题解决指南

## 问题描述

在 GitHub Actions（Linux 环境）中运行 Shell 脚本时出现权限错误：

```
/home/runner/work/_temp/xxx.sh: line 2: script.sh: Permission denied
Error: Process completed with exit code 126.
```

## 问题原因

### 1. Windows 与 Linux 权限差异

| 系统 | 权限模型 | 说明 |
|------|----------|------|
| Windows (NTFS) | ACL | 不使用 Unix 风格的执行权限位 |
| Linux | rwx | 需要执行权限（x）才能运行脚本 |
| Git | 644/755 | 在提交时记录文件模式 |

### 2. Git 文件模式

Git 使用三位八进制数表示文件模式：

- `100644` - 普通文件（不可执行）
- `100755` - 可执行文件
- `120000` - 符号链接

### 3. 问题根源

在 Windows 上提交的 Shell 脚本，Git 默认使用 `100644` 模式。当代码被克隆到 Linux 环境（如 GitHub Actions）时，脚本没有执行权限，导致无法运行。

## 解决方案

### 方法 1：使用 git update-index（推荐）

这是在 Windows 上修改 Git 文件权限的标准方法：

```bash
# 添加执行权限
git update-index --chmod=+x path/to/script.sh

# 移除执行权限
git update-index --chmod=-x path/to/script.sh
```

### 方法 2：批量修改多个文件

```bash
# 修改多个指定文件
git update-index --chmod=+x script1.sh script2.sh script3.sh

# 使用 find 批量修改所有 .sh 文件
find . -name "*.sh" -exec git update-index --chmod=+x {} \;

# 修改某个目录下所有脚本
find buildroot-external/scripts -name "*.sh" -exec git update-index --chmod=+x {} \;
```

### 方法 3：在 Unix/Linux 系统上操作

如果在 Unix/Linux 系统上，可以直接使用 chmod：

```bash
# 修改文件权限
chmod +x script.sh

# 添加到 Git
git add script.sh
```

## 操作步骤

### 步骤 1：检查当前权限

```bash
# 查看文件在 Git 中的模式
git ls-files -s path/to/file

# 输出示例：
# 100644 xxx... 0 path/to/script.sh  (不可执行)
# 100755 xxx... 0 path/to/script.sh  (可执行)
```

### 步骤 2：修改权限

```bash
# 添加执行权限
git update-index --chmod=+x path/to/script.sh
```

### 步骤 3：验证修改

```bash
# 再次查看文件模式
git ls-files -s path/to/file

# 查看暂存区状态
git status --short

# 查看变更详情
git diff --cached --stat
```

### 步骤 4：提交更改

```bash
git commit -m "fix: add execute permission to scripts"
```

### 步骤 5：推送到远程

```bash
git push origin main
```

## 实际案例

### 案例：Home Assistant OS 构建错误

**错误信息：**
```
buildroot-external/scripts/generate-signing-key.sh: Permission denied
Error: Process completed with exit code 126.
```

**诊断过程：**

```bash
# 1. 检查文件权限
$ git ls-files -s buildroot-external/scripts/generate-signing-key.sh
100644 d16dbd48d0753ebfc9d0d312812a2cc5d142 0 buildroot-external/scripts/generate-signing-key.sh
# ↑ 模式是 100644，不可执行

# 2. 检查所有脚本权限
$ git ls-files -s buildroot-external/scripts/*.sh
100644 ... generate-signing-key.sh
100644 ... hdd-image.sh
100644 ... name.sh
100644 ... post-build.sh
100644 ... post-image.sh
100644 ... rauc.sh
100644 ... rootfs-layer.sh
# ↑ 所有脚本都是 100644
```

**修复过程：**

```bash
# 1. 修改所有脚本权限
git update-index --chmod=+x \
  buildroot-external/scripts/generate-signing-key.sh \
  buildroot-external/scripts/hdd-image.sh \
  buildroot-external/scripts/name.sh \
  buildroot-external/scripts/post-build.sh \
  buildroot-external/scripts/post-image.sh \
  buildroot-external/scripts/rauc.sh \
  buildroot-external/scripts/rootfs-layer.sh

# 2. 验证修改
$ git ls-files -s buildroot-external/scripts/*.sh
100755 ... generate-signing-key.sh
100755 ... hdd-image.sh
100755 ... name.sh
100755 ... post-build.sh
100755 ... post-image.sh
100755 ... rauc.sh
100755 ... rootfs-layer.sh
# ↑ 所有脚本已改为 100755

# 3. 提交更改
git commit -m "fix: add execute permission to build scripts"

# 4. 推送
git push origin main
```

## 预防措施

### 1. 配置 Git 自动处理权限

在 `.gitattributes` 文件中添加：

```
# 自动为 Shell 脚本设置执行权限
*.sh text eol=lf
```

注意：`.gitattributes` 主要处理换行符，对于执行权限仍需手动设置。

### 2. 使用 pre-commit 钩子

创建 `.git/hooks/pre-commit`：

```bash
#!/bin/bash
# 自动为 .sh 文件添加执行权限
git diff --cached --name-only | grep '\.sh$' | while read file; do
    git update-index --chmod=+x "$file"
done
```

### 3. CI/CD 中显式设置权限

在 GitHub Actions 中添加步骤：

```yaml
- name: Set script permissions
  run: |
    chmod +x buildroot-external/scripts/*.sh
```

## 常见问题

### Q1: 为什么本地可以运行，GitHub Actions 却不行？

**A:** Windows 文件系统不依赖执行权限位，而 Linux 需要。本地 Git Bash 或 PowerShell 可以直接运行脚本，但 Linux 环境需要文件具有执行权限。

### Q2: chmod +x 和 git update-index --chmod=+x 有什么区别？

**A:**
- `chmod +x`：修改文件系统权限（仅 Unix/Linux 有效）
- `git update-index --chmod=+x`：修改 Git 索引中的文件模式（跨平台）

在 Windows 上，`chmod +x` 不会影响 Git 提交的内容，必须使用 `git update-index`。

### Q3: 如何查看 Git 中所有可执行文件？

```bash
git ls-files -s | grep "^100755"
```

### Q4: 如何撤销执行权限？

```bash
git update-index --chmod=-x path/to/script.sh
```

### Q5: 为什么 .gitattributes 不能解决权限问题？

**A:** `.gitattributes` 主要用于：
- 换行符转换（text, eol）
- 差异比较（diff）
- 合并策略（merge）

它不直接控制文件权限模式。要设置执行权限，仍需使用 `git update-index`。

## 相关命令速查

| 命令 | 说明 |
|------|------|
| `git ls-files -s <file>` | 查看文件模式 |
| `git update-index --chmod=+x <file>` | 添加执行权限 |
| `git update-index --chmod=-x <file>` | 移除执行权限 |
| `git diff --cached --stat` | 查看暂存变更 |
| `find . -name "*.sh"` | 查找所有脚本 |

## 参考资料

- [Git - File Permissions](https://git-scm.com/docs/git-update-index)
- [GitHub Actions - File Permissions](https://docs.github.com/en/actions)
- [Cross-platform Git Permissions](https://stackoverflow.com/questions/1202547/)
