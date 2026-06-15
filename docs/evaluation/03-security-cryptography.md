# 安全与密码学模块评估报告

## 评估摘要

**总评分：7.5 / 10**

DeepBase 的安全架构整体设计合理，使用了 Windows CNG/BCrypt 作为主加密后端，密码学原语实现正确，具备常量时间比较、加密后认证（Encrypt-then-MAC）、CSPRNG 等关键安全特性。主要风险在于：(1) AES-CBC 仍为默认模式而非 AES-GCM；(2) 遗留格式兼容路径削弱了整体安全姿态；(3) 授权模块缺少身份认证集成和会话管理。

---

## 威胁模型概述

DeepBase 作为桌面数据库应用框架，面临以下主要威胁：

| 威胁类别 | 描述 | 当前防御状态 |
|----------|------|-------------|
| 数据静态安全 | 数据库文件被物理访问/窃取 | AES-CBC + HMAC（中等） |
| 密钥泄露 | 加密密钥从内存中被提取 | 部分缓解（密钥清零） |
| 权限绕过 | 未授权用户访问受限功能 | RBAC 实现完整（中等） |
| 篡改攻击 | 二进制文件或数据库被修改 | AntiTamper 完整性校验（较好） |
| 密码暴力破解 | 用户密码被离线字典攻击 | PBKDF2 100K 迭代（较好） |
| 侧信道攻击 | 时序攻击泄露密钥信息 | 常量时间比较（较好） |

---

## 各模块详细评估

### 1. Core/DeepBase.Crypto.pas — 主加密模块

**职责**：提供哈希、编码、对称加密（AES）、��码哈希（PBKDF2）、随机数生成、HMAC、RSA 签名/验证等密码学原语。

#### 密码学正确性

| 检查项 | 结果 | 说明 |
|--------|------|------|
| AES 模式选择 | 中 | 默认使用 CBC（line 401），GCM 常量已定义（line 32-33）但未在 TAESCrypto 中使用 |
| 密钥派生参数 | 良 | 100,000 迭代（line 1122）、16 字节 salt（line 1123）、SHA-256 |
| 随机数生成 | 优 | BCryptGenRandom with BCRYPT_USE_SYSTEM_PREFERRED_RNG（line 1007） |
| 常量时间比较 | 良 | BytesEqualConstantTime 使用 XOR-OR 模式（lines 590-603） |
| HMAC 实现 | 优 | 正确实现 RFC 2104 HMAC（lines 820-868） |
| PBKDF2 实现 | 良 | 正确实现 RFC 2898（lines 1216-1268），但纯软件实现 |
| PKCS7 填充 | 良 | 正确实现填充/去填充（lines 1417-1448） |
| RSA 签名/验证 | 优 | 使用 CNG BCryptSignHash/BCryptVerifySignature，PKCS#1 v1.5 + SHA-256 |

#### 密钥管理

- **密钥清零**：TAESCrypto.Destroy 使用 FillChar 清零密钥和 IV（lines 1343-1352）
- **私钥清零**：TRSASigner.Destroy 清零 FPrivateKeyBlob（lines 2343-2346）
- **密钥存储**：密钥仅在内存中，无持久化泄露风险
- **硬编码密钥**：未发现硬编码密钥

#### 已知漏洞/风险

| 严重程度 | 问题 | 行号 | 描述 |
|----------|------|------|------|
| 中 | AES-CBC 为默认模式 | 401, 1337 | CBC 不提供认证，需要额外 HMAC。应迁移到 AES-GCM |
| 中 | ECB 模式仍可用 | 381 | `TAESMode = (aesECB, aesCBC, ...)` ECB 模式不应暴露给调用者 |
| 中 | 遗留格式无 MAC 保护 | 1844-1857 | Legacy format（无 header）仅包含 IV + Cipher，无完整性校验 |
| 中 | v1 使用确定性 salt | 1395-1398, 1832 | `DeriveSalt` 使用 `SHA256(password + '_salt_v1')` 确定性派生 salt，相同密码总是产生相同 salt |
| 低 | 常量时间比较长度泄露 | 595-596 | 长度不同时立即返回 False，泄露数据长度。对 MAC 比较可接受 |
| 低 | 无最低迭代次数强制 | 1151-1209 | `VerifyPassword` 不强制最低迭代次数，攻击者可提供低迭代 hash |

#### 修复建议

1. **[P1] 默认模式迁移到 AES-GCM**：在 BCrypt 后端实现 AES-GCM 加密（已有 `BCRYPT_CHAIN_MODE_GCM` 常量和 `BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO` 结构定义），将 `TAESCrypto` 默认模式改为 GCM。GCM 提供认证加密，消除 CBC + HMAC 的组合复杂性。

2. **[P1] 移除 ECB 模式**：从 `TAESMode` 枚举中删除 `aesECB`，或至少添加运行时检查拒绝 ECB 模式创建。

3. **[P2] 弃用遗留格式**：为 v1 和无 header 格式添加弃用警告。在下个大版本中移除向后兼容路径。

4. **[P2] v1 确定性 salt 替换**：对于已有 v1 数据，在解密后立即用 v2 格式重新加密。

---

### 2. Core/DeepBase.Crypto.PBKDF2.pas — 独立 PBKDF2 模块

**职责**：提供独立的 PBKDF2-HMAC-SHA256 实现（RFC 2898）。

#### 密码学正确性

- 实现正确：标准 PBKDF2 迭代结构（lines 90-137）
- 有最低迭代次数检查：1000（line 97）
- HMAC-SHA256 实现正确（lines 31-79）

#### 已知漏洞/风险

| 严重程度 | 问题 | 行号 | 描述 |
|----------|------|------|------|
| 低 | 功能重复 | 全局 | 与 Crypto.pas 中的 TPasswordUtils.PBKDF2 重复 |
| 低 | 最低迭代次数偏低 | 97 | 1000 迭代远低于现代推荐值（NIST SP 800-132 推荐至少 10,000） |

#### 修复建议

1. **[P3] 统一 PBKDF2 入口**：将此模块的调用迁移到 `TPasswordUtils.PBKDF2`，或反之。
2. **[P3] 提高最低迭代次数到至少 100,000**。

---

### 3. Core/DeepBase.Crypto.OpenSSL.pas — OpenSSL 后端

**职责**：为非 Windows 平台（macOS/Linux）提供 AES-256-GCM/CBC、PBKDF2、RSA 验证。

#### 密码学正确性

- 使用 AES-256-GCM（line 63-64）：提供认证加密
- 动态加载 libcrypto（lines 106-121）：支持 OpenSSL 3.x 和 1.1
- PBKDF2 使用 OpenSSL 的 PKCS5_PBKDF2_HMAC（line 198）

#### 已知漏洞/风险

| 严重程度 | 问题 | 行号 | 描述 |
|----------|------|------|------|
| 低 | 平台功能差异 | 全局 | Windows 使用 CBC，非 Windows 有 GCM 能力——同一框架在不同平台安全等级不同 |

#### 修复建议

1. **[P2] 统一 GCM 为跨平台默认**：在 Windows BCrypt 后端也实现 GCM，使两端安全等级一致。

---

### 4. Core/DeepBase.Authorization.pas — RBAC 授权模块

**职责**：基于角色的访问控制（RBAC），支持用户、角色、权限管理，层次角色继承，审计日志。

#### 授权模型评估

| 检查项 | 结果 | 说明 |
|--------|------|------|
| 权限检查完整性 | 良 | HasPermission 检查用户激活状态、角色继承（lines 1266-1314） |
| 循环引用防护 | 优 | GetRolePermissionsRecursive 使用 Visited 列表防止循环（lines 878-912） |
| 通配符权限 | 良 | 支持 `*` 和 `resource.*` 通配符（lines 1272-1286） |
| 线程安全 | 良 | TCriticalSection 保护所有读写操作 |
| 审计日志 | 良 | 支持回调和持久化（lines 822-847） |

#### 已知漏洞/风险

| 严重程度 | 问题 | 行号 | 描述 |
|----------|------|------|------|
| 高 | 无身份认证集成 | 全局 | 模块仅提供授权（authorization），不包含认证（authentication）。SetCurrentUser 仅设置用户名（line 1379-1393），无密码验证、无令牌校验 |
| 高 | 单全局用户上下文 | 276, 1379-1425 | FCurrentUser 是单一全局变量，不适合多线程服务场景。多线程环境下用户上下文会相互覆盖 |
| 中 | 通配符权限过宽 | 1276 | `Granted = '*'` 授予所有权限，可能被意外分配 |
| 中 | 无会话超时 | 全局 | SetCurrentUser 后无自动过期机制 |
| 中 | 无暴力破解防护 | 全局 | 登录尝试无速率限制、无账户锁定 |
| 低 | 权限检查无缓存 | 1266-1314 | 每次 HasPermission 调用都递归遍历角色层次，频繁调用有性能开销 |
| 低 | RequirePermissions 全局函数无锁 | 492-496 | `RequirePermissions` 调用链涉及多次锁获取/释放，存在 TOCTOU 窗口 |

#### 修复建议

1. **[P1] 集成身份认证**：添加独立的认证层，支持密码验证、JWT/令牌认证。SetCurrentUser 应仅接受经过认证的用户。

2. **[P1] 线程本地用户上下文**：将 FCurrentUser 改为线程本地存储（TLS），或使用 `TThreadLocal<TUser>` 替代全局变量。

3. **[P2] 添加会话超时**：引入 SessionTimeout 属性，在 CurrentUserCan 检查时验证会话有效性。

4. **[P2] 添加登录速率限制**：在认证层实现账户锁定策略（如 5 次失败后锁定 15 分钟）。

5. **[P3] 权限缓存**：对 GetEffectivePermissions 结果添加 TTL 缓存，减少递归遍历。

---

### 5. Features/DeepBase.AntiTamper.pas — 反篡改模块

**职责**：数据库镜像（image）完整性校验，使用 AES-256-CBC + HMAC-SHA256 加密保护镜像数据。

#### 已知漏洞/风险

| 严重程度 | 问题 | 行号 | 描述 |
|----------|------|------|------|
| 低 | CBC 模式 | 全局 | 镜像加密使用 AES-256-CBC + HMAC，功能上等价于 Encrypt-then-MAC 但增加了实现复杂度 |

#### 修复建议

1. **[P2] 迁移到 AES-GCM**：简化实现，消除 CBC + HMAC 组合的复杂性。

---

### 6. Features/DeepBase.AntiTamper.PersistenceRegistration.pas

**职责**：将 AntiTamper 功能注册到持久化存储适配器，解除 Features 对 FireDAC 的直接依赖。

#### 评估

该模块为纯注册/适配层，无独立安全逻辑。设计合理，遵循依赖倒置原则。

---

### 7. Persistence/DeepBase.External.BCryptDecrypt.pas — BCrypt 解密后端

**职责**：使用 Windows BCrypt API 实现 SQLCipher 数据库的直接解密，支持 SQLCipher v3 和 v4 格式。

#### 密码学正确性

- 使用 BCrypt 进行 AES-256-CBC 解密
- PBKDF2 密钥派生使用 BCrypt 后端（Windows 硬件加速）
- 正确处理 SQLCipher v4（SHA-512, 256,000 迭代）和 v3（SHA-1, 64,000 迭代）

#### 已知漏洞/风险

| 严重程度 | 问题 | 行号 | 描述 |
|----------|------|------|------|
| 低 | SQLCipher v3 弱参数 | 全局 | v3 使用 SHA-1 和 64,000 迭代，已不满足现代安全要求。但这是兼容已有数据所必需的 |

#### 修复建议

1. **[P3] 引导用户迁移 v3 数据库**：检测到 v3 格式时提示用户升级到 v4。

---

### 8. Persistence/DeepBase.Persistence.Authorization.FireDAC.pas — 授权持久化

**职责**：使用 FireDAC 实现 IAuthorizationStorage 接口，持久化用户、角色、权限和审计日志。

#### 安全性评估

| 检查项 | 结果 | 说明 |
|--------|------|------|
| SQL 注入防护 | 优 | 全部使用参数化查询 |
| 表结构安全 | 良 | 字段类型合理，无明文密码存储 |
| 审计日志完整性 | 良 | 记录用户名、操作、资源、IP、成功/失败 |

#### 已知漏洞/风险

| 严重程度 | 问题 | 行号 | 描述 |
|----------|------|------|------|
| 低 | 审计日志可被 DBA 篡改 | 全局 | 审计日志存储在应用数据库中，有数据库访问权限的人可以修改/删除 |

#### 修复建议

1. **[P3] 审计日志防篡改**：考虑将审计日志发送到独立的追加存储（如 WORM 存储或远程 syslog）。

---

## 关键发现（按严重程度排序）

### 高严重度

1. **授权模块缺少身份认证**（Authorization.pas）
   - `SetCurrentUser` 仅接受用户名，无密码/令牌验证
   - 任何能调用此方法的代码都可以冒充任意用户
   - **修复优先级：P1**

2. **单全局用户上下文不适合并发场景**（Authorization.pas:276）
   - `FCurrentUser` 是类级别的单一字段
   - 多线程环境下用户上下文会相互覆盖，导致权限检查错乱
   - **修复优先级：P1**

### 中严重度

3. **AES-CBC 为默认加密模式**（Crypto.pas:401, 1337）
   - CBC 不提供认证，需要额外的 HMAC 来保证完整性
   - 框架已定义了 GCM 常量但未使用
   - **修复优先级：P1**

4. **ECB 模式仍暴露在枚举中**（Crypto.pas:381）
   - ECB 模式是不安全的，不应提供给调用者
   - **修复优先级：P2**

5. **遗留格式无完整性保护**（Crypto.pas:1844-1857）
   - 无 header 的旧格式数据没有 MAC 校验
   - 可被静默篡改
   - **修复优先级：P2**

6. **v1 确定性 salt 削弱安全性**（Crypto.pas:1395-1398）
   - `DeriveSalt` 使用 `SHA256(password + '_salt_v1')` 产生确定性 salt
   - 相同密码总是产生相同加密密钥
   - **修复优先级：P2**

7. **无会话超时机制**（Authorization.pas）
   - 登录后会话永不过期
   - **修复优先级：P2**

8. **无登录暴力破解防护**（Authorization.pas）
   - 缺少速率限制和账户锁定策略
   - **修复优先级：P2**

### 低严重度

9. **常量时间比较泄露长度信息**（Crypto.pas:595-596）
10. **VerifyPassword 不强制最低迭代次数**（Crypto.pas:1151）
11. **PBKDF2 模块功能重复**（Crypto.pas + Crypto.PBKDF2.pas）
12. **Windows/非 Windows 安全等级不一致**（CBC vs GCM）
13. **SQLCipher v3 使用弱参数**（BCryptDecrypt.pas）

---

## 优先级排序的改进建议（Top 5）

### 1. [P1] 实现 AES-GCM 作为默认加密模式

**当前状态**：AES-CBC + HMAC（Encrypt-then-MAC）
**目标**：AES-256-GCM（认证加密）

**实施步骤**：
1. 在 `TAESCrypto.Encrypt/Decrypt` 中添加 GCM 路径，使用 `BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO` 结构
2. 将 `TAESCrypto` 默认模式改为 `aesGCM`（新增枚举值）
3. 更新 `TSimpleCrypto` 使用 v3 格式：Header + Salt + IV(12) + Cipher + Tag(16)
4. 保持 CBC 格式的向后兼容解密，但加密始终使用 GCM
5. 在非 Windows 端使用 OpenSSL 的 EVP_aes_256_gcm（已存在）

**预期收益**：
- 消除 CBC 的 padding oracle 风险
- 简化实现（无需单独的 HMAC 步骤）
- 跨平台安全等级一致

### 2. [P1] 为授权模块添加身份认证层

**当前状态**：仅有授权（authorization），无认证（authentication）
**目标**：完整的认证 + 授权体系

**实施步骤**：
1. 创建 `TAuthenticationManager` 类，负责：
   - 密码验证（调用 `TPasswordUtils.VerifyPassword`）
   - 令牌生成/验证（JWT 或自定义令牌）
   - 登录/注销管理
2. 修改 `SetCurrentUser` 为 `Authenticate(username, password): TSession`
3. 返回包含过期时间的会话对象
4. 在 `CurrentUserCan` 检查时验证会话有效性

### 3. [P1] 线程安全的用户上下文

**当前状态**：单一全局 `FCurrentUser`
**目标**：每个线程/请求独立的上下文

**实施步骤**：
1. 使用 `TThreadLocal<TUser>` 或手动维护 per-thread 字典
2. 添加 `SetUserContext(User)` / `ClearUserContext` 方法
3. 在 `CurrentUserCan` 中使用当前线程的上下文

### 4. [P2] 移除 ECB 模式，弃用遗留格式

**实施步骤**：
1. 从 `TAESMode` 枚举中移除 `aesECB`（或添加运行时拒绝）
2. 为 v1 和无 header 格式的解密添加日志警告
3. 提供迁移工具：检测旧格式并自动升级到 v2/v3 格式
4. 在下个大版本中移除旧格式支持

### 5. [P2] 添加登录安全和会话管理

**实施步骤**：
1. 实现账户锁定策略：5 次失败后锁定 15 分钟
2. 添加会话超时：默认 30 分钟无活动过期
3. 实现登录尝试延迟（指数退避）
4. 在审计日志中记录所有登录失败

---

## 附录：密码学参数基准对照

| 参数 | DeepBase 当前值 | 现代推荐值（NIST/OWASP） | 评估 |
|------|----------------|------------------------|------|
| PBKDF2 迭代次数 | 100,000 | >= 600,000（OWASP 2023） | 偏低 |
| Salt 长度 | 16 字节 | >= 16 字节 | 符合 |
| AES 密钥长度 | 256 位 | 256 位 | 符合 |
| AES 模式 | CBC | GCM | 需改进 |
| HMAC 算法 | SHA-256 | SHA-256 | 符合 |
| MAC 长度 | 32 字节 | >= 16 字节 | 符合 |
| 随机数生成 | BCryptGenRandom | CSPRNG | 符合 |
| RSA 密钥长度 | 未强制最小 | >= 2048 位 | 需添加检查 |
| RSA 填充 | PKCS#1 v1.5 | PSS | 可改进 |

---

*报告生成日期：2026-06-15*
*评估范围：DeepBase 框架安全/密码学相关模块*
*评估方法：静态代码审查 + 密码学最佳实践对照*
