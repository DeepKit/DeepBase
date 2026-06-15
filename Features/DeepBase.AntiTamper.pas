unit DeepBase.AntiTamper;

{$IFDEF RELEASE}
  {$DEFINE NO_DEBUG_LOG}
{$ENDIF}

interface

uses
  System.SysUtils, System.Classes, System.Hash, System.NetEncoding, System.StrUtils, System.Math,
  System.RegularExpressions,
  Winapi.ShellAPI, Winapi.Windows,
  System.Generics.Collections, DeepBase.Crypto, DeepBase.Exceptions,
  DeepBase.Storage.Interfaces;

// 加密算法类型
// BUG-033 FIX: Removed weak XOR encryption, only AES256 is supported
 type
  TEncryptionType = (etAES256);  // etXOR removed for security

  TAntiTamperImageStorageFactory = reference to function(
    const ADatabasePath: string): IAntiTamperImageStorage;

  // 安全配置
  TAntiTamperConfig = record
    EncryptionKey: string;        // 加密密钥
    DownloadURL: string;          // 官网下载地址
    TableName: string;            // 数据库表�?
    EnableLogging: Boolean;       // 是否启用日志
    LogFileName: string;          // 日志文件�?
    EncryptionType: TEncryptionType; // 加密算法类型
    // KDF �?HMAC 设置
    Salt: string;                 // KDF�?
    KdfIterations: Integer;       // KDF迭代次数
    EnableHMAC: Boolean;          // 是否启用HMAC完整性签�?
  end;

  // 防篡改包主类
  TAntiTamperPackage = class
  private
    class var FConfig: TAntiTamperConfig;
    class var FInitialized: Boolean;
    class var FStorageFactory: TAntiTamperImageStorageFactory;

    class procedure WriteLog(const AMessage: string); static;
    class function DeriveKeyBytes: TBytes; static;
    class function GetEffectiveKeyString: string; static;
    class function ComputeHMACSHA256(const Data: TBytes): string; static;
    class function GetTableName: string; static;
    class function GetStorage(const ADatabasePath: string): IAntiTamperImageStorage; static;
    // BUG-036 FIX: Constant-time string comparison to prevent timing attacks
    class function ConstantTimeCompare(const A, B: string): Boolean; static;
  public
    // 初始化配�?
    class procedure Initialize(const AConfig: TAntiTamperConfig); static;

    // 数据库表结构管理
    class procedure SetImageStorageFactory(
      const AFactory: TAntiTamperImageStorageFactory); static;
    class function SetupDatabase(const ADatabasePath: string): Boolean; static;
    class function UpgradeDatabase(const ADatabasePath: string): Boolean; static;
    class procedure ClearTable(const ADatabasePath: string); static;
    class procedure ReseedMinimal(const ADatabasePath: string); static;

    // 哈希计算
    class function CalculateMD5(const Data: TBytes): string; static; deprecated 'Use CalculateSHA256 instead';
    class function CalculateSHA256(const Data: TBytes): string; static;

    // 加密解密
    class function EncryptImageData(const ImageData: TBytes): TBytes; static;
    class function DecryptImageData(const EncryptedData: TBytes): TBytes; static;

    // 完整性校�?
    class function VerifyImageIntegrity(const DecryptedData: TBytes; const ExpectedHash: string): Boolean; static;

    // 安全图像操作
    class function SaveSecureImage(const ADatabasePath, AImageKey: string;
      const AImageData: TBytes; const AAddressText: string = ''; const ADescription: string = ''): Boolean; static;

    class function LoadSecureImageBytesFromDatabase(const ADatabasePath,
      AImageKey: string; out ADecryptedImageData: TBytes;
      out AAddressText: string): Boolean; static;
    class function IsSecureImageEnabled(const ADatabasePath,
      AImageKey: string): Boolean; static;

    // 安全响应
    class procedure HandleSecurityViolation(const ImageKey: string; const Reason: string); static;

    // 工具方法
    class function GetDefaultConfig: TAntiTamperConfig; static;
  end;

implementation

{ 默认配置 }
class function TAntiTamperPackage.GetDefaultConfig: TAntiTamperConfig;
begin
  // BUG-034 FIX: Remove hardcoded key, require explicit configuration
  // Users MUST set their own encryption key before using AntiTamper features
  Result.EncryptionKey := ''; // Empty - must be configured by user
  Result.DownloadURL := 'https://your-website.com/download';
  Result.TableName := 'aboutMeImages';
  Result.EnableLogging := True;
  Result.LogFileName := 'antitamper_debug.log';
  Result.EncryptionType := etAES256;
  Result.Salt := 'DeepMoveC_Default_Salt_2025';
  Result.KdfIterations := 5000;
  Result.EnableHMAC := True;
end;

class procedure TAntiTamperPackage.Initialize(const AConfig: TAntiTamperConfig);
begin
  FConfig := AConfig;
  FInitialized := True;
  WriteLog('AntiTamper package initialized');
end;


class procedure TAntiTamperPackage.SetImageStorageFactory(
  const AFactory: TAntiTamperImageStorageFactory);
begin
  FStorageFactory := AFactory;
end;

class function TAntiTamperPackage.GetStorage(
  const ADatabasePath: string): IAntiTamperImageStorage;
begin
  if ADatabasePath.Trim = '' then
    raise EAntiTamperException.Create('AntiTamper database path is empty');

  if not Assigned(FStorageFactory) then
    raise EAntiTamperException.Create(
      'AntiTamper image storage factory is not registered. Include the DeepBase persistence protection adapter.');

  Result := FStorageFactory(ADatabasePath);
  if Result = nil then
    raise EAntiTamperException.Create('AntiTamper image storage factory returned nil');
end;
class procedure TAntiTamperPackage.WriteLog(const AMessage: string);
{$IFNDEF NO_DEBUG_LOG}
var
  LogFile: TextFile;
{$ENDIF}
begin
  {$IFNDEF NO_DEBUG_LOG}
  if not FInitialized or not FConfig.EnableLogging then
    Exit;
  try
    AssignFile(LogFile, FConfig.LogFileName);
    if FileExists(FConfig.LogFileName) then
      Append(LogFile)
    else
      Rewrite(LogFile);
    WriteLn(LogFile, Format('[%s] %s', [DateTimeToStr(Now), AMessage]));
    CloseFile(LogFile);
  except
  end;
  {$ENDIF}
end;

class function TAntiTamperPackage.CalculateMD5(const Data: TBytes): string;
var
  Hash: THashMD5;
begin
  // THashMD5 is a record (no .Free needed)
  Hash := THashMD5.Create;
  Hash.Update(Data);
  Result := Hash.HashAsString;
end;

class function TAntiTamperPackage.CalculateSHA256(const Data: TBytes): string;
var
  Hash: THashSHA2;
begin
  // THashSHA2 is a record (no .Free needed)
  Hash := THashSHA2.Create;
  Hash.Update(Data);
  Result := Hash.HashAsString;
end;

class function TAntiTamperPackage.DeriveKeyBytes: TBytes;
var
  Iterations: Integer;
begin
  Iterations := Max(FConfig.KdfIterations, 10000); // 最�?0000次迭�?
  Result := TPasswordUtils.PBKDF2(FConfig.EncryptionKey,
    TEncoding.UTF8.GetBytes(FConfig.Salt), Iterations, 32, haSHA256);
end;

class function TAntiTamperPackage.GetEffectiveKeyString: string;
  function BytesToHex(const B: TBytes): string;
  const
    HexChars: PChar = '0123456789ABCDEF';
  var
    I: Integer;
    S: TCharArray;
  begin
    SetLength(S, Length(B) * 2);
    for I := 0 to High(B) do
    begin
      S[I*2]   := HexChars[(B[I] shr 4) and $F];
      S[I*2+1] := HexChars[B[I] and $F];
    end;
    Result := string.Create(S);
  end;
begin
  Result := BytesToHex(DeriveKeyBytes);
end;

class function TAntiTamperPackage.ComputeHMACSHA256(const Data: TBytes): string;
var
  DataDigest, KeyHex: string;
begin
  DataDigest := THash.DigestAsString(Data);
  KeyHex := GetEffectiveKeyString;
  Result := THashSHA2.GetHMAC(DataDigest, KeyHex);
end;

class function TAntiTamperPackage.GetTableName: string;
begin
  Result := FConfig.TableName;
  if Result = '' then
    Result := 'aboutMeImages';

  if not TRegEx.IsMatch(Result, '^[a-zA-Z_][a-zA-Z0-9_]*$') then
    raise EAntiTamperException.CreateFmt('Invalid table name: %s', [Result]);
end;

// BUG-036 FIX: Constant-time string comparison to prevent timing attacks
class function TAntiTamperPackage.ConstantTimeCompare(const A, B: string): Boolean;
var
  I, Diff: Integer;
begin
  if Length(A) <> Length(B) then
    Exit(False);
  
  Diff := 0;
  for I := 1 to Length(A) do
    Diff := Diff or (Ord(UpCase(A[I])) xor Ord(UpCase(B[I])));
  
  Result := Diff = 0;
end;

class function TAntiTamperPackage.EncryptImageData(const ImageData: TBytes): TBytes;
var
  AES: TAESCrypto;
  KeyBytes, Cipher, IV: TBytes;
begin
  if not FInitialized then
    raise EAntiTamperException.Create('AntiTamper package not initialized');

  if FConfig.EncryptionKey = '' then
    raise EMissingConfigurationException.Create('EncryptionKey not configured');

  KeyBytes := DeriveKeyBytes;
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKey(KeyBytes);
    AES.GenerateIV;
    Cipher := AES.Encrypt(ImageData);
    IV := AES.IV;

    // Wire format: IV (16 bytes) || Ciphertext
    SetLength(Result, Length(IV) + Length(Cipher));
    Move(IV[0], Result[0], Length(IV));
    Move(Cipher[0], Result[Length(IV)], Length(Cipher));
  finally
    AES.Free;
  end;
  WriteLog(Format(string('使用AES-256加密，数据长�? %d bytes'), [Length(Result)]));
end;

class function TAntiTamperPackage.DecryptImageData(const EncryptedData: TBytes): TBytes;
const
  AES_BLOCK_SIZE = 16;
var
  AES: TAESCrypto;
  KeyBytes, IV, Cipher: TBytes;
begin
  if not FInitialized then
    raise EAntiTamperException.Create('AntiTamper package not initialized');

  if FConfig.EncryptionKey = '' then
    raise EMissingConfigurationException.Create('EncryptionKey not configured');

  if Length(EncryptedData) < AES_BLOCK_SIZE then
    raise EDecryptionException.Create('Invalid encrypted data (too short)');

  KeyBytes := DeriveKeyBytes;

  // Wire format: IV (16 bytes) || Ciphertext
  SetLength(IV, AES_BLOCK_SIZE);
  Move(EncryptedData[0], IV[0], AES_BLOCK_SIZE);

  SetLength(Cipher, Length(EncryptedData) - AES_BLOCK_SIZE);
  if Length(Cipher) > 0 then
    Move(EncryptedData[AES_BLOCK_SIZE], Cipher[0], Length(Cipher));

  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKey(KeyBytes);
    AES.SetIV(IV);
    Result := AES.Decrypt(Cipher);
  finally
    AES.Free;
  end;
  WriteLog(Format(string('使用AES-256解密，数据长�? %d bytes'), [Length(Result)]));
end;

class function TAntiTamperPackage.VerifyImageIntegrity(const DecryptedData: TBytes; const ExpectedHash: string): Boolean;
var
  ActualHash: string;
  I, Diff: Integer;
begin
  ActualHash := CalculateSHA256(DecryptedData);
  
  // BUG-036 FIX: Use constant-time comparison to prevent timing attacks
  if Length(ActualHash) <> Length(ExpectedHash) then
  begin
    WriteLog(Format(string('SHA-256校验失败: 长度不匹�?期望=%d, 实际=%d'), [Length(ExpectedHash), Length(ActualHash)]));
    Exit(False);
  end;
  
  Diff := 0;
  for I := 1 to Length(ActualHash) do
    Diff := Diff or (Ord(UpCase(ActualHash[I])) xor Ord(UpCase(ExpectedHash[I])));
  
  Result := Diff = 0;
  if not Result then
    WriteLog(Format(string('SHA-256校验失败: 期望=%s, 实际=%s'), [ExpectedHash, ActualHash]));
end;

class function TAntiTamperPackage.SetupDatabase(const ADatabasePath: string): Boolean;
begin
  try
    Result := GetStorage(ADatabasePath).SetupDatabase(GetTableName);
    if Result then
      WriteLog('防篡改数据表创建/检查成功')
    else
      WriteLog('防篡改数据表创建/检查失败');
  except
    on E: Exception do
    begin
      WriteLog('设置防篡改数据表失败: ' + E.Message);
      Result := False;
    end;
  end;
end;

class function TAntiTamperPackage.UpgradeDatabase(const ADatabasePath: string): Boolean;
begin
  try
    Result := GetStorage(ADatabasePath).UpgradeDatabase(GetTableName);
  except
    on E: Exception do
    begin
      WriteLog('升级数据库失败: ' + E.Message);
      Result := False;
    end;
  end;
end;
class function TAntiTamperPackage.SaveSecureImage(const ADatabasePath,
  AImageKey: string; const AImageData: TBytes; const AAddressText,
  ADescription: string): Boolean;
var
  EncryptedData: TBytes;
  Sha256Hex: string;
  Data: TAntiTamperImageData;
begin
  Result := False;
  try
    if Length(AImageData) = 0 then
    begin
      WriteLog('图像数据为空: ' + AImageKey);
      Exit;
    end;

    Sha256Hex := CalculateSHA256(AImageData);
    WriteLog(Format('图像 %s 的SHA-256: %s', [AImageKey, Sha256Hex]));

    EncryptedData := EncryptImageData(AImageData);

    Data.ImageKey := AImageKey;
    Data.EncryptedImageData := EncryptedData;
    Data.AddressText := AAddressText;
    Data.Description := ADescription;
    Data.Sha256Hash := Sha256Hex;
    Data.HmacSha256 := ComputeHMACSHA256(AImageData);
    Data.IsEnabled := True;

    GetStorage(ADatabasePath).SaveSecureImage(GetTableName, Data);

    WriteLog(Format('安全图像保存成功: %s', [AImageKey]));
    Result := True;
  except
    on E: Exception do
    begin
      WriteLog(Format('保存安全图像失败: %s - %s', [AImageKey, E.Message]));
      Result := False;
    end;
  end;
end;
class function TAntiTamperPackage.LoadSecureImageBytesFromDatabase(
  const ADatabasePath, AImageKey: string; out ADecryptedImageData: TBytes;
  out AAddressText: string): Boolean;
var
  StoredData: TAntiTamperImageData;
  DecryptedData: TBytes;
  ExpectedHMAC: string;
begin
  Result := False;
  AAddressText := '';
  SetLength(ADecryptedImageData, 0);

  try
    if not GetStorage(ADatabasePath).TryLoadSecureImage(GetTableName,
      AImageKey, StoredData) then
    begin
      WriteLog('Database record not found: ' + AImageKey);
      Exit;
    end;

    if not StoredData.IsEnabled then
    begin
      WriteLog('记录已禁用(enabled=0): ' + AImageKey);
      Exit;
    end;

    DecryptedData := DecryptImageData(StoredData.EncryptedImageData);

    if StoredData.Sha256Hash = '' then
    begin
      HandleSecurityViolation(AImageKey, 'sha256_hash is missing or null');
      Exit;
    end;

    if not VerifyImageIntegrity(DecryptedData, StoredData.Sha256Hash) then
    begin
      HandleSecurityViolation(AImageKey, 'SHA-256校验失败，图像数据可能被篡改');
      Exit;
    end;

    if StoredData.HmacSha256 = '' then
    begin
      HandleSecurityViolation(AImageKey, 'hmac_sha256 is missing or null');
      Exit;
    end;

    if FConfig.EnableHMAC then
    begin
      ExpectedHMAC := ComputeHMACSHA256(DecryptedData);
      if not ConstantTimeCompare(StoredData.HmacSha256, ExpectedHMAC) then
      begin
        HandleSecurityViolation(AImageKey, 'HMAC-SHA256校验失败，图像数据可能被篡改');
        Exit;
      end;
    end;

    AAddressText := StoredData.AddressText;
    ADecryptedImageData := DecryptedData;
    Result := True;
  except
    on E: Exception do
    begin
      WriteLog(Format('Failed to load secure image from database: %s - %s',
        [AImageKey, E.Message]));
      Result := False;
    end;
  end;
end;

class function TAntiTamperPackage.IsSecureImageEnabled(
  const ADatabasePath, AImageKey: string): Boolean;
begin
  Result := True;
  try
    Result := GetStorage(ADatabasePath).IsSecureImageEnabled(GetTableName,
      AImageKey);
  except
    on E: Exception do
    begin
      WriteLog(Format('Failed to read secure image enabled flag: %s - %s',
        [AImageKey, E.Message]));
      Result := True;
    end;
  end;
end;
class procedure TAntiTamperPackage.HandleSecurityViolation(const ImageKey, Reason: string);
var
  ErrorMsg: string;
  Response: Integer;
begin
  WriteLog(Format('安全违规: %s - %s', [ImageKey, Reason]));

  // Force the log message to disk before showing UI
  if FInitialized and FConfig.EnableLogging then
    WriteLog('Preparing security violation dialog');

  ErrorMsg := Format('Security check failed.'#13#10#13#10 +
    'Image: %s'#13#10 +
    'Reason: %s'#13#10#13#10 +
    'The program files may have been tampered with. The application will exit.'#13#10 +
    'Please download the latest version from the official website.'#13#10#13#10 +
    'Open the official download page now?', [ImageKey, Reason]);

  Response := MessageBox(0, PChar(ErrorMsg), '安全警告', MB_YESNO or MB_ICONERROR or MB_TOPMOST);

  if Response = IDYES then
    ShellExecute(0, 'open', PChar(FConfig.DownloadURL), nil, nil, SW_SHOWNORMAL);

  WriteLog('Program exited because of security violation');

  // Use Halt(1) instead of ExitProcess(1) to allow proper finalization:
  // - Unit finalization sections run (logs flushed, DB connections closed)
  // - Exit procedures execute
  // - File buffers are flushed to disk
  Halt(1);
end;

class procedure TAntiTamperPackage.ClearTable(const ADatabasePath: string);
begin
  try
    GetStorage(ADatabasePath).ClearTable(GetTableName);
    WriteLog('Anti-tamper data table cleared');
  except
    on E: Exception do
      WriteLog('Failed to clear anti-tamper data table: ' + E.Message);
  end;
end;

class procedure TAntiTamperPackage.ReseedMinimal(const ADatabasePath: string);
var
  EmptyData: TBytes;
  Data: TAntiTamperImageData;
begin
  SetLength(EmptyData, 0);
  Data.ImageKey := 'seed';
  Data.EncryptedImageData := EmptyData;
  Data.AddressText := '';
  Data.Description := 'minimal seed';
  Data.Sha256Hash := CalculateSHA256(EmptyData);
  Data.HmacSha256 := ComputeHMACSHA256(EmptyData);
  Data.IsEnabled := True;

  try
    GetStorage(ADatabasePath).ReseedMinimal(GetTableName, Data);
    WriteLog('Seeded minimal valid record: seed');
  except
    on E: Exception do
      WriteLog('Failed to seed minimal anti-tamper record: ' + E.Message);
  end;
end;
end.
