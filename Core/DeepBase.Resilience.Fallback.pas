{ ============================================================================
  DeepBase.Resilience.Fallback - Fallback resilience policy
  Split from DeepBase.Resilience; use DeepBase.Resilience for compatibility.
  ============================================================================ }

unit DeepBase.Resilience.Fallback;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  // ============================================================================
  // Fallback Policy
  // ============================================================================
  
  TFallbackPolicy<T> = class
  private
    FFallbackValue: T;
    FFallbackFunc: TFunc<Exception, T>;
    FHandledExceptions: TList<TClass>;
  public
    constructor Create;
    destructor Destroy; override;
    
    // Configuration
    function Value(AValue: T): TFallbackPolicy<T>;
    function ValueFunc(AFunc: TFunc<Exception, T>): TFallbackPolicy<T>;
    function Handle<E: Exception>: TFallbackPolicy<T>;
    function HandleAll: TFallbackPolicy<T>;
    
    // Execute
    function Execute(Func: TFunc<T>): T;
  end;

implementation

// ============================================================================
// TFallbackPolicy<T>
// ============================================================================

constructor TFallbackPolicy<T>.Create;
begin
  inherited Create;
  FHandledExceptions := TList<TClass>.Create;
end;

destructor TFallbackPolicy<T>.Destroy;
begin
  FreeAndNil(FHandledExceptions);
  inherited;
end;

function TFallbackPolicy<T>.Value(AValue: T): TFallbackPolicy<T>;
begin
  FFallbackValue := AValue;
  FFallbackFunc := nil;
  Result := Self;
end;

function TFallbackPolicy<T>.ValueFunc(AFunc: TFunc<Exception, T>): TFallbackPolicy<T>;
begin
  FFallbackFunc := AFunc;
  Result := Self;
end;

function TFallbackPolicy<T>.Handle<E>: TFallbackPolicy<T>;
begin
  FHandledExceptions.Add(E);
  Result := Self;
end;

function TFallbackPolicy<T>.HandleAll: TFallbackPolicy<T>;
begin
  FHandledExceptions.Clear;
  FHandledExceptions.Add(Exception);
  Result := Self;
end;

function TFallbackPolicy<T>.Execute(Func: TFunc<T>): T;
var
  ExClass: TClass;
  ShouldFallback: Boolean;
begin
  try
    Result := Func;
  except
    on E: Exception do
    begin
      ShouldFallback := FHandledExceptions.Count = 0;
      
      if not ShouldFallback then
      begin
        for ExClass in FHandledExceptions do
        begin
          if E is ExClass then
          begin
            ShouldFallback := True;
            Break;
          end;
        end;
      end;
      
      if ShouldFallback then
      begin
        if Assigned(FFallbackFunc) then
          Result := FFallbackFunc(E)
        else
          Result := FFallbackValue;
      end
      else
        raise;
    end;
  end;
end;

end.
