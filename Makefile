# 获取当前工作目录 - 使用多种方法确保在 Docker 环境中正常工作
BUILDDIR?=$(or $(CURDIR),$(shell pwd),/build)
BUILDROOT:=$(BUILDDIR)/buildroot
BUILDROOT_EXTERNAL:=$(BUILDDIR)/buildroot-external
DEFCONFIG_DIR := $(BUILDROOT_EXTERNAL)/configs


# 目录结构：

# operating-system/
# ├── buildroot/           # BUILDROOT
# ├── buildroot-external/  # BUILDROOT_EXTERNAL
# │   └── configs/         # DEFCONFIG_DIR
# └── output/              # O (输出目录)

TARGETS := $(notdir $(patsubst %_defconfig,%,$(wildcard $(DEFCONFIG_DIR)/*_defconfig)))  #目标自动发现
TARGETS_CONFIG := $(notdir $(patsubst %_defconfig,%-config,$(wildcard $(DEFCONFIG_DIR)/*_defconfig)))

# 如果尚未在命令行中设置 O 变量，请进行设置
# 如果 O 未在命令行指定 → 默认 output/
# 如果 O 在命令行指定 → 转换为绝对路径
ifneq ("$(origin O)", "command line")
O := $(BUILDDIR)/output
else
override O := $(BUILDDIR)/$(O)
endif

################################################################################
#静默模式检测
SILENT := $(findstring s,$(word 1, $(MAKEFLAGS)))

#打印函数
define print
	$(if $(SILENT),,$(info $1))
endef

# 颜色定义
COLOR_STEP := $(shell tput smso 2>/dev/null)  # 高亮
COLOR_WARN := $(shell (tput setab 3; tput setaf 0) 2>/dev/null) # 黄底黑字
TERM_RESET := $(shell tput sgr0 2>/dev/null)  # 重置

################################################################################

#目标定义

#并行控制  作用：禁止这些目标并行执行（避免冲突）
.NOTPARALLEL: $(TARGETS) $(TARGETS_CONFIG) default

# 伪目标声明  作用：声明这些目标不对应实际文件
.PHONY: $(TARGETS) $(TARGETS_CONFIG) default buildroot-help help

# 当目标未定义时，会给出备用目标。  作用：未定义的目标自动转发给 Buildroot
.DEFAULT:
	$(call print,$(COLOR_STEP)=== Falling back to Buildroot target '$@' ===$(TERM_RESET))
	$(MAKE) -C $(BUILDROOT) O=$(O) BR2_EXTERNAL=$(BUILDROOT_EXTERNAL) "$@"

# 当未指定目标时，默认目标 - 必须是 Makefile 中的第一个目标  作用：无参数执行 make 时调用 Buildroot 默认目标
default:
	$(MAKE) -C $(BUILDROOT) O=$(O) BR2_EXTERNAL=$(BUILDROOT_EXTERNAL)

# 配置目标（核心)

$(TARGETS_CONFIG): %-config:
	@if [ -f $(O)/.config ] && ! grep -q 'BR2_DEFCONFIG="$(DEFCONFIG_DIR)/$*_defconfig"' $(O)/.config; then \
		echo "$(COLOR_WARN)WARNING: Output directory '$(O)' already contains files for another target!$(TERM_RESET)"; \
		echo "         Before running build for a different target, run 'make distclean' first."; \
		echo ""; \
		bash -c 'read -t 10 -p "Waiting 10s, press enter to continue or Ctrl-C to abort..."' || true; \
	fi
	$(call print,$(COLOR_STEP)=== Using $*_defconfig ===$(TERM_RESET))
	$(MAKE) -C $(BUILDROOT) O=$(O) BR2_EXTERNAL=$(BUILDROOT_EXTERNAL) "$*_defconfig"

# 构建目标（核心）
$(TARGETS): %: %-config
	$(call print,$(COLOR_STEP)=== Building $@ ===$(TERM_RESET))
	$(MAKE) -C $(BUILDROOT) O=$(O) BR2_EXTERNAL=$(BUILDROOT_EXTERNAL)

# 帮助目标
buildroot-help:
	$(MAKE) -C $(BUILDROOT) O=$(O) BR2_EXTERNAL=$(BUILDROOT_EXTERNAL) help

help:
	@echo "Run 'make <target>' to build a target image."
	@echo "Run 'make <target>-config' to configure buildroot for a target."
	@echo ""
	@echo "Supported targets: $(TARGETS)"
	@echo ""
	@echo "Unknown Makefile targets fall back to Buildroot make - for details run 'make buildroot-help'"
