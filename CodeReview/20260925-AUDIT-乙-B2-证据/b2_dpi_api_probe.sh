#!/usr/bin/env bash
# B2-06 依赖面可用性探针：逐条实测 DPIMapper 想用的 Win32/VCL/Math API 在本机
# Delphi 37.0 (dcc64) 上到底存不存在，并实测几个 DPI 相关量的运行期真值。
#
# 为什么要它：工单只点名了 interface 节带实现体 + 重复声明两处断裂；本单元还引用了
# 4 个本机不存在的 API 和 1 个不存在的单元（Graphics32）。哪些「不可用」是编译器事实，
# 必须逐条实测取原始输出，不能靠推测或文档印象——修完后 DPI 口径也要靠这份证据解释。
#
# 产物落 .tmp（gitignored），不是构建路径；原始输出归档到同名 .txt 作为证据。
# 用法: bash CodeReview/20260925-AUDIT-乙-B2-证据/b2_dpi_api_probe.sh
set -u
export MSYS2_ARG_CONV_EXCL='*'   # 见 b2_unit_compile.sh 同名注释
ROOT="$(git rev-parse --show-toplevel)"
BDS="${DEEPBASE_BDS:-D:/Program Files (x86)/Embarcadero/Studio/37.0}"
DCC="$BDS/bin/dcc64.exe"
DIR="$ROOT/.tmp/b2/dpiprobe"
rm -rf "$DIR" || { echo "无法清空探针目录: $DIR"; exit 3; }
mkdir -p "$DIR"

PREAMBLE='program dpiprobe; {$APPTYPE CONSOLE}
uses System.SysUtils, System.Types, System.Math, Winapi.Windows, System.Win.HighDpi, Vcl.Forms;
var Mon: TMonitor; DX, DY: Cardinal; S: string; I: Integer;
begin'

# 每行 = 断言点 | 一条引用该 API 的语句（编译过=该 API 存在）
ROWS=(
  "Winapi.Windows.GetDpiForSystem|I := GetDpiForSystem;"
  "Winapi.Windows.GetDpiForWindow|I := GetDpiForWindow(GetDesktopWindow());"
  "Winapi.Windows.MonitorFromPoint(P, flags)|Mon := MonitorFromPoint(Point(50,50), MONITOR_DEFAULTTOPRIMARY);"
  "Winapi.Windows.GetDpiForMonitor|I := GetDpiForMonitor(0, MDT_EFFECTIVE_DPI, DX, DY);"
  "TMonitor.Handle|Mon := Screen.PrimaryMonitor; I := Integer(NativeInt(Mon.Handle));"
  "TMonitor.PixelsPerInch|Mon := Screen.PrimaryMonitor; I := Mon.PixelsPerInch;"
  "TMonitor.Scale|Mon := Screen.PrimaryMonitor; S := FloatToStr(Mon.Scale);"
  "TScreen.MonitorFromPoint(P) 单参|Mon := Screen.MonitorFromPoint(Point(50,50));"
  "TScreen.DefaultMonitor|I := Screen.DefaultMonitor.PixelsPerInch;"
  "System.Math.Clamp(Double)|S := FloatToStr(Clamp(0.5, 0.0, 1.0));"
  "System.Math.Min/Max(Double)|S := FloatToStr(Max(0.0, Min(1.0, 0.5)));"
  "System.Win.HighDpi.IsDpiAware|I := Integer(System.Win.HighDpi.IsDpiAware);"
  "旧实现里的 fmt()(单元内不存在)|S := fmt('%d', [1]);"
)

probe() { # $1=label $2=dpr 文件名（相对 $DIR）
  local out rc
  out="$( ( cd "$DIR" && "$DCC" -B -H- "$2" -NU"$DIR" -N0"$DIR" -E"$DIR" ) 2>&1 )"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '[可用]   %s\n' "$1"
  else
    printf '[不可用] %s\n         %s\n' "$1" "$(printf '%s\n' "$out" | grep -E 'Error|Fatal' | head -2 | sed 's/^ *//;s/  */ /g' | paste -sd' | ' -)"
  fi
}

echo "==== 一、编译面：逐 API 存在性（EXIT=0 即存在） ===="
n=0
for row in "${ROWS[@]}"; do
  label="${row%%|*}"; stmt="${row#*|}"
  n=$((n+1))
  # 每个探针用各自的 program 名，避免全部写成同一个 dpiprobe.exe 后分不清是哪轮的产物
  printf '%s\r\n' "${PREAMBLE/program dpiprobe/program apip$n}" "  $stmt" "end." > "$DIR/api$n.dpr"
  probe "$label" "api$n.dpr"
done

echo
echo "==== 二、引用面：整个单元是否存在（Graphics32 / Winapi.Shcore） ===="
m=0
for u in Graphics32 GR32 Winapi.Shcore; do
  m=$((m+1))
  # \$ 转义是关键：{$APPTYPE ...} 里的 $ 一旦被 bash 展开就会在 set -u 下炸掉脚本
  printf '%s\r\n' "program uprobe$m; {\$APPTYPE CONSOLE} uses $u; begin end." > "$DIR/u$m.dpr"
  probe "uses $u" "u$m.dpr"
done

echo
echo "==== 三、运行期真值：Screen 在纯控制台进程里是否可用 + 各 DPI 取值实测 ===="
# 用 heredoc 而不是多个 printf 参数：printf 的 '%s' 参数里 '' 会被 bash 当成引号拼接吃掉，
# Delphi 字符串字面量的单引号就全丢了（实测编出 E2035/E2029）。
cat > "$DIR/rt.dpr" <<'PAS'
program rt; {$APPTYPE CONSOLE}
uses System.SysUtils, System.Types, Winapi.Windows, Vcl.Forms;
var Mon: TMonitor;
begin
  Writeln('Screen = nil ? ', Screen = nil);
  Writeln('MonitorCount=', Screen.MonitorCount);
  Writeln('Screen.PixelsPerInch=', Screen.PixelsPerInch);
  Writeln('Screen.Width=', Screen.Width, '  SM_CXSCREEN=', GetSystemMetrics(SM_CXSCREEN));
  Writeln('GetSystemMetrics(LOGPIXELSX)=', GetSystemMetrics(LOGPIXELSX),
    '  <- 常量配对错误：LOGPIXELSX 属 GetDeviceCaps');
  Mon := Screen.MonitorFromPoint(Point(50,50));
  Writeln('MonitorFromPoint(50,50) assigned=', Mon <> nil);
  if Mon <> nil then Writeln('Mon.PixelsPerInch=', Mon.PixelsPerInch, '  Handle=', Int64(Mon.Handle));
end.
PAS
( cd "$ROOT" && "$DCC" -B -H- "$DIR/rt.dpr" -NU"$DIR" -N0"$DIR" -E"$DIR" ) 2>&1 | tail -2
echo "BUILD_EXIT=${PIPESTATUS[0]}"
( cd "$DIR" && ./rt.exe ); echo "RUN_EXIT=$?"
echo
echo "== 探针产物目录: .tmp/b2/dpiprobe（gitignored，不入库） =="
