#!/usr/bin/env bash
# B2-11 判别探针：把上下文锁换成"不可重入"替身，验证解析路径是否还依赖同线程重入。
#
# 为什么需要它：工单判定（嵌套解析有界返回 / 高并发无死锁）在 Windows 真件上判不出这次修复——
# System.SyncObjs.TCriticalSection 包的是 CRITICAL_SECTION，同线程二次 Enter 直接放行，
# 所以"持锁再调持锁件"的旧形照样绿。要判别只能换原语：
# 替身件 B2NoReentrantLock 与真件同名，靠 SUT uses 子句后置遮蔽完成替换（Delphi 里后列单元胜出），
# 于是旧形必死锁（有界用例红），新形应全绿。这是修复真实有效性的机器可查证据，不是第二条构建路径。
#
# 用法: bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_nonreentrant_probe.sh <SUT 来源: HEAD|WORKTREE> [测试单元]
#   HEAD     = 修复前的上下文单元（工作树不动，从 git 对象里取）
#   WORKTREE = 当前工作树里的修复后版本
set -u
export MSYS2_ARG_CONV_EXCL='*'
ROOT="$(git rev-parse --show-toplevel)"
BDS="${DEEPBASE_BDS:-D:/Program Files (x86)/Embarcadero/Studio/37.0}"
DCC="$BDS/bin/dcc64.exe"
DUNITX="${DEEPBASE_DUNITX_SOURCE:-D:/ProgramData/delphi/DUnitX/Source}"
SUT="DeepFlow/Source/Workflow/DeepFlow.Workflow.Context.pas"
TEST_UNIT="${2:-Tests/Test.DeepBase.DeepFlow.ContextResolve.pas}"
SRC="${1:-}"
case "$SRC" in
  HEAD)     ;;
  WORKTREE) ;;
  *) echo "第一个参数必须是 HEAD 或 WORKTREE"; exit 3 ;;
esac

UNIT_NAME="$(basename "$TEST_UNIT" .pas)"
DIR="$ROOT/.tmp/b2/probe/$UNIT_NAME-$SRC"
rm -rf "$DIR" || exit 3
mkdir -p "$DIR" || exit 3

# 1) 不可重入替身（同名遮蔽，探针专用，不入库）
cat > "$DIR/B2NoReentrantLock.pas" <<'PAS'
unit B2NoReentrantLock;
interface
uses System.SyncObjs;
type
  TCriticalSection = class
  private
    FSem: TSemaphore;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enter;
    procedure Leave;
  end;
implementation
constructor TCriticalSection.Create;
begin
  inherited Create;
  FSem := TSemaphore.Create(nil, 1, 1, '');
end;
destructor TCriticalSection.Destroy;
begin
  FSem.Free;
  inherited;
end;
procedure TCriticalSection.Enter; begin FSem.Acquire; end;
procedure TCriticalSection.Leave; begin FSem.Release; end;
end.
PAS

# 2) SUT 副本：取指定来源，再把替身插进 uses（排在 System.SyncObjs 之后即胜出）
if [ "$SRC" = "HEAD" ]; then
  git show "HEAD:$SUT" > "$DIR/DeepFlow.Workflow.Context.pas" || exit 3
else
  cp "$ROOT/$SUT" "$DIR/DeepFlow.Workflow.Context.pas" || exit 3
fi
perl -i -pe 's/^([ \t]*System\.RegularExpressions, System\.Variants, System\.SyncObjs,)(\r?)$/$1 B2NoReentrantLock,$2/' "$DIR/DeepFlow.Workflow.Context.pas"
grep -n "B2NoReentrantLock" "$DIR/DeepFlow.Workflow.Context.pas" \
  || { echo "替身未能注入 SUT uses，探针不作数"; exit 3; }

# 3) 一次性 runner（与 b2_run_fixture.sh 同一模板，不另立口径）
sed "s/__UNIT__/$UNIT_NAME/" \
  "$ROOT/CodeReview/20260925-AUDIT-乙-B2-证据/附件/B2FixtureRunner.dpr" > "$DIR/B2FixtureRunner.dpr"

U="$DIR;$ROOT/Core;$ROOT/Features;$ROOT/Persistence;$ROOT/VCL;$ROOT/FMX;$ROOT/Governance"
U="$U;$ROOT/Tests;$ROOT/Tests/Regression;$ROOT/Tests/Integration;$ROOT/DeepFlow/Source"
U="$U;$ROOT/DeepFlow/Source/Core;$ROOT/DeepFlow/Source/Workflow;$ROOT/doQry;$ROOT/ThirdParty"
U="$U;$BDS/lib/Win64/release;$DUNITX"
NS="System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win"

echo "== SUT 来源: $SRC   测试单元: $UNIT_NAME =="
( cd "$ROOT" && "$DCC" -B "$DIR/B2FixtureRunner.dpr" -NU"$DIR" -N0"$DIR" -E"$DIR" -U"$U" -NS"$NS" ) 2>&1 | tail -3
rc=${PIPESTATUS[0]}
echo "BUILD_EXIT=$rc"
[ "$rc" -ne 0 ] && { echo "编译未过 ⇒ 探针无效"; exit 3; }

echo "== 真跑（外部墙钟 90s；用例自身还有 5s/20s 有界断言兜在里层） =="
# 第三个参数给单个用例名：旧形 + 替身下整套会硬挂到墙钟，点名单测才能拿到可读的那一条红
RUNARG="--run:$UNIT_NAME.TTestDeepFlowContextResolve"
[ -n "${3:-}" ] && RUNARG="$RUNARG.$3"
( cd "$DIR" && timeout 90 ./B2FixtureRunner.exe --hidebanner "$RUNARG" ) 2>&1
echo "RUN_EXIT=$? (124 = 被外部墙钟杀掉 = 真死锁)"
