# UniBase SVG 图表库

本目录包含 UniBase 框架的所有关键 SVG 图表，这些图表可以直接在任何支持 SVG 的工具中打开。

---

## 📊 可用图表

### 1. **01-Architecture-Overview.svg** - 架构总览图
**尺寸**: 1200 × 900 px  
**内容**:
- UniBase 整体架构（Core、UI、Tools、Cloud）
- Tier 0/1/2 表分层结构（6 张 Tier 0 表，4 张 Tier 1 表，6 张 Tier 2 表）
- 10 个核心模块的依赖关系
- 数据流向图
- 编译依赖链（Image32 → Core → UI/Tools → 应用）

**使用场景**:
- 项目启动会议演示
- 架构文档
- 新开发人员培训
- 系统设计评审

---

### 2. **02-UI-Controls-System.svg** - UI 控件体系图
**尺寸**: 1400 × 1000 px  
**内容**:
- 15 个 UI 控件的 5 大分类
  - MRU 控件（2个）
  - i18n 控件（3个）
  - Config 控件（3个）
  - Selection 控件（2个）
  - Utility 控件（5个）
- VCL 继承树示例
- 控件功能映射矩阵
- TI18nLabel 数据流示例
- VCL vs FMX 兼容性对比
- 控件生命周期（设计时→编译时→运行时→销毁）

**使用场景**:
- UI 开发规范文档
- 控件使用培训
- 集成工程师参考
- 架构设计审查

---

### 3. **04-Integration-Workflow.svg** - 渐进式集成流程图
**尺寸**: 1600 × 1000 px  
**内容**:
- 8 阶段集成流程（从 root.txt 到自动更新）
- 每个阶段的风险等级（低/中/高）
- 8 个阶段的详细检查清单
- 风险等级说明
- 推荐 4 周集成时间表
- 关键指标（代码改动量、回滚难度）
- 集成建议和最佳实践

**使用场景**:
- 项目集成计划制定
- QA 验证清单
- 风险评估和规划
- 团队沟通和进度跟踪

---

## 🎨 设计特点

### 颜色编码系统

| 颜色 | 含义 | RGB |
|------|------|-----|
| 红色 (#ff9999) | Core 库 / 高风险 | 关键组件 |
| 绿色 (#99ff99) | 数据库 / 完成 | 数据存储/里程碑 |
| 蓝色 (#99ccff) | UI 控件 | 用户界面 |
| 黄色 (#ffffcc) | 配置/中等风险 | 中间层/中等风险 |
| 紫色 (#ffccff) | 云端服务 / Utility | 扩展功能 |
| 灰色 (#e6e6e6) | 基类 / 中性 | 通用组件 |

### 箭头说明

- **实心箭头 (→)** - 直接依赖或数据流
- **虚线箭头** - 间接依赖或可选关系
- **双向箭头** - 相互通信

---

## 💻 打开和编辑

### 查看 SVG

1. **浏览器**（推荐）
   ```bash
   # 直接打开任何浏览器
   open 01-Architecture-Overview.svg
   # 或双击文件
   ```

2. **VS Code**
   - 安装扩展：`SVG Viewer` 或 `SVG`
   - 右键点击 SVG 文件 → `Preview SVG`

3. **在线查看器**
   - https://www.svgviewer.dev/
   - 上传或粘贴 SVG 代码

4. **其他工具**
   - Adobe Illustrator
   - Inkscape（开源）
   - Figma（协作）

### 编辑 SVG

1. **文本编辑器**（简单修改）
   ```
   # 使用 VS Code 或其他文本编辑器
   # SVG 本质上是 XML，可以直接编辑文本
   ```

2. **设计工具**（完整编辑）
   - Inkscape（开源，完全功能）
   - Figma（云端协作）
   - Adobe Illustrator（专业）

---

## 🔄 导出为其他格式

### 导出为 PNG/JPG

**使用 ImageMagick**：
```bash
# 安装 ImageMagick
# Windows: choco install imagemagick
# macOS: brew install imagemagick
# Linux: apt-get install imagemagick

# 转换为 PNG（高质量）
convert -density 150 01-Architecture-Overview.svg -quality 95 01-Architecture-Overview.png

# 转换为 JPG
convert -density 150 01-Architecture-Overview.svg -quality 90 01-Architecture-Overview.jpg
```

**使用 Inkscape**：
```bash
# 命令行转换
inkscape -D --export-filename=output.png input.svg

# 带缩放
inkscape -D --export-filename=output.png --export-width=1920 input.svg
```

**使用在线工具**：
- https://cloudconvert.com/（支持多种格式）
- https://convertio.co/svg-png/

### 导出为 PDF

```bash
# 使用 Inkscape
inkscape input.svg --export-filename=output.pdf

# 使用在线工具
# 访问 https://cloudconvert.com/svg-pdf
```

---

## 📐 响应式缩放

所有 SVG 都使用 `viewBox` 属性，可以自动缩放：

```html
<!-- 在 HTML 中使用 SVG -->
<img src="01-Architecture-Overview.svg" style="max-width: 100%; height: auto;">

<!-- 或嵌入 -->
<object data="01-Architecture-Overview.svg" type="image/svg+xml" style="width: 100%;"></object>
```

---

## 🎯 快速参考

### 按角色查看

| 角色 | 推荐查看 | 用途 |
|------|---------|------|
| **项目经理** | 04-Integration | 制定计划和时间表 |
| **架构师** | 01-Architecture + 02-UI | 系统设计和控件架构 |
| **前端开发** | 02-UI-Controls | 控件使用和继承 |
| **后端开发** | 01-Architecture | 模块依赖和数据流 |
| **QA/测试** | 04-Integration | 验证清单和风险评估 |
| **集成工程师** | 04-Integration + 02-UI | 集成计划和控件集成 |

### 按用途查看

| 用途 | 图表 | 说明 |
|------|------|------|
| 架构理解 | 01-Architecture | 整体系统架构 |
| 代码开发 | 02-UI-Controls | 控件实现和继承 |
| 集成实施 | 04-Integration | 分阶段集成步骤 |
| 会议展示 | 01-Architecture | 给 stakeholder 讲解 |
| 培训教材 | 全部 | 新员工入门 |

---

## 📝 文件清单

```
svg/
├── README.md                          # 本文件
├── 01-Architecture-Overview.svg        # 架构总览（1200×900）
├── 02-UI-Controls-System.svg           # UI 控件体系（1400×1000）
└── 04-Integration-Workflow.svg         # 集成工作流（1600×1000）
```

**总大小**：约 150 KB（原始 SVG 文本格式）  
**建议存储**：版本控制系统（Git）中

---

## 🔗 相关文档

这些 SVG 图表对应以下 Markdown 文档中的 Mermaid 图：

- `../01-Architecture-Overview.md` - 架构总览详细描述
- `../02-UI-Controls-System.md` - UI 控件详细规范
- `../04-Integration-Workflow.md` - 集成流程详细说明

**推荐**：结合 SVG 图表和 Markdown 文档使用，获得最佳理解。

---

## 🔧 技术细节

### SVG 特性

- **无损缩放**：任意尺寸显示不失真
- **可编程**：所有元素通过 XML 定义
- **搜索友好**：文本内容可被搜索
- **文件小**：相比位图节省空间
- **动画支持**：可添加 CSS/JavaScript 动画

### 浏览器兼容性

- ✅ Chrome/Edge 100%
- ✅ Firefox 100%
- ✅ Safari 100%
- ✅ IE 11（部分支持）
- ✅ 移动浏览器 100%

---

## 💡 最佳实践

### 使用 SVG 时

1. **保持高纵横比**：显示时使用 `max-width: 100%; height: auto`
2. **链接到源文件**：在文档中引用 SVG 的 GitHub 链接
3. **版本控制**：使用 Git 追踪 SVG 变更
4. **导出备份**：定期导出 PNG 用于备份和演示

### 编辑 SVG 时

1. **保持一致性**：使用相同的颜色编码和字体
2. **验证视图框**：确保 viewBox 覆盖所有内容
3. **测试兼容性**：在多个浏览器中验证
4. **压缩文件**：使用 SVGO 减小文件大小（可选）

---

## 📞 支持和反馈

- 问题？检查 SVG 是否正确渲染
- 建议？在源 Markdown 文件中提出改进
- 错误？提交 Issue 或 Pull Request

---

**最后更新**：2025-11-26  
**版本**：v0.3  
**格式**：SVG 1.1 Compatible  
**许可证**：与 UniBase 相同
