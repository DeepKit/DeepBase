{ ============================================================================
  Test.DeepBase.TemplateElseBranch - A2-09 regression

  RenderIf else-side defects pinned fixed:
  - multiple else content nodes must all render (old code overwrote Result per
    node, keeping only the last one);
  - when nothing matches (or else renders empty), the whole ElseBranch must
    not be re-rendered (old trailing `if Result = ''` pass leaked unmatched
    elseif subtrees into the output);
  - first matching elseif wins and excludes later content.
  ============================================================================ }

unit Test.DeepBase.TemplateElseBranch;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Template;

type
  [TestFixture]
  TTestTemplateElseBranchA209 = class
  private
    FEngine: TTemplateEngine;
    FContext: TTemplateContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Else_MultipleNodes_AllRendered;

    [Test]
    procedure Test_ElseIfAllFalse_EmptyElse_MustNotReRenderBranch;

    [Test]
    procedure Test_ElseIf_FirstMatchWins;

    [Test]
    procedure Test_ElseIfAllFalse_FallbackElseRendered;

    [Test]
    procedure Test_IfTrue_OnlyThenBranch;

    [Test]
    procedure Test_EmptyElse_NoOutput;
  end;

implementation

{ TTestTemplateElseBranchA209 }

procedure TTestTemplateElseBranchA209.Setup;
begin
  FEngine := TTemplateEngine.Create;
  FContext := TTemplateContext.Create;
end;

procedure TTestTemplateElseBranchA209.TearDown;
begin
  FContext.Free;
  FEngine.Free;
end;

procedure TTestTemplateElseBranchA209.Test_Else_MultipleNodes_AllRendered;
begin
  // Else content is three nodes (text/variable/text); old code kept only the
  // last node ("two").
  FContext.Add('show', False);
  FContext.Add('sep', '-');
  Assert.AreEqual('one-two',
    FEngine.Render('{{#if show}}yes{{else}}one{{sep}}two{{/if}}', FContext));
end;

procedure TTestTemplateElseBranchA209.Test_ElseIfAllFalse_EmptyElse_MustNotReRenderBranch;
begin
  // Old code: else content renders empty -> trailing pass re-rendered the
  // whole ElseBranch, leaking the unmatched elseif subtree ('B').
  FContext.Add('a', False);
  FContext.Add('b', False);
  FContext.Add('x', '');
  Assert.AreEqual('',
    FEngine.Render('{{#if a}}A{{#elseif b}}B{{else}}{{x}}{{/if}}', FContext));
end;

procedure TTestTemplateElseBranchA209.Test_ElseIf_FirstMatchWins;
begin
  FContext.Add('a', False);
  FContext.Add('b', True);
  FContext.Add('c', True);
  Assert.AreEqual('B', FEngine.Render(
    '{{#if a}}A{{#elseif b}}B{{#elseif c}}C{{else}}E{{/if}}', FContext));
end;

procedure TTestTemplateElseBranchA209.Test_ElseIfAllFalse_FallbackElseRendered;
begin
  FContext.Add('a', False);
  FContext.Add('b', False);
  Assert.AreEqual('C', FEngine.Render(
    '{{#if a}}A{{#elseif b}}B{{else}}C{{/if}}', FContext));
end;

procedure TTestTemplateElseBranchA209.Test_IfTrue_OnlyThenBranch;
begin
  FContext.Add('show', True);
  Assert.AreEqual('yes',
    FEngine.Render('{{#if show}}yes{{else}}no{{/if}}', FContext));
end;

procedure TTestTemplateElseBranchA209.Test_EmptyElse_NoOutput;
begin
  FContext.Add('show', False);
  Assert.AreEqual('',
    FEngine.Render('{{#if show}}yes{{else}}{{/if}}', FContext));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTemplateElseBranchA209);

end.
