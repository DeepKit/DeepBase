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

将图片放置到：`D:\_Progs\02Business\UniBase\Tools\SeedTool\assets\`

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

### 步骤 2: 修改 FrameAboutMe.pas

**文件位置**: `D:\_Progs\02Business\TwoKeyRun\FrameAboutMe.pas`

#### 2.1 修改 uses 区域

```pascal
// 在 uses 中添加
uses
  // ... 现有引用 ...
  UniBase.Security;  // 添加这行
```

#### 2.2 修改构造函数中的数据库连接

找到构造函数 `Create`，修改安全管理器初始化：

```pascal
constructor TFrameAboutMe.Create(AOwner: TComponent; AController: IControllerMain);
begin
  inherited Create(AOwner);
  FController := AController;

  // 【修改】使用 TwoKeyRunConfig.db 而不是 TwoKeyRun.db
  FSecurityManager := TDatabaseSecurityManager.Create(
    ExtractFilePath(ParamStr(0)) + 'TwoKeyRunConfig.db', nil, nil);

  // ... 其余代码不变 ...
end;
```

#### 2.3 修改图片加载方法

找到 `LoadImageFromDB` 方法，替换为使用 UniBase 安全加载：

```pascal
procedure TFrameAboutMe.LoadImageFromDB(const ImageKey: string; TargetImage: TSkAnimatedImage);
var
  ImageStream: TMemoryStream;
  DBPath: string;
begin
  LogMessage(Format('LoadImageFromDB: 开始加载图片 - %s', [ImageKey]));

  if not Assigned(TargetImage) then
  begin
    LogMessage(Format('LoadImageFromDB: 目标图片控件不可用 - %s', [ImageKey]));
    Exit;
  end;

  DBPath := ExtractFilePath(ParamStr(0)) + 'TwoKeyRunConfig.db';
  ImageStream := TMemoryStream.Create;
  try
    // 【修改】使用 UniBase 的安全图片加载
    if TAntiTamperPackage.LoadSecureImage(DBPath, ImageKey, ImageStream) then
    begin
      LogMessage(Format('LoadImageFromDB: 安全加载成功 - %s, 大小: %d', [ImageKey, ImageStream.Size]));
      ImageStream.Position := 0;
      TargetImage.LoadFromStream(ImageStream);
    end
    else
    begin
      LogMessage(Format('LoadImageFromDB: 图片不存在或验证失败 - %s', [ImageKey]));
    end;
  finally
    ImageStream.Free;
  end;
end;
```

#### 2.4 修改 LoadAllImages 方法

确保使用标准 ImageKey：

```pascal
procedure TFrameAboutMe.LoadAllImages;
begin
  // 使用标准 ImageKey
  LoadImageFromDB('wechat', imgWechat);
  LoadImageFromDB('alipay', imgAlipay);
  LoadImageFromDB('btc', imgBTC);
  LoadImageFromDB('usdt', imgUSDT);
  LoadImageFromDB('aboutme', imgAboutMe);
  // 如需公众号页签，添加: LoadImageFromDB('official_gzh', imgOfficialGzh);
end;
```

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

```pascal
uses
  // ... 现有引用 ...
  // 【移除】 uAntiTamperPackage, uBasicProtection  // 旧版
  UniBase.Security;  // 【添加】新版
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
  Vcl.Forms, Vcl.Controls, System.Classes, System.SysUtils,
  UniBase.VCL.AboutFrame;

type
  TfrmAbout = class(TForm)
  private
    FAboutFrame: TAboutFrame;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  frmAbout: TfrmAbout;

implementation

{$R *.dfm}

constructor TfrmAbout.Create(AOwner: TComponent);
begin
  inherited;
  Caption := '关于 码到成功';
  Width := 520;
  Height := 620;
  Position := poMainFormCenter;
  BorderStyle := bsSingle;
  BorderIcons := [biSystemMenu];

  FAboutFrame := TAboutFrame.Create(Self);
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

### 状态: 无 AboutFrame，需开发 FMX 版组件

### 前置任务: 创建 UniBase.FMX.AboutFrame.pas

**此任务由 Claude 完成**，见下方 "FMX 组件开发" 章节。

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

## FMX 组件开发 ✅

### UniBase.FMX.AboutFrame.pas

**已完成**，文件位置：`D:\_Progs\02Business\UniBase\FMX\UniBase.FMX.AboutFrame.pas`

此组件提供：
- FMX 原生 `TTabControl` + `TTabItem` 布局 (6 个 Tab 页)
- 与 VCL 版相同的功能接口
- 支持 `DatabasePath` 属性配置
- HMAC-SHA256 签名验证
- 根据 `enabled` 字段动态显示/隐藏 Tab
- BTC/USDT 地址复制功能
- 机器码生成与显示

### 使用示例 (OmniSync/Stocks)

```pascal
uses
  UniBase.FMX.AboutFrame;

procedure TMainForm.ShowAboutFrame;
var
  Frame: TFMXAboutFrame;
begin
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

```powershell
cd D:\_Progs\02Business\UniBase\Tools\SeedTool

# 初始化数据库
.\SeedTool.exe --init --db "C:\MyApp\AppConfig.db"

# 批量播种
.\SeedTool.exe --seed --db "C:\MyApp\AppConfig.db" --dir ".\assets" --keys "official_gzh,wechat,alipay,btc,usdt,aboutme"
```

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

### Q3: HMAC 签名验证失败
- 重新使用 SeedTool 播种图片
- 确保播种时使用的机器与运行程序的机器一致

### Q4: FMX 项目如何使用？
- 等待 `UniBase.FMX.AboutFrame.pas` 开发完成
- 或先完成 VCL 项目的集成

---

## 任务检查清单

### 人工任务 (由您完成)
- [ ] 准备 6 张标准图片资源
- [ ] 运行 SeedTool 创建各项目的 Config.db
- [ ] 在 IDE 中编译测试各项目

### 自动任务 (由 Claude 完成)
- [x] TwoKeyRun 集成代码修改说明
- [x] SVGThing 集成代码修改说明
- [x] TransSuccess 集成代码 (AboutForm.pas)
- [x] UniBase.FMX.AboutFrame.pas 开发 ✅
- [x] OmniSync 集成说明
- [x] Stocks/InfoCenter 集成说明

---

## 下一步

所有代码已准备完毕，您只需完成以下人工任务：

1. **准备图片资源** - 6 张标准图片
2. **运行 SeedTool** - 为各项目创建 Config.db 并播种图片
3. **在 IDE 中集成** - 按本文档修改各项目代码
4. **编译测试** - 验证 About 页面显示正常

如有问题，参考“常见问题”章节或联系开发者。
