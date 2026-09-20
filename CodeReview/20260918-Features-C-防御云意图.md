# DeepBase Features-C 深度代码审计报告（安全防御 / 云 / 网络 / 推理 / 意图澄清）

- **报告编号**：20260918-Features-C-防御云意图
- **审计对象**：`d:\_Progs\02Business\DeepBase\Features\` 下安全防御/云/网络/推理/意图澄清组，共 50 个 Pascal 单元（实测枚举口径，含 Inference 5 个 + IntentClarification 34 个；约 24,000 行）
- **审计日期**：2026-09-19（基线 = 当前工作副本）
- **执行者**：资深 Object Pascal / Delphi 架构审查（只读，未修改任何源码）
- **排除项**：`UIAutomationClient_TLB.pas`（第三方生成代码）

## 一、范围与方法

### 1.1 文件清单与规模（实测行数）

| 分组 | 单元 | 行数 |
|---|---|---|
| 更新/防篡改 | DeepBase.Updater.pas | 2368 |
| 更新/防篡改 | DeepBase.AutoUpdate.pas | 914 |
| 更新/防篡改 | DeepBase.AntiTamper.pas | 565 |
| 更新/防篡改 | DeepBase.AntiTamper.PersistenceRegistration.pas | 24 |
| 守护 | DeepBase.ClipboardGuard.pas | 342 |
| 守护 | DeepBase.TimeGuard.pas | 489 |
| 守护 | DeepBase.WindowMonitor.pas | 440 |
| 守护 | DeepBase.Unlock.pas | 543 |
| 许可 | DeepBase.Licensing.pas | 1030 |
| 云 | DeepBase.CloudBackup.pas | 2331 |
| 云 | DeepBase.CloudSync.pas | 2125 |
| 云 | DeepBase.Config.Upload.pas | 551 |
| 网络/图 | DeepBase.Graph.pas | 2191 |
| 网络/图 | DeepBase.HttpServer.pas | 1279 |
| 网络/图 | DeepBase.Net.pas | 1961 |
| 网络/图 | DeepBase.Net.Transport.pas | 393 |
| 网络/图 | DeepBase.Net.Transport.ICS.pas | 125 |
| 推理 | DeepBase.Inference.{IoC,Runtime,Service,Session,Types}.pas | 83/188/182/508/270 |
| 意图澄清 | DeepBase.IntentClarification.*.pas（主单元 + 27 个） | 合计 ≈ 7,700（最大 Engine 1296） |

### 1.2 方法

1. **逐单元全文精读**（大文件分段读取，行号以 `Read` 实测输出为准）。
2. **跨单元/跨层取证**：对"签名输入是否一致"这类单文件无法判定的问题，读取 `Core\DeepBase.Crypto.RSA.pas` 等实现层确认语义。
3. **git 基线比对**：用 `git log -1` 取得每个目标文件的最后提交日期，与 2026-08-25 的 `CodeReview\20260825-Features.md`（F1 批）比对，判定历史缺陷是否已被修复工单触及。
4. **全仓横向检索**：对 `hiDeepStory`、`InsecureDevMode`、UTF-8 BOM/`{$CODEPAGE}` 等系统性问题做全仓 grep。
5. **7 维度逐条对齐**：正确性 / 内存与生命周期 / 线程安全 / 异常处理 / 安全 / 性能 / 架构。每条发现给出 `文件:行号 + 代码片段 + 触发条件 + 修复建议`；某维度无问题时显式标注"未发现问题"。

### 1.3 与 2026-08-25 F1 批的关系（重要前提）

`git log -1 --format=%ai` 显示，本轮所有目标文件的最后提交时间**均早于** 2026-08-25 审查日：

| 文件 | 最后提交 |
|---|---|
| DeepBase.Updater.pas / DeepBase.AutoUpdate.pas | 2026-08-18 |
| DeepBase.HttpServer.pas | 2026-08-06 |
| DeepBase.Config.Upload.pas | 2026-08-12 |
| DeepBase.AntiTamper.pas / TimeGuard / CloudBackup / CloudSync / Net / Licensing / Inference.\* / IntentClarification.\* | 2026-07-15 |
| DeepBase.ClipboardGuard.pas / WindowMonitor.pas | 2026-06-17 |
| DeepBase.IntentClarification.Engine.pas | 2026-06-20 |
| DeepBase.Graph.pas | 2026-05-16 |
| DeepBase.Unlock.pas | 2026-05-22 |

`git status --porcelain -- Features/` 仅显示 3 个 Browser 相关文件存在未提交改动，与本组无关。

**结论：F1 批列出的 🔴/🟡 缺陷在本组文件中基本未被修复工单触及。** 因此本轮**不重复计数的前提不成立**——除少数经交叉验证确认已修复的项（见"历史缺陷复核"）外，历史缺陷按当前代码重新取证并计入本轮总数，同时在编号上保留 `F1.x.y` 溯源标记。

## 二、总体统计

> 统计口径：🔴=崩溃/数据损坏/安全漏洞；🟡=功能缺陷；🔵=优化建议；❓=存疑区（需运行期/外部信息确认）。

| 分组 | 🔴 | 🟡 | 🔵 | ❓ | 小计 |
|---|---|---|---|---|---|
| 更新/防篡改（Updater 6/9/1 · AutoUpdate 1/4/1 · AntiTamper 2/4/1 · PersistenceRegistration 0） | 9 | 17 | 3 | 0 | 29 |
| 守护（ClipboardGuard 2/7/1 · TimeGuard 3/4/1 · Unlock 0/4/0 · WindowMonitor 1/8/1） | 6 | 23 | 3 | 1 | 32 |
| 许可（Licensing） | 3 | 5 | 2 | 0 | 10 |
| 云（CloudBackup 9/10/0 · CloudSync 5/7/0 · Config.Upload 1/4/1） | 15 | 21 | 2 | 1 | 38 |
| 网络/图（Graph 3/4/3 · HttpServer 2/6/1 · Net 4/5/1 · Net.Transport 0/5/1 · Net.Transport.ICS 0/3/0） | 9 | 23 | 6 | 2 | 38 |
| 推理（Inference.IoC/Runtime/Service/Session/Types） | 1 | 7 | 1 | 1 | 9 |
| 意图澄清（IntentClarification.\*，50 单元中占 34 个） | 10 | 88 | 19 | 0 | 117 |
| 横向/系统性（X-01~X-09） | 2 | 5 | 2 | 1 | 9 |
| **全部合计** | **55** | **189** | **38** | **6** | **282**（另存疑 6 项不计入） |

> 口径说明：① 意图澄清组的 88 🟡 / 19 🔵 中包含因“模块零接线”而从 🔴 降级的项目（降级前提与 grep 证据见 3.20 章首）；② “正面项”（已做对的实现）不单独立号计数，只在所属条目内标注 ✓；③ 存疑区 6 项（❓）列于第六章，不并入合计列；④ **编号冲突提醒**：`CB-xx` 前缀被两个单元各自使用（§3.5 ClipboardGuard 与 §3.17 CloudBackup），本文属 CloudBackup 的条目均已标 §3.17；其余前缀全库唯一。

> 注：`AT-02`、`TG-04` 原文标为「🔴/🟡」双重严重度，统计时一律按 🔴 计入（保守取高）。

## 三、按单元分组的发现

### 3.1 DeepBase.Updater.pas（`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas`，2368 行）

#### 🔴 U-01 下载式安装的"备份"是空操作，回滚静默失效（历史 F1.5.1 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1952-1972`（`InstallDownloadedUpdate`）、`d:\...\DeepBase.Updater.pas:1576-1579`（`CreateBackup`）

```pascal
  // For downloaded packages, we don't have file list, backup everything
  SetLength(FilesToBackup, 1);
  FilesToBackup[0] := '*.*';
  if not CreateBackup(FilesToBackup) then Exit;
```

`CreateBackup` 内部把每一项与 `FApplicationDir` 拼接后走 `FileExists`/`TFile.Copy`：

```pascal
  for I := 0 to High(AFiles) do
  begin
    LSourceFile := TPath.Combine(FApplicationDir, AFiles[I]);
    if not FileExists(LSourceFile) then Continue;   // ← 'D:\App\*.*' 恒不存在
```

- **问题说明**：`'*.*'` 是通配符字面量而非目录枚举模式，`FileExists('D:\...\App\*.*')` 返回 False，循环 `Continue`，因此**一个文件都没有备份**；但函数随后仍然写出 `manifest.json` 并返回 `Result := True`。上层据此认为"已建立可回滚快照"，实际 `RestoreBackup` 恢复时只遍历一个空清单。
- **触发条件**：任何走"下载包 → 就地安装"路径的更新（`InstallDownloadedUpdate`），且安装过程中 `ApplyUpdate` 抛异常触发回滚。
- **后果**：全量覆盖应用目录后失败，**无法回滚 → 应用目录处于半新半旧的损坏态**（数据损坏级）。
- **建议修复**：`CreateBackup` 增加 `bRecursiveAll: Boolean` 语义（或显式传入 `TDirectory.GetFiles(Dir, '*', soAllDirectories)` 的真实数组），并对"清单非空但实际备份 0 个文件"直接判失败返回 False；`manifest.json` 写入前校验 `CopiedCount > 0`。

#### 🔴 U-02 manifest 签名两条验证路径的输入不一致，合法签名不可能同时通过（用户重点：两路径输入一致性）

- 路径 A：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1831-1846`（`DownloadAndInstall`）

```pascal
    if (Info.ManifestHash <> '') and (not SameText(Info.ManifestHash, ComputedManifestHash)) then
    ...
    if not VerifySignature(ComputedManifestHash, Info.ManifestSignature, SignatureAlg) then
```

- 路径 B：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1275-1293`（`StageAndVerifyPackage`）

```pascal
    ExpectedManifestHash := Info.ManifestHash;
    if SameText(Copy(ExpectedManifestHash, 1, 7), 'sha256:') then
      Delete(ExpectedManifestHash, 1, 7);
    ...
    // §16.10 Step 6: manifest_signature 签的是 payload 的 UTF-8 字节（非 hash）
    if not VerifySignature(ManifestPayload, Info.ManifestSignature, SignatureAlg) then
```

- **问题说明**：A 把**哈希字符串**（且带 `sha256:` 前缀的比较未剥前缀）作为被签数据；B 按 `docs/66 §16.10` 把 **manifest 原文字节**作为被签数据，并且哈希比较前剥离前缀。同一服务端签名值只能匹配其中一种构造。
- **触发条件**：任何正式签名的 manifest。若服务端按规范签 payload → 走 A 的分支恒失败；若服务端签 hash → 走 B 恒失败。
- **后果**：更新链路不可用（可用性缺陷），且更危险的是它会**驱动运维去打开 `InsecureDevMode` 之类的旁路**，从而把安全门整体关掉（间接安全漏洞）。同时 A 路径 `Info.ManifestHash` 未剥前缀与 B 剥前缀，属同一 SSOT 下的两套语义。
- **建议修复**：抽出唯一 `TUpdateSignatureCodec`：`BuildManifestSigningInput()` 与 `NormalizeHashLiteral()` 单点实现，`DownloadAndInstall` 与 `StageAndVerifyPackage` 必须调用同一函数；加一条"同一 manifest 双路径验签结果必须一致"的单元回归测试。

#### 🔴 U-03 签名算法由远端元数据自述，且接受无密钥的 `sha256`"伪签名"→ 远程代码执行

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1464-1471`（`VerifySignature`）

```pascal
    if (LAlgorithm = 'sha256') or (LAlgorithm = 'sha-256') then
    begin
      LExpected := LowerCase(THashSHA2.GetHashString(Data));
      Result := SameText(LExpected, Signature);
      Exit;
    end;
```

配合 `d:\...\DeepBase.Updater.pas:858-860`（`signature_alg` 直接取自响应 JSON）与 `d:\...\DeepBase.Updater.pas:1243-1259`（密钥存在性检查用 `Pos('hmac', Alg) = 1` / `Pos('rsa', Alg) = 1`，对 `'sha256'` **两者都不匹配 → 跳过"必须有公钥"的前置检查**）：

- **问题说明**：`signature` 字段被允许声明为"纯 SHA256 摘要"。攻击者（或任何被 MITM 篡改的响应）只需把 `signature` 填成包哈希本身、`signature_alg` 填 `sha256`，即可在没有私钥的情况下通过"验签"。而密钥存在性门恰好因为算法名前缀不匹配而被绕过。
- **触发条件**：恶意/被劫持的更新响应 + zip 包（`ApplyUpdate` 会把包内文件全量覆盖到 `FApplicationDir`）。
- **后果**：**未认证远程代码执行**（更新即代码执行）。
- **建议修复**：把允许的算法收敛为编译期常量白名单（仅 `RSA-SHA256`/`HMAC-SHA256`），未知/弱算法**直接 fail-closed**；密钥存在性检查改为"非空且可解析"而非按前缀 `Pos`；禁止 `sha256`/`none`/空作为算法值。

#### 🔴 U-04 类方法 `StageAndVerifyPackage` 全程 fail-open（省略字段 = 零校验通过）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:2281-2342`

```pascal
    if AInfo.PackageHash <> '' then
      ... // 仅非空才校验哈希
    if (Signature <> '') and (APublicKeyPEM <> '') then
      ... // 仅非空才验签
    Result := True;   // ← L2341 无条件放行
```

- **问题说明**：这是对外暴露的"暂存并验证"静态入口（供第三方宿主复用），但所有安全校验都是**可选的**：只要响应里不提供 `package_hash`/`signature`，或调用方不传公钥，函数就在**零完整性校验**下返回 True。
- **触发条件**：任何使用公开类方法的宿主（而非内部实例方法路径）。
- **后果**：与 U-03 叠加构成"下载未校验包 → 覆盖安装目录"的完整 RCE 链。
- **建议修复**：引入 `TVerifyPolicy`（`vpStrict` 默认），要求 `PackageHash` 与 `Signature` 必须同时存在且通过；把 `Result` 的默认值改为 False 并在每个失败分支显式 `Exit`；对"字段缺失"与"字段不匹配"返回可区分的错误码，避免调用方以空字符串静默降级。

#### 🔴 U-05 更新检查/下载 URL 无 scheme 与主机白名单校验

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1003`（`BuildUpdateCheckUrl`）、`d:\...\DeepBase.Updater.pas:1417`（`DownloadFile`）
- **问题说明**：`FServerURL`/响应中的 `download_url` 未做 `https://` 强制、未做主机白名单、未禁止重降到 `http://`；`DownloadFile` 对任意传入 URL 直接 GET。
- **触发条件**：配置写错、配置文件被篡改，或网络路径上的 MITM（http 明文源时）。
- **后果**：明文下载 + U-03/U-04 的伪签名 = 中间人注入任意更新包。
- **建议修复**：在 URL 入口集中校验（scheme=https、主机在常量白名单、拒绝用户信息与非常规端口）；下载 URL 只允许来自"已通过验签的 manifest"，不允许来自未认证的顶层响应。

#### 🔴 U-06 静默安装线程 use-after-free（`FSilentInstallTask` 从未赋值，Destroy 的等待分支死代码）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:2069-2122`（`StartSilentInstallLoop`）、`:662/:682`（仅置 nil）、`:672-688`（`Destroy`）、`:2124+`（`StopSilentInstallLoop`）

```pascal
  FSilentInstallThread := TThread.CreateAnonymousThread(
    procedure
    ...
      while not FStopSilentInstall do   // 捕获 Self
```

```pascal
destructor TUpdater.Destroy;
begin
  ...
  if Assigned(FSilentInstallTask) then   // ← 永不为 True（从未赋值）
  begin
    FSilentInstallTask.Wait;
```

- **问题说明**：后台循环用 `CreateAnonymousThread`（`FreeOnTerminate` 默认 True）并捕获 `Self`；对象析构时 `StopSilentInstallLoop` 只 `SetEvent` 通知而不 join；而 `Destroy` 里唯一真正会 join 的分支依赖 `FSilentInstallTask`，该字段从未被赋过非 nil 值 → **死代码**。事件对象 `FStopSilentInstall` 在 `Destroy` 中被 `Free`，运行中的线程下一次 ` WaitFor`/访问字段即触及已释放内存。
- **触发条件**：应用退出时静默安装循环仍在运行（正常退出即可能命中）。
- **后果**：偶发访问违例 / 堆损坏。
- **建议修复**：用局部变量持有 thread 引用，`Terminate + WaitFor`（或把 task 真正赋值为 `TTask.Create`/`ITask` 并在 Destroy 中 `task.Wait`），并把 `FreeOnTerminate := False`；`Destroy` 顺序改为"先确认线程退出，再释放事件/临界区"。

#### 🟡 U-07 `InstallPackage` 备份清单取自 `Info.Files[].RelativePath`，全量包更新时为空 → 回滚无效

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1313-1327`
- **问题说明**：zip 全量包的 manifest 往往 `files: []`（或只含少量差异项），`CreateBackup([])` 空循环后返回 True。与 U-01 同类，是"备份成功"的假阳性。
- **触发条件**：全量 zip 更新 + 安装期异常。
- **建议修复**：备份范围应来自"将要被写入的目标集合"（先在暂存区枚举包内全部相对路径，再据此备份），且空集合视为错误。

#### 🟡 U-08 `ApplyUpdate` 忽略逐文件哈希与 `action='delete'`，运行中 exe 覆盖失败后进入空回滚

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1662-1758`
- **问题说明**：manifest 的 `files[]` 语义只实现了 copy，未实现 `delete`，也不做 per-file hash 复核（只信包级哈希）；对正在运行的 exe 覆盖会抛异常，路径直接进入 `RestoreBackup`（而备份又可能为空 → U-01/U-07）。另外 `Pos('..', FileName) > 0` 的遍历防护过度收紧（合法文件名含 `..` 会被误拒），同时**未防护绝对路径与 `C:` / UNC**（`TPath.Combine(Dest, '\\server\share\x'`) 仍可逃逸）。
- **触发条件**：含删除项的 manifest；含绝对路径/UNC 的恶意 zip。
- **建议修复**：实现 delete；per-file hash 强校验（缺失即拒绝）；路径遍历校验改为 `TPath.GetRelativePath` + "规范化后必须以目标目录为前缀"，并显式拒绝绝对路径/UNC/盘符。

#### 🟡 U-09 `RestoreBackup` 用字符串排序选"最新备份"，且只 copy 不删除新增文件

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1603-1660`
- **问题说明**：目录名含时间戳，字典序 ≈ 时间序仅在同格式同长度时成立（跨时区/手工命名即错），实为"看起来像时间戳"的隐式契约；回滚只覆盖旧文件，**不删除本次新增的文件**，回滚后目录混有新版残留。
- **建议修复**：备份目录名用固定 `yyyyMMdd-HHmmss`+`TFile.GetCreationTime` 排序；回滚前 diff 出新增文件清单（写入 manifest）并删除。

#### 🟡 U-10 `BuildManifestSignaturePayload` 不含文件清单，且把自身签名字段拼入 payload

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1151-1157`
- **问题说明**：被签字符串由版本/URL/哈希等字段拼成，**未包含 `Info.Files` 列表**（zip 内文件集合可被替换而签名仍有效）；同时把 `Info.Signature` 自身纳入 payload（自指），语义可疑，正常实现应排除签名字段。
- **建议修复**：payload 纳入 canonical 化的文件清单（相对路径+大小+hash 排序后拼接）；显式排除 `signature` 字段本身。

#### 🟡 U-11 `TSemanticVersion.Parse` 只剥离小写 `v` 前缀

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:549`
- **问题说明**：`'V1.2.3'` 解析失败或版本号错位，导致"有新版本"判定错误。同仓 `AutoUpdate.NormalizeVersion`（`DeepBase.AutoUpdate.pas:280`）同时处理 `v/V`，是正确参照实现 → 属同一功能双实现且其中一份有 bug（SSOT 问题，见 A-16）。
- **建议修复**：`if Version.Chars[0] in ['v','V'] then Delete(Version,1,1);`，并统一复用一份实现。

#### 🟡 U-12 `CleanupTempFiles` 在 try/except 之外调用，目录不存在时抛异常吞掉 `OnComplete`

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:2265`（实现）、`:1880`（调用点在 try/except 结构之外）
- **问题说明**：`TDirectory.GetFiles(FTempDir)` 在目录不存在时抛 `DirectoryNotFoundException`；调用点位于匿名线程中 try/except 保护范围之外 → 异常逃逸到线程顶层，`OnComplete` 永不回调，UI 停在"正在更新"。
- **建议修复**：`if TDirectory.Exists(FTempDir) then ...`；把清理纳入同一 try/finally；线程体内用顶层 try/except 兜底并保证回调。

#### 🟡 U-13 `DownloadFile` 错误诊断缺失、空响应判成功、整包驻留内存

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1417`
- **问题说明**：非 200 时不设 `FLastError`；`ContentStream` 为 nil / 0 字节时仍 `Result := True`（随后哈希校验会以"空包哈希"失败的形式暴露，错误信息误导）；下载内容整体读入 `TBytes`，大包（数百 MB）内存翻倍。
- **建议修复**：区分"传输失败/状态码非 2xx/空响应"三种原因并写入 `FLastError`；流式写盘（`Stream.CopyTo(FileStream)`）；下载后强制校验 `Size > 0`。

#### 🟡 U-14 全局单例与共享状态缺乏线程安全

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:444`（`Updater` 函数双检锁外层裸读 `FUpdater`）；`FCancelled`/`FLastError`/`FStatus`/`FLastStagedPackagePath` 跨线程读写无同步
- **问题说明**：DCL 的第一次检查未加内存屏障/未用 `Interlocked`，存在"看到非 nil 但对象尚未构造完成"的经典窗口；状态字段在 worker 线程与 UI 线程间裸读写。
- **建议修复**：改用 `TInterlocked.CompareExchange` 或 `Lazy<T>`/初始化单元单例；状态字段用锁或原子访问，跨线程事件通过 `TThread.Queue` 投递。

#### 🟡 U-15 `LaunchHelperForPackage` 命令行参数注入

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:1376`
- **问题说明**：把路径直接内插进命令行字符串，未做引号转义。路径含 `"` 时可追加任意参数（提权 helper 的参数可控）。
- **建议修复**：统一 `QuoteArg`（包裹 `"..."` 并把内部 `"` 转义为 `\"`）；对来自远端的包路径做字符白名单校验。

#### 🔵 U-16 建议：拆分 2368 行大文件

`DeepBase.Updater.pas` 同时承载：版本比较、manifest 解析、验签、下载、暂存、备份、应用、回滚、静默安装循环、清理。建议按 `Updater.Manifest` / `Updater.Verification` / `Updater.Transport` / `Updater.Apply` / `Updater.Rollback` 拆分，公共契约（payload 构造、前缀规范化、路径校验）单点定义——这也是消除 U-02/U-11 双实现漂移的根本手段。

### 3.2 DeepBase.AutoUpdate.pas（`d:\_Progs\02Business\DeepBase\Features\DeepBase.AutoUpdate.pas`，914 行）

#### 🔴 AU-01 RSA 验签前自行 SHA256，被验层又做一次 → 实际校验 `SHA256(SHA256(file))`（两路径输入不一致）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AutoUpdate.pas:867-895`

```pascal
      var H := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
      ...
      DigestBytes := H.HashAsBytes;                     // 已 SHA256
      if not Verifier.VerifySignature(DigestBytes, Info.Signature) then
```

- 交叉取证：`d:\_Progs\02Business\DeepBase\Core\DeepBase.Crypto.RSA.pas:412-422`

```pascal
  BCryptHash(AlgHandle, @AData[0], Length(AData), @LHash[0], 32)  // 内部再次 SHA256
  ... BCryptVerifySignature(KeyHandle, @PaddingInfo, @LHash[0], 32, @ASignature[0], Length(ASignature), 0)
```

- **问题说明**：`TRSAVerifier.VerifySignature(AData: TBytes, ...)` 的契约输入是**原始数据**，实现内部做哈希。`AutoUpdate` 传入预计算摘要 → 双重哈希。而 `Updater.StageAndVerifyPackage`（`DeepBase.Updater.pas:2323`）传的是原始文件字节。同一份签名在两个单元下必然一真一假。
- **触发条件**：任何走 `TAutoUpdate` 的签名包更新（标准签名）→ 恒判"签名无效"。
- **后果**：更新功能不可用；更重要的是它掩盖了真实的签名验证路径，运维极可能以"关掉验签"来绕过（结合 `InsecureDevMode` → 安全门失效）。
- **建议修复**：改为 `Verifier.VerifySignature(FileBytes, Signature)`；或（更推荐）提供显式 `VerifyDigestPreHashed` 并在名字中写明，禁止两个调用点各自拼哈希；补一条"同一文件 + 同一签名，AutoUpdate 与 Updater 判定必须一致"的差分测试。

#### 🟡 AU-02 SHA 校验失败的包体未删除，且 `FLastError` 未设置

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AutoUpdate.pas:849-850`（对比签名分支 `:862-863`、`:890-891`）
- **问题说明**：签名失败路径会 `DeleteFile(TempFile)`，仅哈希不匹配路径直接 `Exit`，把已知被篡改的包留在临时目录；`FLastError` 不写 → 上层拿不到诊断。
- **建议修复**：把"任何完整性失败 → 删除临时文件 + 写 FLastError"收敛到一个 `fail(IntegrityError)` 局部过程。

#### 🟡 AU-03 文档宣称的证书固定回调从未绑定（TLS pinning 死代码）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AutoUpdate.pas:106`、`:121`、`:198`（`OnCertRejected` 属性）；`d:\...\DeepBase.AutoUpdate.pas:528-547`（`CreateHttpClient` 无 `OnValidateServerCertificate` 绑定）
- **建议修复**：`LHTTP.OnValidateServerCertificate := HandleCert;`，或在文档中删除该承诺（当前是"宣称有、实际无"，属虚假安全控制）。

#### 🟡 AU-04 `CheckForUpdateFromJson` 未保护的 `as TJSONObject`；GitHub/Gitee 通道不产出完整性字段 → 必然被自己的门拒绝

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AutoUpdate.pas:564`（`as TJSONObject`）、`:582-717`（GitHub/Gitee 解析）、`:800-804`（完整性门）
- **问题说明**：顶层为 JSON 数组/标量时抛 `EInvalidCast` 冒泡到调用方；GitHub/Gitee 分支从不填 `SHA256`/`Signature`，而 `DownloadUpdate` 在 `:800` 处要求二者之一 → 这两个通道实际不可用。
- **建议修复**：`if not (Root is TJSONObject)` 显式报错；对公开托管通道改为"至少强制 SHA256 且 SHA256 必须来自签名过的源"，否则在 `CheckForUpdate` 阶段就明确不支持并给出错误码。

#### 🟡 AU-05 非 200 静默 `Exit`、`ContentStream` 未判 nil、整包缓冲

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AutoUpdate.pas:825-826`、`:828`
- **建议修复**：显式区分状态码并写入 `FLastError`；`Assigned(Response.ContentStream)` 检查；流式落盘。

#### 🔵 AU-06 架构：与 Updater 存在 SSOT 分裂（重复的 `TUpdateChannel` 与**同名 `TUpdateInfo` record**）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AutoUpdate.pas:76-97`
- **问题说明**：两个单元各自定义 `TUpdateInfo`（字段集合不同），别名 `TUpdateChannel` 也重复。跨单元传参只能靠隐式转换/手工映射，正是 U-02/AU-01 类"两路径不一致"根因。
- **建议修复**：抽出 `DeepBase.Update.Contracts` 单元，定义唯一 `TUpdateInfo` 与唯一签名 payload 编解码器；`AutoUpdate` 与 `Updater` 均依赖它，自身只做编排。

### 3.3 DeepBase.AntiTamper.pas（`d:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas`，565 行）

#### 🔴 AT-01 `IsSecureImageEnabled` 异常时 fail-open，防篡改判定可被"破坏存储"绕过（历史 F1.1.3 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas:483-498`

```pascal
  Result := True;
  try
    Result := GetStorage(ADatabasePath).IsSecureImageEnabled(AQuery);
  except
    on E: Exception do
    begin
      WriteLog('...');
      Result := True;
    end;
  end;
```

- **问题说明**：安全属性判定在异常时返回"通过"。攻击者只需制造异常（损坏表/断开连接/传入畸形查询），即可让任何查询都得到"该图像已安全启用"。
- **触发条件**：DB 层任意异常（含权限、锁、损坏）。
- **建议修复**：安全门必须 fail-closed（`Result := False`），并把异常上报为独立状态 `ateStorageUnavailable` 以便区分"未启用"与"无法判定"（对应 `docs/66` 的 EDGE-006 fail-closed 原则）。

#### 🔴/🟡 AT-02 `HandleSecurityViolation` 在任意线程 `MessageBox` + `Halt(1)`（历史 F1.1.7 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas:499-529`
- **问题说明**：`Halt` 跳过所有 `finally`/析构 → 事务不回滚、日志缓冲丢失、DB 连接不释放（可能造成数据损坏）；模态框出现在后台线程会卡死无人可见（服务/无头场景永久挂起）。同时这也给了攻击者一个"只要触发误报就能 DoS"的靶点。
- **建议修复**：改为向上传播 `ETamperDetected` 异常，由应用主线程决定退出；退出前经 `TAmperAudit.Flush`，用 `Application.Terminate`/受控关闭流程。

#### 🟡 AT-03 KDF 迭代次数默认值与使用值不一致（历史 F1.1.1 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas:107`（`KdfIterations := 5000`）vs `:196`（`Iterations := Max(FConfig.KdfIterations, 10000)`）
- **问题说明**：默认配置写 5000，实际执行被 `Max(...,10000)` 抬到 10000。若某条加密路径用 5000、另一条用 10000（例如 `Max` 只在一处），则记录间参数漂移导致解密失败；至少是"声明与实施不一致"。
- **建议修复**：把迭代次数作为随密文一同持久化的参数（并在解密时按存储值执行），删除 `Max` 魔法修正，统一从常量单元取值。

#### 🟡 AT-04 `WriteLog` 无 try/finally，安全审计日志被吞；RELEASE 下日志整体关闭（历史 F1.1.2 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas:159-168`；`:3-5`（`{$IFDEF RELEASE} {$DEFINE NO_DEBUG_LOG}`）
- **问题说明**：`AssignFile/Rewrite/.../CloseFile` 无 finally，写失败时文件句柄泄漏；`except end` 静默吞异常。更关键：审计日志在 Release 编译下被条件编译整体关闭 → **生产环境的防篡改事件零留痕**，安全事件不可追溯。
- **建议修复**：安全审计日志不得随调试开关关闭；用 `try/finally CloseFile`；失败时降级到 Windows 事件日志/备用 sink 并计数告警。

#### 🟡 AT-05 `ReseedMinimal` 写入零长密文，seed 记录加载即抛异常（历史 F1.1.4 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas:542-563`（`Data.EncryptedImageData := EmptyData`）、`:297`（`DecryptImageData` 对 `Length < 16` 抛异常）
- **建议修复**：为"最小 seed"定义显式空标记（如 `HasImage=False` 且跳过解密），或写入合法的空明文密文块（含 IV/HMAC），保证解密路径可正常返回。

#### 🟡 AT-06 类级可变状态无锁；`EnableHMAC=False` 可完全取消完整性认证

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas:41-43`（`class var FConfig/FInitialized/FStorageFactory`）、`:460`（HMAC 校验位于 `if FConfig.EnableHMAC then`）、`:226-227`（`GetEffectiveKeyString` 将派生密钥 hex 化后当作 HMAC key）
- **问题说明**：多线程首次 `Initialize` 存在竞态（双初始化 / 半初始化）；关闭 HMAC 后 AES-CBC 无任何 MAC → 可被字节翻转（padding oracle 风险面）。把加密子密钥的 hex 文本直接当认证密钥，跨用途复用同一密钥材料。
- **建议修复**：`FInitialized` 用 `TInterlocked`/`TCriticalSection` 保护一次性初始化；把 `EnableHMAC` 从可配置项中移除（生产强制开启），或改为"关闭即拒绝写"；用 HKDF 分别派生 ENC_KEY 与 MAC_KEY，禁止 hex 复用。

#### 🔵 AT-07 历史 F1.1.5/F1.1.6：HMAC 先摘要再 hex 化；重复实现常量时间比较（未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas:321-342`（自行手写比较）vs `:241`（已有 `ConstantTimeCompare`）
- **建议修复**：统一调用 `ConstantTimeCompare`；哈希/HMAC 编码约定（raw vs hex）在文档与代码中单点定义。

### 3.4 DeepBase.AntiTamper.PersistenceRegistration.pas（24 行）

7 个维度均**未发现问题**。该单元为薄注册垫片（把存储工厂注册到 AntiTamper 的 `FStorageFactory`）。唯一提示：它写入的是 3.3/AT-06 中所述**无锁类变量**，注册时序与首次 `Initialize` 的竞态由 AT-06 覆盖，不在本单元重复计数。

### 3.5 DeepBase.ClipboardGuard.pas（`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas`，342 行）

#### 🔴 CB-01 三处 `GlobalAlloc`/`GlobalLock` 返回值未检查 → nil 解引用（历史 F1.6.1 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas:185-187`（`SetContent`）、`:201-203`（`SetContentBytes`）、`:265-267`（`RestoreInternal`）

```pascal
  var hMem := GlobalAlloc(GMEM_MOVEABLE, CharSize);
  var pMem := GlobalLock(hMem);
  Move(PChar(Text)^, pMem^, CharSize);
```

- **问题说明**：`hMem = 0`（内存不足/剪贴板占用）时 `GlobalLock` 返回 nil，`Move` 目的地址 nil → AV。`Text = ''` 时 `CharSize = SizeOf(Char)`，但 `PChar('')` 在 Delphi 中指向 `#0` 常量（可读写越界风险取决于长度计算），`SetContentBytes` 中 `Move(Data[0], ...)` 在 `Length(Data) = 0` 时**源索引越界**（`ERangeError`/AV）。
- **触发条件**：低内存、剪贴板被其他进程锁定、清空内容/零长字节数组调用。
- **建议修复**：统一封装 `AllocateClipboardBlock: Boolean`，逐级检查 `hMem <> 0`、`pMem <> nil`、`Length > 0`，任一失败即 `GlobalFree` 并返回失败；空内容走 `EmptyClipboard` 语义。

#### 🔴 CB-02 剪贴板明文（可能含口令/令牌）被无加密、永不清理地写入磁盘（CWE-313）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas:286-329`（`SaveBackupToTemp`/`SaveBackupToPath`）、`:86-96`（析构兜底路径）
- **问题说明**：本单元的用途正是"守卫剪贴板"，其备份却把**整份原始剪贴板内容**以明文写到 `%TEMP%\DeepBase\` 与 `%APPDATA%\DeepBase\clipboard_backups\`，文件名带时间戳，**从不加密、从不删除**。口令管理器复制的密码、令牌、私钥片段都会持久化落盘。
- **触发条件**：任何一次 Save/Restore 失败路径（析构里的兜底尤其常见）。
- **建议修复**：(a) 用 `TAmperStorage`/DPAPI/AES-GCM 加密备份 blob；(b) 设置 TTL 与最大保留数并在 `Restore` 成功后立即 `DeleteFile`；(c) 提供"敏感格式不落盘"白名单；(d) 目录 ACL 限定当前用户。

#### 🟡 CB-03 `SetClipboardData` 返回值全未检查 → 句柄泄漏（历史 F1.6.2 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas`（3 处 `SetClipboardData(...)`）
- **问题说明**：`SetClipboardData` 失败时所有权仍归调用方，不 `GlobalFree` 即泄漏；成功时绝不可再 `GlobalFree`（当前代码两条路径都未处理）。
- **建议修复**：`if not SetClipboardData(fmt, hMem) then GlobalFree(hMem);`

#### 🟡 CB-04 `Save` 中 `GlobalLock` 结果未判 nil 即 `Move`（历史 F1.6.3 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas:154-160`
- **建议修复**：`if pData = nil then Continue;`，并检查 `GlobalSize` 与实际读取长度。

#### 🟡 CB-05 `DoPaste` 不检查 `SendInput` 返回值，失败时 Ctrl 键卡在按下态（历史 F1.6.4 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas:211-241`
- **问题说明**：注入被 UIPI/锁工作站阻断时返回 0，Ctrl keydown 已发出但 keyup 丢失 → 用户键盘进入"Ctrl 常按"状态，后续按键全变快捷键。
- **建议修复**：检查每次 `SendInput` 返回值；失败时补发 keyup 做安全复位，并记录失败。

#### 🟡 CB-06 `GetOriginalContent` 恒返回空串（历史 F1.6.5 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas:331-334`
- **建议修复**：实现或从接口移除（当前是"接口承诺存在、实现永远空"，调用方以为无原内容）。

#### 🟡 CB-07 手写 `_AddRef/_Release` 使用非原子 `Inc/Dec`（历史 F1.6.6 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas:103-114`
- **问题说明**：跨线程交接接口引用时计数竞态 → 提前释放（UAF）或泄漏（对象永不释放）。
- **建议修复**：`TInterlocked.Increment/Decrement`，或直接继承 `TInterfacedObject` 并删除手写实现。

#### 🟡 CB-08 析构中 `Restored := True` 被过早置位，兜底备份路径不可达

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas:63-101`（`:73-77`）
- **问题说明**：`PreCheckMemory` 失败（本应"未能恢复"）也走 `Restored := True` 分支 → CB-02 的磁盘备份兜底永不执行（安全功能静默失效）；同时析构里最长 `5 × Sleep(200)` 阻塞退出流程 1 秒。
- **建议修复**：区分 `succeeded / skipped / failed` 三态，仅 `succeeded` 才跳过兜底；不要在析构中 sleep（改为一次 `OpenClipboard` 重试上限后立即放弃并落盘备份）。

#### 🟡 CB-09 `Restore` 不做 `PreCheckMemory`，而 `Destroy` 做 → 行为不一致

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas:243`
- **建议修复**：把前置检查移入 `RestoreInternal`，两个入口共享。

#### 🔵 CB-10 `Save` 全量复制所有剪贴板格式的完整字节

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.ClipboardGuard.pas:143-165`
- **问题说明**：复制大位图/文件列表（`CF_HDROP`、`PNG` 私有格式）时全部驻留内存，且实际只需 `CF_UNICODETEXT`/`CF_BITMAP` 等少数格式。
- **建议修复**：格式白名单 + 单格式体积上限（超限只保存该格式的延迟恢复标记）。

### 3.6 DeepBase.TimeGuard.pas（`d:\_Progs\02Business\DeepBase\Features\DeepBase.TimeGuard.pas`，489 行）

#### 🔴 TG-01 RFC-822 的 GMT 被当作本地时间 → UTC+8 环境每次在线 Verify 恒判 `tgSkewMajor`，并把回拨阈值整体平移 8 小时（历史 F1.7.1 未修，用户维度⑤"许可证时钟回拨"）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.TimeGuard.pas:263`（`EncodeDateTime` 无时区处理）、`:434`（`FServerTimeOffset := LServerTime - LLocalNow`）、`:438`、`:448`、`:452-457`
- **问题说明**：解析出 UTC 字段后直接 `EncodeDateTime(...)` 返回"本地化的数值"，忽略末尾 `GMT`。在 UTC+8：`LServerTime` 比真实本地时刻早 8 小时 → `offset = -8h` → `Abs(DriftMinutes) = 480 > MaxDriftMinutes(5)` → 恒 `tgSkewMajor`；并且 `:448` 把这个 UTC 数值存成"最后可信时间"，`:438` 的回拨判定基准也被抬高/压低 8 小时：**用户把系统时间往回拨最多 8 小时完全不会被发现**（这正是本单元存在的目的）。
- **触发条件**：任何非 UTC 时区（≈全球绝大多数用户），只要执行一次 Verify。
- **建议修复**：`Result := EncodeDateTime(...) ` 之后 `LocalToUTC/UTCToLocal` 显式转换（或直接使用 `VarFromUTCDateTime`/`TDateTimeUtils`）；比较统一在 UTC 域进行；`SaveLastKnownGoodTime` 存的必须是与比较域一致的时区基准；补一条"UTC+8/UTC-5 下 offset≈0"的单元测试。

#### 🔴 TG-02 未 Verify 即视为可信（fail-open）（历史 F1.7.2 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.TimeGuard.pas:325`（`FLastVerifyResult := tgOffline`）、`:470-473`（`IsTimeTrusted` 把 `tgOffline` 当可信）
- **问题说明**：构造后的初始状态就是"可信"，应用若从不调用 `Verify`（或调用前就查询）则防护形同不存在；`tgOffline` 与"从未验证"无法区分。
- **建议修复**：初始状态引入 `tgUnknown` 且 `IsTimeTrusted` 对 `tgUnknown` 返回 False；`tgOffline` 时要求"本地存储的最后可信时间 + 允许的离线窗口"双重判定。

#### 🟡 TG-03 `Verify` 无条件 `FVerified := True`，离线时仍用陈旧的 `FServerTimeOffset` 修正时间（历史 F1.7.3 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.TimeGuard.pas:399`、`:462-468`
- **问题说明**：离线路径把"上一次在线时算出的 offset"当作仍然有效。若上次在线是 30 天前且当时时钟已错，则所有试用到期判定都用错误时间（可被利用：断网 + 提前系统时钟即可延长试用）。
- **建议修复**：`FVerified` 仅在线成功时置真；`GetCorrectedNow` 在离线时使用 `LastKnownGoodTime + 经过的单调 tick 估计`，并对 offset 的"年龄"设上限。

#### 🔴/🟡 TG-04 时间信任根未认证：任意主机的 HTTP `Date` 头都被当作权威时间，且 `SetServerUrl` 不校验 scheme

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.TimeGuard.pas:278-314`（`FetchServerTime`，`LHTTP.Get(AUrl)` + 接受任意 `<400` 响应的 `Date`）、`:329-335`（`SetServerUrl` 无校验）
- **问题说明**：无证书/主机固定、无响应签名。MITM（或 http 明文）可任意伪造 `Date`：往前推 → 永久误报"时钟回拨"（DoS）；往后推 → 让回拨检测阈值失效，用户可任意调表。
- **建议修复**：`SetServerUrl` 强制 https 且主机白名单为编译期常量；把服务器时间纳入带签名的响应载荷（而非依赖 `Date` 头）；对单次偏移设置合理上限（>25 小时直接拒绝采信）。

#### 🟡 TG-05 未注入 SecretStore 时静默失去持久化，回拨检测整体失效

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.TimeGuard.pas:354-357`（`GetSecretStore` 直接返回可能为 nil 的 `FSecretStore`）、`:365-366`、`:382-383`（save/load 静默 no-op）
- **建议修复**：`Verify` 开头 fail-fast（无 store 即返回 `tgStorageUnavailable` 并记日志），或提供内置的加密文件后备存储；不得静默降级。

#### 🟡 TG-06 `ParseRfc822Date` 假定 index 0 是星期，且解析变量被污染

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.TimeGuard.pas:210`（`for I := 1 to High(LParts)`）、`:216`、`:220`
```pascal
  for I := 1 to High(LParts) do        // 跳过 [0]
    ...
    if (LYear = 0) and TryStrToInt(LParts[I].Trim, LYear) and (LYear >= 1970) then
```
- **问题说明**：(a) 无星期前缀的日期串（`"3 Jul 2026 12:34:56 GMT"`）会整体偏移一位，仍从 1 开始扫会漏掉首位数字；(b) `TryStrToInt` 成功但条件失败时 `LYear` **已被写入**（如 `"25"` → LYear=25），后续 `LYear = 0` 判假 → 真正的年份再也无法被采纳，最终 `EncodeDateTime(25, ...)` 得到荒谬日期或抛异常 → `Result := 0` → 永远 `tgOffline`；`LDay` 同理（`TryStrToInt` 把月份数字先吃成 LDay）。
- **建议修复**：改用显式格式匹配（先按空格切 5~6 段并定位时间段的 `:`），或用 `TryRFC822ToDateTime`/`VarDateFromStr`；`TryStrToInt` 结果先取到临时变量再判条件。

#### 🟡 TG-07 枚举文档语义与实现矛盾

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.TimeGuard.pas:48-50`（注释）vs `:452-457`（实现）
- **问题说明**：注释称 `tgSkewMinor` = "偏差 <= MaxDriftMinutes"，实现里 `<= MaxDriftMinutes` 判的是 `tgOk`；注释称 `tgSkewMajor` = "但 < 24 小时"，实现无任何上界。调用方按注释写分支会走错。
- **建议修复**：以实现为准重写文档，或补齐 24h 上界并新增 `tgSkewImplausible`；把阈值常量集中定义。

#### 🔵 TG-08 注释说用 HEAD 请求，实现用 GET 全量下载响应体

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.TimeGuard.pas:64`、`:292`
- **建议修复**：`LHTTP.Head(AUrl)`（或 `CustomRequest('HEAD', ...)`），避免为读一个头下载整页。

### 3.7 DeepBase.Unlock.pas（`d:\_Progs\02Business\DeepBase\Features\DeepBase.Unlock.pas`，543 行）

#### 🟡 UK-01 `ApplyCode` 返回值与文档承诺不符，降级被忽略（历史 F1.3.1 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Unlock.pas:126-127`（文档："Returns True only when uvsOk **and** level was accepted"）、`:508-526`（实现）
```pascal
  Result := Status = uvsOk;
```
- **问题说明**：当码合法但请求层级低于/不符合当前状态（`WasUpgraded = False` 的降级拒绝分支）时仍返回 True，UI 会提示"解锁成功"而实际层级未变。
- **建议修复**：`Result := (Status = uvsOk) and LApplied;`，并区分错误码 `uokInvalid / uokExpired / uokDowngradeRejected`。

#### 🟡 UK-02 解锁码熵过低、无尝试限速，且硬编码种子可离线批量伪造

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Unlock.pas:168`（`UNLOCK_SECRET = 'DeepBase-Unlock-Seed-2025'`）、`:172`（32 字符表）、`:454-465`（同时接受 legacy 校验方案）
- **问题说明**：单字符 `CheckChar` + 32 字符表 + 时间窗口 3 个月（窗口内有效字符仅约 6 个）+ 3 个层级 → 穷举 ≤53~96 次即可得到一个可用的 `ulShare` 码；模块**没有任何尝试次数限制、冷却或锁定**。同时 secret 以明文字符串常量存在于二进制中，`strings` 提取后可离线生成任意层级/任意年份的码。
- **触发条件**：本地暴力枚举（无网络参与），或逆向二进制。
- **建议修复**：(a) 至少 2~3 个校验字符或改走 HMAC 截断（≥40 bit）；(b) 失败计数 + 指数退避（持久化）；(c) 移除 legacy 双方案兼容或在 Release 下禁用；(d) 密钥不落地：改由服务端签发或经白盒/派生（并结合 AT-06 的密钥派生统一处理）。

#### 🟡 UK-03 未来月份的合法码被误判为 `uvsExpired`；年份窗口硬编码 2000–2099

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Unlock.pas:480`（`YearFull := 2000 + Y2`）、`:495-500`
- **建议修复**：区分 `uvsNotYetValid`；年份基准来自配置常量并做范围校验。

#### 🟡 UK-04 `StrToLevel` 未知值静默降级为 `ulFree`；`StoredLevel` 明文存于 Settings 表

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Unlock.pas:216-229`
- **问题说明**：解析失败与"确实是 Free"不可区分（掩盖数据损坏）；层级明文存储 → 手工编辑配置表即可改层级（与 AT-01 的 fail-open 叠加会失去判定依据）。
- **建议修复**：解析失败抛异常/返回 `False`+out 参数；层级持久化附带 HMAC（复用 AntiTamper 的 HMAC 机制），读取时校验。

### 3.8 DeepBase.TimeGuard/Licensing 之外的守护交叉项

- `Unlock` 依赖 `TimeGuard` 的时间语义，TG-01/TG-02/TG-03 会使 UK 的有效期判定整体偏移；修复需两单元联动。

### 3.9 DeepBase.Licensing.pas（`d:\_Progs\02Business\DeepBase\Features\DeepBase.Licensing.pas`，1030 行）

#### 🔴 LC-01 离线首启 `Initialize` 必抛异常，许可门面完全不可用（递归初始化缺陷）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Licensing.pas:546`（`Initialize` 在 `FIsInitialized := True`（`:548`）**之前**调用 `RefreshCachedTier`）、`:500-506`、`:1008-1014`

```pascal
// RefreshCachedTier
    else if not FIsOnline then
    begin
      if IsOfflineGraceActive then Exit;   // ← 内部第一步 EnsureInitialized

// IsOfflineGraceActive
    begin
      EnsureInitialized;                    // FIsInitialized 仍为 False
      raise EDeepBaseCommerceError.Create(...);
```

- **问题说明**：`Initialize` → `RefreshCachedTier` → `IsOfflineGraceActive` → `EnsureInitialized` → 因 `FIsInitialized` 尚未置真而抛 `EDeepBaseCommerceError`。这是一条初始化期自依赖环。
- **触发条件**：设备在无网络（`TryLogin` 失败 → `FIsOnline = False`）下首次启动。
- **后果**：产品离线启动即崩（或所有上层功能因未捕获异常而中断）。
- **建议修复**：把 `FIsInitialized := True` 提前到依赖它的工作之前（或在 `Initialize` 内部路径调用"不校验初始化"的私有 `RefreshCachedTierCore`）；`IsOfflineGraceActive` 等被初始化流程调用的方法不得再 `EnsureInitialized`；补"离线冷启动"集成测试。

#### 🔴 LC-02 `VerifyTime` 从不给 TimeGuard 注入 SecretStore → 时钟回拨检测整体失效

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Licensing.pas:821-830`

```pascal
    FTimeGuard := TTimeGuard.Create(FConfig.AppID + '.timeguard');
    FTimeGuard.SetServerUrl(FConfig.ServerBaseURL);
    // ← 无 SetSecretStore
```

- **问题说明**：结合 TG-05（无 store → save/load 静默 no-op），`LoadLastKnownGoodTime` 恒为 0，`tgClockRewound` 分支永远不可达。单元头注释（`:12` "Store last known good time in encrypted storage"）与实际行为矛盾。
- **后果**：用户可通过调整系统时间无限延长试用/绕过到期。
- **建议修复**：注入加密 SecretStore（与 AntiTamper/安全存储层复用）；在缺少 store 时 `VerifyTime` 返回明确失败码；加一条"回拨 30 天必须报 tgClockRewound"的回归测试。

#### 🔴 LC-03 时间可信判定双重 fail-open

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Licensing.pas:840-846`

```pascal
  if not Assigned(FTimeGuard) then
    Result := True;   // Trust by default if not verified
```

- **问题说明**：未 Verify（含 LC-01 抛异常后的状态、纯离线从未验证）时直接判"可信"，叠加 TG-02 的 `tgOffline` 可信 → 时间防护在最常见的离线场景里默认放行。
- **建议修复**：未验证时返回 False，由上层依据"离线宽限期"策略决定是否降级为 Free，而不是默认信任。

#### 🟡 LC-04 Pro 权限断网不降级；在线刷新异常被吞并保留旧缓存

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Licensing.pas:463-485`（`FIsOnline` 仅在 `Initialize`→`TryLogin` 设置一次，无重连路径）、`:496-498`（`except` 吞异常并保持 `FCachedTier`，含 `ltPro`）
- **问题说明**：进程启动时在线拿到 Pro，之后服务器吊销/订阅到期也不会降级（长驻进程终身 Pro）；反之启动时登录失败 → `FPermissions = nil` → 终身 Free 且无重试。
- **建议修复**：定期（如每 30 分钟 + 网络恢复事件）重刷 tier；`except` 记录并区分"网络不可达"（保留缓存 + 进入宽限）与"服务器明确拒绝"（立即降级）；`FPermissions = nil` 时提供 `RetryLogin`。

#### 🟡 LC-05 试用到期配置项只读不写，`IsTrialActive`/`GetTrialDaysRemaining` 恒失效

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Licensing.pas:325`（`CFG_TRIAL_EXPIRES` 声明）、`:681`（唯一读取点）、`:645-662`（`StartTrial` 只写本地标记，从不写 expires）
- **问题说明**：`GetTrialDaysRemaining` 恒 -1 → `IsTrialActive` 恒 False；`StartTrial` 不校验服务端是否真的授予了试用。
- **建议修复**：`StartTrial` 成功后由服务端返回的到期时间写入 `CFG_TRIAL_EXPIRES`；服务端未授予时不得本地伪造。

#### 🟡 LC-06 RSA 签名快照只写不读，文档承诺的"离线快照回退"无消费方

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Licensing.pas:327-328`、`:999-1000`
- **问题说明**：单元头（`:18` "offline fallback via RSA-signed license snapshots"）承诺的能力，实际只持久化从不解析使用 → 离线降级策略退化为 `IsOfflineGraceActive`（而它又是 LC-01 的崩溃点）。
- **建议修复**：实现 `LoadSnapshotAndVerify`（校验签名 + 有效期）并在离线分支使用；或更新文档取消该承诺。

#### 🟡 LC-07 `FTimeGuard` 惰性创建无锁 → 并发下重复创建并泄漏；缓存字段无同步

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Licensing.pas:824`（`if FTimeGuard = nil then FTimeGuard := TTimeGuard.Create(...)`）
- **问题说明**：两个线程同时进入 → 前者实例被覆盖泄漏（`Destroy` 只 Free 最后一个）。`FCachedTier`/`FFeatureIndex` 多线程读写无保护；`GetCorrectedNow`/`IsTimeTrusted` 不做 `EnsureInitialized`（与其余方法不一致，未初始化即返回垃圾值）。
- **建议修复**：统一 `TCriticalSection` 或 `System.Threading.Lazy<T>`；补齐 `EnsureInitialized` 一致性；`Destroy` 中按引用置 nil 后释放。

#### 🟡 LC-08 `HasFeature` 整型特性分支实现与文档相反

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Licensing.pas:162-165`（文档）vs `:587-591`（实现）
- **问题说明**：文档称"返回 True 表示使用了 Pro 值"，实现对 Free 档（值 > 0）也返回 True → Free 用户被判定拥有该特性。
- **建议修复**：`(Result := (CurrentTier = ltPro) and (Def.ProInt <> Def.FreeInt))` 之类显式判定，或改文档并把判定责任交给 `GetFeatureInt`。

#### 🔵 LC-09 建议：`GetTier` 增加 TTL 刷新；`TryLogin` 的 `on E: Exception do` 变量未使用（丢失原因），应至少 `Logger.Warn(E.ClassName + ': ' + E.Message)`。

#### 🔵 LC-10 建议：门面层不应同时持有"权限缓存 + 快照 + 离线宽限 + TimeGuard"四种真相来源；tier 判定应集中到一个 `TTierResolver`（SSOT）。

### 3.10 DeepBase.WindowMonitor.pas（`d:\_Progs\02Business\DeepBase\Features\DeepBase.WindowMonitor.pas`，440 行）

#### 🔴 WM-01 声明为 ANSI API 却传 `PChar`(PWideChar) → 进程名解析错乱，监视目标永不命中（历史 F1.8.1 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.WindowMonitor.pas:102-104`（声明）、`:419-429`（调用）

```pascal
function QueryFullProcessImageName(hProcess: THandle; dwFlags: DWORD;
  lpExeName: PChar; var lpdwSize: DWORD): BOOL; stdcall;
  external 'kernel32.dll' name 'QueryFullProcessImageNameA';
```

```pascal
  SetLength(Result, MAX_PATH);
  Len := MAX_PATH;
  if QueryFullProcessImageName(hProcess, 0, PChar(Result), Len) then
    SetLength(Result, Len);
```

- **问题说明**：入口被硬绑定到 `...A`（ANSI）版本，缓冲区却是 `UnicodeString` 的 `PWideChar`。API 往缓冲区写单字节 ASCII，每个字符后残留原高字节；`Len` 返回的是**字节数**却被当作字符数 `SetLength`。结果 `Result` 形如 `'c\x00h\x00r...'`/尾部脏字节混合体，长度亦错。
- **触发条件**：任何一次前台窗口变化（`HandleForegroundChange` → `GetProcessNameFromHWND`）。
- **后果**：`FWatchTargets.Contains(NewProc)`（`:224`）恒 False → 整个监视功能失效；若调用方把该串用于路径/日志拼接，还可能引入后续解码错误。属安全监视类功能静默失效（该单元用于防御性监控，故按 🔴 计）。
- **建议修复**：绑定 `name 'QueryFullProcessImageNameW'` 且参数用 `PWideChar`，`Len` 为字符数；或改用 `GetModuleFileNameExW`/`QueryFullProcessImageName` 的 Delphi 官方封装（`Winapi.PSAPI`，本单元已 uses）。

#### 🟡 WM-02 `TThread.WaitFor` 返回值语义误用 → 假告警 + `Terminate` 永不生效（历史 F1.8.2 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.WindowMonitor.pas:174-182`

```pascal
    if FPollThread.WaitFor = 0 then
    begin
      Logger.Warn('WindowMonitor: poll thread did not exit in 5s', 'WindowMonitor');
      FPollThread.Terminate;
    end;
```

- **问题说明**：`WaitFor` 返回等待结果**卡数**，`0` 表示"已成功等到线程结束"，`WAIT_TIMEOUT(258)` 才是超时。当前逻辑把"正常退出"当日志告警，把真正的超时漏掉；且 `WaitFor` 在 `FreeOnTerminate = False` 下总是阻塞到结束（不会 5s 超时），所以后面的 `Terminate` 是死代码。
- **建议修复**：`FreeAndNil(FPollThread)` 即可（`TThread.Destroy` 内部会 WaitFor）；若需超时语义改用 `FPollThread.FinishThread`/自行 `WaitFor` 判 `WAIT_TIMEOUT(<>0)` 并告警。

#### 🟡 WM-03 轮询线程计算结果被丢弃，`RegisterProcessCallback` 注册的回调永不触发（历史 F1.8.3 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.WindowMonitor.pas:287-307`

```pascal
        for var Target in Targets do
        begin
          var Running := IsProcessRunning(Target);   // ← 结果从未使用
        end;
```

- **问题说明**：全文件搜索无任何 `NotifyProcess` / 遍历 `FProcessCallbacks` 的代码；`FProcessCallbacks`（`:51`）仅在 `RegisterProcessCallback`/`UnregisterCallback` 中被增删。也没有"上一次状态"的对比存储，因此 `psStarted/psStopped` 边沿检测逻辑整体缺失。
- **后果**：公开 API `RegisterProcessCallback` 是空头承诺，调用方注册的回调静默不触发；每 30 秒白做一次全进程快照（纯性能开销）。
- **建议修复**：新增 `FProcessState: TDictionary<string, Boolean>`，在轮询中对比并投递 `TThread.Queue` 通知 `FProcessCallbacks`；或从接口中删除该能力。

#### 🟡 WM-04 `AddWatchTarget` 的 `ExpectedPath` 参数被完全忽略（历史 F1.8.4 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.WindowMonitor.pas:367-372`（写入 `FWatchTargetPaths`）、`:47`
- **问题说明**：`FWatchTargetPaths` 只写不读，轮询与前台判定均只用进程名匹配。攻击者只需把自己的进程命名为 `explorer.exe`/受监控名即可冒充目标（路径校验是本参数存在的唯一理由）。
- **建议修复**：在 `HandleForegroundChange` 中对命中项做 `SameText(TPath.GetFileName(GetProcessNameFromHWND), Target) and SameText(fullPath, ExpectedPath)`；无 `ExpectedPath` 时显式记录"弱匹配"。

#### 🟡 WM-05 `Stop` 无条件清空 class var `FActiveInstance`，与回调存在 UAF 竞态（历史 F1.8.7 未修）

- 位置：`:57`（`class var FActiveInstance`)、`:138`（`TInterlocked.Exchange`）、`:149`、`:184`（`FActiveInstance := nil`）、`:196`（回调读 `FActiveInstance`）
- **问题说明**：(a) `Stop` 不判断当前 `FActiveInstance` 是否就是 `Self`，实例 B 的 `Stop` 会把实例 A 的活动指针清掉，导致 A 的钩子回调被丢弃；(b) `Start` 用 `Exchange` 静默抢占，两个 monitor 互相覆盖，先创建者收到事件但已非"活动实例"，钩子句柄泄漏语义混乱；(c) `WinEventCallback` 在 `var Instance := FActiveInstance` 取到非 nil 后进入 `Instance.HandleForegroundChange`，与另一线程 `Stop` → `Destroy` 并发即**对正在析构对象的调用（use-after-free）**；`Stop` 里的 `UnhookWinEvent` 并不能保证已投递到消息队列的回调不再执行。
- **建议修复**：`if FActiveInstance = Self then FActiveInstance := nil;`（配合 `TInterlocked.CompareExchange`）；`Start` 在已有活动实例时抛错而非抢占；`WinEventCallback` 与 `Destroy` 之间加引用计数或全局锁保护（在类级别 `TCriticalSection` 内取实例并 `_AddRef`，用完 `_Release`）。

#### 🟡 WM-06 容器锁策略不一致，`FWatchTargetPaths` 裸字典跨线程读写（历史 F1.8.5 未修）

- 位置：`:46`（`FWatchTargets: TThreadList<string>`）、`:47`（`FWatchTargetPaths: TDictionary<string,string>`）、`:367-372`（无锁写）
- **问题说明**：同一逻辑集合一半用 `TThreadList` 保护、一半裸放；`AddWatchTarget`/`RemoveWatchTarget`（调用方线程）与轮询线程读取之间无任何同步 → `TDictionary` 在并发修改下可崩溃/死循环。
- **建议修复**：统一用一把 `TCriticalSection`（或 `TReaderWriterLock`）保护两组集合；`FWindowCallbacks`/`FProcessCallbacks` 已有 `FCallbackLock` 也应复用同一模式。

#### 🟡 WM-07 `AddWatchTarget` 不去重，`Remove` 只删一次（历史 F1.8.6 未修）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.WindowMonitor.pas:369`
- **问题说明**：`TThreadList.Add` 允许重复；重复注册同名目标导致轮询里对同一目标多次快照；`RemoveWatchTarget` 的 `Remove` 只删一个，"注册 3 次后注销 1 次"仍残留，语义与调用方期望相反。
- **建议修复**：`if not FWatchTargets.LockList.Contains(...) then Add`；`Remove` 循环清空，或改用 `TDictionary<string,string>`（key 唯一）同时承载 `ExpectedPath`（顺带修 WM-04）。

#### 🟡 WM-08 `AllocateHWnd(nil)` + `CheckHookHealth` 死代码 → 钩子健康检查未实现

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.WindowMonitor.pas:141`、`:309-313`
- **问题说明**：`AllocateHWnd(nil)` 传入无窗口过程，句柄只被 `PostMessage` 到（无人处理）；`CheckHookHealth` 全文件无调用点。注释所暗示的"OUT_OFCONTEXT 钩子失效自检"能力不存在。
- **建议修复**：提供真实 `WndProc`（响应心跳消息回写 `FHookAlive`），在轮询线程定期 `SendMessage(FHealthCheckWnd, WM_NULL)` 检测主线程消息泵是否存活；否则删除该字段与死方法。

#### 🟡 WM-09 `HandleForegroundChange` 防抖字段跨锁读写

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.WindowMonitor.pas:209-216`（`FLastCallbackTime` 无锁读写）、`:222`（`FWatchTargets.LockList`）与 `:234-247`（`FCallbackLock`）；`:243-244` 在 `finally` 前 `Exit`
- **问题说明**：`FLastCallbackTime`/`FLastForegroundProc` 分属两把锁保护域，多线程（WinEvent 回调可能来自不同线程的上下文）下防抖判定与"是否有变化"判定可互相撕裂，产生重复或漏报回调。`:244` 的 `Exit` 位于 `try/finally` 内，`Leave` 会执行（此处**不是** bug，仅提示阅读时易误判）。
- **建议修复**：把"最后状态 + 防抖时间"全部收进 `FCallbackLock` 临界区；`FIsRunning` 声明为 `Boolean` 但跨线程读写，建议 `Volatile`/原子访问。

#### 🔵 WM-10 `IsProcessRunning` 与 `GetProcessID` 各自做一次全量 `CreateToolhelp32Snapshot` 遍历

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.WindowMonitor.pas:333-360` 及 `GetProcessID` 实现
- **问题说明**：轮询循环里对每个 target 都单独快照一次全进程列表（N 个 target = N 次快照）。
- **建议修复**：单次快照构建名字→PID 字典后复用；`GetProcessID` 与 `IsProcessRunning` 合并为 `TryGetProcessID`。

#### 本单元未发现问题之维度

- **异常处理**：`WinEventCallback`/`PollThreadProc`/`NotifyCallbacks` 均有 try/except 且写日志，未发现吞异常导致安全门失效（但功能缺失本身见 WM-03）。
- **内存与生命周期（对象释放）**：`Destroy` 中各容器 `Free` 顺序正确，未见 double-free；`TWindowChangeCallback` 为 managed record，`FWindowCallbacks.Values.ToArray` 快照后在锁外调用是正确做法。

### 3.11 DeepBase.HttpServer.pas（1394 行）

> 基于 Indy `TIdHTTPServer` 的路由式 HTTP 服务（中间件、静态文件、CORS、BasicAuth、JSON 响应）。

#### 🔴 HS-01 `Listen(AHost)` 完全忽略 `AHost`，本地服务绑定 `0.0.0.0` 暴露到局域网

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.HttpServer.pas:1358-1375`

```pascal
procedure TDeepBaseHttpServer.Listen(const APort: Word; const AHost: string);
begin
  FServer.DefaultPort := APort;
  FServer.Active := False;
  FServer.Bindings.Clear;
  FServer.Bindings.Add.Port := APort;   // AHost 从未使用
  FServer.Active := True;
end;
```

- **问题说明**：签名与文档都接受绑定地址（默认值 `'0.0.0.0'`），实现只设端口。Indy 的 `TIdSocketHandle` 在 `Address` 为空时默认监听全部接口。调用方传 `'127.0.0.1'`（意图"仅本机"）时**参数被静默丢弃**，服务仍对所有网卡开放。
- **触发条件**：任何以"回环限定"意图调用 `Listen(port, '127.0.0.1')` 的场景（桌面内嵌 API、调试面板、Localhost Token 服务）。
- **后果**：未鉴权/弱鉴权（见 HS-06）的管理面端口暴露到 LAN，属安全漏洞。
- **建议修复**：`Bindings.Add.Address := AHost`；对 `'0.0.0.0'`/`'::'` 显式记一条启动警告日志；新增"仅回环"断言型便捷方法 `ListenLocalhost`。

#### 🔴 HS-02 运行期热注册路由/中间件与 worker 线程并发读写，无锁保护

- 位置：`...DeepBase.HttpServer.pas:1143-1152`（`Use`）、`:1163-1203`（`Get/Post/Route/Put/Delete`）、消费侧 `:1106`（`FRouter.Match`）、`:1348-1355`（`for I := High(FMiddlewares) downto 0`）

```pascal
procedure TDeepBaseHttpServer.Use(AMiddleware: IHttpRequestMiddleware);
begin
  FMiddlewares.Add(AMiddleware);   // 与 worker 线程的枚举并发
end;
```

- **问题说明**：`FMiddlewares`（`TInterfaceList` 或动态数组）与 `FRouter` 内部路由表在服务 `Active=True`、worker 线程正在 `CommandGet` 分派时被修改。Indy 每个请求在独立线程执行，读侧无任何锁/快照；动态数组 `Add` 触发重分配会让正在枚举的线程读到已释放的旧缓冲区。
- **触发条件**：动态挂载模块（插件式路由注册）、延迟注册、或在请求处理回调里再注册路由。
- **后果**：间歇性访问违例/野指针，崩溃点远离成因。
- **建议修复**：路由与中间件表加 `TCriticalSection`，或采用"写时复制 + 读侧取不可变快照"（注册后整体替换 `FSharedRoutes: TBytes/不可变数组`，worker 只读字段引用）；文档明确"注册必须在 `Active := True` 之前完成"并在 `Use/Route` 中 `if FServer.Active then raise`。

#### 🟡 HS-03 中间件仅在路由命中时执行，全局头/CORS 预检/404 响应全部绕过

- 位置：`...DeepBase.HttpServer.pas:1300-1320`（`RunMiddlewareChain` 只在 `LRoute <> nil` 分支内调用）、`:880-884`（OPTIONS 预检直接返回）
- **问题说明**：链式中间件（CORS、安全头、鉴权、日志）被实现为"路由处理器的包装器"而非"请求管线"。未命中路由的请求（404）、静态文件分支、OPTIONS 预检都不经过链 → `Access-Control-Allow-*`、`X-Content-Type-Options` 等永不下发；BasicAuth 中间件对未注册路径不生效（等于免鉴权）。
- **触发条件**：浏览器跨域预检；访问不存在的路径；依赖中间件做统一鉴权。
- **建议修复**：把链改为在 `OnCommandGet` 入口无条件执行（终端为路由器/静态文件/404 生成器）。

#### 🟡 HS-04 请求体大小限制基于客户端自报的 `ContentLength`，可被分块编码绕过

- 位置：`...DeepBase.HttpServer.pas:1275`（`if Request.ContentLength > FMaxBodyBytes then`）、`:1288-1291`（`ReadStream` 全量入内存）
- **问题说明**：`Transfer-Encoding: chunked` 时 `ContentLength = -1`，守卫直接放行，随后把整个请求体读进 `TMemoryStream`/`string`。恶意或异常客户端可用无限量请求体耗尽内存。
- **触发条件**：任何未设 `Content-Length` 的 POST。
- **建议修复**：以 `ReadStream` 的分块读取循环强制累计上限（超限即 413 并断开），不信任 `ContentLength`。

#### 🟡 HS-05 零字节静态文件触发 `BodyBytesContent[0]` 越界

- 位置：`...DeepBase.HttpServer.pas:1331`

```pascal
  Response.ContentText := TEncoding.UTF8.GetString(LBytes) ...
  // 上一行附近存在对 BodyBytesContent[0] 的直接索引
```

- **问题说明**：在 `{$R+}`（范围检查，Debug 配置默认开启）下空文件抛 `ERangeError`；Release（`{$R-}`）下读越界字节，产出一个伪造字符的响应体。两种构建行为不一致。
- **触发条件**：`wwwroot` 下存在 0 字节文件，或上传后被截断的文件。
- **建议修复**：`if Length(LBytes) > 0 then ... else Response.ContentLength := 0`。

#### 🟡 HS-06 BasicAuth 中间件：异常逃逸、无常量时间比较、无限速

- 位置：`...DeepBase.HttpServer.pas:901-933`（`TBasicAuthMiddleware`）、`:1303-1317`（`RunMiddlewareChain` 只包裹 `FinalHandler`）
- **问题说明**：① `DecodeBase64(ACredentials)` 对非法 Base64 抛异常，而该异常发生在链的 `Invoke` 内、`try/except` 之外 → 逃逸为 500 且中断后续中间件；② 口令比较用 `<>`（短路、逐字节），存在时序侧信道；③ 无失败计数/限速 → 在线口令爆破无成本；④ 未校验 `realm`、无 `WWW-Authenticate` 缺失时的降级路径。
- **触发条件**：畸形 `Authorization` 头；对管理端点的持续尝试。
- **建议修复**：`TryStrToInt`/`TryDecodeBase64` 化；改用常量时间比较（或先 SHA-256 再比较）；在中间件内加按 IP 的失败退避；异常在链的每一环单独捕获并记 401。

#### 🟡 HS-07 未知/拼错的方法名映射为 `hmAny`；方法不匹配返回 404 而非 405

- 位置：`...DeepBase.HttpServer.pas:455`（`StringToMethod` 的 `else Result := hmAny`）、`:570`（`Status(405)` 已定义但全仓无产生点）
- **问题说明**：注册 `srv.Route('GETT', ...)`（拼错）时静默变成"匹配所有方法"，一个只应响应 GET 的端点开始接受 POST/DELETE；反之，路径存在但方法不符时返回 404，违反 HTTP 语义（应 405 + `Allow` 头），也让客户端无法区分"路径不存在"与"方法不支持"。
- **建议修复**：`StringToMethod` 无法识别即 `raise EArgument`（或返回 `hmUnknown` 并在注册处拒绝）；路由匹配阶段路径命中而方法不命中时返回 405 并附 `Allow`。

#### 🟡 HS-08 `THttpContext` 在 `ProcessRequest` 结束即释放，异步 handler 捕获即悬垂

- 位置：`...DeepBase.HttpServer.pas:1340-1342`（`finally FreeAndNil(Ctx)`）
- **问题说明**：框架对外暴露的 `THttpContext`（含 `Request/Response/JSON 写出方法`）生命周期与同步处理绑定，但没有任何文档/类型约束阻止 handler 把 `Ctx` 存进队列或 `TTask`。异步路径下写响应 = 写已释放对象，且 Indy 的 `Response` 此刻可能已发送完毕。
- **触发条件**：handler 内启动后台任务并回调 `Ctx.RespondJSON`。
- **建议修复**：把 `THttpContext` 设计为只用于同步（类名/文档明确），或为异步提供独立的"响应发射器"对象并显式移交所有权。

#### 🔵 HS-09 死字段与 CORS 组合违规

- 位置：`...DeepBase.HttpServer.pas:138`、`:167`（`FSent`/`SSent` 声明后从未读写）；`:867-876`（`Access-Control-Allow-Origin: *` 与 `Allow-Credentials: true` 同时下发）
- **问题说明**：`*` + `AllowCredentials=true` 是 CORS 规范明确禁止的组合，浏览器会拒绝该响应（等于功能失效）；同时通配源 + 凭据本身即跨站攻击面。`FSent/SSent` 为遗留死代码。
- **建议修复**：`AllowCredentials=true` 时必须回显具体 `Origin` 并维护白名单；删除死字段。

#### 本单元未发现问题之维度

- **内存与生命周期（对象释放）**：`Json(Data, OwnsData)` 的所有权传递在 `:606-613` 处理正确，未见 double-free 或含 string record 的 `Move` 滥用。

#### 存疑（详见第 6 节）

- 静态文件路径存在"双重 URL 解码"（Indy 已解码一次，`:1003` 再 `TNetEncoding.URL.Decode`），是否能构造出绕过 `:1004-1019`（`GetFullPath` + `StartsWith(Root)`）前缀校验的输入（如 `%252e%252e`、`..%c0%af`），需在真实 Indy 版本上实测，故未直接计入 🔴。

### 3.12 DeepBase.Net.pas（2153 行）

> 自研 HTTP 客户端门面（`THTTPClient` 封装 + SSRF 防护 + DNS/子网工具 + 端口扫描 + WebSocket 占位）。

#### 🔴 NET-01 `THttpResponse` record 携带 `TDictionary` 且提供 `Free` 方法 → 所有权分裂

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Net.pas:33-49`（record 定义）、`:420-424`（`Headers` 懒创建）、`:548`（`Execute` 内创建）、`Free` 方法实现

```pascal
THttpResponse = record
  ...
  Headers: TDictionary<string, string>;
  procedure Free;   // 名字与 System.Free 冲突，语义为"释放 Headers"
end;
```

- **问题说明**：record 按值返回/赋值时 `Headers` 指针被逐位复制，多个 `THttpResponse` 变量共享同一字典；任一调用 `Resp.Free` 后其余副本的 `Headers` 成为悬垂指针（后续 `Headers.Values[...]` = 读已释放内存），而不调 `Free` 则每个副本都无人释放（泄漏）。`Execute` 在 `:581`、`:598-601` 抛异常的路径上，`:548` 已创建的字典**必然泄漏**（无 try/finally）。
- **触发条件**：任何调用 `Http.Get/Post` 后把结果赋给另一变量、或存进容器；以及任何抛异常的请求。
- **后果**：悬垂指针读取（崩溃/数据错乱）+ 系统性内存泄漏。
- **建议修复**：把 `THttpResponse` 改为 `class`（`TInterfacedObject` 更佳），或让 `Headers` 为不可变 `TArray<TPair<string,string>>`/record 内的值语义 map；无论如何必须移除名为 `Free` 的方法（与 RTL `Free` 同名，掩盖 `System.Free` 且易被误读为析构）。

#### 🔴 NET-02 SSRF 防护可被非规范 IP 写法完全绕过

- 位置：`...DeepBase.Net.pas:2103-2143`（`IsSafeUrl`）、`:1978-2014`（`IsUnsafeResolvedAddress`）、`:1673-1690`（`IsValidIPv4`）、`:1692-1701`（IPv6 正则）
- **问题说明**：校验器只识别**点分十进制四段**形式。以下写法都能指向内网/链路本地元数据服务而被放行：
  - `http://127.1/`、`http://127.0.1/`（两段简写，Winsock 解释为 127.0.0.1）
  - `http://0177.0.0.1/`（八进制 → 127.0.0.1）
  - `http://2130706433/`（单段十进制 → 127.0.0.1）
  - `http://0/`、`http://0000000000/`（→ 本机；`Octets[0]=0` 那条规则对应的判定函数**从未被调用**）
  - `http://[::ffff:127.0.0.1]/`（IPv4-mapped IPv6；IPv6 正则不匹配该形式 → `IsUnsafeResolvedAddress` 直接返回"安全"）
  - `http://fd12::1/`（ULA：正则要求完整 8 段，`fd` 前缀检查永不命中 → 形同虚设）
- **触发条件**：任何允许外部影响目标 URL 的入口（配置上传、回调地址、插件源、Webhook）。
- **后果**：SSRF → 云元数据 `169.254.169.254` 凭据窃取、内网管理面打洞。
- **建议修复**：不要用字符串正则判 IP。统一 `TIPv4Address/ TNetEncoding` 风格的**数值解析**：先 `Resolve` 成 `TNetIPAddress`（含 Winsock 对简写/八进制/十进制的规范化），再对**字节值**做网段判定（0.0.0.0/8、10/8、100.64/10、127/8、169.254/16、172.16/12、192.168/16、::1、fc00::/7、::ffff:0:0/96 解封装后再判），并对 `ToHost` 与 `Resolve` 两次解析结果都做校验（防 rebinding，见 NET-05）。

#### 🔴 NET-03 跟随重定向后不复校 SSRF，首 URL 白名单被 `Location` 绕过

- 位置：`...DeepBase.Net.pas:571-572`（`HandleRedirects := FFollowRedirects`）、`:437`（默认 `True`）、`:598-601`（SSRF 校验只在发起前）
- **问题说明**：`THTTPClient` 在句柄层自动跟随 3xx，本地校验只覆盖第一个 URL。攻击者提供一个公网 URL，服务端 302 到 `http://169.254.169.254/latest/meta-data/`，客户端会**自动带上下一个请求的所有自定义头**（含 API key，若 `Authorization` 在重定向时被复用）。
- **触发条件**：目标服务器可控（用户配置的镜像源、上传端点）。
- **建议修复**：改用手动重定向（`AllowRedirects := False`），逐跳解析 `Location` 并重新执行 `IsSafeUrl` + 跨主机时剥离 `Authorization`/`Cookie`；限制最大跳数。

#### 🔴 NET-04 安全门由环境变量全局关闭

- 位置：`...DeepBase.Net.pas:2098-2099`、`:2123-2124`

```pascal
  if GetEnvironmentVariable('DeepBase_ALLOW_PRIVATE_NET_HTTP') = '1' then ...
  if GetEnvironmentVariable('DeepBase_ALLOW_LOCALHOST_HTTP') = '1' then ...
```

- **问题说明**：SSRF 防护的总开关放在**进程级环境变量**里：① 一旦在开发机/CI 镜像/部署模板中被 `setx` 设置，会对该机器上所有 DeepBase 进程**永久生效**；② 无作用域（不能只对某个客户端实例放开）；③ 无任何审计日志；④ 每次请求都读环境变量（也属性能问题）。这与本轮 `Updater`/`Licensing` 的 `InsecureDevMode` 属同一类"旁路无门禁"缺陷（横向 X-03）。
- **触发条件**：开发期为图方便设置变量后忘记清除；或攻击者可控环境（CI 配置、.env 泄漏）。
- **建议修复**：改为**实例级显式 API**（`TNetClient.AllowPrivateNetwork := True`），在 Release 构建中用编译期常量使其不可达；每次放行写一条 `ltWarning` 审计日志。

#### 🟡 NET-05 校验用 DNS 与实际连接 DNS 不是同一个解析器，无 rebinding 防护、无 IP pin

- 位置：`...DeepBase.Net.pas:945-946`、`:2016-2087`（`TDnsResolver_` 自建解析器，硬编码 `8.8.8.8:53`）、`:998-1021`（`ResolveIPv6` 只取首条 AAAA）
- **问题说明**：① 安全判定基于向 `8.8.8.8` 的 UDP 查询结果，而真正连接由 WinHTTP 用系统解析器（可能走 hosts 文件、企业 DNS、`NCSI` 缓存）完成 → 两次解析可以给出不同地址（DNS rebinding），校验形同虚设；② 硬编码 8.8.8.8 在受限网络/中国内网环境下直接超时 → 解析失败时的默认返回值决定安全门方向（需为 fail-closed）；③ `ResolveIPv6` 丢弃除第一条外的所有记录 → 多记录域名可被用于绕过；④ 即使校验通过也没有把"已校验的 IP"钉到连接上。
- **建议修复**：解析后把 URL 主机替换为已校验的字面 IP 并显式传 `Host:` 头/SNI（IP pin）；或改用系统解析器做校验并连接同一结果；解析失败必须 fail-closed 并记日志。

#### 🟡 NET-06 异常被吞成 `StatusCode := -1`，与 `Net.Transport` 契约再次分裂

- 位置：`...DeepBase.Net.pas:676-683`

```pascal
except
  on E: Exception do
  begin
    Result.StatusCode := -1;
    Result.StatusText := E.Message;
  end;
end;
```

- **问题说明**：`THTTPClient` 门面把任何异常（含 `EArgumentNil`、证书错误、SSRF 拒绝）压成"状态码 -1 + 消息文本"，调用方无法区分"传输失败""被安全门拒绝""编程错误"；而同一库的 `INetTransport.Send` 是 **raise**、`SendStreaming` 是 **StatusCode=0**——三种失败语义并存（详见 3.13 NT-01）。错误分类缺失会让上层的重试/降级策略失效。
- **建议修复**：定义 `ENetError` 层次（`ENetTransport`/`ENetBlocked`/`ENetTimeout`）并保留 `raise`，或让门面返回带 `Kind` 判别式的结果记录，三处统一。

#### 🟡 NET-07 二进制请求体被 `TStringStream` 的编码转换损坏

- 位置：`...DeepBase.Net.pas:620-627`

```pascal
  LStream := TStringStream.Create(FBodyBytes{ string }, ...);
```

- **问题说明**：把 `TBytes` 经 `string`（再经 `TEncoding`）写入请求体。非 UTF-8 字节序列会被替换为 `?`/U+FFFD，长度与内容均改变 → 上传文件/图片/protobuf/签名原文时**签名验证必然失败或对端数据损坏**。与本轮 CloudBackup/CloudSync 的编码问题同族。
- **建议修复**：`TBytesStream.Create(LBytes)` + `Position := Size`，`ContentType` 由调用方指定；`TStringStream` 只用于文本 body。

#### 🟡 NET-08 子网/主机计算的越界与未校验

- 位置：`...DeepBase.Net.pas:1328-1334`（`GetHostCount`：`Cardinal(1) shl (32 - APrefix)`，`APrefix = 0` 时移位量 32 → 未定义行为）、`:1372-1383`（`MaskToPrefix` 不校验掩码连续性）、`:1299`（`TIPv4Subnet.Create(ACIDR)` 内 `StrToInt` 可抛 `EConvertError`）
- **问题说明**：`shl 32` 在 x86/x64 上按 5 位取模 → 实际结果 `1`，与"/0 = 42 亿地址"的正确值差 40 亿倍；非连续掩码（`255.0.255.0` 写成 `255.255.0.0` 顺序错乱等）被静默接受并给出错误前缀；`ParseCIDR` 抛异常类型未封装。
- **建议修复**：`Result := if APrefix >= 32 then 1 else (1 shl (32 - APrefix)) - 2`；`MaskToPrefix` 校验"高位连续 1、低位全 0"否则 raise；`Create(ACIDR)` 内 `TryStrToInt` + 显式 `ENetArgument`。

#### 🟡 NET-09 WebSocket 与网络信息接口为占位实现，且 `Destroy` 内可抛

- 位置：`...DeepBase.Net.pas:889-925`（WS 全占位、`Destroy` 无 try 包裹）、`:1583-1593`（`GetMacAddress`/`GetDefaultGateway` 直接 `Result := ''`）、`:1557-1581`（`GetNetworkInterfaces` 字段不全且 `IsUp := True` 硬编码）
- **问题说明**：① WS 的连接/发送/接收全是返回默认值的空壳，但类型与枚举已公开导出 → 调用方以为可用；析构路径可能抛（违反"析构不抛"）；② `GetMacAddress`/`GetDefaultGateway` 恒返回空串，任何以"设备指纹/网关校验"为目的的逻辑会得到恒定值（若被用于许可证绑定即成假阳性/假阴性源）；③ `IsUp := True` 使枚举接口的"在线"判定完全失真。
- **建议修复**：未实现的公开 API 应在编译期不可见（移出接口或 `raise ENotImplemented` 明确失败），或从特性矩阵中删除声明；网络信息用 `GetAdaptersInfo/GetAdaptersAddresses` 实装。

#### 🔵 NET-10 其它

- `...DeepBase.Net.pas:670`、`:682`：`Round((Now - LStartTime) * 86400000)` 计算耗时，依赖挂钟且精度损失 → 应改 `TStopwatch`。
- `:1972`：`IsValidHttpHeader` 的 CRLF 检查写成了永假分支（死代码）→ 头注入（Response Splitting / Cache Poisoning）实际未防护，**这条若被上层用于用户可控头应升格 🟡**；建议 `Pos(#13, S) > 0` 显式判定并加测试。
- `:2136`：`Host.Contains('metadata')` 做元数据服务识别 → 误杀正常域名（`api.metadata.example.com`），同时漏掉 AWS `169.254.170.2`、阿里云 `100.100.100.200`、OpenStack `169.254.169.254` 的其它变体。
- `:1404-1407`：`IsInternetAvailable` 用 `8.8.8.8:53` TCP 探测 → 与 NET-05 同源，受限网络下恒 False。
- `:1494-1514`：`ScanPortRange` 无范围/数量校验、串行连接 → 扫 65535 端口即长时间阻塞（且这是"内网扫描"能力，缺乏任何调用方约束）。
- `:378-391`、`:2145-2151`：`Http()` 单例 DCL 无内存屏障，`finalization` 释放与运行期懒创建竞态；`TIdStack.IncUsage/DecUsage` 配对正确 ✓。
- `:1650-1671`：`JoinUrl` 不做斜杠归并、不编码 → 双斜杠/空格/`#` 注入。
- `:748-751`：`SetTimeout` 裸写字段无锁，与并发 `Execute` 竞态。

### 3.13 DeepBase.Net.Transport.pas（440 行）

> 统一传输层抽象（`INetTransport`），WinHTTP 实现 + SSE 流式解析。

#### 🟡 NT-01 同一接口的两个方法错误语义相反

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Net.Transport.pas:185-186`（`Send` 失败 `raise`）、`:351-357`（`SendStreaming` 失败 `StatusCode := 0` + `StatusText := E.Message`）
- **问题说明**：实现同一契约的两个方法一个抛异常一个吞异常并伪造"零状态码"响应。上层按 `Send` 写的 `try/except` 在流式路径下永不触发，只能检查 `StatusCode`；反之按 `SendStreaming` 写的调用方在 `Send` 路径下会遇到未捕获异常。`StatusCode = 0` 还与"合法但未设置"歧义。
- **触发条件**：混合使用普通与流式（LLM 对话 + 图片下载）的调用者；任何网络故障。
- **建议修复**：统一为"返回结果对象 + `Error` 判别式字段，不抛"（推荐，与库内 `TChatResult` 风格一致），并在接口注释与契约测试中固化。

#### 🟡 NT-02 HEAD/OPTIONS 丢弃请求头

- 位置：`...DeepBase.Net.Transport.pas:233`、`:235`
- **问题说明**：这两条分支绕过了统一施加 `ARequest.Headers` 的代码路径 → 鉴权头/`Accept`/`User-Agent` 丢失。HEAD 常用于"是否存在/大小"探测，缺 `Authorization` 会得到 401/403 而被误判为"资源不存在"。
- **建议修复**：所有方法共用同一段头施加逻辑，仅在"是否读响应体"上分叉。

#### 🟡 NT-03 流式请求复用非流式 30 秒超时，长回答被截断

- 位置：`...DeepBase.Net.Transport.pas:336-337`（复用默认超时常量）
- **问题说明**：SSE/LLM 流式响应整体可达数十分钟，30s 硬超时会在模型"思考"或长输出时切断连接，表现为随机的"回答到一半没了"。流式路径的正确超时模型是**首字节超时 + 块间空闲超时**，而非总时长超时。
- **建议修复**：`SendStreaming` 使用独立的 `ReadTimeoutMs`（块间空闲），总时长不设限或按配置；把超时值暴露为可注入配置（与 `TLLMResilienceConfig.TimeoutMs` 对齐，避免两套超时）。

#### 🟡 NT-04 SSE 解析不符合规范

- 位置：`...DeepBase.Net.Transport.pas:405-408`
- **问题说明**：只识别字面 `'data: '`（强制要求空格）→ 规范的 `data:xxx`（无空格）被整行丢弃；按"行"而非"事件帧"解析 → 一个事件多行 `data:` 不会以 `\n` 拼接、空行分帧语义丢失；`event:`/`id:`/`retry:`/注释行 `:hb` 全被忽略（心跳行被忽略是好事，但 `id:` 丢失导致无法断线续传）。
- **触发条件**：任何非 "data: 单行" 风格的 SSE 服务端（OpenAI 风格部分事件即无空格；`retry:` 是标准字段）。
- **建议修复**：实现 WHATWG SSE 状态机（累积 `data:` 直到空行才 dispatch，容忍可选空格，保留 `event`/`id`）。

#### 🟡 NT-05 取消检查粒度与注释矛盾；响应体无上限

- 位置：`...DeepBase.Net.Transport.pas:399-400`（仅在行边界检查 `IsCancelled`）、`:53-55`（注释宣称"及时取消"）、`:251`、`:377`（读取无累计上限）
- **问题说明**：若服务端持续发送一个不含换行的巨块，取消与超时都无法中断；两条路径都没有"最大字节数"守卫 → 恶意/异常上游可耗尽内存（与 HS-04 同族）。
- **建议修复**：按块读取循环内同时检查取消与累计字节上限（超限即抛/返回错误状态）。

#### 🔵 NT-06 正面与提示

- 正面：`TCancellationToken` 用 `TInterlocked.*` 读写（`:290-298`）✓；二进制响应不做 UTF-8 解码的容错路径（`:258-266`，P4.5-T3）✓；`BodyStream.Free` 置于 `finally`（`:283`、`:434`）✓；未发现 `Move` 滥用与 double-free。
- 提示：SSE 逐行 `Result := Result + Line` 风格累加为 O(n²)（如存在）→ 建议 `TStringBuilder`。

#### 存疑（详见第 6 节）

- `...DeepBase.Net.Transport.pas:395`：`TStreamReader.Create(Resp.ContentStream, TEncoding.UTF8, True)` 的第三参若为 `AFreeEncoding`，则流阅读器析构时会对**全局共享的 `TEncoding.UTF8` 实例**调用 `Free`，后续任何 UTF-8 使用即踩已释放对象。需按本工程所用 RTL 版本确认参数名后定级（若确认则为 🔴）。

### 3.14 DeepBase.Net.Transport.ICS.pas（145 行）

> `INetTransport` 的 ICS/OverMI 可选实现。

#### 🟡 ICS-01 实际为不可用实现，但 IoC 可注册 → 一旦选用即全部网络调用运行期异常

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Net.Transport.ICS.pas:125-142`（`Send` 无条件 `raise`）、`:91-94`（`Create` 在组件不可用时已抛）
- **问题说明**：`Send` 抛异常使得方法体内后续逻辑成为死代码；类本身在 ICS 未安装时构造即失败，但"构造成功 ≠ 能发送"。该实现被公开导出并可被容器注册，任何按"多传输后端可切换"文档配置的用户会在**运行期第一个请求**收到异常，且异常消息指向"未实现"而非可操作原因。
- **建议修复**：若为占位，就不要在 IoC 中暴露该实现名；在单元头与特性矩阵标注 `NOT_IMPLEMENTED`；或返回明确的 `ENetTransportNotSupported`（含"请改用 WinHTTP"提示）。

#### 🟡 ICS-02 `EffectiveRequest` 的默认值合并语义自相矛盾

- 位置：`...DeepBase.Net.Transport.ICS.pas:117-122`
- **问题说明**：`Proxy`/`Timeout` 走"请求未设则用默认"，而 `FollowRedirects`/`MaxRedirects` 是**无条件覆盖**请求值 → 同一函数内两种合并规则；且 `MaxRedirects < 0` 的合法性校验发生在覆盖**之后**，用户设的合法值可能被默认的非法值覆盖后抛错（错误归因困难）。
- **建议修复**：统一"请求值优先、默认值仅填空缺"；校验放在合并之前并在异常消息中指明字段名。

#### 🟡 ICS-03 安全相关字段全是空声明

- 位置：`...DeepBase.Net.Transport.ICS.pas:23-27`（`VerifyPeer`、`TlsMinVersion`、`CertificateErrorPolicy`、`OnCertificateError`、`OnCancel`）、`:74-82`（`CreateSecure`）
- **问题说明**：契约要求"可强制 TLS 校验/最小版本/证书错误策略"，本实现接受这些参数但从不传递给底层；公开枚举含 `icepAllow`（忽略证书错误）→ 调用方以为设置了校验，实际毫无作用（与 NET-04 同属"假安全旋钮"）。
- **建议修复**：在真正实现之前，任何非默认安全参数（如 `VerifyPeer=False` 或 `icepAllow`）必须 `raise`；或让 `CreateSecure` 直接返回未支持异常。

#### 本单元未发现问题的维度

- 线程安全 / 内存与生命周期 / 性能：单元内无可执行逻辑，未发现问题。

### 3.15 DeepBase.Config.Upload.pas（611 行）

> 配置变更上传客户端（JCS 规范化 + SHA-256 幂等键 + 重试退避）。

#### 🔴 CU-01 JCS 数字规范化使用未初始化的 `TFormatSettings` 且存在悬空表达式

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Config.Upload.pas:156-163`

```pascal
function SameDoubleBits(A, B: Double): Boolean;
var
  Fmt: TFormatSettings;
begin
  Result := FloatToStrF(A, ffGeneral, 17, 0, Fmt) =
    FloatToStrF(B, ffGeneral, 17, 0, Fmt);
    FloatToStrF(B, ffGeneral, 16, 0, Fmt);   // 孤立表达式，返回值被丢弃
end;
```

- **问题说明**：`Fmt` 从未赋值（同文件 `CanonicalNumber` 在 `:254` 有 `Fmt := TFormatSettings.Invariant`，那是**另一个局部变量**）→ 使用未初始化记录做小数点/千分符格式化，输出随进程 locale 甚至栈残留而变化；结尾那行孤立表达式说明本意是 16 位精度比较，实际写成 17 位，精度与注释意图相反。这两个函数直接服务于"同一份配置在两台机器上是否等价"（`ConfigSha256`、幂等键、409 冲突判定）。
- **触发条件**：配置中含浮点值；上传端与生成端的 locale/RTL 构建选项不同（正常跨机器场景）。
- **后果**：幂等判定与去重基础失效 → 重复发布、错误 409、审计链断裂；未初始化变量属未定义行为。
- **建议修复**：`Fmt := TFormatSettings.Invariant` 必须在每个使用点显式赋值；统一走 `CanonicalNumber`（RFC 8785 最短往返表示）后再比较字符串；删除悬空表达式；加"1e-300/1e300/0.1/-0.0/NaN/Infinity"往返单测。

#### 🟡 CU-02 成员存在性与取值用两套查找，重复键只按大小写敏感判重

- 位置：`...DeepBase.Config.Upload.pas:347`（重复键检测，`string` 区分大小写默认比较器）、`:354-359`（用 `Obj.Values[Name]` 按名字反查，而非按 `TJSONPair` 索引遍历）
- **问题说明**：排序/规范化阶段用 `Names` 数组按索引配对，取值阶段又按名字查 —— JSON 对象里存在 `"A"` 与 `"a"` 两个键时（本文件判重用的是序数比较，认为它们不重复），`Values['a']` 可能取到 `"A"` 的值（`TJSONObject.GetValue` 的大小写策略与判重逻辑不同源）→ **排序结果与序列化取值错位**，规范化输出与输入语义不同（数据损坏方向）。
- **触发条件**：配置键名仅大小写不同的两个条目；或键在同层重复出现。
- **建议修复**：全程按 `Object[Pairs[I]]` 索引访问，禁止名字二次查找；判重使用与取值一致的比较器；对"重复键"直接判为不可上传（fail-closed）。

#### 🟡 CU-03 严格类型判定导致字段被静默丢弃

- 位置：`...DeepBase.Config.Upload.pas:485-488`
- **问题说明**：只有 `TJSONBool` 才解析 `WasPublished`/`Idempotent`。服务端若返回 `"wasPublished": true`（正确）之外的形式（`1`、`"true"`，不同网关/序列化库常见），字段被跳过 → 结果恒为 `False` → **上传实际成功却被上层记录为失败**（与 CS-02"上传失败却报成功"是同族的双向错误报告）。
- **建议修复**：加宽容错（`TJSONNumber<>0`、`'true'/'1'`），并在缺字段时置 `Unknown` 三态而非默认 False。

#### 🟡 CU-04 退避计算移位溢出与配置未校验

- 位置：`...DeepBase.Config.Upload.pas:496-506`（`Cardinal(1 shl AAttempt) * 2000`）、`:71`（`MaxRetries` public `write`，无范围校验）、`RetryDelayMs` 解析只用 `TryStrToInt`
- **问题说明**：`MaxRetries` 可被配为 ≥31 → `1 shl 31` 起未定义/回绕 → 退避时长可能变成极小值（重试风暴）；`Retry-After` 的 HTTP-date 形式（RFC 7231 合法）不被解析 → 违反服务端限速指示，立即重试。
- **建议修复**：`MaxRetries` 在 setter 中 `EnsureRange(0..10)`；退避用 `Int64` 且 `Min(cap, ...)`；解析 `Retry-After` 支持 delta-seconds 与 IMF-fixdate 两种形式。

#### 🟡 CU-05 `MaxRetries < 0` 时整个上传被跳过却只报"失败"

- 位置：`...DeepBase.Config.Upload.pas:546`（`for A := 0 to FMaxRetries - 1`）、`:591`（`Result := False`）
- **问题说明**：`MaxRetries := 0`（或负值）时循环体一次都不执行，代码直接落到"返回 False"，`AResult` 保持全零 —— 调用方看不到"根本没发过请求"与"服务端拒绝"的区别，日志中也不存在任何请求记录。
- **建议修复**：入口处校验 `MaxRetries >= 1`，或至少设置 `ErrorCode := 'NOT_ATTEMPTED'` 并写日志。

#### 🔵 CU-06 正面与小项

- 正面：`:410-417` 强制 HTTPS（仅 localhost 例外）+ API key 必填 ✓；`:118-154` 手写 JSON 字符串转义含**代理对配对校验**（比 `TJSONObject` 默认行为更严）✓；`:537` 512KB 体积上限 ✓；`:540-542` 幂等键在重试循环外生成并复用 ✓（正确的幂等实现）。
- 小项：`:595-611` 文件尾部 17 行空行；`1..17` 精度试探循环做数字规范化属高成本实现（每个数字最多 17 次格式化），配置项多时明显拖慢上传前置计算 → 建议直接实现 RFC 8785 最短往返（`FloatToStr` 的 `ffCurrency`-free 变体或 `Double` 的 round-trip 最短算法）。
- 架构：本单元与 `CloudBackup`/`CloudSync` 各自实现了"JSON 规范化 + SHA256 + 重试 + 退避"（三套，无共同内核）→ 应下沉为 Core 的 `DeepBase.CanonicalJson`/`DeepBase.RetryPolicy`（横向 X-04，见 3.21）。

### 3.16 DeepBase.Graph.pas（2307 行）

> 泛型图（有/无向、带权）+ 最短路/拓扑/SCC/MST/环检测 + `TTree<T>` + `TGraphBuilder`。

#### 🔴 GRAPH-01 `RemoveNode` 不清理权重表 → 图被永久"毒化" + 泄露 + SSOT 分裂

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Graph.pas:388-424`（`RemoveNode`）、`:900-909`（`ShortestPath` 的负权守卫）
- **问题说明**：`RemoveNode` 从 `FAdjacency` 移除了节点及其入边，但 `FWeights` 字典**完全未动**：既不删除 `FWeights[ANode]` 这一整层（稳定泄露），也不从其他节点的权重子字典中剔除指向它的条目。后果之一是功能性错误：`ShortestPath` 的负权检测是遍历 **`FWeights`** 而非 `FAdjacency` → 用户曾加过一条负权边、后来把那条边/节点删干净（`HasEdge = False`）之后，该图仍会永久抛 `EGraphNegativeWeight`，Dijkstra 再也不可用。
- **触发条件**：任何"加负权边试探→删除→跑最短路"序列；或长期使用同一图实例。
- **后果**：算法永久不可用（需重建整图）；内存泄露；`HasEdge` 与 `Weight[A,B]`（`:349-360`）对已删边仍返回旧值。
- **建议修复**：`RemoveNode` 中 `FWeights.Remove(ANode)` + 遍历所有 `FWeights[K].Remove(ANode)`；把"边存在性"收敛为单一真相源（建议 `FWeights` 为唯一边集，`FAdjacency` 仅存邻接表并在每次变更后校验一致）；负权检测改为看**当前存在的边**。

#### 🔴 GRAPH-02 所有遍历/读算法不持锁，且 `GetNeighbors` 外泄内部列表

- 位置：`...DeepBase.Graph.pas:343-347`（`GetNeighbors` 直接返回活的 `TNodeList` 元素）、写侧 `:388-424`（`RemoveNode` 内 `LNeighbors.Free`，`:398`）；读侧 `BFS/DFS/ShortestPath/TopologicalSort/FindCycle/SCC/MST/IsConnected/Transpose/Subgraph` 均无 `FLock.Enter`
- **问题说明**：写方法（`AddNode/AddEdge/RemoveNode/RemoveEdge`）加锁，读方法一个也没加；更严重的是 `GetNeighbors` 把内部拥有的列表交给调用方，而 `RemoveNode` 会 `Free` 这个列表 → 外部正在枚举的邻居列表被释放（UAF）；`Neighbors()`（`:546-559`）做了 `ToArray` 拷贝，证明作者知道正确做法但**内部路径（BFS/DFS/SCC 等）未拷贝**。
- **触发条件**：后台线程做拓扑排序/最短路，主线程修改图（UI 实时编辑依赖图的典型场景）。
- **建议修复**：读方法全部加 `FLock`（`TReaderWriterLock` 更好）；`GetNeighbors` 改为私有，公开面只给快照；或文档限定单线程使用并删除 `FLock` 造成的"线程安全"假象。

#### 🔴 GRAPH-10 `TTreeNode.ReDeepMoveChild` 名不符实，释放整棵子树 → 悬垂

- 位置：`...DeepBase.Graph.pas:1848-1855`
- **问题说明**：方法名与注释声称"重新深度移动子节点"，实现却对 owning 容器（`TObjectList`，`OwnsObjects=True`）调 `FChildren.Remove(...)` —— `Remove` 会 **Free** 被移除对象。调用方手中先前拿到的子节点引用当场失效；"移动"语义应为 `Extract`（不释放）或 `List.MoveTo`。与 CloudSync CS-03 属同一模式（容器 owns + `Remove` 外泄引用）。
- **触发条件**：任何重组树结构的调用（拖拽重父、导入合并）。
- **建议修复**：改用 `FChildren.Extract(child)` 后 `Add` 到新父；补一条单测：提取后原对象仍可用且只有一个所有者。

#### 🟡 GRAPH-03 无向图的 `HasCycle` 恒为 True

- 位置：`...DeepBase.Graph.pas:1125-1136`、`:1183-1190`
- **问题说明**：环检测未排除"回父边"。无向图中任意一条边 `A-B` 都会被 DFS 看成"B 的后继 A 已在访问集" → 只要有至少一条边就报环。正确做法是跳过 `parent`（或按边 id 去重）。
- **后果**：任何基于"是否成环"的业务判定（依赖冲突提示、循环引用拦截）在拓扑树上恒报警。
- **建议修复**：无向图分支传递 `parent` 并跳过；或统一转成有向双向表示后按边 id 判重。

#### 🟡 GRAPH-04 `FindCycle` 返回的不是环

- 位置：`...DeepBase.Graph.pas:1187`（`LParent.AddOrSetValue`）、`:1194-1204`（回溯拼接）
- **问题说明**：`AddOrSetValue` 会在同一节点被多条边重复访问时**覆盖**其父指针，导致回溯出的路径不是 DFS 树上的真实祖先链；拼出的数组首尾可能不相等、中间可含重复节点 → 调用方拿到的"环"不闭合。另外每个 visited 节点都重复入栈 → 栈大小 O(E)（性能），且提前清理 `LRecStack` 与入栈顺序交互可能漏报。
- **建议修复**：环检测使用显式递归栈与"只在首次发现时写父指针"（`TryAdd`），命中回边时从 `LRecStack` 尾部截取到该节点（天然就是环）。

#### 🟡 GRAPH-05 多个图算法的语义错误集中区

- `MinimumSpanningTree`（`:1594`）：非连通图静默返回不完整树（无森林标记/无异常）→ 调用方无法区分"图就是这些边"与"图不连通"。
- `IsConnected`/`ConnectedComponents`（`:1234-1330`）：在有向图上仍只用后继遍历 → 把"弱连通"当"强连通"，也不校验 `FDirected`。
- `BFSPath`/`DFSPath`（`:733`、`:851`）：把**跳数**写入 `TPath.TotalWeight` → 带权图字段谎报路径代价（与 HS-07/ICT-03 同族"默认值伪装合法"）。
- `Subgraph`（`:1648-1649`）：输入节点集含重复项时 `TDictionary.Add` 抛 `EDuplicateKey`（文档未声明，调用方无从预期）。
- `TryTopologicalSort`（`:1070-1071`）：在无向图上直接 `raise` —— 违反 `Try*` 命名契约（应返回 False）。
- **建议修复**：逐项按上述契约修正；为 `TPath` 区分 `HopCount` 与 `TotalWeight`。

#### 🟡 GRAPH-14 架构：一个单元 2307 行、六个不相关类同文件

- 位置：`...DeepBase.Graph.pas`（全文件）；`TTree<T>` 从 `:1800+` 起与图本体无关系；`TGraphBuilder`（`:2285-2286`）在 `Build` 后置 `FGraph := nil`，若调用方继续用同一 builder `AddNode/AddEdge` 则对 nil Self 赋值/调用 → AV；`TTree<T>.Find`（`:1990`）写死 `TEqualityComparer<T>.Default`（record 键为二进制比较，含 `Double` 时极脆弱）不可注入。
- **建议修复**：拆为 `DeepBase.Graph.pas` / `DeepBase.Graph.Algorithms.pas` / `DeepBase.Tree.pas`；`Build` 后禁用 builder（显式 raise）；Comparer 可注入。

#### 🔵 GRAPH-11~13

- `TPriorityQueue.UpdatePriority/Contains`（`:1772-1798`）为线性扫描 → Dijkstra 松弛退化 O(V·E)（`:958-959`）；建议维护"节点→堆索引"字典做 O(log n) decrease-key。
- `TPath.ToString`（`:301`）`Format('%.2f')` 无 `TFormatSettings`（纳入浮点横向发现 X-05）。
- `GetWeight`（`:349-360`）对不存在的边返回 `1.0` 而非 raise → 默认权重掩盖调用错误（与 NET-06 同族"默认值吞错误"）。
- `SCC` 内部 `LStack`（`:1348` 创建、`:1461` 释放）**从未使用**（死变量）；`Destroy`（`:329`）先 `FreeAndNil(FLock)` 再遍历释放容器 → 字段终局化顺序风险。

#### 本单元未发现问题的维度

- **异常处理（吞异常）**：未发现 `except` 静默吞异常；失败均为 raise（部分 raise 不当见 GRAPH-05）。

### 3.17 DeepBase.CloudBackup.pas（2521 行）

> 本地备份 + 云端上传下载 + 清单（manifest）+ 增量/差量链 + 定时调度 + 加密。

#### 🔴 CB-01 托管记录 `Move` 滥用（任务书点名模式，已坐实）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.CloudBackup.pas:1362-1393`（`DoRequest`）

```pascal
  LDefaultHeaders := ...;  // array of TNameValuePair（两个 string 字段的 record）
  if Length(AHeaders) > 0 then
    Move(AHeaders[0], LDefaultHeaders[2], Length(AHeaders) * SizeOf(TNameValuePair));
```

- **问题说明**：`TNameValuePair` 含 `string` 字段（`UnicodeString`，带引用计数）。`Move` 按位拷贝**绕过引用计数**：源端字符串对象计数不增。任一相关变量被终局化/赋值/异常展开时，引用计数提前归零→ 字符串被释放，而 `LDefaultHeaders` 仍持有指针；后续把它交给 `THTTPClient.CustomHeaders` 即读已释放内存（典型 double-free / 悬垂读）。这是本轮最典型的一类错。
- **触发条件**：任何带自定义头（API key、Idempotency-Key）的云请求——即上传/下载/删除的主路径。
- **后果**：间歇性崩溃/头内容损坏（假 API key → 401）；在堆已复用时可能把乱码当 Authorization 发出（凭据错发）。
- **建议修复**：逐个 `for i := 0 to High(AHeaders) do LDefaultHeaders[2 + i] := AHeaders[i];`（赋值运算符会正确处理引用计数），或直接用 `TNetHTTPClient` 的 `HeaderSupport`/逐项 `SetHeader`。

#### 🔴 CB-02 `ABackupId` 未做路径规范校验 → 任意路径读/写/删

- 位置：`...DeepBase.CloudBackup.pas:1728-1733`（`GetBackupArchivePath`）、`:1735-1738`（`GetManifestPath`）、消费侧 `:2281`（`DeleteVersion`）、`:2356`→`:1437`（`SyncFromCloud`，`fmCreate`）
- **问题说明**：备份 id 直接 `TPath.Combine` 拼入文件路径，无 `../`/绝对路径/驱动器号/空字节校验。`DeleteVersion('../../..')` 可删任意文件；同步流程的 id 可来自**云端清单/列表响应**（服务器被入侵或中间人即可投毒），本地写文件同理 → 任意路径写入。
- **触发条件**：恶意/被攻陷的云端；或本地配置被篡改。
- **建议修复**：id 白名单正则（`^[0-9A-Za-z_-]{1,64}$`）；拼接后 `GetFullPath` + `StartsWith(BackupRoot, OrdinalIgnoreCase)` 双校验（参照本仓 `BuildSafeDestination` 已做对的部分，见 🔵）。

#### 🔴 CB-03 损坏的清单文件被当作"空面合法清单"

- 位置：`...DeepBase.CloudBackup.pas:705-717`（`TBackupManifest.LoadFromFile`）
- **问题说明**：`TJSONObject.ParseJSONValue(...) as TJSONObject` 在返回 `null`/非对象时得到 nil 而**不抛**（`as` 对 nil 返回 nil），随后 `FromJSON` 的各 helper 均为 `if not Assigned(...) then Exit` → 得到一个字段全空/文件列表为空的"正常"清单。校验门（"两边集合都为空则相等"）与 `Restore` 的 `BasePath = ''` 都会把"文件已损"当成合法状态（与 HS-07/ICT-03/L2-04 同族：默认值伪装成功）。
- **触发条件**：清单半写入（断电）/被截断/版本不兼容。
- **后果**：基于空清单做"增量对比"会误判"无文件需备份"或"全部已删"→ 数据丢失；`Restore` 在空清单上可能删库。
- **建议修复**：`LoadFromFile` 对 nil/类型不符/`version` 缺失/`checksum` 不匹配均 raise；引入 `Error` 出参并强制调用方检查；写入时附尾部 CRC（或 `.bak` 双写）。

#### 🔴 CB-04 `VerifyBackup` 对增量备份恒判失败，且恢复前根本不调用它

- 位置：`...DeepBase.CloudBackup.pas:2412-2498`（`VerifyBackup`）、`:1809`（manifest 包含 `fctDeleted` 项）、`:1143`（`CreateArchive` 跳过这些项）、`:2443`（`FileCount` 比对）、`:2495`（`except Result := False`）、`:1943`/`:1985`（`InternalRestore` 直接进恢复，无校验）
- **问题说明**：① 增量/差量备份的 manifest 记录被删除文件的墓碑项，而 zip 中不会包含它们 → `FileCount` 永远不等 → 验证必假；② 同一文件在 manifest 中出现两次（大小写不同路径，见 CB-12）时 `TDictionary.Add` 抛 `EDuplicateKey`，被 `:2495` 的空 `except` 吞为 `False`；③ 最关键：`InternalRestore` **从不调用 `VerifyBackup`** → 恢复前零完整性校验（安全门形同虚设）。
- **触发条件**：任何一次恢复（最常用路径）。
- **后果**：用护不上的/被截断的备份直接覆盖现网数据 = 不可逆数据丢失。
- **建议修复**：验证失败原因分类（计数/哈希/缺失文件）；`FileCount` 只计"实际写入 zip 的项"；`Restore` 开头强制 `VerifyBackup`，失败则拒绝（除非显式 `force`）并备份当前库。

#### 🔴 CB-05 `CleanupOldVersions` 破坏增量链，且参数无下限

- 位置：`...DeepBase.CloudBackup.pas:2063-2082`、`:416`（`MaxVersionsToKeep` public `write`）
- **问题说明**：回收策略是"按时间从最旧开始删到限制数"，**完全不看 `ParentBackupId`** → 一旦删掉某个增量链的根全量备份，其后所有增量/差量备份永久不可用（但列表仍显示为"可恢复"，直到真正 Restore 时才爆）。`AKeep := FMaxVersionsToKeep` 未限幅：设 0 → 删全部；负数 → 循环条件永真，递减至越界后行为未定义（且**删除已逐项生效，不可回滚**）。
- **触发条件**：运维把保留数设得比链长还小；或误设 0/负值。
- **建议修复**：按链保留（先保证每条链的全量根存在）；`MaxVersionsToKeep` setter 做 `EnsureRange(1..N)`；改为"先生成待删清单并校验链完整，再执行删除"（可逆）。

#### 🔴 CB-06 增量与差量走同一分支，恢复侧无链式回放

- 位置：`...DeepBase.CloudBackup.pas:1788`（`btDifferential` 与 `btIncremental` 落入同一 `case` 分支）、恢复侧无链回放逻辑
- **问题说明**：两种语义不同的备份（差量=相对最近全量；增量=相对上一次任意备份）在代码中完全等价，且 `Restore` 只解一个 zip、不做"全量→逐个回放增量"的链式重建 → **只要不是全量备份，恢复结果就不是当时的数据**（静默错数据）。
- **建议修复**：要么删除 `btDifferential` 枚举（不假装支持），要么实现链式回放（按 `ParentBackupId` 拓扑排序依次应用，并处理 `fctDeleted`）。

#### 🔴 CB-07 `fctDeleted` 墓碑在恢复时被忽略

- 位置：`...DeepBase.CloudBackup.pas:1809`（写入端）、恢复侧无处理
- **问题说明**：恢复时只重建 zip 里存在的文件，从不按墓碑列表**删除**已删文件 → 恢复后"已删掉的文件复活"，与用户预期相反（对用户数据的静默回填，可能包含已主动清理的隐私文件）。
- **建议修复**：恢复流程末尾按 `fctDeleted` 清单逐项删除（先校验路径属于 `BasePath`，复用 CB-02 的路径校验）。

#### 🔴 CB-08 调度器异常静默终止，自动备份永不再触发

- 位置：`...DeepBase.CloudBackup.pas:1558-1573`（`SchedulerLoop` 无 `try/except`）、`:1607-1650`（`GetNextScheduledTime`）
- **问题说明**：`stMonthly` 且 `DayOfMonth = 31` 在小月调 `EncodeDate` 抛 `EConvertError`；`stWeekly` 且 `DayOfWeek ∉ 1..7` 时 `while` 循环永不满足（死循环）。两者都在线程内抛出 → `SchedulerLoop` 无捕获 → 调度线程静默退出，**自动备份从此不再运行**，而 UI/日志无异常提示（用户以为在备份）。属"吞异常/失反馈致安全门失效"的反向形式（异常未被吞但无人观察，效果同样）。
- **触发条件**：选"每月 31 日"（常见设置）或写入非法 `DayOfWeek`。
- **建议修复**：循环体整体 `try/except` + `ltError` 日志 + 保留线程存活；月度调度改为"月末钳位"（`Min(DayOfMonth, DaysInMonth)`）；`DayOfWeek` 入参校验；主线程定期检查心跳。

#### 🟡 CB-09~CB-13 功能正确性集中区

- **CB-09**（`:1619-1620`）：`stHourly` 计算错误（实为约 3 小时一次；跨午夜时变成每天一次）。
- **CB-10**（`:834`、`:1031`、`:1048`、`:1251`、`:1268`、`:1407`）：打开备份源/目标统一用 `fmShareDenyWrite`，对**活动数据库文件**会抛 `EOSError 32`（共享冲突）→ 对运行中的实例备份失败（而"备份活库"正是主用途）。建议用 `TFileShare` 含 `fsRead`/容错重试，或走 SQLite Backup API。
- **CB-11**（`:892`、`:932`；`:848-861`）：增量备份对**每个文件全量 SHA256**（大文件慢）；`ShouldInclude` 只匹配 `ExtractFileName` → 同名不同目录的文件被误匹配/漏匹配；`MaxBackupSizeGB` 声明但无执行点（死配置）。
- **CB-12**（`:819`、`:913`）：用**大小写敏感**字典存 Windows 路径 → `C:\Dir\A.db` 与 `c:\dir\a.db` 计为两个文件 → 增量判定与 `FileCount` 失真（也触发 CB-04 的 `EDuplicateKey`）。
- **CB-13**（`:96`、`:121`、`:604-608` vs `:674`）：`FileCount` 与 `FFiles.Count` 两个真相源（且 `FileCount` public `write`）→ 手写 `FileCount` 与内容不一致时验证门仍过（清单正确性双 SSOT）。

#### 🟡 CB-14~CB-18 协议/线程/压缩/时区

- **CB-14**（`:1417`、`:1456`、`:1513`）：只认状态码 200（2xx 其他值当失败）；`SyncFromCloud` 从不下载 manifest → 本地无法重建链信息（与 CS-02 同族：部分失败被当全部成功）。
- **CB-15**（`:2145-2221`、`:1702`）：线程字段被 `FreeOnTerminate := False` 与覆盖式赋值混用（旧线程可能仍在写 `FStatus`）；`FStatus` 检查在锁外（TOCTOU）；`DoProgress` 在后台线程**直调** `FOnProgress` 无 `TThread.Queue` → VCL 宿主上跨线程操作控件。
- **CB-16**（`:2257`、`:1382-1389`）：`GetVersions` 返回内部 owns=True 列表的引用 → 调用方 `Free` 即 double-free；`AMethod` 未知时 `Result := nil` → 上层解引用 AV。
- **CB-17**（`:1081-1085`、`:1063-1066`）：`DecompressStream` 用 `repeat ... until LBytesRead = 0` 退出（对"临时返回 0 但流未完"敏感）；解压**无输出上限**（解压炸弹 DoS）；`clNone`（不压缩）往返与 `DecompressBytes` 路径不一致。
- **CB-18**（`:571`/`:642` vs `:580`/`:670`；`:500`；`:583`/`:669`）：写入用 `DateToISO8601(x)`（默认 `DateIsUTC=True`）而读出用 `ISO8601ToDate(x)`（默认 `False`）→ **往返时区漂移**（横向 X-06）；`:500` 用 locale 相关 `TryStrToFloat`；枚举从 JSON 还原无范围校验（`TBackupType(99)` 直接合法）。

#### 🔴 CB-19（架构）与 🔵 正面

- **CB-19**：2521 行单文件（超 2000 行阈值），客户端/加密/清单/调度/压缩/备份业务全部同文件 → 建议拆分（manifest/加密/调度各自成单元）。
- 正面（应保住的基线）：`ExtractArchive.BuildSafeDestination`（`:1171-1189`）的解压路径遍历防御做得到位 ✓；`TCloudBackupClient.Create`（`:1338-1344`）强制 HTTPS ✓；`FromJSON` 系列有 `try/except → Free → raise` 不泄对象 ✓；`TBackupEncryptor` 走 `TSimpleCrypto`（AES-256-GCM + PBKDF2 100k + HMAC）且 fail-closed ✓。

### 3.18 DeepBase.CloudSync.pas（2299 行）

> 配置项双向同步（版本/校验和乐观并发 + JCS 合并 + 冲突解决 + 加密 + 自动同步定时器）。

#### 🔴 CS-01 `TCloudServiceConfig.Default` 产生一个永远无法工作的配置

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.CloudSync.pas:840-853`（`Default`：`EnableEncryption := True` 且 `EncryptionKey := ''`）、`:984-1010`（`EncryptData`/`DecryptData` key 为空即 raise）、`:964-979`（`DoRequest`）
- **问题说明**：默认值组合出自带矛盾：开启加密但不提供密钥 → 任何同步在首次加密时抛异常；更糟的是 `DoRequest` 把这类**编程/配置错误当成 5xx 可重试错误**处理，并在 **持有 `FLock` 期间 `Sleep` 重试**（`:968`）→ 配置错误变成整局线程阻塞数秒到数十秒（所有调用方卡在 `IsSyncing`/`Sync`）。
- **触发条件**：使用 `Default` 构造且忘设 `EncryptionKey`（文档推荐路径）；或任何 5xx。
- **建议修复**：`Default` 不开加密（或 raise 强制要求密钥）；区分"不可重试"（配置/参数）与"可重试"（5xx）；重试 `Sleep` 必须移出临界区。

#### 🔴 CS-02 上传失败被上报为同步成功

- 位置：`...DeepBase.CloudSync.pas:964-971`（5xx 耗尽后静默返回 nil，无 raise）、`:1604-1608`（`InternalSync` 仍推进 `CurrentVersion`、计 `SuccessfulSyncs`、`DoComplete(True, '')`）
- **问题说明**：`UploadConfigs` 返回 `False`，但调用链不检查它（或将其归入"无变更"），同步完成后本地版本号已推高 → 下次不再重试这些项（脏标记被清）→ **配置永久丢失在本地**，而用户看到"同步成功"。属任务书点名的"备份/同步清单正确性"最严重一类。
- **触发条件**：任何服务端不可用/限流/证书问题。
- **建议修复**：`InternalSync` 必须根据上传结果决定是否推进版本/清脏标记（失败则保留脏位与版本）；`DoComplete(False, reason)`；加契约测试（模拟 5xx 后断言脏位仍在）。

#### 🔴 CS-03 字典 owns 值与外泄裸引用冲突 → 后台遍历期间 UAF

- 位置：`...DeepBase.CloudSync.pas:1167`（`TObjectDictionary.Create(doOwnsValues)`）、`:1327-1355`（`GetAll`/`GetDirtyItems` 返回 `TList<TItem>.Create(False)`，不持有所有权）、`:1593-1595`（后台遍历 `LDirtyItems`）、`:1731`（主线程 `Delete`/`Clear` 会 Free 值对象）、`:1510`（`ApplyResolution` 把正在遍历的对象放回字典）
- **问题说明**：典型的所有权分裂：容器拥有对象但对外交出裸指针列表；主线程 `Delete` 触发 `doOwnsValues` 释放 → 后台线程正在读的元素变为悬垂；`AddOrSetValue` 替换同 key 时也会释放旧值。`ApplyResolution` 在遍历中回写字典还可能触发容器重发（rehash）。
- **触发条件**：同步进行中用户编辑/删除同一配置项。
- **建议修复**：`GetAll/GetDirtyItems` 返回**值拷贝快照**（record）或引用计数安全的 `TList<TItem>`（`Create(True)`）；遍历期间对字典加"同步进行中禁删"门闩（或 copy-on-iterate）。

#### 🔴 CS-04 删除玻碑不可复活 → 双向静默丢数据

- 位置：`...DeepBase.CloudSync.pas:1271-1285`（`Delete`：只置 `IsDeleted`）、`:1298-1313`、`:1327-1340`（`SetString` 等 setter 命中同一对象时**不重置 `IsDeleted`**）
- **问题说明**：用户删一个配置项后又重新写同名项：本地对象玻碑仍为 `True` → 新值不会被上传（或作为"已删"上传），远端则收到删除 → **本地新值不生效 + 远端被删**（一次操作丢掉两端数据）。`Get` 也不报障，看起来"保存了但下次打开又没了"。
- **触发条件**：删除→重建同名项（极常见）。
- **建议修复**：任一 setter 必须 `IsDeleted := False`；或区分 `Deleted` 与 `Tombstone` 状态并强制复活走显式 `Undelete`。

#### 🔴 CS-05 数组合并按索引替换被实现为"移到末尾" → 结构性损坏

- 位置：`...DeepBase.CloudSync.pas:497-531`（`JSONMergeArrays`，`amsMergeByIndex` 分支）
- **问题说明**：用 `Remove(idx)` + `AddElement` 实现"按索引替换"，而 `AddElement` 把元素追加到末尾 → 合并结果不是"索引 i 被替换"，而是"数组重排"；注释自认"简化实现"。多次同步后数组语义（优先级列表、模型列表、规则顺序）完全破坏，且破坏会被同步到所有设备。
- **建议修复**：`TJSONArray` 无按位替换 API，需重建数组（逐项复制，命中索引时写入新值）或直接 `arr[idx] := v`（新版 RTL 支持 `Put`）；补"按索引替换后长度与顺序不变"的Property 测试。

#### 🟡 CS-06~CS-09 并发判定与类型契约

- **CS-06**（`:1480-1492`）：`DetectConflicts` 跨字段比较（用远端 `RemoteVersion` 与本地 `Version` 比，而远端该值恒为 0）→ 冲突几乎永不触发，后写覆盖前写（静默丢改动）。
- **CS-07**（`:804-807`）：`crNewerWins` 依赖带时区漂移的时间戳（与 CB-18 同源），且 `ISO8601ToDate('')` 会抛 → 缺时间字段时冲突解决器本身失败（无兜底）。
- **CS-08**（`:695`、`:735`、`:1853`；`:760`）：`FloatToStr`/`StrToFloatDef` 无 `TFormatSettings`（locale 依赖）；`ToJSON` 未走 JCS 规范化 → 同一逻辑配置产生不同字节串 → **伪冲突**（checksum 不等）。
- **CS-09**（`:115`）：`Value` 属性 public `write` 绕过脏标记设置路径 → 直写 `Item.Value` 的变更永不同步（与 CB-13 `FileCount` public write 同族）。

#### 🟡 CS-10~CS-12 定时器/事件/全局单例

- **CS-10**（`:1968-1984`、`:1658`、`:1671`）：`StartAutoSyncTimer` 用 `FreeOnTerminate := True` 的匿名线程但 `Stop` 不 `WaitFor`；`Sleep` 循环不可中断（退出时最长等待一个周期）；**闭包捕获 `Self`** → 对象先于线程释放即 UAF（与 WindowMonitor 同族）；`Sync`/`SyncAsync` 的状态检查在锁外（TOCTOU，两个同步可并发进入）。
- **CS-11**（`:1452-1463`、`:1646`）：`DoResolveConflict` 在非主线程时**静默跳过** `FOnConflict`（冲突被默默吞掉并按默认策略处理）；`FConflicts` 只增不清；`HasConflictForKey` 导致一旦某 key 进过冲突列表，其**后续远端更新被永久屏蔽**。
- **CS-12**（`:426-431`、`:2295-2296`、`:2028`/`:2058`/`:2096`）：`MultiTenantSync` 无双检锁的内存屏障（可能返回未完全构造的实例）；`finalization` 不释放 `GCloudSync`（退出时泄漏且回调可能打在已终止的对象上）；变更日志每行开/关文件一次（N 次 IO）；`Cleanup` 对解析失败的行静默丢弃。

#### 本单元未发现问题的维度

- **加密强度**：走 `TSimpleCrypto`，FR-002 fail-closed 有效，未发现自造密码学或"失败即用明文"回退路径。

### 3.19 DeepBase.Inference.*（5 个单元，共约 1231 行）

#### 🔴 INF-01 `HAS_ONNX` 分支不可编译：`ExtractModelInfo`/`AttachProviderDML`/`AttachProviderCUDA` 全仓不存在

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Inference.Session.pas:128` 与 `:178`（`ExtractModelInfo;` 两次调用；类声明 `:29-54` 私有段只有 `FSessionId/FState/FModelInfo/FRuntime/FOrtSession/ReleaseOrtSession`）；`d:\_Progs\02Business\DeepBase\Features\DeepBase.Inference.Runtime.pas:121-122`（`ipDirectML: AttachProviderDML(AConfig.DeviceId); ipCUDA: AttachProviderCUDA;`，类声明 `:24` 只有 `AttachProviderCPU`）
- **取证**：全仓 grep `ExtractModelInfo` 仅命中：Session.pas 两处调用、测试注释（`Test...pasc:419` "Mirror of TInferenceSession.ExtractModelInfo"）与 `docs/evaluation/06-ai-llm-integration.md`；`HAS_ONNX` 未出现在任何 `.dproj`/`.cfg`/`.inc`。
- **问题说明**：所有现存构建都走 `{$ELSE}`（无 ONNX）分支，因此 `Session.pas:128-151`、`:171-196`、`:273-356`、`:383-466` 与 `Runtime.pas:113-140` 内的全部代码**从未被编译器看过一眼**；一旦真启用 ONNX，立即 `E2003 Undeclared identifier`。INFER-001/002/003/006/008 等历史修复全部落在死分支里（无法验证是否真有效）。`docs/80.feature-matrix.md:43` 宣称"DirectML/CUDA 需 HAS_ONNX"属虚假能力声明。
- **触发条件**：任何工程定义 `HAS_ONNX`（即真正想用推理功能时）。
- **建议修复**：补齐三个方法实现（或把 ONNX 分支整段移出到独立可选包单元）；CI 增加一个 `-DHAS_ONNX` 的编译冒烟测试（否则死分支会持续膨胀）；从特性矩阵移除未实现项。

#### 🟡 INF-02 输出张量一律按 `SizeOf(Single)` 计算字节数

- 位置：`...DeepBase.Inference.Session.pas:332-340`（`Run`）与 `:441-449`（`RunTyped`）

```pascal
      LByteCount := 1;
      for j := 0 to High(LOutShape) do
        LByteCount := LByteCount * NativeUInt(LOutShape[j]);
      LByteCount := LByteCount * SizeOf(Single);
      SetLength(LData[i], LByteCount);
      LRawPtr := LOutValue.GetTensorMutableData<Single>;
      if (LByteCount > 0) and (LRawPtr <> nil) then
        Move(LRawPtr^, LData[i][0], LByteCount);
```

- **问题说明**：完全忽略 `LOutValue` 的真实元素类型：int8/uint8/bool 输出会**多读 4 倍字节**（堆越界读）；float64 只读一半（数据损坏）；int32 恰好 4 字节属侥幸正确。`LByteCount` 乘法无溢出检查（`docs/evaluation/06-ai-llm-integration.md:273` 早已记录，至今未修）；`LOutShape` 含 `-1`（未解析的动态维）时 `NativeUInt(-1)` → 天文数字分配。输入侧同样硬编码：`:286` `div SizeOf(Single)`、`:314` `ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT`，`Run` 的三个重载**没有任何元素类型参数**（只能喂 float32）。
- **触发条件**：使用任意非 float32 输出的模型（分类头常为 int64/int32；量化模型为 int8）。
- **建议修复**：读 `GetTensorElementType()` 后按真实元素大小计算；逐维校验 `> 0` 并乘积溢出检测（超阈直报 `EInferenceSessionError`）；`Run` 增加元素类型参数或改用 `RunTyped` 统一入口。

#### 🟡 INF-03 会话无锁：`Dispose` 与 `Run` 竞态 → UAF

- 位置：`...DeepBase.Inference.Session.pas:265`、`:380`（`if FState <> issReady then Exit(...)`）、`:497-506`（`Dispose` 置 `FOrtSession := nil` + `FState := issDisposed`）、`:202-207`（`Destroy` 同源）。`TInferenceSession` **无任何 `TCriticalSection`**（`Runtime` 才有 `FLock`）。
- **问题说明**：一线线程 `Run`（包含秒级 ONNX 推理），另一线程 `Dispose` 或最后一个引用释放触发 `Destroy` → `TORTSessionPtr(FOrtSession)^.Run` 解引用已 `FreeMem` 的指针。
- **触发条件**：超时取消/会话池回收与推理并发。
- **建议修复**：`FOrtSession`/`FState` 全部访问加锁；`Run` 期间用引用计数/"禁止并发 Dispose"门闩保护。

#### 🟡 INF-04 `RunTyped` 不在接口里，Service 用硬 downcast 且无错误通道

- 位置：`Types.pas:119-132`（`IInferenceSession` 只有 `Run/GetCustomMetadata/Dispose`）；`Session.pas:51`（`RunTyped` 仅存在于类）；`Service.pas:179` `Result := (ASession as TInferenceSession).RunTyped(AInputs);`
- **问题说明**：传入任何其它实现/装饰器/mock → `as` 抛 `EInvalidCast`，而 `TInferenceService.RunTyped` **无 try/except**（对比 `:169-170` 对 `Session = nil` 的优雅处理）→ 违反门面"never raises，返回 Failed"契约，也破坏 DI 抽象（接口路径不可用，只能传具体类）。
- **建议修复**：把 `RunTyped` 提升进接口（新 GUID）；或 `if not (ASession is TInferenceSession) then Exit(Failed(...))`。

#### 🟡 INF-05 Provider 字段先写后校验；Shutdown 不解除 EP；配置漂移

- 位置：`Runtime.pas:98`（`FProvider := AConfig.Provider;` 在 `case ... raise EInferenceProviderError`（`:124-126`/`:132-134`）**之前**）、`:158-176`（`ShutdownInternal`）、`:23`/`:138`/`:172`（`FOptionsBuilt`）
- **问题说明**：① `Initialize` 失败后 `GetProvider` 仍报告一个从未生效的 provider（`FInitialized = False` 但字段已脏）；② 注释承认 ONNX 全局 `DefaultSessionOptions` 上的 EP 无法摘除 → `Initialize(DML) → Shutdown → Initialize(CUDA)` 会在同一 options 上同时挂着 DML+CUDA，实际执行者由库顺序决定（静默配置漂移）；③ `FOptionsBuilt` 赋值但从未被读（死字段）。
- **建议修复**：先算局部变量、全部校验通过再提交字段；每次 `Initialize` 重建**新的** `SessionOptions` 而不是复用全局；删除或真正使用 `FOptionsBuilt`。

#### 🟡 INF-06 `GetCustomMetadata` 静默吞异常，释放与编码未验证

- 位置：`...DeepBase.Inference.Session.pas:484-493`

```pascal
  except
    // metadata lookup failure is non-critical
  end;
```

- **问题说明**：① 完全无日志的 `except`（维度④）；② `LAllocd := LMeta.LookupCustomMetadataMapAllocated(...)` 得到的 `AllocatedStringPtr` 未见显式 `OrtFree`，是否依赖自动终局化无法验证（HAS_ONNX 死分支，见 INF-01）；③ `:490` 用 `string(AnsiString(PAnsiChar(LP)))` 而（不存在的）`ExtractModelInfo` 应用 `UTF8ToString` → 中文 metadata 值损坏（`docs/evaluation:274` 已记录，未修）。
- **建议修复**：至少记一条 `ltDebug` 并写明失败类型；按 OrtAllocatedString 释放约定显式 `OrtFree`；统一 UTF-8 解码。

#### 🟡 INF-07 IoC 部分注册不回滚；静态门面与容器共享所有权

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Inference.IoC.pas:56-65`、`:69-72`；`...DeepBase.Inference.Service.pas:21-22`
- **问题说明**：① `RegisterSingleton<IInferenceRuntime>` 成功、后续 `RegisterSingleton<IInferenceSessionFactory>` 或 `SetRuntime/SetSessionFactory` 抛异常时，容器里留下一个已 `Shutdown` 的 runtime 注册，无 unregister/回滚；`:69-72` 的 `except LRuntime.Shutdown; raise;` 也救不回容器状态。② `TInferenceService` 的 `class var FRuntime/FSessionFactory` 强引用与容器注册**升为两个持有者**：第 2 次 `RegisterAll`（新容器）静默覆盖门面，旧 runtime 永不 `Shutdown`（泄露）；容器 Free 后门面仍持可用 runtime（生命周期语义混乱）。
- **建议修复**：注册失败时回滚已注册项；门面只保存容器引用并在调用时 `Resolve`（消除双持有），或明确声明"门面拥有、容器不拥有"并在注释与测试中固定。

#### 🟡 INF-08 创建会话时持全局服务锁加载模型

- 位置：`...DeepBase.Inference.Service.pas:139-147`（`FLock.Enter` 内调用 `FSessionFactory.CreateSession(...)`）
- **问题说明**：创建会话可能加载数百 MB ONNX 文件（秒级），期间进程内所有 `TInferenceService.*`（含 `IsReady`）被串行阻塞；`Shutdown` 走同一把锁 → **模型加载期间无法关闭应用**。
- **建议修复**：锁内只修改注册表/占位，模型 IO 在锁外；用"状态 = Loading"标志代替持锁计算。

#### 🔵 INF-09 正面与小项

- 正面：`Types.pas:181-200` 的 `Move` 用于**纯数值数组**（`TArray<Single>`/`TArray<Integer>`），不涉及托管字段，用法正确 ✓（说明作者知道边界，CB-01 是同仓反例）；`TInferenceOutput` 各构造均显式初始化 nil 数组 ✓；`Service.pas:73-133` 每个访问器都加锁 ✓；`Session.pas:76` 用 `TInterlocked.Increment(GSessionCounter)` ✓。
- 小项：`Types.pas:19` `INFERENCE_API_LEVEL` 常量无消费者（死代码）；`Runtime.pas:123-127` 的 `else raise` 在枚举穷尽时不可达（仅防御，可保留但应标注）。

### 3.20 DeepBase.IntentClarification.*（34 个单元，实测量约 7,900 行）

> 五层 Provider（L0-L4）意图澄清引擎：路由/信号/预算/退出/选项框/会话/检查点/脸融度/预判/度量/韧性包装/IoC 装配。
>
> **先说结论性前提（影响所有条目的爆面）**：全仓 grep 确认，除 `Persistence\DeepBase.IntentClarification.Storage.pas`（实现 `IClarificationStorage`）与 Tests 外，**没有任何 Features/VCL/FMX/Core/Platform/Tools 单元引用本模块**（`DeepBase.Browser.IoC.pas:6` 只在注释里提到 `TICIoCRegistration` 作为设计参考）。即：本模块当前是"已声明、已单测、未接线"的孤岛。因此下文关于"未接线/死单元"的条目定为 🟡（功能宣称与实际不符）而非 🔴；而"一旦按推荐路径接线就必然坏"的条目仍计 🔴。

#### 🔴 ICT-01 `TSessionCheckpoint.ToJson` 丢弃绝大部分会话状态（检查清单正确性）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.IntentClarification.Types.pas:300-329`（`ToJson`）、`:331-415`（`FromJson`）
- **问题说明**：`ToJson` 只序列化 `version`/`resumeHint`/`serializedAt` 与内层 `sessionState` 的 11 个标量字段。`TSessionCheckpoint` 的 **`RapportSnapshot`、`TurnHistory`、`OpenQuestions` 完全不写**；`TSessionState` 的 **`Hypotheses`、`Signals`、`History`、`CheckpointJson` 完全不写**。`FromJson` 也只读回这些标量。Engine 在 4 处（`Engine.pas:513-519`、`:1040-1046`、`:1140-1146`、`:1248-1254`）明明赋值了 `LCheckpoint.TurnHistory := GetSessionHistory(...)` —— **填了但不写，静默蒸发**。
- **触发条件**：挂起→恢复（尤其跨进程/重启后从存储 `LoadCheckpoint`）。
- **后果**：恢复后引擎"失忆"（对话历史/已检信号/假设集全空）→ 重复提问、级别/姿态回退、用户已答问题被再问；属会话数据丢失。
- **建议修复**：补 `turnHistory[]`、`openQuestions[]`、`rapportSnapshot{}`、`hypotheses[]`、`signals[]`；加"序列化→反序列化→字段级相等"往返测试（现有 Property 5 只覆盖标量，必然测不过）。

#### 🔴 ENG-01 会话资源只增不减（四本字典永久泄露）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.IntentClarification.Engine.pas:96-99`（`FSessions`/`FHistory`/`FSessionLocks`）、`:124`（`FTokenUsage`）；写入点 `:782-784`（每会话 `FSessions.Add` + `FSessionLocks.Add(TCriticalSection.Create)`）、`:353-358`（`AddTurnToHistory` 每会话新建 `TList<TTurnRecord>`）
- **问题说明**：全文**没有任何** `FSessions.Remove`/`FHistory.Remove`/`FSessionLocks.Remove`/`FTokenUsage.Remove`。`CancelSession`（`:1232-1234`）只把 `Status := ssCompleted`，条目与锁对象永久保留；`SessionCount`（`:1290`）把已取消/已完成会话一并计入（语义失真）。`RemoveSession`（`Session.pas:388-398`）是全模块唯一的回收入口，但 Engine 从不它。
- **触发条件**：长运行宿主（VCL 常驻/服务）反复 `StartSession`。
- **后果**：无界内存增长（每会话一个 `TCriticalSection` 内核对象 + `TList` + 多个含 string 的 record）。
- **建议修复**：完成/取消后按可配置宽限期回收四本字典（回收需与在途 `SubmitInput` 的 per-session 锁协同，参照 `TSessionManager.RemoveSession`）；`SessionCount` 只计活跃会话。

#### 🔴 ENG-02 "读副本—长临界—写回副本" 造成丢失更新，Cancel/Suspend 可被静默覆盖

- 位置：`...DeepBase.IntentClarification.Engine.pas:844-871`（锁内取 record 副本 `LState`）、`:906`/`:910`/`:940`（锁外跑信号检测/路由/`LProvider.Process`）、`:1029-1034` 与 `:1071-1076`（写回）、`:1110-1131`（`SuspendSession`）、`:1175-1196`（`ResumeSession`）、`:1223-1237`（`CancelSession`）

```pascal
    // Persist updated session state
    FLock.Enter;
    try
      FSessions.AddOrSetValue(AHandle.Id, LState);   // 用回合开始时的副本覆盖
    finally
      FLock.Leave;
    end;
```

- **问题说明**：`TSessionState` 是 record，`TryGetValue` 拿到的是**值副本**；随后释放 `FLock`、持 `LSessionLock` 跑完整个回合（L3/L4 路径含**多个 LLM 调用，可达数十秒**），最后用**回合开始时那份副本**整体覆盖写回。而 `SuspendSession`/`ResumeSession`/`CancelSession` **完全不走 per-session 锁**（只拿 `FGlobalLock` 做读改写）→ 二者无任何互序保障。
- **触发条件**：一轮 `SubmitInput` 进行中（LLM 未返回），用户点"取消"或"挂起"。
- **后果**：取消/挂起被回合末尾的 `AddOrSetValue` 覆盖回 `ssActive`，且 `TurnCount`/`Depth`/`Level` 回滚为回合开始值（状态倒退）；`CancelSession` 还会重复 `SaveCheckpoint` + 重复发布 `SessionCompleted` 事件。
- **建议修复**：把会话状态改为进程内唯一可变对象（或类）+ 读写全收进 per-session 锁；回合结束时对 `Status` 做"仅前进不回退"合并；`Suspend/Resume/Cancel` 必须持对应 session lock。

#### 🔴 SM-01 三套并行的会话/状态机实现，Engine 一套也不用

- 位置：`...IntentClarification.Session.pas:57`（`TSessionManager.FSessions: TDictionary<string, TSessionState>`）与 `Engine.pas:96`（`TClarificationEngine.FSessions` **同名同类型、互不相通**；Engine 的 uses 列表 `:25-43` **不含** Session/SessionFSM）；`SessionFSM.pas` 的 `TSessionFSMFactory` **只被 `Tests\Test.DeepBase.IntentClarification.Integration.pas:153,800-888` 使用**（grep 取证，生产零消费者）
- **问题说明**：触发器枚举也双套：`TSessionTrigger(stSuspend/stResume/stComplete/stArchive)`（`Session.pas:43-48`）与 `TSessionFSMTrigger(sfStart/sfSubmit/sfSuspend/sfResume/sfCancel/sfTimeout/sfComplete)`（`SessionFSM.pas:35-43`）；后者注释自称"Extends the simpler TSessionTrigger"（`:33`），前者单元头又自称"Replaces manual IsValidTransition in Session.pas"（`:13`）→ **文档互相矛盾，实际三套并存**。最关键的后果：Engine 的状态迁移是**裸赋值**（`:458`/`:1027` `:= ssCompleted`、`:1126` `:= ssSuspended`、`:1191` `:= ssActive`、`:1232` `:= ssCompleted`），绕过自己写的 `TransitionTo` 校验 → 非法迁移无统一守卫（`ResumeSession` 只挡 `<> ssSuspended`，`CancelSession` **完全不挡**：对 `ssArchived`/`ssCompleted` 会话仍返回 `Success = True` 并重复存检查点 + 重复发布完成事件）。
- **建议修复**：以 `TSessionFSMFactory` 为唯一迁移裁决点，Engine 的四个生命周期方法改为 `FSM.Fire(trigger)`；删除 `TSessionTrigger` 或让 `Session.pas` 复用 FSM 单元；补"已完成/已归档会话不可取消"的单测。

#### 🔴 IOC-IC-01 推荐初始化路径下 L2/L3/L4 永久失效且完全静默

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.IntentClarification.IoC.pas:102-107`、`:126-157`；`...Engine.pas:924-925`、`:944-948`

```pascal
  LProvider := TL2ProblemProvider.Create(nil);          // IoC.pas:102
  LProvider := TL3ExpertProvider.Create(nil, nil);      // :104
  LProvider := TL4RoundtableProvider.Create(nil, nil);  // :106
  // CreateEngineFromContainer(:126-157) 仅 RegisterProvider，从不 SetLLM/SetPresenter/
  //   SetDomainAdapter/SetPersonaRegistry/SetFeatureConfig/SetStorage
```

- **问题说明**：三个靠 LLM 的 provider 以 `FLLM = nil` 注册（注释 `:94-97` 自认"因 RTTI 参数解析问题只能注册实例"）；`CreateEngineFromContainer` 又从不注入。叠加 Engine `:924-925`（`RequiresLLM and (FLLM = nil)` → `LProvider := nil`），L2/L3/L4 一律退化为兜底文本（`:944-948` `'Please clarify your intent: "%s"'`）。**五层里三层不可用，一次日志/异常都没有**（`:951` 只 Log `'rule'`）。另一条可选路径 `Registration.RegisterLLM`（`Registration.pas:84-86`）确实注入了 LLM，但它**绕开容器**新建三个实例，容器里那三个 nil 实例仍活着（永远不再被用且占据单例位）。
- **建议修复**：`CreateEngineFromContainer` 内解析并注入 `ILLMClient`/`IPresenter`/`IDomainAdapter`/`TICFeatureConfig`/`IClarificationStorage`；provider 的 LLM 依赖改为首次 `Process` 时延迟解析；注册时不再传 nil；无任何可用 provider 时 `raise`（fail-fast）而非静默降级。

#### 🔴 LR-01 超时后把捕获变量置 nil，后台任务解引用 nil → 结果丢失 + 重试风暴

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.IntentClarification.LLMResilience.pas:305-341`（关键 `:328` `LCtx := nil;`）与 `:434-474`（图像版，`:451` 同）

```pascal
      LCtx := TLLMTaskContext.Create;
      LTask := TTask.Run(
        procedure
        begin
          try
            LCtx.Result := ACall();
          ...
      LTimedOut := not LTask.Wait(FConfig.TimeoutMs);
      if LTimedOut then
      begin
        LCtx := nil;  // transfer ownership to the captured anonymous method
```

- **问题说明**：Delphi 闭包对局部变量是**按引用捕获**（存在共享的 display 记录里），不是"捕获当时的值"。所以上行注释假设的"移交所有权"恰好相反：主线程 `LCtx := nil` 写的是**同一个存储位置**，后台任务稍后醒来时读到 nil，`LCtx.Result := ACall()` 变成向 `[nil + offset]` 写字段 → worker 线程抛 AV，被 `TTask` 内部 `except` 抓住存在 task 对象里；因为已经放弃 `Wait`，**该异常永不被观察**（维度④：吞异常），超时那一次的真实回答即使最终返回也丢弃。同时超时后的重试会**再发一个新请求**，而旧请求仍在后台跑 → 一次用户输入最多向 LLM 供应商发出 `MaxRetries+1` 个**并发**请求（成本×N、副作用重复、上游限流反噬）。
- **触发条件**：LLM 响应超过 `TimeoutMs`（默认 10s，极易触发）。
- **建议修复**：把 ctx 存进一个**专门的所有权对象**（`TCtxHolder`）并让闭包捕获 holder 的**副本字段**（而非同一个变量）；或用 `RefCount`/`InterlockedIncrement` 手工引用计数（主线程与 worker 各持一引用）；超时分支必须同时 `Cancel`/中断上游 HTTP（否则重试风暴无法消除），并在日志中记录"放弃的后台任务仍在运行"。

#### 🔴 LR-02 熔断器形同虚设：超时后闭包捕获 `Self` 可悬垂，且生产未接线

- 位置：`...LLMResilience.pas:513-517`（`ACall` 闭包捕获 `Self`/`FInner`）、`:55-62`（熔断参数）、`:561`/`:617`（流式门控）；接线取证：grep `TResilientLLMWrapper|LLMResilience` 仅命中本单元与 `Tests\Test.DeepBase.IntentClarification.Integration.pas:30,135,717`
- **问题说明**：① 包装器是 `TInterfacedObject`，超时后最后一个接口引用可能释放 → `Destroy` 中 `FLock.Free`、`FInner` 字段终局化，而后台任务正在读 `FInner` → UAF；② **整个韧性层零生产消费者** —— `Registration.RegisterLLM`（`Registration.pas:77-87`）与 `IoC.pas` 都是把裸 `ILLMClient` 直传 provider，所声称的"重试/超时/熔断"从未生效；而 Engine 在持 per-session 锁时调 provider（`Engine.pas:940`），一个挂死的 LLM 调用会**无限期持有该会话锁** → 会话永久卡死（`SubmitInput` 自身无任何超时）。这两点合并构成可用性/内存安全 🔴。
- **建议修复**：把 `TResilientLLMWrapper` 接进装配链（`RegisterLLM` 内包一层），或在 IoC 注册 `ILLMClient` 的装饰器；闭包不捕获 `Self`（改为先取局部 `LInner: ILLMClient` 并捕获该局部）；`FConfig` 写入加锁。

#### 🟡 ICI-01 `TProviderResult` 契约不含假设/置信度 → 五层之间无法传递推理状态

- 位置：`...IntentClarification.Interfaces.pas:100-108`（`TProviderResult`：`Success/Question/Options/Scaffolds/RecommendedOption/Source/ErrorMessage`）
- **问题说明**：`TProcessingContext`（`:85-97`）**有** `Hypotheses: TArray<THypothesis>`，`TSessionState`（`Types.pas:156`）也有 `Hypotheses`，但 provider **结果里没有 `Hypotheses`/`Confidence` 字段** → L2 生成的假设无法回传，L3/L4 看不到前一层推论。实证：Engine 只在 `:406` 读出 `AState.Hypotheses`，**全仓无任何写回**（`LState.Hypotheses` 仅 `:763` 初始化为 nil）→ 假设链恒为空，`THypothesis.Denied` 字段无人消费。这是任务书点名的"五层 Provider 契约一致性"核心缺陷。同族：`L2ProblemProvider.DenyHypothesis`（`Provider.L2.pas:314-330`）与 `GetDeniedHypotheses` **只被测试调用**（grep：仅 `Test...Round2.PBT.pas:134`、`Test...PBT.pas:183`），因 `AContext.Hypotheses` 恒空，`:286-309` 的同步分支永不执行 → 否认约束永为空。
- **建议修复**：`TProviderResult` 增加 `Hypotheses: TArray<THypothesis>` 与 `Confidence: Double`；Engine 在每回合末尾合并写回 `LState.Hypotheses`，并将用户"否答"映射为 `DenyHypothesis`。

#### 🟡 ICI-02~ICI-05 契约层其它缺口

- **ICI-02**（`Interfaces.pas:106`、`:69`）：`Source`（`'rule'|'llm'`）、`Reason`（注释列 4 种）、`ErrorCode` 全为裸 string 靠注释约定 → 拼写漂移无编译期保护（实测已漂移，见 EXIT-02）。
- **ICI-03**（`:275-278` `IFeasibilityChecker`、`:284-289` `ILearningAdapter`）：定义在带 GUID 的公共契约里，但 `IClarificationEngine`（`:180-196`）没有任何对应的 `Set...` 方法 → **不可注入**；grep 除定义外无消费者 → 死契约（Requirements 12.8/12.6 未落地）。
- **ICI-04**（`:189-195`）：接口只列 7 个 setter，缺 `SetFeatureConfig`/`SetMetrics`（Engine 类有，`:180-181`）→ 经 IoC 拿到 `IClarificationEngine` 的应用无法注入；grep 确认 `SetFeatureConfig/SetMetrics/SetAnticipationEngine/SetStorage` 在整个 Features 下**除 Engine 自身定义外零调用者** → `GetMaxLevel`（`:286`）退化为 `clL4`（最贵一层默认全开）、预算退化为 `TBudgetConfig.Default`、指标与持久化恒 nil。
- **ICI-05**（`:206` 与 `:211`）：`IClarificationStorage.LoadRapport` 返回 `TRapportProfile`（无 `Error` 通道），而 `LoadCheckpoint` 返回带 `Error` 字段的 `TSessionCheckpoint` → 两种错误语义；"记录不存在"与"记录损坏"不可区分。

#### 🟡 ICT-02~ICT-04 checkpoint 反序列化的"默认值伪装合法"

- **ICT-02**（`Types.pas:316-318`）：`status`/`currentLevel`/`currentPosture` 以 `Ord()` 落库，构成持久化契约；`Result.Version := JsonInt(..., 'version', 1)`（`:331+`）读回但**从不与受支持版本比较**。将来在 `TClarificationLevel` 中间插入新值（如 clL5）会使所有历史 checkpoint 语义漂移（范围校验只挡越界，不挡"合法但含义已变"）。
- **ICT-03**（`:389`、`:373`、`:378`）：`LStatus` 缺省为 `Ord(ssArchived)` → 字段丢失的 checkpoint 被标为"已归档"而非报错；`Error` 仅在根对象/`sessionState` 缺失时设置，**子字段解析失败全静默取默认** → 上层只查 `Error = ''` 会以为完好。
- **ICT-04**（`:239`）：`JsonFloat` 无条件 `StringReplace(LValue.Value, ',', '.', rfReplaceAll)` → `"1,234.5"` 变 `"1.234.5"` 回退默认；对非数值 `TJSONValue`（对象/数组）取 `.Value` 得 JSON 文本再替换逗号 → 静默默认。建议先做 `is TJSONNumber` 类型判定。
- 正面（必须记录）：本单元 `DateToISO8601(x, False)`/`ISO8601ToDate(x, False)` **两侧一致**（`:309`/`:321`/`:322` vs `:366`/`:407`/`:409`），往返无漂移 —— 与 CloudBackup/CloudSync（用 1 参默认、两侧不对称）构成对照，应作为库内统一时区约定的参照实现。

#### 🟡 ENG-03~ENG-07 Engine 功能缺口集中区

- **ENG-03**（`:768-778`、`:754-756`、`:972-975`）：`ARequest.Template` 与 `ARequest.HasBudgetOverride` **只写日志、不应用**（`if ARequest.Template <> '' then Log(...)`）；新会话硬编码 `CurrentPosture := posClarifying; CurrentDepth := 0.3; CurrentLevel := clL1`，无视 `TPresetTemplate.DefaultPosture/MaxLevel/BudgetConfig`；预算只从 `FFeatureConfig` 或 `TBudgetConfig.Default` 取，`BudgetOverride` 无落点。另：`ARequest.Locale` 全模块仅在主单元 `DeepBase.IntentClarification.pas:52`/`:592` 与序列化里出现（默认 `'zh-CN'`），**Provider/Templates/OptionFrame/SignalDetector 一处不用**。后果：成本/深度控制入口失效；非中文用户的信号检测恒为 0（见 SD-01）。
- **ENG-04**（`:954-955` 与 `:988`）：传给 `EnsureValidFrame` 的是 `RecommendedOption - 1`，但 `Result.RecommendedOption := LProviderResult.RecommendedOption`（**未经校验的原值**）；provider 给出越界/无推荐时，OptionFrame 内部已兜底为 index 0，而结果字段仍是越界原值 → 前端高亮错位（`HandleRegenerate:563-574` 同问题）。建议用 `LValidatedOptions` 中 `IsRecommended` 反查最终索引。
- **ENG-05**（`:899` 与 `:1096`）：异常前已 `Inc(LState.TurnCount)`，但 `MakeErrorResult(AHandle.Id, 0, 'INTERNAL_ERROR', ...)` 报 TurnNumber=0 且已递增的计数因未写回而丢 → 下一轮重复同一 TurnNumber（历史重复编号），`MaxTurns` 预算少算一轮（成本门偏弱）。`MakeErrorResult:431-433` 一律 `Status := ssActive`，对"会话不存在"也报活跃（`:848`/`:865` 使用该工厂）→ 调用方据 `Status` 判生命周期会被误导。
- **ENG-06**（`:1053`）：`FPresenter.PresentExit(FExitHandler.HandleExit(LState, 'budget_exhausted'))` **无 try/except**（对比 `:463-477` 同类调用有兜底）；若 ExitHandler 抛异常会被最外层 `:1090` 归为 `INTERNAL_ERROR`，但此时已 `Status := ssCompleted`、已 `SaveCheckpoint`、已发布 `SessionCompleted`（`:1027-1051`）→ 状态"已完成"与结果"内部错误"矛盾，Presenter 收不到 `PresentExit`（UI 卡在提问态）。另 `:1052` 把 `HandleExit` 调用放在 `if FPresenter <> nil` 内 → 无 presenter 时连退出摘要都不生成（`:509-527` 同）。
- **ENG-07**（`:833-841` 与 `:694-697`）：`FProvidersFrozen` 先裸读后加锁置位，与 `RegisterProvider` 的加锁检查+raise 构成 TOCTOU → 并发下 `CreateEngineFromContainer`（`IoC.pas:132`/`:138`/`:144`/`:150`/`:156`）可能在首回合之后被调用 → **启动路径抛 `EInvalidOperation`**。

#### 🔵 ENG-08~ENG-10 与小项

- `:612-614`、`:629`、`:644`、`:657`、`:677`：5 个 `Publish*` 全用空 `except`，EventBus 订阅者异常被完全吞掉且**不留任何日志**（审计/埋点链路断裂不可诊断）。建议至少 `Log(ltWarning, E.ClassName + ': ' + E.Message)`。
- `:958-960`：token 计量为 `Length(Question) div 4` 且仅当 `RequiresLLM = True` 才计入 → 与真实用量无关；`TBudgetConfig.MaxTokens` 默认 0（`Types.pas:246`）且 FeatureConfig 强制 0（`FeatureConfig.pas:191`）→ **token 预算三源一致地失效**（L4 一次 5 个 LLM 调用只计 1 次）。
- `:218-227`：`FOwnsEventBus` 两分支都置 False → 死字段，`Destroy:252-253` 的释放分支不可达。Engine 1297 行（未超 2000，但已是模块内最大文件）。
- 正面：**锁序无死锁** —— 实测全部为 `LSessionLock → FGlobalLock` 单向嵌套（`:857-871`、`:1025`→`:1029`），未见反向嵌套 ✓。

#### 🟡 RTR-01~RTR-03 路由语义

- **RTR-01**（`Router.pas:109-117`）：`ClampDepth` 用 `>` 而非 `>=` 做上限钳制（`if ADepth > LMaxDepth then Result := LMaxDepth - 0.01`），而 `DepthToLevel`（`:76-85`）用 `ADepth < 0.2/0.4/0.6/0.8` 阶梯 → `ADepth` **恰好等于边界**（如 0.4 且 `MaxLevel = clL1`）时不钳制，`DepthToLevel(0.4) = clL2` → **超出 MaxLevel 一级**。逐轮 `+0.02` 浮点累加确实会落在边界邻域。建议改 `>=` 或 `Result := Min(ADepth, LevelToMaxDepth(AMaxLevel) - 0.01)`。
- **RTR-02**（`:224-248`）：深度单调累加（信号 +0.1、轮次 +`TurnCount*0.02`、长输入 +0.05），唯一减项是"长度<10 **且** 无任何信号"-0.1 → 跨过 0.6/0.8 后永久停在 L2/L3/L4；用户输入"别问了算了"时 `ComputePosture` 只改姿态为 `posExecutive`，**深度不减** → 与"挫败时快速收敛"目标相反。`HasSignal`（`:251-265`）**不看 Confidence**，0.01 置信度信号也算"有信号" → 污染规则 2 与 `+0.1`。
- **RTR-03**（`:171`）：要求 `GetMaxConfidence(..., skFrustration) > 0.5`，而 SignalDetector 单独命中一个"烦/算了"关键词恰好 = **0.5**（`SignalDetector.pas:240`）→ 单一强关键词永远不足以切到 `posExecutive`（必须再叠一个证据），阈值与产生器不同源。
- **RTR-04/05**：阈值全为硬编码字面量（0.2/0.4/0.6/0.8、0.7、0.5、10/50/100、0.1/0.05/0.02/0.01），无命名常量、不可注入（SSOT）；`DepthToLevel(NaN)` → `clL4`（所有 `<` 比较为假），`EnsureRange(NaN)` 两比较皆假 → 返回 NaN（持久层 `JsonFloat` 可产出 `1e999` → Infinity）→ 建议加 `if not (ADepth >= 0.0) then Exit(clL0)` 守卫。

#### 🟡 BDG-01~BDG-03 预算控制

- **BDG-01**（`Budget.pas:57`、`:74-75`）：`LElapsedMs := MilliSecondsBetween(Now, AStartTime)`，而 `AStartTime = LState.CreatedAt`（Engine `:977`，由 `Now` 赋值）→ **时钟回拨/时区变更/夏令时** 使 `LElapsedMs` 为负 → 时间预算永不触发（无 `Max(0, ...)`、无回拨检测、未复用 TimeGuard 的单调时钟）。与本轮 TimeGuard/Licensing/BDG/SM-05/LR-04 同属"挂钟依赖"家族。
- **BDG-02**（`:61-78`）：`TBudgetConfig` 四个维度中 `MaxCognitiveLoad` 与 `UserPatienceThreshold` 在 `Check` 中**完全未使用**；Engine 也不依据挫败置信度触发退出 → `frustration` 退出触发器从未接线（死配置）。
- **BDG-03**（`:64`、`:70`）：无上限时返回 `MaxInt` → 直接喂给 `TOptionFrameBuilder.BuildProgressHint`（Engine `:990`）产出"预计还需 2147483647 轮"（`Moments.GenerateExpectationHint` 同）。
- 🔵 `TBudgetController` 注册为容器单例（`IoC.pas:87`）但引擎自建实例（`Engine.pas:215`）；本单元实际无状态，可全为 `class function`。

#### 🟡 OF-01/OF-02 选项框兜底掩盖真实失败

- **OF-01**（`OptionFrame.pas:166-175`，`BuildOptions:84-93` 同）：provider 什么都没给时注入 `Number=1, Text='继续', Value='continue', IsRecommended=True`，**不置任何降级标记**（Engine `:993` `Result.DegradationInfo := ''`）→ 前端把兜底当真实选项，`Source` 仍是 provider 原值。属任务书"吞异常致门失效"的同族：**吞空结果致质量门失效**。
- **OF-02**（`:117` 与 `:120`）：`EstimatedRemaining := Max(AEstimatedRemaining, 0)` 但消息分支用**原始** `AEstimatedRemaining` 判定 → `<= 0` 时消息"即将完成"而字段已被改为 0（且 MaxInt 直通显示）。
- 🔵 OF-03：提示语硬编码中文（'继续'、'第 %d 轮/预计还需 %d 轮'）且无视 `Locale`；`ParseOptionSelection:151` 用 locale 相关 `TryStrToInt`（'+3' 亦接受）；正面：`MAX_OPTIONS = 8` 与特殊输入 '9'/'0' 不冲突（`:62-70` 常量集中）✓。

#### 🟡 EXIT-01/EXIT-02 退出处理

- **EXIT-01**（`Exit.pas:44`）：`CheckpointSaved := True` **无条件谎报** —— `TGracefulExitHandler` 从不保存任何检查点（保存由 Engine 在外部做，且 `FStorage = nil` 时根本不保存）→ 契约字段误导调用方与审计；反常的是 Engine 的异常兜底分支（`:474`）诚实设 False。
- **EXIT-02**（`:74-88`）：声明支持 5 种 reason（`'user_cancel'`/`'info_sufficient'`/`'budget_exhausted'`/`'frustration'`/`'action_over_perfection'`），实际代码只产生三种：`'user_cancel'`（Engine `:464`/`:510`/`:530`）、`'budget_exhausted'`（`:1037`/`:1051`/`:1053`）、**`'cancelled'`**（`:1245`/`:1259`，`CancelSession`）。`'cancelled'` 不在名单 → 落入 else 分支输出"会话 %s 已暂停，可随时恢复"，**与"已取消并保存检查点"的真实语义相反**；`info_sufficient`/`frustration`/`action_over_perfection` 全仓无生产者（Requirements 10.1-10.6 未实现）。根因：reason 为裸 string，三处（Engine/Exit/Metrics）各自拼字面量（ICI-02 的具体爆发点）。
- 🔵 EXIT-03：`BuildSummary` 不用 `AState.History/Signals`（摘要信息量低）；`:81` `Format(常量串, [])` 多余。**未发现问题的维度**：内存/线程（`HandleExit` 传 `const AState`，纯函数，无共享状态）。

#### 🟡 SD-01~SD-03 信号检测

- **SD-01**（`SignalDetector.pas:128`、`:134`、`:182`、`:190`、`:202`、`:237`、`:294`、`:343`、`:362`）：只支持中文关键词（'嗯'/'呃'/'不确定'/'不是'/'其实'/'不要'/'算了'/'烦'/'够了'/'换个'/'别的'/'对！'/'明白了'/'原来'），英文仅补了 `'?'`/`'!'`；`Locale` 不参与 → 非中文会话 5 类信号置信度恒 0 → Router 的 `+0.1`、`posExecutive`/`posReflective`/`posAdvisory` 分支全部不可达（连带 BDG/EXIT 的挫败保护失效）。
- **SD-02**：`skAvoidance` 检测后**无消费者**（Router 只用 Hesitation/Contradiction/Frustration/Breakthrough + 通用高置信度，`Router.pas:153-156`；Engine 只把 signals 塞进结果 `:920`/`:994`）→ 死信号。
- **SD-03**：各检测器置信度独立相加后 clamp（0.4+0.3+0.2+0.3=1.2→1.0），互不校准；`Result.DetectedAt := Now` 每检测器各取一次（同轮 5 个时间戳）；阈值（0.4/0.3/0.2/0.5/0.6）硬编码、词表不可注入 → 无法单测/本地化/调优。
- 🔵 SD-04：每轮 5 次 `Log(ltDebug, Format('%.2f', ...))` 无 `TFormatSettings`（纳入 X-05）；Debug 关闭时字符串仍先在调用点构造（每轮 5 次 ToLower/Contains + Format）。
- 正面：`CountToken:48-66` 用 `PosEx(AToken, AText, LStart)` 避免 O(n²) Copy（IC-019 修复有效，已复核 ✓）；`Detect` 全程 `TList` + `try/finally` ✓；`ClampConfidence` 用 `EnsureRange` ✓（但 NaN 不防御，同 RTR-05）。

#### 🟡 SM-02~SM-08 会话与状态机（`Session.pas` 480 行 / `SessionFSM.pas` 216 行）

- **SM-02 魔法序数解耦枚举（SSOT）**（`d:\_Progs\02Business\DeepBase\Features\DeepBase.IntentClarification.Session.pas:141-142`、`d:\...\DeepBase.IntentClarification.SessionFSM.pas:79`）：

```pascal
  IC_STATUS_COMPLETED = TSessionStatus(2);
  IC_STATUS_ARCHIVED  = TSessionStatus(3);
```

  而权威定义在 `DeepBase.IntentClarification.Types.pas:27-32`（`ssActive/ssSuspended/ssCompleted/ssArchived/...`）。两个单元各自重复 cast，**与枚举声明顺序强耦合**。触发条件：任何人在 `TSessionStatus` 中间插入一个新状态。后果：`TransitionTo` 的 `case IC_STATUS_COMPLETED` 分支（`Session.pas:184`、`SessionFSM.pas:96/136/155`）静默指向错误状态，迁移表整体错位而编译不报错。建议：直接写 `ssCompleted`/`ssArchived`，删除本地 cast 常量。
- **SM-03 检查点主动丢弃历史**（`Session.pas:347-348`）：`SaveCheckpoint` 里 `TurnHistory := nil; OpenQuestions := nil;` 且 `RapportSnapshot := Default(...)`（只填 `UserId`）→ 与 🔴 ICT-01 叠加，恢复出的会话是"无对话历史的空壳"，但状态字段被标为可继续。
- **SM-04 恢复检查点无合法性/状态前置校验**（`Session.pas:377-378`）：`RestoreCheckpoint` 无条件 `AddOrSetValue`，**不检查当前是否 `ssActive`、不消费 `ACheckpoint.Error`**（`Types.pas` 已提供该字段）→ 一份损坏或陈旧的检查点 JSON 可静默劫持并回滚一个正在进行的活跃会话。触发条件/攻击面：任何能提交检查点的通道（含 `Persistence\DeepBase.IntentClarification.Storage.pas` 与云同步链路）。建议：`if LSM <> ssSuspended then Exit(False)` + `if ACheckpoint.Error <> '' then Exit(False)` + 校验 `SessionId` 一致性与 `SchemaVersion`。
- **SM-05 空闲超时依赖挂钟 + 无下限 setter**（`Session.pas:326`、`:420`、`:135`）：`SecondsBetween(Now, LastActiveAt)`（时钟回拨 → 负值 → 永不超时；与 BDG-01/LR-04/TG 同族）；`FIdleTimeoutSeconds` 暴露 public `write` 且无下限校验，设 0 时 `SuspendIdleSessions` 一次挂起**全部**活跃会话。建议：改用单调时钟（`TStopwatch`/`GetTickCount64`）+ setter 钳制 `>= 60`。
- **SM-06 状态机不持久 + 幂等语义丢失**（`Session.pas:278`、`:299`）：每次 `TransitionTo` 都 `CreateStateMachine` 再 `LSM.Free`，状态机退化为一次性校验器（白白承受构造/析构开销，见性能维度）；目标态 == 当前态时返回 False，调用方无法区分"已在目标态（幂等成功）"与"非法迁移"。
- **SM-07 会话回收不可达**（`Session.pas:388-398`）：`RemoveSession` 是全模块唯一的容器回收入口，但 Engine 从不调用（呼应 🔴 ENG-01 的会话字典只增不减）→ 该 API 是死路，泄漏无法从外部修复。`destructor:158-160` 先 `FLock.Free` 再 Free 容器（若在 finally 期间仍有并发访问则为 UAF；当前无并发调用者故未升 🔴）。
  - ✅ 正面复核：`SuspendIdleSessions` 的两段式加锁（先快照 key、锁外取值再回锁）**已修复正确**（`Session.pas:412-443`），记入"历史缺陷复核"。
- **SM-08** `StatusToTrigger:179-189` 用"目标状态"反推触发器（`ssActive → stResume`），语义上是巧合正确（首次 `ssCreated→ssActive` 也会得到 `stResume`），建议由调用方显式传入 trigger。
- **本组未发现问题之维度**：**内存与生命周期**（`Session.pas` 容器由 `TObjectDictionary.Create([doOwnsValues])` 持有，未发现双重所有权；`TurnHistory` 为 `TArray` 值语义 ✓）。

#### 🟡 TPL-01~TPL-04 模板与校验双口径

- **TPL-01 两套并存的"模板是否合法"答案**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.IntentClarification.Templates.pas:80-103`（`ValidateTemplate`，4 个 `if`；`:29-33` 的 `CRequiredFields` 声明 5 项含 `'MaxLevel'` 却**从未被读取** = 死常量；不校验 `Style`/`MaxLevel` 白名单）与 `d:\...\DeepBase.IntentClarification.Validation.pas:152-204`（`TICTemplateValidator.BuildDefaultRules`，6 条规则，含 `Style` 白名单与 `MaxLevel` 范围）。`Validation.pas` 单元头 `:4-5` 明写"Replaces manual if-checks in Templates.ValidateTemplate"——**实际未替换**，且经全仓 grep，`TICTemplateValidator` 的生产代码消费者为 0（仅 `Tests\Test.DeepBase.IntentClarification.Integration.pas:605,610`）。后果：同一模板两套判定可给出相反结论；较松的一套在生产路径生效。
- **TPL-02 覆盖失败被静默吞**（`Templates.pas:119-156`）：枚举字段越界会 `raise`（IC-015）、未知字段名会 `raise`（IC-016），但**整数/浮点非法值静默保持原值**（`:145-152` 用 `StrToIntDef(AValue, 原值)` / `StrToFloatDef(..., 原值)`）→ `MaxTurns=abc` 返回"成功"而值未变；布尔分支（`:141-144`）把任何非 `'true'`/`'1'` 输入（含拼错的 `'ture'`、`'TRUE '`）**静默解释为 False** → 特性被误关。建议：三态返回"已应用/未识别/非法"，非法即 raise。
- **TPL-03 locale 依赖**（`Templates.pas:152`）：`UserPatienceThreshold` 用 locale 相关 `StrToFloatDef` → 德语/法语机器上 `'0.7'` 解析失败并静默保持原值。（本轮同类问题已累计 5 处：CU-01、CS-08、Graph `:301`、此处、主单元 `JsonFloat:229`；统一收进 X-05。）
- **TPL-04 结果不复核**：`ApplyOverride` 产出后不重跑 `ValidateTemplate`，可生成 `MaxTurns<=0`、`Style=''`、`EnablePersonas=True 但 PersonaPack=''` 的非法模板；而调用方（Engine）本身也**从不调用** Validate（ENG-03 同源）。
- 🔵 TPL-05：`LoadTemplate` 无 `ListTemplates`（名单散在 `:70-75` 的 `SameText` 链）；三个纯函数声明为实例方法；`:111` `Result := ATemplate` 的 record 含 `TArray`，值拷贝引用计数正确 ✓。
- 🔵 **VAL-01（正面）**：`Validation.pas:228-235` 每条规则独立 `try/except` 且**把异常记为校验失败**（fail-closed 方向正确 ✓）；`TICValidationRule.Validator` 为不捕获外部状态的匿名函数，存入 `TList<record>` 无生命周期风险。
- 🟡 **VAL-02** 规则集不完整：`MaxTokens`/`MaxCognitiveLoad`/`UserPatienceThreshold`/`EnableAnticipation`/`EnablePersonas`+`PersonaPack` 联动/`DefaultPosture` 全无规则。

#### 🟡 MET-01~MET-03 指标可信度

- **MET-01 token 双计（统计恒 2 倍）**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.IntentClarification.Engine.pas:966-968` **同时**调用 `FMetrics.RecordTurn(..., LTokensThisTurn)` 与 `FMetrics.RecordTokens(LTokensThisTurn)`，而 `d:\...\DeepBase.IntentClarification.Metrics.pas:102` 的 `RecordTurn` 内部已经执行 `TInterlocked.Add(FTotalTokensUsed, ATokensUsed)`：

```pascal
  FMetrics.RecordTurn(Ord(Level), LTokensThisTurn, LLatency, True);
  FMetrics.RecordTokens(LTokensThisTurn);   // ← 第二次累加
```

  触发条件：任何一轮正常完成的澄清。后果：`TotalTokensUsed` **恒为真实值 2 倍**，基于它的预算/告警/计费全部失真（预算侧另有 ENG-09 的低估，两个方向的误差叠加后不可解释）。
- **MET-02 宣称的集成不存在**：`Metrics.pas:5` 单元头"Integrates with DeepBase.Metrics"、`:40` "flushed to DeepBase.Metrics periodically"，但 uses 列表（`:20-27`）**不含 `DeepBase.Metrics`**，真实调用点全是注释（`:113-118`、`:128-129`）→ 指标永不出仓、无 histogram/分位数；`ALevel`/`APosture`/`AReason` 参数除写日志外不参与任何统计。可观测性是"看起来有"（与 FC-01 同族）。
- **MET-03 撕裂读**：`AverageLatencyMs:140-146` 与 `Log(..., FSessionsCompleted):132` 裸读跨线程 `Int64/Double` 字段；`Reset:148-155` 多字段清零非原子（并发下可读到"总数已清、平均值仍旧"）。🔵 正面：`FMaxLatencyMs` 的 CAS 循环（`:105-111`）实现正确 ✓。

#### 🟡 IOC-IC-02~IOC-IC-04 IoC 假注入

- **IOC-IC-02 容器单例是死对象**：`d:\...\DeepBase.IntentClarification.IoC.pas:86-89` 注册 `TSignalDetector/TBudgetController/TGracefulExitHandler/TPostureDepthRouter` 四个单例，但 `Engine.Create:213-216` 自己 `Create` 四个新实例，全模块无任何 `Resolve<>` 取用它们 → **外部替换实现对引擎完全无效**（典型的"注册即以为注入"）。
- **IOC-IC-03 推荐路径下 EventBus 静默不发布**：`IoC.pas:83` `RegisterSingleton<IClarificationEngine, TClarificationEngine>` 走无参 `Create`（`Engine.pas:195-198` → `Create(nil)`）→ `FEventBus = nil` → 5 个 `Publish*` 全部 `if FEventBus = nil then Exit`（`:605/:622/:638/:652/:667`）。Phase2 宣称的"EventBus 发布会话事件"在文档推荐入口下**一条都不会发生**，且无任何日志告警。
- **IOC-IC-04 provider 名单双处硬编码 + 装配时序无保护**：`IoC.pas:98-107`（注册）与 `:129-157`（逐个 `IsRegistered`/`Resolve`）重复写 10+ 次同样的名字，缺 `ResolveAll<ILevelProvider>` 统一装配；`CreateEngineFromContainer` 可在引擎已跑完首回合后被调用 → 内部 `RegisterProvider` 抛 `EInvalidOperation`（见 🟡 ENG-07），而注册辅助自身**无 try/except、无"引擎是否已被使用"前置检查**。

#### 🔴 FC-01 `Reload` 整体是注释，特性开关与预算上限实为硬编码

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.IntentClarification.FeatureConfig.pas`（`Reload` 方法体全部为注释，从不读取 `Config/FeatureFlags`）
- **问题说明**：单元对外承诺"从配置中心加载特性开关 / 最大级别 / 预算"，实际 `Reload` 是空实现（整段被注释掉），所有字段恒为构造默认值。Engine 通过 `FFeatureConfig`（`:509/:511/:526` 等真实读取点）取到的永远是编译默认。
- **触发条件**：运维通过配置关闭某一层（例如 L4 以省钱）或调低 `MaxLevel`——**配置写入后无任何效果，且无告警日志**。
- **后果**：安全/成本门的"可配置性"是假的；与 MET-02、TPL-01、ENG-03、REG-02 构成同一族"声明与实现脱节"。
- **建议修复**：要么实现 `Reload`（接 `DeepBase.Config` 并做白名单校验 + 变更日志），要么删除 `Reload`/`Config` 相关公开 API 与文档承诺，避免给出错误的安全感。

#### 🟡 Rapport / Degradation / Moments / Anticipation 四单元

- **Rapport（`Rapport.pas` 191 行）**
  - `UpdateAfterSession:144-166` 是 `LoadProfile → 修改 → SaveProfile` 三步且**不跨步持锁** → 两个会话同时结束时互相覆盖（熟悉度/信任度/偏好深度 lost update，与 🔴 ENG-02 同族）。
  - `LoadProfile:110-129` 未命中时在**锁外**构造默认值并 `LastUpdated := Now` → 同一用户两次读取时间戳不同（非幂等），且不回写缓存，每次都重建。
  - `SaveProfile:131-142` 直接用 `LSanitized.UserId` 作字典 key，**无空串检查、无大小写/前后空白规范化** → `TDictionary` 默认序数比较器区分大小写，`'User'` 与 `'user'` 产生两份画像（SSOT 分裂），信任度被劈半。
  - `SanitizeProfile:97-108` 只钳 `TrustLevel/Familiarity/PreferredDepth` 与 `Style`，**不处理 `Boundaries`**（无去重、无长度上限）→ 外部可控字符串列表可无界增长（与 SD/L2 的无界集合同族）。
  - 🔵 单元头 `:17` 声称"SQLite 持久化在 Task 17.2 中实现"——未实现：画像仅内存，重启全丢；端口 `IClarificationStorage.SaveRapport`（`Interfaces.pas:206`）存在但 Engine 从不调用（Engine 只调 `SaveCheckpoint`）。`TRapportLayer` 注册为容器单例（`IoC.pas:92`）但 Engine 的 uses 列表不含 Rapport，`GetInitialDepth:168-178` 从未被 `StartSession` 使用（Engine `:755` 硬编码 `CurrentDepth := 0.3`）→ Requirements 11.x / Property 33-35 生产不可达。`:25-30` `const`/`var` 混写在同一 private 段（可编译但罕见）。
- **Degradation（`Degradation.pas` 85 行）**：🟡 **两套并存的降级逻辑** —— 本单元 `TDegradationHandler.Degrade:37-82`（L4→L3→L2→L1→L0 + `Info` 恒非空，满足 Property 14）在生产**零消费者**（grep 证据见本章章首），真实降级由 Engine `:311-323` 的 while 循环 + `:1005` 字符串拼接完成；`TDegradationResult` 类型从未出现在任何接口字段。逻辑本身无 bug（`case` 穷尽 + `else` 兜底 ✓），Info 串中文硬编码（`'降级 %s: %s'`、`'L0(已是最低级别)'`）。属架构维度缺陷（SSOT + 死单元），建议二选一并删除另一套。
- **Moments（`Moments.pas` 107 行）**：🟡 三个方法全为英文硬编码文案（`:68` `'Understood - you want to %s.'`、`:89` `'Based on our previous conversations about %s...'`、`:101` `'About %d more questions to go.'`），与 Exit/OptionFrame/Degradation/L0~L4 的中文混用 → 同一次会话内 UI 语言混杂；`GenerateEchoConfirmation:58-69` **不使用 `AUserInput`**（仅判空）→ "echo 确认"实际复述的是已解析意图而非用户原话，用户无法据此发现解析错误（该功能的唯一价值点失效）；`GenerateExpectationHint` 直通 `MaxInt`（BDG-03 同源）。🔵 无状态实例方法 + **零消费者**（死单元）。
- **Anticipation（`Anticipation.pas` 273 行）**：
  - 🟡 `FFeedback: TList<TFeedbackRecord>`（`:31`）只 append（`:244-270`）**从不读取** → 宣称的"反馈闭环/预测校准"（Requirements 9.x）完全未实现；列表无上限、无清理 → 单实例无界增长（性能/内存）。
  - 🟡 `GeneratePredictionId:74-80` 计数器为**实例作用域** → 多实例（当前 IoC 未注册本单元，未来注册为 transient 即发生）产生重复 ID；`FeedbackPositive/FeedbackNegative` 不校验 ID 是否存在，任意字符串（含空串）照收 → 反馈可被伪造且不可追溯。
  - 🟡 四路权重 0.15/0.30/0.35/0.20 而各分支上限 0.3 → `Result.Confidence` **恒 ≤ 0.3**（`:205-208`），任何 `> 0.5` 的消费门控永不可达（当前无消费者，故不升 🔴）。
  - 🔵 `AnalyzeTemporal:82-100` 忽略 `AContext` 只用 `Now`（挂钟/时区依赖）；`BuildEvidence:138-163` 同样忽略 `AContext` 参数。正面：`TInterlocked.Increment(FPredictionCounter)` ✓、`TList` + `try/finally` ✓、`EnsureRange` ✓。
  - 🟡 `IAnticipationEngine` 从未在 `IoC.pas`/`Registration.pas` 注册（`IoC.pas` uses 列表不含 Anticipation），Engine 的 `FAnticipationEngine` 字段**只写不读**（`:115` 声明、`:718` 赋值，全模块零读取点）→ 整单元生产悬空（与 `FPersonaRegistry:114/:712` 同一处失配模式）。
- **Logging（`Logging.pas` 27 行）**：🔵 `ltDebug = llDebug` 等常量别名 + 一行 `Logger.Log(AMessage, ALevel, 'IntentClarification')` 薄封装（`:23`）；与 `DeepBase.Logging` 存在 `Log` 同名遮蔽（`LLMResilience.pas:28-29` 同时 uses 两者）→ 符号解析依赖 uses 顺序，建议调用点显式单元限定。

#### 🟡 LR-03~LR-09 LLM 韧性层其余项（`LLMResilience.pas` 689 行；🔴 LR-01/LR-02 见本章前半）

- **LR-03** `:364-371`：except 分支 `FreeAndNil(LCtx)`——若异常来自 `LTask.Wait` 本身（而非任务内部），后台任务仍在跑且仍持有 `LCtx` 引用 → 与主线程的释放构成 double-free 窗口（与 LR-01 同根，但需 Wait 自身抛出发）。建议：超时/异常路径一律"放弃所有权"（只置 nil，永不 Free）。
- **LR-04** `:206`、`:240`：`MilliSecondsBetween(Now, FLastFailureTime)` + `FLastFailureTime := Now` → 时钟回拨使熔断冷却期永不结束（同 BDG-01 / SM-05 / TG 家族）。建议：改用 `TStopwatch`/`GetTickCount64`。
- **LR-05 half-open 无单探针门闩**：`ShouldAttemptHalfOpen:194-218` 把状态改为 `csHalfOpen` 后返回 True，但**没有其他线程的隔离**——后续并发线程进 `IsCircuitOpen` 时因已不是 `csOpen` 而直接放行 → 恢复瞬间全部流量一次性打到上游（thundering herd），熔断器形同虚设。建议：half-open 下只允许 1 个探针（`FHalfOpenInFlight` 标志 + CAS），其余快速失败。
- **LR-06 失败计数粒度错**：`RecordFailure` 仅在整轮重试耗尽后调用一次（`:380`/`:503`），`CircuitBreakerThreshold=3` 实际需要 3 轮 × (`MaxRetries`+1) ≈ 9 次真实请求才熔断；循环内的超时/异常分支不计失败 → **间歇性超时永不触发熔断**（恰是最需要熔断的场景）。
- **LR-07** `:359` `LLastError := Result.FinishReason`（丢弃 `Result.ErrorMessage`）→ LLM 真实失败原因不进日志，排障时只能看到 `stop`/`length`。
- **LR-08 无校验 setter**：`property Config ... read FConfig write FConfig`（`:141`）无锁无校验。`TimeoutMs <= 0` → `LTask.Wait(0)` 立即"超时"（每次调用都走超时分支）；`MaxRetries < 0` → `for LAttempt := 0 to FConfig.MaxRetries` 不执行 → 直接 RecordFailure 返回失败（静默禁用）；`CircuitBreakerThreshold <= 0` → 首次失败即永久熔断。建议：setter 加锁 + `EnsureRange`。
- **LR-09 安全门覆盖不一致**：`GenerateImageStream:603-610` **完全绕过熔断器与 try/except**（对比 `:554-579` `ChatStream`、`:612-636` `ChatVisionStream` 均有门控）；ChatStream/ChatVisionStream 在 `FInner.ChatStream` 正常返回后即 `RecordSuccess`，即使流内通过 `AOnError` 回调报错 → **流式失败不计入熔断**（与 OF-01 同为"门可绕过"家族）。
- 🔵 正面：circuit 状态的读/写全部在 `FLock` 临界区内 ✓；`FInner: ILLMClient` 接口持有，无裸对象所有权分裂；689 行未超文件大小阈值。

#### 🟡 五层 Provider 契约一致性（任务书重点维度 ⑦）

> 契约锚点：`ILevelProvider`（`Interfaces.pas`）只约定 `GetLevel/CanHandle/Process/RequiresLLM`，字段语义（`Success`/`Question`/`Options[].Value`/`Scaffolds`/`RecommendedOption`）全靠各自领会。以下为跨层不一致的具体爆发点。

- **L0-01（🟡）** `Provider.L0.pas:42-52` 与 `:54-90` 不一致：`CanHandle` 只看 `Depth < 0.2`（**不要求任何上下文**），`Process` 在无 `ActiveIntent` 时仍返回 `Success := True` + 泛化问题 `'请问您想做什么？'` + 单个自造选项。后果：**L0 在零信息时也报成功**，Engine 永不降级到 L1 做槽位填充（降级链在最低层被提前断掉）。
- **L1-01（🟡）** `Provider.L1.pas:9` 的 **interface** `uses DeepBase.IntentClarification` → Provider 层编译期依赖遗留主单元（主单元 implementation uses Engine `:157`）。不是循环依赖（Engine 不 uses 主单元），但分层方向脆弱：删除/重命名主单元即编译失败整个五层。`TIntentClarifier` 无 `Destroy`、非 `TInterfacedObject`。
- **L1-02（🟡）LLM 成本逃逸预算**：`Create(AClarifier <> nil)` 分支（`:54-58`）**不改 `Policy.UseLLM`**，而 `RequiresLLM` 恒返回 False（`:82-85`）：

```pascal
function TL1SlotProvider.RequiresLLM: Boolean;
begin
  Result := False;   // 即使 FClarifier.LLM 已配置
end;
```

  外部传入的 `TIntentClarifier` 若配了 LLM，Engine 既不计入 token 预算也不走熔断（"L1 零 LLM 依赖"的声明只对自建实例成立）。建议：`RequiresLLM := (FClarifier <> nil) and FClarifier.LLM.LLMClientAssigned` 或强制 `UseLLM := False`。
- **L1（🔵）** `ConvertResult:113-157`：`IsRecommended := (I = 0)` + `RecommendedOption := 1` 硬编码（丢弃原结果的推荐位）；成功分支不填 `Scaffolds`（L2 填）→ 下游按字段有无判断层级行为会不一致；`BuildRequest:93-111` 的 `RecentTurns` 只取 `History[I].UserInput`（不含助手回复）且**无条数/长度上限**（长会话直接拼出超长 prompt）。
- **L2-01（🟡）per-session 字典无界增长**：`Provider.L2.pas:31` `FSessionDenied: TDictionary<string, TList<string>>` + `:27` `CMaxDeniedPerSession = 64` 只限制**每会话列表长度**；字典 key（SessionId）数量无上限、无 `ClearSession`/`Remove` API（对比 L3 有 `ResetExpert:329-337`）→ 每会话泄漏一个 `TList`，直到 `Destroy:79-93`。与 🔴 ENG-01（会话字典只增不减）叠加：上游已无界，本层又乘一个系数。
- **L2-03（🟡）** `ParseScaffolds:165-203` 兜底链（无 bullet → 取第一个非空行 → 再兜底 `Trim(AContent)` 整段）会**把整段 LLM 回答当成选项文本**（Property 15 的"至少 1 个"以牺牲质量换来）；不过滤 ``` 代码围栏、markdown 加粗（对比主单元 `NormalizeJsonObjectText:159-181` 处理了围栏 → 同库内两套解析器，一有一无）。
- **L2-04（🟡）** `ProcessWithLLM:248-249`：注释写"Extract question (last non-bullet line or generate default)"，实现直接 `Result.Question := '您的真实需求是以下哪个方向？'` → **prompt 明确要求的澄清问题被丢弃**（LLM 成本浪费 + 语义丢失，用户看到的问题与自己的真实上下文无关）。
- **L2-05（🟡）** `:217` `FLLM.Chat(...)` 无 try/except：降级路径 `BuildDegradedResult` 只覆盖"`Success = False`"，不覆盖"抛异常"。接了熔断 wrapper 时 `MakeCircuitOpenResult` 返回 `Success=False` 可走降级，但**未接熔断的裸客户端抛异常即直接绕过降级保护**（Engine 外层有 try/except 但会记为整会话失败而非降级）。
- 🔵 L2：`BuildConstraintsText:144-163` 无长度截断（最多 64 条全量拼进 prompt → token 膨胀）且 `Result := Result + x` 为 O(n²)；`for I := 0 to Min(High(LScaffolds), 7)` 对空数组安全（`High = -1`）✓；`:286-309` 的 `AContext.Hypotheses` 同步分支因 `Hypotheses` 恒空而**永不执行**（见 ICI-01），`DenyHypothesis:314-330`/`GetDeniedHypotheses:332-345` 仅测试调用。
- **L3-01（🟡）专家选择跨临界区 TOCTOU**：`Provider.L3.pas:124-167` 的"读（`:131-136`）—判（`:138-145`）—写（`:161-166`）"跨**三个独立临界区**，非原子。同一 `SessionId` 并发两请求各自选中不同专家、后者覆盖 → Property 18（跨轮专家一致）被破坏。建议：整段包入单一临界区或改用 `TryAdd` 语义。
- **L3-02（🟡）** `IsExpertSwitchRequested:112-122` 用中文/英文子串白名单（`'换专家'`/`'switch expert'`/`'换一个'`/`'other expert'`/`'另一位'`）判定"用户要求换专家"：`'换一个思路讲讲'` 误命中 → 频繁重选专家（额外 LLM 调用 + 上下文丢失）；无置信度、不看 `Locale`。
- **L3-03（🟡）Persona 子系统在生产不可达**：`FPersonaRegistry` 恒为 nil（`IoC.pas:104` `Create(nil, nil)`、`Registration.pas:85` `Create(ALLM, nil)`）→ `SelectExpert` 永远走 `:151-159` 的硬编码 `'generic-expert'`/`'通用顾问'`；而 `Engine.SetPersonaRegistry`（`Engine.pas:712`）**从不传播到已注册的 provider**（Engine 只存字段从不读，见本章 grep 取证）→ 即使应用调了 setter 也不生效。
- **L3-04（🟡）** `FindBestMatch` 返回 `Name = ''` 的 Default profile 时**无兜底**（L4 有 `'专家 N'`，L3 没有）→ `BuildSystemPrompt:169-178` 产出 `"You are , an expert in . "`（提示词损坏，LLM 行为不可控），`:260` `Result.Question := LExpert.Name + ' 的建议：'` 产出空前缀文案。同族代码不一致（与 L4 对比即见）。
- 🔵 L3：`GetCurrentExpert:308-317` 用 Default record 表示"无专家"，调用方无法区分"未选"与"真有一个空名字专家"；`BuildUserPrompt:180-194` 中 `:184` 的赋值被 `:189` 整体覆盖（冗余死代码）；`:296-303` 的 Remove+SelectExpert 组合语义正确但分散；**锁使用正面** ✓：`FLock` 覆盖所有 `FSessionExperts` 访问点（IC-008/009 已生效）。
- **L4-01（🔴）单 Turn 串行 5 次 LLM 调用，无超时/异常保护且共享熔断器**：`Provider.L4.pas:340-390`（`Process`）+ `:191-223`（`GenerateViewpoints`）+ `:225-252`（`SynthesizeConsensus`）：一次调用发起 `len(panel)+1`（最多 **5**）次 `FLLM.Chat`，全部**无 try/except**（`:212`、`:244`、`:374`）、无单轮取消；Engine 在 per-session 锁内调 provider（`Engine.pas:940`）→ 最坏 5×timeout 全程持锁，同会话其他请求全部堆积。若注入熔断 wrapper，5 次连续失败会**立即打开整个进程共享的 circuit**（连带影响其他层/其他调用方）。成本上 Engine 只按 1 个 Question 计 token（ENG-09）→ **最贵一层的成本被严重低估**（5×）。
- **L4-02（🟡）** `SelectPanel:114-176`：`LDesiredCount := ClampPanelSize(3)` 对常量做钳制 = 无意义代码，面板规模恒为 3，完全无视 `AContext`（用户输入长度/意图复杂度）→ Property 19（面板规模自适应）退化为常量。建议：从 `AContext`/`FeatureConfig` 取期望值。
- **L4-03（🟡）用中文字面量做控制流哨兵**：`:362` `AViewpoints[I].Content = '（该专家暂时无法提供观点）'`、`:370` `LSynthesis = '综合分析暂时不可用，请参考各专家的独立观点。'`。`GenerateViewpoints` 内部明明知道 `Success`，却只以哨兵字符串传出 → **改文案或 LLM 复述该串即控制流失效**（无错误码/标志位）。建议：`TViewpoint` 增加 `Succeeded: Boolean` + `ErrorCode`。
- **L4-04（🟡）** `LAllViewpointsFailed` 且 synthesis 成功时仍走 `BuildResultFromViewpoints:254-317` → 用户看到 N 个失败哨兵串 + "采纳 专家1 的建议"（内容为空）的无意义 UI（与 OF-01 同属"兜底掩盖真实失败"）。
- **L4-05（🟡）`Options[].Value` 语义在五层不一致**：`:286` `LOption.Value := AViewpoints[I].Speaker`（专家人名），而 L0/L1/L2/L3 的 `Value` 都是建议内容文本 → 下游"采纳某选项"拿到的是一人名而非建议内容（契约漂移，需上层硬编码分支适配）。
- **L4-06（🟡）** `:388-389` 同时置 `Success := True` 与 `ErrorMessage := 'Synthesis unavailable...'`：契约无"部分成功"概念，Engine 只看 `Success`，但 `Engine.pas:1005` 又会把 `ErrorMessage` 拼进 `DegradationInfo` → 部分成功与降级互相污染（前端无法判断该不该弹错误条）。
- 🔵 L4：`:282` `Min(High(AViewpoints), 7)` ✓；`:154-174` fallback 面板 `case I of 0, 1` 只覆盖 2 项（若 `CMinPanelSize > 2` 则新元素为 Default，但 `:209-210` 有 `'专家 N'` 兜底 ✓）；`FExpertTier`/`FSynthesisTier` 可注入但 IoC 只用双参构造（`TierBalanced`/`TierSmart` 硬编码）。

#### 🟡 REG-01~REG-03 注册辅助与容器双 SSOT（`Registration.pas` 108 行）

- **REG-01 provider 来源双 SSOT**：`RegisterLLM:77-87` 在 `AEngine.SetLLM(ALLM)` 后**新建** L2/L3/L4 provider 并 `RegisterProvider`（`:84-86`），而容器里 `IoC.pas:102-107` 注册的 nil-LLM 实例仍然存在（同名 `'L2'`/`'L3'`/`'L4'`）→ 同一抽象层有两套实例，容器里那 3 个永不使用但仍由容器 `Free`（生命周期归容器、使用归 Registration）。
- **REG-02 `ApplyPreset` 名不符实**：`:89-105` 的 `Result := LManager.LoadTemplate(APresetName)` 后**只注册 L0/L1，从不把模板应用到引擎**（无 `SetFeatureConfig`/深度/姿态/预算赋值）→ 调用者以为已应用 preset，实际全部参数仍为默认。与 🟡 ENG-03（`Template` 只写日志）、🔴 MAIN-01（`CreateEngineWithPreset` 忽略参数）构成**同一"模板不生效"缺陷的三个独立爆发点**。未知 preset 名静默返回 Default record（无异常、无日志）。
- **REG-03 无效传播**：`RegisterPersonaRegistry:69-75` 只调 `AEngine.SetPersonaRegistry`（Engine 存字段从不读）→ 对已捕获 nil 的 L3/L4 provider 无任何影响（`Create(ALLM, nil)` 在先）；`RegisterDomainAdapter`/`RegisterPresenter` 只对 `AEngine` 做 nil 检查，`AAdapter`/`APresenter` 可为 nil 照收。
- 🔵 正面：`RegisterAll:48-51` 纯转发 `TICIoCRegistration.RegisterAll`（无重复逻辑）；`LManager` 用 `try/finally Free` ✓。

#### 🔴 MAIN-01 `CreateEngineWithPreset` 完全忽略 `APresetName`（文档推荐入口直接坏）

- 位置：`d:\_Progs\02Business\DeepBase\Features\DeepBase.IntentClarification.pas:817-821`（对比 `:812-815`）

```pascal
class function TIntentClarifier.CreateEngineWithPreset(
  const APresetName: string): IInterface;
begin
  Result := TClarificationEngine.Create;   // APresetName 从未使用
end;
```

- **问题说明**：与无参 `CreateEngine` 逐字相同，但文档注释 `:138-144` 声称 "configured with the named preset template"。且返回的引擎**没有任何 provider**（需外部逐个 `RegisterProvider`）→ 直接调 `SubmitInput` 时 `FindProvider` 全部失败，每一回合都得 Engine `:944-948` 的兜底文本。
- **触发条件**：任何按注释推荐入口（"use the IoC path"失败时）使用 `CreateEngineWithPreset('conservative')` 的应用。
- **后果**：用户指定的预算/最大深度/特性开关全部失效（包含"关闭 L4 以省钱"这类成本门），且无错误提示 → 属**安全/成本门静默失效**，计 🔴。
- **建议修复**：删除该重载，或实现为 `LoadTemplate` + 真实写入引擎配置 + `TICIoCRegistration.RegisterAll`，并在模板不存在时 raise。

#### 🟡 MAIN-02~MAIN-07 遗留 `TIntentClarifier` 的置信度与解析缺陷

- **MAIN-02 无置信度信息默认放行**（`DeepBase.IntentClarification.pas:415-423`、`:478-499`、`:539-540`）：

```pascal
  Result := (Trim(Value) <> '') and
    ((Confidence <= 0) or (Confidence >= AMinConfidence));   // IsSatisfied
...
  else if LSlot.Confidence <= 0 then
    LValue := 1.0;                                           // CalculateConfidence
```

  `Confidence <= 0`（即"LLM 没给分/解析失败"）被视为**满分**。叠加 `:539-540` `if Result.Confidence <= 0 then Result.Confidence := 1.0` → 只要槽位非空就 `icsReady`。**澄清质量门在信息缺失时默认放行**（fail-open），与 `Init` 将 `Confidence := 0` 的默认值组合后意味着：LLM 返回完全不相关 JSON 时系统反而"已就绪"。建议：未知置信度二态区分（`HasConfidence` 标志），缺失时 fail-closed 或走显式人工确认。
- **MAIN-03 任意自由文本获得满分置信度**（`:753-788`，关键点 `:783-785`）：`ApplyOptionAnswer` 在用户输入不匹配任何选项时直接 `Value := LAnswer; Confidence := 1.0` → 绕过 `MinSlotConfidence`/LLM 判定，下一轮必 `icsReady`（澄清循环的逃逸门，且与 MAIN-02 叠加使任何胡言均可一次性通过）；`LAnswer = ''` 时 `Result := True` 但什么都没改（谎报成功）。建议：自由文本走 `UseLLM` 重新打分，空串返回 False。
- **MAIN-04 JSON prompt 在中间硬切 + 可抛异常**（`:617-620`、`:587-623`）：`MaxPromptChars` 超限时直接 `Copy(Result, 1, N)` → **在 JSON 字符串中间硬切**（送给 LLM 的是非法 JSON，无截断标记、无槽位降级）；`:605` `TJSONNumber.Create(LSlot.Confidence)` 当 `Confidence` 为 NaN/Infinity 时可使 `ToJSON` raise，而 `:587-623` 只有 `finally LRoot.Free` 无 except → 异常直接冒泡出 `Clarify`（调用方未必包住）。建议：按整槽截断（丢弃尾部槽位并附 `"truncated":true`）；写 JSON 前 `if not (Confidence.IsFinite) then ...`。
- **MAIN-05 外部输入无范围钳制**（`ParseSlots:326-368`，关键点 `:361-362`）：`Confidence := JsonFloat(...)` 无 `[0,1]` 钳制 → LLM 可返回 5/`1e999`(Infinity)/解析失败的 NaN。NaN 使 `Confidence >= AMinConfidence` 恒为 False → 该槽永不满足 → **无限澄清循环**（与 MAIN-02 的 `<= 0` 放行形成两个方的失效）。新增槽用 `SetLength(Result, Length+1)` 逐个扩容 O(n²)。建议：`EnsureRange(C, 0.0, 1.0)`（注意 `EnsureRange` 不防御 NaN，需先 `IsFinite`）。
- **MAIN-06 选项码溢出**（`:306`，与 `:268-269`/`:289-290` 联动）：`Result[I].Code := Chr(Ord('A') + I)`；而 `TrimOptions` 与 `ParseOptions` 在 `AMaxOptions <= 0` 时**取消上限**（`Policy.MaxOptions` 是 public write，`:147`）→ `I > 25` 时 Code 变成乱码大字符码点，前端选项码重复/不可选。建议：`Code := IntToStr(I+1)` 或 `Chr(Ord('A') + (I mod 26))`+后缀，并对 `MaxOptions <= 0` 钳为默认 8。
- **MAIN-07 降级结果矛盾 + 半成品外泄**（`Clarify:732-751`、`TryParseLLMJson:682/:686`）：LLM 失败时降级为规则结果，但把 LLM 的 `ErrorCode/ErrorMessage/RawResponse` 附到 `Source = 'rule_fallback'` 的结果上（`:742-746`），而规则结果可能是 `icsReady` → 出现"已就绪 + 带错误码"的自相矛盾输出；`TryParseLLMJson` 中途 `Exit(False)` 时 `AResult` 已写入部分槽位（解析一半的脏数据可被调用者误用）。建议：失败分支统一 `Result := Default(...)` 后重新赋规则结果；out 参数只在成功路径写入。
- 🔵 **MAIN-08 重复轮子（SSOT）**：本单元的 `JsonString/JsonBool/JsonFloat/FirstText/CopySlots/TrimOptions` 与 `Types.pas` 的 `JsonInt/JsonFloat`、`Config.Upload` 的 `JsonString` 至少**三套并行实现**（语义细节还不一样，如 `JsonBool:214-215` 额外接受 `'yes'`）；`:159-181` 的 `NormalizeJsonObjectText`（处理 ```json 围栏）正确，**但 L2/L3 的 `ParseScaffolds`/`ParseOptions` 完全不处理围栏**（同库两套行为）；`:547` 英文兜底串 `'Please clarify ' + EffectiveName + '.'` 与全模块中文文案混用。
- **本单元未发现问题的维度**：**内存与生命周期**（无自定义容器、无 `Move` 滥用，`LRoot.Free` 在 `finally` ✓，`TIntentClarifier` 非接口类由外部 `Free`、`Policy` record 值语义 ✓）；**线程安全**：`Policy`/`LLM` 属性为 public write 无锁（跳线程共用一实例时有竞态，但主单元无并发生产路径），未单独计数。

#### 意图澄清章未发现问题之维度（全模块汇总）

- **内存与生命周期（除已列条目）**：未发现"含 string record 的 `Move` 滥用"（本轮该模式仅在 `CloudBackup` CB-01 出现）；L0~L4 均 `TInterfacedObject`，容器全部在 `Destroy` 中配对释放，未发现 double-free/UAF（L2 `Destroy:83-91` 在锁内释放容器、锁自身在锁外释放 ✓）。
- **正确性（状态机本体）**：`SessionFSM.pas` 的迁移表本身（可达边集合）与 `IsValidTransition` 一致，未发现非法边放行（除 SM-02 的序数耦合风险）。

### 3.21 横向 / 系统性发现

#### 🔴 X-01 全仓 find/replace 事故污染：`history` → `hiDeepStory`

- 典型功能级证据：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Updater.pas:2230`

```pascal
  Url := Url + 'hiDeepStory';
```

  另见 `d:\_Progs\02Business\DeepBase\Tools\CLI\CLI.DB.pas:93,102`（表名 `ub_llm_hiDeepStory`）、`d:\_Progs\02Business\DeepBase\Tests\Test.DeepBase.CLI.Interactive.pas:763`（命令名）。全仓 grep 命中数十处（多数在注释，少量在字符串常量/标识符）。
- **问题说明**：一次误操作的全局替换把英文单词 `history` 替换成 `hiDeepStory`，且**未被 review/测试拦下**。 updater 的 URL 路径与 DB 表名属于**对外契约**，改名即 404 / 表不存在。
- **触发条件**：请求更新检查接口；访问该 DB 表。
- **后果**：功能直接坏（更新检查失败）；若服务端同步改名则历史数据链路断裂。
- **建议修复**：全仓精确回滚 `hiDeepStory`→`history`（区分标识符边界，避免误改真实品牌词）；为 CLI 表名/HTTP 路径补契约测试；在 CI 加"可疑全局替换"检查（同词大量出现在非代码区即告警）。

#### 🔴 X-02 编码契约已断裂且源码已发生不可逆损坏（本轮脚本实测，修正早期初判）

> 修正说明：本轮早期阶段曾根据"很多文件无 BOM"初步定为 🔴，后根据"多数单元实际无中文字面量"下调 🟡；本条为**最终实测结论**（逐字节检测），重新上调 🔴，因为取证发现的不是"风险"而是**已提交的源码损坏**。

取证（本轮脚本，非推断）：

1. 审计范围 50 个单元（`Features\**\*.pas` 共 131 个）；其中"无 BOM 且含非 ASCII 字符串字面量"的 11 个文件，本组占 10 个：`DeepBase.AntiTamper.pas`（17 条）、`IntentClarification.SignalDetector`（34）、`Provider.L4`（29）、`Exit`（17）、`Anticipation`（14）、`Provider.L3`（10）、`Degradation`（8）、`OptionFrame`（5）、`Provider.L0`（3）、`Provider.L2`（2）（+组外 `Browser.ResponseWaiter.pas`）。**其余 38 个本组单元无此问题**（如 CloudBackup/CloudSync/HttpServer/Net/Graph 非 ASCII 字面量 = 0）。
2. 构建机码页实测：`HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage\ACP = 936`（GBK），`ANSICodePage = 936`。dcc32/dcc64 对无 BOM、无 `{$CODEPAGE}` 的源文件按系统 ANSI 码页解释 → 上述 10 个单元的中文字面量**在本机编译即产出乱码，且无编译告警**。
3. **已发生的不可逆损坏**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.AntiTamper.pas` 含 12 个 U+FFFD（Unicode 替换字符），其中 **3 处在字符串字面量内**。`:281` 字面量的真实码点序列为：

```
39 '  20351 使  29992 用  AES-256  21152 加  23494 密  65292 ，  25968 数  25454 据  38271 超
65533 <U+FFFD>  63 ?  32  37 %  100 d  32  bytes  39 '
```

  即原意大概为"数据超长/超长 %d bytes"，中间汉字已被替换字符 + `?` 永久取代，**原文不可恢复**（安全防御模块的用户告警文案）。
4. 注释级损坏（不影响产物，但文档/可维护性已损毁）：`DeepBase.CloudBackup.pas` **807** 处 U+FFFD、`DeepBase.CloudSync.pas` **851** 处 U+FFFD（均在文件头与注释，字面量 0 命中）。
5. 全仓横向（Features/Core/Persistence/Platform/VCL/FMX/Governance/Tools）：**36 个 .pas 含 U+FFFD**，其中 `FMX\DeepBase.FMX.LLMChatFrame.pas:223` 的 `FLabelStatus.Text := '<U+FFFD>...'` 已是用户可见乱码；另有多个文件**不是合法 UTF-8**（严格解码在 `[E2][80]`/`[E5][8C]`/`[A1]` 等字节序列失败）。→ 同一仓库内"UTF-8+BOM / UTF-8 无BOM / GBK / 已损坏"四类混杂，无 `.gitattributes`、无构建期校验。
- **触发条件**：任何读取这些文案的路径（AntiTamper 安全弹窗、IntentClarification 五层用户提示语）；任何用 PowerShell 5.1 `Set-Content`/`Out-File` 默认编码回写 .pas 的加工程序。
- **后果**：① 安全告警文案不可读（用户看到乱码弹窗）；② 新代码在标准构建配置下必然产出乱码 UI；③ "文件被 lossy 解码后回写"证明工具链存在可摧毁任意源文件的环节（与 🔴 X-01 的全局替换事故同源）。
- **建议修复**：(1) 用历史版本恢复被 U+FFFD 污染的字面量，并定位首个污染 commit（`git log -S`）；(2) 全源文件统一 UTF-8 BOM（或统一 `{$CODEPAGE UTF8}`）+ `.editorconfig`/`.gitattributes` 固化；(3) CI 前置扫描：发现 U+FFFD / 非法 UTF-8 / 无 BOM 且含非 ASCII 即 fail build；(4) 禁止无编码参数的"读文本→写文本"脚本回写源码（写入 `CLAUDE.md`/工具链约束）。

#### 🟡 X-03 `InsecureDevMode` 类旁路缺乏编译/发布门禁约束

- 取证：更新链路存在开发模式旁路（`DeepBase.Updater.pas` 内相关分支）。结合 AU-01/U-02 造成的"合法签名恒失败"，现实中极易被误开成常开。
- **建议修复**：Release 配置下用编译期常量使旁路不可达（`{$IFDEF RELEASE}` 直接 False 且不可被运行时配置打开），并在启动时把旁路状态写入安全审计日志。

#### 🔵 X-04 "规范化 JSON + SHA256 + 重试退避"内核三套并行，未下沉

- 取证：`DeepBase.Config.Upload.pas`（CanonicalJson/SameDoubleBits + 重试退避）、`DeepBase.CloudSync.pas`（JCS 风格规范化 + 乐观并发）、`DeepBase.CloudBackup.pas`（清单哈希 + 上传重试）各自实现一份，无共同内核；三套的浮点规范化策略还互不一致（CU-01 vs CS-08）。
- **后果**：同一份配置在不同模块得到不同哈希 → "内容未变"判定漂移（假冲突 / 假无冲突）；修一处遗漏两处。
- **建议修复**：下沉为 `Core\DeepBase.CanonicalJson.pas`（严格 RFC 8785）+ `Core\DeepBase.RetryPolicy.pas`（单调时钟、全抖动退避、可取消），三单均改为调用；补一组"三套实现 vs 内核"的交叉回归用例。

#### 🟡 X-05 locale 相关浮点解析/格式化家族（至少 6 处）

- 取证（均已在各单元章节定位行号）：CU-01（未初始化 `TFormatSettings` 即使用 = **未定义行为**）、CS-08、`Graph.pas:301`（`Format('%.2f')`）、`Templates.pas:152`（TPL-03）、主单元 `DeepBase.IntentClarification.pas:229`（`JsonFloat` 用 `StrToFloatDef`）、`SignalDetector` 的 `Format('%.2f', ...)`（SD-04）；另 `OptionFrame.pas:151` 的 `TryStrToInt`。
- **问题说明**：这些位置都假定"点号小数点"，而 `Format`/`StrToFloat*` 默认使用线程 locale。在 ACP=936 的中文机器上小数点恰为 `.` 所以下发不爆；但在德语/法语 locale（逗号小数点）上：`'0.7'` 解析失败静默取默认值（TPL-02 叠加后表现为"配置项被丢弃"），而 `FloatToStr(0.7)` 会输出 `'0,7'` 写进 JSON/哈希。
- **建议修复**：库内统一使用全局 `CInvariantFmt: TFormatSettings`（构造时从 `LocaleName='0000-00-00'` 取）；加一条 lint：禁止 `Format`/`StrToFloat`/`FloatToStr` 不带 `TFormatSettings` 参数。

#### 🟡 X-06 `DateToISO8601` / `ISO8601ToDate` 往返不对称（时区漂移）

- 取证：`CloudBackup.pas:571`/`:642`/`:580`/`:670`（写入用 `DateToISO8601(x)`，默认 `DateIsUTC=True`；读出用 `ISO8601ToDate(x)` 默认 `False`）；同模式见 `CloudSync` 与 `Config.Upload` 的时间戳字段。
- **问题说明**：写出的串带 `Z` 后缀（把本地时间当 UTC），读回时按本地时区解释 → **每次往返漂移一个时区偏移**（UTC+8 机器上 8 小时）。备份/同步清单里的 `CreatedAt` 越存越早/越晚，排序与"保留最近 N 份"策略因此误删。
- **建议修复**：统一 `DateToISO8601(x, True)` + `ISO8601ToDate(x, True)` 成对使用，或封装 `TDeepBaseTimestamp.ToJson/FromJson` 单一入口（SSOT）；补一个"写入→读出→相等"的 round-trip 断言测试。

#### 🟡 X-07 挂钟依赖家族（时钟回拨/夏令时使时间门失效）

- 取证：TG-01/TG-03（TimeGuard 本身）、LC-02/LC-03（许可时钟回拨）、BDG-01（`Budget.pas:57` `MilliSecondsBetween(Now, AStartTime)`）、SM-05（`Session.pas:326`/`:420` 空闲超时）、LR-04（`LLMResilience.pas:206`/`:240` 熔断冷却）；另有 `Anticipation.AnalyzeTemporal` 与 `Rapport.LoadProfile`（`LastUpdated := Now`）。
- **问题说明**：所有"预算/超时/冷却/过期"判定共用同一个易被篡改、可回拨的时间源，且**全部库内已有的单调时钟能力（TimeGuard）未被复用**；CloudBackup/CloudSync 的环境变量旁路（NET-04）+ 时钟旁路组合后，任何本地权限用户可同时关断"防篡改、时间信任、预算上限"三道门。
- **建议修复**：引入单一单调时钟抽象（`GetTickCount64`/`TStopwatch`）用于一切"流逝时间"；只有"绝对时刻"才用挂钟，且必须经 TimeGuard 校正；对负值差一律 `Max(0, ...)` + 记安全日志。

#### 🔵 X-08 用户可见文案硬编码、中英混用、无 Locale 层

- 取证（本组）：L0（'请问您想做什么？'）、L2（'您的真实需求是…'）、L3（'通用顾问'/的建议：'）、L4（'（该专家暂时无法提供观点）'）、OptionFrame（'继续'/'第 %d 轮'）、Exit（'会话 %s 已暂停…'）、Degradation（'L0(已是最低级别)'）为中文；Moments（'Understood - you want to %s.'）、主单元（'Please clarify %s.'）为英文；`SignalDetector` 词表仅中文（SD-01）。
- **问题说明**：同一次会话内 UI 语言混杂；L4-03 更把中文字面量当控制流哨兵（改文案即失效）；`Locale` 字段在请求 record 里存在（主单元 `Request.Locale:52`）但除拼进 prompt 外无任何消费者。
- **建议修复**：文案入资源表（`.resx`/`TResourceString`）并按 `Locale` 解析；控制流标志位彻底离开文案（L4-03）；关键词表可注入（SD-01/03）。

#### 🟡 X-09 "声明与实现脱节"家族（文档/接口承诺无对应代码）

- 取证（本组 12 个独立爆发点）：FC-01（`Reload` 全为注释）、MET-02（"Integrates with DeepBase.Metrics" 但 uses 里没有）、TPL-01（"Replaces manual if-checks" 未替换）、ENG-03（`Template` 只写日志）、REG-02（`ApplyPreset` 不应用）、MAIN-01（`CreateEngineWithPreset` 忽略参数）、Rapport `:17`（"SQLite 持久化在 Task 17.2" 未实现）、Anticipation（反馈闭环无读取方）、L2-04（注释说"提取问题"实际写常量）、INF-01（`HAS_ONNX` 死分支调不存在的方法）、LC-06（"离线可用"依赖签名库但未接）、U-13（进度回调缺失）。
- **问题说明**：对使用方而言，这些是"看起来已实现"的安全/成本/可观测性门；与实际不可达的代码（IntentClarification 全模块零接线）叠加，形成"已声明、已单测、未接线、部分假实现"的系统性信任风险。
- **建议修复**：建立"文档承诺 → 代码锚点 → 测试"三对齐清单（可作为工单验收标准）；对空实现统一改为 `raise ENotImplemented`（而非默默返回默认值）；CI 参加"注释式实现检测"（方法体全为注释/`Result := Default` 即告警）。

## 四、🔴 Top10（按爆炸半径排序，优先修复）

| # | 编号 | 位置 | 一句话后果 |
|---|---|---|---|
| 1 | U-03 + U-04 + AU-01 | `Updater.pas:1275-1293`/`:1831-1846`、`AutoUpdate.pas` | 更新包签名验证链 fail-open（算法元数据远程可控、两条路径输入不一致、缺字段=不校验）→ **恶意包可被当合法包安装（RCE 级）** |
| 2 | CB-02（§3.17 CloudBackup） | `CloudBackup.pas`（`ABackupId` 拼接处） | 备份 ID 无路径规范化校验 → **路径遍历，备份 API 成为任意文件读/写/删原语** |
| 3 | CB-04（§3.17） | `CloudBackup.pas`（`VerifyBackup` 与其调用点） | 校验函数恒失败且恢复流程从不调用 → **损坏/被篡改的备份可直接覆盖生产库** |
| 4 | CS-02 | `CloudSync.pas`（上传失败分支） | 上传失败仍上报"同步成功" → 用户以为有云副本，**静默丢数据** |
| 5 | CB-05 + CB-06 + CB-07（§3.17） | `CloudBackup.pas`（`CleanupOldVersions`/差量分支/恢复循环） | 版本清理破坏增量链（含负数死循环）、差量与增量同代码且恢复不回放链、`fctDeleted` 墓被忽略 → **恢复结果错乱 + 已删数据复活** |
| 6 | NET-02 + NET-05 | `Net.pas`（SSRF 校验） | 非规范 IP（`127.1`/八进制/`::ffff:127.0.0.1`）与 DNS rebinding 绕过 → **内网/云元数据端点可达** |
| 7 | NET-04 | `Net.pas`（安全开关） | 安全门可被环境变量全局关闭（无告警、子进程继承）→ **一次注入即永久旁路** |
| 8 | HS-01 + HS-02 | `HttpServer.pas:1358-1375`、`:1143-1203` | `Listen(AHost)` 丢弃绑定地址（局域网暴露）+ 运行期热注册与 worker 无锁并发 → **未鉴权管理面 + 崩溃** |
| 9 | CB-01（§3.17；含 CS-03/CS-04） | `CloudBackup.pas` `Move(AHeaders[0],…)`、`CloudSync.pas` 字典 owns 值 | 含 string 的托管记录用 `Move` 批量拷贝/所有权双向分裂 → **double-free / 悬垂指针（F1.9.1、F1.10.1-3 均未修）** |
| 10 | LR-01 | `IntentClarification.LLMResilience.pas:328`、`:451` | 超时时 `LCtx := nil` 与 Delphi 闭包按引用捕获语义相反 → **后台线程写 `[nil+offset]` AV + 超时后重试风暴（并发重复计费）** |

> 其余 45 项 🔴 不在此表（完整列表见第三章）；其中从"未接线"降级为 🟡 的项目（如 IntentClarification 多数）在接线时必须重新评估为 🔴。

## 五、历史缺陷复核（基线：`CodeReview\20260825-Features.md`，F1 批 18 单元 11🔴/46🟡/38🔵）

### 5.1 F1 批 🔴 逐条复核：全部仍在，未修复

| 历史编号 | 本轮取证（当前代码） | 状态 |
|---|---|---|
| F1.1.1~F1.1.7（AntiTamper） | AT-01（fail-open）、AT-02（`Halt(1)` 于调用线程）、AT-03（KDF 参数不一致）、AT-04（无 `try/finally`）、AT-05（`ReseedMinimal` 零长模板）、AT-06（`EnableHMAC=False` 一键取消）、AT-07（hex 非常数时间比较） | ✗ 全部未修 |
| F1.3.1（Unlock） | UK-01（`ApplyCode` 无状校验与文档不符） | ✗ 未修 |
| F1.4.1、F1.4.2（AutoUpdate） | AU-04（`as TJSONObject` 无 `is` 保护）、AU-02（SHA 失败备份未删） | ✗ 未修 |
| F1.5.1~F1.5.7（Updater） | U-01（`'*.*'` 备份为空操作）、U-02（两路径输入不一致）、U-03、U-04、U-06（`FSilentInstallTask` 从未赋值）、U-10、U-11、U-12 | ✗ 全部未修 |
| F1.6.1~F1.6.6（ClipboardGuard） | §3.5 的 CB-01~CB-07（`GlobalAlloc`/`SetClipboardData`/`GlobalLock`/`SendInput` 返回值全未查；手写 `_AddRef/_Release` 非原子） | ✗ 全部未修 |
| F1.7.1~F1.7.3（TimeGuard） | TG-01（GMT 秒不折时区）、TG-02（未 Verify 即放行）、TG-03（旧 `FServerTimeOffset`） | ✗ 全部未修 |
| F1.8.1~F1.8.7（WindowMonitor） | WM-01~WM-07（ANSI API 误用 `PChar`、`WaitFor` 返回值、进程回调从不触发、`ExpectedPath` 未校验、`FActiveInstance` 竞态、字典无锁、去重缺失） | ✗ 全部未修 |
| F1.9.1~F1.9.3（CloudBackup） | §3.17 的 CB-01（`Move` 滥用仍在）、CB-03（`LoadVersions` nil 强转）、CB-09~CB-13（`LData[0]` 越界类） | ✗ 未修，且本轮新增 6 个 🔴（CB-02/04/05/06/07/08） |
| F1.10.1~F1.10.5（CloudSync） | CS-03/CS-04（远端列表所有权）、CS-10~CS-12（`FreeOnTerminate` + `WaitFor`）、CS-06（重试 off-by-one）、CS-05（`amsMergeByIndex` 被实现为移到末尾） | ✗ 全部未修 |
| F1.11.1（Config.Upload） | CU-01（未初始化 `TFormatSettings`） | ✗ 未修 |
| F1.13.1~F1.13.5（Graph） | GRAPH-10（`ReDeepMoveChild`）、GRAPH-01（`RemoveNode` 不清 `FWeights`）、GRAPH-02（`GetNeighbors` 外泄内部列表）、GRAPH-03/04/05（算法无上限/环误判）、GRAPH-11（`UpdatePriority` 双 Heapify） | ✗ 全部未修 |
| F1.14.1~F1.14.3（HttpServer） | HS-05（0 字节 `BodyBytesContent[0]`）、HS-04（限额看客户端自报 `ContentLength`）、HS-09（CORS 默认宽） | ✗ 全部未修 |
| F1.16.1（Net） | NET-01（`THttpResponse` record 携 `TDictionary` + `Free`，异常路径 Headers 泄漏与二次释放） | ✗ 未修 |

> 原因交叉验证：`git log -1 --format=%ai` 显示本组文件最后提交均早于 2026-08-25（见 1.3 节）；修复工单未覆盖 Features。因此本节按用户约定：**确认已修复的才不计入总数，本轮 🔴 全量为当前代码重新取证的新计项**。

### 5.2 代码内自建工单（IC-0xx）复核：以下 5 项确认已修复，不重复计数

| 工单号 | 位置 | 当前取证 | 结论 |
|---|---|---|---|
| IC-004 | `IntentClarification.Session.pas:412-443` | `SuspendIdleSessions` 改为两段式加锁（快照 key 数组 → 锁外判定 → 回锁变更） | ✅ 已修 |
| IC-008 / IC-009 | `Provider.L2.pas:32/:150-162/:288-308`、`Provider.L3.pas` 全部 `FSessionExperts` 访问点 | per-session 字典 + `FLock` 已覆盖读写两端（仅余 L3 `SelectExpert` 的跨临界区 TOCTOU，已单列为 L3-01） | ✅ 主体已修 |
| IC-019 | `SignalDetector.pas:48-66` | `CountToken` 已改 `PosEx` 递进定位，无 O(n²) `Copy` | ✅ 已修 |
| IC-015 / IC-016 | `Templates.pas:119-156` | 枚举越界与未知字段名已改为 raise（但数值/布尔分支仍静默，已单列为 TPL-02） | ⚠ 部分修复 |
| CloudBackup 目标路径安全 | `CloudBackup.pas` `BuildSafeDestination` | 恢复目标路径已做规范化/前缀校验；但**同一类校验未应用于 `ABackupId`**（CB-02） | ⚠ 半边修复 |

## 六、存疑区（❓ 6 项，需运行期/外部信息才判定）

| # | 存疑项 | 涉及位置 | 需什么证据才能定论 |
|---|---|---|---|
| ❓1 | Indy 静态文件服务是否存"双重解码"从而绕过前缀校验（`TIdHTTPServer` 对 `%252e%252e/` 的处理） | `HttpServer.pas` 静态文件分支 | 实跑一个本地实例 + `curl --path-as-is` 发 8 组编码变体，比对落盘读取路径 |
| ❓2 | `TStreamReader.Create(stream, TEncoding.UTF8, True)` 第三参是否 `AOwnsEncoding`（若是则与后续 `TEncoding.UTF8` 全局实例的释放无关；若否可能存在重复 Free） | `Net.pas` / `Net.Transport.pas` 流读取处 | 查本机 RTL 源码 `System.Classes` 重载声明（或跑 FastMM 全堆校验） |
| ❓3 | `PWideChar`/`AllocatedStringPtr` 取回后是否需显式 `OleStrFree`/`StrDispose`（COM 调用约定下的所有权） | `Unlock.pas`/`AntiTamper.pas` 的 COM/Crypto API 包装 | 看具体 API 文档归属方；可用 FastMM `FullDebugMode` 跑 1000 次循环看堆增长 |
| ❓4 | `HAS_ONNX` 死分支内的代码是否能编译（INF-01 列出的 `ExtractModelInfo`/`AttachProviderDML`/`AllocSession` 均全仓不存在，但可能存在于未入库的 onnxruntime 绑定包） | `Inference.Runtime.pas` | 定义 `HAS_ONNX` 实编译一次；或确认该包版本/来源 |
| ❓5 | `fmShareDenyWrite` 与运行中 SQLite 活库是否真冲突（取现在时/连接池配置下是否必然失败） | `CloudBackup.pas` 在线备份分支 | 在实库上跑一次备份；比对 `PRAGMA journal_mode` 与连接串共享标志 |
| ❓6 | X-02 的乱码是否已体现在**已发布产物**（若历史 BPL 是在 ACP=65001 的 CI 机上构建则未发生） | `AntiTamper`/IC providers 文案 | 用资源/字符串表工具 dump 已发布的 BPL/DLL，比对是否含 GBK 误解码序列 |

## 七、总体结论与修复顺序建议

1. **本组不具备"安全模块"可信度**：更新验签（U-03/U-04/AU-01）、防篡改（AT-01/AT-06）、HTTP 服务绑与鉴权（HS-01/HS-02/HS-06）、网络 SSRF 与全局旁路（NET-02/04/05）四类"门"均为 fail-open 或可被一个参数/一个环境变量关断。建议先修 Top10 的 1~8 项，再动其余。
2. **数据完整性风险集中在云备份/同步**：`manifest` 双 SSOT、增量链破坏、墓被忽略、失败上报成功、数组按索引合并语义错误 —— 五者叠加后，"有备份"不代表"能恢复"。建议在修代码前先做一次**离线全链回放实验**（取真实备份集恢复到临时库并比对 checksum）。
3. **IntentClarification 应作为"未发布代码"对待**：34 个单元、约 7,900 行、零生产消费者（仅 `Persistence\DeepBase.IntentClarification.Storage.pas` 引用其类型）；内部已积 10 🔴 / 88 🟡。接线前必须先清 ENG-01/ENG-02/ICT-01/IOC-IC-01/LR-01/MAIN-01 六项，否则一接即爆。
4. **工程侧根因**：X-01（全局替换事故）、X-02（编码回写事故）、X-09（声明与实现脱节）三件都不是单点 bug，而是**无 CI 门禁、无契约测试、无编码/文本处理约束**的必然后果。建议先上三条门禁（U+FFFD/非法 UTF-8 扫描、无 BOM 检测、方法体全注释检测 + `ENotImplemented`），再逐个修代码，否则修完还会坏。

