#!/usr/bin/env bash
# WO-20261003-MC-甲-ORPHANREG : full-suite (Tests/DeepBaseTests.dpr) baseline + per-batch after-readings.
# recipe copied from Scripts/run_tests.ps1 (house SSOT): -U<SearchPath> -NS<default(default.csv) U dproj-DCC_Namespace>
#   -N0<dcudir> -Q -B -DDEBUG, run with --exitbehavior:Continue (no --xmlfile: console log is the reading).
#   sqlite3.dll copied into Tests/ exactly like Ensure-SqliteDll (removed afterwards).
#
# usage: fullsuite-run.sh <label>            # label becomes the output dir name
# reads:   <root>/Tests/DeepBaseTests.dpr
# writes:  $OUT/<label>/{compile.log,run.log,_reading.txt}   (outside the repo)
set -u
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

LABEL="${1:-baseline}"
ROOT='D:\_ProgData\DeepBase-ORPHANREG\wt-orphanreg'
OUT='D:\_ProgData\DeepBase-ORPHANREG\fullsuite'
BDS='D:\Program Files (x86)\Embarcadero\Studio\37.0'
DCC="$BDS\bin\dcc64.exe"
DUNITX='D:/ProgramData/delphi/DUnitX/Source'
DIR="$OUT\\$LABEL"
BS='\'
DIR="$OUT$BS$LABEL"
mkdir -p "$DIR"

U="$ROOT\Core;$ROOT\Features;$ROOT\Persistence;$ROOT\VCL;$ROOT\FMX;$ROOT\Governance;$ROOT\doQry;\
$ROOT\ThirdParty\Payment;$ROOT\ThirdParty\Social;$ROOT\Tools\CLI;$ROOT\Tools\WebService;\
$ROOT\Tests;$ROOT\Tests\Regression;$ROOT\Tests\Integration;$BDS\lib\Win64\release;$DUNITX"
NS_DEFAULT='System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;\
FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win'
NS_DPROJ=$(grep -o '<DCC_Namespace>[^<]*</DCC_Namespace>' "$ROOT\Tests\DeepBaseTests.dproj" \
  | sed 's/<[^>]*>//g' | tr -d '\r' | awk -F';' '{for(i=1;i<=NF;i++) if($i!="") printf "%s;", $i}')
[ -z "$NS_DPROJ" ] && NS_DPROJ=''
NS="$NS_DEFAULT"
if [ -n "$NS_DPROJ" ]; then NS="$NS_DEFAULT;$NS_DPROJ"; fi

DCUDIR="$DIR\dcu"
mkdir -p "$DCUDIR"

# BUG-285 hygiene: clear stale DCUs from source dirs before building (run_tests.ps1 does the same)
for d in Core Persistence Features Tests VCL FMX ThirdParty; do
  [ -d "$ROOT\$d" ] && find "$ROOT\\$d" -name '*.dcu' -type f -delete 2>/dev/null
done

# sqlite3.dll (Ensure-SqliteDll equivalent): compiler bin64 first, then known fallbacks
SQLITE=''
for c in "$BDS\bin64\sqlite3.dll" "$ROOT\sqlite3.dll" \
         'D:\UserData\Administrator\AppData\Local\Programs\Python\Python311\DLLs\sqlite3.dll' \
         'D:\ProgramData\Python313\DLLs\sqlite3.dll' \
         'D:\ProgramData\anaconda3\Library\bin\sqlite3.dll'; do
  if [ -f "$c" ]; then SQLITE="$c"; break; fi
done
SQLITE_COPIED=0
if [ -n "$SQLITE" ]; then
  cp -f "$SQLITE" "$ROOT\Tests\sqlite3.dll" && SQLITE_COPIED=1
  echo "sqlite3.dll copied from $SQLITE" > "$DIR\sqlite.txt"
else
  echo "sqlite3.dll NOT FOUND (FireDAC SQLite tests may fail)" > "$DIR\sqlite.txt"
fi

echo "[$LABEL] build start $(date '+%F %T')"
# WorkingDirectory MUST be the Tests dir: dcc64 resolves relative `in '..\...'` clauses
# against CWD (Test.DeepBase.DeepFlow.ContextResolve.pas has `in '..\DeepFlow\Source\...'`).
# run_tests.ps1 Compile-TestProject uses -WorkingDirectory $projectDir for the same reason.
( cd "$ROOT\Tests" && "$DCC" -U"$U" -NS"$NS" -N0"$DCUDIR" -Q -B -DDEBUG \
    "$ROOT\Tests\DeepBaseTests.dpr" ) > "$DIR\compile.log" 2>&1
BRC=$?
echo "[$LABEL] BUILD_EXIT=$BRC  $(date '+%F %T')"

EXE="$ROOT\Tests\DeepBaseTests.exe"
RUNRC=''
if [ $BRC -eq 0 ] && [ -f "$EXE" ]; then
  cp -f "$EXE" "$DIR\DeepBaseTests.exe"
  ( cd "$ROOT\Tests" && "$EXE" --exitbehavior:Continue ) > "$DIR\run.log" 2>&1
  RUNRC=$?
  echo "[$LABEL] RUN_EXIT=$RUNRC  $(date '+%F %T')"
else
  echo "[$LABEL] no exe produced" > "$DIR\run.log"
  RUNRC='N/A'
fi

if [ $SQLITE_COPIED -eq 1 ]; then rm -f "$ROOT\Tests\sqlite3.dll"; fi
# BUG-285: remove any DCU dcc64 dropped into source dirs
for d in Core Persistence Features Tests VCL FMX ThirdParty; do
  [ -d "$ROOT\$d" ] && find "$ROOT\\$d" -name '*.dcu' -type f -delete 2>/dev/null
done

{
  echo "LABEL=$LABEL"
  echo "BUILD_EXIT=$BRC"
  echo "RUN_EXIT=$RUNRC"
  grep -E "Tests Found|Tests Ignored|Tests Passed|Tests Leaked|Tests Failed|Tests Errored" "$DIR\run.log" 2>/dev/null
} > "$DIR\_reading.txt"
cat "$DIR\_reading.txt"
echo "[$LABEL] done $(date '+%F %T')"
