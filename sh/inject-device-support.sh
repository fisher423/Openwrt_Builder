#!/bin/bash

# ============================================================
# 脚本功能：从 ImmortalWrt 注入 jdcloud_re-ss-01 设备支持
# 使用方法：在 fanchmwrt 源码目录中执行此脚本
# 注意：仅复制设备特定文件，不覆盖补丁和内核配置
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  注入 jdcloud_re-ss-01 设备支持${NC}"
echo -e "${GREEN}=============================================${NC}"

OPENWRT_DIR="$PWD"

IMMORTALWRT_URL="https://github.com/immortalwrt/immortalwrt.git"
IMMORTALWRT_BRANCH="master"

TEMP_DIR="/tmp/immortalwrt-device-inject"

rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo -e "${YELLOW}[1/5] 克隆 ImmortalWrt 源码（仅 target/linux/qualcommax）...${NC}"

cd "$TEMP_DIR"
git clone -b "$IMMORTALWRT_BRANCH" "$IMMORTALWRT_URL" --single-branch --depth 1 --filter=blob:none immortalwrt-temp 2>/dev/null || \
git clone -b "$IMMORTALWRT_BRANCH" "$IMMORTALWRT_URL" --single-branch --depth 1 immortalwrt-temp

cd immortalwrt-temp

git sparse-checkout set target/linux/qualcommax 2>/dev/null || true
git checkout 2>/dev/null || true

TARGET_DIR="$OPENWRT_DIR/target/linux/qualcommax"
mkdir -p "$TARGET_DIR"

echo -e "${YELLOW}[2/5] 复制 jdcloud_re-ss-01 设备特定文件（DTS、image、wifi board）...${NC}"

DEVICE_NAME="jdcloud_re-ss-01"

if [ -d "target/linux/qualcommax/ipq60xx" ]; then
    mkdir -p "$TARGET_DIR/ipq60xx"

    if [ -d "target/linux/qualcommax/ipq60xx/base-files" ]; then
        cp -rf target/linux/qualcommax/ipq60xx/base-files "$TARGET_DIR/ipq60xx/"
        echo -e "${GREEN}  ✅ 已复制 ipq60xx/base-files${NC}"
    fi

    if [ -f "target/linux/qualcommax/ipq60xx/target.mk" ]; then
        cp -f target/linux/qualcommax/ipq60xx/target.mk "$TARGET_DIR/ipq60xx/"
        echo -e "${GREEN}  ✅ 已复制 ipq60xx/target.mk${NC}"
    fi
fi

if [ -d "target/linux/qualcommax/dts" ]; then
    mkdir -p "$TARGET_DIR/dts"
    for dts_file in target/linux/qualcommax/dts/*jdcloud*; do
        if [ -f "$dts_file" ]; then
            cp -f "$dts_file" "$TARGET_DIR/dts/"
            echo -e "${GREEN}  ✅ 已复制 DTS: $(basename $dts_file)${NC}"
        fi
    done
    echo -e "${YELLOW}  ⚠️  DTS 目录中可能存在对其他 DTS 的 include 依赖，如编译报错需手动补全${NC}"
fi

if [ -d "target/linux/qualcommax/image" ]; then
    mkdir -p "$TARGET_DIR/image"
    if [ -f "target/linux/qualcommax/image/ipq60xx.mk" ]; then
        cp -f target/linux/qualcommax/image/ipq60xx.mk "$TARGET_DIR/image/"
        echo -e "${GREEN}  ✅ 已复制 image/ipq60xx.mk${NC}"
    fi
fi

WIFI_BOARD_DIR="$OPENWRT_DIR/package/firmware/ipq-wifi"
mkdir -p "$WIFI_BOARD_DIR"
for board_file in "$TEMP_DIR/immortalwrt-temp/package/firmware/ipq-wifi/board-"*jdcloud*; do
    if [ -f "$board_file" ]; then
        cp -f "$board_file" "$WIFI_BOARD_DIR/"
        echo -e "${GREEN}  ✅ 已复制 wifi board: $(basename $board_file)${NC}"
    fi
done

echo -e "${YELLOW}[3/5] 检查并修复设备配置...${NC}"

if [ -f "$TARGET_DIR/image/ipq60xx.mk" ]; then
    if grep -q "jdcloud_re-ss-01" "$TARGET_DIR/image/ipq60xx.mk"; then
        echo -e "${GREEN}  ✅ jdcloud_re-ss-01 设备定义已存在${NC}"
    else
        echo -e "${RED}  ❌ 未找到 jdcloud_re-ss-01 设备定义，尝试手动添加...${NC}"
        cat >> "$TARGET_DIR/image/ipq60xx.mk" << 'EOF'

define Device/jdcloud_re-ss-01
	$(call Device/FitImage)
	DEVICE_VENDOR := JDCloud
	DEVICE_MODEL := RE-SS-01
	SOC := ipq6000
	BLOCKSIZE := 64k
	KERNEL_SIZE := 6144k
	DEVICE_DTS_CONFIG := config@cp03-c2
	DEVICE_PACKAGES := ipq-wifi-jdcloud_re-ss-01
endef
TARGET_DEVICES += jdcloud_re-ss-01
EOF
        echo -e "${GREEN}  ✅ 已添加 jdcloud_re-ss-01 设备定义${NC}"
    fi
else
    echo -e "${RED}  ❌ 未找到 ipq60xx.mk 文件${NC}"
fi

if [ ! -f "$TARGET_DIR/ipq60xx/target.mk" ]; then
    mkdir -p "$TARGET_DIR/ipq60xx"
    cat > "$TARGET_DIR/ipq60xx/target.mk" << 'EOF'
SUBTARGET:=ipq60xx
BOARDNAME:=Qualcomm Atheros IPQ60xx
DEFAULT_PACKAGES += ath11k-firmware-ipq6018
define Target/Description
	Build firmware images for Qualcomm Atheros IPQ60xx based boards.
endef
EOF
    echo -e "${GREEN}  ✅ 已创建 ipq60xx/target.mk${NC}"
fi

echo -e "${YELLOW}[4/5] 补全 ipq60xx 内核配置（仅追加缺失选项）...${NC}"

CONFIG_FILE="$TARGET_DIR/ipq60xx/config-default"

REQUIRED_CONFIGS=(
    "CONFIG_IPQ_CMN_PLL=y"
    "CONFIG_IPQ_GCC_6018=y"
    "CONFIG_MTD_SPLIT_FIT_FW=y"
    "CONFIG_PINCTRL_IPQ6018=y"
    "CONFIG_PWM=y"
    "CONFIG_PWM_IPQ=y"
    "CONFIG_QCOM_APM=y"
    "# CONFIG_QCOM_CLK_SMD_RPM is not set"
    "# CONFIG_QCOM_RPMPD is not set"
    "CONFIG_QCOM_SMD_RPM=y"
    "CONFIG_REGULATOR_CPR3=y"
    "# CONFIG_REGULATOR_CPR3_NPU is not set"
    "CONFIG_REGULATOR_CPR4_APSS=y"
    "CONFIG_REGULATOR_QCOM_SMD_RPM=y"
    "# CONFIG_NF_CONNTRACK_DSCPREMARK_EXT is not set"
)

if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$TARGET_DIR/ipq60xx"
    for config_line in "${REQUIRED_CONFIGS[@]}"; do
        echo "$config_line" >> "$CONFIG_FILE"
    done
    echo -e "${GREEN}  ✅ 已创建 ipq60xx/config-default${NC}"
else
    ADDED=0
    for config_line in "${REQUIRED_CONFIGS[@]}"; do
        config_key=$(echo "$config_line" | grep -oP 'CONFIG_\w+' || echo "$config_line" | sed 's/^# //' | sed 's/ is not set//')
        if ! grep -q "$config_key" "$CONFIG_FILE"; then
            echo "$config_line" >> "$CONFIG_FILE"
            echo -e "${GREEN}  ✅ 已追加内核配置: $config_line${NC}"
            ADDED=$((ADDED + 1))
        fi
    done
    if [ "$ADDED" -eq 0 ]; then
        echo -e "${GREEN}  ✅ 内核配置完整，无需追加${NC}"
    fi
fi

echo -e "${YELLOW}[5/5] 检查 qualcommax/Makefile...${NC}"

if [ -f "$TARGET_DIR/Makefile" ]; then
    if grep -q "ipq60xx" "$TARGET_DIR/Makefile"; then
        echo -e "${GREEN}  ✅ qualcommax/Makefile 已包含 ipq60xx 子目标${NC}"
    else
        echo -e "${YELLOW}  ⚠️  qualcommax/Makefile 中未找到 ipq60xx，可能需要手动添加${NC}"
    fi
else
    echo -e "${RED}  ❌ 未找到 qualcommax/Makefile 文件${NC}"
fi

cd "$OPENWRT_DIR"
rm -rf "$TEMP_DIR"

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  ✅ jdcloud_re-ss-01 设备支持注入完成！${NC}"
echo -e "${GREEN}=============================================${NC}"
echo ""
echo -e "现在可以使用以下配置进行编译："
echo -e "  CONFIG_TARGET_qualcommax=y"
echo -e "  CONFIG_TARGET_qualcommax_ipq60xx=y"
echo -e "  CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01=y"
echo ""