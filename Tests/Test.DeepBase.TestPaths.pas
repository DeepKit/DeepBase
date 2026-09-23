{ ============================================================================
  Test.DeepBase.TestPaths — 测试仓库根解析（单一 helper）

  背景：若干 fixture 原先用 GetCurrentDir / TDirectory.GetCurrentDirectory
  解析仓库内相对路径（Examples\、VCL\、FMX\、dcl*.dpk 等），只在「cwd 恰好
  等于仓库根」时成立，导致同一 exe 换 cwd 运行结论不一致。

  本单元统一改为「从可执行文件位置向上探测仓库根」，彻底不依赖进程 cwd。
  ============================================================================ }

unit Test.DeepBase.TestPaths;

interface

uses
  System.SysUtils,
  System.IOUtils;

type
  TTestPaths = class
  public
    /// <summary>仓库根（带尾路径分隔符）。探测失败抛异常。</summary>
    class function RepoRoot: string;

    /// <summary>仓库根 + 相对路径。</summary>
    class function RepoPath(const ARelativePath: string): string;

    /// <summary>在候选目录列表中返回第一个存在的目录；均不存在返回 ''。</summary>
    class function FirstExistingDir(const ACandidates: array of string): string;

    /// <summary>在候选文件列表中返回第一个存在的文件；均不存在返回 ''。</summary>
    class function FirstExistingFile(const ACandidates: array of string): string;
  end;

implementation

const
  ROOT_MARKERS: array[0..1] of string = ('DeepBaseCore.dpk', 'tasks.md');

class function TTestPaths.RepoRoot: string;
var
  Dir: string;
  AllFound: Boolean;
  Marker: string;
begin
  Dir := ExtractFilePath(ParamStr(0));
  while Dir <> '' do
  begin
    AllFound := True;
    for Marker in ROOT_MARKERS do
      if not TFile.Exists(TPath.Combine(Dir, Marker)) then
      begin
        AllFound := False;
        Break;
      end;

    if AllFound then
      Exit(Dir);

    if TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(Dir)) = '' then
      Break;

    Dir := IncludeTrailingPathDelimiter(
      TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(Dir)));
  end;

  raise Exception.CreateFmt(
    string('TTestPaths.RepoRoot: 无法从可执行文件位置定位仓库根（需同时存在 %s 与 %s）。exe = %s'),
    [ROOT_MARKERS[0], ROOT_MARKERS[1], ParamStr(0)]);
end;

class function TTestPaths.RepoPath(const ARelativePath: string): string;
begin
  Result := TPath.Combine(RepoRoot, ARelativePath);
end;

class function TTestPaths.FirstExistingDir(const ACandidates: array of string): string;
var
  Candidate: string;
  Resolved: string;
begin
  for Candidate in ACandidates do
  begin
    if Candidate = '' then
      Continue;
    Resolved := Candidate;
    if not TDirectory.Exists(Resolved) then
    begin
      // 允许传入仓库相对路径（以 '\' 开头视为相对仓库根）
      if Candidate[1] = '\' then
        Resolved := RepoPath(string(Copy(Candidate, 2, MaxInt)));
    end;
    if TDirectory.Exists(Resolved) then
      Exit(Resolved);
  end;
  Result := '';
end;

class function TTestPaths.FirstExistingFile(const ACandidates: array of string): string;
var
  Candidate: string;
  Resolved: string;
begin
  for Candidate in ACandidates do
  begin
    if Candidate = '' then
      Continue;
    Resolved := Candidate;
    if not TFile.Exists(Resolved) then
    begin
      if Candidate[1] = '\' then
        Resolved := RepoPath(string(Copy(Candidate, 2, MaxInt)));
    end;
    if TFile.Exists(Resolved) then
      Exit(Resolved);
  end;
  Result := '';
end;

end.
