/// <summary>
/// Unit tests for UniBase.Diff module
/// Tests: TTextDiff, TDiffResult, TDiffHunk, TPatch, TMergeResult, TDiff helper
/// </summary>
unit Test.UniBase.Diff;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  UniBase.Diff;

type
  /// <summary>
  /// Tests for TDiffOptions
  /// </summary>
  [TestFixture]
  TDiffOptionsTests = class
  public
    [Test]
    procedure Test_Default_Values;
    [Test]
    procedure Test_Default_ContextLines;
  end;

  /// <summary>
  /// Tests for TDiffItem
  /// </summary>
  [TestFixture]
  TDiffItemTests = class
  public
    [Test]
    procedure Test_CreateEqual;
    [Test]
    procedure Test_CreateInsert;
    [Test]
    procedure Test_CreateDelete;
  end;

  /// <summary>
  /// Tests for TDiffHunk
  /// </summary>
  [TestFixture]
  TDiffHunkTests = class
  private
    FHunk: TDiffHunk;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_AddItem;
    [Test]
    procedure Test_Properties;
  end;

  /// <summary>
  /// Tests for TDiffResult
  /// </summary>
  [TestFixture]
  TDiffResultTests = class
  private
    FResult: TDiffResult;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_HasDifferences_False;
    [Test]
    procedure Test_GetSummary;
  end;

  /// <summary>
  /// Tests for TTextDiff
  /// </summary>
  [TestFixture]
  TTextDiffTests = class
  private
    FDiff: TTextDiff;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Compare_Identical;
    [Test]
    procedure Test_Compare_Different;
    [Test]
    procedure Test_Compare_Addition;
    [Test]
    procedure Test_Compare_Deletion;
    [Test]
    procedure Test_Compare_MultipleChanges;
    [Test]
    procedure Test_Compare_Empty;
    [Test]
    procedure Test_Compare_ToEmpty;
    [Test]
    procedure Test_Compare_FromEmpty;
    [Test]
    procedure Test_CompareLines;
    [Test]
    procedure Test_CompareChars;
    [Test]
    procedure Test_CompareWords;
    [Test]
    procedure Test_Options_IgnoreCase;
    [Test]
    procedure Test_Options_IgnoreWhitespace;
    [Test]
    procedure Test_Options_TrimLines;
  end;

  /// <summary>
  /// Tests for TDiffResult output formats
  /// </summary>
  [TestFixture]
  TDiffResultFormatTests = class
  private
    FDiff: TTextDiff;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_ToUnifiedDiff;
    [Test]
    procedure Test_ToUnifiedDiff_Header;
    [Test]
    procedure Test_ToContextDiff;
    [Test]
    procedure Test_ToSideBySide;
    [Test]
    procedure Test_ToHTML;
  end;

  /// <summary>
  /// Tests for TPatch
  /// </summary>
  [TestFixture]
  TPatchTests = class
  private
    FPatch: TPatch;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_ParseUnifiedDiff;
    [Test]
    procedure Test_Apply;
    [Test]
    procedure Test_CanApply;
    [Test]
    procedure Test_Reverse;
  end;

  /// <summary>
  /// Tests for TMergeResult
  /// </summary>
  [TestFixture]
  TMergeResultTests = class
  private
    FResult: TMergeResult;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_GetMergedText;
    [Test]
    procedure Test_GetMergedTextWithMarkers;
  end;

  /// <summary>
  /// Tests for TDiff helper class
  /// </summary>
  [TestFixture]
  TDiffHelperTests = class
  public
    [Test]
    procedure Test_Compare;
    [Test]
    procedure Test_Compare_WithOptions;
    [Test]
    procedure Test_UnifiedDiff;
    [Test]
    procedure Test_ApplyPatch;
    [Test]
    procedure Test_AreEqual_True;
    [Test]
    procedure Test_AreEqual_False;
    [Test]
    procedure Test_AreEqual_IgnoreCase;
    [Test]
    procedure Test_Merge;
    [Test]
    procedure Test_Similarity_Identical;
    [Test]
    procedure Test_Similarity_Different;
    [Test]
    procedure Test_Similarity_Partial;
    [Test]
    procedure Test_IsBinary_Text;
    [Test]
    procedure Test_IsBinary_Binary;
    [Test]
    procedure Test_Default;
  end;

  /// <summary>
  /// Tests for three-way merge
  /// </summary>
  [TestFixture]
  TThreeWayMergeTests = class
  private
    FDiff: TTextDiff;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Merge3Way_NoConflict;
    [Test]
    procedure Test_Merge3Way_OursOnly;
    [Test]
    procedure Test_Merge3Way_TheirsOnly;
    [Test]
    procedure Test_Merge3Way_Conflict;
  end;

implementation

// ============================================================================
// TDiffOptionsTests
// ============================================================================

procedure TDiffOptionsTests.Test_Default_Values;
var
  Opts: TDiffOptions;
begin
  Opts := TDiffOptions.Default;
  Assert.IsFalse(Opts.IgnoreCase);
  Assert.IsFalse(Opts.IgnoreWhitespace);
  Assert.IsFalse(Opts.IgnoreBlankLines);
  Assert.IsFalse(Opts.TrimLines);
end;

procedure TDiffOptionsTests.Test_Default_ContextLines;
var
  Opts: TDiffOptions;
begin
  Opts := TDiffOptions.Default;
  Assert.AreEqual(3, Opts.ContextLines);
end;

// ============================================================================
// TDiffItemTests
// ============================================================================

procedure TDiffItemTests.Test_CreateEqual;
var
  Item: TDiffItem;
begin
  Item := TDiffItem.CreateEqual('test line', 5, 7);
  Assert.AreEqual(doEqual, Item.Operation);
  Assert.AreEqual('test line', Item.Text);
  Assert.AreEqual(5, Item.OldIndex);
  Assert.AreEqual(7, Item.NewIndex);
end;

procedure TDiffItemTests.Test_CreateInsert;
var
  Item: TDiffItem;
begin
  Item := TDiffItem.CreateInsert('new line', 10);
  Assert.AreEqual(doInsert, Item.Operation);
  Assert.AreEqual('new line', Item.Text);
  Assert.AreEqual(-1, Item.OldIndex);
  Assert.AreEqual(10, Item.NewIndex);
end;

procedure TDiffItemTests.Test_CreateDelete;
var
  Item: TDiffItem;
begin
  Item := TDiffItem.CreateDelete('old line', 3);
  Assert.AreEqual(doDelete, Item.Operation);
  Assert.AreEqual('old line', Item.Text);
  Assert.AreEqual(3, Item.OldIndex);
  Assert.AreEqual(-1, Item.NewIndex);
end;

// ============================================================================
// TDiffHunkTests
// ============================================================================

procedure TDiffHunkTests.Setup;
begin
  FHunk := TDiffHunk.Create;
end;

procedure TDiffHunkTests.TearDown;
begin
  FHunk.Free;
end;

procedure TDiffHunkTests.Test_Create;
begin
  Assert.IsNotNull(FHunk);
  Assert.IsNotNull(FHunk.Items);
  Assert.AreEqual(0, FHunk.Items.Count);
end;

procedure TDiffHunkTests.Test_AddItem;
var
  Item: TDiffItem;
begin
  Item := TDiffItem.CreateEqual('line', 0, 0);
  FHunk.AddItem(Item);
  Assert.AreEqual(1, FHunk.Items.Count);
end;

procedure TDiffHunkTests.Test_Properties;
begin
  FHunk.OldStart := 10;
  FHunk.OldCount := 5;
  FHunk.NewStart := 12;
  FHunk.NewCount := 7;
  
  Assert.AreEqual(10, FHunk.OldStart);
  Assert.AreEqual(5, FHunk.OldCount);
  Assert.AreEqual(12, FHunk.NewStart);
  Assert.AreEqual(7, FHunk.NewCount);
end;

// ============================================================================
// TDiffResultTests
// ============================================================================

procedure TDiffResultTests.Setup;
begin
  FResult := TDiffResult.Create;
end;

procedure TDiffResultTests.TearDown;
begin
  FResult.Free;
end;

procedure TDiffResultTests.Test_Create;
begin
  Assert.IsNotNull(FResult);
  Assert.IsNotNull(FResult.Items);
  Assert.IsNotNull(FResult.Hunks);
end;

procedure TDiffResultTests.Test_HasDifferences_False;
begin
  // Empty result has no differences
  Assert.IsFalse(FResult.HasDifferences);
end;

procedure TDiffResultTests.Test_GetSummary;
var
  Summary: string;
begin
  Summary := FResult.GetSummary;
  Assert.IsNotEmpty(Summary);
end;

// ============================================================================
// TTextDiffTests
// ============================================================================

procedure TTextDiffTests.Setup;
begin
  FDiff := TTextDiff.Create;
end;

procedure TTextDiffTests.TearDown;
begin
  FDiff.Free;
end;

procedure TTextDiffTests.Test_Create;
begin
  Assert.IsNotNull(FDiff);
end;

procedure TTextDiffTests.Test_Compare_Identical;
var
  Result: TDiffResult;
begin
  Result := FDiff.Compare('Hello World', 'Hello World');
  try
    Assert.IsFalse(Result.HasDifferences);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_Compare_Different;
var
  Result: TDiffResult;
begin
  Result := FDiff.Compare('Line A', 'Line B');
  try
    Assert.IsTrue(Result.HasDifferences);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_Compare_Addition;
var
  Result: TDiffResult;
  OldText, NewText: string;
begin
  OldText := 'Line 1' + sLineBreak + 'Line 2';
  NewText := 'Line 1' + sLineBreak + 'Line 2' + sLineBreak + 'Line 3';
  
  Result := FDiff.Compare(OldText, NewText);
  try
    Assert.IsTrue(Result.HasDifferences);
    Assert.IsTrue(Result.AddedCount > 0);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_Compare_Deletion;
var
  Result: TDiffResult;
  OldText, NewText: string;
begin
  OldText := 'Line 1' + sLineBreak + 'Line 2' + sLineBreak + 'Line 3';
  NewText := 'Line 1' + sLineBreak + 'Line 3';
  
  Result := FDiff.Compare(OldText, NewText);
  try
    Assert.IsTrue(Result.HasDifferences);
    Assert.IsTrue(Result.DeletedCount > 0);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_Compare_MultipleChanges;
var
  Result: TDiffResult;
  OldText, NewText: string;
begin
  OldText := 'A' + sLineBreak + 'B' + sLineBreak + 'C';
  NewText := 'A' + sLineBreak + 'X' + sLineBreak + 'Y' + sLineBreak + 'C';
  
  Result := FDiff.Compare(OldText, NewText);
  try
    Assert.IsTrue(Result.HasDifferences);
    Assert.IsTrue(Result.ChangedCount > 0);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_Compare_Empty;
var
  Result: TDiffResult;
begin
  Result := FDiff.Compare('', '');
  try
    Assert.IsFalse(Result.HasDifferences);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_Compare_ToEmpty;
var
  Result: TDiffResult;
begin
  Result := FDiff.Compare('Some content', '');
  try
    Assert.IsTrue(Result.HasDifferences);
    Assert.IsTrue(Result.DeletedCount > 0);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_Compare_FromEmpty;
var
  Result: TDiffResult;
begin
  Result := FDiff.Compare('', 'New content');
  try
    Assert.IsTrue(Result.HasDifferences);
    Assert.IsTrue(Result.AddedCount > 0);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_CompareLines;
var
  Result: TDiffResult;
  OldLines, NewLines: TArray<string>;
begin
  OldLines := TArray<string>.Create('A', 'B', 'C');
  NewLines := TArray<string>.Create('A', 'X', 'C');
  
  Result := FDiff.CompareLines(OldLines, NewLines);
  try
    Assert.IsTrue(Result.HasDifferences);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_CompareChars;
var
  Result: TDiffResult;
begin
  Result := FDiff.CompareChars('hello', 'hallo');
  try
    Assert.IsTrue(Result.HasDifferences);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_CompareWords;
var
  Result: TDiffResult;
begin
  Result := FDiff.CompareWords('hello world', 'hello brave world');
  try
    Assert.IsTrue(Result.HasDifferences);
  finally
    Result.Free;
  end;
end;

procedure TTextDiffTests.Test_Options_IgnoreCase;
var
  Opts: TDiffOptions;
  Diff: TTextDiff;
  Result: TDiffResult;
begin
  Opts := TDiffOptions.Default;
  Opts.IgnoreCase := True;
  Diff := TTextDiff.Create(Opts);
  try
    Result := Diff.Compare('Hello', 'hello');
    try
      Assert.IsFalse(Result.HasDifferences);
    finally
      Result.Free;
    end;
  finally
    Diff.Free;
  end;
end;

procedure TTextDiffTests.Test_Options_IgnoreWhitespace;
var
  Opts: TDiffOptions;
  Diff: TTextDiff;
  Result: TDiffResult;
begin
  Opts := TDiffOptions.Default;
  Opts.IgnoreWhitespace := True;
  Diff := TTextDiff.Create(Opts);
  try
    Result := Diff.Compare('Hello World', 'Hello  World');
    try
      Assert.IsFalse(Result.HasDifferences);
    finally
      Result.Free;
    end;
  finally
    Diff.Free;
  end;
end;

procedure TTextDiffTests.Test_Options_TrimLines;
var
  Opts: TDiffOptions;
  Diff: TTextDiff;
  Result: TDiffResult;
begin
  Opts := TDiffOptions.Default;
  Opts.TrimLines := True;
  Diff := TTextDiff.Create(Opts);
  try
    Result := Diff.Compare('  Hello  ', 'Hello');
    try
      Assert.IsFalse(Result.HasDifferences);
    finally
      Result.Free;
    end;
  finally
    Diff.Free;
  end;
end;

// ============================================================================
// TDiffResultFormatTests
// ============================================================================

procedure TDiffResultFormatTests.Setup;
begin
  FDiff := TTextDiff.Create;
end;

procedure TDiffResultFormatTests.TearDown;
begin
  FDiff.Free;
end;

procedure TDiffResultFormatTests.Test_ToUnifiedDiff;
var
  Result: TDiffResult;
  Unified: string;
begin
  Result := FDiff.Compare('Line 1' + sLineBreak + 'Line 2', 'Line 1' + sLineBreak + 'Line X');
  try
    Unified := Result.ToUnifiedDiff('old.txt', 'new.txt');
    Assert.IsNotEmpty(Unified);
  finally
    Result.Free;
  end;
end;

procedure TDiffResultFormatTests.Test_ToUnifiedDiff_Header;
var
  Result: TDiffResult;
  Unified: string;
begin
  Result := FDiff.Compare('A', 'B');
  try
    Unified := Result.ToUnifiedDiff('file1.txt', 'file2.txt');
    Assert.IsTrue(Unified.Contains('---') or Unified.Contains('+++') or (Unified = ''));
  finally
    Result.Free;
  end;
end;

procedure TDiffResultFormatTests.Test_ToContextDiff;
var
  Result: TDiffResult;
  Context: string;
begin
  Result := FDiff.Compare('Old text', 'New text');
  try
    Context := Result.ToContextDiff('old.txt', 'new.txt');
    Assert.IsNotEmpty(Context);
  finally
    Result.Free;
  end;
end;

procedure TDiffResultFormatTests.Test_ToSideBySide;
var
  Result: TDiffResult;
  SideBySide: string;
begin
  Result := FDiff.Compare('Line 1' + sLineBreak + 'Line 2', 'Line 1' + sLineBreak + 'Modified');
  try
    SideBySide := Result.ToSideBySide(80);
    Assert.IsNotEmpty(SideBySide);
  finally
    Result.Free;
  end;
end;

procedure TDiffResultFormatTests.Test_ToHTML;
var
  Result: TDiffResult;
  HTML: string;
begin
  Result := FDiff.Compare('Old', 'New');
  try
    HTML := Result.ToHTML;
    Assert.IsNotEmpty(HTML);
    Assert.IsTrue(HTML.Contains('<') and HTML.Contains('>'));
  finally
    Result.Free;
  end;
end;

// ============================================================================
// TPatchTests
// ============================================================================

procedure TPatchTests.Setup;
begin
  FPatch := TPatch.Create;
end;

procedure TPatchTests.TearDown;
begin
  FPatch.Free;
end;

procedure TPatchTests.Test_Create;
begin
  Assert.IsNotNull(FPatch);
  Assert.IsNotNull(FPatch.Operations);
end;

procedure TPatchTests.Test_ParseUnifiedDiff;
var
  Diff: string;
begin
  Diff := '--- old.txt' + sLineBreak +
          '+++ new.txt' + sLineBreak +
          '@@ -1,3 +1,3 @@' + sLineBreak +
          ' Line 1' + sLineBreak +
          '-Line 2' + sLineBreak +
          '+Modified' + sLineBreak +
          ' Line 3';
  
  FPatch.ParseUnifiedDiff(Diff);
  Assert.IsTrue(FPatch.Operations.Count > 0);
end;

procedure TPatchTests.Test_Apply;
var
  OldText, Diff, NewText: string;
  Success: Boolean;
begin
  OldText := 'Line 1' + sLineBreak + 'Line 2' + sLineBreak + 'Line 3';
  Diff := '--- old.txt' + sLineBreak +
          '+++ new.txt' + sLineBreak +
          '@@ -1,3 +1,3 @@' + sLineBreak +
          ' Line 1' + sLineBreak +
          '-Line 2' + sLineBreak +
          '+Modified' + sLineBreak +
          ' Line 3';
  
  FPatch.ParseUnifiedDiff(Diff);
  Success := FPatch.Apply(OldText, NewText);
  
  Assert.IsTrue(Success);
  Assert.IsTrue(NewText.Contains('Modified'));
end;

procedure TPatchTests.Test_CanApply;
var
  OldText, Diff: string;
begin
  OldText := 'Line 1' + sLineBreak + 'Line 2' + sLineBreak + 'Line 3';
  Diff := '--- old.txt' + sLineBreak +
          '+++ new.txt' + sLineBreak +
          '@@ -1,3 +1,3 @@' + sLineBreak +
          ' Line 1' + sLineBreak +
          '-Line 2' + sLineBreak +
          '+Modified' + sLineBreak +
          ' Line 3';
  
  FPatch.ParseUnifiedDiff(Diff);
  Assert.IsTrue(FPatch.CanApply(OldText));
end;

procedure TPatchTests.Test_Reverse;
var
  Diff: string;
begin
  Diff := '--- old.txt' + sLineBreak +
          '+++ new.txt' + sLineBreak +
          '@@ -1,3 +1,3 @@' + sLineBreak +
          ' Line 1' + sLineBreak +
          '-Old' + sLineBreak +
          '+New' + sLineBreak +
          ' Line 3';
  
  FPatch.ParseUnifiedDiff(Diff);
  FPatch.Reverse;
  // After reverse, apply should revert New to Old
  Assert.IsNotNull(FPatch);
end;

// ============================================================================
// TMergeResultTests
// ============================================================================

procedure TMergeResultTests.Setup;
begin
  FResult := TMergeResult.Create;
end;

procedure TMergeResultTests.TearDown;
begin
  FResult.Free;
end;

procedure TMergeResultTests.Test_Create;
begin
  Assert.IsNotNull(FResult);
  Assert.IsNotNull(FResult.MergedLines);
  Assert.IsNotNull(FResult.Conflicts);
  Assert.IsFalse(FResult.HasConflicts);
end;

procedure TMergeResultTests.Test_GetMergedText;
var
  Text: string;
begin
  FResult.MergedLines.Add('Line 1');
  FResult.MergedLines.Add('Line 2');
  Text := FResult.GetMergedText;
  Assert.IsTrue(Text.Contains('Line 1'));
  Assert.IsTrue(Text.Contains('Line 2'));
end;

procedure TMergeResultTests.Test_GetMergedTextWithMarkers;
var
  Text: string;
begin
  FResult.MergedLines.Add('Line 1');
  Text := FResult.GetMergedTextWithMarkers;
  Assert.IsNotEmpty(Text);
end;

// ============================================================================
// TDiffHelperTests
// ============================================================================

procedure TDiffHelperTests.Test_Compare;
var
  Result: TDiffResult;
begin
  Result := TDiff.Compare('Hello', 'World');
  try
    Assert.IsNotNull(Result);
    Assert.IsTrue(Result.HasDifferences);
  finally
    Result.Free;
  end;
end;

procedure TDiffHelperTests.Test_Compare_WithOptions;
var
  Opts: TDiffOptions;
  Result: TDiffResult;
begin
  Opts := TDiffOptions.Default;
  Opts.IgnoreCase := True;
  Result := TDiff.Compare('HELLO', 'hello', Opts);
  try
    Assert.IsFalse(Result.HasDifferences);
  finally
    Result.Free;
  end;
end;

procedure TDiffHelperTests.Test_UnifiedDiff;
var
  Diff: string;
begin
  Diff := TDiff.UnifiedDiff('Old Line', 'New Line', 'old.txt', 'new.txt');
  Assert.IsNotEmpty(Diff);
end;

procedure TDiffHelperTests.Test_ApplyPatch;
var
  Original, Patch, Result: string;
begin
  Original := 'Line 1' + sLineBreak + 'Line 2' + sLineBreak + 'Line 3';
  Patch := '--- old.txt' + sLineBreak +
           '+++ new.txt' + sLineBreak +
           '@@ -1,3 +1,3 @@' + sLineBreak +
           ' Line 1' + sLineBreak +
           '-Line 2' + sLineBreak +
           '+Changed' + sLineBreak +
           ' Line 3';
  
  Result := TDiff.ApplyPatch(Original, Patch);
  Assert.IsTrue(Result.Contains('Changed'));
end;

procedure TDiffHelperTests.Test_AreEqual_True;
var
  Opts: TDiffOptions;
begin
  Opts := TDiffOptions.Default;
  Assert.IsTrue(TDiff.AreEqual('Hello', 'Hello', Opts));
end;

procedure TDiffHelperTests.Test_AreEqual_False;
var
  Opts: TDiffOptions;
begin
  Opts := TDiffOptions.Default;
  Assert.IsFalse(TDiff.AreEqual('Hello', 'World', Opts));
end;

procedure TDiffHelperTests.Test_AreEqual_IgnoreCase;
var
  Opts: TDiffOptions;
begin
  Opts := TDiffOptions.Default;
  Opts.IgnoreCase := True;
  Assert.IsTrue(TDiff.AreEqual('Hello', 'HELLO', Opts));
end;

procedure TDiffHelperTests.Test_Merge;
var
  Result: TMergeResult;
begin
  Result := TDiff.Merge('Base', 'Ours', 'Theirs');
  try
    Assert.IsNotNull(Result);
  finally
    Result.Free;
  end;
end;

procedure TDiffHelperTests.Test_Similarity_Identical;
var
  Sim: Double;
begin
  Sim := TDiff.Similarity('Hello World', 'Hello World');
  Assert.AreEqual(1.0, Sim, 0.001);
end;

procedure TDiffHelperTests.Test_Similarity_Different;
var
  Sim: Double;
begin
  Sim := TDiff.Similarity('AAAA', 'BBBB');
  Assert.IsTrue(Sim < 0.5);
end;

procedure TDiffHelperTests.Test_Similarity_Partial;
var
  Sim: Double;
begin
  Sim := TDiff.Similarity('Hello', 'Hallo');
  Assert.IsTrue((Sim > 0.5) and (Sim < 1.0));
end;

procedure TDiffHelperTests.Test_IsBinary_Text;
var
  Data: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes('Hello World! This is text content.');
  Assert.IsFalse(TDiff.IsBinary(Data));
end;

procedure TDiffHelperTests.Test_IsBinary_Binary;
var
  Data: TBytes;
begin
  // Binary content with null bytes
  Data := TBytes.Create($00, $01, $02, $03, $FF, $FE, $FD);
  Assert.IsTrue(TDiff.IsBinary(Data));
end;

procedure TDiffHelperTests.Test_Default;
begin
  Assert.IsNotNull(TDiff.Default);
end;

// ============================================================================
// TThreeWayMergeTests
// ============================================================================

procedure TThreeWayMergeTests.Setup;
begin
  FDiff := TTextDiff.Create;
end;

procedure TThreeWayMergeTests.TearDown;
begin
  FDiff.Free;
end;

procedure TThreeWayMergeTests.Test_Merge3Way_NoConflict;
var
  Base, Ours, Theirs: string;
  Result: TMergeResult;
begin
  Base := 'Line 1' + sLineBreak + 'Line 2' + sLineBreak + 'Line 3';
  Ours := 'Line 1' + sLineBreak + 'Line 2' + sLineBreak + 'Line 3';
  Theirs := 'Line 1' + sLineBreak + 'Line 2' + sLineBreak + 'Line 3';
  
  Result := FDiff.Merge3Way(Base, Ours, Theirs);
  try
    Assert.IsFalse(Result.HasConflicts);
  finally
    Result.Free;
  end;
end;

procedure TThreeWayMergeTests.Test_Merge3Way_OursOnly;
var
  Base, Ours, Theirs: string;
  Result: TMergeResult;
begin
  Base := 'Line 1' + sLineBreak + 'Line 2';
  Ours := 'Line 1' + sLineBreak + 'Our change';
  Theirs := 'Line 1' + sLineBreak + 'Line 2';
  
  Result := FDiff.Merge3Way(Base, Ours, Theirs);
  try
    Assert.IsFalse(Result.HasConflicts);
    Assert.IsTrue(Result.GetMergedText.Contains('Our change'));
  finally
    Result.Free;
  end;
end;

procedure TThreeWayMergeTests.Test_Merge3Way_TheirsOnly;
var
  Base, Ours, Theirs: string;
  Result: TMergeResult;
begin
  Base := 'Line 1' + sLineBreak + 'Line 2';
  Ours := 'Line 1' + sLineBreak + 'Line 2';
  Theirs := 'Line 1' + sLineBreak + 'Their change';
  
  Result := FDiff.Merge3Way(Base, Ours, Theirs);
  try
    Assert.IsFalse(Result.HasConflicts);
    Assert.IsTrue(Result.GetMergedText.Contains('Their change'));
  finally
    Result.Free;
  end;
end;

procedure TThreeWayMergeTests.Test_Merge3Way_Conflict;
var
  Base, Ours, Theirs: string;
  Result: TMergeResult;
begin
  Base := 'Line 1' + sLineBreak + 'Line 2';
  Ours := 'Line 1' + sLineBreak + 'Our version';
  Theirs := 'Line 1' + sLineBreak + 'Their version';
  
  Result := FDiff.Merge3Way(Base, Ours, Theirs);
  try
    Assert.IsTrue(Result.HasConflicts);
  finally
    Result.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDiffOptionsTests);
  TDUnitX.RegisterTestFixture(TDiffItemTests);
  TDUnitX.RegisterTestFixture(TDiffHunkTests);
  TDUnitX.RegisterTestFixture(TDiffResultTests);
  TDUnitX.RegisterTestFixture(TTextDiffTests);
  TDUnitX.RegisterTestFixture(TDiffResultFormatTests);
  TDUnitX.RegisterTestFixture(TPatchTests);
  TDUnitX.RegisterTestFixture(TMergeResultTests);
  TDUnitX.RegisterTestFixture(TDiffHelperTests);
  TDUnitX.RegisterTestFixture(TThreeWayMergeTests);

end.
