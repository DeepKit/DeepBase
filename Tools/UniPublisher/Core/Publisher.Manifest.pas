{ ============================================================================
  Publisher.Manifest - Version Manifest Generator
  
  Version: 1.0
  Description:
    Generates version.json manifest files for UniBase auto-update system.
    
    Supports two formats:
    1. New Standard Format (UniPublisher-Spec.md compliant):
       {
         "appId": "com.goodmem.app",
         "version": "1.2.0",
         "channel": "stable",
         "publishedAt": "2025-12-11T08:00:00Z",
         "files": [{ "name": "...", "url": "...", "size": ..., "sha256": "..." }],
         "releaseNotes": "...",
         "mandatory": false,
         "minVersion": "1.0.0",
         "metadata": {}
       }
    
    2. Legacy Format (for backward compatibility):
       {
         "stable": { "version": "...", "downloadUrl": "...", "sha256": "...", ... },
         "beta": { ... },
         "dev": { ... },
         "meta": { "lastUpdated": "...", "checkIntervalHours": 24 }
       }
  ============================================================================ }

unit Publisher.Manifest;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.DateUtils,
  System.Hash,
  System.Generics.Collections;

type
  /// <summary>File entry in the version manifest.</summary>
  TManifestFile = record
    Name: string;           // File name (e.g. 'MyApp-1.2.0-Win32.zip')
    Url: string;            // Download URL
    Size: Int64;            // File size in bytes
    Sha256: string;         // SHA-256 hash (lowercase hex)
    Platform: string;       // Optional: 'Win32', 'Win64', 'macOS', etc.
    
    function ToJSON: TJSONObject;
    procedure FromJSON(AObj: TJSONObject);
  end;

  /// <summary>Metadata section of the manifest.</summary>
  TManifestMetadata = record
    Author: string;
    Website: string;
    ChangelogUrl: string;
    
    function ToJSON: TJSONObject;
    procedure FromJSON(AObj: TJSONObject);
  end;

  /// <summary>
  /// Version manifest model following the new standard format.
  /// </summary>
  TVersionManifest = record
    AppId: string;              // Application unique identifier
    Version: string;            // Semantic version (e.g. '1.2.0')
    Channel: string;            // 'stable', 'beta', 'dev'
    PublishedAt: TDateTime;     // Publication timestamp
    Files: TArray<TManifestFile>;  // Download files
    ReleaseNotes: string;       // Changelog/release notes (Markdown)
    Mandatory: Boolean;         // Force update flag
    MinVersion: string;         // Minimum compatible version
    Metadata: TManifestMetadata;
    
    procedure Clear;
    
    /// <summary>Generate new standard format JSON.</summary>
    function ToJSON: TJSONObject;
    
    /// <summary>Generate new standard format JSON string.</summary>
    function ToJSONString(AIndent: Integer = 2): string;
    
    /// <summary>Parse from new standard format JSON.</summary>
    procedure FromJSON(AObj: TJSONObject);
    
    /// <summary>Save to file in new standard format.</summary>
    function SaveToFile(const APath: string): Boolean;
    
    /// <summary>Load from file (auto-detects format).</summary>
    function LoadFromFile(const APath: string): Boolean;
  end;

  /// <summary>
  /// Helper class for generating and managing version manifests.
  /// </summary>
  TManifestGenerator = class
  public
    /// <summary>
    /// Generate a new standard format manifest.
    /// </summary>
    class function GenerateManifest(
      const AppId, Version, Channel: string;
      const Files: TArray<TManifestFile>;
      const ReleaseNotes: string;
      Mandatory: Boolean = False;
      const MinVersion: string = ''
    ): TVersionManifest; static;
    
    /// <summary>
    /// Generate legacy format JSON for backward compatibility.
    /// This format uses root-level channel objects (stable/beta/dev).
    /// </summary>
    class function GenerateLegacyJSON(
      const Channel, Version, DownloadUrl: string;
      FileSize: Int64;
      const Sha256, ReleaseNotes: string;
      Mandatory: Boolean = False;
      const MinOsVersion: string = '10.0'
    ): TJSONObject; static;
    
    /// <summary>
    /// Generate legacy format JSON string.
    /// </summary>
    class function GenerateLegacyJSONString(
      const Channel, Version, DownloadUrl: string;
      FileSize: Int64;
      const Sha256, ReleaseNotes: string;
      Mandatory: Boolean = False;
      const MinOsVersion: string = '10.0';
      AIndent: Integer = 2
    ): string; static;
    
    /// <summary>
    /// Save legacy format JSON to file.
    /// </summary>
    class function SaveLegacyManifest(
      const APath, Channel, Version, DownloadUrl: string;
      FileSize: Int64;
      const Sha256, ReleaseNotes: string;
      Mandatory: Boolean = False
    ): Boolean; static;
    
    /// <summary>
    /// Compute SHA-256 hash of a file.
    /// </summary>
    class function ComputeFileSha256(const AFilePath: string): string; static;
    
    /// <summary>
    /// Get file size in bytes.
    /// </summary>
    class function GetFileSize(const AFilePath: string): Int64; static;
    
    /// <summary>
    /// Create a TManifestFile from a local file path.
    /// </summary>
    class function CreateFileEntry(
      const AFilePath, ADownloadUrl: string;
      const APlatform: string = ''
    ): TManifestFile; static;
    
    /// <summary>
    /// Detect if a JSON string is new format or legacy format.
    /// Returns True if new format, False if legacy.
    /// </summary>
    class function IsNewFormat(const AJson: string): Boolean; overload; static;
    class function IsNewFormat(ARoot: TJSONObject): Boolean; overload; static;
  end;

implementation

{ TManifestFile }

function TManifestFile.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  Result.AddPair('url', Url);
  Result.AddPair('size', TJSONNumber.Create(Size));
  Result.AddPair('sha256', Sha256);
  if Platform <> '' then
    Result.AddPair('platform', Platform);
end;

procedure TManifestFile.FromJSON(AObj: TJSONObject);
begin
  Name := '';
  Url := '';
  Size := 0;
  Sha256 := '';
  Platform := '';
  
  if AObj = nil then Exit;
  
  Name := AObj.GetValue<string>('name', '');
  Url := AObj.GetValue<string>('url', '');
  Size := AObj.GetValue<Int64>('size', 0);
  Sha256 := AObj.GetValue<string>('sha256', '');
  Platform := AObj.GetValue<string>('platform', '');
end;

{ TManifestMetadata }

function TManifestMetadata.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  if Author <> '' then
    Result.AddPair('author', Author);
  if Website <> '' then
    Result.AddPair('website', Website);
  if ChangelogUrl <> '' then
    Result.AddPair('changelogUrl', ChangelogUrl);
end;

procedure TManifestMetadata.FromJSON(AObj: TJSONObject);
begin
  Author := '';
  Website := '';
  ChangelogUrl := '';
  
  if AObj = nil then Exit;
  
  Author := AObj.GetValue<string>('author', '');
  Website := AObj.GetValue<string>('website', '');
  ChangelogUrl := AObj.GetValue<string>('changelogUrl', '');
end;

{ TVersionManifest }

procedure TVersionManifest.Clear;
begin
  AppId := '';
  Version := '';
  Channel := 'stable';
  PublishedAt := Now;
  SetLength(Files, 0);
  ReleaseNotes := '';
  Mandatory := False;
  MinVersion := '';
  Metadata.Author := '';
  Metadata.Website := '';
  Metadata.ChangelogUrl := '';
end;

function TVersionManifest.ToJSON: TJSONObject;
var
  FilesArr: TJSONArray;
  F: TManifestFile;
begin
  Result := TJSONObject.Create;
  Result.AddPair('appId', AppId);
  Result.AddPair('version', Version);
  Result.AddPair('channel', Channel);
  Result.AddPair('publishedAt', DateToISO8601(PublishedAt, False));
  
  FilesArr := TJSONArray.Create;
  for F in Files do
    FilesArr.AddElement(F.ToJSON);
  Result.AddPair('files', FilesArr);
  
  Result.AddPair('releaseNotes', ReleaseNotes);
  Result.AddPair('mandatory', TJSONBool.Create(Mandatory));
  
  if MinVersion <> '' then
    Result.AddPair('minVersion', MinVersion);
    
  if (Metadata.Author <> '') or (Metadata.Website <> '') or (Metadata.ChangelogUrl <> '') then
    Result.AddPair('metadata', Metadata.ToJSON);
end;

function TVersionManifest.ToJSONString(AIndent: Integer): string;
var
  Root: TJSONObject;
begin
  Root := ToJSON;
  try
    Result := Root.Format(AIndent);
  finally
    Root.Free;
  end;
end;

procedure TVersionManifest.FromJSON(AObj: TJSONObject);
var
  FilesArr: TJSONArray;
  I: Integer;
  DateStr: string;
begin
  Clear;
  if AObj = nil then Exit;
  
  AppId := AObj.GetValue<string>('appId', '');
  Version := AObj.GetValue<string>('version', '');
  Channel := AObj.GetValue<string>('channel', 'stable');
  
  DateStr := AObj.GetValue<string>('publishedAt', '');
  if DateStr <> '' then
  try
    PublishedAt := ISO8601ToDate(DateStr, False);
  except
    PublishedAt := Now;
  end
  else
    PublishedAt := Now;
  
  FilesArr := AObj.GetValue<TJSONArray>('files', nil);
  if FilesArr <> nil then
  begin
    SetLength(Files, FilesArr.Count);
    for I := 0 to FilesArr.Count - 1 do
      Files[I].FromJSON(FilesArr.Items[I] as TJSONObject);
  end;
  
  ReleaseNotes := AObj.GetValue<string>('releaseNotes', '');
  Mandatory := AObj.GetValue<Boolean>('mandatory', False);
  MinVersion := AObj.GetValue<string>('minVersion', '');
  
  Metadata.FromJSON(AObj.GetValue<TJSONObject>('metadata', nil));
end;

function TVersionManifest.SaveToFile(const APath: string): Boolean;
var
  Content: string;
begin
  Result := False;
  try
    Content := ToJSONString;
    ForceDirectories(ExtractFilePath(APath));
    TFile.WriteAllText(APath, Content, TEncoding.UTF8);
    Result := True;
  except
    Result := False;
  end;
end;

function TVersionManifest.LoadFromFile(const APath: string): Boolean;
var
  Content: string;
  Root: TJSONObject;
begin
  Result := False;
  if not TFile.Exists(APath) then
    Exit;
    
  try
    Content := TFile.ReadAllText(APath, TEncoding.UTF8);
    Root := TJSONObject.ParseJSONValue(Content) as TJSONObject;
    if Root = nil then
      Exit;
      
    try
      FromJSON(Root);
      Result := True;
    finally
      Root.Free;
    end;
  except
    Result := False;
  end;
end;

{ TManifestGenerator }

class function TManifestGenerator.GenerateManifest(
  const AppId, Version, Channel: string;
  const Files: TArray<TManifestFile>;
  const ReleaseNotes: string;
  Mandatory: Boolean;
  const MinVersion: string
): TVersionManifest;
begin
  Result.Clear;
  Result.AppId := AppId;
  Result.Version := Version;
  Result.Channel := Channel;
  Result.PublishedAt := Now;
  Result.Files := Files;
  Result.ReleaseNotes := ReleaseNotes;
  Result.Mandatory := Mandatory;
  Result.MinVersion := MinVersion;
end;

class function TManifestGenerator.GenerateLegacyJSON(
  const Channel, Version, DownloadUrl: string;
  FileSize: Int64;
  const Sha256, ReleaseNotes: string;
  Mandatory: Boolean;
  const MinOsVersion: string
): TJSONObject;
var
  ChanObj, MetaObj: TJSONObject;
  ChanKey: string;
begin
  Result := TJSONObject.Create;
  
  ChanKey := LowerCase(Channel);
  if (ChanKey <> 'stable') and (ChanKey <> 'beta') and (ChanKey <> 'dev') then
    ChanKey := 'stable';
  
  // Initialize all three channels with empty objects
  Result.AddPair('stable', TJSONObject.Create);
  Result.AddPair('beta', TJSONObject.Create);
  Result.AddPair('dev', TJSONObject.Create);
  
  // Fill the target channel
  ChanObj := Result.GetValue<TJSONObject>(ChanKey);
  ChanObj.AddPair('version', Version);
  ChanObj.AddPair('versionCode', TJSONNumber.Create(0));
  ChanObj.AddPair('downloadUrl', DownloadUrl);
  ChanObj.AddPair('fileSize', TJSONNumber.Create(FileSize));
  ChanObj.AddPair('sha256', Sha256);
  ChanObj.AddPair('releaseNotes', ReleaseNotes);
  ChanObj.AddPair('releaseDate', DateToISO8601(Now, False));
  ChanObj.AddPair('isMandatory', TJSONBool.Create(Mandatory));
  ChanObj.AddPair('minOsVersion', MinOsVersion);
  
  // Meta section
  MetaObj := TJSONObject.Create;
  MetaObj.AddPair('lastUpdated', DateToISO8601(Now, False));
  MetaObj.AddPair('checkIntervalHours', TJSONNumber.Create(24));
  Result.AddPair('meta', MetaObj);
end;

class function TManifestGenerator.GenerateLegacyJSONString(
  const Channel, Version, DownloadUrl: string;
  FileSize: Int64;
  const Sha256, ReleaseNotes: string;
  Mandatory: Boolean;
  const MinOsVersion: string;
  AIndent: Integer
): string;
var
  Root: TJSONObject;
begin
  Root := GenerateLegacyJSON(Channel, Version, DownloadUrl, FileSize,
    Sha256, ReleaseNotes, Mandatory, MinOsVersion);
  try
    Result := Root.Format(AIndent);
  finally
    Root.Free;
  end;
end;

class function TManifestGenerator.SaveLegacyManifest(
  const APath, Channel, Version, DownloadUrl: string;
  FileSize: Int64;
  const Sha256, ReleaseNotes: string;
  Mandatory: Boolean
): Boolean;
var
  Content: string;
begin
  Result := False;
  try
    Content := GenerateLegacyJSONString(Channel, Version, DownloadUrl,
      FileSize, Sha256, ReleaseNotes, Mandatory);
    ForceDirectories(ExtractFilePath(APath));
    TFile.WriteAllText(APath, Content, TEncoding.UTF8);
    Result := True;
  except
    Result := False;
  end;
end;

class function TManifestGenerator.ComputeFileSha256(const AFilePath: string): string;
var
  FS: TFileStream;
begin
  Result := '';
  if not TFile.Exists(AFilePath) then
    Exit;
    
  FS := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
  try
    Result := LowerCase(THashSHA2.GetHashString(FS, THashSHA2.TSHA2Version.SHA256));
  finally
    FS.Free;
  end;
end;

class function TManifestGenerator.GetFileSize(const AFilePath: string): Int64;
begin
  if TFile.Exists(AFilePath) then
    Result := TFile.GetSize(AFilePath)
  else
    Result := 0;
end;

class function TManifestGenerator.CreateFileEntry(
  const AFilePath, ADownloadUrl, APlatform: string
): TManifestFile;
begin
  Result.Name := ExtractFileName(AFilePath);
  Result.Url := ADownloadUrl;
  Result.Size := GetFileSize(AFilePath);
  Result.Sha256 := ComputeFileSha256(AFilePath);
  Result.Platform := APlatform;
end;

class function TManifestGenerator.IsNewFormat(const AJson: string): Boolean;
var
  Root: TJSONObject;
begin
  Result := False;
  Root := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Root = nil then
    Exit;
    
  try
    Result := IsNewFormat(Root);
  finally
    Root.Free;
  end;
end;

class function TManifestGenerator.IsNewFormat(ARoot: TJSONObject): Boolean;
begin
  // New format has 'appId' and 'files' at root level
  // Legacy format has 'stable', 'beta', 'dev' at root level
  Result := (ARoot.GetValue('appId') <> nil) or (ARoot.GetValue('files') <> nil);
end;

end.
