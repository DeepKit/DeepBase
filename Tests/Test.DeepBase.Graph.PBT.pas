{ ============================================================================
  Test.DeepBase.Graph.PBT - Property-based tests for Graph correctness

  Properties covered:
    P15: Dijkstra Rejects Negative Weights (Req 11.1)
    P16: GetNeighbors Returns Independent Snapshot (Req 11.2)

  Each property runs >= 100 random iterations.
  ============================================================================ }

unit Test.DeepBase.Graph.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Graph;

type
  [TestFixture]
  TGraphPropertyTests = class
  strict private
    function MakeRandomGraph(out ANodeCount, AEdgeCount: Integer;
      AAllowNegative: Boolean): TGraph<Integer>;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 15
    [Test]
    procedure Property15_DijkstraRejectsNegativeWeights;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 15 (control)
    [Test]
    procedure Property15_DijkstraAcceptsNonNegativeWeights;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 16
    [Test]
    procedure Property16_NeighborsReturnsIndependentSnapshot;
  end;

implementation

procedure TGraphPropertyTests.Setup;
begin
  Randomize;
end;

function TGraphPropertyTests.MakeRandomGraph(out ANodeCount, AEdgeCount: Integer;
  AAllowNegative: Boolean): TGraph<Integer>;
begin
  ANodeCount := 3 + Random(18); // [3, 20]
  Result := TGraph<Integer>.Create(True);
  for var I := 1 to ANodeCount do
    Result.AddNode(I);

  // Build a random number of edges; ensure at least one when negatives are
  // requested so the property has something to reject.
  AEdgeCount := 1 + Random(ANodeCount * 2);
  for var I := 1 to AEdgeCount do
  begin
    var LSrc := 1 + Random(ANodeCount);
    var LDst := 1 + Random(ANodeCount);
    if LSrc = LDst then
      Continue;
    var LWeight: Double :=
      if AAllowNegative and (Random(3) = 0)
        then -(0.1 + Random(100) / 10.0)
        else 0.1 + Random(100) / 10.0;
    Result.AddEdge(LSrc, LDst, LWeight);
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 15: Dijkstra rejects negative
// weights when at least one edge has weight < 0.
procedure TGraphPropertyTests.Property15_DijkstraRejectsNegativeWeights;
begin
  for var Iter := 1 to 100 do
  begin
    var LNodeCount, LEdgeCount: Integer;
    var LGraph := MakeRandomGraph(LNodeCount, LEdgeCount, False);
    try
      // Force at least one negative edge so the property has a target.
      var LSrc := 1 + Random(LNodeCount);
      var LDst := 1 + Random(LNodeCount);
      if LSrc = LDst then
        LDst := ((LDst) mod LNodeCount) + 1;
      LGraph.AddEdge(LSrc, LDst, -(1.0 + Random(50)));

      var LRaised := False;
      try
        LGraph.ShortestPath(1, LNodeCount);
      except
        on E: EGraphNegativeWeight do
          LRaised := True;
      end;
      Assert.IsTrue(LRaised,
        Format('Iter %d: expected EGraphNegativeWeight (nodes=%d edges=%d)',
          [Iter, LNodeCount, LEdgeCount + 1]));
    finally
      LGraph.Free;
    end;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 15 (control): Dijkstra does not
// raise EGraphNegativeWeight when all edge weights are non-negative.
procedure TGraphPropertyTests.Property15_DijkstraAcceptsNonNegativeWeights;
begin
  for var Iter := 1 to 100 do
  begin
    var LNodeCount, LEdgeCount: Integer;
    var LGraph := MakeRandomGraph(LNodeCount, LEdgeCount, False);
    try
      try
        // Path may or may not exist; only the absence of negative-weight
        // exception matters for this property.
        LGraph.ShortestPath(1, LNodeCount);
      except
        on E: EGraphNegativeWeight do
          Assert.Fail(Format('Iter %d: unexpected EGraphNegativeWeight on ' +
            'non-negative graph (nodes=%d edges=%d)',
            [Iter, LNodeCount, LEdgeCount]));
      end;
    finally
      LGraph.Free;
    end;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 16: Neighbors returns a
// snapshot. Mutating the returned array MUST NOT affect subsequent calls or
// the graph's internal adjacency.
procedure TGraphPropertyTests.Property16_NeighborsReturnsIndependentSnapshot;
begin
  for var Iter := 1 to 100 do
  begin
    var LNodeCount, LEdgeCount: Integer;
    var LGraph := MakeRandomGraph(LNodeCount, LEdgeCount, False);
    try
      // Pick a node that actually has neighbours when possible; fall back to
      // node 1 otherwise.
      var LNode := 1;
      for var I := 1 to LNodeCount do
        if Length(LGraph.Neighbors(I)) > 0 then
        begin
          LNode := I;
          Break;
        end;

      var LFirst := LGraph.Neighbors(LNode);
      var LFirstLen := Length(LFirst);

      // Mutate the returned array. A snapshot must not propagate this back
      // into the graph.
      if LFirstLen > 0 then
      begin
        LFirst[0] := -999;
        SetLength(LFirst, 0);
      end;

      var LSecond := LGraph.Neighbors(LNode);
      Assert.AreEqual<Integer>(LFirstLen, Length(LSecond),
        Format('Iter %d: neighbour count changed after mutating snapshot ' +
          '(node=%d)', [Iter, LNode]));

      for var I := 0 to High(LSecond) do
        Assert.AreNotEqual<Integer>(-999, LSecond[I],
          Format('Iter %d: sentinel leaked back into graph state', [Iter]));
    finally
      LGraph.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TGraphPropertyTests);

end.
