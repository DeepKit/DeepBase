# AipexBase 用户认证与账务系统集成指南

> **文档版本**: 1.0
> **创建日期**: 2025-12-15
> **用途**: 指导 Delphi 应用快速集成 AipexBase 用户认证、余额充值、用量统计和账单功能

---

## 概述

AipexBase 是一个云端用户认证和计费服务，为桌面应用提供：
- 用户注册/登录/找回密码
- 账户余额管理和充值
- API 调用用量统计
- 账单和发票管理

UniBase 提供了完整的 VCL 和 FMX UI 组件，可直接集成到您的 Delphi 应用中。

---

## 快速开始

### 前置条件

1. UniBase 项目已编译
2. 网络可访问 AipexBase 服务器
3. 已获取 AipexBase 服务地址（开发/生产环境）

### 文件清单

**共用组件：**
- `Core/UniBase.AipexBase.Client.pas` - API 客户端

**VCL 组件：**
- `VCL/UniBase.VCL.LoginDialog.pas` - 登录对话框
- `VCL/UniBase.VCL.RegisterDialog.pas` - 注册对话框
- `VCL/UniBase.VCL.ForgotPasswordDialog.pas` - 找回密码对话框
- `VCL/UniBase.VCL.UserProfileFrame.pas` - 用户信息 Frame
- `VCL/UniBase.VCL.BalanceFrame.pas` - 余额/充值 Frame
- `VCL/UniBase.VCL.UsageStatsFrame.pas` - 用量统计 Frame
- `VCL/UniBase.VCL.BillingFrame.pas` - 账单/发票 Frame

**FMX 组件：**
- `FMX/UniBase.FMX.LoginDialog.pas` - 登录对话框
- `FMX/UniBase.FMX.RegisterDialog.pas` - 注册对话框
- `FMX/UniBase.FMX.ForgotPasswordDialog.pas` - 找回密码对话框
- `FMX/UniBase.FMX.UserProfileFrame.pas` - 用户信息 Frame
- `FMX/UniBase.FMX.BalanceFrame.pas` - 余额/充值 Frame
- `FMX/UniBase.FMX.UsageStatsFrame.pas` - 用量统计 Frame
- `FMX/UniBase.FMX.BillingFrame.pas` - 账单/发票 Frame

---

## VCL 应用集成

### 步骤 1: 添加搜索路径

在 Delphi IDE 项目选项中添加：
```
D:\_Progs\02Business\UniBase\Core
D:\_Progs\02Business\UniBase\VCL
```

### 步骤 2: 初始化 API 客户端

```pascal
uses
  UniBase.AipexBase.Client;

var
  GAipexClient: TAipexBaseClient;

procedure InitializeAipexBase;
begin
  // 开发环境
  GAipexClient := TAipexBaseClient.Create('https://dev.aipexbase.com/api');
  
  // 生产环境
  // GAipexClient := TAipexBaseClient.Create('https://api.aipexbase.com');
end;
```

### 步骤 3: 实现登录功能

```pascal
uses
  UniBase.AipexBase.Client,
  UniBase.VCL.LoginDialog;

procedure TMainForm.DoLogin;
var
  LoginDlg: TVCLLoginDialog;
begin
  LoginDlg := TVCLLoginDialog.Create(Self);
  try
    LoginDlg.ApiClient := GAipexClient;
    if LoginDlg.ShowModal = mrOk then
    begin
      // 登录成功，保存 Token
      SaveToken(LoginDlg.LoginResult.Token);
      ShowMessage('欢迎, ' + LoginDlg.LoginResult.User.Username);
    end;
  finally
    LoginDlg.Free;
  end;
end;
```

### 步骤 4: 显示用户中心

```pascal
uses
  UniBase.VCL.UserProfileFrame,
  UniBase.VCL.BalanceFrame,
  UniBase.VCL.UsageStatsFrame,
  UniBase.VCL.BillingFrame;

procedure TMainForm.ShowUserCenter;
var
  ProfileFrame: TVCLUserProfileFrame;
begin
  ProfileFrame := TVCLUserProfileFrame.Create(Self);
  ProfileFrame.Parent := PanelContent;
  ProfileFrame.Align := alClient;
  ProfileFrame.ApiClient := GAipexClient;
  ProfileFrame.RefreshData;
end;
```

---

## FMX 应用集成

### 步骤 1: 添加搜索路径

```
D:\_Progs\02Business\UniBase\Core
D:\_Progs\02Business\UniBase\FMX
```

### 步骤 2: 使用 FMX 对话框

```pascal
uses
  UniBase.AipexBase.Client,
  UniBase.FMX.LoginDialog;

procedure TMainForm.DoLogin;
begin
  if TFMXLoginDialog.Execute(GAipexClient) then
  begin
    // 登录成功
    RefreshUserInterface;
  end;
end;
```

### 步骤 3: 嵌入 FMX Frame

```pascal
uses
  UniBase.FMX.BalanceFrame;

procedure TMainForm.ShowBalancePage;
var
  BalanceFrame: TFMXBalanceFrame;
begin
  BalanceFrame := TFMXBalanceFrame.Create(Self);
  BalanceFrame.Parent := LayoutContent;
  BalanceFrame.Align := TAlignLayout.Client;
  BalanceFrame.ApiClient := GAipexClient;
  BalanceFrame.RefreshData;
end;
```

---

## API 客户端方法参考

### TAipexBaseClient

#### 用户认证
```pascal
// 登录支持邮箱/手机/用户名作为登录标识
function Login(const Username, Password: string): TAipexLoginResult;
function Register(const Username, Email, Password, ConfirmPassword: string): TAipexLoginResult;
function ForgotPassword(const Email: string): Boolean;
function RefreshAccessToken: Boolean;
procedure Logout;
```

#### 用户信息
```pascal
function GetProfile: TAipexUser;
function UpdateProfile(const Request: TAipexUserUpdateRequest): Boolean;
function ChangePassword(const OldPassword, NewPassword: string): Boolean;
```

#### 余额与充值
```pascal
function GetBalance: TAipexBalance;
function CreateRecharge(Amount: Double; const PaymentMethod: string): TAipexRechargeResult;
function GetTransactions(Page, PageSize: Integer): TArray<TAipexTransaction>;
```

#### 用量统计
```pascal
function GetUsageStats(StartDate, EndDate: TDateTime): TAipexUsageSummary;
function GetDailyUsage(StartDate, EndDate: TDateTime): TArray<TAipexDailyUsage>;
```

#### 账单发票
```pascal
function GetInvoices(const Filter, Month: string; Page, PageSize: Integer): TArray<TAipexInvoice>;
function DownloadInvoice(const InvoiceId: string): TBytes;
function RequestInvoice(const InvoiceIds: TArray<string>): Boolean;
```

---

## 异常处理

```pascal
uses
  UniBase.AipexBase.Client;

try
  Result := GAipexClient.Login(Email, Password);
except
  on E: EAipexBaseAuthError do
    ShowMessage('认证失败: ' + E.Message);
  on E: EAipexBaseValidationError do
    ShowMessage('参数错误: ' + E.Message);
  on E: EAipexBaseNotFoundError do
    ShowMessage('资源不存在: ' + E.Message);
  on E: EAipexBaseError do
    ShowMessage('服务器错误: ' + E.Message);
  on E: Exception do
    ShowMessage('网络错误: ' + E.Message);
end;
```

---

## 测试连接

### 方法 1: 使用演示程序

```
VCL: Examples/UserAuthDemo/UserAuthDemo.dpr
FMX: Tools/Studio - 用户中心页面
```

### 方法 2: 代码测试

```pascal
procedure TestAipexBaseConnection;
var
  Client: TAipexBaseClient;
begin
  Client := TAipexBaseClient.Create('https://dev.aipexbase.com/api');
  try
    // 测试注册（使用测试邮箱）
    try
      Client.Register('testuser', 'test@example.com', 'Test123456', 'Test123456');
      WriteLn('注册成功');
    except
      on E: Exception do
        WriteLn('注册失败: ' + E.Message);
    end;
    
    // 测试登录
    try
      var LoginResult := Client.Login('test@example.com', 'Test123456');
      if LoginResult.Success then
        WriteLn('登录成功, Token: ' + Copy(LoginResult.Token, 1, 20) + '...')
      else
        WriteLn('登录失败: ' + LoginResult.ErrorMessage);
    except
      on E: Exception do
        WriteLn('登录错误: ' + E.Message);
    end;
  finally
    Client.Free;
  end;
end;
```

---

## 真实支付测试

> **警告**: 以下操作涉及真实付款，请谨慎操作！

### 沙箱环境测试
1. 使用开发服务器: `https://dev.aipexbase.com/api`
2. 充值金额不会真实扣款
3. 支付宝/微信会跳转到沙箱支付页面

### 生产环境测试
1. 使用生产服务器: `https://api.aipexbase.com`
2. 充值金额会真实扣款
3. 建议先使用最小金额（¥1）测试

### 支付流程
1. 调用 `CreateRecharge(Amount, PaymentMethod)`
2. 服务器返回支付链接/二维码
3. 用户完成支付
4. 调用 `GetBalance` 刷新余额

---

## 配置项

### 服务器地址

- **本地开发**: `http://localhost:8090`
- **生产环境**: `https://api.aipexbase.com`

### 本地存储

建议使用 UniBase.Config 保存用户凭证：

```pascal
uses
  UniBase.Config;

// 保存 Token
TUniConfig.Current.SetString('aipexbase.token', Token);
TUniConfig.Current.SetString('aipexbase.refresh_token', RefreshToken);

// 读取 Token
Token := TUniConfig.Current.GetString('aipexbase.token', '');
```

---

## 常见问题

### Q1: 连接超时
- 检查网络连接
- 确认服务器地址正确
- 检查防火墙设置

### Q2: 401 认证失败
- Token 可能已过期，尝试 RefreshToken
- 重新登录获取新 Token

### Q3: 余额不更新
- 支付完成后需要调用 GetBalance 刷新
- 支付可能有延迟，稍后重试

### Q4: 编译错误
- 确认搜索路径包含 `UniBase\Core` 和 `UniBase\VCL`（或 `FMX`）
- 确认引用了必要的单元

---

## 下一步

1. 运行演示程序测试连接
2. 在沙箱环境测试支付流程
3. 集成到您的应用中
4. 切换到生产环境
