unit uAntiTamperPackage;

{
  闃茬鏀规満鍒舵墦鍖呮ā鍧?
  
  鍔熻兘锛?
  1. 鍥惧儚鏁版嵁鍔犲瘑/瑙ｅ瘑
  2. SHA-256瀹屾暣鎬ф牎楠?
  3. 绡℃敼妫€娴嬪拰瀹夊叏鍝嶅簲
  4. 鏁版嵁搴撹〃缁撴瀯绠＄悊
  
  浣跨敤鏂规硶锛?
  1. 鍦ㄩ」鐩腑寮曠敤姝ゅ崟鍏?
  2. 璋冪敤 TAntiTamperPackage.SetupDatabase() 鍒濆鍖栨暟鎹簱
  3. 浣跨敤 TAntiTamperPackage.SaveSecureImage() 淇濆瓨鍔犲瘑鍥惧儚
  4. 浣跨敤 TAntiTamperPackage.LoadSecureImage() 鍔犺浇骞舵牎楠屽浘鍍?
  
  渚濊禆锛?
  - FireDAC缁勪欢
  - System.Hash鍗曞厓
  
  缂栬瘧鎸囦护锛?
  - 鍦≧elease閰嶇疆涓畾涔塕ELEASE绗﹀彿浠ョ鐢ㄨ缁嗘棩蹇?
}

{$IFDEF RELEASE}
  {$DEFINE NO_DEBUG_LOG}  // 鐢熶骇鐜绂佺敤璇︾粏鏃ュ織
{$ENDIF}

interface

uses
  System.SysUtils, System.Classes, System.Hash, System.NetEncoding, System.StrUtils,
  Vcl.Dialogs, Vcl.Graphics, Vcl.ExtCtrls, Winapi.ShellAPI, Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Stan.Param, Data.DB, uBasicProtection,
  DeepBase.Exceptions;

type
  // 鍔犲瘑绠楁硶绫诲瀷
  TEncryptionType = (etXOR, etAES256);
  
  // 瀹夊叏閰嶇疆
  TAntiTamperConfig = record
    EncryptionKey: string;        // 鍔犲瘑瀵嗛挜
    DownloadURL: string;          // 瀹樼綉涓嬭浇鍦板潃
    TableName: string;            // 鏁版嵁搴撹〃鍚?
    EnableLogging: Boolean;       // 鏄惁鍚敤鏃ュ織
    LogFileName: string;          // 鏃ュ織鏂囦欢鍚?
    EncryptionType: TEncryptionType; // 鍔犲瘑绠楁硶绫诲瀷
    // KDF 涓?HMAC 璁剧疆
    Salt: string;                 // KDF鐩?
    KdfIterations: Integer;       // KDF杩唬娆℃暟
    EnableHMAC: Boolean;          // 鏄惁鍚敤HMAC瀹屾暣鎬х鍚?
  end;

 

  // 闃茬鏀瑰寘涓荤被
  TAntiTamperPackage = class
  private
    class var FConfig: TAntiTamperConfig;
    class var FInitialized: Boolean;
    
    // 鍐呴儴鏂规硶
    class function SimpleXOREncrypt(const Data: TBytes; const Key: string): TBytes;
    class function SimpleXORDecrypt(const Data: TBytes; const Key: string): TBytes;
    class procedure WriteLog(const AMessage: string);
    class function DeriveKeyBytes: TBytes; // 鍩轰簬EncryptionKey+Salt鐨勮凯浠ｅ搱甯?
    class function GetEffectiveKeyString: string; // 渚涘绉板姞瑙ｅ瘑浣跨敤鐨勬淳鐢熷瘑閽ワ紙hex锛?
    class function ComputeHMACSHA256(const Data: TBytes): string; // HMAC绛惧悕
    
  public
    // 鍒濆鍖栭厤缃?
    class procedure Initialize(const AConfig: TAntiTamperConfig);
    
    // 鏁版嵁搴撹〃缁撴瀯绠＄悊
    class function SetupDatabase(AConnection: TFDConnection): Boolean;
    class function UpgradeDatabase(AConnection: TFDConnection): Boolean;
    class procedure ClearTable(AConnection: TFDConnection);
    class procedure ReseedMinimal(AConnection: TFDConnection);
    
    // 鍝堝笇璁＄畻
    class function CalculateMD5(const Data: TBytes): string; deprecated 'Use CalculateSHA256 instead';
    class function CalculateSHA256(const Data: TBytes): string;
    
    // 鍔犲瘑瑙ｅ瘑
    class function EncryptImageData(const ImageData: TBytes): TBytes;
    class function DecryptImageData(const EncryptedData: TBytes): TBytes;
    
    // 瀹屾暣鎬ф牎楠?
    class function VerifyImageIntegrity(const DecryptedData: TBytes; const ExpectedHash: string): Boolean;
    
    // 瀹夊叏鍥惧儚鎿嶄綔
    class function SaveSecureImage(AConnection: TFDConnection; const AImageKey: string; 
      const AImageData: TBytes; const AAddressText: string = ''; const ADescription: string = ''): Boolean;
    class function LoadSecureImage(ATable: TFDTable; const AImageKey: string; 
      AImage: TImage; out AAddressText: string): Boolean;
    
    // 瀹夊叏鍝嶅簲
    class procedure HandleSecurityViolation(const ImageKey: string; const Reason: string);
    
    // 宸ュ叿鏂规硶
    class function GetDefaultConfig: TAntiTamperConfig;
  end;

implementation

// 榛樿閰嶇疆
class function TAntiTamperPackage.GetDefaultConfig: TAntiTamperConfig;
begin
  Result.EncryptionKey := 'Default_AntiTamper_Key_2025';
  Result.DownloadURL := 'https://your-website.com/download';
  Result.TableName := 'aboutMeImages';
  Result.EnableLogging := True;
  Result.LogFileName := 'antitamper_debug.log';
  Result.EncryptionType := etAES256; // 榛樿浣跨敤AES-256
  // KDF/HMAC 榛樿鍊?
  Result.Salt := 'DeepMoveC_Default_Salt_2025';
  Result.KdfIterations := 5000;
  Result.EnableHMAC := True;
end;

class procedure TAntiTamperPackage.Initialize(const AConfig: TAntiTamperConfig);
begin
  FConfig := AConfig;
  FInitialized := True;
    WriteLog('闃茬鏀瑰寘鍒濆鍖栧畬鎴�');
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
  // XOR鍔犲瘑鏄绉扮殑锛岃В瀵嗗拰鍔犲瘑浣跨敤鐩稿悓绠楁硶
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

// 鍩轰簬 SHA-256 鐨勭畝鍗曡凯浠DF锛岃緭鍑?2瀛楄妭
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
  // 绉嶅瓙閲囩敤UTF-8瀛楃涓插弬涓庡搱甯?
  SeedStr := FConfig.EncryptionKey + '|' + FConfig.Salt;
  AccHex := THashSHA2.GetHashString(SeedStr); // 64浣嶅崄鍏繘鍒跺瓧绗︿覆
  Iterations := FConfig.KdfIterations;
  if Iterations < 2 then Iterations := 2;
  for I := 2 to Iterations do
    AccHex := THashSHA2.GetHashString(AccHex);
  Result := HexToBytes(AccHex); // 32瀛楄妭
end;

// 灏嗘淳鐢熷瘑閽ヨ浆涓篐EX瀛楃涓诧紝浣滀负瀵圭О鍙ｄ护
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
  // 杩斿洖鍗佸叚杩涘埗鍙ｄ护瀛楃涓?
  Result := BytesToHex(DeriveKeyBytes);
end;

// 璁＄畻 HMAC-SHA256 骞惰繑鍥濰EX
// 娉ㄦ剰锛氳繖閲屽疄闄呰绠楃殑鏄?HMAC(SHA256(Data), Key)锛岃€岄潪鏍囧噯 HMAC(Data, Key)
// 浣嗗彧瑕佹挱绉嶅拰楠岃瘉浣跨敤鐩稿悓閫昏緫锛岄槻绡℃敼浠嶇劧鏈夋晥
class function TAntiTamperPackage.ComputeHMACSHA256(const Data: TBytes): string;
var
  DataDigest, KeyHex: string;
begin
  // 鍏堣绠?Data 鐨?SHA-256 鎽樿锛屽啀璁＄畻鍏?HMAC
  DataDigest := THash.DigestAsString(Data);
  KeyHex := GetEffectiveKeyString;
  Result := THashSHA2.GetHMAC(DataDigest, KeyHex);
end;

class function TAntiTamperPackage.EncryptImageData(const ImageData: TBytes): TBytes;
begin
  if not FInitialized then
    raise EAntiTamperException.Create('闃茬鏀瑰寘鏈垵濮嬪寲');
  
  // 鏍规嵁閰嶇疆閫夋嫨鍔犲瘑绠楁硶
  case FConfig.EncryptionType of
    etXOR:
      Result := SimpleXOREncrypt(ImageData, FConfig.EncryptionKey);
    etAES256:
      Result := TBasicProtection.EncryptBinaryData(ImageData, GetEffectiveKeyString);
  else
      raise EAntiTamperException.Create('鏈煡鐨勫姞瀵嗙被鍨�');
  end;
  
  if FConfig.EncryptionType = etAES256 then
      WriteLog(Format('浣跨敤AES-256鍔犲瘑锛屾暟鎹暱搴�: %d bytes', [Length(Result)]))
  else
      WriteLog(Format('浣跨敤XOR鍔犲瘑锛屾暟鎹暱搴�: %d bytes', [Length(Result)]));
end;

class function TAntiTamperPackage.DecryptImageData(const EncryptedData: TBytes): TBytes;
begin
  if not FInitialized then
    raise EAntiTamperException.Create('闃茬鏀瑰寘鏈垵濮嬪寲');
  
  // 鏍规嵁閰嶇疆閫夋嫨瑙ｅ瘑绠楁硶
  case FConfig.EncryptionType of
    etXOR:
      Result := SimpleXORDecrypt(EncryptedData, FConfig.EncryptionKey);
    etAES256:
      Result := TBasicProtection.DecryptBinaryData(EncryptedData, GetEffectiveKeyString);
  else
      raise EAntiTamperException.Create('鏈煡鐨勫姞瀵嗙被鍨�');
  end;
  
  if FConfig.EncryptionType = etAES256 then
      WriteLog(Format('浣跨敤AES-256瑙ｅ瘑锛屾暟鎹暱搴�: %d bytes', [Length(Result)]))
  else
      WriteLog(Format('浣跨敤XOR瑙ｅ瘑锛屾暟鎹暱搴�: %d bytes', [Length(Result)]));
end;

class function TAntiTamperPackage.VerifyImageIntegrity(const DecryptedData: TBytes; const ExpectedHash: string): Boolean;
var
  ActualHash: string;
begin
  // 浣跨敤SHA-256杩涜瀹屾暣鎬ф牎楠?
  ActualHash := CalculateSHA256(DecryptedData);
  Result := SameText(ActualHash, ExpectedHash);
  
  if not Result then
    WriteLog(Format('SHA-256鏍￠獙澶辫触: 鏈熸湜=%s, 瀹為檯=%s', [ExpectedHash, ActualHash]));
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
      
      // 妫€鏌ヨ〃鏄惁瀛樺湪
      Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''table'' AND name=''' + FConfig.TableName + '''';
      Query.Open;
      TableExists := not Query.IsEmpty;
      Query.Close;
      
      if not TableExists then
      begin
        // 鍒涘缓鏂拌〃缁撴瀯锛堝寘鍚墍鏈夊瓧娈碉級
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
        WriteLog('闃茬鏀规暟鎹〃鍒涘缓鎴愬姛');
      end
      else
      begin
        // 琛ㄥ凡瀛樺湪锛屽崌绾ц〃缁撴瀯
        WriteLog('闃茬鏀规暟鎹〃宸插瓨鍦紝妫€鏌ュ苟鍗囩骇瀛楁');
        if not UpgradeDatabase(AConnection) then
        begin
            WriteLog('鍗囩骇鏁版嵁琛ㄥけ璐�');
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
      WriteLog('璁剧疆闃茬鏀规暟鎹〃澶辫触: ' + E.Message);
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
      
      // 涓虹幇鏈夎〃娣诲姞sha256_hash瀛楁
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN sha256_hash TEXT';
        Query.ExecSQL;
        WriteLog('sha256_hash瀛楁娣诲姞鎴愬姛');
      except
          WriteLog('sha256_hash瀛楁鍙兘宸插瓨鍦�');
      end;
      // 涓虹幇鏈夎〃娣诲姞hmac_sha256瀛楁
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN hmac_sha256 TEXT';
        Query.ExecSQL;
        WriteLog('hmac_sha256瀛楁娣诲姞鎴愬姛');
      except
          WriteLog('hmac_sha256瀛楁鍙兘宸插瓨鍦�');
      end;
      // 涓虹幇鏈夎〃娣诲姞enabled瀛楁
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN enabled INTEGER NOT NULL DEFAULT 1';
        Query.ExecSQL;
        WriteLog('enabled瀛楁娣诲姞鎴愬姛');
      except
          WriteLog('enabled瀛楁鍙兘宸插瓨鍦�');
      end;
      // 涓虹幇鏈夎〃娣诲姞md5_hash瀛楁锛堝吋瀹规棫瀹炵幇锛?
      try
        Query.SQL.Text := 'ALTER TABLE ' + FConfig.TableName + ' ADD COLUMN md5_hash TEXT';
        Query.ExecSQL;
        WriteLog('md5_hash瀛楁娣诲姞鎴愬姛');
      except
          WriteLog('md5_hash瀛楁鍙兘宸插瓨鍦�');
      end;
      
      Result := True;
      
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLog('鍗囩骇鏁版嵁搴撳け璐? ' + E.Message);
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
      WriteLog('鍥惧儚鏁版嵁涓虹┖: ' + AImageKey);
      Exit;
    end;
    
    // 璁＄畻鍘熷鍥惧儚鏁版嵁鐨凷HA-256
    Sha256Hex := CalculateSHA256(AImageData);
    WriteLog(Format('鍥惧儚 %s 鐨凷HA-256: %s', [AImageKey, Sha256Hex]));
    
    // 鍔犲瘑鍥惧儚鏁版嵁
    EncryptedData := EncryptImageData(AImageData);
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := AConnection;
      
      // 妫€鏌ヨ褰曟槸鍚﹀瓨鍦?
      Query.SQL.Text := 'SELECT COUNT(*) as cnt FROM ' + FConfig.TableName + ' WHERE image_key = :key';
      Query.ParamByName('key').AsString := AImageKey;
      Query.Open;
      RecordExists := Query.FieldByName('cnt').AsInteger > 0;
      Query.Close;
      
      if RecordExists then
      begin
        // 鏇存柊鐜版湁璁板綍锛堜弗鏍兼ā寮忥細蹇呴』鍖呭惈 sha256_hash 涓?hmac_sha256锛宮d5_hash 淇濇寔鍏煎锛?
        Query.SQL.Text :=
          'UPDATE ' + FConfig.TableName + ' SET image_data = :data, address_text = :addr, description = :desc, ' +
          'sha256_hash = :hash, hmac_sha256 = :hmac, md5_hash = :md5, updated_at = CURRENT_TIMESTAMP ' +
          'WHERE image_key = :key';
      end
      else
      begin
        // 鎻掑叆鏂拌褰曪紙涓ユ牸妯″紡锛宮d5_hash 鍐欏叆绌哄瓧绗︿覆浠ュ吋瀹规棫琛?NOT NULL 绾︽潫锛?
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
      // 鍐欏叆HMAC锛堜弗鏍兼ā寮忥細蹇呴』锛?
      Query.ParamByName('hmac').AsString := ComputeHMACSHA256(AImageData);
      // 鍐欏叆md5_hash锛堝吋瀹规棫琛ㄧ殑NOT NULL绾︽潫锛屽啓鍏ョ┖瀛楃涓诧級
      Query.ParamByName('md5').AsString := '';
      Query.ExecSQL;
      
      WriteLog(Format('瀹夊叏鍥惧儚淇濆瓨鎴愬姛: %s', [AImageKey]));
      Result := True;
      
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLog(Format('淇濆瓨瀹夊叏鍥惧儚澶辫触: %s - %s', [AImageKey, E.Message]));
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
      WriteLog('Image鎺т欢鏈垎閰? ' + AImageKey);
      Exit;
    end;
    
    if not ATable.Active then
    begin
      WriteLog('鏁版嵁琛ㄦ湭婵€娲? ' + AImageKey);
      Exit;
    end;
    
    // 鏌ユ壘璁板綍
    if ATable.Locate('image_key', AImageKey, []) then
    begin
      WriteLog('鍦ㄦ暟鎹簱涓壘鍒拌褰? ' + AImageKey);
      
      // 鑾峰彇瀛楁
      var ImageField := ATable.FieldByName('image_data');
      var AddressField := ATable.FieldByName('address_text');
      var SHAField := ATable.FieldByName('sha256_hash');
      var HMACField := ATable.FindField('hmac_sha256');
      
      if not ImageField.IsNull then
      begin
        MemoryStream := TMemoryStream.Create;
        try
          // 浠嶣lob瀛楁鍔犺浇鍔犲瘑鏁版嵁
          TBlobField(ImageField).SaveToStream(MemoryStream);
          MemoryStream.Position := 0;
          
          // 璇诲彇鍔犲瘑鏁版嵁
          SetLength(EncryptedData, MemoryStream.Size);
          MemoryStream.ReadBuffer(EncryptedData[0], MemoryStream.Size);
          
          WriteLog(Format('鍔犲瘑鏁版嵁闀垮害: %d bytes - %s', [Length(EncryptedData), AImageKey]));
          
          // 瑙ｅ瘑鏁版嵁
          DecryptedData := DecryptImageData(EncryptedData);
          WriteLog(Format('瑙ｅ瘑鏁版嵁闀垮害: %d bytes - %s', [Length(DecryptedData), AImageKey]));
          
          // SHA-256瀹屾暣鎬ф牎楠岋紙涓ユ牸锛氬瓧娈靛繀椤诲瓨鍦級
          if not Assigned(SHAField) or SHAField.IsNull then
          begin
              HandleSecurityViolation(AImageKey, '缂哄皯 sha256_hash 瀛楁鎴栦负绌�');
            Exit;
          end;
          ExpectedMD5 := SHAField.AsString;
          if not VerifyImageIntegrity(DecryptedData, ExpectedMD5) then
          begin
            WriteLog(Format('SHA-256鏍￠獙澶辫触: %s', [AImageKey]));
            HandleSecurityViolation(AImageKey, 'SHA-256鏍￠獙澶辫触锛屽浘鍍忔暟鎹彲鑳借绡℃敼');
            Exit;
          end;
          // HMAC 鏍￠獙锛堜弗鏍硷細瀛楁蹇呴』瀛樺湪涓斿尮閰嶏級
          if not Assigned(HMACField) or HMACField.IsNull then
          begin
              HandleSecurityViolation(AImageKey, '缂哄皯 hmac_sha256 瀛楁鎴栦负绌�');
            Exit;
          end;
          if FConfig.EnableHMAC then
          begin
            var ExpectedHMAC := HMACField.AsString;
            var ActualHMAC := ComputeHMACSHA256(DecryptedData);
            if not SameText(ExpectedHMAC, ActualHMAC) then
            begin
              WriteLog(Format('HMAC-SHA256鏍￠獙澶辫触: %s', [AImageKey]));
              HandleSecurityViolation(AImageKey, 'HMAC-SHA256鏍￠獙澶辫触锛屽浘鍍忔暟鎹彲鑳借绡℃敼');
              Exit;
            end;
          end;
          
          WriteLog(Format('SHA-256鏍￠獙閫氳繃: %s', [AImageKey]));
          
          // 浠庤В瀵嗘暟鎹姞杞藉浘鍍?
          MemoryStream.Clear;
          MemoryStream.WriteBuffer(DecryptedData[0], Length(DecryptedData));
          MemoryStream.Position := 0;
          
          AImage.Picture.LoadFromStream(MemoryStream);
          WriteLog(Format('瀹夊叏鍥惧儚鍔犺浇鎴愬姛: %s, 灏哄: %dx%d', [AImageKey, AImage.Picture.Width, AImage.Picture.Height]));
          
          // 鑾峰彇鍦板潃鏂囨湰
          if not AddressField.IsNull then
            AAddressText := AddressField.AsString;
            
          Result := True;
          
        finally
          MemoryStream.Free;
        end;
      end
      else
      begin
        WriteLog('鍥惧儚瀛楁涓虹┖: ' + AImageKey);
      end;
    end
    else
    begin
      WriteLog('鏁版嵁搴撲腑鏈壘鍒拌褰? ' + AImageKey);
    end;
    
  except
    on E: Exception do
    begin
      WriteLog(Format('鍔犺浇瀹夊叏鍥惧儚鏃跺嚭閿? %s - %s', [AImageKey, E.Message]));
      Result := False;
    end;
  end;
end;

class procedure TAntiTamperPackage.HandleSecurityViolation(const ImageKey: string; const Reason: string);
var
  ErrorMsg: string;
  Response: Integer;
begin
  WriteLog(Format('瀹夊叏杩濊: %s - %s', [ImageKey, Reason]));
  
  ErrorMsg := Format('瀹夊叏妫€鏌ュけ璐ワ紒'#13#10#13#10 +
    '鍥惧儚: %s'#13#10 +
    '鍘熷洜: %s'#13#10#13#10 +
      '妫€娴嬪埌绋嬪簭鏂囦欢鍙兘琚鏀癸紝涓轰簡鎮ㄧ殑瀹夊叏锛岀▼搴忓皢閫€鍑恒€�'#13#10 +
      '璇蜂粠瀹樻柟缃戠珯涓嬭浇鏈€鏂扮増鏈€�'#13#10#13#10 +
      '鏄惁鐜板湪璁块棶瀹樻柟涓嬭浇椤甸潰锛�', [ImageKey, Reason]);
    
  Response := MessageBox(0, PChar(ErrorMsg), '瀹夊叏璀﹀憡', MB_YESNO or MB_ICONERROR or MB_TOPMOST);
  
  if Response = IDYES then
  begin
    // 鎵撳紑瀹樻柟涓嬭浇椤甸潰
    ShellExecute(0, 'open', PChar(FConfig.DownloadURL), nil, nil, SW_SHOWNORMAL);
  end;
  
  // 寮哄埗閫€鍑虹▼搴?
    WriteLog('绋嬪簭鍥犲畨鍏ㄨ繚瑙勯€€鍑�');
  ExitProcess(1);
end;

// 娓呯┖闃茬鏀硅〃锛堜弗鏍兼ā寮忚緟鍔╋級
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
      WriteLog('宸叉竻绌洪槻绡℃敼鏁版嵁琛�');
  finally
    Q.Free;
  end;
end;

// 鎾鏈€灏忓悎娉曡褰曪紙涓ユ牸妯″紡杈呭姪锛?
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
    WriteLog('宸叉挱绉嶆渶灏忓悎娉曡褰?seed');
  finally
    Q.Free;
  end;
end;

end.
