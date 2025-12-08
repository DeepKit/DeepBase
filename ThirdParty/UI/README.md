# UniBase UI Theme Package

现代化 VCL 应用主题系统，支持 Material Design、Fluent Design 和 macOS 风格主题。

## 内置主题

### Material Design

| 主题 | 配色方案 |
|------|----------|
| `MaterialLight` | 浅色基础 |
| `MaterialDark` | 深色基础 |
| `MaterialBlueLight` | 蓝色浅色 |
| `MaterialBlueDark` | 蓝色深色 |
| `MaterialIndigoLight` | 靛蓝浅色 |
| `MaterialIndigoDark` | 靛蓝深色 |
| `MaterialTealLight` | 青色浅色 |
| `MaterialTealDark` | 青色深色 |
| `MaterialDeepOrangeLight` | 深橙浅色 |
| `MaterialDeepOrangeDark` | 深橙深色 |

### Fluent Design (Windows 11)

| 主题 | 配色方案 |
|------|----------|
| `FluentLight` | 浅色 |
| `FluentDark` | 深色 |
| `FluentAcrylicLight` | 亚克力浅色 |
| `FluentAcrylicDark` | 亚克力深色 |

### macOS Style

| 主题 | 配色方案 |
|------|----------|
| `MacOSLight` | 浅色 |
| `MacOSDark` | 深色 |
| `MacOSBigSurLight` | Big Sur 浅色 |
| `MacOSBigSurDark` | Big Sur 深色 |

## 使用示例

### 初始化

```pascal
uses UniBase.UI.Themes;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  // 注册所有内置主题
  RegisterBuiltInThemes;
  
  // 应用默认主题
  TUniBaseThemeManager.ApplyTheme('MaterialLight');
end;
```

### 切换主题

```pascal
// 切换到深色主题
TUniBaseThemeManager.ApplyTheme('MaterialDark');

// 切换明暗模式
TUniBaseThemeManager.ToggleDarkMode;

// 检查当前是否深色
if TUniBaseThemeManager.IsDarkTheme then
  // ...
```

### 监听主题变化

```pascal
procedure TMainForm.FormCreate(Sender: TObject);
begin
  TUniBaseThemeManager.OnThemeChange := OnThemeChanged;
end;

procedure TMainForm.OnThemeChanged(Sender: TObject; const AThemeName: string);
begin
  // 主题已切换
  UpdateUI;
end;
```

### 获取当前主题颜色

```pascal
var
  Colors: TThemeColors;
begin
  Colors := TUniBaseThemeManager.GetCurrentColors;
  
  Panel1.Color := Colors.Surface;
  Panel1.Font.Color := Colors.OnSurface;
  
  Button1.Color := Colors.Primary;
  Button1.Font.Color := Colors.OnPrimary;
end;
```

### 自定义主题

```pascal
var
  MyTheme: TThemeDefinition;
begin
  MyTheme.Name := 'MyCustomTheme';
  MyTheme.DisplayName := 'My Custom Theme';
  MyTheme.Version := '1.0';
  MyTheme.Author := 'Me';
  MyTheme.ColorScheme := tcsLight;
  
  // 自定义颜色
  MyTheme.Colors := TThemeColors.Light;
  MyTheme.Colors.Primary := $FF5722;  // Deep Orange
  MyTheme.Colors.Secondary := $03A9F4; // Light Blue
  
  // 自定义字体
  MyTheme.Typography := TThemeTypography.Default;
  MyTheme.Typography.FontFamily := 'Microsoft YaHei UI';
  
  // 自定义间距
  MyTheme.Spacing := TThemeSpacing.Default;
  MyTheme.Spacing.BorderRadius := 8;
  
  // 关联 VCL 样式
  MyTheme.VclStyleName := 'Cobalt XEMedia';
  
  // 注册并应用
  TUniBaseThemeManager.RegisterTheme(MyTheme);
  TUniBaseThemeManager.ApplyTheme('MyCustomTheme');
end;
```

## 颜色配置

```pascal
TThemeColors = record
  Primary: TColor;        // 主色
  PrimaryLight: TColor;   // 主色浅
  PrimaryDark: TColor;    // 主色深
  Secondary: TColor;      // 次要色
  Background: TColor;     // 背景色
  Surface: TColor;        // 表面色
  Error: TColor;          // 错误色
  OnPrimary: TColor;      // 主色上的文字
  OnSecondary: TColor;    // 次要色上的文字
  OnBackground: TColor;   // 背景上的文字
  OnSurface: TColor;      // 表面上的文字
  OnError: TColor;        // 错误色上的文字
  Border: TColor;         // 边框
  Divider: TColor;        // 分隔线
  Shadow: TColor;         // 阴影
  Overlay: TColor;        // 遮罩
end;
```

## 字体配置

```pascal
TThemeTypography = record
  FontFamily: string;      // 字体家族
  FontSizeH1: Integer;     // 标题1 (32)
  FontSizeH2: Integer;     // 标题2 (24)
  FontSizeH3: Integer;     // 标题3 (20)
  FontSizeH4: Integer;     // 标题4 (16)
  FontSizeBody: Integer;   // 正文 (14)
  FontSizeCaption: Integer;// 说明 (12)
  FontSizeButton: Integer; // 按钮 (14)
  LineHeight: Double;      // 行高 (1.5)
  LetterSpacing: Double;   // 字间距
end;
```

## 间距配置

```pascal
TThemeSpacing = record
  XS: Integer;         // 4px
  SM: Integer;         // 8px
  MD: Integer;         // 16px
  LG: Integer;         // 24px
  XL: Integer;         // 32px
  XXL: Integer;        // 48px
  BorderRadius: Integer; // 圆角
  BorderWidth: Integer;  // 边框宽度
end;
```

## 辅助函数

```pascal
// 颜色转 Hex
var Hex := ColorToHex(clRed);  // '#FF0000'

// Hex 转颜色
var Color := HexToColor('#2196F3');

// 混合颜色
var Blended := BlendColors(clWhite, clBlack, 128);  // 50% 混合

// 加深颜色
var Darker := DarkenColor(clBlue, 20);  // 加深 20%

// 减淡颜色
var Lighter := LightenColor(clBlue, 20);  // 减淡 20%
```

## 强调色

| 强调色 | 说明 |
|--------|------|
| `tacBlue` | 蓝色 |
| `tacRed` | 红色 |
| `tacGreen` | 绿色 |
| `tacOrange` | 橙色 |
| `tacPurple` | 紫色 |
| `tacPink` | 粉色 |
| `tacTeal` | 青色 |
| `tacCyan` | 青绿 |
| `tacAmber` | 琥珀 |
| `tacIndigo` | 靛蓝 |

## 注意事项

1. 需要在应用启动时调用 `RegisterBuiltInThemes`
2. VCL 样式需要在项目选项中启用对应的样式资源
3. 某些 VCL 控件可能需要手动应用主题颜色
4. 建议使用 `TStyleManager` 配合使用以获得最佳效果
