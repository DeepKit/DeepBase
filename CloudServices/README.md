# DeepBase Cloud Services

本目录包�?DeepBase 框架云端服务所需的示例配置文件�?

## 文件说明

### version.json

用于自动更新功能的版本信息文件�?

**结构:**
- `stable` - 稳定版信�?
- `beta` - 测试版信�?
- `dev` - 开发版信息
- `meta` - 元数据信�?

**字段说明:**
| 字段 | 类型 | 说明 |
|------|------|------|
| version | string | 版本�?(�?"1.0.0") |
| versionCode | integer | 版本代码 (用于比较) |
| downloadUrl | string | 下载地址 |
| fileSize | integer | 文件大小 (字节) |
| sha256 | string | 文件 SHA256 校验�?|
| releaseNotes | string | 更新说明 |
| releaseDate | string | 发布日期 |
| isMandatory | boolean | 是否强制更新 |
| minOsVersion | string | 最低系统版本要�?|

### remote-config.json

远程配置文件，支持动态配置和功能开关�?

**结构:**
- `configs` - 配置�?
- `featureFlags` - 功能开�?
- `messages` - 应用内消�?
- `meta` - 元数�?

**配置项字�?**
| 字段 | 类型 | 说明 |
|------|------|------|
| value | string | 配置�?|
| type | string | 值类�?(string/integer/boolean/float) |
| description | string | 配置说明 |

**功能开关字�?**
| 字段 | 类型 | 说明 |
|------|------|------|
| enabled | boolean | 是否启用 |
| rolloutPercentage | integer | 灰度发布百分�?(0-100) |
| description | string | 功能说明 |

## 部署指南

### 1. 静态文件托�?

最简单的方式是将 JSON 文件托管在静态文件服务器上：

```
# 目录结构
/api/
  /v1/
    /version.json
    /config.json
```

**Nginx 配置示例:**
```nginx
server {
    listen 443 ssl;
    server_name api.example.com;
    
    location /v1/ {
        root /var/www/DeepBase;
        add_header Cache-Control "public, max-age=300";
        add_header Access-Control-Allow-Origin "*";
    }
}
```

### 2. CDN 部署

推荐使用 CDN 来提供更好的访问速度和可用性：

- **阿里�?OSS + CDN**
- **腾讯�?COS + CDN**
- **Cloudflare R2 + CDN**
- **AWS S3 + CloudFront**

**CDN 配置要点:**
1. 启用 HTTPS
2. 设置合理的缓存时�?(建议 5-15 分钟)
3. 启用 CORS
4. 启用 Gzip 压缩

### 3. 动�?API 服务

如果需要更复杂的逻辑（如用户分组、A/B测试），可以使用动�?API�?

**Go 示例:**
```go
func handleVersion(w http.ResponseWriter, r *http.Request) {
    channel := r.URL.Query().Get("channel")
    // 根据 channel 返回对应版本信息
    json.NewEncoder(w).Encode(versionInfo[channel])
}
```

**Delphi WebBroker 示例:**
```pascal
procedure TWebModule1.WebModule1VersionAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  Channel: string;
begin
  Channel := Request.QueryFields.Values['channel'];
  Response.ContentType := 'application/json';
  Response.Content := GetVersionJson(Channel);
  Handled := True;
end;
```

## 客户端集�?

### 自动更新

```pascal
uses DeepBase.AutoUpdate, DeepBase.VCL.AutoUpdater;

// 方式1: 使用组件
AutoUpdater1.UpdateUrl := 'https://api.example.com/v1/version.json';
AutoUpdater1.Channel := ucStable;
AutoUpdater1.CheckNowAsync;

// 方式2: 直接使用�?
var
  Updater: TDeepBaseAutoUpdate;
begin
  Updater := TDeepBaseAutoUpdate.Create('https://api.example.com/v1/version.json');
  try
    Updater.Channel := ucStable;
    if Updater.CheckForUpdate then
      // 有新版本
  finally
    Updater.Free;
  end;
end;
```

### 远程配置

```pascal
uses DeepBase.RemoteConfig;

var
  Config: TDeepBaseRemoteConfig;
begin
  Config := TDeepBaseRemoteConfig.Create('https://api.example.com/v1/config.json');
  try
    Config.RefreshConfig;
    
    // 获取配置�?
    MaxSize := Config.GetConfigInt('app.maxUploadSize', 10485760);
    Theme := Config.GetConfig('ui.defaultTheme', 'light');
    
    // 检查功能开�?
    if Config.IsFeatureEnabled('feature.newDashboard') then
      ShowNewDashboard;
  finally
    Config.Free;
  end;
end;
```

## 安全建议

1. **始终使用 HTTPS**
2. **验证 SHA256 校验�?* - 下载文件后验证完整�?
3. **签名验证** - 可选：使用代码签名�?JSON 签名
4. **速率限制** - 防止滥用
5. **监控告警** - 监控配置变更和异常访�?

## 更新流程

1. 修改 JSON 文件
2. 测试验证
3. 上传到服务器/CDN
4. 等待缓存过期或手动清除缓�?
5. 客户端获取新配置

## 回滚

如需回滚，只需�?JSON 文件恢复到之前的版本并重新上传�?

建议使用版本控制系统（如 Git）管理配置文件，便于追踪变更和回滚�?
