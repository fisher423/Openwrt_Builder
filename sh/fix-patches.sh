#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  修复 qualcommax 补丁和内核配置兼容性问题${NC}"
echo -e "${GREEN}=============================================${NC}"

PATCH_DIR="$PWD/target/linux/qualcommax/patches-6.18"

if [ -d "$PATCH_DIR" ]; then
    PROBLEMATIC_PATCHES=(
        "0607-1-qca-nss-clients-iptunnel-fixes.patch"
    )

    for patch in "${PROBLEMATIC_PATCHES[@]}"; do
        PATCH_FILE="$PATCH_DIR/$patch"
        if [ -f "$PATCH_FILE" ]; then
            echo -e "${YELLOW}  ⚠️  发现不兼容的补丁: $patch${NC}"
            echo -e "${YELLOW}  ⚠️  该补丁与 Linux 6.18.26 内核不兼容，正在删除...${NC}"
            rm -f "$PATCH_FILE"
            echo -e "${GREEN}  ✅ 已删除不兼容的补丁: $patch${NC}"
        else
            echo -e "${GREEN}  ✅ 补丁 $patch 不存在，无需处理${NC}"
        fi
    done
else
    echo -e "${YELLOW}  ⚠️  未找到补丁目录: $PATCH_DIR${NC}"
fi

echo -e "${YELLOW}[2/2] 修复 Linux 6.18 内核新增配置选项...${NC}"

CONFIG_FILE="$PWD/target/linux/qualcommax/ipq60xx/config-default"

if [ -f "$CONFIG_FILE" ]; then
    MISSING_CONFIGS=(
        "# CONFIG_NF_CONNTRACK_DSCPREMARK_EXT is not set"
    )

    for config_line in "${MISSING_CONFIGS[@]}"; do
        config_key=$(echo "$config_line" | grep -oP 'CONFIG_\w+' || echo "$config_line" | sed 's/^# //' | sed 's/ is not set//')
        if ! grep -q "$config_key" "$CONFIG_FILE"; then
            echo "$config_line" >> "$CONFIG_FILE"
            echo -e "${GREEN}  ✅ 已添加内核配置: $config_line${NC}"
        else
            echo -e "${GREEN}  ✅ 内核配置 $config_key 已存在，跳过${NC}"
        fi
    done
else
    echo -e "${RED}  ❌ 未找到内核配置文件: $CONFIG_FILE${NC}"
fi

GENERIC_CONFIG="$PWD/target/linux/qualcommax/config-6.18"
if [ -f "$GENERIC_CONFIG" ]; then
    MISSING_GENERIC_CONFIGS=(
        "# CONFIG_NF_CONNTRACK_DSCPREMARK_EXT is not set"
    )

    for config_line in "${MISSING_GENERIC_CONFIGS[@]}"; do
        config_key=$(echo "$config_line" | grep -oP 'CONFIG_\w+' || echo "$config_line" | sed 's/^# //' | sed 's/ is not set//')
        if ! grep -q "$config_key" "$GENERIC_CONFIG"; then
            echo "$config_line" >> "$GENERIC_CONFIG"
            echo -e "${GREEN}  ✅ 已添加平台内核配置: $config_line${NC}"
        else
            echo -e "${GREEN}  ✅ 平台内核配置 $config_key 已存在，跳过${NC}"
        fi
    done
fi

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  ✅ 补丁和内核配置兼容性修复完成！${NC}"
echo -e "${GREEN}=============================================${NC}"