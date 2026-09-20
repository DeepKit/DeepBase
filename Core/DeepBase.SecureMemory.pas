unit DeepBase.SecureMemory;

{*******************************************************************************
  DeepBase SecureMemory - SSOT for wiping sensitive material from memory.

  Every unit that handles key material, master secrets or decrypted plaintext
  depends on this unit instead of carrying its own zeroing helper.

  Author: DeepBase Team
  Created: 2026-09-20
*******************************************************************************}

interface

uses
  System.SysUtils;

/// <summary>Overwrite a dynamic array with zeroes without letting the compiler elide the write.</summary>
procedure SecureZeroMemory(var Data: TBytes); overload;

/// <summary>Overwrite a string buffer with zeroes without letting the compiler elide the write.</summary>
procedure SecureZeroMemory(var Data: string); overload;

/// <summary>Zero a byte array and release its storage.</summary>
procedure SecureClearBytes(var Data: TBytes);

/// <summary>Zero an arbitrary buffer.</summary>
procedure SecureZeroBuffer(Ptr: Pointer; Count: NativeUInt);

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;

type
  TSecureZeroProc = function(ptr: Pointer; cnt: NativeUInt): Pointer; stdcall;

function ResolveSecureZeroProc: Pointer;
var
  LModule: HMODULE;
begin
  Result := nil;

  // Some Windows builds do not export RtlSecureZeroMemory from kernel32.
  // Resolve at runtime to avoid load-time STATUS_ENTRYPOINT_NOT_FOUND.
  LModule := GetModuleHandle('kernel32.dll');
  if LModule <> 0 then
    Result := GetProcAddress(LModule, 'RtlSecureZeroMemory');

  if Result = nil then
  begin
    LModule := GetModuleHandle('ntdll.dll');
    if LModule <> 0 then
      Result := GetProcAddress(LModule, 'RtlZeroMemory');
  end;
end;
{$ENDIF}

procedure SecureZeroBuffer(Ptr: Pointer; Count: NativeUInt);
{$IFDEF MSWINDOWS}
var
  LProc: Pointer;
{$ENDIF}
begin
  if (Ptr = nil) or (Count = 0) then
    Exit;

  {$IFDEF MSWINDOWS}
  LProc := ResolveSecureZeroProc;
  if LProc <> nil then
    TSecureZeroProc(LProc)(Ptr, Count)
  else
    FillChar(Ptr^, Count, 0);
  {$ELSE}
  FillChar(Ptr^, Count, 0);
  {$ENDIF}
end;

procedure SecureZeroMemory(var Data: TBytes);
begin
  if Length(Data) = 0 then
    Exit;
  SecureZeroBuffer(@Data[0], Length(Data));
end;

procedure SecureZeroMemory(var Data: string);
begin
  if Length(Data) = 0 then
    Exit;
  UniqueString(Data);
  SecureZeroBuffer(PChar(Data), Length(Data) * SizeOf(Char));
end;

procedure SecureClearBytes(var Data: TBytes);
begin
  SecureZeroMemory(Data);
  SetLength(Data, 0);
end;

end.
