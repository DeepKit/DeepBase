#!/usr/bin/env bash
# WO-20261003-MC-甲-ORPHANREG probe driver (ASCII-only; raw logs stay outside the repo)
#
# usage: orphanreg-probe.sh <one|all> <worktree-root> <scratch-out> [unit ...]
#
#   one : materialize Tests/Regression/ORPHANREGOne.dpr.template per unit, compile+run each
#   all : materialize Tests/Regression/ORPHANREG22.dpr.template (all 22 units in one program)
#
# build/run recipe is copied from Scripts/run_tests.ps1 (house SSOT):
#   dcc64 -U<SearchPath> -NS<namespaces> -N0<dcudir> -Q -B <dpr>
#   <exe> --exitbehavior:Continue --xmlfile:<...>
# namespaces = run_tests.ps1 default UNION DeepBaseTests.dproj DCC_Namespace declarations.
set -u
# git-bash rewrites embedded POSIX-looking paths inside dcc64 args (-N0D:/x -> D:D:/Program Files/Git/x
# => F2039 Could not create output file). House pattern (run-probe.ps1) never hits this; disable it.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

MODE="${1:-}"; ROOT="${2:-}"; OUT="${3:-}"; shift 3 2>/dev/null || shift $#
BS='\'
ROOT="${ROOT//"/"$BS}"
OUT="${OUT//"/"$BS}"

BDS='D:\Program Files (x86)\Embarcadero\Studio\37.0'
DCC="$BDS\bin\dcc64.exe"
U="$ROOT\Core;$ROOT\Features;$ROOT\Persistence;$ROOT\VCL;$ROOT\FMX;$ROOT\Governance;$ROOT\doQry;$ROOT\ThirdParty;$ROOT\ThirdParty\Payment;$ROOT\ThirdParty\Social;$ROOT\Tools\CLI;$ROOT\Tools\WebService;$ROOT\DeepFlow\Source;$ROOT\DeepFlow\Source\Core;$ROOT\DeepFlow\Source\Roles;$ROOT\DeepFlow\Source\Workflow;$ROOT\DeepFlow\Source\AI;$ROOT\Tests;$ROOT\Tests\Regression;$ROOT\Tests\Integration;$BDS\lib\Win64\release;D:\ProgramData\delphi\DUnitX\Source"
NS='System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win;Datasnap;Data.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win;Bde'
TPL="$ROOT\Tests\Regression"
JOBS="${JOBS:-4}"
\
# single backslash path separator for Windows-side args (kept out of "$OUT$BS$s" style strings)
BS='\'

UNITS_ONE="$@"
if [ -z "$UNITS_ONE" ]; then
UNITS_ONE='Test.Regression.A8_InFlightUnloadGate
Test.Regression.BUG001_AnimationMemoryLeak
Test.Regression.BUG007_WhenReadyDeadlock
Test.Regression.BUG009_LoggingRace
Test.Regression.BUG010_WorkerQueueRace
Test.Regression.BUG013_RSASignature
Test.Regression.BUG014_WeChatPaySignature
Test.Regression.BUG020_KeyNameValidation
Test.Regression.BUG033_WeakEncryption
Test.Regression.BUG034_HardcodedKeys
Test.Regression.BUG035_InsecureRandom
Test.Regression.BUG037_KeyDerivation
Test.Regression.BUG054_SemaphoreLeak
Test.Regression.BUG058_XOREncryption
Test.Regression.BUG059_JsonDeserializationType
Test.Regression.BUG060_SerializationDepth
Test.Regression.BUG062_PluginSandbox
Test.Regression.BUG063_PluginConfigBypass
Test.Regression.BUG066_PathTraversal
Test.Regression.BUG070_LogInjection
Test.Regression.BUG073_EventTypeInjection
Test.Regression.CR606_FrameDifferAlpha'
fi

# short name: strip the common prefix
short() { echo "${1#Test.Regression.}"; }

# one_unit <unit-full-name>  -> writes <OUT>/<short>/_result.txt (ASCII, committed as derived summary)
one_unit() {
  local unit="$1" s; s="$(short "$unit")"
  local dir="$OUT$BS$s"
  rm -rf "$dir"; mkdir -p "$dir" || return 9
  local dpr="$dir\ORPHANREGOne.dpr"
  sed "s/__UNIT__/$unit/" "$TPL\ORPHANREGOne.dpr.template" > "$dpr"
  local clog="$dir\compile.log" rlog="$dir\run.log" res="$dir\_result.txt"
  local bstart bend
  bstart=$(date +%s)
  ( cd "$dir" && "$DCC" -B "$dpr" "-NU$dir" "-N0$dir" "-E$dir" "-U$U" "-NS$NS" -Q ) > "$clog" 2>&1
  local brc=$?
  bend=$(date +%s)
  local lines hints warns
  lines=$(grep -c . "$clog" 2>/dev/null || true)
  hints=$(grep -c 'Hint:' "$clog" 2>/dev/null || true)
  warns=$(grep -c 'Warning:' "$clog" 2>/dev/null || true)
  local summ="" verdict="" found="" passed="" failed="" errored="" leaked="" ignored="" rrc=""
  if [ "$brc" -ne 0 ]; then
    verdict="BUILD_FAILED"
    summ=$(grep -m3 -E '^.*\[dcc64 (Fatal )?Error\]|Error: ' "$clog" | tr -d '\r' | head -3 | tr '\n' '|')
  else
    ( cd "$dir" && "$dir\ORPHANREGOne.exe" --exitbehavior:Continue --hidebanner "--xmlfile:$dir\run.xml" ) > "$rlog" 2>&1
    rrc=$?
    found=$(grep -m1 'Tests Found' "$rlog" | sed 's/.*: *//' | tr -d '\r\n ')
    passed=$(grep -m1 'Tests Passed' "$rlog" | sed 's/.*: *//' | tr -d '\r\n ')
    failed=$(grep -m1 'Tests Failed' "$rlog" | sed 's/.*: *//' | tr -d '\r\n ')
    errored=$(grep -m1 'Tests Errored' "$rlog" | sed 's/.*: *//' | tr -d '\r\n ')
    leaked=$(grep -m1 'Tests Leaked' "$rlog" | sed 's/.*: *//' | tr -d '\r\n ')
    ignored=$(grep -m1 'Tests Ignored' "$rlog" | sed 's/.*: *//' | tr -d '\r\n ')
    verdict=$(grep -m1 'RUNNER_VERDICT' "$rlog" | sed 's/.*: *//' | tr -d '\r\n ')
    summ=$(grep -E '^\s+(Test|DeepBase)\.' "$rlog" | tr -d '\r' | tr '\n' '|')
  fi
  printf '%s\tBUILD_EXIT=%s(%ss,lines=%s,hint=%s,warn=%s)\tRUN_EXIT=%s\tVERDICT=%s\tFound=%s\tPassed=%s\tFailed=%s\tErrored=%s\tLeaked=%s\tIgnored=%s\tDETAIL=%s\n' \
    "$unit" "$brc" "$((bend-bstart))" "$lines" "$hints" "$warns" "$rrc" "$verdict" "$found" "$passed" "$failed" "$errored" "$leaked" "$ignored" "$summ" > "$res"
}

case "$MODE" in
  all)
    dir="$OUT\ALL22"; rm -rf "$dir"; mkdir -p "$dir" || exit 9
    dpr="$dir\ORPHANREG22.dpr"
    cp "$TPL\ORPHANREG22.dpr.template" "$dpr"
    bstart=$(date +%s)
    ( cd "$dir" && "$DCC" -B "$dpr" "-NU$dir" "-N0$dir" "-E$dir" "-U$U" "-NS$NS" -Q ) > "$dir\compile.log" 2>&1
    brc=$?; bend=$(date +%s)
    if [ "$brc" -ne 0 ]; then
      printf 'ALL22\tBUILD_EXIT=%s(%ss)\n' "$brc" "$((bend-bstart))" > "$dir\_result.txt"
      exit "$brc"
    fi
    ( cd "$dir" && "$dir\ORPHANREG22.exe" --exitbehavior:Continue --hidebanner "--xmlfile:$dir\run.xml" ) > "$dir\run.log" 2>&1
    rrc=$?
    { printf 'ALL22\tBUILD_EXIT=0(%ss)\tRUN_EXIT=%s\n' "$((bend-bstart))" "$rrc"
      grep -E 'Tests Found|Tests Passed|Tests Failed|Tests Errored|Tests Leaked|Tests Ignored|RUNNER_VERDICT' "$dir\run.log" | tr -d '\r' | sed 's/^ *//'
      grep -E '^\s+(Test|DeepBase)\.' "$dir\run.log" | tr -d '\r'
    } > "$dir\_result.txt"
    exit 0
    ;;
  one)
    n=0
    for u in $UNITS_ONE; do
      one_unit "$u" &
      n=$((n+1))
      if [ $((n % JOBS)) -eq 0 ]; then wait; fi
    done
    wait
    exit 0
    ;;
  *) echo "unknown mode: $MODE" >&2; exit 2 ;;
esac
