unit UniFlow.Guard;

{*******************************************************************************
  UniFlow.Guard - 守卫角色 (L2 能力层)
  
  描述：
    负责输入/输出校验、安全检查和内容过滤。
    实现三层守卫机制：门卫(输入) → 监工(过程) → 审核官(输出)
    
  职责：
    - 输入校验 (ValidateInput) - 门卫
    - 输出校验 (ValidateOutput) - 审核官
    - 安全检查 (CheckSecurity)
    - 注入检测 (DetectInjection)
    - 敏感信息过滤
    
  信任级别：有限信任
    
  作者：仙儿（安全专家）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.RegularExpressions,
  UniFlow.Message, UniFlow.Role, UniFlow.Config;

type
  /// <summary>校验结果</summary>
  TValidationResult = record
    IsValid: Boolean;
    ErrorCode: string;
    ErrorMessage: string;
    Warnings: TArray<string>;
    SanitizedValue: string;
  end;

  /// <summary>安全检查结果</summary>
  TSecurityCheckResult = record
    IsSafe: Boolean;
    ThreatLevel: Integer;  // 0-10
    ThreatType: string;
    Details: string;
  end;

  /// <summary>Guard 角色</summary>
  TGuard = class(TUniFlowRoleBase, IGuard)
  private
    FConfig: TUniFlowConfig;
    FBlockedPatterns: TList<TRegEx>;
    FSensitivePatterns: TList<TRegEx>;
    
    procedure InitializePatterns;
    function SanitizeInput(const AInput: string): string;
    function CheckForInjectionPatterns(const AInput: string): TSecurityCheckResult;
  protected
    procedure DoInitialize; override;
    procedure DoStart; override;
    procedure DoStop; override;
    function DoHandleMessage(const AMessage: TUniFlowMessage): TUniFlowMessage; override;
  public
    constructor Create; overload;
    constructor Create(const AConfig: TUniFlowConfig); overload;
    destructor Destroy; override;
    
    // IGuard 实现
    /// <summary>校验输入</summary>
    function ValidateInput(const AInput: TJSONObject; const ASchema: TJSONObject): TJSONObject;
    /// <summary>校验输出</summary>
    function ValidateOutput(const AOutput: TJSONObject; const ASchema: TJSONObject): TJSONObject;
    /// <summary>安全检查</summary>
    function CheckSecurity(const AContent: string): TJSONObject;
    /// <summary>检测注入攻击</summary>
    function DetectInjection(const AInput: string): Boolean;
    
    /// <summary>消毒输入内容</summary>
    function Sanitize(const AInput: string): string;
    /// <summary>过滤敏感信息</summary>
    function FilterSensitive(const AContent: string): string;
    
    function CanHandle(const AMsgType: string): Boolean; override;
  end;

implementation

uses
  System.StrUtils, System.DateUtils;

const
  // Prompt 注入模式
  INJECTION_PATTERNS: array[0..14] of string = (
    'ignore.*previous.*instructions',
    'ignore.*all.*previous',
    'disregard.*above',
    'forget.*everything',
    'new.*instructions',
    'system.*prompt',
    'reveal.*prompt',
    'show.*system',
    'jailbreak',
    'dan.*mode',
    'developer.*mode',
    'pretend.*you.*are',
    'act.*as.*if',
    'bypass.*filter',
    'override.*safety'
  );
  
  // 敏感信息模式
  SENSITIVE_PATTERNS: array[0..5] of string = (
    '\b\d{16,19}\b',           // 信用卡号
    '\b\d{3}-\d{2}-\d{4}\b',   // SSN
    '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',  // Email
    '\b1[3-9]\d{9}\b',         // 手机号
    '\b\d{17}[\dXx]\b',        // 身份证号
    'password\s*[:=]\s*\S+'    // 密码
  );

{ TGuard }

constructor TGuard.Create;
begin
  Create(GlobalConfig);
end;

constructor TGuard.Create(const AConfig: TUniFlowConfig);
var
  Meta: TRoleMetaInfo;
begin
  Meta.Name := 'Guard';
  Meta.DisplayName := '守卫';
  Meta.Level := rlCapability;
  Meta.TrustLevel := tlLimitedTrust;
  Meta.Description := '负责输入输出校验、安全检查';
  Meta.Version := '1.0';
  
  inherited Create(Meta);
  
  FConfig := AConfig;
  FBlockedPatterns := TList<TRegEx>.Create;
  FSensitivePatterns := TList<TRegEx>.Create;
end;

destructor TGuard.Destroy;
begin
  FBlockedPatterns.Free;
  FSensitivePatterns.Free;
  inherited;
end;

procedure TGuard.InitializePatterns;
var
  I: Integer;
  Pattern: string;
begin
  // 初始化注入检测模式
  FBlockedPatterns.Clear;
  for I := Low(INJECTION_PATTERNS) to High(INJECTION_PATTERNS) do
  begin
    FBlockedPatterns.Add(TRegEx.Create(INJECTION_PATTERNS[I], [roIgnoreCase]));
  end;
  
  // 添加配置中的自定义模式
  for Pattern in FConfig.BlockedPatterns do
  begin
    try
      FBlockedPatterns.Add(TRegEx.Create(Pattern, [roIgnoreCase]));
    except
      // 忽略无效的正则表达式
    end;
  end;
  
  // 初始化敏感信息模式
  FSensitivePatterns.Clear;
  for I := Low(SENSITIVE_PATTERNS) to High(SENSITIVE_PATTERNS) do
  begin
    FSensitivePatterns.Add(TRegEx.Create(SENSITIVE_PATTERNS[I], [roIgnoreCase]));
  end;
end;

procedure TGuard.DoInitialize;
begin
  InitializePatterns;
end;

procedure TGuard.DoStart;
begin
  // 启动 Guard
end;

procedure TGuard.DoStop;
begin
  // 停止 Guard
end;

function TGuard.SanitizeInput(const AInput: string): string;
begin
  Result := AInput;
  
  // 移除零宽字符
  Result := TRegEx.Replace(Result, '[\x{200B}-\x{200D}\x{FEFF}]', '');
  
  // 规范化空白字符
  Result := TRegEx.Replace(Result, '\s+', ' ');
  
  // 移除控制字符（保留换行和制表符）
  Result := TRegEx.Replace(Result, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '');
  
  Result := Trim(Result);
end;

function TGuard.CheckForInjectionPatterns(const AInput: string): TSecurityCheckResult;
var
  Regex: TRegEx;
  ThreatCount: Integer;
begin
  Result.IsSafe := True;
  Result.ThreatLevel := 0;
  Result.ThreatType := '';
  Result.Details := '';
  
  ThreatCount := 0;
  
  for Regex in FBlockedPatterns do
  begin
    if Regex.IsMatch(AInput) then
    begin
      Inc(ThreatCount);
      Result.IsSafe := False;
      
      if Result.ThreatType = '' then
        Result.ThreatType := 'PROMPT_INJECTION'
      else
        Result.ThreatType := Result.ThreatType + ',PROMPT_INJECTION';
    end;
  end;
  
  // 计算威胁等级
  if ThreatCount > 0 then
  begin
    Result.ThreatLevel := Min(10, ThreatCount * 3);
    Result.Details := Format('检测到 %d 个可疑模式', [ThreatCount]);
  end;
end;

function TGuard.ValidateInput(const AInput: TJSONObject; const ASchema: TJSONObject): TJSONObject;
var
  InputStr: string;
  SecurityCheck: TSecurityCheckResult;
  Warnings: TJSONArray;
begin
  Result := TJSONObject.Create;
  Warnings := TJSONArray.Create;
  
  // 检查输入长度
  InputStr := AInput.ToJSON;
  if Length(InputStr) > FConfig.MaxInputLength then
  begin
    Result.AddPair('valid', TJSONBool.Create(False));
    Result.AddPair('error_code', 'INPUT_TOO_LONG');
    Result.AddPair('error_message', Format('输入长度 %d 超过限制 %d', [Length(InputStr), FConfig.MaxInputLength]));
    Result.AddPair('warnings', Warnings);
    Exit;
  end;
  
  // 提取文本内容进行安全检查
  var TextContent: string := '';
  var TextValue: TJSONValue;
  if AInput.TryGetValue('input', TextValue) or 
     AInput.TryGetValue('text', TextValue) or
     AInput.TryGetValue('content', TextValue) or
     AInput.TryGetValue('prompt', TextValue) then
  begin
    TextContent := TextValue.Value;
  end;
  
  if TextContent <> '' then
  begin
    // 安全检查
    SecurityCheck := CheckForInjectionPatterns(TextContent);
    if not SecurityCheck.IsSafe then
    begin
      Result.AddPair('valid', TJSONBool.Create(False));
      Result.AddPair('error_code', 'SECURITY_THREAT');
      Result.AddPair('error_message', '检测到安全威胁: ' + SecurityCheck.ThreatType);
      Result.AddPair('threat_level', TJSONNumber.Create(SecurityCheck.ThreatLevel));
      Result.AddPair('warnings', Warnings);
      Exit;
    end;
    
    // 消毒输入
    var SanitizedText := SanitizeInput(TextContent);
    if SanitizedText <> TextContent then
      Warnings.Add('输入已被消毒处理');
  end;
  
  // TODO: JSON Schema 校验（如果提供了 Schema）
  if (ASchema <> nil) and (ASchema.Count > 0) then
  begin
    // 简单的必填字段检查
    var Required: TJSONArray;
    if ASchema.TryGetValue<TJSONArray>('required', Required) then
    begin
      for var I := 0 to Required.Count - 1 do
      begin
        var FieldName := Required.Items[I].Value;
        if not AInput.GetValue(FieldName, False) then
        begin
          Result.AddPair('valid', TJSONBool.Create(False));
          Result.AddPair('error_code', 'MISSING_REQUIRED');
          Result.AddPair('error_message', Format('缺少必填字段: %s', [FieldName]));
          Result.AddPair('warnings', Warnings);
          Exit;
        end;
      end;
    end;
  end;
  
  Result.AddPair('valid', TJSONBool.Create(True));
  Result.AddPair('warnings', Warnings);
end;

function TGuard.ValidateOutput(const AOutput: TJSONObject; const ASchema: TJSONObject): TJSONObject;
var
  OutputStr: string;
  Warnings: TJSONArray;
begin
  Result := TJSONObject.Create;
  Warnings := TJSONArray.Create;
  
  OutputStr := AOutput.ToJSON;
  
  // 检查输出中是否包含敏感信息
  var HasSensitive := False;
  for var Regex in FSensitivePatterns do
  begin
    if Regex.IsMatch(OutputStr) then
    begin
      HasSensitive := True;
      Warnings.Add('输出可能包含敏感信息');
      Break;
    end;
  end;
  
  // 检查输出中是否包含系统提示泄露
  if TRegEx.IsMatch(OutputStr, '(?i)(system\s*prompt|系统提示|内部指令)', []) then
  begin
    Warnings.Add('输出可能包含系统信息泄露');
  end;
  
  // TODO: JSON Schema 校验
  
  Result.AddPair('valid', TJSONBool.Create(True));
  Result.AddPair('has_sensitive', TJSONBool.Create(HasSensitive));
  Result.AddPair('warnings', Warnings);
end;

function TGuard.CheckSecurity(const AContent: string): TJSONObject;
var
  CheckResult: TSecurityCheckResult;
begin
  Result := TJSONObject.Create;
  
  CheckResult := CheckForInjectionPatterns(AContent);
  
  Result.AddPair('is_safe', TJSONBool.Create(CheckResult.IsSafe));
  Result.AddPair('threat_level', TJSONNumber.Create(CheckResult.ThreatLevel));
  Result.AddPair('threat_type', CheckResult.ThreatType);
  Result.AddPair('details', CheckResult.Details);
  Result.AddPair('timestamp', DateToISO8601(Now));
end;

function TGuard.DetectInjection(const AInput: string): Boolean;
var
  CheckResult: TSecurityCheckResult;
begin
  CheckResult := CheckForInjectionPatterns(AInput);
  Result := not CheckResult.IsSafe;
end;

function TGuard.Sanitize(const AInput: string): string;
begin
  Result := SanitizeInput(AInput);
end;

function TGuard.FilterSensitive(const AContent: string): string;
var
  Regex: TRegEx;
begin
  Result := AContent;
  
  for Regex in FSensitivePatterns do
  begin
    Result := Regex.Replace(Result, '[REDACTED]');
  end;
end;

function TGuard.DoHandleMessage(const AMessage: TUniFlowMessage): TUniFlowMessage;
var
  Input, Schema: TJSONObject;
  Content: string;
  ValidationResult: TJSONObject;
begin
  Result := nil;
  
  if AMessage.MsgType = 'guard.validate_input' then
  begin
    // 校验输入
    if AMessage.Payload.TryGetValue<TJSONObject>('input', Input) then
    begin
      AMessage.Payload.TryGetValue<TJSONObject>('schema', Schema);
      ValidationResult := ValidateInput(Input, Schema);
      
      Result := TResponseMessage.Create(AMessage);
      TResponseMessage(Result).Payload.Free;
      TResponseMessage(Result).Payload := ValidationResult;
      
      var IsValid: Boolean;
      if ValidationResult.TryGetValue<Boolean>('valid', IsValid) then
        TResponseMessage(Result).Success := IsValid;
    end;
  end
  else if AMessage.MsgType = 'guard.validate_output' then
  begin
    // 校验输出
    if AMessage.Payload.TryGetValue<TJSONObject>('output', Input) then
    begin
      AMessage.Payload.TryGetValue<TJSONObject>('schema', Schema);
      ValidationResult := ValidateOutput(Input, Schema);
      
      Result := TResponseMessage.Create(AMessage);
      TResponseMessage(Result).Payload.Free;
      TResponseMessage(Result).Payload := ValidationResult;
      TResponseMessage(Result).Success := True;
    end;
  end
  else if AMessage.MsgType = 'guard.check_security' then
  begin
    // 安全检查
    if AMessage.Payload.TryGetValue<string>('content', Content) then
    begin
      ValidationResult := CheckSecurity(Content);
      
      Result := TResponseMessage.Create(AMessage);
      TResponseMessage(Result).Payload.Free;
      TResponseMessage(Result).Payload := ValidationResult;
      
      var IsSafe: Boolean;
      if ValidationResult.TryGetValue<Boolean>('is_safe', IsSafe) then
        TResponseMessage(Result).Success := IsSafe;
    end;
  end
  else if AMessage.MsgType = 'guard.sanitize' then
  begin
    // 消毒
    if AMessage.Payload.TryGetValue<string>('content', Content) then
    begin
      ValidationResult := TJSONObject.Create;
      ValidationResult.AddPair('original', Content);
      ValidationResult.AddPair('sanitized', Sanitize(Content));
      ValidationResult.AddPair('filtered', FilterSensitive(Content));
      
      Result := TResponseMessage.Create(AMessage);
      TResponseMessage(Result).Payload.Free;
      TResponseMessage(Result).Payload := ValidationResult;
      TResponseMessage(Result).Success := True;
    end;
  end;
end;

function TGuard.CanHandle(const AMsgType: string): Boolean;
begin
  Result := AMsgType.StartsWith('guard.');
end;

end.
