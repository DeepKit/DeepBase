unit UniBase.AntiTamper;

{$IFDEF RELEASE}
  {$DEFINE NO_DEBUG_LOG}
{$ENDIF}

interface

uses
  System.SysUtils, System.Classes, System.Hash, System.NetEncoding, System.StrUtils, System.Math,
  System.RegularExpressions,
  Winapi.ShellAPI, Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Stan.Param, Data.DB,
  System.Generics.Collections, UniBase.Crypto, UniBase.Exceptions;

// 加密算法类型
// BUG-033 FIX: Removed weak XOR encryption, only AES256 is supported
 type
  TEncryptionType = (etAES256);  // etXOR removed for security

  // 安全配置
  TAntiTamperConfig = record
    EncryptionKey: string;        // 加密密钥
    DownloadURL: string;          // 官网下载地址
    TableName: string;            // 数据库表名
    EnableLogging: Boolean;       // 是否启用日志
    LogFileName: string;          // 日志文件名
    EncryptionType: TEncryptionType; // 加密算法类型
    // KDF 与 HMAC 设置
    Salt: string;                 // KDF盐
    KdfIterations: Integer;       // KDF迭代次数
    EnableHMAC: Boolean;          // 是否启用HMAC完整性签名
  end;

  // 防篡改包主类
  TAntiTamperPackage = class
  private
    class var FConfig: TAntiTamperConfig;
    class var FInitialized: Boolean;

    class procedure WriteLog(const AMessage: string); static;
    class function DeriveKeyBytes: TBytes; static;
    class function GetEffectiveKeyString: string; static;
    class function ComputeHMACSHA256(const Data: TBytes): string; static;
    // BUG-036 FIX: Constant-time string comparison to prevent timing attacks
    class function ConstantTimeCompare(const A, B: string): Boolean; static;
  public
    // 初始化配置
    class procedure Initialize(const AConfig: TAntiTamperConfig); static;

    // 数据库表结构管理
    class function SetupDatabase(AConnection: TFDConnection): Boolean; static;
    class function UpgradeDatabase(AConnection: TFDConnection): Boolean; static;
    class procedure ClearTable(AConnection: TFDConnection); static;
    class procedure ReseedMinimal(AConnection: TFDConnection); static;

    // 哈希计算
    class function CalculateMD5(const Data: TBytes): string; static; deprecated 'Use CalculateSHA256 instead';
    class function CalculateSHA256(const Data: TBytes): string; static;

    // 加密解密
    class function EncryptImageData(const ImageData: TBytes): TBytes; static;
    class function DecryptImageData(const EncryptedData: TBytes): TBytes; static;

    // 完整性校验
    class function VerifyImageIntegrity(const DecryptedData: TBytes; const ExpectedHash: string): Boolean; static;

    // 安全图像操作
    class function SaveSecureImage(AConnection: TFDConnection; const AImageKey: string;
      const AImageData: TBytes; const AAddressText: string = ''; const ADescription: string = ''): Boolean; static;

    /// <summary>
    /// 从 aboutMeImages 读取并验证图像数据，返回解密后的原始图像字节。
    /// 注意：此方法不依赖任何 UI 框架（VCL/FMX），由调用方自行加载到控件。
    /// </summary>
    class function LoadSecureImageBytes(ATable: TFDTable; const AImageKey: string;
      out ADecryptedImageData: TBytes; out AAddressText: string): Boolean; static;

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
  Result.Salt := 'MoveC_Default_Salt_2025';
  Result.KdfIterations := 5000;
  Result.EnableHMAC := True;
end;

class procedure TAntiTamperPackage.Initialize(const AConfig: TAntiTamperConfig);
begin
  FConfig := AConfig;
  FInitialized := True;
  WriteLog('防篡改包初始化完成');
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
  Iterations := Max(FConfig.KdfIterations, 10000); // 最少10000次迭代
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
  WriteLog(Format(string('使用AES-256加密，数据长度: %d bytes'), [Length(Result)]));
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
  WriteLog(Format(string('使用AES-256解密，数据长度: %d bytes'), [Length(Result)]));
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
    WriteLog(Format(string('SHA-256校验失败: 长度不匹配 期望=%d, 实际=%d'), [Length(ExpectedHash), Length(ActualHash)]));
    Exit(False);
  end;
  
  Diff := 0;
  for I := 1 to Length(ActualHash) do
    Diff := Diff or (Ord(UpCase(ActualHash[I])) xor Ord(UpCase(ExpectedHash[I])));
  
  Result := Diff = 0;
  if not Result then
    WriteLog(Format(string('SHA-256校验失败: 期望=%s, 实际=%s'), [ExpectedHash, ActualHash]));
end;

class function TAntiTamperPackage.SetupDatabase(AConnection: TFDConnection): Boolean;
var
  Query: TFDQuery;
  TableExists: Boolean;
begin
  Result := False;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := AConnection;
      if not TRegEx.IsMatch(FConfig.TableName, '^[a-zA-Z_][a-zA-Z0-9_]*$') then
        raise EAntiTamperException.CreateFmt('Invalid table name: %s', [FConfig.TableName]);
      Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''table'' AND name=:tname';
      Query.ParamByName('tname').AsString := FConfig.TableName;
      Query.Open;
      TableExists := not Query.IsEmpty;
      Query.Close;

      if not TableExists then
      begin
        Query.SQL.Text :=
          'CREATE TABLE ' + FConfig.TableName + ' (' +
          '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
          '  image_key TEXT NOT NULL UNIQUE,' +
          '  image_data BLOB NOT NULL,' +
          '  address_text TEXT,' +
          '  description TEXT,' +
          '  enabled INTEGER NOT NULL DEFAULT 1,' +
          '  sha256_hash TEXT NOT NULL,' +
          '  hmac_sha256 TEXT NOT NULL,' +
          '  md5_hash TEXT,' +
          '  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
          '  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP' +
          ')';
        Query.ExecSQL;
        WriteLog('防篡改数据表创建成功');
      end
      else
      begin
        WriteLog('防篡改数据表已存在，检查并升级字段');
        if not UpgradeDatabase(AConnection) then
        begin
          WriteLog('升级数据表失败');
          Exit;
        end;
      end;
      Result := True;
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLog('设置防篡改数据表失败: ' + E.Message);
      Result := False;
    end;
  end;
end;

class function TAntiTamperPackage.UpgradeDatabase(AConnection: TFDConnection): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := AConnection;
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN sha256_hash TEXT';
        Query.ExecSQL;
        WriteLog('sha256_hash字段添加成功');
      except
        WriteLog('sha256_hash字段可能已存在');
      end;
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN hmac_sha256 TEXT';
        Query.ExecSQL;
        WriteLog('hmac_sha256字段添加成功');
      except
        WriteLog('hmac_sha256字段可能已存在');
      end;
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1';
        Query.ExecSQL;
        WriteLog('enabled字段添加成功');
      except
        WriteLog('enabled字段可能已存在');
      end;
      // 兼容旧实现：md5_hash 字段（不再使用，但 SaveSecureImage 仍会写入空字符串）
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN md5_hash TEXT';
        Query.ExecSQL;
        WriteLog('md5_hash字段添加成功');
      except
        WriteLog('md5_hash字段可能已存在');
      end;
      Result := True;
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLog('升级数据库失败: ' + E.Message);
      Result := False;
    end;
  end;
end;

class function TAntiTamperPackage.SaveSecureImage(AConnection: TFDConnection; const AImageKey: string;
  const AImageData: TBytes; const AAddressText, ADescription: string): Boolean;
var
  Query: TFDQuery;
  EncryptedData: TBytes;
  Sha256Hex: string;
  RecordExists: Boolean;
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

    Query := TFDQuery.Create(nil);
    try
      Query.Connection := AConnection;
      Query.SQL.Text := 'SELECT COUNT(*) as cnt FROM ' + FConfig.TableName + ' WHERE image_key = :key';
      Query.ParamByName('key').AsString := AImageKey;
      Query.Open;
      RecordExists := Query.FieldByName('cnt').AsInteger > 0;
      Query.Close;

      if RecordExists then
      begin
        Query.SQL.Text :=
          'UPDATE ' + FConfig.TableName + ' SET image_data = :data, address_text = :addr, description = :desc, ' +
          'sha256_hash = :hash, hmac_sha256 = :hmac, md5_hash = :md5, updated_at = CURRENT_TIMESTAMP ' +
          'WHERE image_key = :key';
      end
      else
      begin
        Query.SQL.Text :=
          'INSERT INTO ' + FConfig.TableName + ' (image_key, image_data, address_text, description, sha256_hash, hmac_sha256, md5_hash) ' +
          'VALUES (:key, :data, :addr, :desc, :hash, :hmac, :md5)';
      end;

      var Stream := TBytesStream.Create(EncryptedData);
      try
        Query.ParamByName('key').AsString := AImageKey;
        Query.ParamByName('data').LoadFromStream(Stream, ftBlob);
        Query.ParamByName('addr').AsString := AAddressText;
        Query.ParamByName('desc').AsString := ADescription;
        Query.ParamByName('hash').AsString := Sha256Hex;
      finally
        Stream.Free;
      end;
      Query.ParamByName('hmac').AsString := ComputeHMACSHA256(AImageData);
      Query.ParamByName('md5').AsString := '';
      Query.ExecSQL;

      WriteLog(Format('安全图像保存成功: %s', [AImageKey]));
      Result := True;
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLog(Format('保存安全图像失败: %s - %s', [AImageKey, E.Message]));
      Result := False;
    end;
  end;
end;

class function TAntiTamperPackage.LoadSecureImageBytes(ATable: TFDTable; const AImageKey: string;
  out ADecryptedImageData: TBytes; out AAddressText: string): Boolean;
var
  EncryptedData: TBytes;
  DecryptedData: TBytes;
  ExpectedHash: string;
  MemoryStream: TMemoryStream;
  ImageField: TField;
  AddressField: TField;
  SHAField: TField;
  HMACField: TField;
  EnabledField: TField;
  ExpectedHMAC, ActualHMAC: string;
begin
  Result := False;
  AAddressText := '';
  SetLength(ADecryptedImageData, 0);

  try
    if not ATable.Active then
    begin
      WriteLog('数据表未激活: ' + AImageKey);
      Exit;
    end;

    if ATable.Locate('image_key', AImageKey, []) then
    begin
      WriteLog('在数据库中找到记录: ' + AImageKey);

      EnabledField := ATable.FindField('enabled');
      if (EnabledField <> nil) and (not EnabledField.IsNull) and (EnabledField.AsInteger = 0) then
      begin
        WriteLog('记录已禁用(enabled=0): ' + AImageKey);
        Exit;
      end;

      ImageField := ATable.FieldByName('image_data');
      AddressField := ATable.FieldByName('address_text');
      SHAField := ATable.FieldByName('sha256_hash');
      HMACField := ATable.FindField('hmac_sha256');

      if ImageField.IsNull then
      begin
        WriteLog('图像字段为空: ' + AImageKey);
        Exit;
      end;

      MemoryStream := TMemoryStream.Create;
      try
        TBlobField(ImageField).SaveToStream(MemoryStream);
        MemoryStream.Position := 0;

        SetLength(EncryptedData, MemoryStream.Size);
        if MemoryStream.Size > 0 then
          MemoryStream.ReadBuffer(EncryptedData[0], MemoryStream.Size);

        WriteLog(Format('加密数据长度: %d bytes - %s', [Length(EncryptedData), AImageKey]));

        DecryptedData := DecryptImageData(EncryptedData);
        WriteLog(Format('解密数据长度: %d bytes - %s', [Length(DecryptedData), AImageKey]));

        if (SHAField = nil) or SHAField.IsNull then
        begin
          HandleSecurityViolation(AImageKey, '缺少 sha256_hash 字段或为空');
          Exit;
        end;

        ExpectedHash := SHAField.AsString;
        if not VerifyImageIntegrity(DecryptedData, ExpectedHash) then
        begin
          HandleSecurityViolation(AImageKey, 'SHA-256校验失败，图像数据可能被篡改');
          Exit;
        end;

        if (HMACField = nil) or HMACField.IsNull then
        begin
          HandleSecurityViolation(AImageKey, '缺少 hmac_sha256 字段或为空');
          Exit;
        end;

        if FConfig.EnableHMAC then
        begin
          ExpectedHMAC := HMACField.AsString;
          ActualHMAC := ComputeHMACSHA256(DecryptedData);
          // BUG-036 FIX: Use constant-time comparison to prevent timing attacks
          if not ConstantTimeCompare(ExpectedHMAC, ActualHMAC) then
          begin
            HandleSecurityViolation(AImageKey, 'HMAC-SHA256校验失败，图像数据可能被篡改');
            Exit;
          end;
        end;

        if (AddressField <> nil) and (not AddressField.IsNull) then
          AAddressText := AddressField.AsString;

        ADecryptedImageData := DecryptedData;
        WriteLog(Format('安全图像读取成功: %s, 明文长度: %d bytes', [AImageKey, Length(ADecryptedImageData)]));
        Result := True;
      finally
        MemoryStream.Free;
      end;
    end
    else
      WriteLog('数据库中未找到记录: ' + AImageKey);
  except
    on E: Exception do
    begin
      WriteLog(Format('加载安全图像时出错: %s - %s', [AImageKey, E.Message]));
      Result := False;
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
    WriteLog('准备显示安全违规对话框');

  ErrorMsg := Format('安全检查失败！'#13#10#13#10 +
    '图像: %s'#13#10 +
    '原因: %s'#13#10#13#10 +
    '检测到程序文件可能被篡改，为了您的安全，程序将退出。'#13#10 +
    '请从官方网站下载最新版本。'#13#10#13#10 +
    '是否现在访问官方下载页面？', [ImageKey, Reason]);

  Response := MessageBox(0, PChar(ErrorMsg), '安全警告', MB_YESNO or MB_ICONERROR or MB_TOPMOST);

  if Response = IDYES then
    ShellExecute(0, 'open', PChar(FConfig.DownloadURL), nil, nil, SW_SHOWNORMAL);

  WriteLog('程序因安全违规退出');

  // Use Halt(1) instead of ExitProcess(1) to allow proper finalization:
  // - Unit finalization sections run (logs flushed, DB connections closed)
  // - Exit procedures execute
  // - File buffers are flushed to disk
  Halt(1);
end;

class procedure TAntiTamperPackage.ClearTable(AConnection: TFDConnection);
var
  Q: TFDQuery;
begin
  if not Assigned(AConnection) then Exit;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConnection;
    Q.SQL.Text := 'DELETE FROM ' + FConfig.TableName;
    Q.ExecSQL;
    WriteLog('已清空防篡改数据表');
  finally
    Q.Free;
  end;
end;

class procedure TAntiTamperPackage.ReseedMinimal(AConnection: TFDConnection);
var
  Q: TFDQuery;
  EmptyData: TBytes;
  SHAHex, HMACHex: string;
  Stream: TBytesStream;
begin
  if not Assigned(AConnection) then Exit;
  SetLength(EmptyData, 0);
  SHAHex := CalculateSHA256(EmptyData);
  HMACHex := ComputeHMACSHA256(EmptyData);
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConnection;
    Q.SQL.Text := 'INSERT INTO ' + FConfig.TableName + ' (image_key, image_data, address_text, description, sha256_hash, hmac_sha256) ' +
                  'VALUES (:key, :data, :addr, :desc, :sha, :hmac)';
    Q.ParamByName('key').AsString := 'seed';
    Stream := TBytesStream.Create(EmptyData);
    try
      Q.ParamByName('data').LoadFromStream(Stream, ftBlob);
    finally
      Stream.Free;
    end;
    Q.ParamByName('addr').AsString := '';
    Q.ParamByName('desc').AsString := 'minimal seed';
    Q.ParamByName('sha').AsString := SHAHex;
    Q.ParamByName('hmac').AsString := HMACHex;
    Q.ExecSQL;
    WriteLog('已播种最小合法记录 seed');
  finally
    Q.Free;
  end;
end;

end.