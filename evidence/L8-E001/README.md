# L8-E001 Controlled Evidence Landing Zone
## Case 001 观察证据受控归档落点与基准索引

- **所属协议**：`L8-E001 Observation Protocol v1`
- **定位**：Case 001 唯一受 Git 版本控制的官方证据归档基座（消除工作树单副本与 `.gitignore` 逃逸风险）
- **依据工单**：`WO-20260916-EHAI-L8-E001-OBS-GAP-001` (R2/R3 整改)
- **维护人**：观察员 / 调查员（只读归档，不可篡改）

---

## 一、目录结构与归档职责

```text
DeepBase/evidence/L8-E001/
├── README.md                           # 本说明文件
├── episodes/                           # 标准化 Episode YAML 记录集 (ep-YYYYMMDD-AW/AX-###.yaml)
├── aswish/                             # AsWish 各 Episode 抽取的受控证据快照 (snapshots/decisions/trees)
├── axis/                               # AXIS 各 Episode 抽取的受控证据回执与审计链 (receipts/audit-logs)
└── baselines/                          # Comparison B 历史对照样本受控清单与指纹镜像
    ├── aswish-historical-manifest.json # AsWish 历史自由式 AI 开发对照基准指纹（51 文件 SHA256）
    └── axis-historical-manifest.json   # AXIS 历史关系经营归档受控清单（56 篇已跟踪文档）
```

---

## 二、证据入库纪律（防单副本丢失）

1. **实时归档**：
   - AsWish 观察过程中，被测项目常位于不受 Git 控制或受 `.gitignore` 排除的目录（如 `dogfood_*/`）；
   - **强制纪律**：每个 Episode 结束后，必须将该次任务产生的核心数据镜像（`snapshot.yaml`、`decisions.yaml`、`change-set-*.yaml`）与标准化 `ep-*.yaml` 复制到本目录对应子目录中；
   - 并在当日观察窗口结束时执行 Git Commit 入库。
2. **三仓隔离**：
   - 保持被测产品仓（`AsWish`、`DeepAxis`）只运行被测逻辑；
   - 全部研究级原始证据（E0/E1）统一落盘于 `DeepBase/evidence/L8-E001/`，由主控集中归档。

---

## 三、Comparison B 历史对照基准受控登记

针对 AsWish 仓内 `batch_dogfood/` 处于 `.gitignore:57` 状态的事实，本目录正式登记受版本控制的 Comparison B 基准：
1. **仓内受控工兵样本**：`AsWish/Spikes/WO-0030-VCL-HighFidelity/`（已于 Commit `7624a1d09da164b60d3a6deffb2d4c1127383548` 正式入库受控）；
2. **历史冻结样本**：见 [`baselines/aswish-historical-manifest.json`](baselines/aswish-historical-manifest.json)，对 `batch_dogfood/proj_calc_tool` 全部 51 个历史素材文件进行 SHA256 固化与受控存证；
3. **AXIS 历史受控样本**：见 [`baselines/axis-historical-manifest.json`](baselines/axis-historical-manifest.json)，对 `DeepAxis/docs/_archive/`（56 个已跟踪历史文档）进行受控清单锁定。
