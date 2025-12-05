unit UniBase.Compression;

{*******************************************************************************
  UniBase Compression Utilities
  A comprehensive compression module with:
  - GZip/Deflate compression using System.ZLib
  - ZIP archive support using System.Zip
  - Stream-based compression/decompression
  - Multi-format support (ZIP, GZip, Deflate)
  - Progress callbacks
  - Memory and file-based operations
  - Compression level control
  
  Author: UniBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.ZLib, System.Zip, System.Types,
  System.Generics.Collections, System.IOUtils, System.SyncObjs;

type
  ECompressionException = class(Exception);

  /// <summary>Compression level</summary>
  TCompressionLevel = (
    clNone,       // No compression
    clFastest,    // Fastest compression
    clDefault,    // Default compression
    clMax         // Maximum compression
  );

  /// <summary>Compression format</summary>
  TCompressionFormat = (
    cfDeflate,    // Raw deflate
    cfGZip,       // GZip format
    cfZLib        // ZLib format with header
  );

  /// <summary>Progress callback</summary>
  TCompressionProgress = reference to procedure(AProcessed, ATotal: Int64; var ACancel: Boolean);

  /// <summary>Compression statistics</summary>
  TCompressionStats = record
    OriginalSize: Int64;
    CompressedSize: Int64;
    CompressionRatio: Double;
    ElapsedMs: Int64;
    
    function ToString: string;
  end;

  /// <summary>ZIP entry info</summary>
  TZipEntryInfo = record
    FileName: string;
    UncompressedSize: Int64;
    CompressedSize: Int64;
    CRC32: Cardinal;
    IsDirectory: Boolean;
    IsEncrypted: Boolean;
    ModifiedDate: TDateTime;
    Comment: string;
    
    function CompressionRatio: Double;
  end;

  /// <summary>ZIP archive reader</summary>
  TZipArchiveReader = class
  private
    FZipFile: TZipFile;
    FFileName: string;
    FEntries: TList<TZipEntryInfo>;
    
    procedure LoadEntries;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    
    /// <summary>Get entry count</summary>
    function EntryCount: Integer;
    
    /// <summary>Get entry info</summary>
    function GetEntry(AIndex: Integer): TZipEntryInfo;
    function FindEntry(const AEntryName: string): Integer;
    
    /// <summary>Check if entry exists</summary>
    function ContainsEntry(const AEntryName: string): Boolean;
    
    /// <summary>Extract single entry to stream</summary>
    procedure ExtractToStream(const AEntryName: string; AStream: TStream); overload;
    procedure ExtractToStream(AIndex: Integer; AStream: TStream); overload;
    
    /// <summary>Extract single entry to file</summary>
    procedure ExtractToFile(const AEntryName, ADestFileName: string);
    
    /// <summary>Extract all entries to directory</summary>
    procedure ExtractAll(const ADestDir: string; AProgress: TCompressionProgress = nil);
    
    /// <summary>Read entry as bytes</summary>
    function ReadBytes(const AEntryName: string): TBytes;
    
    /// <summary>Read entry as string</summary>
    function ReadString(const AEntryName: string; AEncoding: TEncoding = nil): string;
    
    /// <summary>List all entries</summary>
    function GetEntries: TArray<TZipEntryInfo>;
    
    property FileName: string read FFileName;
  end;

  /// <summary>ZIP archive writer</summary>
  TZipArchiveWriter = class
  private
    FZipFile: TZipFile;
    FFileName: string;
    FComment: string;
    FCompressionLevel: TCompressionLevel;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    
    /// <summary>Add file to archive</summary>
    procedure AddFile(const AFileName: string; const AArchiveName: string = '');
    
    /// <summary>Add stream to archive</summary>
    procedure AddStream(const AArchiveName: string; AStream: TStream);
    
    /// <summary>Add bytes to archive</summary>
    procedure AddBytes(const AArchiveName: string; const AData: TBytes);
    
    /// <summary>Add string to archive</summary>
    procedure AddString(const AArchiveName: string; const AData: string; AEncoding: TEncoding = nil);
    
    /// <summary>Add directory to archive</summary>
    procedure AddDirectory(const ASourceDir: string; const AArchiveDir: string = ''; 
      ARecursive: Boolean = True; AProgress: TCompressionProgress = nil);
    
    /// <summary>Set archive comment</summary>
    procedure SetComment(const AComment: string);
    
    /// <summary>Close and finalize archive</summary>
    procedure Close;
    
    property CompressionLevel: TCompressionLevel read FCompressionLevel write FCompressionLevel;
    property FileName: string read FFileName;
  end;

  /// <summary>GZip compressor</summary>
  TGZipCompressor = class
  private
    FCompressionLevel: TCompressionLevel;
    
    class function GetZLibLevel(ALevel: TCompressionLevel): TZCompressionLevel; static;
  public
    constructor Create;
    
    /// <summary>Compress stream</summary>
    procedure CompressStream(ASource, ADest: TStream; AProgress: TCompressionProgress = nil);
    
    /// <summary>Decompress stream</summary>
    procedure DecompressStream(ASource, ADest: TStream; AProgress: TCompressionProgress = nil);
    
    /// <summary>Compress bytes</summary>
    function CompressBytes(const AData: TBytes): TBytes;
    
    /// <summary>Decompress bytes</summary>
    function DecompressBytes(const AData: TBytes): TBytes;
    
    /// <summary>Compress string</summary>
    function CompressString(const AData: string; AEncoding: TEncoding = nil): TBytes;
    
    /// <summary>Decompress to string</summary>
    function DecompressString(const AData: TBytes; AEncoding: TEncoding = nil): string;
    
    /// <summary>Compress file</summary>
    function CompressFile(const ASourceFile, ADestFile: string; 
      AProgress: TCompressionProgress = nil): TCompressionStats;
    
    /// <summary>Decompress file</summary>
    function DecompressFile(const ASourceFile, ADestFile: string;
      AProgress: TCompressionProgress = nil): TCompressionStats;
    
    property CompressionLevel: TCompressionLevel read FCompressionLevel write FCompressionLevel;
  end;

  /// <summary>Deflate compressor</summary>
  TDeflateCompressor = class
  private
    FCompressionLevel: TCompressionLevel;
    FFormat: TCompressionFormat;
    
    class function GetZLibLevel(ALevel: TCompressionLevel): TZCompressionLevel; static;
  public
    constructor Create(AFormat: TCompressionFormat = cfDeflate);
    
    /// <summary>Compress stream</summary>
    procedure CompressStream(ASource, ADest: TStream; AProgress: TCompressionProgress = nil);
    
    /// <summary>Decompress stream</summary>
    procedure DecompressStream(ASource, ADest: TStream; AProgress: TCompressionProgress = nil);
    
    /// <summary>Compress bytes</summary>
    function CompressBytes(const AData: TBytes): TBytes;
    
    /// <summary>Decompress bytes</summary>
    function DecompressBytes(const AData: TBytes): TBytes;
    
    property CompressionLevel: TCompressionLevel read FCompressionLevel write FCompressionLevel;
    property Format: TCompressionFormat read FFormat write FFormat;
  end;

  /// <summary>Compression helper with progress stream</summary>
  TProgressStream = class(TStream)
  private
    FStream: TStream;
    FOwnsStream: Boolean;
    FPosition: Int64;
    FTotal: Int64;
    FProgress: TCompressionProgress;
    FCancelled: Boolean;
    FLastProgress: Int64;
    FProgressInterval: Int64;
  protected
    function GetSize: Int64; override;
    procedure SetSize(NewSize: Longint); override;
    procedure SetSize(const NewSize: Int64); override;
  public
    constructor Create(AStream: TStream; ATotal: Int64; AProgress: TCompressionProgress;
      AOwnsStream: Boolean = False);
    destructor Destroy; override;
    
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    
    property Cancelled: Boolean read FCancelled;
    property ProgressInterval: Int64 read FProgressInterval write FProgressInterval;
  end;

  /// <summary>Compression utilities static class</summary>
  TCompression = class
  public
    /// <summary>GZip compression</summary>
    class function GZipCompress(const AData: TBytes; ALevel: TCompressionLevel = clDefault): TBytes; static;
    class function GZipDecompress(const AData: TBytes): TBytes; static;
    
    class function GZipCompressString(const AData: string; ALevel: TCompressionLevel = clDefault): TBytes; static;
    class function GZipDecompressString(const AData: TBytes): string; static;
    
    class procedure GZipCompressFile(const ASourceFile, ADestFile: string; 
      ALevel: TCompressionLevel = clDefault); static;
    class procedure GZipDecompressFile(const ASourceFile, ADestFile: string); static;
    
    /// <summary>Deflate compression</summary>
    class function DeflateCompress(const AData: TBytes; ALevel: TCompressionLevel = clDefault): TBytes; static;
    class function DeflateDecompress(const AData: TBytes): TBytes; static;
    
    /// <summary>ZLib compression</summary>
    class function ZLibCompress(const AData: TBytes; ALevel: TCompressionLevel = clDefault): TBytes; static;
    class function ZLibDecompress(const AData: TBytes): TBytes; static;
    
    /// <summary>ZIP operations</summary>
    class procedure ZipDirectory(const ASourceDir, AZipFile: string;
      AProgress: TCompressionProgress = nil); static;
    class procedure UnzipToDirectory(const AZipFile, ADestDir: string;
      AProgress: TCompressionProgress = nil); static;
    
    class procedure ZipFiles(const AFiles: TArray<string>; const AZipFile: string;
      AProgress: TCompressionProgress = nil); static;
    
    /// <summary>Check if file is a valid ZIP</summary>
    class function IsValidZip(const AFileName: string): Boolean; static;
    
    /// <summary>Check if data is GZip compressed</summary>
    class function IsGZipData(const AData: TBytes): Boolean; static;
    
    /// <summary>Get compression ratio</summary>
    class function CalculateRatio(AOriginal, ACompressed: Int64): Double; static;
  end;

  /// <summary>Builder for compression operations</summary>
  TCompressionBuilder = class
  private
    FLevel: TCompressionLevel;
    FFormat: TCompressionFormat;
    FProgress: TCompressionProgress;
  public
    constructor Create;
    
    function Level(ALevel: TCompressionLevel): TCompressionBuilder;
    function Format(AFormat: TCompressionFormat): TCompressionBuilder;
    function OnProgress(AProgress: TCompressionProgress): TCompressionBuilder;
    
    function Compress(const AData: TBytes): TBytes;
    function Decompress(const AData: TBytes): TBytes;
    
    function CompressStream(ASource, ADest: TStream): TCompressionBuilder;
    function DecompressStream(ASource, ADest: TStream): TCompressionBuilder;
    
    function CompressFile(const ASource, ADest: string): TCompressionStats;
    function DecompressFile(const ASource, ADest: string): TCompressionStats;
  end;

implementation

uses
  System.DateUtils, System.Diagnostics;

{ TCompressionStats }

function TCompressionStats.ToString: string;
begin
  Result := System.SysUtils.Format('Original: %d bytes, Compressed: %d bytes, Ratio: %.1f%%, Time: %d ms',
    [OriginalSize, CompressedSize, CompressionRatio * 100, ElapsedMs]);
end;

{ TZipEntryInfo }

function TZipEntryInfo.CompressionRatio: Double;
begin
  if UncompressedSize > 0 then
    Result := 1 - (CompressedSize / UncompressedSize)
  else
    Result := 0;
end;

{ TZipArchiveReader }

constructor TZipArchiveReader.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FEntries := TList<TZipEntryInfo>.Create;
  FZipFile := TZipFile.Create;
  FZipFile.Open(AFileName, zmRead);
  LoadEntries;
end;

destructor TZipArchiveReader.Destroy;
begin
  if FZipFile.Mode <> zmClosed then
    FZipFile.Close;
  FZipFile.Free;
  FEntries.Free;
  inherited;
end;

procedure TZipArchiveReader.LoadEntries;
var
  I: Integer;
  LHeader: TZipHeader;
  LEntry: TZipEntryInfo;
begin
  FEntries.Clear;
  for I := 0 to FZipFile.FileCount - 1 do
  begin
    LHeader := FZipFile.FileInfo[I];
    LEntry.FileName := FZipFile.FileName[I];
    LEntry.UncompressedSize := LHeader.UncompressedSize;
    LEntry.CompressedSize := LHeader.CompressedSize;
    LEntry.CRC32 := LHeader.CRC32;
    LEntry.IsDirectory := LEntry.FileName.EndsWith('/') or LEntry.FileName.EndsWith('\');
    LEntry.IsEncrypted := (LHeader.Flag and 1) <> 0;
    LEntry.ModifiedDate := FileDateToDateTime(LHeader.ModifiedDateTime);
    LEntry.Comment := '';
    FEntries.Add(LEntry);
  end;
end;

function TZipArchiveReader.EntryCount: Integer;
begin
  Result := FEntries.Count;
end;

function TZipArchiveReader.GetEntry(AIndex: Integer): TZipEntryInfo;
begin
  Result := FEntries[AIndex];
end;

function TZipArchiveReader.FindEntry(const AEntryName: string): Integer;
var
  I: Integer;
  LNormalized: string;
begin
  LNormalized := AEntryName.Replace('\', '/');
  for I := 0 to FEntries.Count - 1 do
  begin
    if SameText(FEntries[I].FileName.Replace('\', '/'), LNormalized) then
      Exit(I);
  end;
  Result := -1;
end;

function TZipArchiveReader.ContainsEntry(const AEntryName: string): Boolean;
begin
  Result := FindEntry(AEntryName) >= 0;
end;

procedure TZipArchiveReader.ExtractToStream(const AEntryName: string; AStream: TStream);
var
  LIndex: Integer;
begin
  LIndex := FindEntry(AEntryName);
  if LIndex < 0 then
    raise ECompressionException.CreateFmt('Entry not found: %s', [AEntryName]);
  ExtractToStream(Integer(LIndex), AStream);
end;

procedure TZipArchiveReader.ExtractToStream(AIndex: Integer; AStream: TStream);
var
  LBytes: TBytes;
begin
  FZipFile.Read(AIndex, LBytes);
  if Length(LBytes) > 0 then
    AStream.WriteBuffer(LBytes[0], Length(LBytes));
end;

procedure TZipArchiveReader.ExtractToFile(const AEntryName, ADestFileName: string);
var
  LStream: TFileStream;
begin
  ForceDirectories(ExtractFilePath(ADestFileName));
  LStream := TFileStream.Create(ADestFileName, fmCreate);
  try
    ExtractToStream(AEntryName, LStream);
  finally
    LStream.Free;
  end;
end;

procedure TZipArchiveReader.ExtractAll(const ADestDir: string; AProgress: TCompressionProgress);
var
  I: Integer;
  LEntry: TZipEntryInfo;
  LDestPath: string;
  LCancel: Boolean;
begin
  LCancel := False;
  for I := 0 to FEntries.Count - 1 do
  begin
    LEntry := FEntries[I];
    LDestPath := TPath.Combine(ADestDir, LEntry.FileName.Replace('/', PathDelim));
    
    if LEntry.IsDirectory then
      ForceDirectories(LDestPath)
    else
    begin
      ForceDirectories(ExtractFilePath(LDestPath));
      FZipFile.Extract(I, ADestDir);
    end;
    
    if Assigned(AProgress) then
    begin
      AProgress(I + 1, FEntries.Count, LCancel);
      if LCancel then
        Break;
    end;
  end;
end;

function TZipArchiveReader.ReadBytes(const AEntryName: string): TBytes;
var
  LStream: TMemoryStream;
begin
  LStream := TMemoryStream.Create;
  try
    ExtractToStream(AEntryName, LStream);
    SetLength(Result, LStream.Size);
    if LStream.Size > 0 then
    begin
      LStream.Position := 0;
      LStream.ReadBuffer(Result[0], LStream.Size);
    end;
  finally
    LStream.Free;
  end;
end;

function TZipArchiveReader.ReadString(const AEntryName: string; AEncoding: TEncoding): string;
var
  LBytes: TBytes;
begin
  if AEncoding = nil then
    AEncoding := TEncoding.UTF8;
  LBytes := ReadBytes(AEntryName);
  Result := AEncoding.GetString(LBytes);
end;

function TZipArchiveReader.GetEntries: TArray<TZipEntryInfo>;
begin
  Result := FEntries.ToArray;
end;

{ TZipArchiveWriter }

constructor TZipArchiveWriter.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FCompressionLevel := clDefault;
  FZipFile := TZipFile.Create;
  FZipFile.Open(AFileName, zmWrite);
end;

destructor TZipArchiveWriter.Destroy;
begin
  Close;
  FZipFile.Free;
  inherited;
end;

procedure TZipArchiveWriter.AddFile(const AFileName: string; const AArchiveName: string);
var
  LArchiveName: string;
begin
  if AArchiveName = '' then
    LArchiveName := ExtractFileName(AFileName)
  else
    LArchiveName := AArchiveName;
  FZipFile.Add(AFileName, LArchiveName);
end;

procedure TZipArchiveWriter.AddStream(const AArchiveName: string; AStream: TStream);
var
  LBytes: TBytes;
begin
  SetLength(LBytes, AStream.Size);
  if AStream.Size > 0 then
  begin
    AStream.Position := 0;
    AStream.ReadBuffer(LBytes[0], AStream.Size);
  end;
  AddBytes(AArchiveName, LBytes);
end;

procedure TZipArchiveWriter.AddBytes(const AArchiveName: string; const AData: TBytes);
begin
  FZipFile.Add(AData, AArchiveName);
end;

procedure TZipArchiveWriter.AddString(const AArchiveName: string; const AData: string;
  AEncoding: TEncoding);
begin
  if AEncoding = nil then
    AEncoding := TEncoding.UTF8;
  AddBytes(AArchiveName, AEncoding.GetBytes(AData));
end;

procedure TZipArchiveWriter.AddDirectory(const ASourceDir: string; const AArchiveDir: string;
  ARecursive: Boolean; AProgress: TCompressionProgress);
var
  LFiles: TStringDynArray;
  LFile, LRelPath, LArchivePath: string;
  LCancel: Boolean;
  I: Integer;
begin
  if ARecursive then
    LFiles := TDirectory.GetFiles(ASourceDir, '*', TSearchOption.soAllDirectories)
  else
    LFiles := TDirectory.GetFiles(ASourceDir, '*', TSearchOption.soTopDirectoryOnly);
    
  LCancel := False;
  for I := 0 to High(LFiles) do
  begin
    LFile := LFiles[I];
    LRelPath := LFile.Substring(Length(ASourceDir));
    if LRelPath.StartsWith(PathDelim) then
      LRelPath := LRelPath.Substring(1);
      
    if AArchiveDir <> '' then
      LArchivePath := AArchiveDir + '/' + LRelPath.Replace('\', '/')
    else
      LArchivePath := LRelPath.Replace('\', '/');
      
    AddFile(LFile, LArchivePath);
    
    if Assigned(AProgress) then
    begin
      AProgress(I + 1, Length(LFiles), LCancel);
      if LCancel then
        Break;
    end;
  end;
end;

procedure TZipArchiveWriter.SetComment(const AComment: string);
begin
  FComment := AComment;
end;

procedure TZipArchiveWriter.Close;
begin
  if FZipFile.Mode <> zmClosed then
  begin
    if FComment <> '' then
      FZipFile.Comment := FComment;
    FZipFile.Close;
  end;
end;

{ TGZipCompressor }

constructor TGZipCompressor.Create;
begin
  inherited Create;
  FCompressionLevel := clDefault;
end;

class function TGZipCompressor.GetZLibLevel(ALevel: TCompressionLevel): TZCompressionLevel;
begin
  case ALevel of
    clNone: Result := zcNone;
    clFastest: Result := zcFastest;
    clMax: Result := zcMax;
  else
    Result := zcDefault;
  end;
end;

procedure TGZipCompressor.CompressStream(ASource, ADest: TStream; AProgress: TCompressionProgress);
var
  LCompressor: TZCompressionStream;
  LProgressStream: TProgressStream;
  LBuffer: TBytes;
  LRead: Integer;
begin
  if Assigned(AProgress) then
    LProgressStream := TProgressStream.Create(ASource, ASource.Size, AProgress)
  else
    LProgressStream := nil;
    
  try
    LCompressor := TZCompressionStream.Create(ADest, GetZLibLevel(FCompressionLevel), 15 + 16);
    try
      SetLength(LBuffer, 65536);
      if Assigned(LProgressStream) then
      begin
        repeat
          LRead := LProgressStream.Read(LBuffer[0], Length(LBuffer));
          if LRead > 0 then
            LCompressor.WriteBuffer(LBuffer[0], LRead);
        until (LRead = 0) or LProgressStream.Cancelled;
      end
      else
      begin
        repeat
          LRead := ASource.Read(LBuffer[0], Length(LBuffer));
          if LRead > 0 then
            LCompressor.WriteBuffer(LBuffer[0], LRead);
        until LRead = 0;
      end;
    finally
      LCompressor.Free;
    end;
  finally
    LProgressStream.Free;
  end;
end;

procedure TGZipCompressor.DecompressStream(ASource, ADest: TStream; AProgress: TCompressionProgress);
var
  LDecompressor: TZDecompressionStream;
  LProgressStream: TProgressStream;
  LBuffer: TBytes;
  LRead: Integer;
begin
  if Assigned(AProgress) then
    LProgressStream := TProgressStream.Create(ASource, ASource.Size, AProgress)
  else
    LProgressStream := nil;
    
  try
    if Assigned(LProgressStream) then
      LDecompressor := TZDecompressionStream.Create(LProgressStream, 15 + 16)
    else
      LDecompressor := TZDecompressionStream.Create(ASource, 15 + 16);
    try
      SetLength(LBuffer, 65536);
      repeat
        LRead := LDecompressor.Read(LBuffer[0], Length(LBuffer));
        if LRead > 0 then
          ADest.WriteBuffer(LBuffer[0], LRead);
      until LRead = 0;
    finally
      LDecompressor.Free;
    end;
  finally
    LProgressStream.Free;
  end;
end;

function TGZipCompressor.CompressBytes(const AData: TBytes): TBytes;
var
  LSource, LDest: TBytesStream;
begin
  LSource := TBytesStream.Create(AData);
  LDest := TBytesStream.Create;
  try
    CompressStream(LSource, LDest);
    Result := Copy(LDest.Bytes, 0, LDest.Size);
  finally
    LDest.Free;
    LSource.Free;
  end;
end;

function TGZipCompressor.DecompressBytes(const AData: TBytes): TBytes;
var
  LSource, LDest: TBytesStream;
begin
  LSource := TBytesStream.Create(AData);
  LDest := TBytesStream.Create;
  try
    DecompressStream(LSource, LDest);
    Result := Copy(LDest.Bytes, 0, LDest.Size);
  finally
    LDest.Free;
    LSource.Free;
  end;
end;

function TGZipCompressor.CompressString(const AData: string; AEncoding: TEncoding): TBytes;
begin
  if AEncoding = nil then
    AEncoding := TEncoding.UTF8;
  Result := CompressBytes(AEncoding.GetBytes(AData));
end;

function TGZipCompressor.DecompressString(const AData: TBytes; AEncoding: TEncoding): string;
begin
  if AEncoding = nil then
    AEncoding := TEncoding.UTF8;
  Result := AEncoding.GetString(DecompressBytes(AData));
end;

function TGZipCompressor.CompressFile(const ASourceFile, ADestFile: string;
  AProgress: TCompressionProgress): TCompressionStats;
var
  LSource, LDest: TFileStream;
  LStopwatch: TStopwatch;
begin
  LStopwatch := TStopwatch.StartNew;
  LSource := TFileStream.Create(ASourceFile, fmOpenRead or fmShareDenyWrite);
  try
    Result.OriginalSize := LSource.Size;
    LDest := TFileStream.Create(ADestFile, fmCreate);
    try
      CompressStream(LSource, LDest, AProgress);
      Result.CompressedSize := LDest.Size;
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
  LStopwatch.Stop;
  Result.ElapsedMs := LStopwatch.ElapsedMilliseconds;
  Result.CompressionRatio := TCompression.CalculateRatio(Result.OriginalSize, Result.CompressedSize);
end;

function TGZipCompressor.DecompressFile(const ASourceFile, ADestFile: string;
  AProgress: TCompressionProgress): TCompressionStats;
var
  LSource, LDest: TFileStream;
  LStopwatch: TStopwatch;
begin
  LStopwatch := TStopwatch.StartNew;
  LSource := TFileStream.Create(ASourceFile, fmOpenRead or fmShareDenyWrite);
  try
    Result.CompressedSize := LSource.Size;
    LDest := TFileStream.Create(ADestFile, fmCreate);
    try
      DecompressStream(LSource, LDest, AProgress);
      Result.OriginalSize := LDest.Size;
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
  LStopwatch.Stop;
  Result.ElapsedMs := LStopwatch.ElapsedMilliseconds;
  Result.CompressionRatio := TCompression.CalculateRatio(Result.OriginalSize, Result.CompressedSize);
end;

{ TDeflateCompressor }

constructor TDeflateCompressor.Create(AFormat: TCompressionFormat);
begin
  inherited Create;
  FCompressionLevel := clDefault;
  FFormat := AFormat;
end;

class function TDeflateCompressor.GetZLibLevel(ALevel: TCompressionLevel): TZCompressionLevel;
begin
  case ALevel of
    clNone: Result := zcNone;
    clFastest: Result := zcFastest;
    clMax: Result := zcMax;
  else
    Result := zcDefault;
  end;
end;

procedure TDeflateCompressor.CompressStream(ASource, ADest: TStream; AProgress: TCompressionProgress);
var
  LCompressor: TZCompressionStream;
  LProgressStream: TProgressStream;
  LBuffer: TBytes;
  LRead: Integer;
  LWindowBits: Integer;
begin
  case FFormat of
    cfDeflate: LWindowBits := -15;
    cfGZip: LWindowBits := 15 + 16;
    cfZLib: LWindowBits := 15;
  else
    LWindowBits := 15;
  end;
  
  if Assigned(AProgress) then
    LProgressStream := TProgressStream.Create(ASource, ASource.Size, AProgress)
  else
    LProgressStream := nil;
    
  try
    LCompressor := TZCompressionStream.Create(ADest, GetZLibLevel(FCompressionLevel), LWindowBits);
    try
      SetLength(LBuffer, 65536);
      if Assigned(LProgressStream) then
      begin
        repeat
          LRead := LProgressStream.Read(LBuffer[0], Length(LBuffer));
          if LRead > 0 then
            LCompressor.WriteBuffer(LBuffer[0], LRead);
        until (LRead = 0) or LProgressStream.Cancelled;
      end
      else
      begin
        repeat
          LRead := ASource.Read(LBuffer[0], Length(LBuffer));
          if LRead > 0 then
            LCompressor.WriteBuffer(LBuffer[0], LRead);
        until LRead = 0;
      end;
    finally
      LCompressor.Free;
    end;
  finally
    LProgressStream.Free;
  end;
end;

procedure TDeflateCompressor.DecompressStream(ASource, ADest: TStream; AProgress: TCompressionProgress);
var
  LDecompressor: TZDecompressionStream;
  LProgressStream: TProgressStream;
  LBuffer: TBytes;
  LRead: Integer;
  LWindowBits: Integer;
begin
  case FFormat of
    cfDeflate: LWindowBits := -15;
    cfGZip: LWindowBits := 15 + 16;
    cfZLib: LWindowBits := 15;
  else
    LWindowBits := 15;
  end;
  
  if Assigned(AProgress) then
    LProgressStream := TProgressStream.Create(ASource, ASource.Size, AProgress)
  else
    LProgressStream := nil;
    
  try
    if Assigned(LProgressStream) then
      LDecompressor := TZDecompressionStream.Create(LProgressStream, LWindowBits)
    else
      LDecompressor := TZDecompressionStream.Create(ASource, LWindowBits);
    try
      SetLength(LBuffer, 65536);
      repeat
        LRead := LDecompressor.Read(LBuffer[0], Length(LBuffer));
        if LRead > 0 then
          ADest.WriteBuffer(LBuffer[0], LRead);
      until LRead = 0;
    finally
      LDecompressor.Free;
    end;
  finally
    LProgressStream.Free;
  end;
end;

function TDeflateCompressor.CompressBytes(const AData: TBytes): TBytes;
var
  LSource, LDest: TBytesStream;
begin
  LSource := TBytesStream.Create(AData);
  LDest := TBytesStream.Create;
  try
    CompressStream(LSource, LDest);
    Result := Copy(LDest.Bytes, 0, LDest.Size);
  finally
    LDest.Free;
    LSource.Free;
  end;
end;

function TDeflateCompressor.DecompressBytes(const AData: TBytes): TBytes;
var
  LSource, LDest: TBytesStream;
begin
  LSource := TBytesStream.Create(AData);
  LDest := TBytesStream.Create;
  try
    DecompressStream(LSource, LDest);
    Result := Copy(LDest.Bytes, 0, LDest.Size);
  finally
    LDest.Free;
    LSource.Free;
  end;
end;

{ TProgressStream }

constructor TProgressStream.Create(AStream: TStream; ATotal: Int64;
  AProgress: TCompressionProgress; AOwnsStream: Boolean);
begin
  inherited Create;
  FStream := AStream;
  FOwnsStream := AOwnsStream;
  FTotal := ATotal;
  FProgress := AProgress;
  FPosition := 0;
  FCancelled := False;
  FLastProgress := 0;
  FProgressInterval := 65536;
end;

destructor TProgressStream.Destroy;
begin
  if FOwnsStream then
    FStream.Free;
  inherited;
end;

function TProgressStream.GetSize: Int64;
begin
  Result := FStream.Size;
end;

procedure TProgressStream.SetSize(NewSize: Longint);
begin
  FStream.Size := NewSize;
end;

procedure TProgressStream.SetSize(const NewSize: Int64);
begin
  FStream.Size := NewSize;
end;

function TProgressStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FStream.Read(Buffer, Count);
  Inc(FPosition, Result);
  
  if Assigned(FProgress) and ((FPosition - FLastProgress) >= FProgressInterval) then
  begin
    FProgress(FPosition, FTotal, FCancelled);
    FLastProgress := FPosition;
  end;
end;

function TProgressStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := FStream.Write(Buffer, Count);
  Inc(FPosition, Result);
  
  if Assigned(FProgress) and ((FPosition - FLastProgress) >= FProgressInterval) then
  begin
    FProgress(FPosition, FTotal, FCancelled);
    FLastProgress := FPosition;
  end;
end;

function TProgressStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := FStream.Seek(Offset, Origin);
  FPosition := Result;
end;

{ TCompression }

class function TCompression.GZipCompress(const AData: TBytes; ALevel: TCompressionLevel): TBytes;
var
  LCompressor: TGZipCompressor;
begin
  LCompressor := TGZipCompressor.Create;
  try
    LCompressor.CompressionLevel := ALevel;
    Result := LCompressor.CompressBytes(AData);
  finally
    LCompressor.Free;
  end;
end;

class function TCompression.GZipDecompress(const AData: TBytes): TBytes;
var
  LCompressor: TGZipCompressor;
begin
  LCompressor := TGZipCompressor.Create;
  try
    Result := LCompressor.DecompressBytes(AData);
  finally
    LCompressor.Free;
  end;
end;

class function TCompression.GZipCompressString(const AData: string; ALevel: TCompressionLevel): TBytes;
var
  LCompressor: TGZipCompressor;
begin
  LCompressor := TGZipCompressor.Create;
  try
    LCompressor.CompressionLevel := ALevel;
    Result := LCompressor.CompressString(AData);
  finally
    LCompressor.Free;
  end;
end;

class function TCompression.GZipDecompressString(const AData: TBytes): string;
var
  LCompressor: TGZipCompressor;
begin
  LCompressor := TGZipCompressor.Create;
  try
    Result := LCompressor.DecompressString(AData);
  finally
    LCompressor.Free;
  end;
end;

class procedure TCompression.GZipCompressFile(const ASourceFile, ADestFile: string;
  ALevel: TCompressionLevel);
var
  LCompressor: TGZipCompressor;
begin
  LCompressor := TGZipCompressor.Create;
  try
    LCompressor.CompressionLevel := ALevel;
    LCompressor.CompressFile(ASourceFile, ADestFile);
  finally
    LCompressor.Free;
  end;
end;

class procedure TCompression.GZipDecompressFile(const ASourceFile, ADestFile: string);
var
  LCompressor: TGZipCompressor;
begin
  LCompressor := TGZipCompressor.Create;
  try
    LCompressor.DecompressFile(ASourceFile, ADestFile);
  finally
    LCompressor.Free;
  end;
end;

class function TCompression.DeflateCompress(const AData: TBytes; ALevel: TCompressionLevel): TBytes;
var
  LCompressor: TDeflateCompressor;
begin
  LCompressor := TDeflateCompressor.Create(cfDeflate);
  try
    LCompressor.CompressionLevel := ALevel;
    Result := LCompressor.CompressBytes(AData);
  finally
    LCompressor.Free;
  end;
end;

class function TCompression.DeflateDecompress(const AData: TBytes): TBytes;
var
  LCompressor: TDeflateCompressor;
begin
  LCompressor := TDeflateCompressor.Create(cfDeflate);
  try
    Result := LCompressor.DecompressBytes(AData);
  finally
    LCompressor.Free;
  end;
end;

class function TCompression.ZLibCompress(const AData: TBytes; ALevel: TCompressionLevel): TBytes;
var
  LCompressor: TDeflateCompressor;
begin
  LCompressor := TDeflateCompressor.Create(cfZLib);
  try
    LCompressor.CompressionLevel := ALevel;
    Result := LCompressor.CompressBytes(AData);
  finally
    LCompressor.Free;
  end;
end;

class function TCompression.ZLibDecompress(const AData: TBytes): TBytes;
var
  LCompressor: TDeflateCompressor;
begin
  LCompressor := TDeflateCompressor.Create(cfZLib);
  try
    Result := LCompressor.DecompressBytes(AData);
  finally
    LCompressor.Free;
  end;
end;

class procedure TCompression.ZipDirectory(const ASourceDir, AZipFile: string;
  AProgress: TCompressionProgress);
var
  LWriter: TZipArchiveWriter;
begin
  LWriter := TZipArchiveWriter.Create(AZipFile);
  try
    LWriter.AddDirectory(ASourceDir, '', True, AProgress);
  finally
    LWriter.Free;
  end;
end;

class procedure TCompression.UnzipToDirectory(const AZipFile, ADestDir: string;
  AProgress: TCompressionProgress);
var
  LReader: TZipArchiveReader;
begin
  LReader := TZipArchiveReader.Create(AZipFile);
  try
    LReader.ExtractAll(ADestDir, AProgress);
  finally
    LReader.Free;
  end;
end;

class procedure TCompression.ZipFiles(const AFiles: TArray<string>; const AZipFile: string;
  AProgress: TCompressionProgress);
var
  LWriter: TZipArchiveWriter;
  I: Integer;
  LCancel: Boolean;
begin
  LCancel := False;
  LWriter := TZipArchiveWriter.Create(AZipFile);
  try
    for I := 0 to High(AFiles) do
    begin
      LWriter.AddFile(AFiles[I]);
      if Assigned(AProgress) then
      begin
        AProgress(I + 1, Length(AFiles), LCancel);
        if LCancel then
          Break;
      end;
    end;
  finally
    LWriter.Free;
  end;
end;

class function TCompression.IsValidZip(const AFileName: string): Boolean;
begin
  Result := TZipFile.IsValid(AFileName);
end;

class function TCompression.IsGZipData(const AData: TBytes): Boolean;
begin
  Result := (Length(AData) >= 2) and (AData[0] = $1F) and (AData[1] = $8B);
end;

class function TCompression.CalculateRatio(AOriginal, ACompressed: Int64): Double;
begin
  if AOriginal > 0 then
    Result := 1 - (ACompressed / AOriginal)
  else
    Result := 0;
end;

{ TCompressionBuilder }

constructor TCompressionBuilder.Create;
begin
  inherited Create;
  FLevel := clDefault;
  FFormat := cfGZip;
  FProgress := nil;
end;

function TCompressionBuilder.Level(ALevel: TCompressionLevel): TCompressionBuilder;
begin
  FLevel := ALevel;
  Result := Self;
end;

function TCompressionBuilder.Format(AFormat: TCompressionFormat): TCompressionBuilder;
begin
  FFormat := AFormat;
  Result := Self;
end;

function TCompressionBuilder.OnProgress(AProgress: TCompressionProgress): TCompressionBuilder;
begin
  FProgress := AProgress;
  Result := Self;
end;

function TCompressionBuilder.Compress(const AData: TBytes): TBytes;
begin
  case FFormat of
    cfDeflate:
      Result := TCompression.DeflateCompress(AData, FLevel);
    cfGZip:
      Result := TCompression.GZipCompress(AData, FLevel);
    cfZLib:
      Result := TCompression.ZLibCompress(AData, FLevel);
  else
    Result := TCompression.GZipCompress(AData, FLevel);
  end;
end;

function TCompressionBuilder.Decompress(const AData: TBytes): TBytes;
begin
  case FFormat of
    cfDeflate:
      Result := TCompression.DeflateDecompress(AData);
    cfGZip:
      Result := TCompression.GZipDecompress(AData);
    cfZLib:
      Result := TCompression.ZLibDecompress(AData);
  else
    Result := TCompression.GZipDecompress(AData);
  end;
end;

function TCompressionBuilder.CompressStream(ASource, ADest: TStream): TCompressionBuilder;
var
  LCompressor: TDeflateCompressor;
begin
  LCompressor := TDeflateCompressor.Create(FFormat);
  try
    LCompressor.CompressionLevel := FLevel;
    LCompressor.CompressStream(ASource, ADest, FProgress);
  finally
    LCompressor.Free;
  end;
  Result := Self;
end;

function TCompressionBuilder.DecompressStream(ASource, ADest: TStream): TCompressionBuilder;
var
  LCompressor: TDeflateCompressor;
begin
  LCompressor := TDeflateCompressor.Create(FFormat);
  try
    LCompressor.DecompressStream(ASource, ADest, FProgress);
  finally
    LCompressor.Free;
  end;
  Result := Self;
end;

function TCompressionBuilder.CompressFile(const ASource, ADest: string): TCompressionStats;
var
  LCompressor: TGZipCompressor;
begin
  LCompressor := TGZipCompressor.Create;
  try
    LCompressor.CompressionLevel := FLevel;
    Result := LCompressor.CompressFile(ASource, ADest, FProgress);
  finally
    LCompressor.Free;
  end;
end;

function TCompressionBuilder.DecompressFile(const ASource, ADest: string): TCompressionStats;
var
  LCompressor: TGZipCompressor;
begin
  LCompressor := TGZipCompressor.Create;
  try
    Result := LCompressor.DecompressFile(ASource, ADest, FProgress);
  finally
    LCompressor.Free;
  end;
end;

end.
