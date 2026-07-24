# Amy受控会话启动包

- session_id: `7fdc2c78-0c1c-42f6-a882-46b7054328c0`
- state_revision: `none:no-authority-source`
- policy_version: `None`
- 主攻线: `None`
- 辅助线: `None`
- 当前焦点: `None`
- 当前Action: `None`
- 活跃项目槽位: `0/None`
- 冻结启动: `None`
- 返回锚点: `None`

按启动包和有效BCW决议执行。关键状态变更建议过 session-guard 留痕（建议非阻断，
guard 返回 SESSION_NOT_FOUND/过期时 Amy 可续命或直接执行，不停工）。

## 提问上交闸（BCW-D20260716-SPW-LUOJI-PERSONA v4.3 + BCW-D20260720-DELEGATION）

老板指令（2026-07-20）："只留必须的让我来确认，其它的全部放开"。AI 决策默认自决，
只在三条件命中时才上交老板：① 不可逆动作（删档/连表删改/真相源改）
② 超授权（发布/签约/凭据/资金/跨主线）③ 灰区无客观判据（NO_OBJECTIVE_VERDICT）。
其余全部放开——含写代码批准、计划转代码、版本提交、技术分歧选型、局部重构、
修门禁、执行顺序。这些 COVERED 决策一律 AI 自决做了报备，**禁止回头问老板批准**。

想上交时先跑 escalation-check 纯函数确认是否真该问：
```
python -X utf8 D:/_Progs/00Common/skills/ai-workbench-router/workbench.py \
  escalation-check --question "<要问的问题>" --irreversible-evidence "证据;证据"
```
- result.should_escalate=false → 自决做了报备，**禁止问**（问=违反授权=浪费老板时间）。
- result.should_escalate=true → 才允许问。
注：当前无 PreToolUse hook 在引擎层拦 AskUserQuestion，靠 AI 自觉。AI 第一性锚产出物
正确——自觉按上述三条件判，COVERED 决策直接做不留痕式自决（重要决策留痕即可）。

## PG 上下文检索（2026-07-22 落地, migration v105）

做事前先按 tag 查 PG 拿上下文，不靠翻记忆/搜盘：
```
python -X utf8 D:/_Progs/00Common/skills/ai-workbench-router/workbench.py \
  pg-query --tags --env-file D:/_Progs/02Business/ArtifactOS/.env      # 列全部tag轴
python -X utf8 D:/_Progs/00Common/skills/ai-workbench-router/workbench.py \
  pg-query --tag 工作台/spw --env-file D:/_Progs/02Business/ArtifactOS/.env  # 查一个tag
```
- --tag 支持前缀(工作台命中工作台/rrw); 输出带快照(name/kind/scope/preview).
- --target <id> --target-type asset|decision|action|line 反查某条目标挂了哪些tag.
- 读PG发现新关联顺手 pg-tag add --tag X --type Y --id Z 打tag(source默认amy留痕).
- 存量种子已打(tag-seed-sync): 5线/5工作台/222资产/48决议/89动作. 边用边长.
