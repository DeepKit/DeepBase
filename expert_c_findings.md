# 专家 C 审阅报告:Persistence + Payment + 包边界

> 审查日期:2026-06-21
> 审查人:专家 C(持久化、支付与模块化架构专家)
> 审查范围:Persistence/ 全部(31 个 .pas)、ThirdParty/Payment/ 全部(17 个 .pas)、数据平台相关、包定义 .dpk
> 文件总数:40+ 个 .pas + 8 个 .dpk

## 概要

| 项目 | 数值 |
|------|------|
| 审阅模块数 | 40+ |
| 发现总数 | 8 |
| P0(紧急) | 3 |
| P1(高) | 3 |
| P2(中) | 2 |
| 安全性相关 | 4 |
| 可靠性/正确性 | 3 |
| 架构/边界 | 3 |

## 发现列表

| ID | 模块 | 严重度 | 类型 | 简述 | 位置 |
|----|------|--------|------|------|------|
| PAY-ARCH-001 | ThirdParty/Payment | P0 | architecture | IPaymentClient GUID 重复:`DeepBase.Payment.pas` 与 `DeepBase.Payment.Core.pas` 声明同名同 GUID 但方法签名完全不同的接口,QueryInterface 失败或调用错误内存偏移 | DeepBase.Payment.pas:215, DeepBase.Payment.Core.pas:18-38 |
| PAY-001 | ThirdParty/Payment/Stripe | P0 | correctness | 幂等键仅精确到秒(DateTimeToUnix),同一订单并发重试生成相同键,Stripe 侧可能多扣款 | DeepBase.Payment.Stripe.pas:303, 344 |
| PAY-002 | ThirdParty/Payment/Alipay | P0 | security | `FormatFloat('0.00', Amount)` 依赖系统区域设置,非 US 区域输出逗号小数分隔符,Alipay 拒收或错误解析金额 | DeepBase.Payment.Alipay.pas:375, 417, 462, 503, 608 |
| PERS-001 | Persistence/DB.Pool | P1 | thread-safety | TPooledConnection.Release 在 FLock 外调用 FAvailableEvent.SetEvent,与 ValidateIdleConnections 的 csValidating 状态交互可拿到未验证完成的连接 | DeepBase.DB.Pool.pas:737-761 |
| PERS-002 | Persistence/DB.StatusMachine | P1 | api-design | ValidateIdentifier 正则 `^[A-Za-z_][A-Za-z0-9_]*$` 不支持 schema.table 格式,多 schema 环境无法使用 | DeepBase.DB.StatusMachine.pas:191-209 |
| PERS-003 | Persistence/DB.JobQueue | P1 | reliability | Fail(Requeue=True 默认)无最大重试/指数退避/DLQ,下游服务故障时触发重试风暴压垮连接池 | Fail 方法 |
| PKG-001 | DeepBaseCommerce.dpk | P1 | package-boundary | requires 列表无 DeepBasePersistence,但 Commerce.Storage 等单元可能 uses FireDAC,违反 dpk 级显式声明原则 | DeepBaseCommerce.dpk |
| PERS-004 | Persistence/DB.Factory | P2 | performance | CreateConnectionFromProfile 每次调用创建并立即释放 TUniConnectionPool,高频调用消耗 CPU/内存 | DeepBase.DB.Factory.pas:177-196 |

## 严重度定义

| 严重度 | 含义 |
|--------|------|
| P0 | 可直接导致资金损失、数据损坏或系统不可用;须立即修复 |
| P1 | 存在明显缺陷,特定场景下可触发错误;须在当前迭代修复 |
| P2 | 设计瑕疵或潜在风险;建议在后续迭代中修复 |

## 详细发现说明

### PAY-ARCH-001 — IPaymentClient GUID 重复 + 方法签名不兼容

**模块**:ThirdParty/Payment
**严重度**:P0(架构缺陷)
**类型**:接口冲突

两个不同单元声明同名同 GUID 的 IPaymentClient 接口但方法签名完全不同:
- `DeepBase.Payment.pas:215` — GUID `{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}`,方法 `CreateOrder/QueryOrder/CloseOrder/Refund/QueryRefund/VerifyNotification/GetNotificationResponse`
- `DeepBase.Payment.Core.pas:19` — 同 GUID,方法 `CreatePayment/GetPaymentStatus/CapturePayment/CancelPayment/CreateRefund/GetRefundStatus/VerifyWebhookSignature/ParseWebhookEvent/GetProvider/GetEnvironment`

**影响**:同时 uses 两个单元的代码,QueryInterface 视为同一接口但方法签名不匹配,运行时调用错误内存偏移导致 AV 或数据损坏。

**修复建议**:
1. 将 `DeepBase.Payment.Core.pas` 的接口重命名为 `IPaymentCoreClient` 并分配新 GUID;或
2. 删除其中一个接口,统一方法签名;或
3. 包级隔离,确保使用者不会同时引用两个冲突接口

---

### PAY-001 — Stripe 幂等键秒级精度碰撞

**模块**:ThirdParty/Payment/DeepBase.Payment.Stripe.pas
**严重度**:P0(逻辑错误)
**类型**:并发/幂等性缺陷
**位置**:L303, L344

幂等键构造:
```pascal
'cs_' + AOrder.OrderNo + '_' + IntToStr(DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False))
```

`DateTimeToUnix(..., False)` 截断为整秒。同一订单并发创建请求在同一秒内生成相同幂等键,Stripe 将后续请求视为重复,可能返回首次结果而非创建新订单,导致多扣款。

**修复建议**:
1. 追加毫秒:`IntToStr(DateTimeToUnix(Now, False)) + '_' + IntToStr(MilliSecondOf(Now))`
2. 或用 GUID 后缀:`AOrder.OrderNo + '_' + TGUID.NewGuid.ToString`
3. 或调用方维护幂等键状态,重试时复用

---

### PAY-002 — Alipay 金额格式化依赖系统区域设置

**模块**:ThirdParty/Payment/DeepBase.Payment.Alipay.pas
**严重度**:P0(安全缺陷)
**类型**:本地化/数据有效性
**位置**:L375, L417, L462, L503, L608

```pascal
FormatFloat('0.00', AOrder.Amount)
```

`FormatFloat` 使用调用线程当前 `TFormatSettings`。在非 US 区域(如中文、德语、法语),小数分隔符为逗号,金额被格式化为 `"1234,56"`。Alipay API 要求 `\d+(\.\d+)?` 格式,逗号形式被拒收或静默解析为整数部分,导致实际扣款偏差。

**修复建议**:
1. 显式传入 `TFormatSettings`:
   ```pascal
   var FS := TFormatSettings.Create('en-US');
   FS.DecimalSeparator := '.';
   LAmount := FormatFloat('0.00', AOrder.Amount, FS);
   ```
2. 或改用 `TMoney.ToMinorUnits`(整数分)传输,避免浮点精度
3. 在 Alipay 网关类统一使用 `TMoney`,消除所有 `FormatFloat`

---

### PERS-001 — TPooledConnection.Release 状态变更竞态窗口

**模块**:Persistence/DeepBase.DB.Pool.pas
**严重度**:P1(线程安全)
**类型**:竞态条件
**位置**:L737-761

```pascal
procedure TPooledConnection.Release;
begin
  if Assigned(FPool) then
  begin
    var LUseTime := UseTime;
    FPool.FLock.Enter;
    try
      FState := csIdle;
      FLastUsedAt := Now;
      FOwnerThreadId := 0;
      FLeakWarned := False;
    finally
      FPool.FLock.Leave;
    end;
    FPool.FAvailableEvent.SetEvent;  // 在锁外设置事件
  end;
end;
```

**风险**:
- 并发唤醒竞争:多个等待线程同时被��醒竞争同一连接,多余线程经历不必要等待-重试
- 与 ValidateIdleConnections 交互:`FindAvailableConnection` 只检查 csIdle,不检查 csValidating,验证线程未完成时 Release 的 SetEvent 可触发获取未验证完成的连接

**修复建议**:
1. 将 `FAvailableEvent.SetEvent` 移至 FLock 内部
2. `FindAvailableConnection` 跳过 csValidating 状态连接,或增加 csreleased 中间态

---

### PERS-002 — StatusMachine 表名校验不支持 schema 限定名

**模块**:Persistence/DeepBase.DB.StatusMachine.pas
**严重度**:P1(架构缺陷)
**类型**:功能限制
**位置**:L191-209

```pascal
class function TStatusMachine.ValidateIdentifier(const AIdentifier: string): Boolean;
begin
  Result := TRegEx.IsMatch(AIdentifier, '^[A-Za-z_][A-Za-z0-9_]*$');
end;
```

拒绝 `public.users`/`dbo.order_status` 等多 schema 引用。PostgreSQL 多 schema 或 SQLite ATTACH 场景无法使用。

**修复建议**:
1. 正则改为支持可选 schema 前缀:`^([A-Za-z_][A-Za-z0-9_]*\.)?[A-Za-z_][A-Za-z0-9_]*$`
2. 或拆分标识符分别校验

---

### PERS-003 — JobQueue 无死信队列,重试风暴风险

**模块**:Persistence/DeepBase.DB.JobQueue.pas
**严重度**:P1(架构缺陷)
**类型**:可靠性缺陷
**位置**:Fail 方法(Requeue 默认 True)

`Fail(TaskID, ErrorMessage, Requeue=True)` 将失败任务重置为 pending,无以下控制机制:
- 最大重试次数
- 指数退避
- 死信队列(DLQ)
- 失败原因持久化审计

下游服务故障时大量任务反复入队引发重试风暴,压垮 JobQueue 自身的 4 槽连接池并阻塞正常任务。

**修复建议**:
1. 增加 MaxRetries 字段和 RetryCount 计数器
2. 将 Requeue 默认值改为 False
3. 增加 ExponentialBackoff(`2^RetryCount` 秒延迟)
4. 增加独立 DLQ 表,达阈值任务自动转移
5. 持续失败任务触发告警钩子

---

### PKG-001 — DeepBaseCommerce.dpk 包依赖声明可能不完整

**模块**:DeepBaseCommerce.dpk
**严重度**:P1(包边界)
**类型**:依赖管理缺陷

requires 列表:
```
requires
  rtl,
  DeepBaseCore,
  DeepBaseServices
```

contains 包含 `Commerce.Storage`/`Commerce.Service` 等,很可能 uses FireDAC 单元,但未在 requires 中声明 DeepBasePersistence。

**影响**:
- 编译期:Delphi 可编译通过(单元各自声明 uses),但违反 dpk 级显式声明原则
- 设计期:IDE 包依赖分析不正确,可能安装顺序问题
- 运行期:包拆分加载时未声明的依赖包可能在所需包之前卸载,导致空指针

**修复建议**:
1. 检查 Commerce.Storage/Service 的 uses 列表确认 FireDAC 引用
2. 若存在,在 requires 添加 DeepBasePersistence
3. 若 Commerce 无需直接访问 DB,将存储逻辑上移至独立层

---

### PERS-004 — CreateConnectionFromProfile 每次创建临时连接池

**模块**:Persistence/DeepBase.DB.Factory.pas
**严重度**:P2(设计缺陷)
**类型**:资源开销
**位置**:L177-196

```pascal
function TDBConnectionFactory.CreateConnectionFromProfile(...): TFDConnection;
var
  LPool: TUniConnectionPool;
begin
  LPool := TUniConnectionPool.Create(nil);  // 创建临时池
  try
    Result := LPool.CreateUnopenedConnection(...);
  finally
    LPool.Free;  // 立即释放
  end;
end;
```

高频调用下创建/销毁完整池(含维护线程、预热逻辑)消耗 CPU/内存。临时池参数可能与全局池不一致导致行为差异。

**修复建议**:
1. 工厂关联全局 TUniConnectionPool,直接借用
2. 或在工厂内维护长生命周期内部池
3. 或文档明确"创建不加入全局池的独立连接"语义

## 审查说明

### 审查方法
静态代码分析,全文阅读所有相关文件,未执行编译或动态分析。覆盖:
- Persistence/ 全部 .pas(ConnectionPool、JobQueue、Pool、StatusMachine、Guardian、AutoRefreshConfig、Factory、DoQry、SQLLogger、ORM)
- ThirdParty/Payment/ 全部 .pas(Types、Core、Stripe、Alipay、PayPal、WeChatPay、AESGCM)
- Features/DeepBase.DataPlatform.Bootstrap.pas
- 所有 .dpk 包文件

### 未覆盖事项
- DoQry 集成层预编译语句缓存正确性(DeepBase.DB.DoQry.pas,约 1700 行,需专项审查)
- BCRYPT Windows CNG API 封装(WeChatPay.pas:117-443)内存安全
- Guardian 隔离恢复流程端到端正确性
- AutoRefreshConfig 变更令牌与数据库触发器一致性
- 包文件 contains 列表与磁盘 .pas 同步性(当前静态比对,未交叉校验)
- PayPal VerifyNotification production 模式无签名直接返回 False 的兜底策略合理性

## 优先级排序

1. **PAY-ARCH-001(P0)**:IPaymentClient GUID 重复 — 可导致运行时崩溃或数据损坏
2. **PAY-002(P0)**:Alipay 金额本地化 — 可导致资金损失
3. **PAY-001(P0)**:Stripe 幂等键精度 — 可导致重复扣款
4. **PERS-003(P1)**:JobQueue 重试风暴 — 下游故障时系统崩溃
5. **PERS-001(P1)**:连接池 Release 竞态 — 高并发下性能/正确性
6. **PERS-002(P1)**:StatusMachine schema 限定 — 多 schema 环境无法使用
7. **PKG-001(P1)**:Commerce.dpk 依赖声明
8. **PERS-004(P2)**:连接工厂临时池开销
