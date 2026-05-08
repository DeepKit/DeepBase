# 防篡改播种工具使用说�?
## 功能概述

`SeedTool.exe` 是一个独立的图像资源加密播种工具，用于将图像文件加密后写�?`DeepDeepDeepDeepDeepMoveC.db` 数据库�?
## 安全机制

- **KDF 密钥派生**：使�?PBKDF2 (SHA-256) 从管理员密码派生加密密钥
- **AES-256 加密**：图像数据使用派生密钥进�?AES-256 加密
- **双重校验**�?  - SHA-256：验证数据完整�?  - HMAC-SHA256：防止数据被篡改和伪�?
## 使用步骤

### 1. 启动播种工具
```
运行 SeedTool.exe
```

### 2. 输入管理员密�?- 密码长度不少�?8 �?- **重要**：此密码必须与主程序 `uMain.pas` 中的 `Config.EncryptionKey` 一�?- 当前主程序使用的密码：`DeepDeepDeepDeepDeepMoveC_AntiTamper_Key_2025`

### 3. 添加图像文件
- 点击"添加图像"按钮
- 选择一个或多个图像文件（支�?PNG、JPG、BMP、GIF 等）
- 图像�?key 将自动使用文件名（不含扩展名�?
### 4. 开始播�?- 点击"开始播�?按钮
- 工具将：
  1. 初始化防篡改包（使用输入的密码）
  2. 连接数据�?`DeepDeepDeepDeepDeepMoveC.db`
  3. 创建/验证表结构（包含 `sha256_hash` �?`hmac_sha256` 字段�?  4. 逐个加密并写入图�?
### 5. 查看日志
- 播种过程的详细日志会显示在底部日志区�?- 包括成功/失败状�?
## 注意事项

1. **密码一致�?*
   - 播种工具使用的密码必须与主程序一�?   - 否则主程序无法解密图�?
2. **数据库位�?*
   - 数据库文�?`DeepDeepDeepDeepDeepMoveC.db` 应与 `SeedTool.exe` 在同一目录
   - 或使用主程序的数据库路径

3. **严格模式**
   - 播种工具使用严格模式
   - 所有记录都包含 `sha256_hash` �?`hmac_sha256` 字段

4. **主程序配�?*
   - 主程序必须启用相同的配置�?     ```pascal
     Config.Salt := 'DeepDeepDeepDeepDeepMoveC_Salt_v1';
     Config.KdfIterations := 10000;
     Config.EnableHMAC := True;
     ```

## 安全建议

1. **管理员密�?*
   - 使用强密码（建议 16 位以上，包含大小写字母、数字、特殊字符）
   - 妥善保管密码，不要泄�?
2. **播种环境**
   - 在安全的环境中运行播种工�?   - 播种完成后立即关闭工�?
3. **数据库保�?*
   - 播种后的 `DeepDeepDeepDeepDeepMoveC.db` 应妥善保�?   - 定期备份

## 故障排除

### 播种失败
- 检查密码长度是否符合要�?- 检查图像文件是否存�?- 查看日志区域的详细错误信�?
### 主程序无法解�?- 确认播种工具和主程序使用相同的密�?- 确认 Salt、KdfIterations、EnableHMAC 配置一�?
### 数据库错�?- 检�?`DeepDeepDeepDeepDeepMoveC.db` 文件是否存在
- 检查文件权�?- 尝试使用 `DeepDeepDeepDeepDeepMoveC.reset` 清空并重新播�?
## 与主程序集成

主程序（`C盘超级瘦�?exe`）会�?1. 初始化相同的防篡改配�?2. 读取并解密图像数�?3. 验证 SHA-256 �?HMAC-SHA256
4. 如果校验失败，触发安全退出（fail-closed�?
## 开发者信�?
- 工具版本�?.0
- 使用单元�?  - `uAntiTamperPackage.pas`
  - `uBasicProtection.pas`
  - `uLogger.pas`
