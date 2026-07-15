{ ============================================================================
  DeepBase.StorageFactory - Generic connection-backed storage factory helper

  Version: 1.0
  Description: Eliminates boilerplate in modules that register a connection-
               backed storage factory.  Each instantiation of
               TConnectionStorageFactory<T> holds its own static factory
               lambda, so modules no longer need their own FConnectionStorage-
               Factory field, SetStorageFactory implementation, or
               CreateStorageFromConnection wrapper.
  Thread Safety: Factory registration is expected at startup (single-threaded).
                 Create is safe to call from any thread once registered.
  ============================================================================ }

unit DeepBase.StorageFactory;

interface

uses
  System.SysUtils,
  System.Types;

type
  /// <summary>
  ///   Generic helper that stores a <c>TFunc&lt;TObject, T&gt;</c> factory and
  ///   invokes it to create a storage interface from a connection object.
  /// </summary>
  /// <remarks>
  ///   Each concrete instantiation (e.g.
  ///   <c>TConnectionStorageFactory&lt;IConfigStorage&gt;</c>) maintains its
  ///   own independent static factory field, so modules do not need to
  ///   declare their own <c>FConnectionStorageFactory</c> class var.
  /// </remarks>
  TConnectionStorageFactory<T> = class
  private
    class var FFactory: TFunc<TObject, T>;
  public
    /// <summary>Register the factory lambda (nil to clear).</summary>
    class procedure SetFactory(const AFactory: TFunc<TObject, T>); static;

    /// <summary>
    ///   Create a storage instance from a connection object.
    ///   Returns <c>nil</c> when <paramref name="AConnection"/> is nil or no
    ///   factory has been registered.
    /// </summary>
    class function Create(AConnection: TObject): T; static;
  end;

  /// <summary>
  ///   Generic helper that stores a no-argument <c>TFunc&lt;T&gt;</c> factory.
  /// </summary>
  /// <remarks>
  ///   Used by modules that create storage without a connection object
  ///   (e.g. TAntiTamperServiceImpl).
  /// </remarks>
  TStorageFactory<T> = class
  private
    class var FFactory: TFunc<T>;
  public
    /// <summary>Register the factory lambda (nil to clear).</summary>
    class procedure SetFactory(const AFactory: TFunc<T>); static;

    /// <summary>
    ///   Create a storage instance.  Returns <c>nil</c> when no factory
    ///   has been registered.
    /// </summary>
    class function Create: T; static;
  end;

implementation

{ TConnectionStorageFactory<T> }

class procedure TConnectionStorageFactory<T>.SetFactory(
  const AFactory: TFunc<TObject, T>);
begin
  FFactory := AFactory;
end;

class function TConnectionStorageFactory<T>.Create(
  AConnection: TObject): T;
begin
  Result := Default(T);
  if Assigned(AConnection) and Assigned(FFactory) then
    Result := FFactory(AConnection);
end;

{ TStorageFactory<T> }

class procedure TStorageFactory<T>.SetFactory(const AFactory: TFunc<T>);
begin
  FFactory := AFactory;
end;

class function TStorageFactory<T>.Create: T;
begin
  if Assigned(FFactory) then
    Result := FFactory()
  else
    Result := Default(T);
end;

end.
