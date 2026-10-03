#!/usr/bin/env bash
# F5/判据6 编译探针驱动器：隔离 worktree 内对每个用例跑 dcc64，留存 compile.log。
# 不用主树（主树 46679 陈旧 .dcu 必红），worktree 为干净 HEAD 检出。
set -u
EV="D:/_Progs/02Business/DeepBase/CodeReview/20261003-AUDIT-甲-TPLBOOT-证据"
WT="D:/_ProgData/DeepBase-TPLBOOT-wt"
BDS="D:/Program Files (x86)/Embarcadero/Studio/37.0"
DCC="$BDS/bin/dcc64.exe"
# 探针目录放 -U 首位（每个用例目录自带被测单元副本）；不挂 worktree 的 Examples/Templates/Common，
# 否则 dcc 会解析到 worktree 原件而不是用例副本。
U=".;$WT/Core;$WT/Features;$WT/VCL;$WT/FMX;$WT/Persistence;$WT/Governance;$WT/doQry;$WT/ThirdParty;$WT/DeepFlow/Source;$BDS/lib/Win64/release"
NS="System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win"

for case in F5-head F5-fixed NC1-typo NC2-missing-uses; do
  dir="$EV/_probe_out/$case"
  cd "$dir" || exit 3
  "$DCC" -B TPLBOOTProbe.dpr -NU. -N0. -E. "-U$U" "-NS$NS" -DDEBUG > compile.log 2>&1
  rc=$?
  echo "===== $case  BUILD_EXIT=$rc ====="
  grep -E "Error|Fatal|error" compile.log | head -12
  ls TPLBOOTProbe.exe >/dev/null 2>&1 && echo "exe: 生成" || echo "exe: 未生成"
  echo
done
