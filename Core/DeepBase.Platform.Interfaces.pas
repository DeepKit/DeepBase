{ ============================================================================
  DeepBase.Platform.Interfaces
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : UI-framework-agnostic service contracts for platform
                capabilities that live in DeepBaseFMX / DeepBaseVCL, plus
                a simple function-reference registration point so the
                concrete platform implementation can be swapped for tests.

                Four permission outcomes are exposed:
                  prGranted        — permission held
                  prDenied         — explicitly denied or policy-forbidden
                  prUnsupported    — permission key not recognised on this
                                     platform
                  prRequestIssued  — async request dispatched to user;
                                     the registered callback fires once
                                     with prGranted / prDenied

                Thread safety: all Set*/Get* calls go through a
                TCriticalSection; the delegates themselves must be safe
                to call from any thread (the default FMX implementation
                serialises onto the platform thread where required).
  ============================================================================ }

unit DeepBase.Platform.Interfaces;

interface

uses
  System.SysUtils;

type
  TPermissionResult = (prGranted, prDenied, prUnsupported, prRequestIssued);

  /// <summary>Callback invoked once when an asynchronous permission
  /// request resolves. AResult is prGranted or prDenied.</summary>
  TPermissionCallback = reference to procedure(const APermission: string;
    AResult: TPermissionResult);

  /// <summary>Non-blocking permission check. Must return prUnsupported
  /// if the permission key is not recognised on the current platform.</summary>
  TPermissionCheckFunc = reference to function(
    const APermission: string): TPermissionResult;

  /// <summary>Issue a (possibly async) permission request. Return value
  /// semantics match TPermissionResult; if prRequestIssued, ACallback must
  /// be invoked exactly once.</summary>
  TPermissionRequestFunc = reference to function(const APermission: string;
    const ACallback: TPermissionCallback): TPermissionResult;

  /// <summary>Share text via the platform share sheet. Returns True iff
  /// the share UI was presented or the fallback succeeded.</summary>
  TShareTextFunc = reference to function(const AText, ASubject: string): Boolean;

  /// <summary>Share a file by URI. Returns True iff the share UI was
  /// presented.</summary>
  TShareFileFunc = reference to function(const AFilePath: string): Boolean;

/// <summary>Install (or replace) the global permission check delegate.
/// Pass nil to unregister.</summary>
procedure SetPermissionCheck(const AFunc: TPermissionCheckFunc);
/// <summary>Install (or replace) the global permission request delegate.
/// Pass nil to unregister.</summary>
procedure SetPermissionRequest(const AFunc: TPermissionRequestFunc);
/// <summary>Install (or replace) the global ShareText delegate.
/// Pass nil to unregister.</summary>
procedure SetShareText(const AFunc: TShareTextFunc);
/// <summary>Install (or replace) the global ShareFile delegate.
/// Pass nil to unregister.</summary>
procedure SetShareFile(const AFunc: TShareFileFunc);

function GetPermissionCheck: TPermissionCheckFunc;
function GetPermissionRequest: TPermissionRequestFunc;
function GetShareText: TShareTextFunc;
function GetShareFile: TShareFileFunc;

implementation

uses
  System.SyncObjs;

var
  GServiceLock: TCriticalSection;
  GPermissionCheck: TPermissionCheckFunc;
  GPermissionRequest: TPermissionRequestFunc;
  GShareText: TShareTextFunc;
  GShareFile: TShareFileFunc;

procedure SetPermissionCheck(const AFunc: TPermissionCheckFunc);
begin
  GServiceLock.Enter;
  try
    GPermissionCheck := AFunc;
  finally
    GServiceLock.Leave;
  end;
end;

procedure SetPermissionRequest(const AFunc: TPermissionRequestFunc);
begin
  GServiceLock.Enter;
  try
    GPermissionRequest := AFunc;
  finally
    GServiceLock.Leave;
  end;
end;

procedure SetShareText(const AFunc: TShareTextFunc);
begin
  GServiceLock.Enter;
  try
    GShareText := AFunc;
  finally
    GServiceLock.Leave;
  end;
end;

procedure SetShareFile(const AFunc: TShareFileFunc);
begin
  GServiceLock.Enter;
  try
    GShareFile := AFunc;
  finally
    GServiceLock.Leave;
  end;
end;

function GetPermissionCheck: TPermissionCheckFunc;
begin
  GServiceLock.Enter;
  try
    Result := GPermissionCheck;
  finally
    GServiceLock.Leave;
  end;
end;

function GetPermissionRequest: TPermissionRequestFunc;
begin
  GServiceLock.Enter;
  try
    Result := GPermissionRequest;
  finally
    GServiceLock.Leave;
  end;
end;

function GetShareText: TShareTextFunc;
begin
  GServiceLock.Enter;
  try
    Result := GShareText;
  finally
    GServiceLock.Leave;
  end;
end;

function GetShareFile: TShareFileFunc;
begin
  GServiceLock.Enter;
  try
    Result := GShareFile;
  finally
    GServiceLock.Leave;
  end;
end;

initialization
  GServiceLock := TCriticalSection.Create;

finalization
  SetPermissionCheck(nil);
  SetPermissionRequest(nil);
  SetShareText(nil);
  SetShareFile(nil);
  FreeAndNil(GServiceLock);

end.
