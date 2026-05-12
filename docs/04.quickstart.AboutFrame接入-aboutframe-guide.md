# AboutFrame 集成实施指南

> **文档版本**: 1.0
> **创建日期**: 2025-12-11
> **用�?*: 指导各工具项目快速接�?DeepBase AboutFrame

---

## 快速开�?

### 前置条件
- DeepBase 项目已编�?
- SeedTool 可用 (`DeepBase/Tools/SeedTool/SeedTool.exe`)
- 准备�?6 张标准图片资�?
- 应用启动时需初始�?`DeepBase.AntiTamper`（`EncryptionKey/Salt/KdfIterations/EnableHMAC` 必须�?SeedTool 播种一致）

### 标准图片资源清单

在开始任何项目集成前，请准备以下图片（建�?PNG 格式�?00x300 像素）：

| 文件�?| ImageKey | 用�?|
|--------|----------|------|
| `official_gzh.png` | `official_gzh` | 公司公众号二维码 |
| `wechat.png` | `wechat` | 微信收款�?|
| `alipay.png` | `alipay` | 支付宝收款码 |
| `btc.png` | `btc` | BTC 钱包二维�?|
| `usdt.png` | `usdt` | USDT 钱包二维�?|
| `aboutme.png` | `aboutme` | 开发者照�?名片 |

图片可放在任意目录，使用 SeedTool GUI 直接导入即可（本仓库未强制要求固�?assets 目录）�?

---

## 项目 1: TwoKeyRun (VCL)

### 状�? 已有 FrameAboutMe，需切换数据�?

### 步骤 1: 创建配置数据�?(SeedTool)

```
1. 运行 SeedTool.exe
2. 点击 "选择数据�? �?浏览�?D:\_Progs\02Business\TwoKeyRun\
3. 输入文件�? TwoKeyRunConfig.db (会自动创�?
4. 点击 "初始化表" 按钮创建 aboutMeImages �?
5. 逐个导入 6 张图�?
   - 选择图片文件
   - 输入对应�?ImageKey (�?official_gzh)
   - 输入地址文本 (BTC/USDT 需要填写钱包地址)
   - 勾�?Enabled
   - 点击 "播种"
6. 验证: 点击 "查看数据" 确认 6 条记录存�?
```

### 步骤 2: 接入 DeepBase.VCL.AboutFrame（推荐）

TwoKeyRun 当前已有自定�?About UI。为减少维护成本，建议直接替换为 DeepBase 提供的统一 AboutFrame�?

#### 2.1 新建 About 窗口（或在现有页面中嵌入 Frame�?

**推荐方式**：新�?`AboutForm.pas`，内部放�?`TUniAboutFrame`�?

```pascal
uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  DeepBase.AntiTamper,
  DeepBase.VCL.AboutFrame;

procedure TMainForm.ShowAbout;
var
  Frame: TUniAboutFrame;
  Config: TAntiTamperConfig;
  DbPath: string;
begin
  // 1) AntiTamper 初始化（参数必须�?SeedTool 播种时一致）
  Config := TAntiTamperPackage.GetDefaultConfig;
  // TwoKeyRun 现有工程里已使用 @2241114 作为密码/口令（DB/Debug 等）；这里复用它作为 AntiTamper �?EncryptionKey
  Config.EncryptionKey := '@2241114';
  Config.Salt := 'TwoKeyRun_Salt_v1';
  Config.KdfIterations := 10000;
  Config.EnableHMAC := True;
  TAntiTamperPackage.Initialize(Config);

  // 2) DB1：{AppName}Config.db
  DbPath := ExtractFilePath(ParamStr(0)) + 'TwoKeyRunConfig.db';

  // 3) 创建并显�?AboutFrame
  Frame := TUniAboutFrame.Create(Self);
  Frame.Parent := Self; // 或者某�?Panel
  Frame.Align := alClient;
  Frame.DatabasePath := DbPath;
  Frame.ManualInitialize;
end;
```

> 说明：如�?TwoKeyRun 必须保留现有自定�?UI（Skia 等），需要按相同算法�?`aboutMeImages.image_data` 解密并校�?`sha256_hash/hmac_sha256`。可参�?`Features/DeepBase.AntiTamper.pas` 的实现�?
### 步骤 3: 更新项目搜索路径

�?Delphi IDE 中，添加 DeepBase 路径到项目搜索路径：
- `D:\_Progs\02Business\DeepBase\Core`
- `D:\_Progs\02Business\DeepBase\VCL`

### 步骤 4: 验证

- [ ] 编译通过
- [ ] TwoKeyRunConfig.db 存在于程序目�?
- [ ] 启动程序，About 页面显示所有图�?
- [ ] BTC/USDT 地址复制功能正常
- [ ] 机器码显示正�?

---

## 项目 2: SVGThing (VCL)

### 状�? 已有 FrameAboutMe，需切换数据�?

### 步骤 1: 创建配置数据�?(SeedTool)

```
1. 运行 SeedTool.exe
2. 选择数据库路�? D:\_Progs\02Business\SVGThing\
3. 输入文件�? SVGThingConfig.db
4. 初始化表并播�?6 张图�?(�?TwoKeyRun)
```

### 步骤 2: 修改 FrameAboutMe.pas

**文件位置**: `D:\_Progs\02Business\SVGThing\FrameAboutMe.pas`

#### 2.1 修改 uses 区域

VCL 项目推荐直接使用 `DeepBase.VCL.AboutFrame`（配�?`DeepBase.AntiTamper` 初始化）�?

```pascal
uses
  // ... 现有引用 ...
  DeepBase.AntiTamper,
  DeepBase.VCL.AboutFrame;
```

#### 2.2 修改数据库路�?

找到 `InitializeDataManager` 或数据库连接代码，修改路径：

```pascal
// �? FDConnection1.Params.Database := GetProjectRootPath + 'data.db';
// �?
FDConnection1.Params.Database := GetProjectRootPath + 'SVGThingConfig.db';
```

#### 2.3 修改图片加载（同 TwoKeyRun�?

�?`LoadAndDisplayImages` 中的图片加载改为使用 `TAntiTamperPackage.LoadSecureImage`�?

### 步骤 3: 更新项目搜索路径

添加 DeepBase 路径（同 TwoKeyRun）�?

### 步骤 4: 验证

- [ ] 编译通过
- [ ] SVGThingConfig.db 存在
- [ ] About 页面图片显示正常
- [ ] Tab 轮播功能正常

---

## 项目 3: DeepCharset (VCL)

### 状�? �?AboutFrame，需新建

### 步骤 1: 创建配置数据�?(SeedTool)

```
1. 运行 SeedTool.exe
2. 选择数据库路�? D:\_Progs\02Business\DeepCharset\
3. 输入文件�? DeepCharsetConfig.db
4. 初始化表并播�?6 张图�?
```

### 步骤 2: 创建 AboutForm.pas

�?DeepCharset 项目中新建文�?`AboutForm.pas`�?

```pascal
unit AboutForm;

interface

uses
  System.Classes, System.SysUtils,
  Vcl.Controls, Vcl.Forms,
  DeepBase.AntiTamper,
  DeepBase.VCL.AboutFrame;

type
  TfrmAbout = class(TForm)
  private
    FAboutFrame: TUniAboutFrame;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  frmAbout: TfrmAbout;

implementation

{$R *.dfm}

constructor TfrmAbout.Create(AOwner: TComponent);
var
  Config: TAntiTamperConfig;
begin
  inherited;
  Caption := '关于 码到成功';
  Width := 520;
  Height := 620;
  Position := poMainFormCenter;
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];

  // AntiTamper 初始化（参数必须�?SeedTool 播种时一致）
  Config := TAntiTamperPackage.GetDefaultConfig;
  Config.EncryptionKey := 'DeepCharset_AntiTamper_Key_2025';
  Config.Salt := 'DeepCharset_Salt_v1';
  Config.KdfIterations := 10000;
  Config.EnableHMAC := True;
  TAntiTamperPackage.Initialize(Config);

  FAboutFrame := TUniAboutFrame.Create(Self);
  FAboutFrame.Parent := Self;
  FAboutFrame.Align := alClient;
  FAboutFrame.DatabasePath := ExtractFilePath(ParamStr(0)) + 'DeepCharsetConfig.db';
  FAboutFrame.ManualInitialize;
end;

end.
```

### 步骤 3: 创建 AboutForm.dfm

```dfm
object frmAbout: TfrmAbout
  Left = 0
  Top = 0
  Caption = '关于 码到成功'
  ClientHeight = 580
  ClientWidth = 500
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  PixelsPerInch = 96
end
```

### 步骤 4: 在主窗体添加菜单�?

�?`ViewMainCode.pas` 的主菜单中添加：

```pascal
// 在主菜单�?"帮助" 菜单下添�?"关于" �?
procedure TForm1.mnuAboutClick(Sender: TObject);
begin
  if not Assigned(frmAbout) then
    frmAbout := TfrmAbout.Create(Application);
  frmAbout.ShowModal;
end;
```

### 步骤 5: 更新 dpr 文件

```pascal
uses
  // ... 现有引用 ...
  AboutForm in 'AboutForm.pas' {frmAbout},
  DeepBase.VCL.AboutFrame;
```

### 步骤 6: 更新项目搜索路径

添加 DeepBase 路径�?

### 步骤 7: 验证

- [ ] 编译通过
- [ ] DeepCharsetConfig.db 存在
- [ ] 帮助菜单显示 "关于" �?
- [ ] 点击弹出 About 窗口
- [ ] 图片显示正常

---

## 项目 4: DeepSync (FMX)

### 状�? �?AboutFrame，依�?FMX 组件对齐后集�?

### 前置任务: 对齐 DeepBase.FMX.AboutFrame.pas（与 SeedTool/AntiTamper�?

`FMX/DeepBase.FMX.AboutFrame.pas` 已存在，但需要先对齐字段�?解密/sha256+hmac 校验逻辑，确保可读取 SeedTool 播种的数据后再在 DeepSync 集成�?

### 步骤 1: 创建配置数据�?(SeedTool)

```
1. 运行 SeedTool.exe
2. 选择数据库路�? D:\_Progs\02Business\DeepSync\
3. 输入文件�? DeepSyncConfig.db
4. 初始化表并播�?6 张图�?
```

### 步骤 2: 在侧边栏添加导航�?

修改 `uSidePanelFrame.pas`，添�?"关于" 导航项�?

### 步骤 3: 集成 FMX AboutFrame

�?`uMainForm.pas` 中添�?AboutFrame 容器和显示逻辑�?

### 步骤 4: 验证

- [ ] 编译通过
- [ ] DeepSyncConfig.db 存在
- [ ] 侧边栏显�?"关于" 导航
- [ ] 点击显示 About 页面

---

## 项目 5: Stocks/InfoCenter (FMX)

### 状�? �?AboutFrame，依�?FMX 组件

### 步骤 1: 扩展现有配置数据�?(SeedTool)

```
1. 运行 SeedTool.exe
2. 选择现有数据�? D:\_Progs\02Business\Stocks\07-InformationCenter\InfoCenterConfig.db
3. 初始�?aboutMeImages �?(表不存在则创�?
4. 播种 6 张图�?
```

### 步骤 2: 在设置或帮助菜单添加入口

修改 `ViewMain.pas` �?`SettingsForm.pas`�?

### 步骤 3: 集成 FMX AboutFrame

复用 DeepSync 的集成模式�?

### 步骤 4: 验证

- [ ] 编译通过
- [ ] aboutMeImages 表存在于 InfoCenterConfig.db
- [ ] 菜单显示 "关于" 入口
- [ ] About 页面显示正常

---

## FMX 组件开发（�?已完成对齐）

### DeepBase.FMX.AboutFrame.pas

文件位置：`D:\_Progs\02Business\DeepBase\FMX\DeepBase.FMX.AboutFrame.pas`

当前实现提供�?
- FMX 原生 `TTabControl` + `TTabItem` 布局�? �?Tab 页）
- 支持 `DatabasePath` 属性配�?
- 根据 `enabled` 字段动态显�?隐藏 Tab
- BTC/USDT 地址复制功能
- 机器码生成与显示
- 使用 `TAntiTamperPackage.LoadSecureImageBytes()` 统一解密和校�?
- 字段名与 SeedTool/AntiTamper 一致：`sha256_hash`、`hmac_sha256`

### 使用示例（DeepSync/Stocks�?

```pascal
uses
  DeepBase.AntiTamper,
  DeepBase.FMX.AboutFrame;

procedure TMainForm.ShowAboutFrame;
var
  Frame: TFMXAboutFrame;
  Config: TAntiTamperConfig;
begin
  Config := TAntiTamperPackage.GetDefaultConfig;
  Config.EncryptionKey := 'DeepSync_AntiTamper_Key_2025';
  Config.Salt := 'DeepSync_Salt_v1';
  Config.KdfIterations := 10000;
  Config.EnableHMAC := True;
  TAntiTamperPackage.Initialize(Config);

  Frame := TFMXAboutFrame.Create(Self);
  Frame.Parent := SomeContainer;  // �?Self
  Frame.Align := TAlignLayout.Client;
  Frame.DatabasePath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'DeepSyncConfig.db');
  Frame.Initialize;
end;
```

---

## SeedTool 快速参�?

### 命令行模�?(批量操作)

当前仓库内的 SeedTool �?GUI 方式使用（未实现 CLI 参数）。如需批量化能力，请在后续单独实现 CLI 或提供脚本化入口�?

### GUI 模式操作流程

1. **选择数据�?*: 浏览或输�?`.db` 文件路径
2. **初始化表**: 点击按钮创建 `aboutMeImages` �?
3. **导入图片**:
   - 选择图片文件
   - 输入 ImageKey
   - 输入地址文本 (可�?
   - 勾�?Enabled
   - 点击 "播种"
4. **验证数据**: 点击 "查看数据" 检查记�?

---

## 常见问题

### Q1: 图片不显�?
- 检�?`*.Config.db` 文件是否存在于程序目�?
- 检�?ImageKey 是否正确 (大小写敏�?
- 检�?`enabled` 字段是否�?1

### Q2: 编译报错找不�?DeepBase 单元
- 确认项目搜索路径包含 `DeepBase\Core` �?`DeepBase\VCL`（或 `DeepBase\FMX`�?

### Q3: sha256 / hmac 校验失败（或图片解密失败�?
- 确认应用启动时调�?`TAntiTamperPackage.Initialize(...)`，且参数�?SeedTool 播种时一致（EncryptionKey/Salt/KdfIterations/EnableHMAC�?
- 重新使用 SeedTool 播种图片（确保写�?`sha256_hash`/`hmac_sha256` �?`image_data` 非空�?
- 确认数据库表字段名为 `sha256_hash`/`hmac_sha256`（不�?`hmac_signature`�?

### Q4: FMX 项目如何使用�?
- FMX AboutFrame 已与 `DeepBase.AntiTamper`/SeedTool 协议对齐，可直接用于 DeepSync/Stocks
- 使用方式�?VCL 版本类似，参考上方示例代�?

---

## 任务检查清�?

### 人工任务 (由您完成)
- [ ] 准备 6 张标准图片资�?
- [ ] 运行 SeedTool 创建各项目的 Config.db
- [ ] �?IDE 中编译测试各项目

### 仓库侧（DeepBase）已提供/待办
- [x] VCL �?AboutFrame（`TUniAboutFrame`�?
- [x] SeedTool（GUI）播�?
- [x] 本文档与集成规划文档
- [x] FMX �?AboutFrame �?AntiTamper/SeedTool 协议对齐�?025-12-12 已完成）
- [ ] 各工具项目手工集成与验证

---

## 下一�?

建议按以下顺序推进：

1. ~~**先对�?FMX AboutFrame**~~（✅ 已完成）
2. **完成 VCL 项目集成**（TwoKeyRun/SVGThing/DeepCharset）并验证图片可显�?
3. **完成 FMX 项目集成**（DeepSync/Stocks）并验证
4. **统一跑测�?*（`Scripts/run_tests.ps1`）确保回归通过
