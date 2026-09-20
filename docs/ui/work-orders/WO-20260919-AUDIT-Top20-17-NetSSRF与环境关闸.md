# WO-20260919-AUDIT-Top20-17 — Net：SSRF 非规范 IP/DNS rebinding 绕过 + 环境变量全局关闸

- 法源：`CodeReview/20260918-全库审计-总报告.md` §三 Top20 #17；明细条目 `CodeReview/20260918-Features-C-防御云意图.md` NET-02/NET-03/NET-04/NET-05
- 执行方：**开发 AI 甲**（2026-09-20 主控派发 → `WO-20260920-AUDIT-甲-R5-Top20安全链与Gate5.md` M3；本单由 WO-20260919-AUDIT-甲 A5 建立；主控裁定理由：`Features\DeepBase.Net.pas` 不在任一方脏集，安全线主导权在甲）

## 五件套

### 1. 文件:行（2026-09-19 复核）

| 锚点 | 缺陷 |
|---|---|
| `Features\DeepBase.Net.pas:2103-2143`（`TNetworkUtils.IsSafeUrl`，起始 `:2103` 已核验） | NET-02：只识别点分十进制四段；`http://127.1/`、`http://0177.0.0.1/`（八进制）、`::ffff:127.0.0.1` 等写法绕过指向内网/元数据服务 |
| `Features\DeepBase.Net.pas:1978-2014`（`IsUnsafeResolvedAddress`） | 同上（IPv4 正则 `:1673-1690`、IPv6 正则 `:1692-1701`） |
| `Features\DeepBase.Net.pas:2098`、`:2123`（`AllowPrivateNet := SameText(GetEnvironmentVariable('DeepBase_ALLOW_PRIVATE_NET_HTTP'), '1')`） | NET-04：安全门被环境变量全局关闭，无告警、子进程继承 → 一次注入即永久旁路 |
| `Features\DeepBase.Net.pas:571-572`、`:437`、`:598-601` | NET-03：`THTTPClient` 自动跟随 3xx，SSRF 校验只覆盖首 URL；重定向复用自定义头（API key 泄漏） |
| `Features\DeepBase.Net.pas:945-946`、`:2016-2087`（`TDnsResolver_` 硬编码 `8.8.8.8:53`）、`:998-1021` | NET-05：安全判定用自建 DNS、实际连接用系统解析器 → rebinding 两解不同果；8.8.8.8 在受限网络超时后的缺省方向未 fail-closed；AAAA 只取首条；无 IP pin |

### 2. 改法

1. **废弃字符串正则判 IP**：统一数值解析——主机名先经系统解析器解析为 `TNetIPAddress` 字节值，再对字节值做网段判定（0.0.0.0/8、10/8、100.64/10、127/8、169.254/16、172.16/12、192.168/16、::1、fc00::/7、::ffff:0:0/96 解封装后复判）；简写/八进制/十进制由解析器规范化天然覆盖。
2. **IP pin 防 rebinding**：校验通过的 IP 钉入连接（URL 主机替换为已校验字面 IP + 显式 `Host:` 头/SNI）；删除硬编码 `8.8.8.8` 自建解析器，判定与连接共用同一解析结果；解析失败一律拒绝（fail-closed）+ 记日志。
3. 环境变量关闸改造：`DeepBase_ALLOW_PRIVATE_NET_HTTP` 仅在生产构建**编译期剔除**后保留调试用途（`{$IFDEF DEBUG}`），Release 下读取到该变量 = 直接拒绝请求并 `Logger.Error`；不新增替代开关（H8：不留后门）。
4. 重定向改手动：`AllowRedirects := False`，逐跳重新执行 SSRF 校验，跨主机时剥离 `Authorization`/`Cookie`，最大跳数限制（NET-03）。
5. 门禁函数返回值接甲单 A6 `TGateVerdict`：`IsSafeUrl` 系列改为返回强类型判定（含 Reason），异常/未知输入 = `gvRejected`。

### 3. 验收标准

- 负向用例矩阵全拒绝：`127.1`、`127.0.1`、`0177.0.0.1`、`2130706433`（十进制）、`::ffff:127.0.0.1`、`169.254.169.254`、`[::1]`、`0.0.0.0`、DNS rebinding 模拟（两次解析不同结果时按**较危险**者拒绝）、302→内网、Release 下置环境变量 = 请求被拒；
- 正向用例：公网主机名/字面 IP 正常访问不回归；
- 既有 Net 回归全绿。

### 4. 证据要求

- 修复 diff + 负向矩阵测试原始输出（逐条列出输入→判定）；
- rebinding 与重定向两条链路的模拟服务端演练日志；
- 提交信息注明 H6/H7：Release 下环境变量关闸失效属**可观察行为变更**（依赖它做内网联调的下游需改用显式调试构建），登记 Product Intervention。

### 5. 阻塞他仓

- **潜在是**：若 AsWish/DeepAxis 现网依赖 `DeepBase_ALLOW_PRIVATE_NET_HTTP` 在生产访问内网服务，改造前必须盘点该变量在下游部署中的实际使用（`grep -r` 下游仓 + 部署配置），否则升级即断。属三仓协调项，工单执行前报主控盘点。


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