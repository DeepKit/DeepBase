# AboutFrame 集成实施指南

> **文档版本**: 1.0
> **创建日期**: 2025-12-11
> **用途**: 指导各工具项目快速接入 UniBase AboutFrame

---

## 快速开始

### 前置条件
- UniBase 项目已编译
- SeedTool 可用 (`UniBase/Tools/SeedTool/SeedTool.exe`)
- 准备好 6 张标准图片资源
- 应用启动时需初始化 `UniBase.AntiTamper`（`EncryptionKey/Salt/KdfIterations/EnableHMAC` 必须与 SeedTool 播种一致）

### 标准图片资源清单

在开始任何项目集成前，请准备以下图片（建议 PNG 格式，300x300 像素）：

| 文件名 | ImageKey | 用途 |
|--------|----------|------|
| `official_gzh.png` | `official_gzh` | 公司公众号二维码 |
| `wechat.png` | `wechat` | 微信收款码 |
| `alipay.png` | `alipay` | 支付宝收款码 |
| `btc.png` | `btc` | BTC 钱包二维码 |
| `usdt.png` | `usdt` | USDT 钱包二维码 |
| `aboutme.png` | `aboutme` | 开发者照片/名片 |

图片可放在任意目录，使用 SeedTool GUI 直接导入即可（本仓库未强制要求固定 assets 目录）。

---

## 项目 1: TwoKeyRun (VCL)

### 状态: 已有 FrameAboutMe，需切换数据源

### 步骤 1: 创建配置数据库 (SeedTool)

```
1. 运行 SeedTool.exe
2. 点击 "选择数据库" → 浏览到 D:\_Progs\02Business\TwoKeyRun\
3. 输入文件名: TwoKeyRunConfig.db (会自动创建)
4. 点击 "初始化表" 按钮创建 aboutMeImages 表
5. 逐个导入 6 张图片:
   - 选择图片文件
   - 输入对应的 ImageKey (如 official_gzh)
   - 输入地址文本 (BTC/USDT 需要填写钱包地址)
   - 勾选 Enabled
   - 点击 "播种"
6. 验证: 点击 "查看数据" 确认 6 条记录存在
```

### 步骤 2: 接入 UniBase.VCL.AboutFrame（推荐）

TwoKeyRun 当前已有自定义 About UI。为减少维护成本，建议直接替换为 UniBase 提供的统一 AboutFrame。

#### 2.1 新建 About 窗口（或在现有页面中嵌入 Frame）

**推荐方式**：新建 `AboutForm.pas`，内部放置 `TUniAboutFrame`。

```pascal
uses
  System.SysUtils,
  Vcl.Forms,
  Vcl.Controls,
  UniBase.AntiTamper,
  UniBase.VCL.AboutFrame;

procedure TMainForm.ShowAbout;
var
  Frame: TUniAboutFrame;
  Config: TAntiTamperConfig;
  DbPath: string;
begin
  // 1) AntiTamper 初始化（参数必须与 SeedTool 播种时一致）
  Config := TAntiTamperPackage.GetDefaultConfig;
  Config.EncryptionKey := 'TwoKeyRun_AntiTamper_Key_2025';
  Config.Salt := 'TwoKeyRun_Salt_v1';
  Config.KdfIterations := 10000;
  Config.EnableHMAC := True;
  TAntiTamperPackage.Initialize(Config);

  // 2) DB1：{AppName}Config.db
  DbPath := ExtractFilePath(ParamStr(0)) + 'TwoKeyRunConfig.db';

  // 3) 创建并显示 AboutFrame
  Frame := TUniAboutFrame.Create(Self);
  Frame.Parent := Self; // 或者某个 Panel
  Frame.Align := alClient;
  Frame.DatabasePath := DbPath;
  Frame.ManualInitialize;
end;
```

> 说明：如果 TwoKeyRun 必须保留现有自定义 UI（Skia 等），需要按相同算法从 `aboutMeImages.image_data` 解密并校验 `sha256_hash/hmac_sha256`。可参考 `Core/UniBase.AntiTamper.pas` 的实现。

### 步骤 3: 更新项目搜索路径

在 Delphi IDE 中，添加 UniBase 路径到项目搜索路径：
- `D:\_Progs\02Business\UniBase\Core`
- `D:\_Progs\02Business\UniBase\VCL`

### 步骤 4: 验证

- [ ] 编译通过
- [ ] TwoKeyRunConfig.db 存在于程序目录
- [ ] 启动程序，About 页面显示所有图片
- [ ] BTC/USDT 地址复制功能正常
- [ ] 机器码显示正常

---

## 项目 2: SVGThing (VCL)

### 状态: 已有 FrameAboutMe，需切换数据源

### 步骤 1: 创建配置数据库 (SeedTool)

```
1. 运行 SeedTool.exe
2. 选择数据库路径: D:\_Progs\02Business\SVGThing\
3. 输入文件名: SVGThingConfig.db
4. 初始化表并播种 6 张图片 (同 TwoKeyRun)
```

### 步骤 2: 修改 FrameAboutMe.pas

**文件位置**: `D:\_Progs\02Business\SVGThing\FrameAboutMe.pas`

#### 2.1 修改 uses 区域

VCL 项目推荐直接使用 `UniBase.VCL.AboutFrame`（配合 `UniBase.AntiTamper` 初始化）。

```pascal
uses
  // ... 现有引用 ...
  UniBase.AntiTamper,
  UniBase.VCL.AboutFrame;
```

#### 2.2 修改数据库路径

找到 `InitializeDataManager` 或数据库连接代码，修改路径：

```pascal
// 旧: FDConnection1.Params.Database := GetProjectRootPath + 'data.db';
// 新:
FDConnection1.Params.Database := GetProjectRootPath + 'SVGThingConfig.db';
```

#### 2.3 修改图片加载（同 TwoKeyRun）

将 `LoadAndDisplayImages` 中的图片加载改为使用 `TAntiTamperPackage.LoadSecureImage`。

### 步骤 3: 更新项目搜索路径

添加 UniBase 路径（同 TwoKeyRun）。

### 步骤 4: 验证

- [ ] 编译通过
- [ ] SVGThingConfig.db 存在
- [ ] About 页面图片显示正常
- [ ] Tab 轮播功能正常

---

## 项目 3: TransSuccess (VCL)

### 状态: 无 AboutFrame，需新建

### 步骤 1: 创建配置数据库 (SeedTool)

```
1. 运行 SeedTool.exe
2. 选择数据库路径: D:\_Progs\02Business\TransSuccess\
3. 输入文件名: TransSuccessConfig.db
4. 初始化表并播种 6 张图片
```

### 步骤 2: 创建 AboutForm.pas

在 TransSuccess 项目中新建文件 `AboutForm.pas`：

```pascal
unit AboutForm;

interface

uses
  System.Classes, System.SysUtils,
  Vcl.Controls, Vcl.Forms,
  UniBase.AntiTamper,
  UniBase.VCL.AboutFrame;

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

  // AntiTamper 初始化（参数必须与 SeedTool 播种时一致）
  Config := TAntiTamperPackage.GetDefaultConfig;
  Config.EncryptionKey := 'TransSuccess_AntiTamper_Key_2025';
  Config.Salt := 'TransSuccess_Salt_v1';
  Config.KdfIterations := 10000;
  Config.EnableHMAC := True;
  TAntiTamperPackage.Initialize(Config);

  FAboutFrame := TUniAboutFrame.Create(Self);
  FAboutFrame.Parent := Self;
  FAboutFrame.Align := alClient;
  FAboutFrame.DatabasePath := ExtractFilePath(ParamStr(0)) + 'TransSuccessConfig.db';
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

### 步骤 4: 在主窗体添加菜单项

在 `ViewMainCode.pas` 的主菜单中添加：

```pascal
// 在主菜单的 "帮助" 菜单下添加 "关于" 项
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
  UniBase.VCL.AboutFrame;
```

### 步骤 6: 更新项目搜索路径

添加 UniBase 路径。

### 步骤 7: 验证

- [ ] 编译通过
- [ ] TransSuccessConfig.db 存在
- [ ] 帮助菜单显示 "关于" 项
- [ ] 点击弹出 About 窗口
- [ ] 图片显示正常

---

## 项目 4: OmniSync (FMX)

### 状态: 无 AboutFrame，依赖 FMX 组件对齐后集成

### 前置任务: 对齐 UniBase.FMX.AboutFrame.pas（与 SeedTool/AntiTamper）

`FMX/UniBase.FMX.AboutFrame.pas` 已存在，但需要先对齐字段名/解密/sha256+hmac 校验逻辑，确保可读取 SeedTool 播种的数据后再在 OmniSync 集成。

### 步骤 1: 创建配置数据库 (SeedTool)

```
1. 运行 SeedTool.exe
2. 选择数据库路径: D:\_Progs\02Business\OmniSync\
3. 输入文件名: OmniSyncConfig.db
4. 初始化表并播种 6 张图片
```

### 步骤 2: 在侧边栏添加导航项

修改 `uSidePanelFrame.pas`，添加 "关于" 导航项。

### 步骤 3: 集成 FMX AboutFrame

在 `uMainForm.pas` 中添加 AboutFrame 容器和显示逻辑。

### 步骤 4: 验证

- [ ] 编译通过
- [ ] OmniSyncConfig.db 存在
- [ ] 侧边栏显示 "关于" 导航
- [ ] 点击显示 About 页面

---

## 项目 5: Stocks/InfoCenter (FMX)

### 状态: 无 AboutFrame，依赖 FMX 组件

### 步骤 1: 扩展现有配置数据库 (SeedTool)

```
1. 运行 SeedTool.exe
2. 选择现有数据库: D:\_Progs\02Business\Stocks\07-InformationCenter\InfoCenterConfig.db
3. 初始化 aboutMeImages 表 (表不存在则创建)
4. 播种 6 张图片
```

### 步骤 2: 在设置或帮助菜单添加入口

修改 `ViewMain.pas` 或 `SettingsForm.pas`。

### 步骤 3: 集成 FMX AboutFrame

复用 OmniSync 的集成模式。

### 步骤 4: 验证

- [ ] 编译通过
- [ ] aboutMeImages 表存在于 InfoCenterConfig.db
- [ ] 菜单显示 "关于" 入口
- [ ] About 页面显示正常

---

## FMX 组件开发（✅ 已完成对齐）

### UniBase.FMX.AboutFrame.pas

文件位置：`D:\_Progs\02Business\UniBase\FMX\UniBase.FMX.AboutFrame.pas`

当前实现提供：
- FMX 原生 `TTabControl` + `TTabItem` 布局（6 个 Tab 页）
- 支持 `DatabasePath` 属性配置
- 根据 `enabled` 字段动态显示/隐藏 Tab
- BTC/USDT 地址复制功能
- 机器码生成与显示
- 使用 `TAntiTamperPackage.LoadSecureImageBytes()` 统一解密和校验
- 字段名与 SeedTool/AntiTamper 一致：`sha256_hash`、`hmac_sha256`

### 使用示例（OmniSync/Stocks）

```pascal
uses
  UniBase.AntiTamper,
  UniBase.FMX.AboutFrame;

procedure TMainForm.ShowAboutFrame;
var
  Frame: TFMXAboutFrame;
  Config: TAntiTamperConfig;
begin
  Config := TAntiTamperPackage.GetDefaultConfig;
  Config.EncryptionKey := 'OmniSync_AntiTamper_Key_2025';
  Config.Salt := 'OmniSync_Salt_v1';
  Config.KdfIterations := 10000;
  Config.EnableHMAC := True;
  TAntiTamperPackage.Initialize(Config);

  Frame := TFMXAboutFrame.Create(Self);
  Frame.Parent := SomeContainer;  // 或 Self
  Frame.Align := TAlignLayout.Client;
  Frame.DatabasePath := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'OmniSyncConfig.db');
  Frame.Initialize;
end;
```

---

## SeedTool 快速参考

### 命令行模式 (批量操作)

当前仓库内的 SeedTool 以 GUI 方式使用（未实现 CLI 参数）。如需批量化能力，请在后续单独实现 CLI 或提供脚本化入口。

### GUI 模式操作流程

1. **选择数据库**: 浏览或输入 `.db` 文件路径
2. **初始化表**: 点击按钮创建 `aboutMeImages` 表
3. **导入图片**:
   - 选择图片文件
   - 输入 ImageKey
   - 输入地址文本 (可选)
   - 勾选 Enabled
   - 点击 "播种"
4. **验证数据**: 点击 "查看数据" 检查记录

---

## 常见问题

### Q1: 图片不显示
- 检查 `*.Config.db` 文件是否存在于程序目录
- 检查 ImageKey 是否正确 (大小写敏感)
- 检查 `enabled` 字段是否为 1

### Q2: 编译报错找不到 UniBase 单元
- 确认项目搜索路径包含 `UniBase\Core` 和 `UniBase\VCL`（或 `UniBase\FMX`）

### Q3: sha256 / hmac 校验失败（或图片解密失败）
- 确认应用启动时调用 `TAntiTamperPackage.Initialize(...)`，且参数与 SeedTool 播种时一致（EncryptionKey/Salt/KdfIterations/EnableHMAC）
- 重新使用 SeedTool 播种图片（确保写入 `sha256_hash`/`hmac_sha256` 且 `image_data` 非空）
- 确认数据库表字段名为 `sha256_hash`/`hmac_sha256`（不是 `hmac_signature`）

### Q4: FMX 项目如何使用？
- FMX AboutFrame 已与 `UniBase.AntiTamper`/SeedTool 协议对齐，可直接用于 OmniSync/Stocks
- 使用方式与 VCL 版本类似，参考上方示例代码

---

## 任务检查清单

### 人工任务 (由您完成)
- [ ] 准备 6 张标准图片资源
- [ ] 运行 SeedTool 创建各项目的 Config.db
- [ ] 在 IDE 中编译测试各项目

### 仓库侧（UniBase）已提供/待办
- [x] VCL 版 AboutFrame（`TUniAboutFrame`）
- [x] SeedTool（GUI）播种
- [x] 本文档与集成规划文档
- [x] FMX 版 AboutFrame 与 AntiTamper/SeedTool 协议对齐（2025-12-12 已完成）
- [ ] 各工具项目手工集成与验证

---

## 下一步

建议按以下顺序推进：

1. ~~**先对齐 FMX AboutFrame**~~（✅ 已完成）
2. **完成 VCL 项目集成**（TwoKeyRun/SVGThing/TransSuccess）并验证图片可显示
3. **完成 FMX 项目集成**（OmniSync/Stocks）并验证
4. **统一跑测试**（`Scripts/run_tests.ps1`）确保回归通过
