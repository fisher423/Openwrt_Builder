# 回退 inject-device-support.sh 到工作版本 Spec

## Why
当前版本的 inject-device-support.sh 导致固件无法启动（LAN 无法获取 IP、WiFi 无法启动）。commit 58f9738 的版本可以正常工作，用户要求回退。

## 根因分析
58f9738 版本采用"整体覆盖"策略，将 ImmortalWrt 的整个 qualcommax 目录（image/Makefile + ipq60xx.mk + base-files + dts）一起复制过来，保持了 ImmortalWrt 内部的一致性：
- ImmortalWrt 的 `image/Makefile` 使用 `DEVICE_DTS_DIR := ../dts`
- ImmortalWrt 的 `ipq60xx.mk` 使用 `DTS_DIR := $(DTS_DIR)/qcom`
- ImmortalWrt 的 `base-files` 包含 `02_network`（含 jdcloud,re-ss-01 网络配置）
- 这三者配合使用，不会出现 `qcom/qcom` 双重路径问题

后续修改试图"智能地"只修改特定文件，破坏了这种一致性，导致各种问题。

## What Changes
- 将 `sh/inject-device-support.sh` 回退到 commit 58f9738 的版本
- 保留其他文件的变更（LuCI 插件配置、IP 地址修改、CI 触发方式等）

## Impact
- Affected code: `sh/inject-device-support.sh`
- 不影响其他文件

## MODIFIED Requirements
### Requirement: inject-device-support.sh
回退到 commit 58f9738 的"整体覆盖"策略。该策略将 ImmortalWrt 的整个 qualcommax 目录复制到 fanchmwrt，保持内部一致性。
