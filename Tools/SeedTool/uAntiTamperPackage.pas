unit uAntiTamperPackage;

{
  防篡改机制打包模块
  
  功能：
  1. 图像数据加密/解密
  2. SHA-256完整性校验
  3. 篡改检测和安全响应
  4. 数据库表结构管理
  
  使用方法：
  1. 在项目中引用此单元
  2. 调用 TAntiTamperPackage.SetupDatabase() 初始化数据库
  3. 使用 TAntiTamperPackage.SaveSecureImage() 保存加密图像
  4. 使用 TAntiTamperPackage.LoadSecureImage() 加载并校验图像
  
  依赖：
  - FireDAC组件
  - System.Hash单元
  
  编译指令：
  - 在Release配置中定义RELEASE符号以禁用详细日志
}

{$IFDEF RELEASE}
  {$DEFINE NO_DEBUG_LOG}  // 生产环境禁用详细日志
{$ENDIF}

interface

uses
  System.SysUtils, System.Classes, System.Hash, System.NetEncoding, System.StrUtils,
  Vcl.Dialogs, Vcl.Graphics, Vcl.ExtCtrls, Winapi.ShellAPI, Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Stan.Param, Data.DB, uBasicProtection;

type
  // 加密算法类型
  TEncryptionType = (etXOR, etAES256);
  
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
    
    // 内部方法
    class function SimpleXOREncrypt(const Data: TBytes; const Key: string): TBytes;
    class function SimpleXORDecrypt(const Data: TBytes; const Key: string): TBytes;
    class procedure WriteLog(const AMessage: string);
    class function DeriveKeyBytes: TBytes; // 基于EncryptionKey+Salt的迭代哈希
    class function GetEffectiveKeyString: string; // 供对称加解密使用的派生密钥（hex）
    class function ComputeHMACSHA256(const Data: TBytes): string; // HMAC签名
    
  public
    // 初始化配置
    class procedure Initialize(const AConfig: TAntiTamperConfig);
    
    // 数据库表结构管理
    class function SetupDatabase(AConnection: TFDConnection): Boolean;
    class function UpgradeDatabase(AConnection: TFDConnection): Boolean;
    class procedure ClearTable(AConnection: TFDConnection);
    class procedure ReseedMinimal(AConnection: TFDConnection);
    
    // 哈希计算
    class function CalculateMD5(const Data: TBytes): string; deprecated 'Use CalculateSHA256 instead';
    class function CalculateSHA256(const Data: TBytes): string;
    
    // 加密解密
    class function EncryptImageData(const ImageData: TBytes): TBytes;
    class function DecryptImageData(const EncryptedData: TBytes): TBytes;
    
    // 完整性校验
    class function VerifyImageIntegrity(const DecryptedData: TBytes; const ExpectedHash: string): Boolean;
    
    // 安全图像操作
    class function SaveSecureImage(AConnection: TFDConnection; const AImageKey: string; 
      const AImageData: TBytes; const AAddressText: string = ''; const ADescription: string = ''): Boolean;
    class function LoadSecureImage(ATable: TFDTable; const AImageKey: string; 
      AImage: TImage; out AAddressText: string): Boolean;
    
    // 安全响应
    class procedure HandleSecurityViolation(const ImageKey: string; const Reason: string);
    
    // 工具方法
    class function GetDefaultConfig: TAntiTamperConfig;
  end;

implementation

// 默认配置
class function TAntiTamperPackage.GetDefaultConfig: TAntiTamperConfig;
begin
  Result.EncryptionKey := 'Default_AntiTamper_Key_2025';
  Result.DownloadURL := 'https://your-website.com/download';
  Result.TableName := 'images';
  Result.EnableLogging := True;
  Result.LogFileName := 'antitamper_debug.log';
  Result.EncryptionType := etAES256; // 默认使用AES-256
  // KDF/HMAC 默认值
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

class function TAntiTamperPackage.SimpleXOREncrypt(const Data: TBytes; const Key: string): TBytes;
var
  I: Integer;
  KeyBytes: TBytes;
  KeyIndex: Integer;
begin
  SetLength(Result, Length(Data));
  KeyBytes := TEncoding.UTF8.GetBytes(Key);
  KeyIndex := 0;
  
  for I := 0 to High(Data) do
  begin
    Result[I] := Data[I] xor KeyBytes[KeyIndex];
    KeyIndex := (KeyIndex + 1) mod Length(KeyBytes);
  end;
end;

class function TAntiTamperPackage.SimpleXORDecrypt(const Data: TBytes; const Key: string): TBytes;
begin
  // XOR加密是对称的，解密和加密使用相同算法
  Result := SimpleXOREncrypt(Data, Key);
end;

class function TAntiTamperPackage.CalculateMD5(const Data: TBytes): string;
var
  Hash: THashMD5;
begin
  Hash := THashMD5.Create;
  Hash.Update(Data);
  Result := Hash.HashAsString;
end;

class function TAntiTamperPackage.CalculateSHA256(const Data: TBytes): string;
var
  Hash: THashSHA2;
begin
  Hash := THashSHA2.Create;
  Hash.Update(Data);
  Result := Hash.HashAsString;
end;

// 基于 SHA-256 的简单迭代KDF，输出32字节
class function TAntiTamperPackage.DeriveKeyBytes: TBytes;
  function HexToBytes(const Hex: string): TBytes;
  var
    I, N: Integer;
  begin
    N := Length(Hex) div 2;
    SetLength(Result, N);
    for I := 0 to N - 1 do
      Result[I] := StrToInt('$' + Copy(Hex, I*2+1, 2));
  end;
var
  I, Iterations: Integer;
  AccHex: string;
  SeedStr: string;
begin
  // 种子采用UTF-8字符串参与哈希
  SeedStr := FConfig.EncryptionKey + '|' + FConfig.Salt;
  AccHex := THashSHA2.GetHashString(SeedStr); // 64位十六进制字符串
  Iterations := FConfig.KdfIterations;
  if Iterations < 2 then Iterations := 2;
  for I := 2 to Iterations do
    AccHex := THashSHA2.GetHashString(AccHex);
  Result := HexToBytes(AccHex); // 32字节
end;

// 将派生密钥转为HEX字符串，作为对称口令
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
  // 返回十六进制口令字符串
  Result := BytesToHex(DeriveKeyBytes);
end;

// 计算 HMAC-SHA256 并返回HEX
// 注意：这里实际计算的是 HMAC(SHA256(Data), Key)，而非标准 HMAC(Data, Key)
// 但只要播种和验证使用相同逻辑，防篡改仍然有效
class function TAntiTamperPackage.ComputeHMACSHA256(const Data: TBytes): string;
var
  DataDigest, KeyHex: string;
begin
  // 先计算 Data 的 SHA-256 摘要，再计算其 HMAC
  DataDigest := THash.DigestAsString(Data);
  KeyHex := GetEffectiveKeyString;
  Result := THashSHA2.GetHMAC(DataDigest, KeyHex);
end;

class function TAntiTamperPackage.EncryptImageData(const ImageData: TBytes): TBytes;
begin
  if not FInitialized then
    raise Exception.Create('防篡改包未初始化');
  
  // 根据配置选择加密算法
  case FConfig.EncryptionType of
    etXOR:
      Result := SimpleXOREncrypt(ImageData, FConfig.EncryptionKey);
    etAES256:
      Result := TBasicProtection.EncryptBinaryData(ImageData, GetEffectiveKeyString);
  else
    raise Exception.Create('未知的加密类型');
  end;
  
  if FConfig.EncryptionType = etAES256 then
    WriteLog(Format('使用AES-256加密，数据长度: %d bytes', [Length(Result)]))
  else
    WriteLog(Format('使用XOR加密，数据长度: %d bytes', [Length(Result)]));
end;

class function TAntiTamperPackage.DecryptImageData(const EncryptedData: TBytes): TBytes;
begin
  if not FInitialized then
    raise Exception.Create('防篡改包未初始化');
  
  // 根据配置选择解密算法
  case FConfig.EncryptionType of
    etXOR:
      Result := SimpleXORDecrypt(EncryptedData, FConfig.EncryptionKey);
    etAES256:
      Result := TBasicProtection.DecryptBinaryData(EncryptedData, GetEffectiveKeyString);
  else
    raise Exception.Create('未知的加密类型');
  end;
  
  if FConfig.EncryptionType = etAES256 then
    WriteLog(Format('使用AES-256解密，数据长度: %d bytes', [Length(Result)]))
  else
    WriteLog(Format('使用XOR解密，数据长度: %d bytes', [Length(Result)]));
end;

class function TAntiTamperPackage.VerifyImageIntegrity(const DecryptedData: TBytes; const ExpectedHash: string): Boolean;
var
  ActualHash: string;
begin
  // 使用SHA-256进行完整性校验
  ActualHash := CalculateSHA256(DecryptedData);
  Result := SameText(ActualHash, ExpectedHash);
  
  if not Result then
    WriteLog(Format('SHA-256校验失败: 期望=%s, 实际=%s', [ExpectedHash, ActualHash]));
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
      
      // 检查表是否存在
      Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''table'' AND name=''' + FConfig.TableName + '''';
      Query.Open;
      TableExists := not Query.IsEmpty;
      Query.Close;
      
      if not TableExists then
      begin
        // 创建新表结构（包含所有字段）
        Query.SQL.Text :=
          'CREATE TABLE ' + FConfig.TableName + ' (' +
          '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
          '  image_key TEXT NOT NULL UNIQUE,' +
          '  image_data BLOB NOT NULL,' +
          '  address_text TEXT,' +
          '  description TEXT,' +
          '  sha256_hash TEXT NOT NULL,' +
          '  hmac_sha256 TEXT NOT NULL,' +
          '  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
          '  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP' +
          ')';
        Query.ExecSQL;
        WriteLog('防篡改数据表创建成功');
      end
      else
      begin
        // 表已存在，升级表结构
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
      
      // 为现有表添加sha256_hash字段
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN sha256_hash TEXT';
        Query.ExecSQL;
        WriteLog('sha256_hash字段添加成功');
      except
        WriteLog('sha256_hash字段可能已存在');
      end;
      // 为现有表添加hmac_sha256字段
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN hmac_sha256 TEXT';
        Query.ExecSQL;
        WriteLog('hmac_sha256字段添加成功');
      except
        WriteLog('hmac_sha256字段可能已存在');
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
  const AImageData: TBytes; const AAddressText: string; const ADescription: string): Boolean;
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
    
    // 计算原始图像数据的SHA-256
    Sha256Hex := CalculateSHA256(AImageData);
    WriteLog(Format('图像 %s 的SHA-256: %s', [AImageKey, Sha256Hex]));
    
    // 加密图像数据
    EncryptedData := EncryptImageData(AImageData);
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := AConnection;
      
      // 检查记录是否存在
      Query.SQL.Text := 'SELECT COUNT(*) as cnt FROM ' + FConfig.TableName + ' WHERE image_key = :key';
      Query.ParamByName('key').AsString := AImageKey;
      Query.Open;
      RecordExists := Query.FieldByName('cnt').AsInteger > 0;
      Query.Close;
      
      if RecordExists then
      begin
        // 更新现有记录（严格模式：必须包含 sha256_hash 与 hmac_sha256，md5_hash 保持兼容）
        Query.SQL.Text :=
          'UPDATE ' + FConfig.TableName + ' SET image_data = :data, address_text = :addr, description = :desc, ' +
          'sha256_hash = :hash, hmac_sha256 = :hmac, md5_hash = :md5, updated_at = CURRENT_TIMESTAMP ' +
          'WHERE image_key = :key';
      end
      else
      begin
        // 插入新记录（严格模式，md5_hash 写入空字符串以兼容旧表 NOT NULL 约束）
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
      // 写入HMAC（严格模式：必须）
      Query.ParamByName('hmac').AsString := ComputeHMACSHA256(AImageData);
      // 写入md5_hash（兼容旧表的NOT NULL约束，写入空字符串）
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

class function TAntiTamperPackage.LoadSecureImage(ATable: TFDTable; const AImageKey: string; 
  AImage: TImage; out AAddressText: string): Boolean;
var
  EncryptedData: TBytes;
  DecryptedData: TBytes;
  ExpectedMD5: string;
  MemoryStream: TMemoryStream;
begin
  Result := False;
  AAddressText := '';
  
  try
    if not Assigned(AImage) then
    begin
      WriteLog('Image控件未分配: ' + AImageKey);
      Exit;
    end;
    
    if not ATable.Active then
    begin
      WriteLog('数据表未激活: ' + AImageKey);
      Exit;
    end;
    
    // 查找记录
    if ATable.Locate('image_key', AImageKey, []) then
    begin
      WriteLog('在数据库中找到记录: ' + AImageKey);
      
      // 获取字段
      var ImageField := ATable.FieldByName('image_data');
      var AddressField := ATable.FieldByName('address_text');
      var SHAField := ATable.FieldByName('sha256_hash');
      var HMACField := ATable.FindField('hmac_sha256');
      
      if not ImageField.IsNull then
      begin
        MemoryStream := TMemoryStream.Create;
        try
          // 从Blob字段加载加密数据
          TBlobField(ImageField).SaveToStream(MemoryStream);
          MemoryStream.Position := 0;
          
          // 读取加密数据
          SetLength(EncryptedData, MemoryStream.Size);
          MemoryStream.ReadBuffer(EncryptedData[0], MemoryStream.Size);
          
          WriteLog(Format('加密数据长度: %d bytes - %s', [Length(EncryptedData), AImageKey]));
          
          // 解密数据
          DecryptedData := DecryptImageData(EncryptedData);
          WriteLog(Format('解密数据长度: %d bytes - %s', [Length(DecryptedData), AImageKey]));
          
          // SHA-256完整性校验（严格：字段必须存在）
          if not Assigned(SHAField) or SHAField.IsNull then
          begin
            HandleSecurityViolation(AImageKey, '缺少 sha256_hash 字段或为空');
            Exit;
          end;
          ExpectedMD5 := SHAField.AsString;
          if not VerifyImageIntegrity(DecryptedData, ExpectedMD5) then
          begin
            WriteLog(Format('SHA-256校验失败: %s', [AImageKey]));
            HandleSecurityViolation(AImageKey, 'SHA-256校验失败，图像数据可能被篡改');
            Exit;
          end;
          // HMAC 校验（严格：字段必须存在且匹配）
          if not Assigned(HMACField) or HMACField.IsNull then
          begin
            HandleSecurityViolation(AImageKey, '缺少 hmac_sha256 字段或为空');
            Exit;
          end;
          if FConfig.EnableHMAC then
          begin
            var ExpectedHMAC := HMACField.AsString;
            var ActualHMAC := ComputeHMACSHA256(DecryptedData);
            if not SameText(ExpectedHMAC, ActualHMAC) then
            begin
              WriteLog(Format('HMAC-SHA256校验失败: %s', [AImageKey]));
              HandleSecurityViolation(AImageKey, 'HMAC-SHA256校验失败，图像数据可能被篡改');
              Exit;
            end;
          end;
          
          WriteLog(Format('SHA-256校验通过: %s', [AImageKey]));
          
          // 从解密数据加载图像
          MemoryStream.Clear;
          MemoryStream.WriteBuffer(DecryptedData[0], Length(DecryptedData));
          MemoryStream.Position := 0;
          
          AImage.Picture.LoadFromStream(MemoryStream);
          WriteLog(Format('安全图像加载成功: %s, 尺寸: %dx%d', [AImageKey, AImage.Picture.Width, AImage.Picture.Height]));
          
          // 获取地址文本
          if not AddressField.IsNull then
            AAddressText := AddressField.AsString;
            
          Result := True;
          
        finally
          MemoryStream.Free;
        end;
      end
      else
      begin
        WriteLog('图像字段为空: ' + AImageKey);
      end;
    end
    else
    begin
      WriteLog('数据库中未找到记录: ' + AImageKey);
    end;
    
  except
    on E: Exception do
    begin
      WriteLog(Format('加载安全图像时出错: %s - %s', [AImageKey, E.Message]));
      Result := False;
    end;
  end;
end;

class procedure TAntiTamperPackage.HandleSecurityViolation(const ImageKey: string; const Reason: string);
var
  ErrorMsg: string;
  Response: Integer;
begin
  WriteLog(Format('安全违规: %s - %s', [ImageKey, Reason]));
  
  ErrorMsg := Format('安全检查失败！'#13#10#13#10 +
    '图像: %s'#13#10 +
    '原因: %s'#13#10#13#10 +
    '检测到程序文件可能被篡改，为了您的安全，程序将退出。'#13#10 +
    '请从官方网站下载最新版本。'#13#10#13#10 +
    '是否现在访问官方下载页面？', [ImageKey, Reason]);
    
  Response := MessageBox(0, PChar(ErrorMsg), '安全警告', MB_YESNO or MB_ICONERROR or MB_TOPMOST);
  
  if Response = IDYES then
  begin
    // 打开官方下载页面
    ShellExecute(0, 'open', PChar(FConfig.DownloadURL), nil, nil, SW_SHOWNORMAL);
  end;
  
  // 强制退出程序
  WriteLog('程序因安全违规退出');
  ExitProcess(1);
end;

// 清空防篡改表（严格模式辅助）
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

// 播种最小合法记录（严格模式辅助）
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
