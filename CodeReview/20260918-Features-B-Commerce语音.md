# DeepBase Features-B 深度代码审计报告：Commerce 商业化 + Speech 语音

## 元信息

- **审计对象**：`d:\_Progs\02Business\DeepBase\Features\` 下 Commerce 组 14 个单元 + Speech 组 26 个单元（共 40 个 `.pas`）
- **审计日期**：2026-09-18
- **审计方法**：只读静态精读。逐单元通读全文；支付链路（金额类型/最小单位换算/幂等/签名/发放/消费）与音频缓冲区（PCM 采集/环形缓冲/DSP 特征提取）逐行核对；对含 managed 类型的 `Move`、COM 引用计数、锁边界、异常吞咽做定向排查。严重度分级：🔴 崩溃/数据损坏/安全/资金错乱；🟡 功能缺陷；🔵 优化建议；无法确证入「存疑区」。
- **约束**：全程未修改任何源码。
- **说明**：行号基于审计当日源码，若文件后续变更请以函数名定位。

## 总体统计表

| 分组 | 单元数 | 🔴 | 🟡 | 🔵 | 存疑 |
|------|-------|----|----|----|------|
| Commerce（14） | 14 | 7 | 8 | 4 | 2 |
| Speech（26） | 26 | 2 | 14 | 6 | 1 |
| **合计** | **40** | **9** | **22** | **10** | **3** |

> 注：跨单元重复的同类缺陷（如两适配器的 ParseOrder/ParseEntitlement 字段缺失、货币换算两处）合并计数但分别列出文件行号。

---

# 第一部分：Commerce 商业化子系统

## DeepBase.Commerce.Types.pas（514 行）

数据契约核心。金额一律以 `AmountMinor: Int64` 最小货币单位存储（正确做法，避免浮点）。`TCommerceEntitlementData`（167-182）定义 `Tier / MaxDevices / OfflineGraceDays / LastValidatedISO` 等治理字段——这些字段是下文两适配器 `ParseEntitlement` 漏读的受害者。

- **未发现本单元内 bug**。record 默认零初始化对 enum 意味着「首成员」，这是隐式契约依赖，风险在消费端（见 JsonUtil / 适配器）。
- 架构 🔵：`AmountMinor + Currency` 遍布 5 个 record（Order/Product/Payment/...），换算规则却散落在 SDKGateway/PaymentBridge，缺一个类型内聚的 `TMoney` 值对象承载换算（见下 SSOT 问题）。

## DeepBase.Commerce.JsonUtil.pas（512 行）

### 🔴 C-01　`OrderStatusFromString` 未知字符串回退为 `cosRefunded`
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Commerce.JsonUtil.pas:245-259`
```pascal
function OrderStatusFromString(const AValue: string): TCommerceOrderStatus;
begin
  if SameText(AValue, 'created') then Result := cosCreated
  ...
  else if SameText(AValue, 'failed') then Result := cosFailed
  else
    Result := cosRefunded;   // ← 任意无法识别值（含 ''、新状态、脏数据）都判为"已退款"
end;
```
- **问题**：`TCommerceOrderStatus`（Types.pas:27）中 `cosRefunded` 是终态且触发退款副作用。任何上游新增状态、大小写/空格差异、字段缺失导致 `AValue=''`、或 JSON 解析降级——都被静默映射为「已退款」。
- **触发条件**：`Service.pas:210` `if Result.Status in [cosPaid, cosClosed, cosRefunded]` 将 cosRefunded 当作「已终结、可关闭支付/回收权益」处理；一条尚未支付（status 字段临时缺失）的订单会被误判已退款并终结，或直接触发权益回收 → 用户已付款却被撤权，或对未付款订单发起退款。
- **建议修复**：`cosRefunded` 必须显式匹配 `'refunded'`；未知/空值应回退到 `cosCreated`（安全默认）或引入 `cosUnknown` 并要求调用方显式处理，绝不默认落入带资金副作用的终态。

## DeepBase.Commerce.Adapter.Supabase.pas（788 行）

### 🔴 C-02　`ParseOrder` 漏读 `Status` 字段，订单状态读取即丢失
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Commerce.Adapter.Supabase.pas:311-323`
```pascal
function TSupabaseCommerceStorage.ParseOrder(Obj: TJSONObject): TCommerceOrderData;
begin
  ...
  Result.AmountMinor := Int64Val(Obj, 'amount_minor');
  Result.Currency := Str(Obj, 'currency');
  Result.CreatedAtISO := Str(Obj, 'created_at');
  Result.PaidAtISO := Str(Obj, 'paid_at');
  // ← 无 Result.Status := ...；而序列化端 OrderToRow 写入 status
end;
```
- **问题**：写路径 `OrderToRow`（约 :393）序列化 `amount_minor`；`Service` 层依赖 `Order.Status` 判终态，但读回时 `Status` 从未赋值，record 零初始化 → 恒为 `cosCreated`（首成员）。
- **触发条件**：任何从 Supabase 读回的订单，状态被抹平为「已创建」。重复支付守卫、幂等判定、发放触发全部基于错误的 `cosCreated`。
- **建议修复**：补 `Result.Status := OrderStatusFromString(Str(Obj, 'status'));`，并与 `OrderToRow` 字段清单做双向一致性测试。

### 🔴 C-03　`ParseEntitlement` 漏读 `Tier/MaxDevices/OfflineGraceDays/LastValidatedISO`
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Commerce.Adapter.Supabase.pas:356-368`（对照 Types.pas:178-181 的字段定义）
- **问题**：只读到 `SourceOrderId`（:367）即结束；四个治理字段全部丢失。`ParseProduct`（:339-354）却读了 `Tier/MaxDevices/OfflineGraceDays`，说明是 ParseEntitlement 遗漏。
- **触发条件**：读回权益后 `Tier=''`、`MaxDevices=0`、`OfflineGraceDays=0` → 设备数限制失效、离线宽限期归零（联网校验抖动即误判过期）、按 Tier 的分级鉴权错乱。
- **建议修复**：补齐四字段的反序列化；写入端（`EntitlementToRow`）也需确认已持久化对应列。

### 🔴 C-04　`ConsumeEntitlement` 假阳性成功 → 并发双花
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Commerce.Adapter.Supabase.pas:722-786`
```pascal
  LFilter := 'entitlement_id=eq.' + ... +
    '&remaining_quota=eq.' + IntToStr(AEntitlement.RemainingQuota); // 乐观并发条件
  Body.AddPair('remaining_quota', TJSONNumber.Create(NewQuota));
  SupabasePatch(BuildUrl(TableName('entitlements'), LFilter), Body); // ← 返回值/影响行数未检查
  ...
  Obj := SupabaseGet(...);           // 再读
  if Assigned(Obj) then ... ParseEntitlement(Obj);
  Result := True;                     // ← 无条件为 True（:772）
```
- **问题**：条件 PATCH（带 `remaining_quota=eq.<old>` 过滤）在冲突时影响 0 行（被并发消费者抢先扣减），但 `SupabasePatch` 的返回与「实际更新行数」均未校验；`Result := True` 在 :772 无条件执行。若 :764 的确认 GET 失败（`Obj=nil`），`AEntitlement` 仍保留 :736 的首次读取旧值，本调用也照样返回 True。
- **触发条件**：两个并发消费同一权益，条件更新一个成功一个匹配 0 行；失败方仍被告知「消费成功」，实际未扣减 → 少扣/双花；配额账实不符。
- **建议修复**：读取 PostgREST 响应头 `Content-Range` 或要求 `Prefer: return=representation` 并校验返回行；若影响行数为 0 视为 CAS 失败，重读重试或返回 False。绝不无条件 `Result := True`。确认 GET 失败时必须返回 False。

### 🟡 C-05　GET 网络失败与「记录不存在」不可区分
- **位置**：`ConsumeEntitlement` :733 `if not Assigned(Obj) then Exit(False)`；`SupabaseGet`/`SupabasePatch` 内部吞异常返回 nil。
- **问题**：网络中断、5xx、404 都坍缩为 `nil`/`False`。消费扣减的 PATCH 若因网络失败，调用方收到 False 会向上重试——但扣减可能已在服务端成功，导致「客户端认为失败、服务端已扣」的漏单/重复消费。
- **建议修复**：区分「确定未发生」与「结果未知」两类；后者需依赖幂等键（见 Idempotency）而非直接返回 False。

### 架构 🔵 C-06　与 Firebase 适配器契约分裂（SSOT 缺失）
- **位置**：`Adapter.Supabase.pas` vs `Adapter.Firebase.pas`
- **问题**：两套几乎同构的 Parse/Serialize/Consume 逻辑各写一遍，且都存在同类字段漏读、语义不一致（Supabase 有乐观条件、Firebase 无）。修一处易漏另一处。
- **建议修复**：抽取共享 DTO 映射层，或让存储层契约由后端 HTTP 单一实现，适配器只做传输。

## DeepBase.Commerce.Adapter.Firebase.pas（935 行）

### 🔴 C-07　`ParseOrder` / `ParseEntitlement` 同样漏字段（与 C-02/C-03 同源）
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Commerce.Adapter.Firebase.pas:367-379`（ParseOrder 无 `Result.Status`）；`:412-424`（ParseEntitlement 止于 `SourceOrderId`，缺 Tier/MaxDevices/OfflineGraceDays/LastValidatedISO）
- **触发条件/后果**：同 C-02/C-03，且 Firestore 写路径确实用 `WrapValue` 持久化了 status（见 :451）——写读不对称，纯数据损坏型缺陷。
- **建议修复**：同 C-02/C-03。

### 🔴（已在源码注明为受限设计）ConsumeEntitlement 非原子读-改-写
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Commerce.Adapter.Firebase.pas:875-933`
```pascal
  // NOTE: Firestore REST API does not support atomic read-modify-write transactions.
  Doc := FirestoreGet(...);            // 读
  AEntitlement := ParseEntitlement(Fields);
  ...
  NewQuota := AEntitlement.RemainingQuota - ACount;   // 改（本地）
  FirestorePatch(...WrapValue(NewQuota));             // 写（无前置条件）
  Result := True;
```
- **问题**：无版本/条件守卫的经典 TOCTOU；两个并发读得同值 → 都写回同一 NewQuota，一次扣减被覆盖 → 双花。源码注释明确承认「仅适合单实例部署」，多实例并发不安全。
- **触发条件**：多实例/多设备并发消费同一 Firestore 权益。
- **建议修复**：如注释建议，走支持服务端事务的后端 HTTP 适配器；若必须客户端直连，改用 Firestore 事务或条件写（ETag/版本字段）。因属「已知且文档化的取舍」，同时列入存疑区（见 Q-2）评估实际部署形态。

## DeepBase.Commerce.Backend.Http.pas（985 行）

后端 HTTP 存储实现（服务端事务可用路径）。
- **正确性/内存/线程/异常/安全**：本组审计范围内**未发现新增 🔴**。它是 C-07 推荐迁移的目标实现。
- 🟡：`ConsumeEntitlement`（:743）应与 Service 层共享幂等键，避免重试二次扣减——需与 Idempotency 单元联看，未见显式 nonce 透传到扣减请求。

## DeepBase.Commerce.Idempotency.pas（245 行）

- **未发现 🔴**。幂等实现是本模块资金安全的关键防线；风险在于上文消费/支付路径是否真正调用它——见下「跨单元」结论。
- 🟡：需确认 `ConsumeEntitlement`/`CreateOrder` 在 SDKGateway/SafeClient 侧强制携带幂等键；当前适配器直连路径（C-04/C-07）似未经过 Idempotency 层，幂等保护被旁路。

## DeepBase.Commerce.SDKGateway.pas（229 行）

### 🔴 C-08　零小数/三小数货币换算不完整且硬编码重复
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Commerce.SDKGateway.pas:72-79`
```pascal
function MinorUnitsToAmount(AMinorUnits: Int64; const ACurrency: string): Currency;
begin
  if SameText(ACurrency, 'JPY') or SameText(ACurrency, 'KRW') then
    Result := AMinorUnits          // 零小数
  else
    Result := AMinorUnits / 100;   // 假设一律两位小数
end;
```
- **问题**：① 零小数货币远不止 JPY/KRW（VND、IDR、CLP、KRW 等；VND/IDR 常以整数元计）被漏 → 显示/对账时缩小 100 倍。② 三位小数货币（BHD、KWD、TND、OMR、UGW 等，1 元 = 1000 最小单位）一律按 /100 → 金额错 10 倍。③ `Currency` 为 Delphi 定点类型，`AMinorUnits/100` 隐式转换尚可，但逻辑错在标度选择。④ 与 PaymentBridge:255-258 的反向换算重复实现（SSOT 违背），两处清单必须手工保持同步，极易漂移。
- **触发条件**：任何非 USD/CNY/EUR 主流两位币种的收单显示与回调金额换算。
- **建议修复**：建立单一 ISO-4217 exponent 查表（含 0/2/3 小数位），换算函数只此一份，SDKGateway 与 PaymentBridge 共用。

## DeepBase.Commerce.PaymentBridge.pas（328 行）

### 🔴/🟡 C-09　回调金额换算反向逻辑同样残缺（与 C-08 成对）
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Commerce.PaymentBridge.pas:255-258`
```pascal
  if SameText(FCurrency, 'JPY') or SameText(FCurrency, 'KRW') then
    Result.AmountMinor := Round(SDKNotif.Amount)
  else
    Result.AmountMinor := Round(SDKNotif.Amount * 100);
```
- **问题**：这是**入站回调**（第三方通知）金额 → AmountMinor 的换算，缺 VND/IDR/CLP 与三位小数货币，且与出站换算分别硬编码。若 `FCurrency` 与实际通知币种不符，或上游用元为单位而本地清单不含该币种 → 落库 AmountMinor 错 10/100 倍，直接污染对账与发放门槛。
- **触发条件**：非两位小数币种的支付回调。
- **建议修复**：统一到共享 exponent 表；回调金额应优先信任 provider 直接给出的最小单位值而非本地 `Amount`（元）反推。
- ✅ 签名校验：`VerifyNotification`（:245）与 PayPal Transmission-Sig（:238-242）失败即抛异常，**未发现问题**（签名链存在）。

## DeepBase.Commerce.Permissions.pas（384 行）

- **未发现 🔴**。权限矩阵单元，逻辑集中。
- 🟡：需确认权益 Tier 鉴权读取的是完整 `TCommerceEntitlementData.Tier`——而 Tier 恰被 C-03/C-07 抹空。链路组合后果：付费 Pro 用户读回 `Tier=''` 可能被降级为 free 权限（数据缺失放大为鉴权错误）。列入跨单元结论。

## DeepBase.Commerce.SafeClient.pas（1250 行）

超 1200 行单体客户端。`ConsumeEntitlement`（:1067）、`Order.Status := OrderStatusFromString(...)`（:260）。
- 🔴（继承）：:260 调用 C-01 的 `OrderStatusFromString`，直连后端返回体若缺 `status` 或含新值 → 误判 cosRefunded。
- 🟡 线程安全：单客户端实例被多线程共享时，内部 token/session 缓存需确认加锁（本单元过大，未逐行证实 → 存疑区 Q-3）。
- 🔵 架构：1250 行远超 2000 行警戒线以下的可维护阈值，建议按「认证/订单/权益/回调」拆分。

## DeepBase.Commerce.Service.pas（456 行）

业务编排。`ConsumeEntitlement`（:431）、支付守卫 `Status in [cosPaid, cosClosed, cosRefunded]`（:210/:229）。
- 🔴（继承）：编排层严重依赖 `Order.Status`，而 Status 在 Supabase/Firebase 读路径被抹（C-02/C-07）→ 「已支付」读回变「已创建」，:210 的终结判定失效，重复支付/重复发放守卫被绕过。
- 异常处理 🟡：`ConsumeEntitlement` 对下层返回 False 的处理需区分「配额不足」与「网络未知」，否则吞掉「结果未知」会造成漏单（与 C-05 联动）。

## DeepBase.Commerce.Storage.pas（385 行）

内存参考实现 `TInMemoryCommerceStorage.ConsumeEntitlement`（:353）。
- 正确性：作为进程内实现，扣减在同一把锁/单线程语义下应无并发问题（内存 map 直改）。**未发现 🔴**。
- 价值：它是「契约应有的正确行为」的参照，反衬两网络适配器的字段丢失与假阳性。

## DeepBase.Commerce.Backend.Contract.pas（177 行）

契约定义单元。**未发现任何维度问题**（纯接口/类型声明）。

## DeepBase.Commerce.UpgradeFlow.pas（168 行）

升级流。`if Result.Order.Status in [cosClosed, cosFailed, cosRefunded]`（:110）。
- 🔴（继承）：同样受 C-02/C-07 影响；当订单读回 Status 恒为 cosCreated 时，:110 的「非成功终态」分支永不进入，失败/退款订单被当作进行中继续升级 → 权益错发。
- **未发现本单元独立 bug**。

---

# 第二部分：Speech 语音子系统

## DeepBase.Speech.ASR.SenseVoice.pas（810 行）

### 🔴 S-01　`ParseCommaList` 对 string 动态数组使用 `Move` → double-free / 悬垂指针
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Speech.ASR.SenseVoice.pas:117-144`
```pascal
  LList: TArray<string>;
  SetLength(LList, Length(AText));
  LList[LCount] := Copy(AText, LStart, LPos - LStart);  // 带引用计数的托管赋值
  SetLength(Result, LCount);                             // Result 元素初始化为 nil
  Move(LList[0], Result[0], LCount * SizeOf(string));    // ← 裸拷字符串指针，未 AddRef
end;   // ← LList 出栈 Finalize：对每个 string 置 nil 并 decr，字符串体被释放
```
- **问题**：`Move` 绕过 Delphi 对 managed 类型（`string`）的引用计数语义。Result 与 LList 指向同一批字符串体但计数未增；函数退出时编译器对局部 `LList` 做 Finalize，释放这些字符串体，Result 立即持悬垂指针。后续读取 Result 元素为 use-after-free，二次释放即 double-free → 堆损坏/随机崩溃。
- **触发条件**：任何调用 `ParseCommaList` 的路径（:298 / :307 解析 token/词表原始串）。属高发且随机崩溃型。
- **建议修复**：直接 `Result := Copy(LList, 0, LCount);` 或逐元素 `Result[i] := LList[i];`（走托管赋值）；彻底移除对 string 数组的 `Move`。

### 🟡 S-02　流式 `FeedAudio` 与 `DoWork` 无锁并发读写 `FBuffer`
- **位置**：`TDeepBaseSenseVoiceStream.FeedAudio`（约 :708-717 向 FBuffer 追加）与 `DoWork`（约 :688-691 `Copy(FBuffer)`），运行在不同线程（采集/投递线程 vs 后台 worker），未见针对 FBuffer 的锁。
- **问题**：动态数组并发 append + Copy 撕裂读；`FBuffer` 扩容 realloc 与另一线程读取竞争 → 读到已释放旧缓冲/半更新数据。
- **触发条件**：流式识别中边喂边解。
- **建议修复**：FBuffer 访问加临界区，或改用带锁环形缓冲。

### 🔵 S-03　每次 partial 全量重解码 FBuffer → O(N²)
- **位置**：`DoWork` 每个 `FIntervalMs` 周期对整段 `FBuffer` 重跑 FBank+LFR+CMVN+推理+CTC。
- **问题**：随会话时长线性增长的缓冲被反复全量解码，累计 O(N²) 计算量，长语音延迟与 CPU 急剧上升。
- **建议修复**：增量特征/滑窗，或消费后裁剪已定稿前缀。

## DeepBase.Speech.ASR.SAPI.pas（566 行）

### 🔴 S-04　流式 `WorkerProc` 空转，从不产出结果；`Stop` 以空文本回调 Success=True
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Speech.ASR.SAPI.pas:501-522`（worker 空循环）；`:489-498`（Stop 收尾）
```pascal
procedure TDeepBaseSAPIASRStream.WorkerProc;
begin
  CoInitializeEx(...);
  try
    while FRunning do
      if WaitForSingleObject(FStopEvent, 100) = WAIT_OBJECT_0 then Break;
      // 注释："results are collected when Stop is called ... M2 refinement"
  finally CoUninitialize; end;
end;
// Stop:
  LFinal.Success := True;
  LFinal.Text := '';            // ← 永远为空
  FOnFinal(LFinal);
```
- **问题**：worker 线程仅 sleep-pump，从不 `GetEvents`/`GetText` 取识别结果；`Stop` 却以 `Success=True, Text=''` 触发最终回调。这是「静默假成功」：调用方收到成功信号但文本恒空。
- **触发条件**：任何使用 SAPI 流式 ASR 路径。
- **建议修复**：实现事件驱动取结果（ISpNotifySource + GetEvents + GetText），或在能力未就绪时明确返回「不支持/失败」而非 Success=True。

### 🟡 S-05　`RecognizeWavFile` COM 事件 wParam 引用泄漏
- **位置**：`ASR.SAPI.pas:349` `LResult := ISpRecoResult(Pointer(LEvent.wParam))`，:360 局部 Release 归零。
- **问题**：把 `wParam` 原始指针赋给接口变量，编译器自动 AddRef；函数尾局部分消耗一次。但事件队列本身为该 ISpRecoResult 持有的那一份额有引用从未 Release → 每来一个识别事件泄漏一个 COM 对象。
- **触发条件**：批量离线 wav 识别，长时间运行内存增长。
- **建议修复**：取出后对事件持有的原始引用显式释放一次，或用 `PUnknown`+接管所有权模式，确保计数平衡。

## DeepBase.Speech.WakeWord.pas（505 行）

### 🟡 S-06　COM 事件 `wParam` 引用泄漏（同 S-05 模式）
- **位置**：`WakeWord.pas:319` 附近 `EventThreadProc` 从 `GetEvents` 取 `wParam` 转接口，未平衡释放事件原始引用。
- **建议修复**：同 S-05。

### 🟡 S-07　`Confidence` 硬编码 1.0，置信度阈值形同虚设
- **位置**：`WakeWord.pas:332-334` `LConfidence := 1.0;`（注释：GetConfidence vtable 未声明）。
- **问题**：因未声明 GetConfidence vtable，直接将置信度写死 1.0。任何「置信度 ≥ 阈值才算命中」的门禁恒为真 → 误唤醒无法被阈值过滤。
- **建议修复**：补 ISpRecoResult.GetConfidence 声明（Decl 单元已有其余 slot 逆向方法）取真实值；未实现前不应谎报 1.0。

### 🟡 S-08　`Stop` 仅等 400ms 即释放 COM 上下文，worker 可能仍用 → UAF
- **位置**：`WakeWord.pas:447` `WaitForSingleObject(LDoneEvent, 400)` 随后置空 FContext 等接口。
- **问题**：400ms 超时后主线程无条件释放 `FContext`；若 worker 仍在 `GetEvents`/处理事件，接口被并发置 nil → 访问已释放 COM 对象。
- **建议修复**：Stop 必须 join worker 线程（协作取消，勿用固定短超时兜底）后再释放。

## DeepBase.Speech.TTS.Edge.pas（515 行）

### 🟡 S-09　`SpeakAsync` 匿名线程捕获 `Self` 无生命周期持有 → 悬垂
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Speech.TTS.Edge.pas:480-494` `TThread.CreateAnonymousThread(procedure ... Self.Speak ... end).Start;`
- **问题**：闭包强捕获 `Self`（对象指针）但不持引用；方法返回后若调用方释放该 TTS 后端对象，后台线程仍在执行 `Self.Speak`、访问 `FLastError`/`FOnDone` → use-after-free。
- **触发条件**：异步播报期间对象被析构（常见于临时后端实例）。
- **建议修复**：以接口引用持有 self 进闭包，或弱引用 + 存活校验；Destroy 等待/取消在途线程。

### 🟡 S-10　请求格式与注释/契约漂移（MP3 vs PCM）
- **位置**：注释 `:65`「returns raw audio bytes (MP3 for Edge)」，实际请求体 `:294` `"outputFormat":"riff-24khz-16bit-mono-pcm"`。
- **问题**：文档称 MP3，实为 24kHz/16bit/mono PCM(WAV)。下游若按 MP3 解码将失败或噪声；采样率假设需与播放/再处理链一致。
- **建议修复**：统一契约与注释，明确输出格式与采样率，播放端按 PCM/WAV 处理。
- ✅ 句柄/内存：Synthesize 的 WinHTTP 句柄在 finally 全部关闭，**未发现泄漏**。

## DeepBase.Speech.TTS.StepFun.pas（532 行）

### 🟡 S-11　`Speak` 拿到音频响应后既不播放也不返回——静默丢弃
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Speech.TTS.StepFun.pas:303-347`
```pascal
  var RespStream := Response.ContentStream;
  if (RespStream = nil) or (RespStream.Size = 0) then
  begin FLastError := 'StepFun TTS: empty response'; Exit; end;
end;   // ← 非空时函数直接结束，RespStream 从未被读取/播放/回调
```
- **问题**：成功响应的音频流被完全忽略（不送扬声器、不落盘、不回调），合成成功也「无声无息」，且同步路径未触发完成通知。
- **触发条件**：任何 StepFun TTS Speak 调用。
- **建议修复**：读取 RespStream → 交给播放器或回调；结束触发完成通知。

### 🟡 S-12　注册缺 `TTSFactory`，`IsAvailableFunc` 恒 True（无 key 也报可用）
- **位置**：`StepFun.pas:524` `Info.IsAvailableFunc := function: Boolean begin Result := True; end;`，且 registration 未设 `Info.TTSFactory`。
- **问题**：可用性探测恒真（不看是否配置 API key），Resolver/Registry 会选它作可用后端却运行期失败；缺工厂则统一创建路径拿不到实例。
- **建议修复**：`IsAvailableFunc` 应检查凭据是否就绪；补 `TTSFactory`。

## DeepBase.Speech.Occupancy.pas（149 行）

### 🟡 S-13　`GetStatus` 每次新建 SpVoice 查询占用 → 恒 idle
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Speech.Occupancy.pas:113-117`
```pascal
  Voice := CreateComObject(CLSID_SpVoice) as ISpVoice;  // 每次调用都新建实例
  Status := Voice.WaitUntilDone(0);                     // 新实例从未 Speak → 恒 idle
```
- **问题**：新建独立 SpVoice 对象的 `WaitUntilDone(0)` 只反映该新实例自身是否在播报（永远否），无法感知别的实例正在播报 → 「占用检测」永远返回空闲，语音避让/仲裁失效。
- **建议修复**：应查询实际负责播报的同一/共享 ISpVoice 实例的 run-state，而非新建探针。

## DeepBase.Speech.Policy.pas（70 行）

### 🟡 S-14　`IsAllowed` 全部硬编码 True，治理/隐私门禁形同虚设
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Speech.Policy.pas:42-56`
```pascal
    Result := True  // Local SAPI, no governance needed for v1
    Result := True  // Local MFCC, but requires explicit user opt-in via config
    Result := True  // Allowed by default; applications can override via governance
```
- **问题**：含 wake-word 常开麦克风、voiceprint 生物特征处理等隐私敏感能力，门禁恒放行，与单元头部「未初始化则 DISABLED」的声明矛盾。`RegisterGates`（:58）为空实现，无实际覆盖点。
- **触发条件**：任何能力调用前的策略检查都被短路。
- **建议修复**：落地真实门表，默认按隐私分级 fail-closed（尤其麦克风常听与声纹），RegisterGates 接入配置/用户授权源。

## DeepBase.Speech.Registry.pas（271 行）

### 🟡 S-15　`Discover` 在 `FLock` 内调用 `IsAvailableFunc`，探针重活阻塞全局锁
- **位置**：`Registry.pas` `Discover`（:58，实现内 `TMonitor.Enter(FLock)` 持锁期间执行 `LInfo.IsAvailableFunc()`）。
- **问题**：类级 `FLock`（class var）串行化整个注册表；可用性功能探针若在锁内做重活（SenseVoice 的探测经 EnsureInitialized 可能加载 ONNX 模型，数秒），会把所有线程的注册/查询全部阻塞。
- **建议修复**：先在锁内快照候选列表，释放锁后再逐个调用 `IsAvailableFunc`；或缓存/异步预热可用性结果。

## DeepBase.Speech.Voiceprint.pas（701 行）

### 🟡 S-16　锁外访问 `FProfileInfos`，宣称线程安全但违约
- **位置**：`d:\_Progs\02Business\DeepBase\Features\DeepBase.Speech.Voiceprint.pas:487`（`PersistToStorage` 内 `FProfileInfos.TryGetValue` 处于临界区外——相邻 Enter/Leave 为 :458/:477）；`Identify`（:131）对档案字典的读取同样在锁外完成。
- **问题**：`FProfileInfos` 为 `TDictionary`，写路径（:465/:562）在锁内。锁外读 + 锁内写 → 查找/枚举期间遭遇并发 rehash，可能读到损坏桶、抛异常或结果错误；与单元「thread-safe」声明冲突。
- **建议修复**：所有对 FProfiles/FProfileInfos 的读写统一在 FLock 内；返回拷贝而非在锁外解引用。
- 🟡 持久化原子性：`TFile.WriteAllBytes` 覆盖整个 DPAPI store 非原子，写一半掉电 → 全量档案丢失。建议临时文件 + 原子替换。
- ✅ 数值/内存：`FramesToBytes/BytesToFrames` 对 `array[0..12] of Single`（非托管）用 Move 合法，**未发现问题**。

## DeepBase.Speech.DTW.pas（112 行）

- **正确性**：Sakoe-Chiba band 约束下的累积距离递推、边界初始化正确。**未发现功能性 🔴**。
- 🔵 S-17　band 外单元置 `1e30` 作「不可达」，当两序列长度差异过大导致最优路径整体落在 band 外时，返回巨大但有限的数（`LCost[N][M]`），调用方无从分辨「不可达」与「高失真」。建议显式返回失败标志或 inf 语义。
- 🔵 性能：DP 矩阵 O(N·M·bandwidth) 属正常，band 限制有效，**未发现 O(N²) 失控**。

## DeepBase.Speech.MFCC.pas（499 行）

- **正确性**：预加重、Radix-2 FFT、功率谱、Mel 三角滤波器组、DCT-II 取 13 系数、delta/delta-delta（`LNorm = 2*Σk² = 10`，k=1..2）实现均正确；PCM16 小端解码 `SmallInt(bytes[i*2] or (bytes[i*2+1] shl 8))` 字节序无误。
- 🔵 性能：`ExtractFrames` 逐帧分配 + 帧循环内 FFT，长音频高频小对象分配；建议复用帧缓冲。
- **未发现 🔴/🟡 功能或内存问题。**

## DeepBase.Speech.FBank.pas（252 行）

- **正确性**：80 维 log-Mel、预加重、加窗、能量取 log，逻辑正确。
- 🔵 S-18　`Radix2FFT` 位反转重排用嵌套 `for I := K to AN-1 do if (I mod M)=K`，是 O(N²) 实现而非标准 O(N log N) 蝶形交换；SenseVoice/流式长语音下成为热点。建议改标准 bit-reversal 置换。
- **未发现 🔴/🟡。**

## DeepBase.Speech.VAD.pas（95 行）

- **正确性**：RMS 能量阈值判决，帧/采样索引边界正确，空输入有守卫。**未发现任何维度问题。**

## DeepBase.Speech.Audio.WinMM.pas（317 行+）

采集层（waveIn）。
- 🟡：`waveInStart`/回调线程与停止路径的缓冲区所有权需确保 `waveInReset`/`waveInClose` 前所有 header 已归还，否则停止时释放仍在 DSP 队列的 HEADER → 悬垂。停止/关闭次序基本正确，未发现确定性 double-free，列入存疑区 Q-1 复核极端时序。
- ✅ 采样率/位深/通道：格式填充为 16kHz/16bit/mono，与下游 FBank/MFCC 假设一致。

## DeepBase.Speech.Config.pas（196 行）

- **未发现 🔴/🟡**。配置装载，缺省值合理。

## DeepBase.Speech.Resolver.pas（132 行）

后端选择。
- 🟡：可用性判定依赖 `IsAvailableFunc`，受 S-12（StepFun 恒真）污染，可能选中不可用后端。属被上游缺陷波及，本单元逻辑本身**无独立 bug**。

## DeepBase.Speech.Runtime.pas（226 行）

状态机。
- 🔵：`DoTransition` 在持锁内回调 `FOnStateChange`，订阅者回调内再入 Runtime 方法 → 自死锁风险。建议锁外触发通知。

## DeepBase.Speech.Service.pas（531 行）

对外服务门面。
- ✅ `[weak] FPermissionClient` 已显式修掉早期 double-free；生命周期处理正确。
- **未发现新增 🔴**。

## DeepBase.Speech.Intent.pas（438 行）

- 🟡：`Parse` 在 `FLock.Enter`（:341）持锁范围内调用 `LRule.SlotExtractor(AText)`（:352）——`TSlotExtractor` 是外部注入的任意委托，可能回调本实例或长时间计算，造成锁内执行不可控代码 / 再入死锁。
- 🔵 S-19：`ExtractJsonString`/`ExtractJsonNumber`（:131-226）手写 JSON 解析，未复用 `System.JSON`（SSOT 违背，转义/嵌套边界易错）。

## DeepBase.Speech.Intent.LLMBackend.pas（129 行）

- **未发现 🔴/🟡**。异常向上抛由 `Parse` 捕获为 llm_unavailable，契约一致。

## DeepBase.Speech.ASR.Baidu.pas（422 行）

- 🟡：access token 缓存的读-判-刷新-写在多线程下若无锁保护，存在并发重复刷新与竞态读写共享 token 字段。建议加锁或原子交换。
- ✅ 音频上传格式/采样率假设与采集端一致。

## DeepBase.Speech.ASR.SAPIAdapter.pas（134 行）

- **未发现新增 🔴/🟡**。薄适配层；其流式能力实际受 S-04（SAPI 流式空实现）波及。

## DeepBase.Speech.TTS.SAPI.pas（222 行）

- **未发现 🔴**。COM 生命周期在 finally 释放；与 Occupancy(S-13) 组合使用需注意共享实例问题。

## DeepBase.Speech.Voiceprint.Contracts.pas（67 行）

纯契约/类型。**未发现任何维度问题。**

## DeepBase.Speech.SAPI.Decl.pas（486 行）

COM vtable 逆向声明。
- **未发现声明错误**：SPEVENT Win64 40 字节布局（eEventId@0/wParam@24/lParam@32）、SPFEI 位、`{$Z4}` 强制 4 字节枚举、GetEvents/GetText/SetDictationState 等 slot 均标注经 System.Speech 反射 + ctypes 探针 VERIFIED。
- 🔵 建议：为 WakeWord S-07 补 `ISpRecoResult.GetConfidence` slot 声明（当前缺失才致置信度写死）。

---

# 🔴 最严重 Top 10（资金错乱 / 数据损坏 / 崩溃优先）

| # | 位置 | 一句话 |
|---|------|--------|
| 1 | SenseVoice.pas:143 | 对 `string` 数组用 `Move` 绕过引用计数 → double-free / 悬垂，随机崩溃 |
| 2 | Supabase.pas:772 | `ConsumeEntitlement` 不校验条件 PATCH 影响行数，`Result:=True` 无条件 → 并发双花 |
| 3 | Firebase.pas:875-933 | 权益消费非原子读-改-写（无版本守卫）→ 多实例 TOCTOU 双花 |
| 4 | SDKGateway.pas:72-79 / PaymentBridge.pas:255-258 | 零/三小数货币换算只列 JPY/KRW 且重复实现 → 金额错 10~100 倍 |
| 5 | JsonUtil.pas:258 | `OrderStatusFromString` 未知/空值默认 `cosRefunded` → 误判退款、误撤权益 |
| 6 | Supabase.pas:311-323 / Firebase.pas:367-379 | `ParseOrder` 漏读 `Status`，读回恒为 cosCreated → 支付/发放守卫被绕过 |
| 7 | Supabase.pas:356-368 / Firebase.pas:412-424 | `ParseEntitlement` 漏读 Tier/MaxDevices/OfflineGraceDays/LastValidatedISO → 分级/设备/离线鉴权错乱 |
| 8 | ASR.SAPI.pas:501-522 / :489-498 | 流式 worker 空转不产出，`Stop` 以 `Success=True, Text=''` 回调 → 静默假成功 |
| 9 | Service.pas:210,229 / UpgradeFlow.pas:110 | 编排/升级流依赖被 #6 抹平的 Order.Status → 重复支付/失败单继续发放权益 |
| 10 | Permissions/权益链路（组合） | #7 抹空 Tier + 鉴权读取 → 付费用户被降级 / 越权 |

> #9、#10 为 #6/#7 数据缺陷在业务层的放大，根因修 #6/#7 即消解，但因资金/权益影响面最大，单列以示优先级。

# 存疑区（需运行期或上下文确认）

- **Q-1（Audio.WinMM 停止时序）**：`waveInClose` 前是否保证所有 `HWAVEIN` header 已从 DSP 队列归还，未构造确定复现；极端「停止即释放」路径可能悬垂，建议以压力/断电时序测试确认。
- **Q-2（Firebase 并发消费）**：C-07 在源码中明确注明「仅单实例部署安全」。若产品承诺单实例，则严重度可降为 🟡；若多端并发消费同一权益，则维持 🔴。需产品部署形态裁定。
- **Q-3（SafeClient 多线程状态）**：1250 行客户端内含 token/session 缓存字段，是否所有公有方法对共享状态加锁未逐行证实；建议并发压测验证是否存在竞态读写。

*报告结束。全程只读，未改动任何源码。*
