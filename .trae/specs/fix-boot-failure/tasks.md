# Tasks

- [x] Task 1: 修复 board 文件放置位置和移除 Build/Prepare 覆盖
  - [x] 1.1: 将 board 文件目标路径从 `$IPQ_WIFI_DIR/` 改为 `$IPQ_WIFI_DIR/files/`
  - [x] 1.2: 移除 Python 补丁中的 Build/Prepare 覆盖逻辑
  - [x] 1.3: 更新验证步骤中 board 文件路径检查

- [x] Task 2: 添加 02_network 增量补丁逻辑
  - [x] 2.1: 在步骤 2（base-files 合并）后添加新步骤：补丁 02_network
  - [x] 2.2: 检测 fanchmwrt 的 02_network 是否包含 jdcloud,re-ss-01
  - [x] 2.3: 若不包含，使用 sed 在 qihoo,360v6 分支后插入 jdcloud,re-ss-01 网络配置
  - [x] 2.4: 验证补丁结果

- [x] Task 3: 添加 platform.sh 增量补丁逻辑
  - [x] 3.1: 检测 fanchmwrt 的 platform.sh 是否包含 jdcloud,re-ss-01
  - [x] 3.2: 若不包含，使用 sed 在 platform_check_image 和 platform_do_upgrade 的 case 语句中添加 jdcloud,re-ss-01
  - [x] 3.3: 验证补丁结果

- [x] Task 4: 更新验证步骤
  - [x] 4.1: 添加 02_network 包含 jdcloud,re-ss-01 的验证
  - [x] 4.2: 添加 platform.sh 包含 jdcloud,re-ss-01 的验证
  - [x] 4.3: 更新 board 文件路径验证

- [x] Task 5: 语法检查和提交
  - [x] 5.1: bash -n 语法检查
  - [x] 5.2: Python 补丁逻辑模拟验证
  - [x] 5.3: 提交到 main 分支

# Task Dependencies
- Task 2 depends on Task 1 (步骤编号需要调整)
- Task 3 depends on Task 1 (步骤编号需要调整)
- Task 4 depends on Task 2, Task 3
- Task 5 depends on Task 1, Task 2, Task 3, Task 4
