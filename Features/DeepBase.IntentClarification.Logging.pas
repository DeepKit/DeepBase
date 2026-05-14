unit DeepBase.IntentClarification.Logging;

interface

uses
  DeepBase.Types;

const
  ltDebug = llDebug;
  ltInfo = llInfo;
  ltWarning = llWarn;
  ltError = llError;

procedure Log(ALevel: TLogLevel; const AMessage: string);

implementation

uses
  DeepBase.Logging;

procedure Log(ALevel: TLogLevel; const AMessage: string);
begin
  Logger.Log(AMessage, ALevel, 'IntentClarification');
end;

end.
