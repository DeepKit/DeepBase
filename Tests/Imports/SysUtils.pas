unit SysUtils;
// Shim for Delphi 12: onnxruntime.pas uses 'SysUtils' (old-style unit name).
// Re-export everything from System.SysUtils + System.Classes for TFileName.
interface

uses
  System.SysUtils,
  System.Classes;

implementation

end.
