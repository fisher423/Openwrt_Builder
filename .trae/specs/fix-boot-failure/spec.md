# 修复 jdcloud_re-ss-01 固件无法正常启动 Spec

## Why
固件编译成功但刷入路由器后无法正常启动：LAN 口无法获取 IP、WiFi 无法启动搜不到信号。根因是 inject-device-support.sh 脚本存在两个关键缺陷，**与新增的 8 个 LuCI 插件无关**。

## 根因分析

### 根因 1：缺少网络接口配置（LAN 无法获取 IP）
- fanchmwrt 的 `target/linux/qualcommax/ipq60xx/base-files/etc/board.d/02_network` **不包含** `jdcloud,re-ss-01`
- ImmortalWrt 的同名文件**包含** `jdcloud,re-ss-01`，配置为 `ucidef_set_interfaces_lan_wan "lan1 lan2 lan3" "wan"`
- 当前脚本的 base-files 合并策略是"不覆盖已有文件"，但 fanchmwrt 已有 `02_network`，所以 ImmortalWrt 的版本不会被复制
- 结果：设备启动时 `02_network` 的 case 语句匹配不到 `jdcloud,re-ss-01`，走到 `*)` 默认分支，输出 "Unsupported hardware. Network interfaces not initialized"，网络接口未初始化

### 根因 2：ipq-wifi board 文件未安装（WiFi 无法启动）
- fanchmwrt 的 ipq-wifi Makefile 的 `install-overlay` 使用 `$(PKG_BUILD_DIR)/board-*` 搜索 board 文件（第 188 行）
- 当前脚本将 board 文件放在包目录根目录（与 Makefile 同级），但 `install-overlay` 在 `$(PKG_BUILD_DIR)` 中搜索
- 当前脚本的 `Build/Prepare` 覆盖有 bug：`$(CP) ./board-jdcloud_re-ss-01.ipq6018 $(PKG_BUILD_DIR)/` 中的 `./` 在构建时指向 `$(PKG_BUILD_DIR)`（当前工作目录），不是包源码目录
- Makefile 注释明确说明：本地 board 文件应放在 `files/` 子目录，默认的 `Build/Prepare` 会自动将 `files/` 内容复制到 `$(PKG_BUILD_DIR)`
- 结果：`board-2.bin` 未包含在固件中，ath11k 驱动找不到 board 数据，WiFi 无法启动

### 非根因：8 个 LuCI 插件
LuCI 插件仅是 Web 界面包，不影响启动流程、网络栈或 WiFi 驱动。

## What Changes
- 修改 inject-device-support.sh 的 base-files 合并逻辑：对 `02_network` 和 `platform.sh` 等关键配置文件进行增量补丁而非跳过
- 修改 board 文件放置位置：从包目录根目录改为 `files/` 子目录
- 移除有 bug的 `Build/Prepare` 覆盖（使用 `files/` 机制后不再需要）
- 补丁 `02_network`：添加 `jdcloud,re-ss-01` 的网络接口配置
- 补丁 `platform.sh`：添加 `jdcloud,re-ss-01` 的升级支持

## Impact
- Affected code: `/workspace/sh/inject-device-support.sh`
- Affected specs: jdcloud_re-ss-01 设备注入流程

## ADDED Requirements

### Requirement: 网络接口配置补丁
脚本 SHALL 对 fanchmwrt 已有的 `02_network` 文件进行增量补丁，添加 `jdcloud,re-ss-01` 的网络接口配置。

#### Scenario: 02_network 补丁成功
- **WHEN** fanchmwrt 的 `02_network` 不包含 `jdcloud,re-ss-01`
- **THEN** 在 `qihoo,360v6)` 分支后插入 `jdcloud,re-cs-07|\njdcloud,re-ss-01|\`，配置为 `ucidef_set_interfaces_lan_wan "lan1 lan2 lan3" "wan"`

### Requirement: platform.sh 升级支持补丁
脚本 SHALL 对 fanchmwrt 已有的 `platform.sh` 文件进行增量补丁，添加 `jdcloud,re-ss-01` 的升级支持。

#### Scenario: platform.sh 补丁成功
- **WHEN** fanchmwrt 的 `platform.sh` 不包含 `jdcloud,re-ss-01`
- **THEN** 在 platform_check_image 和 platform_do_upgrade 的 case 语句中添加 `jdcloud,re-ss-01` 支持

### Requirement: board 文件正确放置
脚本 SHALL 将 ipq-wifi board 文件放在包目录的 `files/` 子目录中，而非包目录根目录。

#### Scenario: board 文件通过 files/ 机制安装
- **WHEN** board 文件 `board-jdcloud_re-ss-01.ipq6018` 放在 `package/firmware/ipq-wifi/files/` 目录
- **THEN** 默认的 `Build/Prepare` 会自动将其复制到 `$(PKG_BUILD_DIR)`，`install-overlay` 的 `$(PKG_BUILD_DIR)/board-*` 通配符能找到它

## MODIFIED Requirements

### Requirement: base-files 合并策略
原策略为"不覆盖已有文件"。修改为：对关键配置文件（`02_network`、`platform.sh`）进行增量补丁，对其余文件仍保持"不覆盖"策略。

### Requirement: ipq-wifi Makefile 补丁
移除 `Build/Prepare` 覆盖逻辑。board 文件通过 `files/` 子目录机制安装，不需要自定义 `Build/Prepare`。
