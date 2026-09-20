# WO-20260919-AUDIT-Top20-05 — Security 主口令无用户 secret：同机可离线解密

- 法源：`CodeReview/20260918-全库审计-总报告.md` §三 Top20 #5；明细条目 `CodeReview/20260918-Core-A-加密安全基础.md` A11-02（P4 优先级表）
- 执行方：**开发 AI 甲**（2026-09-20 主控派发 → `WO-20260920-AUDIT-甲-R5-Top20安全链与Gate5.md` M2；本单由 WO-20260919-AUDIT-甲 A5 建立）

## 五件套

### 1. 文件:行（2026-09-19 复核）

- `Core\DeepBase.Security.pas:299-340`（`GetMachineEntropy`，函数起始 `:299` 已核验）：POSIX 主口令 = `'machine-id:' + Lid + ':' + GetEnvironmentVariable('USER') + ':Linux:DeepBase'`
- 使用点：`:446`、`:530`（口令参与 KEK 派生）
- 同族：`Core\DeepBase.License.pas` / 硬件绑定"5 中 3"（A14-02，同源 `ComputerName`，一并处理）；`DEEPBASE_MASTER_KEY` 环境变量覆盖使明文主密钥驻留进程环境块（`/proc/<pid>/environ`、子进程继承）

### 2. 改法

1. 引入**用户 secret** 作为主口令必备熵源：每用户 `~/.deepbase/master.key`（0600、随机 32 字节，首启生成）或系统 keyring（libsecret / macOS Keychain）；machine-id 降级为 **AAD/绑定校验值**，不再进口令熵。
2. `DEEPBASE_MASTER_KEY` 覆盖改为传**文件路径**（`DEEPBASE_MASTER_KEY_FILE`），读入派生后立即 `SecureZeroMemory`；保留旧变量名则启动即告警并计划移除（H8：不为此留兼容层，直接切换 + 迁移说明）。
3. 硬件绑定值只作 AAD/门禁；`MachineId` 采集源互不相关化（SMBIOS UUID、卷序列号…），缺失 fail-closed，不回落 `ComputerName`；"5 中 3"改"全量匹配 + 指纹版本化"。
4. UBS2 头引入格式版本号与 KDF 参数上下界（联动 A11-03：`Iterations` 纳入认证标签覆盖，解密侧 `[100_000, 2_000_000]` 界外拒绝）。

### 3. 验收标准

- 新格式密文在无用户 secret 的第二个本机用户下**无法解密**（跨用户重放攻击用例）；
- machine-id 被篡改（模拟）时 AAD 校验失败、fail-closed；
- `master.key` 丢失场景有明确迁移路径（见 5）；
- 既有 UBS2 记录迁移演练通过（见 4）。

### 4. 证据要求

- 跨用户解密攻击正反用例的测试原始输出；
- **历史落盘数据可解密性回答（必答题）**：旧格式（machine-id 熵源派生）密文必须仍能被原机主解密——迁移工具 `ReencryptUBS2`（旧口令熵 → 新 secret 熵，逐条重加密并版本升级头）脚本与运行输出；
- diff + 受影响测试全绿。

### 5. 阻塞他仓

- 否（库内自洽）。但 H7 提示：使用 `TSecurityManager` 的下游（AsWish 凭据存储）在迁移前无法在新熵源下解密旧数据，迁移窗口内行为变化须在提交信息注明并登记 Product Intervention。


### 6. 移交登记（A10）

| Top20 # | 条目 | 移交至 | 甲单编号 |
|---|---|---|---|
| #07 | CLI.SSH 命令注入 | 乙 B1/B2 | - |
| #10 | AES 模式静默降级 | **甲（本单纠正 2 移回）** | A17 |
| #14 | CDP Destroy 缺 WaitFor | 乙 B4 | - |
| #15 | CloudSync 谎报成功 | 乙 | - |
| #18 | WebAPI.Auth CSRF | 乙 | - |
| #19 | Resilience 熔断器双轨 | 乙 | - |
| #20 | 构建归属 | 乙 B3 | - |

本工单覆盖 Top20 条目：#01（本文档）/#05/#06/#17 由甲独立交付；上述 7 条为跨方移交关系，无"无人认领"项。