#!/bin/bash

# ============================================================
# 脚本功能：从 ImmortalWrt 注入 jdcloud_re-ss-01 设备支持到 fanchmwrt
# 核心原则：
#   1. 绝不覆盖 fanchmwrt 已有文件，仅增量追加
#   2. DTS 文件放入 files/ 覆盖目录（fanchmwrt 方式），不用 dts/ 目录（ImmortalWrt 方式）
#   3. 主动检测并移除 DTS_DIR 覆盖，避免 qcom/qcom 双重路径
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

echo -e "${YELLOW}[1/7] 克隆 ImmortalWrt 源码...${NC}"

cd "$TEMP_DIR"
git clone -b "$IMMORTALWRT_BRANCH" "$IMMORTALWRT_URL" --single-branch --depth 1 --filter=blob:none immortalwrt-temp 2>/dev/null || \
git clone -b "$IMMORTALWRT_BRANCH" "$IMMORTALWRT_URL" --single-branch --depth 1 immortalwrt-temp

cd immortalwrt-temp

git sparse-checkout set target/linux/qualcommax package/firmware/ipq-wifi 2>/dev/null || true
git checkout 2>/dev/null || true

IWRT_DIR="$TEMP_DIR/immortalwrt-temp"
TARGET_DIR="$OPENWRT_DIR/target/linux/qualcommax"
mkdir -p "$TARGET_DIR"

echo -e "${YELLOW}[2/7] 合并 base-files（不覆盖已有文件）...${NC}"

if [ -d "$IWRT_DIR/target/linux/qualcommax/ipq60xx/base-files" ]; then
    mkdir -p "$TARGET_DIR/ipq60xx/base-files"
    cd "$IWRT_DIR/target/linux/qualcommax/ipq60xx/base-files"
    find . -type f | while read -r file; do
        dest="$TARGET_DIR/ipq60xx/base-files/$file"
        if [ ! -f "$dest" ]; then
            mkdir -p "$(dirname "$dest")"
            cp -f "$file" "$dest"
            echo -e "${GREEN}  ✅ 新增: $file${NC}"
        fi
    done
    echo -e "${GREEN}  ✅ base-files 合并完成${NC}"
else
    echo -e "${YELLOW}  ⚠️  ImmortalWrt 中未找到 ipq60xx/base-files${NC}"
fi

echo -e "${YELLOW}[3/7] 增量添加 jdcloud_re-ss-01 设备定义到 ipq60xx.mk...${NC}"

MK_FILE="$TARGET_DIR/image/ipq60xx.mk"

if [ -f "$MK_FILE" ]; then
    if grep -q 'DTS_DIR.*:=.*qcom' "$MK_FILE"; then
        echo -e "${RED}  ❌ 检测到 DTS_DIR 覆盖！这会导致 qcom/qcom 双重路径冲突${NC}"
        echo -e "${YELLOW}  正在移除 DTS_DIR 覆盖...${NC}"
        sed -i '/^DTS_DIR.*:=.*/d' "$MK_FILE"
        if ! grep -q 'DTS_DIR.*:=.*qcom' "$MK_FILE"; then
            echo -e "${GREEN}  ✅ 已移除 DTS_DIR 覆盖${NC}"
        else
            echo -e "${RED}  ❌ 移除 DTS_DIR 覆盖失败${NC}"
        fi
    fi

    if grep -q "define Device/jdcloud_re-ss-01" "$MK_FILE"; then
        echo -e "${GREEN}  ✅ jdcloud_re-ss-01 设备定义已存在${NC}"
    else
        cat >> "$MK_FILE" << 'EOF'

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
        echo -e "${GREEN}  ✅ 已追加 jdcloud_re-ss-01 设备定义${NC}"
    fi
else
    echo -e "${RED}  ❌ 未找到 ipq60xx.mk: $MK_FILE${NC}"
fi

echo -e "${YELLOW}[4/7] 复制 DTS 和 DTSI 文件到 files/ 覆盖目录...${NC}"

DTS_DEST_DIR="$TARGET_DIR/files/arch/arm64/boot/dts/qcom"
mkdir -p "$DTS_DEST_DIR"

DTS_FILE="ipq6000-re-ss-01.dts"
DTS_SRC="$IWRT_DIR/target/linux/qualcommax/dts/$DTS_FILE"

if [ -f "$DTS_DEST_DIR/$DTS_FILE" ]; then
    echo -e "${GREEN}  ✅ DTS 已存在: $DTS_FILE${NC}"
elif [ -f "$DTS_SRC" ]; then
    cp -f "$DTS_SRC" "$DTS_DEST_DIR/$DTS_FILE"
    echo -e "${GREEN}  ✅ 已复制 DTS: $DTS_FILE${NC}"
else
    echo -e "${YELLOW}  ⚠️  sparse checkout 中未找到 $DTS_FILE，从 GitHub 下载...${NC}"
    DTS_URL="https://raw.githubusercontent.com/immortalwrt/immortalwrt/master/target/linux/qualcommax/dts/$DTS_FILE"
    if curl -fsSL "$DTS_URL" -o "$DTS_DEST_DIR/$DTS_FILE" 2>/dev/null; then
        echo -e "${GREEN}  ✅ 已下载 DTS: $DTS_FILE${NC}"
    else
        echo -e "${RED}  ❌ 无法获取 DTS: $DTS_FILE${NC}"
    fi
fi

DTSI_FILES=("ipq6018-512m.dtsi" "ipq6018-ess.dtsi")
DTSI_SRC_DIR="$IWRT_DIR/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom"

for dtsi_file in "${DTSI_FILES[@]}"; do
    dest="$DTS_DEST_DIR/$dtsi_file"
    src="$DTSI_SRC_DIR/$dtsi_file"

    if [ -f "$dest" ]; then
        echo -e "${GREEN}  ✅ DTSI 已存在: $dtsi_file${NC}"
    elif [ -f "$src" ]; then
        cp -f "$src" "$dest"
        echo -e "${GREEN}  ✅ 已复制 DTSI: $dtsi_file${NC}"
    else
        echo -e "${YELLOW}  ⚠️  sparse checkout 中未找到 $dtsi_file，从 GitHub 下载...${NC}"
        dtsi_url="https://raw.githubusercontent.com/immortalwrt/immortalwrt/master/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/$dtsi_file"
        if curl -fsSL "$dtsi_url" -o "$dest" 2>/dev/null; then
            echo -e "${GREEN}  ✅ 已下载 DTSI: $dtsi_file${NC}"
        else
            echo -e "${RED}  ❌ 无法获取 DTSI: $dtsi_file${NC}"
        fi
    fi
done

echo -e "${YELLOW}[5/7] 补丁 ipq-wifi Makefile 并添加 board 文件...${NC}"

IPQ_WIFI_MAKEFILE=""
if [ -f "$OPENWRT_DIR/package/firmware/ipq-wifi/Makefile" ]; then
    IPQ_WIFI_MAKEFILE="$OPENWRT_DIR/package/firmware/ipq-wifi/Makefile"
elif [ -f "$OPENWRT_DIR/feeds/packages/firmware/ipq-wifi/Makefile" ]; then
    IPQ_WIFI_MAKEFILE="$OPENWRT_DIR/feeds/packages/firmware/ipq-wifi/Makefile"
fi

if [ -n "$IPQ_WIFI_MAKEFILE" ]; then
    if grep -q "jdcloud_re-ss-01" "$IPQ_WIFI_MAKEFILE"; then
        echo -e "${GREEN}  ✅ ipq-wifi Makefile 已包含 jdcloud_re-ss-01${NC}"
    else
        IPQ_WIFI_MK="$IPQ_WIFI_MAKEFILE" python3 << 'PYEOF'
import os
makefile = os.environ['IPQ_WIFI_MK']
with open(makefile, 'r') as f:
    content = f.read()

if 'jdcloud_re-ss-01' not in content:
    lines = content.split('\n')
    new_lines = []
    for line in lines:
        if line.startswith('ALLWIFIPACKAGES'):
            if new_lines and not new_lines[-1].rstrip().endswith('\\'):
                new_lines[-1] = new_lines[-1].rstrip() + ' \\'
            new_lines.append('\tjdcloud_re-ss-01')
        new_lines.append(line)
    content = '\n'.join(new_lines)

    content = content.rstrip('\n') + '\n$(eval $(call generate-ipq-wifi-package,jdcloud_re-ss-01,JDCloud RE-SS-01))\n'

    if 'define Build/Prepare' not in content:
        content = content.replace(
            'define Build/Compile',
            'define Build/Prepare\n\t$(call Build/Prepare/Default)\n\t$(CP) ./board-jdcloud_re-ss-01.ipq6018 $(PKG_BUILD_DIR)/ 2>/dev/null || true\nendef\n\ndefine Build/Compile'
        )

    with open(makefile, 'w') as f:
        f.write(content)
PYEOF
        echo -e "${GREEN}  ✅ 已添加 jdcloud_re-ss-01 到 ipq-wifi Makefile${NC}"
    fi

    IPQ_WIFI_DIR="$(dirname "$IPQ_WIFI_MAKEFILE")"
    BOARD_FILE="board-jdcloud_re-ss-01.ipq6018"

    if [ -f "$IPQ_WIFI_DIR/$BOARD_FILE" ]; then
        echo -e "${GREEN}  ✅ board 文件已存在: $BOARD_FILE${NC}"
    else
        COPIED=0
        for board_file in "$IWRT_DIR/package/firmware/ipq-wifi/board-"*jdcloud_re-ss-01*; do
            if [ -f "$board_file" ]; then
                cp -f "$board_file" "$IPQ_WIFI_DIR/"
                echo -e "${GREEN}  ✅ 已复制 board: $(basename "$board_file")${NC}"
                COPIED=1
                break
            fi
        done

        if [ "$COPIED" -eq 0 ]; then
            echo -e "${YELLOW}  ⚠️  从 qca-wireless 仓库下载 board 文件...${NC}"
            BOARD_URL="https://raw.githubusercontent.com/openwrt/firmware_qca-wireless/main/$BOARD_FILE"
            if curl -fsSL "$BOARD_URL" -o "$IPQ_WIFI_DIR/$BOARD_FILE" 2>/dev/null; then
                echo -e "${GREEN}  ✅ 已下载 board: $BOARD_FILE${NC}"
            else
                BOARD_URL="https://raw.githubusercontent.com/openwrt/firmware_qca-wireless/master/$BOARD_FILE"
                if curl -fsSL "$BOARD_URL" -o "$IPQ_WIFI_DIR/$BOARD_FILE" 2>/dev/null; then
                    echo -e "${GREEN}  ✅ 已下载 board: $BOARD_FILE${NC}"
                else
                    echo -e "${RED}  ❌ 无法下载 board: $BOARD_FILE${NC}"
                fi
            fi
        fi
    fi
else
    echo -e "${RED}  ❌ 未找到 ipq-wifi Makefile${NC}"
fi

echo -e "${YELLOW}[6/7] 补全 ipq60xx 内核配置...${NC}"

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
)

if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$TARGET_DIR/ipq60xx"
    for config_line in "${REQUIRED_CONFIGS[@]}"; do
        echo "$config_line" >> "$CONFIG_FILE"
    done
    echo -e "${GREEN}  ✅ 已创建 config-default${NC}"
else
    ADDED=0
    for config_line in "${REQUIRED_CONFIGS[@]}"; do
        config_key=$(echo "$config_line" | grep -oP 'CONFIG_\w+' || echo "$config_line" | sed 's/^# //' | sed 's/ is not set//')
        if ! grep -q "$config_key" "$CONFIG_FILE"; then
            echo "$config_line" >> "$CONFIG_FILE"
            echo -e "${GREEN}  ✅ 已追加: $config_line${NC}"
            ADDED=$((ADDED + 1))
        fi
    done
    if [ "$ADDED" -eq 0 ]; then
        echo -e "${GREEN}  ✅ 内核配置完整${NC}"
    fi
fi

echo -e "${YELLOW}[7/7] 验证注入结果...${NC}"

ERRORS=0

if [ -f "$MK_FILE" ] && grep -q "define Device/jdcloud_re-ss-01" "$MK_FILE"; then
    echo -e "${GREEN}  ✅ ipq60xx.mk 包含 jdcloud_re-ss-01${NC}"
else
    echo -e "${RED}  ❌ ipq60xx.mk 缺少 jdcloud_re-ss-01${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$MK_FILE" ] && grep -q 'DTS_DIR.*:=.*qcom' "$MK_FILE"; then
    echo -e "${RED}  ❌ ipq60xx.mk 仍有 DTS_DIR 覆盖！将导致 qcom/qcom 双重路径${NC}"
    echo -e "${YELLOW}  强制移除...${NC}"
    sed -i '/^DTS_DIR.*:=.*/d' "$MK_FILE"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$DTS_DEST_DIR/ipq6000-re-ss-01.dts" ]; then
    echo -e "${GREEN}  ✅ DTS: ipq6000-re-ss-01.dts${NC}"
else
    echo -e "${RED}  ❌ DTS 缺失: ipq6000-re-ss-01.dts${NC}"
    ERRORS=$((ERRORS + 1))
fi

for dtsi_file in "${DTSI_FILES[@]}"; do
    if [ -f "$DTS_DEST_DIR/$dtsi_file" ]; then
        echo -e "${GREEN}  ✅ DTSI: $dtsi_file${NC}"
    else
        echo -e "${RED}  ❌ DTSI 缺失: $dtsi_file${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

if [ -n "$IPQ_WIFI_MAKEFILE" ] && grep -q "jdcloud_re-ss-01" "$IPQ_WIFI_MAKEFILE"; then
    echo -e "${GREEN}  ✅ ipq-wifi Makefile 包含 jdcloud_re-ss-01${NC}"
else
    echo -e "${RED}  ❌ ipq-wifi Makefile 缺少 jdcloud_re-ss-01${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -n "$IPQ_WIFI_MAKEFILE" ] && grep -q "define Build/Prepare" "$IPQ_WIFI_MAKEFILE"; then
    echo -e "${GREEN}  ✅ ipq-wifi Makefile 包含 Build/Prepare 覆盖${NC}"
else
    echo -e "${YELLOW}  ⚠️  ipq-wifi Makefile 缺少 Build/Prepare 覆盖（board 文件可能无法安装）${NC}"
fi

if [ -n "$IPQ_WIFI_MAKEFILE" ]; then
    IPQ_WIFI_DIR="$(dirname "$IPQ_WIFI_MAKEFILE")"
    if [ -f "$IPQ_WIFI_DIR/board-jdcloud_re-ss-01.ipq6018" ]; then
        echo -e "${GREEN}  ✅ board 文件: board-jdcloud_re-ss-01.ipq6018${NC}"
    else
        echo -e "${RED}  ❌ board 文件缺失: board-jdcloud_re-ss-01.ipq6018${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

if [ -f "$TARGET_DIR/ipq60xx/target.mk" ]; then
    echo -e "${GREEN}  ✅ ipq60xx/target.mk 存在${NC}"
else
    echo -e "${RED}  ❌ ipq60xx/target.mk 缺失${NC}"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$TARGET_DIR/Makefile" ] && grep -q "ipq60xx" "$TARGET_DIR/Makefile"; then
    echo -e "${GREEN}  ✅ qualcommax/Makefile 包含 ipq60xx${NC}"
else
    echo -e "${RED}  ❌ qualcommax/Makefile 缺少 ipq60xx${NC}"
    ERRORS=$((ERRORS + 1))
fi

cd "$OPENWRT_DIR"
rm -rf "$TEMP_DIR"

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}=============================================${NC}"
    echo -e "${RED}  ❌ 注入完成，有 $ERRORS 个错误${NC}"
    echo -e "${RED}=============================================${NC}"
else
    echo -e "${GREEN}=============================================${NC}"
    echo -e "${GREEN}  ✅ jdcloud_re-ss-01 设备支持注入完成！${NC}"
    echo -e "${GREEN}=============================================${NC}"
fi
