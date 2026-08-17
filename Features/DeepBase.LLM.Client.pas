unit DeepBase.LLM.Client;

/// <summary>
/// DeepBase LLM Client Interfaces
/// 消费程序 uses 此单元即可使用全部 LLM 能力
/// </summary>

interface

uses
  System.SysUtils,
  DeepBase.LLM.Types;

type
  /// <summary>
  /// Callback for image generation progress. Called with:
  ///   AProgress (0.0..1.0), AStatusText (human-readable), AIsComplete (final call).
  /// </summary>
  TImageProgressCallback = reference to procedure(
    AProgress: Double; const AStatusText: string; AIsComplete: Boolean);

  /// 消费程序接口 �?极简调用
  ILLMClient = interface
    ['{F2A1B3C4-D5E6-7890-ABCD-EF1234567890}']

    function Chat(const ATier: TModelTier; const AUserPrompt: string): TChatResult; overload;
    function Chat(const ATier: TModelTier; const ASystemPrompt, AUserPrompt: string): TChatResult; overload;

    function ChatWithHistory(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;

    /// <summary>
    /// Per-provider chat call (bypasses tier/priority routing).
    /// Routes directly to the named provider using AModelId, so multiple
    /// providers can coexist without one overwriting another's tier config
    /// (fixes DeepFrames TFailoverLLMProvider tier-override trap).
    /// Returns TChatResult with ErrorCode='NO_PROVIDER' if AProviderName
    /// is not registered.
    /// </summary>
    function ChatWithHistoryByProvider(const AProviderName, AModelId: string;
      const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;

    procedure ChatStream(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);

    function ChatVision(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string = ''): TChatResult;

    function GenerateImage(const APrompt: string;
      const ASize: string = '1024x1024'): TImageGenerationResult;

    /// <summary>
    /// Asynchronous image generation with progress and result callbacks.
    /// Returns immediately; AOnResult fires with the final result.
    /// </summary>
    procedure GenerateImageStream(const APrompt: string;
      const AOnProgress: TImageProgressCallback;
      const AOnResult: TProc<TImageGenerationResult>;
      const AOnError: TProc<string>;
      const ASize: string = '1024x1024');

    procedure ChatVisionStream(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);

    function GetModelForTier(const ATier: TModelTier): string;
    function CallCount: Integer;
    function LastDurationMs: Integer;
  end;

  /// 管理接口 �?配置 Providers �?Tiers
  ILLMAdmin = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567891}']

    procedure AddProvider(const AName, AEndpoint, AApiKey, AApiFormat: string;
      APriority: Integer = 0);
    procedure RemoveProvider(const AName: string);
    procedure SetProviderKey(const AName, AApiKey: string);

    procedure SetTierModels(const ATier: TModelTier; const AModels: TArray<string>);
    function GetTierModels(const ATier: TModelTier): TArray<string>;

    function GetProviders: TArray<TProviderConfig>;
    function GetAvailableModels(const AProviderName: string): TArray<string>;

    function TestConnection(const AProviderName, AModelId: string;
      out ADurationMs: Integer; out AErrorMsg: string): Boolean;

    function IsConfigured: Boolean;
    procedure Save;
    procedure Load;
  end;

implementation

end.
