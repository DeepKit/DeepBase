{ ============================================================================
  DeepBase.ClipboardGuard - RAII Clipboard Protection
  Version: 0.7
  ============================================================================ }

unit DeepBase.ClipboardGuard;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  Winapi.Windows, Winapi.ShlObj,
  DeepBase.Exceptions, DeepBase.Logging;

type
  IClipboardGuard = interface
    ['{E1F2A3B4-5C6D-4E8F-9A1B-2C3D4E5F6A7B}']
    procedure Save;
    procedure SetContent(const Text: string);
    procedure SetContentBytes(const Fmt: Integer; const Data: TBytes);
    procedure DoPaste;
    procedure Restore;
    function GetOriginalContent: string;
    function IsSaved: Boolean;
  end;

  TClipboardGuard = class(TObject, IClipboardGuard)
  private
    FOriginalData: TDictionary<Cardinal, TBytes>;
    FOriginalFormats: TArray<Cardinal>;
    FSaved: Boolean;
    FRefCount: Integer;
    function TryOpenClipboard: Boolean;
    procedure RestoreInternal;
    function PreCheckMemory: Boolean;
    procedure SaveBackupToTemp;
    procedure SaveBackupToPath(const APath: string);
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Save;
    procedure SetContent(const Text: string);
    procedure SetContentBytes(const Fmt: Integer; const Data: TBytes);
    procedure DoPaste;
    procedure Restore;
    function GetOriginalContent: string;
    function IsSaved: Boolean;
  end;

implementation

constructor TClipboardGuard.Create;
begin
  inherited Create;
  FOriginalData := TDictionary<Cardinal, TBytes>.Create;
  Save;
end;

destructor TClipboardGuard.Destroy;
begin
  if FSaved then
  begin
    var Restored := False;
    for var I := 1 to 5 do
    begin
      if TryOpenClipboard then
      begin
        try
          if PreCheckMemory then
            RestoreInternal
          else
            Logger.Error('ClipboardGuard: insufficient memory for full restore', 'Clipboard');
          Restored := True;
          Break;
        finally
          CloseClipboard;
        end;
      end;
      Sleep(200);
    end;

    if not Restored then
    begin
      if not SaveBackupToTemp then
      begin
        var AppDataPath := GetEnvironmentVariable('APPDATA') +
          '\DeepBase\clipboard_backups\';
        ForceDirectories(AppDataPath);
        if not SaveBackupToPath(AppDataPath) then
          Logger.Fatal('ClipboardGuard: all restore paths failed', 'Clipboard');
      end;
    end;
  end;

  FOriginalData.Free;
  inherited;
end;

function TClipboardGuard._AddRef: Integer;
begin
  Inc(FRefCount);
  Result := FRefCount;
end;

function TClipboardGuard._Release: Integer;
begin
  Dec(FRefCount);
  Result := FRefCount;
  if Result = 0 then Destroy;
end;

function TClipboardGuard.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TClipboardGuard.TryOpenClipboard: Boolean;
begin
  Result := OpenClipboard(0);
end;

procedure TClipboardGuard.Save;
begin
  if not TryOpenClipboard then
  begin
    FSaved := False;
    Logger.Warn('ClipboardGuard: cannot open clipboard for save', 'Clipboard');
    Exit;
  end;

  try
    FOriginalData.Clear;
    SetLength(FOriginalFormats, 0);

    var Fmt: Cardinal := 0;
    while True do
    begin
      Fmt := EnumClipboardFormats(Fmt);
      if Fmt = 0 then Break;

      SetLength(FOriginalFormats, Length(FOriginalFormats) + 1);
      FOriginalFormats[High(FOriginalFormats)] := Fmt;

      var hData := GetClipboardData(Fmt);
      if hData <> 0 then
      begin
        var pData := GlobalLock(hData);
        var DataSize := GlobalSize(hData);
        if DataSize > 0 then
        begin
          var Bytes: TBytes;
          SetLength(Bytes, DataSize);
          Move(pData^, Bytes[0], DataSize);
          FOriginalData.AddOrSetValue(Fmt, Bytes);
        end;
        GlobalUnlock(hData);
      end;
    end;

    FSaved := True;
  finally
    CloseClipboard;
  end;
end;

procedure TClipboardGuard.SetContent(const Text: string);
begin
  if not TryOpenClipboard then
  begin
    Logger.Warn('SetContent: clipboard busy, retrying', 'Clipboard');
    Sleep(50);
    if not TryOpenClipboard then
      raise EClipboardError.Create('Cannot open clipboard for SetContent');
  end;
  try
    EmptyClipboard;
    var CharSize := (Length(Text) + 1) * SizeOf(Char);
    var hMem := GlobalAlloc(GMEM_MOVEABLE, CharSize);
    var pMem := GlobalLock(hMem);
    Move(PChar(Text)^, pMem^, CharSize);
    GlobalUnlock(hMem);
    SetClipboardData(CF_UNICODETEXT, hMem);
  finally
    CloseClipboard;
  end;
end;

procedure TClipboardGuard.SetContentBytes(const Fmt: Integer; const Data: TBytes);
begin
  if not TryOpenClipboard then
    raise EClipboardError.Create('Cannot open clipboard for SetContentBytes');
  try
    EmptyClipboard;
    var hMem := GlobalAlloc(GMEM_MOVEABLE, Length(Data));
    var pMem := GlobalLock(hMem);
    Move(Data[0], pMem^, Length(Data));
    GlobalUnlock(hMem);
    SetClipboardData(Fmt, hMem);
  finally
    CloseClipboard;
  end;
end;

procedure TClipboardGuard.DoPaste;
var
  Inputs: array[0..3] of TInput;
begin
  ZeroMemory(@Inputs[0], SizeOf(TInput));
  Inputs[0].Itype := INPUT_KEYBOARD;
  Inputs[0].ki.wVk := VK_CONTROL;
  Inputs[0].ki.wScan := MapVirtualKey(VK_CONTROL, 0);

  SendInput(1, Inputs[0], SizeOf(TInput));
  Sleep(5);

  ZeroMemory(@Inputs[1], SizeOf(TInput));
  Inputs[1].Itype := INPUT_KEYBOARD;
  Inputs[1].ki.wVk := Ord('V');
  Inputs[1].ki.wScan := MapVirtualKey(Ord('V'), 0);

  ZeroMemory(@Inputs[2], SizeOf(TInput));
  Inputs[2].Itype := INPUT_KEYBOARD;
  Inputs[2].ki.wVk := Ord('V');
  Inputs[2].ki.wScan := MapVirtualKey(Ord('V'), 0);
  Inputs[2].ki.dwFlags := KEYEVENTF_KEYUP;

  ZeroMemory(@Inputs[3], SizeOf(TInput));
  Inputs[3].Itype := INPUT_KEYBOARD;
  Inputs[3].ki.wVk := VK_CONTROL;
  Inputs[3].ki.wScan := MapVirtualKey(VK_CONTROL, 0);
  Inputs[3].ki.dwFlags := KEYEVENTF_KEYUP;

  SendInput(3, Inputs[1], SizeOf(TInput));
end;

procedure TClipboardGuard.Restore;
begin
  if not FSaved then Exit;
  if TryOpenClipboard then
  begin
    try
      RestoreInternal;
    finally
      CloseClipboard;
    end;
  end;
end;

procedure TClipboardGuard.RestoreInternal;
begin
  if Length(FOriginalFormats) = 0 then Exit;
  EmptyClipboard;
  for var Fmt in FOriginalFormats do
  begin
    if not FOriginalData.ContainsKey(Fmt) then Continue;
    var Bytes := FOriginalData[Fmt];
    if Length(Bytes) = 0 then Continue;
    var hMem := GlobalAlloc(GMEM_MOVEABLE, Length(Bytes));
    var pMem := GlobalLock(hMem);
    Move(Bytes[0], pMem^, Length(Bytes));
    GlobalUnlock(hMem);
    SetClipboardData(Fmt, hMem);
  end;
end;

function TClipboardGuard.PreCheckMemory: Boolean;
begin
  var TotalBytes: Int64 := 0;
  for var Fmt in FOriginalFormats do
    if FOriginalData.ContainsKey(Fmt) then
      Inc(TotalBytes, Length(FOriginalData[Fmt]));

  var MemStatus: TMemoryStatusEx;
  MemStatus.dwLength := SizeOf(MemStatus);
  GlobalMemoryStatusEx(MemStatus);
  Result := MemStatus.ullAvailPhys > UInt64(TotalBytes) * 2;
end;

procedure TClipboardGuard.SaveBackupToTemp;
begin
  var TempPath := GetEnvironmentVariable('TEMP') + '\DeepBase\';
  ForceDirectories(TempPath);
  SaveBackupToPath(TempPath);
end;

procedure TClipboardGuard.SaveBackupToPath(const APath: string);
begin
  try
    var FilePath := APath + Format('clipboard_backup_%s.bin',
      [FormatDateTime('yyyymmdd_hhnnss', Now)]);
    var Stream := TFileStream.Create(FilePath, fmCreate);
    try
      var FmtCount := Length(FOriginalFormats);
      Stream.Write(FmtCount, SizeOf(FmtCount));
      for var Fmt in FOriginalFormats do
      begin
        Stream.Write(Fmt, SizeOf(Fmt));
        var Bytes: TBytes;
        if FOriginalData.TryGetValue(Fmt, Bytes) then
        begin
          var Len := Length(Bytes);
          Stream.Write(Len, SizeOf(Len));
          if Len > 0 then
            Stream.Write(Bytes[0], Len);
        end
        else
        begin
          var Len: Integer := 0;
          Stream.Write(Len, SizeOf(Len));
        end;
      end;
    finally
      Stream.Free;
    end;
    Logger.InfoFmt('ClipboardGuard: backup saved to %s', [FilePath], 'Clipboard');
  except
    on E: Exception do
      Logger.ErrorFmt('SaveBackupToPath failed: %s', [E.Message], 'Clipboard');
  end;
end;

function TClipboardGuard.GetOriginalContent: string;
begin
  Result := '';
end;

function TClipboardGuard.IsSaved: Boolean;
begin
  Result := FSaved;
end;

end.
