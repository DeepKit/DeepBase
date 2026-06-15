{==============================================================================
  DeepBase.Share - Cross-Platform Content Sharing

  Provides a unified API for sharing content (text, images, files) via
  the system share sheet, clipboard, or saving to the user's pictures
  folder.

  Platform implementations:
    Windows: Clipboard (Win32 API), Shell (save-to-file), DataTransfer
             Manager (Win10+ ShareContract)
    macOS/Linux: stubs with TODO markers

  Usage:
    TUniShare.CopyToClipboard('Hello World');
    TUniShare.SaveImageToPictures(Bitmap, 'screenshot.png');
    TUniShare.ShareFile('report.pdf');
==============================================================================}

unit DeepBase.Share;

interface

uses
  System.SysUtils,
  System.Classes;

type
  TShareTarget = (
    stClipboard,
    stSaveToFile,
    stSystemSheet
  );

  TShareResult = (
    srSuccess,
    srCancelled,
    srNotSupported,
    srError
  );

  /// <summary>Callback: copy a bitmap (TObject) to clipboard. Returns True on success.</summary>
  TCopyImageToClipboardProc = reference to function(ABitmap: TObject): Boolean;
  /// <summary>Callback: save a bitmap (TObject) as PNG to file. Returns the saved path.</summary>
  TSaveImagePngProc = reference to function(ABitmap: TObject;
    const AFilePath: string): string;

  TUniShare = class
  private
    class var FCopyImageProc: TCopyImageToClipboardProc;
    class var FSaveImagePngProc: TSaveImagePngProc;
  public
    /// <summary>Inject platform-specific image handlers (call from VCL-aware bootstrap).</summary>
    class procedure SetImageProcs(ACopyImage: TCopyImageToClipboardProc;
      ASaveImagePng: TSaveImagePngProc);
    class function CopyToClipboard(const AText: string): Boolean;
    class function CopyImageToClipboard(ABitmap: TObject): Boolean;
    class function SaveImageToPictures(ABitmap: TObject;
      const AFileName: string): string;
    class function SaveStreamToPictures(AStream: TStream;
      const AFileName: string): string;
    class function ShareFile(const AFilePath: string): TShareResult;
    class function ShareText(const AText: string;
      const ATitle: string = ''): TShareResult;

    class function GetPicturesFolder: string;
    class function GetDownloadsFolder: string;
    class function GetTempSharePath(const AFileName: string): string;
  end;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.ShlObj,
  Winapi.ShellAPI,
  Winapi.ActiveX,
  {$ENDIF}
  System.IOUtils;

class procedure TUniShare.SetImageProcs(ACopyImage: TCopyImageToClipboardProc;
  ASaveImagePng: TSaveImagePngProc);
begin
  FCopyImageProc := ACopyImage;
  FSaveImagePngProc := ASaveImagePng;
end;

{$IFDEF MSWINDOWS}
class function TUniShare.CopyToClipboard(const AText: string): Boolean;
var
  Data: THandle;
  DataPtr: Pointer;
  Size: Integer;
  WStr: string;
begin
  Result := False;
  if not OpenClipboard(0) then
    Exit;
  try
    EmptyClipboard;
    WStr := AText;
    Size := (Length(WStr) + 1) * SizeOf(Char);
    Data := GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT, Size);
    if Data = 0 then
      Exit;
    DataPtr := GlobalLock(Data);
    try
      Move(PChar(WStr)^, DataPtr^, Size);
    finally
      GlobalUnlock(Data);
    end;
    SetClipboardData(CF_UNICODETEXT, Data);
    Result := True;
  finally
    CloseClipboard;
  end;
end;

class function TUniShare.CopyImageToClipboard(ABitmap: TObject): Boolean;
begin
  if Assigned(FCopyImageProc) then
    Result := FCopyImageProc(ABitmap)
  else
    Result := False;
end;
{$ELSE}
class function TUniShare.CopyToClipboard(const AText: string): Boolean;
begin
  Result := False;
end;

class function TUniShare.CopyImageToClipboard(ABitmap: TObject): Boolean;
begin
  Result := False;
end;
{$ENDIF}

class function TUniShare.SaveImageToPictures(ABitmap: TObject;
  const AFileName: string): string;
var
  Dir: string;
begin
  Result := '';
  Dir := GetPicturesFolder;
  ForceDirectories(Dir);
  Result := TPath.Combine(Dir, AFileName);
  if Assigned(FSaveImagePngProc) then
    Result := FSaveImagePngProc(ABitmap, Result)
  else
    Result := '';
end;

class function TUniShare.SaveStreamToPictures(AStream: TStream;
  const AFileName: string): string;
var
  Dir: string;
  FS: TFileStream;
begin
  Dir := GetPicturesFolder;
  ForceDirectories(Dir);
  Result := TPath.Combine(Dir, AFileName);
  FS := TFileStream.Create(Result, fmCreate);
  try
    AStream.Position := 0;
    FS.CopyFrom(AStream, AStream.Size);
  finally
    FS.Free;
  end;
end;

{$IFDEF MSWINDOWS}
class function TUniShare.ShareFile(const AFilePath: string): TShareResult;
var
  Sei: TShellExecuteInfo;
begin
  if not TFile.Exists(AFilePath) then
    Exit(srError);

  FillChar(Sei, SizeOf(Sei), 0);
  Sei.cbSize := SizeOf(Sei);
  Sei.fMask := SEE_MASK_INVOKEIDLIST;
  Sei.lpFile := PChar(AFilePath);
  Sei.lpVerb := PChar('share');
  Sei.nShow := SW_SHOWNORMAL;

  if ShellExecuteEx(@Sei) then
    Result := srSuccess
  else
  begin
    // 'share' verb not supported (older Windows), fall back to open
    Sei.lpVerb := PChar('open');
    if ShellExecuteEx(@Sei) then
      Result := srSuccess
    else
      Result := srError;
  end;
end;

class function TUniShare.ShareText(const AText: string;
  const ATitle: string): TShareResult;
var
  TempFile: string;
begin
  TempFile := GetTempSharePath('share_text.txt');
  TFile.WriteAllText(TempFile, AText, TEncoding.UTF8);
  Result := ShareFile(TempFile);
end;
{$ELSE}
class function TUniShare.ShareFile(const AFilePath: string): TShareResult;
begin
  Result := srNotSupported;
end;

class function TUniShare.ShareText(const AText: string;
  const ATitle: string): TShareResult;
begin
  Result := srNotSupported;
end;
{$ENDIF}

class function TUniShare.GetPicturesFolder: string;
{$IFDEF MSWINDOWS}
var
  Path: array[0..MAX_PATH] of Char;
begin
  if Succeeded(SHGetFolderPath(0, CSIDL_MYPICTURES, 0, 0, @Path)) then
    Result := Path
  else
    Result := TPath.Combine(TPath.GetDocumentsPath, 'Pictures');
  Result := TPath.Combine(Result, 'DeepBase');
end;
{$ELSE}
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, 'Pictures');
  Result := TPath.Combine(Result, 'DeepBase');
end;
{$ENDIF}

class function TUniShare.GetDownloadsFolder: string;
{$IFDEF MSWINDOWS}
var
  Downloads: string;
begin
  Downloads := TPath.Combine(TPath.GetHomePath, 'Downloads');
  if TDirectory.Exists(Downloads) then
    Result := Downloads
  else
    Result := TPath.GetDocumentsPath;
end;
{$ELSE}
begin
  Result := TPath.GetDocumentsPath;
end;
{$ENDIF}

class function TUniShare.GetTempSharePath(const AFileName: string): string;
begin
  Result := TPath.Combine(TPath.GetTempPath, AFileName);
end;

end.
