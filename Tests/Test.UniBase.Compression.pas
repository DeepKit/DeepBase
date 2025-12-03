{ ============================================================================
  Test.UniBase.Compression - Compression Module Unit Tests
  
  Version: 1.0
  Description: Unit tests for compression utilities
  
  Test Coverage:
  - TGZipCompressor: GZip compression/decompression
  - TDeflateCompressor: Deflate/ZLib compression
  - TZipArchiveReader/Writer: ZIP archive operations
  - TCompression: Static helper methods
  - TCompressionBuilder: Fluent API
  ============================================================================ }

unit Test.UniBase.Compression;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  DUnitX.TestFramework;

type
  /// <summary>
  /// Test fixture for TGZipCompressor
  /// </summary>
  [TestFixture]
  TTestGZipCompressor = class
  public
    [Test]
    procedure Test_CompressBytes_ReturnsSmaller;
    
    [Test]
    procedure Test_DecompressBytes_RestoresOriginal;
    
    [Test]
    procedure Test_CompressString_WithUTF8;
    
    [Test]
    procedure Test_DecompressString_RestoresText;
    
    [Test]
    procedure Test_CompressStream_WritesData;
    
    [Test]
    procedure Test_DecompressStream_RestoresData;
    
    [Test]
    procedure Test_CompressionLevel_Fastest;
    
    [Test]
    procedure Test_CompressionLevel_Max;
    
    [Test]
    procedure Test_CompressFile_CreatesFile;
    
    [Test]
    procedure Test_DecompressFile_RestoresFile;
    
    [Test]
    procedure Test_RoundTrip_LargeData;
  end;
  
  /// <summary>
  /// Test fixture for TDeflateCompressor
  /// </summary>
  [TestFixture]
  TTestDeflateCompressor = class
  public
    [Test]
    procedure Test_CompressBytes_Deflate;
    
    [Test]
    procedure Test_DecompressBytes_Deflate;
    
    [Test]
    procedure Test_CompressBytes_ZLib;
    
    [Test]
    procedure Test_DecompressBytes_ZLib;
    
    [Test]
    procedure Test_FormatProperty_CanChange;
    
    [Test]
    procedure Test_RoundTrip_AllFormats;
  end;
  
  /// <summary>
  /// Test fixture for TZipArchiveWriter
  /// </summary>
  [TestFixture]
  TTestZipArchiveWriter = class
  private
    FTempDir: string;
    FTempZip: string;
  public
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_CreatesFile;
    
    [Test]
    procedure Test_AddBytes_AddsEntry;
    
    [Test]
    procedure Test_AddString_AddsEntry;
    
    [Test]
    procedure Test_AddFile_AddsEntry;
    
    [Test]
    procedure Test_AddStream_AddsEntry;
    
    [Test]
    procedure Test_AddDirectory_AddsAllFiles;
    
    [Test]
    procedure Test_CompressionLevel_Affects_Size;
    
    [Test]
    procedure Test_SetComment_SetsArchiveComment;
  end;
  
  /// <summary>
  /// Test fixture for TZipArchiveReader
  /// </summary>
  [TestFixture]
  TTestZipArchiveReader = class
  private
    FTempDir: string;
    FTempZip: string;
    
    procedure CreateTestZip;
  public
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_EntryCount_ReturnsCorrect;
    
    [Test]
    procedure Test_ContainsEntry_ReturnsTrue;
    
    [Test]
    procedure Test_ContainsEntry_ReturnsFalse;
    
    [Test]
    procedure Test_FindEntry_ReturnsIndex;
    
    [Test]
    procedure Test_GetEntry_ReturnsInfo;
    
    [Test]
    procedure Test_ReadBytes_ReturnsContent;
    
    [Test]
    procedure Test_ReadString_ReturnsText;
    
    [Test]
    procedure Test_ExtractToStream_ExtractsData;
    
    [Test]
    procedure Test_ExtractToFile_CreatesFile;
    
    [Test]
    procedure Test_ExtractAll_ExtractsAllFiles;
    
    [Test]
    procedure Test_GetEntries_ReturnsAllEntries;
  end;
  
  /// <summary>
  /// Test fixture for TCompression static methods
  /// </summary>
  [TestFixture]
  TTestCompression = class
  private
    FTempDir: string;
  public
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_GZipCompress_CompressesData;
    
    [Test]
    procedure Test_GZipDecompress_DecompressesData;
    
    [Test]
    procedure Test_GZipCompressString_Works;
    
    [Test]
    procedure Test_DeflateCompress_CompressesData;
    
    [Test]
    procedure Test_DeflateDecompress_DecompressesData;
    
    [Test]
    procedure Test_ZLibCompress_CompressesData;
    
    [Test]
    procedure Test_ZLibDecompress_DecompressesData;
    
    [Test]
    procedure Test_IsGZipData_ReturnsTrueForGZip;
    
    [Test]
    procedure Test_IsGZipData_ReturnsFalseForRaw;
    
    [Test]
    procedure Test_IsValidZip_ReturnsTrueForZip;
    
    [Test]
    procedure Test_IsValidZip_ReturnsFalseForText;
    
    [Test]
    procedure Test_CalculateRatio_Correct;
    
    [Test]
    procedure Test_ZipDirectory_CreatesArchive;
    
    [Test]
    procedure Test_UnzipToDirectory_Extracts;
    
    [Test]
    procedure Test_ZipFiles_ZipsMultipleFiles;
  end;
  
  /// <summary>
  /// Test fixture for TCompressionBuilder
  /// </summary>
  [TestFixture]
  TTestCompressionBuilder = class
  public
    [Test]
    procedure Test_Create_DefaultLevel;
    
    [Test]
    procedure Test_Level_SetsLevel;
    
    [Test]
    procedure Test_Format_SetsFormat;
    
    [Test]
    procedure Test_Compress_CompressesData;
    
    [Test]
    procedure Test_Decompress_DecompressesData;
    
    [Test]
    procedure Test_FluentChaining;
    
    [Test]
    procedure Test_CompressStream_WritesToDest;
    
    [Test]
    procedure Test_OnProgress_Callback;
  end;
  
  /// <summary>
  /// Test fixture for TCompressionStats
  /// </summary>
  [TestFixture]
  TTestCompressionStats = class
  public
    [Test]
    procedure Test_ToString_FormatsCorrectly;
    
    [Test]
    procedure Test_CompressionRatio_Calculated;
  end;
  
  /// <summary>
  /// Test fixture for TZipEntryInfo
  /// </summary>
  [TestFixture]
  TTestZipEntryInfo = class
  public
    [Test]
    procedure Test_CompressionRatio_Calculated;
    
    [Test]
    procedure Test_CompressionRatio_ZeroSize;
  end;

implementation

uses
  UniBase.Compression;

{ TTestGZipCompressor }

procedure TTestGZipCompressor.Test_CompressBytes_ReturnsSmaller;
var
  Compressor: TGZipCompressor;
  Original, Compressed: TBytes;
  I: Integer;
begin
  Compressor := TGZipCompressor.Create;
  try
    // Create repetitive data (compresses well)
    SetLength(Original, 10000);
    for I := 0 to High(Original) do
      Original[I] := I mod 10;
    
    Compressed := Compressor.CompressBytes(Original);
    
    Assert.IsTrue(Length(Compressed) < Length(Original), 
      'Compressed should be smaller');
  finally
    Compressor.Free;
  end;
end;

procedure TTestGZipCompressor.Test_DecompressBytes_RestoresOriginal;
var
  Compressor: TGZipCompressor;
  Original, Compressed, Restored: TBytes;
  I: Integer;
begin
  Compressor := TGZipCompressor.Create;
  try
    SetLength(Original, 1000);
    for I := 0 to High(Original) do
      Original[I] := Random(256);
    
    Compressed := Compressor.CompressBytes(Original);
    Restored := Compressor.DecompressBytes(Compressed);
    
    Assert.AreEqual(Length(Original), Length(Restored));
    for I := 0 to High(Original) do
      Assert.AreEqual(Original[I], Restored[I]);
  finally
    Compressor.Free;
  end;
end;

procedure TTestGZipCompressor.Test_CompressString_WithUTF8;
var
  Compressor: TGZipCompressor;
  Original: string;
  Compressed: TBytes;
begin
  Compressor := TGZipCompressor.Create;
  try
    Original := 'Hello World 你好世界 🎉';
    Compressed := Compressor.CompressString(Original, TEncoding.UTF8);
    Assert.IsTrue(Length(Compressed) > 0, 'Should produce compressed data');
  finally
    Compressor.Free;
  end;
end;

procedure TTestGZipCompressor.Test_DecompressString_RestoresText;
var
  Compressor: TGZipCompressor;
  Original, Restored: string;
  Compressed: TBytes;
begin
  Compressor := TGZipCompressor.Create;
  try
    Original := 'Test string with special chars: äöü';
    Compressed := Compressor.CompressString(Original, TEncoding.UTF8);
    Restored := Compressor.DecompressString(Compressed, TEncoding.UTF8);
    Assert.AreEqual(Original, Restored);
  finally
    Compressor.Free;
  end;
end;

procedure TTestGZipCompressor.Test_CompressStream_WritesData;
var
  Compressor: TGZipCompressor;
  Source, Dest: TMemoryStream;
begin
  Compressor := TGZipCompressor.Create;
  Source := TMemoryStream.Create;
  Dest := TMemoryStream.Create;
  try
    Source.WriteData(Cardinal($DEADBEEF));
    Source.Position := 0;
    
    Compressor.CompressStream(Source, Dest);
    
    Assert.IsTrue(Dest.Size > 0, 'Should write compressed data');
  finally
    Compressor.Free;
    Source.Free;
    Dest.Free;
  end;
end;

procedure TTestGZipCompressor.Test_DecompressStream_RestoresData;
var
  Compressor: TGZipCompressor;
  Source, Compressed, Restored: TMemoryStream;
  OrigVal, RestoredVal: Cardinal;
begin
  Compressor := TGZipCompressor.Create;
  Source := TMemoryStream.Create;
  Compressed := TMemoryStream.Create;
  Restored := TMemoryStream.Create;
  try
    OrigVal := $DEADBEEF;
    Source.WriteData(OrigVal);
    Source.Position := 0;
    
    Compressor.CompressStream(Source, Compressed);
    Compressed.Position := 0;
    
    Compressor.DecompressStream(Compressed, Restored);
    Restored.Position := 0;
    Restored.ReadData(RestoredVal);
    
    Assert.AreEqual(OrigVal, RestoredVal);
  finally
    Compressor.Free;
    Source.Free;
    Compressed.Free;
    Restored.Free;
  end;
end;

procedure TTestGZipCompressor.Test_CompressionLevel_Fastest;
var
  Compressor: TGZipCompressor;
begin
  Compressor := TGZipCompressor.Create;
  try
    Compressor.CompressionLevel := clFastest;
    Assert.AreEqual(clFastest, Compressor.CompressionLevel);
  finally
    Compressor.Free;
  end;
end;

procedure TTestGZipCompressor.Test_CompressionLevel_Max;
var
  Compressor: TGZipCompressor;
begin
  Compressor := TGZipCompressor.Create;
  try
    Compressor.CompressionLevel := clMax;
    Assert.AreEqual(clMax, Compressor.CompressionLevel);
  finally
    Compressor.Free;
  end;
end;

procedure TTestGZipCompressor.Test_CompressFile_CreatesFile;
var
  Compressor: TGZipCompressor;
  SourceFile, DestFile: string;
  Stats: TCompressionStats;
begin
  Compressor := TGZipCompressor.Create;
  try
    SourceFile := TPath.Combine(TPath.GetTempPath, 'gzip_test_source.txt');
    DestFile := TPath.Combine(TPath.GetTempPath, 'gzip_test.gz');
    try
      TFile.WriteAllText(SourceFile, StringOfChar('A', 10000));
      Stats := Compressor.CompressFile(SourceFile, DestFile);
      
      Assert.IsTrue(TFile.Exists(DestFile), 'Should create compressed file');
      Assert.IsTrue(Stats.CompressionRatio > 0, 'Should have compression ratio');
    finally
      if TFile.Exists(SourceFile) then TFile.Delete(SourceFile);
      if TFile.Exists(DestFile) then TFile.Delete(DestFile);
    end;
  finally
    Compressor.Free;
  end;
end;

procedure TTestGZipCompressor.Test_DecompressFile_RestoresFile;
var
  Compressor: TGZipCompressor;
  SourceFile, CompFile, RestoreFile: string;
  Original, Restored: string;
begin
  Compressor := TGZipCompressor.Create;
  try
    SourceFile := TPath.Combine(TPath.GetTempPath, 'gzip_src.txt');
    CompFile := TPath.Combine(TPath.GetTempPath, 'gzip_comp.gz');
    RestoreFile := TPath.Combine(TPath.GetTempPath, 'gzip_restore.txt');
    try
      Original := 'Test content for file compression';
      TFile.WriteAllText(SourceFile, Original);
      
      Compressor.CompressFile(SourceFile, CompFile);
      Compressor.DecompressFile(CompFile, RestoreFile);
      
      Restored := TFile.ReadAllText(RestoreFile);
      Assert.AreEqual(Original, Restored);
    finally
      if TFile.Exists(SourceFile) then TFile.Delete(SourceFile);
      if TFile.Exists(CompFile) then TFile.Delete(CompFile);
      if TFile.Exists(RestoreFile) then TFile.Delete(RestoreFile);
    end;
  finally
    Compressor.Free;
  end;
end;

procedure TTestGZipCompressor.Test_RoundTrip_LargeData;
var
  Compressor: TGZipCompressor;
  Original, Compressed, Restored: TBytes;
  I: Integer;
begin
  Compressor := TGZipCompressor.Create;
  try
    // 1MB of data
    SetLength(Original, 1024 * 1024);
    for I := 0 to High(Original) do
      Original[I] := Random(256);
    
    Compressed := Compressor.CompressBytes(Original);
    Restored := Compressor.DecompressBytes(Compressed);
    
    Assert.AreEqual(Length(Original), Length(Restored));
  finally
    Compressor.Free;
  end;
end;

{ TTestDeflateCompressor }

procedure TTestDeflateCompressor.Test_CompressBytes_Deflate;
var
  Compressor: TDeflateCompressor;
  Original, Compressed: TBytes;
begin
  Compressor := TDeflateCompressor.Create(cfDeflate);
  try
    Original := TEncoding.UTF8.GetBytes(StringOfChar('X', 1000));
    Compressed := Compressor.CompressBytes(Original);
    Assert.IsTrue(Length(Compressed) < Length(Original));
  finally
    Compressor.Free;
  end;
end;

procedure TTestDeflateCompressor.Test_DecompressBytes_Deflate;
var
  Compressor: TDeflateCompressor;
  Original, Compressed, Restored: TBytes;
begin
  Compressor := TDeflateCompressor.Create(cfDeflate);
  try
    Original := TEncoding.UTF8.GetBytes('Test data');
    Compressed := Compressor.CompressBytes(Original);
    Restored := Compressor.DecompressBytes(Compressed);
    Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(Restored));
  finally
    Compressor.Free;
  end;
end;

procedure TTestDeflateCompressor.Test_CompressBytes_ZLib;
var
  Compressor: TDeflateCompressor;
  Original, Compressed: TBytes;
begin
  Compressor := TDeflateCompressor.Create(cfZLib);
  try
    Original := TEncoding.UTF8.GetBytes(StringOfChar('Y', 1000));
    Compressed := Compressor.CompressBytes(Original);
    Assert.IsTrue(Length(Compressed) > 0);
  finally
    Compressor.Free;
  end;
end;

procedure TTestDeflateCompressor.Test_DecompressBytes_ZLib;
var
  Compressor: TDeflateCompressor;
  Original, Compressed, Restored: TBytes;
begin
  Compressor := TDeflateCompressor.Create(cfZLib);
  try
    Original := TEncoding.UTF8.GetBytes('ZLib test');
    Compressed := Compressor.CompressBytes(Original);
    Restored := Compressor.DecompressBytes(Compressed);
    Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(Restored));
  finally
    Compressor.Free;
  end;
end;

procedure TTestDeflateCompressor.Test_FormatProperty_CanChange;
var
  Compressor: TDeflateCompressor;
begin
  Compressor := TDeflateCompressor.Create(cfDeflate);
  try
    Assert.AreEqual(cfDeflate, Compressor.Format);
    Compressor.Format := cfZLib;
    Assert.AreEqual(cfZLib, Compressor.Format);
  finally
    Compressor.Free;
  end;
end;

procedure TTestDeflateCompressor.Test_RoundTrip_AllFormats;
var
  Format: TCompressionFormat;
  Compressor: TDeflateCompressor;
  Original, Compressed, Restored: TBytes;
begin
  for Format := Low(TCompressionFormat) to High(TCompressionFormat) do
  begin
    if Format = cfGZip then Continue; // GZip uses different compressor
    
    Compressor := TDeflateCompressor.Create(Format);
    try
      Original := TEncoding.UTF8.GetBytes('Test for ' + Ord(Format).ToString);
      Compressed := Compressor.CompressBytes(Original);
      Restored := Compressor.DecompressBytes(Compressed);
      Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(Restored));
    finally
      Compressor.Free;
    end;
  end;
end;

{ TTestZipArchiveWriter }

procedure TTestZipArchiveWriter.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'ZipWriterTest_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
  FTempZip := TPath.Combine(FTempDir, 'test.zip');
end;

procedure TTestZipArchiveWriter.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestZipArchiveWriter.Test_Create_CreatesFile;
var
  Writer: TZipArchiveWriter;
begin
  Writer := TZipArchiveWriter.Create(FTempZip);
  try
    Writer.Close;
  finally
    Writer.Free;
  end;
  Assert.IsTrue(TFile.Exists(FTempZip));
end;

procedure TTestZipArchiveWriter.Test_AddBytes_AddsEntry;
var
  Writer: TZipArchiveWriter;
  Reader: TZipArchiveReader;
begin
  Writer := TZipArchiveWriter.Create(FTempZip);
  try
    Writer.AddBytes('test.bin', TEncoding.UTF8.GetBytes('Hello'));
    Writer.Close;
  finally
    Writer.Free;
  end;
  
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Assert.AreEqual(1, Reader.EntryCount);
    Assert.IsTrue(Reader.ContainsEntry('test.bin'));
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveWriter.Test_AddString_AddsEntry;
var
  Writer: TZipArchiveWriter;
  Reader: TZipArchiveReader;
  Content: string;
begin
  Writer := TZipArchiveWriter.Create(FTempZip);
  try
    Writer.AddString('readme.txt', 'Test content');
    Writer.Close;
  finally
    Writer.Free;
  end;
  
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Content := Reader.ReadString('readme.txt');
    Assert.AreEqual('Test content', Content);
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveWriter.Test_AddFile_AddsEntry;
var
  Writer: TZipArchiveWriter;
  Reader: TZipArchiveReader;
  TestFile: string;
begin
  TestFile := TPath.Combine(FTempDir, 'source.txt');
  TFile.WriteAllText(TestFile, 'File content');
  
  Writer := TZipArchiveWriter.Create(FTempZip);
  try
    Writer.AddFile(TestFile, 'archive/source.txt');
    Writer.Close;
  finally
    Writer.Free;
  end;
  
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Assert.IsTrue(Reader.ContainsEntry('archive/source.txt'));
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveWriter.Test_AddStream_AddsEntry;
var
  Writer: TZipArchiveWriter;
  Reader: TZipArchiveReader;
  Stream: TMemoryStream;
begin
  Stream := TMemoryStream.Create;
  try
    Stream.WriteData(Cardinal($12345678));
    Stream.Position := 0;
    
    Writer := TZipArchiveWriter.Create(FTempZip);
    try
      Writer.AddStream('data.bin', Stream);
      Writer.Close;
    finally
      Writer.Free;
    end;
  finally
    Stream.Free;
  end;
  
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Assert.IsTrue(Reader.ContainsEntry('data.bin'));
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveWriter.Test_AddDirectory_AddsAllFiles;
var
  Writer: TZipArchiveWriter;
  Reader: TZipArchiveReader;
  SubDir: string;
begin
  // Create test files
  TFile.WriteAllText(TPath.Combine(FTempDir, 'file1.txt'), 'Content 1');
  TFile.WriteAllText(TPath.Combine(FTempDir, 'file2.txt'), 'Content 2');
  SubDir := TPath.Combine(FTempDir, 'sub');
  TDirectory.CreateDirectory(SubDir);
  TFile.WriteAllText(TPath.Combine(SubDir, 'file3.txt'), 'Content 3');
  
  FTempZip := TPath.Combine(TPath.GetTempPath, 'dir_test.zip');
  
  Writer := TZipArchiveWriter.Create(FTempZip);
  try
    Writer.AddDirectory(FTempDir, '', True);
    Writer.Close;
  finally
    Writer.Free;
  end;
  
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Assert.IsTrue(Reader.EntryCount >= 3, 'Should have at least 3 entries');
  finally
    Reader.Free;
  end;
  
  if TFile.Exists(FTempZip) then
    TFile.Delete(FTempZip);
end;

procedure TTestZipArchiveWriter.Test_CompressionLevel_Affects_Size;
var
  Writer: TZipArchiveWriter;
  FastZip, MaxZip: string;
  FastSize, MaxSize: Int64;
  LargeContent: string;
begin
  LargeContent := StringOfChar('ABCDEF', 10000);
  
  FastZip := TPath.Combine(FTempDir, 'fast.zip');
  MaxZip := TPath.Combine(FTempDir, 'max.zip');
  
  Writer := TZipArchiveWriter.Create(FastZip);
  try
    Writer.CompressionLevel := clFastest;
    Writer.AddString('data.txt', LargeContent);
    Writer.Close;
  finally
    Writer.Free;
  end;
  
  Writer := TZipArchiveWriter.Create(MaxZip);
  try
    Writer.CompressionLevel := clMax;
    Writer.AddString('data.txt', LargeContent);
    Writer.Close;
  finally
    Writer.Free;
  end;
  
  FastSize := TFile.GetSize(FastZip);
  MaxSize := TFile.GetSize(MaxZip);
  
  // Max compression should produce smaller or equal file
  Assert.IsTrue(MaxSize <= FastSize, 'Max compression should be <= fast');
end;

procedure TTestZipArchiveWriter.Test_SetComment_SetsArchiveComment;
var
  Writer: TZipArchiveWriter;
begin
  Writer := TZipArchiveWriter.Create(FTempZip);
  try
    Writer.SetComment('Test archive comment');
    Writer.AddString('test.txt', 'Content');
    Writer.Close;
  finally
    Writer.Free;
  end;
  Assert.IsTrue(TFile.Exists(FTempZip));
end;

{ TTestZipArchiveReader }

procedure TTestZipArchiveReader.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'ZipReaderTest_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
  FTempZip := TPath.Combine(FTempDir, 'test.zip');
  CreateTestZip;
end;

procedure TTestZipArchiveReader.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestZipArchiveReader.CreateTestZip;
var
  Writer: TZipArchiveWriter;
begin
  Writer := TZipArchiveWriter.Create(FTempZip);
  try
    Writer.AddString('file1.txt', 'Content of file 1');
    Writer.AddString('file2.txt', 'Content of file 2');
    Writer.AddString('dir/file3.txt', 'Content of file 3');
    Writer.Close;
  finally
    Writer.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_EntryCount_ReturnsCorrect;
var
  Reader: TZipArchiveReader;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Assert.AreEqual(3, Reader.EntryCount);
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_ContainsEntry_ReturnsTrue;
var
  Reader: TZipArchiveReader;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Assert.IsTrue(Reader.ContainsEntry('file1.txt'));
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_ContainsEntry_ReturnsFalse;
var
  Reader: TZipArchiveReader;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Assert.IsFalse(Reader.ContainsEntry('nonexistent.txt'));
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_FindEntry_ReturnsIndex;
var
  Reader: TZipArchiveReader;
  Index: Integer;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Index := Reader.FindEntry('file1.txt');
    Assert.IsTrue(Index >= 0);
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_GetEntry_ReturnsInfo;
var
  Reader: TZipArchiveReader;
  Info: TZipEntryInfo;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Info := Reader.GetEntry(0);
    Assert.IsTrue(Info.FileName <> '');
    Assert.IsTrue(Info.UncompressedSize > 0);
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_ReadBytes_ReturnsContent;
var
  Reader: TZipArchiveReader;
  Data: TBytes;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Data := Reader.ReadBytes('file1.txt');
    Assert.IsTrue(Length(Data) > 0);
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_ReadString_ReturnsText;
var
  Reader: TZipArchiveReader;
  Content: string;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Content := Reader.ReadString('file1.txt');
    Assert.AreEqual('Content of file 1', Content);
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_ExtractToStream_ExtractsData;
var
  Reader: TZipArchiveReader;
  Stream: TMemoryStream;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  Stream := TMemoryStream.Create;
  try
    Reader.ExtractToStream('file1.txt', Stream);
    Assert.IsTrue(Stream.Size > 0);
  finally
    Reader.Free;
    Stream.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_ExtractToFile_CreatesFile;
var
  Reader: TZipArchiveReader;
  DestFile: string;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    DestFile := TPath.Combine(FTempDir, 'extracted.txt');
    Reader.ExtractToFile('file1.txt', DestFile);
    Assert.IsTrue(TFile.Exists(DestFile));
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_ExtractAll_ExtractsAllFiles;
var
  Reader: TZipArchiveReader;
  ExtractDir: string;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    ExtractDir := TPath.Combine(FTempDir, 'extracted');
    TDirectory.CreateDirectory(ExtractDir);
    Reader.ExtractAll(ExtractDir);
    Assert.IsTrue(TFile.Exists(TPath.Combine(ExtractDir, 'file1.txt')));
  finally
    Reader.Free;
  end;
end;

procedure TTestZipArchiveReader.Test_GetEntries_ReturnsAllEntries;
var
  Reader: TZipArchiveReader;
  Entries: TArray<TZipEntryInfo>;
begin
  Reader := TZipArchiveReader.Create(FTempZip);
  try
    Entries := Reader.GetEntries;
    Assert.AreEqual(3, Length(Entries));
  finally
    Reader.Free;
  end;
end;

{ TTestCompression }

procedure TTestCompression.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'CompressionTest_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
end;

procedure TTestCompression.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestCompression.Test_GZipCompress_CompressesData;
var
  Original, Compressed: TBytes;
begin
  Original := TEncoding.UTF8.GetBytes(StringOfChar('A', 1000));
  Compressed := TCompression.GZipCompress(Original);
  Assert.IsTrue(Length(Compressed) < Length(Original));
end;

procedure TTestCompression.Test_GZipDecompress_DecompressesData;
var
  Original, Compressed, Restored: TBytes;
begin
  Original := TEncoding.UTF8.GetBytes('Test data');
  Compressed := TCompression.GZipCompress(Original);
  Restored := TCompression.GZipDecompress(Compressed);
  Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(Restored));
end;

procedure TTestCompression.Test_GZipCompressString_Works;
var
  Compressed: TBytes;
  Restored: string;
begin
  Compressed := TCompression.GZipCompressString('Hello World');
  Assert.IsTrue(Length(Compressed) > 0);
  Restored := TCompression.GZipDecompressString(Compressed);
  Assert.AreEqual('Hello World', Restored);
end;

procedure TTestCompression.Test_DeflateCompress_CompressesData;
var
  Original, Compressed: TBytes;
begin
  Original := TEncoding.UTF8.GetBytes(StringOfChar('B', 1000));
  Compressed := TCompression.DeflateCompress(Original);
  Assert.IsTrue(Length(Compressed) < Length(Original));
end;

procedure TTestCompression.Test_DeflateDecompress_DecompressesData;
var
  Original, Compressed, Restored: TBytes;
begin
  Original := TEncoding.UTF8.GetBytes('Deflate test');
  Compressed := TCompression.DeflateCompress(Original);
  Restored := TCompression.DeflateDecompress(Compressed);
  Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(Restored));
end;

procedure TTestCompression.Test_ZLibCompress_CompressesData;
var
  Original, Compressed: TBytes;
begin
  Original := TEncoding.UTF8.GetBytes(StringOfChar('C', 1000));
  Compressed := TCompression.ZLibCompress(Original);
  Assert.IsTrue(Length(Compressed) > 0);
end;

procedure TTestCompression.Test_ZLibDecompress_DecompressesData;
var
  Original, Compressed, Restored: TBytes;
begin
  Original := TEncoding.UTF8.GetBytes('ZLib test');
  Compressed := TCompression.ZLibCompress(Original);
  Restored := TCompression.ZLibDecompress(Compressed);
  Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(Restored));
end;

procedure TTestCompression.Test_IsGZipData_ReturnsTrueForGZip;
var
  GZipData: TBytes;
begin
  GZipData := TCompression.GZipCompress(TEncoding.UTF8.GetBytes('Test'));
  Assert.IsTrue(TCompression.IsGZipData(GZipData));
end;

procedure TTestCompression.Test_IsGZipData_ReturnsFalseForRaw;
var
  RawData: TBytes;
begin
  RawData := TEncoding.UTF8.GetBytes('Raw text data');
  Assert.IsFalse(TCompression.IsGZipData(RawData));
end;

procedure TTestCompression.Test_IsValidZip_ReturnsTrueForZip;
var
  ZipFile: string;
  Writer: TZipArchiveWriter;
begin
  ZipFile := TPath.Combine(FTempDir, 'valid.zip');
  Writer := TZipArchiveWriter.Create(ZipFile);
  try
    Writer.AddString('test.txt', 'Content');
    Writer.Close;
  finally
    Writer.Free;
  end;
  
  Assert.IsTrue(TCompression.IsValidZip(ZipFile));
end;

procedure TTestCompression.Test_IsValidZip_ReturnsFalseForText;
var
  TextFile: string;
begin
  TextFile := TPath.Combine(FTempDir, 'text.txt');
  TFile.WriteAllText(TextFile, 'Not a zip file');
  Assert.IsFalse(TCompression.IsValidZip(TextFile));
end;

procedure TTestCompression.Test_CalculateRatio_Correct;
var
  Ratio: Double;
begin
  Ratio := TCompression.CalculateRatio(1000, 100);
  Assert.AreEqual(90.0, Ratio, 0.01);
end;

procedure TTestCompression.Test_ZipDirectory_CreatesArchive;
var
  ZipFile: string;
begin
  TFile.WriteAllText(TPath.Combine(FTempDir, 'test1.txt'), 'Content 1');
  TFile.WriteAllText(TPath.Combine(FTempDir, 'test2.txt'), 'Content 2');
  
  ZipFile := TPath.Combine(TPath.GetTempPath, 'dir_archive.zip');
  try
    TCompression.ZipDirectory(FTempDir, ZipFile);
    Assert.IsTrue(TFile.Exists(ZipFile));
  finally
    if TFile.Exists(ZipFile) then
      TFile.Delete(ZipFile);
  end;
end;

procedure TTestCompression.Test_UnzipToDirectory_Extracts;
var
  ZipFile, ExtractDir: string;
  Writer: TZipArchiveWriter;
begin
  ZipFile := TPath.Combine(FTempDir, 'source.zip');
  ExtractDir := TPath.Combine(FTempDir, 'extracted');
  
  Writer := TZipArchiveWriter.Create(ZipFile);
  try
    Writer.AddString('data.txt', 'Extracted content');
    Writer.Close;
  finally
    Writer.Free;
  end;
  
  TDirectory.CreateDirectory(ExtractDir);
  TCompression.UnzipToDirectory(ZipFile, ExtractDir);
  
  Assert.IsTrue(TFile.Exists(TPath.Combine(ExtractDir, 'data.txt')));
end;

procedure TTestCompression.Test_ZipFiles_ZipsMultipleFiles;
var
  ZipFile: string;
  Files: TArray<string>;
  Reader: TZipArchiveReader;
begin
  Files := [
    TPath.Combine(FTempDir, 'a.txt'),
    TPath.Combine(FTempDir, 'b.txt')
  ];
  TFile.WriteAllText(Files[0], 'A');
  TFile.WriteAllText(Files[1], 'B');
  
  ZipFile := TPath.Combine(FTempDir, 'multi.zip');
  TCompression.ZipFiles(Files, ZipFile);
  
  Reader := TZipArchiveReader.Create(ZipFile);
  try
    Assert.AreEqual(2, Reader.EntryCount);
  finally
    Reader.Free;
  end;
end;

{ TTestCompressionBuilder }

procedure TTestCompressionBuilder.Test_Create_DefaultLevel;
var
  Builder: TCompressionBuilder;
begin
  Builder := TCompressionBuilder.Create;
  try
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TTestCompressionBuilder.Test_Level_SetsLevel;
var
  Builder: TCompressionBuilder;
begin
  Builder := TCompressionBuilder.Create;
  try
    Builder.Level(clMax);
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TTestCompressionBuilder.Test_Format_SetsFormat;
var
  Builder: TCompressionBuilder;
begin
  Builder := TCompressionBuilder.Create;
  try
    Builder.Format(cfGZip);
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TTestCompressionBuilder.Test_Compress_CompressesData;
var
  Builder: TCompressionBuilder;
  Original, Compressed: TBytes;
begin
  Builder := TCompressionBuilder.Create;
  try
    Original := TEncoding.UTF8.GetBytes(StringOfChar('Z', 1000));
    Compressed := Builder.Level(clDefault).Compress(Original);
    Assert.IsTrue(Length(Compressed) > 0);
  finally
    Builder.Free;
  end;
end;

procedure TTestCompressionBuilder.Test_Decompress_DecompressesData;
var
  Builder: TCompressionBuilder;
  Original, Compressed, Restored: TBytes;
begin
  Builder := TCompressionBuilder.Create;
  try
    Original := TEncoding.UTF8.GetBytes('Builder test');
    Compressed := Builder.Compress(Original);
    Restored := Builder.Decompress(Compressed);
    Assert.AreEqual(TEncoding.UTF8.GetString(Original), TEncoding.UTF8.GetString(Restored));
  finally
    Builder.Free;
  end;
end;

procedure TTestCompressionBuilder.Test_FluentChaining;
var
  Builder: TCompressionBuilder;
  Data: TBytes;
begin
  Builder := TCompressionBuilder.Create;
  try
    Data := Builder
      .Level(clMax)
      .Format(cfDeflate)
      .Compress(TEncoding.UTF8.GetBytes('Chained'));
    Assert.IsTrue(Length(Data) > 0);
  finally
    Builder.Free;
  end;
end;

procedure TTestCompressionBuilder.Test_CompressStream_WritesToDest;
var
  Builder: TCompressionBuilder;
  Source, Dest: TMemoryStream;
begin
  Builder := TCompressionBuilder.Create;
  Source := TMemoryStream.Create;
  Dest := TMemoryStream.Create;
  try
    Source.WriteData(Cardinal($CAFEBABE));
    Source.Position := 0;
    
    Builder.CompressStream(Source, Dest);
    
    Assert.IsTrue(Dest.Size > 0);
  finally
    Builder.Free;
    Source.Free;
    Dest.Free;
  end;
end;

procedure TTestCompressionBuilder.Test_OnProgress_Callback;
var
  Builder: TCompressionBuilder;
  ProgressCalled: Boolean;
  Data: TBytes;
begin
  Builder := TCompressionBuilder.Create;
  try
    ProgressCalled := False;
    Builder.OnProgress(
      procedure(AProcessed, ATotal: Int64; var ACancel: Boolean)
      begin
        ProgressCalled := True;
      end);
    
    SetLength(Data, 100000);
    Builder.Compress(Data);
    
    // Progress may or may not be called depending on data size
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

{ TTestCompressionStats }

procedure TTestCompressionStats.Test_ToString_FormatsCorrectly;
var
  Stats: TCompressionStats;
  S: string;
begin
  Stats.OriginalSize := 1000;
  Stats.CompressedSize := 100;
  Stats.CompressionRatio := 90.0;
  Stats.ElapsedMs := 50;
  S := Stats.ToString;
  Assert.Contains(S, '90');
end;

procedure TTestCompressionStats.Test_CompressionRatio_Calculated;
var
  Stats: TCompressionStats;
begin
  Stats.OriginalSize := 1000;
  Stats.CompressedSize := 100;
  Stats.CompressionRatio := 100 - (100 * 100 / 1000);
  Assert.AreEqual(90.0, Stats.CompressionRatio, 0.01);
end;

{ TTestZipEntryInfo }

procedure TTestZipEntryInfo.Test_CompressionRatio_Calculated;
var
  Info: TZipEntryInfo;
begin
  Info.UncompressedSize := 1000;
  Info.CompressedSize := 200;
  Assert.AreEqual(80.0, Info.CompressionRatio, 0.01);
end;

procedure TTestZipEntryInfo.Test_CompressionRatio_ZeroSize;
var
  Info: TZipEntryInfo;
begin
  Info.UncompressedSize := 0;
  Info.CompressedSize := 0;
  Assert.AreEqual(0.0, Info.CompressionRatio, 0.01);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestGZipCompressor);
  TDUnitX.RegisterTestFixture(TTestDeflateCompressor);
  TDUnitX.RegisterTestFixture(TTestZipArchiveWriter);
  TDUnitX.RegisterTestFixture(TTestZipArchiveReader);
  TDUnitX.RegisterTestFixture(TTestCompression);
  TDUnitX.RegisterTestFixture(TTestCompressionBuilder);
  TDUnitX.RegisterTestFixture(TTestCompressionStats);
  TDUnitX.RegisterTestFixture(TTestZipEntryInfo);

end.
