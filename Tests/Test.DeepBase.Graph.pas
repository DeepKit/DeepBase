/// <summary>
/// Unit tests for DeepBase.Graph module
/// Tests: TGraph, TPath, TEdge, TPriorityQueue, TTreeNode, TTree, TGraphBuilder
/// </summary>
unit Test.DeepBase.Graph;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Graph;

type
  /// <summary>
  /// Tests for TEdge
  /// </summary>
  [TestFixture]
  TEdgeTests = class
  public
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Create_WithWeight;
    [Test]
    procedure Test_DefaultWeight;
  end;

  /// <summary>
  /// Tests for TPath
  /// </summary>
  [TestFixture]
  TPathTests = class
  public
    [Test]
    procedure Test_Length;
    [Test]
    procedure Test_ToString;
    [Test]
    procedure Test_Found;
  end;

  /// <summary>
  /// Tests for TGraph basic operations
  /// </summary>
  [TestFixture]
  TGraphBasicTests = class
  private
    FGraph: TGraph<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create_Directed;
    [Test]
    procedure Test_Create_Undirected;
    [Test]
    procedure Test_AddNode;
    [Test]
    procedure Test_RemoveNode;
    [Test]
    procedure Test_HasNode;
    [Test]
    procedure Test_AddEdge;
    [Test]
    procedure Test_RemoveEdge;
    [Test]
    procedure Test_HasEdge;
    [Test]
    procedure Test_GetNodes;
    [Test]
    procedure Test_GetEdges;
    [Test]
    procedure Test_Neighbors;
    [Test]
    procedure Test_Degree;
    [Test]
    procedure Test_NodeCount;
    [Test]
    procedure Test_EdgeCount;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_EdgeWeight;
  end;

  /// <summary>
  /// Tests for TGraph undirected
  /// </summary>
  [TestFixture]
  TGraphUndirectedTests = class
  private
    FGraph: TGraph<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_AddEdge_Bidirectional;
    [Test]
    procedure Test_HasEdge_Bidirectional;
    [Test]
    procedure Test_Degree;
  end;

  /// <summary>
  /// Tests for TGraph traversal
  /// </summary>
  [TestFixture]
  TGraphTraversalTests = class
  private
    FGraph: TGraph<Integer>;
    FVisited: TList<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_BFS;
    [Test]
    procedure Test_BFS_Order;
    [Test]
    procedure Test_DFS;
    [Test]
    procedure Test_DFS_Order;
    [Test]
    procedure Test_BFSPath;
    [Test]
    procedure Test_DFSPath;
    [Test]
    procedure Test_Traversal_Visitor;
  end;

  /// <summary>
  /// Tests for TGraph shortest path
  /// </summary>
  [TestFixture]
  TGraphShortestPathTests = class
  private
    FGraph: TGraph<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_ShortestPath_Simple;
    [Test]
    procedure Test_ShortestPath_Weighted;
    [Test]
    procedure Test_ShortestPath_NotFound;
    [Test]
    procedure Test_ShortestPaths;
  end;

  /// <summary>
  /// Tests for TGraph topological sort
  /// </summary>
  [TestFixture]
  TGraphTopologicalTests = class
  private
    FGraph: TGraph<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_TopologicalSort;
    [Test]
    procedure Test_TopologicalSort_Order;
    [Test]
    procedure Test_TryTopologicalSort_Success;
    [Test]
    procedure Test_TryTopologicalSort_Cycle;
  end;

  /// <summary>
  /// Tests for TGraph cycle detection
  /// </summary>
  [TestFixture]
  TGraphCycleTests = class
  private
    FGraph: TGraph<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_HasCycle_True;
    [Test]
    procedure Test_HasCycle_False;
    [Test]
    procedure Test_FindCycle;
  end;

  /// <summary>
  /// Tests for TGraph connected components
  /// </summary>
  [TestFixture]
  TGraphConnectedTests = class
  private
    FGraph: TGraph<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_IsConnected_True;
    [Test]
    procedure Test_IsConnected_False;
    [Test]
    procedure Test_ConnectedComponents;
    [Test]
    procedure Test_IsReachable;
    [Test]
    procedure Test_ReachableFrom;
  end;

  /// <summary>
  /// Tests for TPriorityQueue
  /// </summary>
  [TestFixture]
  TPriorityQueueTests = class
  private
    FQueue: TPriorityQueue<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Enqueue;
    [Test]
    procedure Test_Dequeue_Priority;
    [Test]
    procedure Test_Peek;
    [Test]
    procedure Test_Contains;
    [Test]
    procedure Test_UpdatePriority;
    [Test]
    procedure Test_Count;
    [Test]
    procedure Test_IsEmpty;
    [Test]
    procedure Test_Clear;
  end;

  /// <summary>
  /// Tests for TTreeNode
  /// </summary>
  [TestFixture]
  TTreeNodeTests = class
  private
    FRoot: TTreeNode<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_AddChild;
    [Test]
    procedure Test_ReDeepMoveChild;
    [Test]
    procedure Test_IsRoot;
    [Test]
    procedure Test_IsLeaf;
    [Test]
    procedure Test_Depth;
    [Test]
    procedure Test_Height;
    [Test]
    procedure Test_Root;
    [Test]
    procedure Test_Siblings;
    [Test]
    procedure Test_Path;
  end;

  /// <summary>
  /// Tests for TTree
  /// </summary>
  [TestFixture]
  TTreeTests = class
  private
    FTree: TTree<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_SetRoot;
    [Test]
    procedure Test_Find;
    [Test]
    procedure Test_Contains;
    [Test]
    procedure Test_Traverse_PreOrder;
    [Test]
    procedure Test_Traverse_PostOrder;
    [Test]
    procedure Test_Traverse_LevelOrder;
    [Test]
    procedure Test_ToArray;
    [Test]
    procedure Test_NodeCount;
    [Test]
    procedure Test_Height;
    [Test]
    procedure Test_Clear;
  end;

  /// <summary>
  /// Tests for TGraphBuilder
  /// </summary>
  [TestFixture]
  TGraphBuilderTests = class
  public
    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_AddNode;
    [Test]
    procedure Test_AddNodes;
    [Test]
    procedure Test_AddEdge;
    [Test]
    procedure Test_Build;
    [Test]
    procedure Test_Fluent;
  end;

implementation

// ============================================================================
// TEdgeTests
// ============================================================================

procedure TEdgeTests.Test_Create;
var
  Edge: TEdge<Integer>;
begin
  Edge := TEdge<Integer>.Create(1, 2);
  Assert.AreEqual(1, Edge.Source);
  Assert.AreEqual(2, Edge.Target);
end;

procedure TEdgeTests.Test_Create_WithWeight;
var
  Edge: TEdge<string>;
begin
  Edge := TEdge<string>.Create('A', 'B', 5.0);
  Assert.AreEqual('A', Edge.Source);
  Assert.AreEqual('B', Edge.Target);
  Assert.AreEqual(5.0, Edge.Weight, 0.001);
end;

procedure TEdgeTests.Test_DefaultWeight;
var
  Edge: TEdge<Integer>;
begin
  Edge := TEdge<Integer>.Create(1, 2);
  Assert.AreEqual(1.0, Edge.Weight, 0.001);
end;

// ============================================================================
// TPathTests
// ============================================================================

procedure TPathTests.Test_Length;
var
  Path: TPath<Integer>;
begin
  Path.Nodes := TArray<Integer>.Create(1, 2, 3, 4);
  Assert.AreEqual(4, Path.Length);
end;

procedure TPathTests.Test_ToString;
var
  Path: TPath<Integer>;
  S: string;
begin
  Path.Nodes := TArray<Integer>.Create(1, 2, 3);
  Path.Found := True;
  S := Path.ToString;
  Assert.IsNotEmpty(S);
end;

procedure TPathTests.Test_Found;
var
  Path: TPath<string>;
begin
  Path.Found := True;
  Assert.IsTrue(Path.Found);
  Path.Found := False;
  Assert.IsFalse(Path.Found);
end;

// ============================================================================
// TGraphBasicTests
// ============================================================================

procedure TGraphBasicTests.Setup;
begin
  FGraph := TGraph<Integer>.Create(True);
end;

procedure TGraphBasicTests.TearDown;
begin
  FGraph.Free;
end;

procedure TGraphBasicTests.Test_Create_Directed;
begin
  Assert.IsNotNull(FGraph);
  Assert.IsTrue(FGraph.Directed);
end;

procedure TGraphBasicTests.Test_Create_Undirected;
var
  G: TGraph<Integer>;
begin
  G := TGraph<Integer>.Create(False);
  try
    Assert.IsFalse(G.Directed);
  finally
    G.Free;
  end;
end;

procedure TGraphBasicTests.Test_AddNode;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  Assert.AreEqual(2, FGraph.NodeCount);
end;

procedure TGraphBasicTests.Test_RemoveNode;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.RemoveNode(1);
  Assert.AreEqual(1, FGraph.NodeCount);
  Assert.IsFalse(FGraph.HasNode(1));
end;

procedure TGraphBasicTests.Test_HasNode;
begin
  FGraph.AddNode(1);
  Assert.IsTrue(FGraph.HasNode(1));
  Assert.IsFalse(FGraph.HasNode(999));
end;

procedure TGraphBasicTests.Test_AddEdge;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddEdge(1, 2);
  Assert.AreEqual(1, FGraph.EdgeCount);
end;

procedure TGraphBasicTests.Test_RemoveEdge;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddEdge(1, 2);
  FGraph.RemoveEdge(1, 2);
  Assert.AreEqual(0, FGraph.EdgeCount);
end;

procedure TGraphBasicTests.Test_HasEdge;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddEdge(1, 2);
  Assert.IsTrue(FGraph.HasEdge(1, 2));
  Assert.IsFalse(FGraph.HasEdge(2, 1)); // Directed
end;

procedure TGraphBasicTests.Test_GetNodes;
var
  Nodes: TArray<Integer>;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  Nodes := FGraph.GetNodes;
  Assert.AreEqual(3, Integer(Length(Nodes)));
end;

procedure TGraphBasicTests.Test_GetEdges;
var
  Edges: TArray<TEdge<Integer>>;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(2, 1);
  Edges := FGraph.GetEdges;
  Assert.AreEqual(2, Integer(Length(Edges)));
end;

procedure TGraphBasicTests.Test_Neighbors;
var
  N: TArray<Integer>;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(1, 3);
  N := FGraph.Neighbors(1);
  Assert.AreEqual(2, Integer(Length(N)));
end;

procedure TGraphBasicTests.Test_Degree;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(1, 3);
  Assert.AreEqual(2, FGraph.OutDegree(1));
end;

procedure TGraphBasicTests.Test_NodeCount;
begin
  Assert.AreEqual(0, FGraph.NodeCount);
  FGraph.AddNode(1);
  Assert.AreEqual(1, FGraph.NodeCount);
end;

procedure TGraphBasicTests.Test_EdgeCount;
begin
  Assert.AreEqual(0, FGraph.EdgeCount);
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddEdge(1, 2);
  Assert.AreEqual(1, FGraph.EdgeCount);
end;

procedure TGraphBasicTests.Test_Clear;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddEdge(1, 2);
  FGraph.Clear;
  Assert.AreEqual(0, FGraph.NodeCount);
  Assert.AreEqual(0, FGraph.EdgeCount);
end;

procedure TGraphBasicTests.Test_EdgeWeight;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddEdge(1, 2, 5.5);
  Assert.AreEqual(5.5, FGraph.Weight[1, 2], 0.001);
end;

// ============================================================================
// TGraphUndirectedTests
// ============================================================================

procedure TGraphUndirectedTests.Setup;
begin
  FGraph := TGraph<string>.Create(False);
end;

procedure TGraphUndirectedTests.TearDown;
begin
  FGraph.Free;
end;

procedure TGraphUndirectedTests.Test_AddEdge_Bidirectional;
begin
  FGraph.AddNode('A');
  FGraph.AddNode('B');
  FGraph.AddEdge('A', 'B');
  Assert.IsTrue(FGraph.HasEdge('A', 'B'));
  Assert.IsTrue(FGraph.HasEdge('B', 'A'));
end;

procedure TGraphUndirectedTests.Test_HasEdge_Bidirectional;
begin
  FGraph.AddNode('X');
  FGraph.AddNode('Y');
  FGraph.AddEdge('X', 'Y');
  Assert.IsTrue(FGraph.HasEdge('Y', 'X'));
end;

procedure TGraphUndirectedTests.Test_Degree;
begin
  FGraph.AddNode('A');
  FGraph.AddNode('B');
  FGraph.AddNode('C');
  FGraph.AddEdge('A', 'B');
  FGraph.AddEdge('A', 'C');
  Assert.AreEqual(2, FGraph.Degree('A'));
end;

// ============================================================================
// TGraphTraversalTests
// ============================================================================

procedure TGraphTraversalTests.Setup;
begin
  FGraph := TGraph<Integer>.Create(True);
  FVisited := TList<Integer>.Create;
  
  // Build test graph: 1 -> 2, 1 -> 3, 2 -> 4, 3 -> 4
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  FGraph.AddNode(4);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(1, 3);
  FGraph.AddEdge(2, 4);
  FGraph.AddEdge(3, 4);
end;

procedure TGraphTraversalTests.TearDown;
begin
  FVisited.Free;
  FGraph.Free;
end;

procedure TGraphTraversalTests.Test_BFS;
begin
  FGraph.BFS(1, procedure(const N: Integer; var C: Boolean)
    begin
      FVisited.Add(N);
    end);
  Assert.AreEqual(4, Integer(FVisited.Count));
  Assert.IsTrue(FVisited.Contains(1));
  Assert.IsTrue(FVisited.Contains(4));
end;

procedure TGraphTraversalTests.Test_BFS_Order;
begin
  FGraph.BFS(1, procedure(const N: Integer; var C: Boolean)
    begin
      FVisited.Add(N);
    end);
  // BFS visits level by level: 1 first, then 2,3, then 4
  Assert.AreEqual(1, FVisited[0]);
  Assert.AreEqual(4, FVisited[3]);
end;

procedure TGraphTraversalTests.Test_DFS;
begin
  FGraph.DFS(1, procedure(const N: Integer; var C: Boolean)
    begin
      FVisited.Add(N);
    end);
  Assert.AreEqual(4, Integer(FVisited.Count));
end;

procedure TGraphTraversalTests.Test_DFS_Order;
begin
  FGraph.DFS(1, procedure(const N: Integer; var C: Boolean)
    begin
      FVisited.Add(N);
    end);
  // DFS visits depth-first: 1 first
  Assert.AreEqual(1, FVisited[0]);
end;

procedure TGraphTraversalTests.Test_BFSPath;
var
  Path: TPath<Integer>;
begin
  Path := FGraph.BFSPath(1, 4);
  Assert.IsTrue(Path.Found);
  Assert.IsTrue(Path.Length >= 2);
end;

procedure TGraphTraversalTests.Test_DFSPath;
var
  Path: TPath<Integer>;
begin
  Path := FGraph.DFSPath(1, 4);
  Assert.IsTrue(Path.Found);
end;

procedure TGraphTraversalTests.Test_Traversal_Visitor;
var
  Count: Integer;
begin
  Count := 0;
  FGraph.BFS(1, procedure(const N: Integer; var C: Boolean)
    begin
      Inc(Count);
      if Count = 2 then
        C := False; // Stop early
    end);
  Assert.AreEqual(2, Count);
end;

// ============================================================================
// TGraphShortestPathTests
// ============================================================================

procedure TGraphShortestPathTests.Setup;
begin
  FGraph := TGraph<string>.Create(True);
  
  // Build weighted graph
  FGraph.AddNode('A');
  FGraph.AddNode('B');
  FGraph.AddNode('C');
  FGraph.AddNode('D');
  FGraph.AddEdge('A', 'B', 1);
  FGraph.AddEdge('A', 'C', 4);
  FGraph.AddEdge('B', 'C', 2);
  FGraph.AddEdge('B', 'D', 6);
  FGraph.AddEdge('C', 'D', 3);
end;

procedure TGraphShortestPathTests.TearDown;
begin
  FGraph.Free;
end;

procedure TGraphShortestPathTests.Test_ShortestPath_Simple;
var
  Path: TPath<string>;
begin
  Path := FGraph.ShortestPath('A', 'D');
  Assert.IsTrue(Path.Found);
end;

procedure TGraphShortestPathTests.Test_ShortestPath_Weighted;
var
  Path: TPath<string>;
begin
  Path := FGraph.ShortestPath('A', 'D');
  Assert.IsTrue(Path.Found);
  // Shortest: A -> B -> C -> D = 1 + 2 + 3 = 6
  Assert.AreEqual(6.0, Path.TotalWeight, 0.001);
end;

procedure TGraphShortestPathTests.Test_ShortestPath_NotFound;
var
  Path: TPath<string>;
begin
  FGraph.AddNode('X'); // Isolated node
  Path := FGraph.ShortestPath('A', 'X');
  Assert.IsFalse(Path.Found);
end;

procedure TGraphShortestPathTests.Test_ShortestPaths;
var
  Paths: TDictionary<string, TPath<string>>;
begin
  Paths := FGraph.ShortestPaths('A');
  try
    Assert.IsTrue(Paths.ContainsKey('B'));
    Assert.IsTrue(Paths.ContainsKey('C'));
    Assert.IsTrue(Paths.ContainsKey('D'));
  finally
    Paths.Free;
  end;
end;

// ============================================================================
// TGraphTopologicalTests
// ============================================================================

procedure TGraphTopologicalTests.Setup;
begin
  FGraph := TGraph<string>.Create(True);
  
  // DAG: A -> B -> D, A -> C -> D
  FGraph.AddNode('A');
  FGraph.AddNode('B');
  FGraph.AddNode('C');
  FGraph.AddNode('D');
  FGraph.AddEdge('A', 'B');
  FGraph.AddEdge('A', 'C');
  FGraph.AddEdge('B', 'D');
  FGraph.AddEdge('C', 'D');
end;

procedure TGraphTopologicalTests.TearDown;
begin
  FGraph.Free;
end;

procedure TGraphTopologicalTests.Test_TopologicalSort;
var
  Sorted: TArray<string>;
begin
  Sorted := FGraph.TopologicalSort;
  Assert.AreEqual(4, Integer(Length(Sorted)));
end;

procedure TGraphTopologicalTests.Test_TopologicalSort_Order;
var
  Sorted: TArray<string>;
  IdxA, IdxD: Integer;
begin
  Sorted := FGraph.TopologicalSort;
  
  // Find positions
  IdxA := -1;
  IdxD := -1;
  for var I := 0 to High(Sorted) do
  begin
    if Sorted[I] = 'A' then IdxA := I;
    if Sorted[I] = 'D' then IdxD := I;
  end;
  
  // A must come before D
  Assert.IsTrue(IdxA < IdxD);
end;

procedure TGraphTopologicalTests.Test_TryTopologicalSort_Success;
var
  Sorted: TArray<string>;
begin
  Assert.IsTrue(FGraph.TryTopologicalSort(Sorted));
  Assert.AreEqual(4, Integer(Length(Sorted)));
end;

procedure TGraphTopologicalTests.Test_TryTopologicalSort_Cycle;
var
  CyclicGraph: TGraph<string>;
  Sorted: TArray<string>;
begin
  CyclicGraph := TGraph<string>.Create(True);
  try
    CyclicGraph.AddNode('X');
    CyclicGraph.AddNode('Y');
    CyclicGraph.AddEdge('X', 'Y');
    CyclicGraph.AddEdge('Y', 'X'); // Create cycle
    
    Assert.IsFalse(CyclicGraph.TryTopologicalSort(Sorted));
  finally
    CyclicGraph.Free;
  end;
end;

// ============================================================================
// TGraphCycleTests
// ============================================================================

procedure TGraphCycleTests.Setup;
begin
  FGraph := TGraph<Integer>.Create(True);
end;

procedure TGraphCycleTests.TearDown;
begin
  FGraph.Free;
end;

procedure TGraphCycleTests.Test_HasCycle_True;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(2, 3);
  FGraph.AddEdge(3, 1); // Cycle
  
  Assert.IsTrue(FGraph.HasCycle);
end;

procedure TGraphCycleTests.Test_HasCycle_False;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(2, 3);
  
  Assert.IsFalse(FGraph.HasCycle);
end;

procedure TGraphCycleTests.Test_FindCycle;
var
  Cycle: TArray<Integer>;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(2, 3);
  FGraph.AddEdge(3, 1);
  
  Cycle := FGraph.FindCycle;
  Assert.IsTrue(Length(Cycle) >= 3);
end;

// ============================================================================
// TGraphConnectedTests
// ============================================================================

procedure TGraphConnectedTests.Setup;
begin
  FGraph := TGraph<Integer>.Create(False); // Undirected
end;

procedure TGraphConnectedTests.TearDown;
begin
  FGraph.Free;
end;

procedure TGraphConnectedTests.Test_IsConnected_True;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(2, 3);
  
  Assert.IsTrue(FGraph.IsConnected);
end;

procedure TGraphConnectedTests.Test_IsConnected_False;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  FGraph.AddNode(4);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(3, 4);
  // Two components: {1,2} and {3,4}
  
  Assert.IsFalse(FGraph.IsConnected);
end;

procedure TGraphConnectedTests.Test_ConnectedComponents;
var
  Components: TArray<TArray<Integer>>;
begin
  FGraph.AddNode(1);
  FGraph.AddNode(2);
  FGraph.AddNode(3);
  FGraph.AddNode(4);
  FGraph.AddEdge(1, 2);
  FGraph.AddEdge(3, 4);
  
  Components := FGraph.ConnectedComponents;
  Assert.AreEqual(2, Integer(Length(Components)));
end;

procedure TGraphConnectedTests.Test_IsReachable;
var
  G: TGraph<Integer>;
begin
  G := TGraph<Integer>.Create(True);
  try
    G.AddNode(1);
    G.AddNode(2);
    G.AddNode(3);
    G.AddEdge(1, 2);
    G.AddEdge(2, 3);
    
    Assert.IsTrue(G.IsReachable(1, 3));
    Assert.IsFalse(G.IsReachable(3, 1)); // Directed, no edge back
  finally
    G.Free;
  end;
end;

procedure TGraphConnectedTests.Test_ReachableFrom;
var
  G: TGraph<Integer>;
  Reachable: TArray<Integer>;
begin
  G := TGraph<Integer>.Create(True);
  try
    G.AddNode(1);
    G.AddNode(2);
    G.AddNode(3);
    G.AddNode(4);
    G.AddEdge(1, 2);
    G.AddEdge(2, 3);
    
    Reachable := G.ReachableFrom(1);
    Assert.AreEqual(3, Integer(Length(Reachable))); // 1, 2, 3
  finally
    G.Free;
  end;
end;

// ============================================================================
// TPriorityQueueTests
// ============================================================================

procedure TPriorityQueueTests.Setup;
begin
  FQueue := TPriorityQueue<string>.Create;
end;

procedure TPriorityQueueTests.TearDown;
begin
  FQueue.Free;
end;

procedure TPriorityQueueTests.Test_Create;
begin
  Assert.IsNotNull(FQueue);
  Assert.IsTrue(FQueue.IsEmpty);
end;

procedure TPriorityQueueTests.Test_Enqueue;
begin
  FQueue.Enqueue('A', 1.0);
  Assert.AreEqual(1, Integer(FQueue.Count));
end;

procedure TPriorityQueueTests.Test_Dequeue_Priority;
begin
  FQueue.Enqueue('Low', 10.0);
  FQueue.Enqueue('High', 1.0);
  FQueue.Enqueue('Mid', 5.0);
  
  // Should dequeue by lowest priority first
  Assert.AreEqual('High', FQueue.Dequeue);
  Assert.AreEqual('Mid', FQueue.Dequeue);
  Assert.AreEqual('Low', FQueue.Dequeue);
end;

procedure TPriorityQueueTests.Test_Peek;
begin
  FQueue.Enqueue('A', 5.0);
  FQueue.Enqueue('B', 1.0);
  
  Assert.AreEqual('B', FQueue.Peek);
  Assert.AreEqual(2, Integer(FQueue.Count)); // Peek doesn't remove
end;

procedure TPriorityQueueTests.Test_Contains;
begin
  FQueue.Enqueue('X', 1.0);
  Assert.IsTrue(FQueue.Contains('X'));
  Assert.IsFalse(FQueue.Contains('Y'));
end;

procedure TPriorityQueueTests.Test_UpdatePriority;
begin
  FQueue.Enqueue('A', 10.0);
  FQueue.Enqueue('B', 5.0);
  FQueue.UpdatePriority('A', 1.0); // Make A highest priority
  
  Assert.AreEqual('A', FQueue.Dequeue);
end;

procedure TPriorityQueueTests.Test_Count;
begin
  Assert.AreEqual(0, Integer(FQueue.Count));
  FQueue.Enqueue('A', 1.0);
  FQueue.Enqueue('B', 2.0);
  Assert.AreEqual(2, Integer(FQueue.Count));
end;

procedure TPriorityQueueTests.Test_IsEmpty;
begin
  Assert.IsTrue(FQueue.IsEmpty);
  FQueue.Enqueue('A', 1.0);
  Assert.IsFalse(FQueue.IsEmpty);
end;

procedure TPriorityQueueTests.Test_Clear;
begin
  FQueue.Enqueue('A', 1.0);
  FQueue.Enqueue('B', 2.0);
  FQueue.Clear;
  Assert.IsTrue(FQueue.IsEmpty);
end;

// ============================================================================
// TTreeNodeTests
// ============================================================================

procedure TTreeNodeTests.Setup;
begin
  FRoot := TTreeNode<string>.Create('Root');
end;

procedure TTreeNodeTests.TearDown;
begin
  FRoot.Free;
end;

procedure TTreeNodeTests.Test_Create;
begin
  Assert.IsNotNull(FRoot);
  Assert.AreEqual('Root', FRoot.Value);
end;

procedure TTreeNodeTests.Test_AddChild;
var
  Child: TTreeNode<string>;
begin
  Child := FRoot.AddChild('Child1');
  Assert.IsNotNull(Child);
  Assert.AreEqual(1, FRoot.ChildCount);
end;

procedure TTreeNodeTests.Test_ReDeepMoveChild;
var
  Child: TTreeNode<string>;
begin
  Child := FRoot.AddChild('Child');
  FRoot.ReDeepMoveChild(Child);
  Assert.AreEqual(0, FRoot.ChildCount);
end;

procedure TTreeNodeTests.Test_IsRoot;
var
  Child: TTreeNode<string>;
begin
  Assert.IsTrue(FRoot.IsRoot);
  Child := FRoot.AddChild('Child');
  Assert.IsFalse(Child.IsRoot);
end;

procedure TTreeNodeTests.Test_IsLeaf;
var
  Child: TTreeNode<string>;
begin
  Assert.IsTrue(FRoot.IsLeaf); // No children yet
  Child := FRoot.AddChild('Child');
  Assert.IsFalse(FRoot.IsLeaf);
  Assert.IsTrue(Child.IsLeaf);
end;

procedure TTreeNodeTests.Test_Depth;
var
  Child, GrandChild: TTreeNode<string>;
begin
  Assert.AreEqual(0, FRoot.Depth);
  Child := FRoot.AddChild('Child');
  Assert.AreEqual(1, Child.Depth);
  GrandChild := Child.AddChild('GrandChild');
  Assert.AreEqual(2, GrandChild.Depth);
end;

procedure TTreeNodeTests.Test_Height;
var
  Child: TTreeNode<string>;
begin
  Assert.AreEqual(0, FRoot.Height); // Leaf
  Child := FRoot.AddChild('Child');
  Assert.AreEqual(1, FRoot.Height);
  Child.AddChild('GrandChild');
  Assert.AreEqual(2, FRoot.Height);
end;

procedure TTreeNodeTests.Test_Root;
var
  Child, GrandChild: TTreeNode<string>;
begin
  Child := FRoot.AddChild('Child');
  GrandChild := Child.AddChild('GrandChild');
  Assert.AreSame(FRoot, GrandChild.Root);
end;

procedure TTreeNodeTests.Test_Siblings;
var
  C1, C2, C3: TTreeNode<string>;
  Sibs: TArray<TTreeNode<string>>;
begin
  C1 := FRoot.AddChild('C1');
  C2 := FRoot.AddChild('C2');
  C3 := FRoot.AddChild('C3');
  
  Sibs := C1.Siblings;
  Assert.AreEqual(2, Integer(Length(Sibs))); // C2 and C3
end;

procedure TTreeNodeTests.Test_Path;
var
  Child, GrandChild: TTreeNode<string>;
  PathNodes: TArray<TTreeNode<string>>;
begin
  Child := FRoot.AddChild('Child');
  GrandChild := Child.AddChild('GrandChild');
  
  PathNodes := GrandChild.Path;
  Assert.AreEqual(3, Integer(Length(PathNodes)));
  Assert.AreSame(FRoot, PathNodes[0]);
  Assert.AreSame(GrandChild, PathNodes[2]);
end;

// ============================================================================
// TTreeTests
// ============================================================================

procedure TTreeTests.Setup;
begin
  FTree := TTree<string>.Create('Root');
end;

procedure TTreeTests.TearDown;
begin
  FTree.Free;
end;

procedure TTreeTests.Test_Create;
begin
  Assert.IsNotNull(FTree);
  Assert.IsNotNull(FTree.Root);
end;

procedure TTreeTests.Test_SetRoot;
var
  Tree: TTree<string>;
begin
  Tree := TTree<string>.Create;
  try
    Tree.SetRoot('NewRoot');
    Assert.AreEqual('NewRoot', Tree.Root.Value);
  finally
    Tree.Free;
  end;
end;

procedure TTreeTests.Test_Find;
var
  Node: TTreeNode<string>;
begin
  FTree.Root.AddChild('Child1');
  FTree.Root.AddChild('Child2');
  
  Node := FTree.Find('Child1');
  Assert.IsNotNull(Node);
  Assert.AreEqual('Child1', Node.Value);
end;

procedure TTreeTests.Test_Contains;
begin
  FTree.Root.AddChild('Child');
  Assert.IsTrue(FTree.Contains('Root'));
  Assert.IsTrue(FTree.Contains('Child'));
  Assert.IsFalse(FTree.Contains('NotExist'));
end;

procedure TTreeTests.Test_Traverse_PreOrder;
var
  Values: TList<string>;
begin
  Values := TList<string>.Create;
  try
    FTree.Root.AddChild('A');
    FTree.Root.AddChild('B');
    
    FTree.Traverse(ttoPreOrder, procedure(const V: string; var C: Boolean)
      begin
        Values.Add(V);
      end);
    
    Assert.AreEqual(3, Integer(Values.Count));
    Assert.AreEqual('Root', Values[0]); // PreOrder: root first
  finally
    Values.Free;
  end;
end;

procedure TTreeTests.Test_Traverse_PostOrder;
var
  Values: TList<string>;
begin
  Values := TList<string>.Create;
  try
    FTree.Root.AddChild('A');
    FTree.Root.AddChild('B');
    
    FTree.Traverse(ttoPostOrder, procedure(const V: string; var C: Boolean)
      begin
        Values.Add(V);
      end);
    
    Assert.AreEqual(3, Integer(Values.Count));
    Assert.AreEqual('Root', Values[2]); // PostOrder: root last
  finally
    Values.Free;
  end;
end;

procedure TTreeTests.Test_Traverse_LevelOrder;
var
  Values: TList<string>;
begin
  Values := TList<string>.Create;
  try
    FTree.Root.AddChild('A').AddChild('A1');
    FTree.Root.AddChild('B');
    
    FTree.Traverse(ttoLevelOrder, procedure(const V: string; var C: Boolean)
      begin
        Values.Add(V);
      end);
    
    Assert.AreEqual(4, Integer(Values.Count));
    Assert.AreEqual('Root', Values[0]); // Level 0
  finally
    Values.Free;
  end;
end;

procedure TTreeTests.Test_ToArray;
var
  Arr: TArray<string>;
begin
  FTree.Root.AddChild('A');
  FTree.Root.AddChild('B');
  
  Arr := FTree.ToArray;
  Assert.AreEqual(3, Integer(Length(Arr)));
end;

procedure TTreeTests.Test_NodeCount;
begin
  FTree.Root.AddChild('A');
  FTree.Root.AddChild('B');
  Assert.AreEqual(3, FTree.NodeCount);
end;

procedure TTreeTests.Test_Height;
begin
  FTree.Root.AddChild('A').AddChild('A1').AddChild('A11');
  Assert.AreEqual(3, FTree.Height);
end;

procedure TTreeTests.Test_Clear;
begin
  FTree.Root.AddChild('A');
  FTree.Clear;
  Assert.IsNull(FTree.Root);
end;

// ============================================================================
// TGraphBuilderTests
// ============================================================================

procedure TGraphBuilderTests.Test_Create;
var
  Builder: TGraphBuilder<Integer>;
begin
  Builder := TGraphBuilder<Integer>.Create;
  try
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TGraphBuilderTests.Test_AddNode;
var
  Builder: TGraphBuilder<Integer>;
begin
  Builder := TGraphBuilder<Integer>.Create;
  try
    Builder.AddNode(1);
    // Just ensure no exception
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TGraphBuilderTests.Test_AddNodes;
var
  Builder: TGraphBuilder<Integer>;
begin
  Builder := TGraphBuilder<Integer>.Create;
  try
    Builder.AddNodes([1, 2, 3, 4]);
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TGraphBuilderTests.Test_AddEdge;
var
  Builder: TGraphBuilder<Integer>;
begin
  Builder := TGraphBuilder<Integer>.Create;
  try
    Builder.AddNode(1).AddNode(2).AddEdge(1, 2);
    Assert.IsNotNull(Builder);
  finally
    Builder.Free;
  end;
end;

procedure TGraphBuilderTests.Test_Build;
var
  Builder: TGraphBuilder<Integer>;
  Graph: TGraph<Integer>;
begin
  Builder := TGraphBuilder<Integer>.Create;
  try
    Builder.AddNodes([1, 2, 3]);
    Builder.AddEdge(1, 2);
    Graph := Builder.Build;
    try
      Assert.AreEqual(3, Graph.NodeCount);
      Assert.AreEqual(1, Graph.EdgeCount);
    finally
      Graph.Free;
    end;
  finally
    Builder.Free;
  end;
end;

procedure TGraphBuilderTests.Test_Fluent;
var
  Builder: TGraphBuilder<string>;
  Graph: TGraph<string>;
begin
  Builder := TGraphBuilder<string>.Create;
  try
    Graph := Builder
      .AddNode('A')
      .AddNode('B')
      .AddNode('C')
      .AddEdge('A', 'B', 1.0)
      .AddEdge('B', 'C', 2.0)
      .Build;
    try
      Assert.AreEqual(3, Graph.NodeCount);
      Assert.AreEqual(2, Graph.EdgeCount);
    finally
      Graph.Free;
    end;
  finally
    Builder.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEdgeTests);
  TDUnitX.RegisterTestFixture(TPathTests);
  TDUnitX.RegisterTestFixture(TGraphBasicTests);
  TDUnitX.RegisterTestFixture(TGraphUndirectedTests);
  TDUnitX.RegisterTestFixture(TGraphTraversalTests);
  TDUnitX.RegisterTestFixture(TGraphShortestPathTests);
  TDUnitX.RegisterTestFixture(TGraphTopologicalTests);
  TDUnitX.RegisterTestFixture(TGraphCycleTests);
  TDUnitX.RegisterTestFixture(TGraphConnectedTests);
  TDUnitX.RegisterTestFixture(TPriorityQueueTests);
  TDUnitX.RegisterTestFixture(TTreeNodeTests);
  TDUnitX.RegisterTestFixture(TTreeTests);
  TDUnitX.RegisterTestFixture(TGraphBuilderTests);

end.
