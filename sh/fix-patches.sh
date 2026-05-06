#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  修复 qualcommax 补丁兼容性问题${NC}"
echo -e "${GREEN}=============================================${NC}"

PATCH_DIR="$PWD/target/linux/qualcommax/patches-6.18"

if [ ! -d "$PATCH_DIR" ]; then
    echo -e "${YELLOW}  ⚠️  未找到补丁目录: $PATCH_DIR${NC}"
    exit 0
fi

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

echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN}  ✅ 补丁兼容性修复完成！${NC}"
echo -e "${GREEN}=============================================${NC}"