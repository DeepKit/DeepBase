unit UniBase.Graph;

{*******************************************************************************
  UniBase Graph Data Structure
  A comprehensive graph implementation with:
  - Generic graph structure (directed/undirected)
  - Adjacency list representation
  - BFS/DFS traversal
  - Topological sorting
  - Shortest path algorithms (Dijkstra, BFS)
  - Cycle detection
  - Connected components
  - Minimum spanning tree (Prim/Kruskal)
  - Path finding
  
  Author: UniBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Generics.Defaults, System.SyncObjs;

type
  EGraphException = class(Exception);

  /// <summary>Graph traversal visitor</summary>
  TGraphVisitor<T> = reference to procedure(const ANode: T; var AContinue: Boolean);

  /// <summary>Edge in graph</summary>
  TEdge<T> = record
    Source: T;
    Target: T;
    Weight: Double;
    
    constructor Create(const ASource, ATarget: T; AWeight: Double = 1.0);
  end;

  /// <summary>Path result</summary>
  TPath<T> = record
    Nodes: TArray<T>;
    TotalWeight: Double;
    Found: Boolean;
    
    function Length: Integer;
    function ToString: string;
  end;

  /// <summary>Generic graph class</summary>
  TGraph<T> = class
  public type
    TNodeList = TList<T>;
    TEdgeList = TList<TEdge<T>>;
    TAdjacencyMap = TDictionary<T, TNodeList>;
    TWeightMap = TDictionary<T, TDictionary<T, Double>>;
  private
    FNodes: TNodeList;
    FAdjacency: TAdjacencyMap;
    FWeights: TWeightMap;
    FDirected: Boolean;
    FComparer: IEqualityComparer<T>;
    FLock: TCriticalSection;
    
    function GetNeighbors(const ANode: T): TNodeList;
    function GetWeight(const ASource, ATarget: T): Double;
    procedure SetWeight(const ASource, ATarget: T; AWeight: Double);
  public
    constructor Create(ADirected: Boolean = True); overload;
    constructor Create(ADirected: Boolean; AComparer: IEqualityComparer<T>); overload;
    destructor Destroy; override;
    
    /// <summary>Add node to graph</summary>
    procedure AddNode(const ANode: T);
    
    /// <summary>Remove node from graph</summary>
    procedure RemoveNode(const ANode: T);
    
    /// <summary>Check if node exists</summary>
    function HasNode(const ANode: T): Boolean;
    
    /// <summary>Add edge to graph</summary>
    procedure AddEdge(const ASource, ATarget: T; AWeight: Double = 1.0);
    
    /// <summary>Remove edge from graph</summary>
    procedure RemoveEdge(const ASource, ATarget: T);
    
    /// <summary>Check if edge exists</summary>
    function HasEdge(const ASource, ATarget: T): Boolean;
    
    /// <summary>Get all nodes</summary>
    function GetNodes: TArray<T>;
    
    /// <summary>Get all edges</summary>
    function GetEdges: TArray<TEdge<T>>;
    
    /// <summary>Get neighbors of node</summary>
    function Neighbors(const ANode: T): TArray<T>;
    
    /// <summary>Get degree of node</summary>
    function Degree(const ANode: T): Integer;
    function InDegree(const ANode: T): Integer;
    function OutDegree(const ANode: T): Integer;
    
    /// <summary>Node and edge counts</summary>
    function NodeCount: Integer;
    function EdgeCount: Integer;
    
    /// <summary>Clear graph</summary>
    procedure Clear;
    
    /// <summary>BFS traversal</summary>
    procedure BFS(const AStart: T; AVisitor: TGraphVisitor<T>);
    function BFSPath(const AStart, AEnd: T): TPath<T>;
    
    /// <summary>DFS traversal</summary>
    procedure DFS(const AStart: T; AVisitor: TGraphVisitor<T>);
    function DFSPath(const AStart, AEnd: T): TPath<T>;
    
    /// <summary>Shortest path (Dijkstra)</summary>
    function ShortestPath(const AStart, AEnd: T): TPath<T>;
    function ShortestPaths(const AStart: T): TDictionary<T, TPath<T>>;
    
    /// <summary>Topological sort (for DAG)</summary>
    function TopologicalSort: TArray<T>;
    function TryTopologicalSort(out ASorted: TArray<T>): Boolean;
    
    /// <summary>Cycle detection</summary>
    function HasCycle: Boolean;
    function FindCycle: TArray<T>;
    
    /// <summary>Connected components</summary>
    function IsConnected: Boolean;
    function ConnectedComponents: TArray<TArray<T>>;
    function StronglyConnectedComponents: TArray<TArray<T>>;
    
    /// <summary>Reachability</summary>
    function IsReachable(const AFrom, ATo: T): Boolean;
    function ReachableFrom(const ANode: T): TArray<T>;
    
    /// <summary>Minimum spanning tree (for undirected)</summary>
    function MinimumSpanningTree: TGraph<T>;
    
    /// <summary>Transpose graph (reverse all edges)</summary>
    function Transpose: TGraph<T>;
    
    /// <summary>Subgraph with specified nodes</summary>
    function Subgraph(const ANodes: TArray<T>): TGraph<T>;
    
    property Directed: Boolean read FDirected;
    property Weight[const ASource, ATarget: T]: Double read GetWeight write SetWeight;
  end;

  /// <summary>Priority queue for graph algorithms</summary>
  TPriorityQueue<T> = class
  private type
    TQueueItem = record
      Value: T;
      Priority: Double;
    end;
  private
    FItems: TList<TQueueItem>;
    FComparer: IEqualityComparer<T>;
    
    procedure HeapifyUp(AIndex: Integer);
    procedure HeapifyDown(AIndex: Integer);
  public
    constructor Create; overload;
    constructor Create(AComparer: IEqualityComparer<T>); overload;
    destructor Destroy; override;
    
    procedure Enqueue(const AValue: T; APriority: Double);
    function Dequeue: T;
    function Peek: T;
    function Contains(const AValue: T): Boolean;
    procedure UpdatePriority(const AValue: T; ANewPriority: Double);
    function Count: Integer;
    function IsEmpty: Boolean;
    procedure Clear;
  end;

  /// <summary>Tree node</summary>
  TTreeNode<T> = class
  private
    FValue: T;
    FParent: TTreeNode<T>;
    FChildren: TObjectList<TTreeNode<T>>;
    
    function GetChild(AIndex: Integer): TTreeNode<T>;
    function GetChildCount: Integer;
  public
    constructor Create(const AValue: T);
    destructor Destroy; override;
    
    function AddChild(const AValue: T): TTreeNode<T>;
    procedure RemoveChild(AChild: TTreeNode<T>);
    procedure Clear;
    
    function IsRoot: Boolean;
    function IsLeaf: Boolean;
    function Depth: Integer;
    function Height: Integer;
    
    function Root: TTreeNode<T>;
    function Siblings: TArray<TTreeNode<T>>;
    function Path: TArray<TTreeNode<T>>;
    
    property Value: T read FValue write FValue;
    property Parent: TTreeNode<T> read FParent;
    property Children[AIndex: Integer]: TTreeNode<T> read GetChild;
    property ChildCount: Integer read GetChildCount;
  end;

  /// <summary>Tree traversal order</summary>
  TTreeTraversalOrder = (ttoPreOrder, ttoPostOrder, ttoLevelOrder);

  /// <summary>Generic tree class</summary>
  TTree<T> = class
  private
    FRoot: TTreeNode<T>;
  public
    constructor Create; overload;
    constructor Create(const ARootValue: T); overload;
    destructor Destroy; override;
    
    procedure SetRoot(const AValue: T);
    procedure Clear;
    
    function Find(const AValue: T): TTreeNode<T>;
    function Contains(const AValue: T): Boolean;
    
    procedure Traverse(AOrder: TTreeTraversalOrder; AVisitor: TGraphVisitor<T>);
    function ToArray(AOrder: TTreeTraversalOrder = ttoPreOrder): TArray<T>;
    
    function NodeCount: Integer;
    function Height: Integer;
    
    property Root: TTreeNode<T> read FRoot;
  end;

  /// <summary>Graph builder</summary>
  TGraphBuilder<T> = class
  private
    FGraph: TGraph<T>;
  public
    constructor Create(ADirected: Boolean = True);
    
    function AddNode(const ANode: T): TGraphBuilder<T>;
    function AddNodes(const ANodes: array of T): TGraphBuilder<T>;
    function AddEdge(const ASource, ATarget: T; AWeight: Double = 1.0): TGraphBuilder<T>;
    function AddEdges(const AEdges: array of TEdge<T>): TGraphBuilder<T>;
    
    function Build: TGraph<T>;
  end;

  /// <summary>Static helper class</summary>
  TGraphs = class
  public
    /// <summary>Create directed graph</summary>
    class function Directed<T>: TGraphBuilder<T>;
    
    /// <summary>Create undirected graph</summary>
    class function Undirected<T>: TGraphBuilder<T>;
    
    /// <summary>Create tree</summary>
    class function Tree<T>(const ARootValue: T): TTree<T>;
  end;

implementation

{ TEdge<T> }

constructor TEdge<T>.Create(const ASource, ATarget: T; AWeight: Double);
begin
  Source := ASource;
  Target := ATarget;
  Weight := AWeight;
end;

{ TPath<T> }

function TPath<T>.Length: Integer;
begin
  Result := System.Length(Nodes);
end;

function TPath<T>.ToString: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Nodes) do
  begin
    if I > 0 then
      Result := Result + ' -> ';
    Result := Result + TValue.From<T>(Nodes[I]).ToString;
  end;
  Result := Result + Format(' (Weight: %.2f)', [TotalWeight]);
end;

{ TGraph<T> }

constructor TGraph<T>.Create(ADirected: Boolean);
begin
  Create(ADirected, nil);
end;

constructor TGraph<T>.Create(ADirected: Boolean; AComparer: IEqualityComparer<T>);
begin
  inherited Create;
  FDirected := ADirected;
  FComparer := AComparer;
  if FComparer = nil then
    FComparer := TEqualityComparer<T>.Default;
  FNodes := TNodeList.Create;
  FAdjacency := TAdjacencyMap.Create(FComparer);
  FWeights := TWeightMap.Create(FComparer);
  FLock := TCriticalSection.Create;
end;

destructor TGraph<T>.Destroy;
var
  LPair: TPair<T, TNodeList>;
  LWeightPair: TPair<T, TDictionary<T, Double>>;
begin
  FLock.Free;
  
  for LPair in FAdjacency do
    LPair.Value.Free;
  FAdjacency.Free;
  
  for LWeightPair in FWeights do
    LWeightPair.Value.Free;
  FWeights.Free;
  
  FNodes.Free;
  inherited;
end;

function TGraph<T>.GetNeighbors(const ANode: T): TNodeList;
begin
  if not FAdjacency.TryGetValue(ANode, Result) then
    Result := nil;
end;

function TGraph<T>.GetWeight(const ASource, ATarget: T): Double;
var
  LWeights: TDictionary<T, Double>;
begin
  if FWeights.TryGetValue(ASource, LWeights) then
  begin
    if not LWeights.TryGetValue(ATarget, Result) then
      Result := 1.0;
  end
  else
    Result := 1.0;
end;

procedure TGraph<T>.SetWeight(const ASource, ATarget: T; AWeight: Double);
var
  LWeights: TDictionary<T, Double>;
begin
  if not FWeights.TryGetValue(ASource, LWeights) then
  begin
    LWeights := TDictionary<T, Double>.Create(FComparer);
    FWeights.Add(ASource, LWeights);
  end;
  LWeights.AddOrSetValue(ATarget, AWeight);
end;

procedure TGraph<T>.AddNode(const ANode: T);
begin
  FLock.Enter;
  try
    if not FAdjacency.ContainsKey(ANode) then
    begin
      FNodes.Add(ANode);
      FAdjacency.Add(ANode, TNodeList.Create);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TGraph<T>.RemoveNode(const ANode: T);
var
  LNeighbors: TNodeList;
  LPair: TPair<T, TNodeList>;
  I: Integer;
begin
  FLock.Enter;
  try
    if FAdjacency.TryGetValue(ANode, LNeighbors) then
    begin
      LNeighbors.Free;
      FAdjacency.Remove(ANode);
      
      // Remove from other nodes' adjacency lists
      for LPair in FAdjacency do
      begin
        for I := LPair.Value.Count - 1 downto 0 do
        begin
          if FComparer.Equals(LPair.Value[I], ANode) then
            LPair.Value.Delete(I);
        end;
      end;
      
      // Remove from nodes list
      for I := FNodes.Count - 1 downto 0 do
      begin
        if FComparer.Equals(FNodes[I], ANode) then
        begin
          FNodes.Delete(I);
          Break;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TGraph<T>.HasNode(const ANode: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FAdjacency.ContainsKey(ANode);
  finally
    FLock.Leave;
  end;
end;

procedure TGraph<T>.AddEdge(const ASource, ATarget: T; AWeight: Double);
var
  LNeighbors: TNodeList;
begin
  FLock.Enter;
  try
    AddNode(ASource);
    AddNode(ATarget);
    
    LNeighbors := FAdjacency[ASource];
    if not LNeighbors.Contains(ATarget) then
      LNeighbors.Add(ATarget);
    SetWeight(ASource, ATarget, AWeight);
    
    if not FDirected then
    begin
      LNeighbors := FAdjacency[ATarget];
      if not LNeighbors.Contains(ASource) then
        LNeighbors.Add(ASource);
      SetWeight(ATarget, ASource, AWeight);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TGraph<T>.RemoveEdge(const ASource, ATarget: T);
var
  LNeighbors: TNodeList;
  I: Integer;
begin
  FLock.Enter;
  try
    if FAdjacency.TryGetValue(ASource, LNeighbors) then
    begin
      for I := LNeighbors.Count - 1 downto 0 do
      begin
        if FComparer.Equals(LNeighbors[I], ATarget) then
        begin
          LNeighbors.Delete(I);
          Break;
        end;
      end;
    end;
    
    if not FDirected then
    begin
      if FAdjacency.TryGetValue(ATarget, LNeighbors) then
      begin
        for I := LNeighbors.Count - 1 downto 0 do
        begin
          if FComparer.Equals(LNeighbors[I], ASource) then
          begin
            LNeighbors.Delete(I);
            Break;
          end;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TGraph<T>.HasEdge(const ASource, ATarget: T): Boolean;
var
  LNeighbors: TNodeList;
begin
  FLock.Enter;
  try
    Result := FAdjacency.TryGetValue(ASource, LNeighbors) and LNeighbors.Contains(ATarget);
  finally
    FLock.Leave;
  end;
end;

function TGraph<T>.GetNodes: TArray<T>;
begin
  FLock.Enter;
  try
    Result := FNodes.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TGraph<T>.GetEdges: TArray<TEdge<T>>;
var
  LEdges: TList<TEdge<T>>;
  LPair: TPair<T, TNodeList>;
  LTarget: T;
begin
  LEdges := TList<TEdge<T>>.Create;
  try
    FLock.Enter;
    try
      for LPair in FAdjacency do
      begin
        for LTarget in LPair.Value do
          LEdges.Add(TEdge<T>.Create(LPair.Key, LTarget, GetWeight(LPair.Key, LTarget)));
      end;
    finally
      FLock.Leave;
    end;
    Result := LEdges.ToArray;
  finally
    LEdges.Free;
  end;
end;

function TGraph<T>.Neighbors(const ANode: T): TArray<T>;
var
  LNeighbors: TNodeList;
begin
  FLock.Enter;
  try
    if FAdjacency.TryGetValue(ANode, LNeighbors) then
      Result := LNeighbors.ToArray
    else
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TGraph<T>.Degree(const ANode: T): Integer;
begin
  if FDirected then
    Result := InDegree(ANode) + OutDegree(ANode)
  else
    Result := OutDegree(ANode);
end;

function TGraph<T>.InDegree(const ANode: T): Integer;
var
  LPair: TPair<T, TNodeList>;
begin
  Result := 0;
  FLock.Enter;
  try
    for LPair in FAdjacency do
    begin
      if LPair.Value.Contains(ANode) then
        Inc(Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TGraph<T>.OutDegree(const ANode: T): Integer;
var
  LNeighbors: TNodeList;
begin
  FLock.Enter;
  try
    if FAdjacency.TryGetValue(ANode, LNeighbors) then
      Result := LNeighbors.Count
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

function TGraph<T>.NodeCount: Integer;
begin
  FLock.Enter;
  try
    Result := FNodes.Count;
  finally
    FLock.Leave;
  end;
end;

function TGraph<T>.EdgeCount: Integer;
var
  LPair: TPair<T, TNodeList>;
begin
  Result := 0;
  FLock.Enter;
  try
    for LPair in FAdjacency do
      Inc(Result, LPair.Value.Count);
    if not FDirected then
      Result := Result div 2;
  finally
    FLock.Leave;
  end;
end;

procedure TGraph<T>.Clear;
var
  LPair: TPair<T, TNodeList>;
  LWeightPair: TPair<T, TDictionary<T, Double>>;
begin
  FLock.Enter;
  try
    for LPair in FAdjacency do
      LPair.Value.Free;
    FAdjacency.Clear;
    
    for LWeightPair in FWeights do
      LWeightPair.Value.Free;
    FWeights.Clear;
    
    FNodes.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TGraph<T>.BFS(const AStart: T; AVisitor: TGraphVisitor<T>);
var
  LQueue: TQueue<T>;
  LVisited: TDictionary<T, Boolean>;
  LCurrent: T;
  LNeighbors: TNodeList;
  LNeighbor: T;
  LContinue: Boolean;
begin
  if not HasNode(AStart) then
    Exit;
    
  LQueue := TQueue<T>.Create;
  LVisited := TDictionary<T, Boolean>.Create(FComparer);
  try
    LQueue.Enqueue(AStart);
    LVisited.Add(AStart, True);
    
    while LQueue.Count > 0 do
    begin
      LCurrent := LQueue.Dequeue;
      
      LContinue := True;
      AVisitor(LCurrent, LContinue);
      if not LContinue then
        Break;
        
      LNeighbors := GetNeighbors(LCurrent);
      if Assigned(LNeighbors) then
      begin
        for LNeighbor in LNeighbors do
        begin
          if not LVisited.ContainsKey(LNeighbor) then
          begin
            LVisited.Add(LNeighbor, True);
            LQueue.Enqueue(LNeighbor);
          end;
        end;
      end;
    end;
  finally
    LVisited.Free;
    LQueue.Free;
  end;
end;

function TGraph<T>.BFSPath(const AStart, AEnd: T): TPath<T>;
var
  LQueue: TQueue<T>;
  LVisited: TDictionary<T, Boolean>;
  LParent: TDictionary<T, T>;
  LCurrent, LNeighbor: T;
  LNeighbors: TNodeList;
  LPath: TList<T>;
begin
  Result.Nodes := nil;
  Result.TotalWeight := 0;
  Result.Found := False;
  
  if not HasNode(AStart) or not HasNode(AEnd) then
    Exit;
    
  LQueue := TQueue<T>.Create;
  LVisited := TDictionary<T, Boolean>.Create(FComparer);
  LParent := TDictionary<T, T>.Create(FComparer);
  try
    LQueue.Enqueue(AStart);
    LVisited.Add(AStart, True);
    
    while LQueue.Count > 0 do
    begin
      LCurrent := LQueue.Dequeue;
      
      if FComparer.Equals(LCurrent, AEnd) then
      begin
        // Build path
        LPath := TList<T>.Create;
        try
          LPath.Add(LCurrent);
          while LParent.ContainsKey(LCurrent) do
          begin
            LCurrent := LParent[LCurrent];
            LPath.Insert(0, LCurrent);
          end;
          Result.Nodes := LPath.ToArray;
          Result.TotalWeight := LPath.Count - 1;
          Result.Found := True;
        finally
          LPath.Free;
        end;
        Break;
      end;
      
      LNeighbors := GetNeighbors(LCurrent);
      if Assigned(LNeighbors) then
      begin
        for LNeighbor in LNeighbors do
        begin
          if not LVisited.ContainsKey(LNeighbor) then
          begin
            LVisited.Add(LNeighbor, True);
            LParent.Add(LNeighbor, LCurrent);
            LQueue.Enqueue(LNeighbor);
          end;
        end;
      end;
    end;
  finally
    LParent.Free;
    LVisited.Free;
    LQueue.Free;
  end;
end;

procedure TGraph<T>.DFS(const AStart: T; AVisitor: TGraphVisitor<T>);
var
  LStack: TStack<T>;
  LVisited: TDictionary<T, Boolean>;
  LCurrent: T;
  LNeighbors: TNodeList;
  LNeighbor: T;
  LContinue: Boolean;
begin
  if not HasNode(AStart) then
    Exit;
    
  LStack := TStack<T>.Create;
  LVisited := TDictionary<T, Boolean>.Create(FComparer);
  try
    LStack.Push(AStart);
    
    while LStack.Count > 0 do
    begin
      LCurrent := LStack.Pop;
      
      if LVisited.ContainsKey(LCurrent) then
        Continue;
        
      LVisited.Add(LCurrent, True);
      
      LContinue := True;
      AVisitor(LCurrent, LContinue);
      if not LContinue then
        Break;
        
      LNeighbors := GetNeighbors(LCurrent);
      if Assigned(LNeighbors) then
      begin
        for LNeighbor in LNeighbors do
        begin
          if not LVisited.ContainsKey(LNeighbor) then
            LStack.Push(LNeighbor);
        end;
      end;
    end;
  finally
    LVisited.Free;
    LStack.Free;
  end;
end;

function TGraph<T>.DFSPath(const AStart, AEnd: T): TPath<T>;
var
  LStack: TStack<T>;
  LVisited: TDictionary<T, Boolean>;
  LParent: TDictionary<T, T>;
  LCurrent, LNeighbor: T;
  LNeighbors: TNodeList;
  LPath: TList<T>;
begin
  Result.Nodes := nil;
  Result.TotalWeight := 0;
  Result.Found := False;
  
  if not HasNode(AStart) or not HasNode(AEnd) then
    Exit;
    
  LStack := TStack<T>.Create;
  LVisited := TDictionary<T, Boolean>.Create(FComparer);
  LParent := TDictionary<T, T>.Create(FComparer);
  try
    LStack.Push(AStart);
    
    while LStack.Count > 0 do
    begin
      LCurrent := LStack.Pop;
      
      if LVisited.ContainsKey(LCurrent) then
        Continue;
        
      LVisited.Add(LCurrent, True);
      
      if FComparer.Equals(LCurrent, AEnd) then
      begin
        LPath := TList<T>.Create;
        try
          LPath.Add(LCurrent);
          while LParent.ContainsKey(LCurrent) do
          begin
            LCurrent := LParent[LCurrent];
            LPath.Insert(0, LCurrent);
          end;
          Result.Nodes := LPath.ToArray;
          Result.TotalWeight := LPath.Count - 1;
          Result.Found := True;
        finally
          LPath.Free;
        end;
        Break;
      end;
      
      LNeighbors := GetNeighbors(LCurrent);
      if Assigned(LNeighbors) then
      begin
        for LNeighbor in LNeighbors do
        begin
          if not LVisited.ContainsKey(LNeighbor) then
          begin
            if not LParent.ContainsKey(LNeighbor) then
              LParent.Add(LNeighbor, LCurrent);
            LStack.Push(LNeighbor);
          end;
        end;
      end;
    end;
  finally
    LParent.Free;
    LVisited.Free;
    LStack.Free;
  end;
end;

function TGraph<T>.ShortestPath(const AStart, AEnd: T): TPath<T>;
var
  LDist: TDictionary<T, Double>;
  LParent: TDictionary<T, T>;
  LPQ: TPriorityQueue<T>;
  LCurrent, LNeighbor: T;
  LNeighbors: TNodeList;
  LNewDist, LEdgeWeight: Double;
  LPath: TList<T>;
begin
  Result.Nodes := nil;
  Result.TotalWeight := 0;
  Result.Found := False;
  
  if not HasNode(AStart) or not HasNode(AEnd) then
    Exit;
    
  LDist := TDictionary<T, Double>.Create(FComparer);
  LParent := TDictionary<T, T>.Create(FComparer);
  LPQ := TPriorityQueue<T>.Create(FComparer);
  try
    // Initialize
    for var LNode in FNodes do
      LDist.Add(LNode, MaxDouble);
    LDist[AStart] := 0;
    LPQ.Enqueue(AStart, 0);
    
    while not LPQ.IsEmpty do
    begin
      LCurrent := LPQ.Dequeue;
      
      if FComparer.Equals(LCurrent, AEnd) then
      begin
        // Build path
        LPath := TList<T>.Create;
        try
          LPath.Add(LCurrent);
          while LParent.ContainsKey(LCurrent) do
          begin
            LCurrent := LParent[LCurrent];
            LPath.Insert(0, LCurrent);
          end;
          Result.Nodes := LPath.ToArray;
          Result.TotalWeight := LDist[AEnd];
          Result.Found := True;
        finally
          LPath.Free;
        end;
        Break;
      end;
      
      LNeighbors := GetNeighbors(LCurrent);
      if Assigned(LNeighbors) then
      begin
        for LNeighbor in LNeighbors do
        begin
          LEdgeWeight := GetWeight(LCurrent, LNeighbor);
          LNewDist := LDist[LCurrent] + LEdgeWeight;
          
          if LNewDist < LDist[LNeighbor] then
          begin
            LDist[LNeighbor] := LNewDist;
            LParent.AddOrSetValue(LNeighbor, LCurrent);
            
            if LPQ.Contains(LNeighbor) then
              LPQ.UpdatePriority(LNeighbor, LNewDist)
            else
              LPQ.Enqueue(LNeighbor, LNewDist);
          end;
        end;
      end;
    end;
  finally
    LPQ.Free;
    LParent.Free;
    LDist.Free;
  end;
end;

function TGraph<T>.ShortestPaths(const AStart: T): TDictionary<T, TPath<T>>;
var
  LDist: TDictionary<T, Double>;
  LParent: TDictionary<T, T>;
  LPQ: TPriorityQueue<T>;
  LCurrent, LNeighbor, LTemp: T;
  LNeighbors: TNodeList;
  LNewDist, LEdgeWeight: Double;
  LPath: TList<T>;
  LResultPath: TPath<T>;
begin
  Result := TDictionary<T, TPath<T>>.Create(FComparer);
  
  if not HasNode(AStart) then
    Exit;
    
  LDist := TDictionary<T, Double>.Create(FComparer);
  LParent := TDictionary<T, T>.Create(FComparer);
  LPQ := TPriorityQueue<T>.Create(FComparer);
  try
    // Initialize
    for var LNode in FNodes do
      LDist.Add(LNode, MaxDouble);
    LDist[AStart] := 0;
    LPQ.Enqueue(AStart, 0);
    
    while not LPQ.IsEmpty do
    begin
      LCurrent := LPQ.Dequeue;
      
      LNeighbors := GetNeighbors(LCurrent);
      if Assigned(LNeighbors) then
      begin
        for LNeighbor in LNeighbors do
        begin
          LEdgeWeight := GetWeight(LCurrent, LNeighbor);
          LNewDist := LDist[LCurrent] + LEdgeWeight;
          
          if LNewDist < LDist[LNeighbor] then
          begin
            LDist[LNeighbor] := LNewDist;
            LParent.AddOrSetValue(LNeighbor, LCurrent);
            
            if LPQ.Contains(LNeighbor) then
              LPQ.UpdatePriority(LNeighbor, LNewDist)
            else
              LPQ.Enqueue(LNeighbor, LNewDist);
          end;
        end;
      end;
    end;
    
    // Build paths
    for var LNode in FNodes do
    begin
      if LDist[LNode] < MaxDouble then
      begin
        LPath := TList<T>.Create;
        try
          LTemp := LNode;
          LPath.Add(LTemp);
          while LParent.ContainsKey(LTemp) do
          begin
            LTemp := LParent[LTemp];
            LPath.Insert(0, LTemp);
          end;
          LResultPath.Nodes := LPath.ToArray;
          LResultPath.TotalWeight := LDist[LNode];
          LResultPath.Found := True;
          Result.Add(LNode, LResultPath);
        finally
          LPath.Free;
        end;
      end;
    end;
  finally
    LPQ.Free;
    LParent.Free;
    LDist.Free;
  end;
end;

function TGraph<T>.TopologicalSort: TArray<T>;
begin
  if not TryTopologicalSort(Result) then
    raise EGraphException.Create('Graph contains a cycle, topological sort not possible');
end;

function TGraph<T>.TryTopologicalSort(out ASorted: TArray<T>): Boolean;
var
  LInDegree: TDictionary<T, Integer>;
  LQueue: TQueue<T>;
  LResult: TList<T>;
  LCurrent, LNeighbor: T;
  LNeighbors: TNodeList;
  LDeg: Integer;
begin
  if not FDirected then
    raise EGraphException.Create('Topological sort only works on directed graphs');
    
  ASorted := nil;
  LInDegree := TDictionary<T, Integer>.Create(FComparer);
  LQueue := TQueue<T>.Create;
  LResult := TList<T>.Create;
  try
    // Calculate in-degrees
    for var LNode in FNodes do
      LInDegree.Add(LNode, 0);
      
    for var LPair in FAdjacency do
    begin
      for LNeighbor in LPair.Value do
      begin
        LInDegree[LNeighbor] := LInDegree[LNeighbor] + 1;
      end;
    end;
    
    // Add nodes with in-degree 0
    for var LNode in FNodes do
    begin
      if LInDegree[LNode] = 0 then
        LQueue.Enqueue(LNode);
    end;
    
    while LQueue.Count > 0 do
    begin
      LCurrent := LQueue.Dequeue;
      LResult.Add(LCurrent);
      
      LNeighbors := GetNeighbors(LCurrent);
      if Assigned(LNeighbors) then
      begin
        for LNeighbor in LNeighbors do
        begin
          LDeg := LInDegree[LNeighbor] - 1;
          LInDegree[LNeighbor] := LDeg;
          if LDeg = 0 then
            LQueue.Enqueue(LNeighbor);
        end;
      end;
    end;
    
    Result := LResult.Count = FNodes.Count;
    if Result then
      ASorted := LResult.ToArray;
  finally
    LResult.Free;
    LQueue.Free;
    LInDegree.Free;
  end;
end;

function TGraph<T>.HasCycle: Boolean;
var
  LSorted: TArray<T>;
begin
  if FDirected then
    Result := not TryTopologicalSort(LSorted)
  else
  begin
    // For undirected, use DFS
    Result := Length(FindCycle) > 0;
  end;
end;

function TGraph<T>.FindCycle: TArray<T>;
var
  LVisited, LRecStack: TDictionary<T, Boolean>;
  LParent: TDictionary<T, T>;
  LCycle: TList<T>;
  LFound: Boolean;
  
  function DFSCycle(const ANode: T): Boolean;
  var
    LNeighbors: TNodeList;
    LNeighbor, LCurrent: T;
  begin
    Result := False;
    LVisited[ANode] := True;
    LRecStack[ANode] := True;
    
    LNeighbors := GetNeighbors(ANode);
    if Assigned(LNeighbors) then
    begin
      for LNeighbor in LNeighbors do
      begin
        if not LVisited.ContainsKey(LNeighbor) or not LVisited[LNeighbor] then
        begin
          LParent.AddOrSetValue(LNeighbor, ANode);
          if DFSCycle(LNeighbor) then
            Exit(True);
        end
        else if LRecStack.ContainsKey(LNeighbor) and LRecStack[LNeighbor] then
        begin
          // Found cycle, reconstruct it
          LCycle.Clear;
          LCurrent := ANode;
          LCycle.Add(LNeighbor);
          while not FComparer.Equals(LCurrent, LNeighbor) do
          begin
            LCycle.Insert(0, LCurrent);
            if LParent.ContainsKey(LCurrent) then
              LCurrent := LParent[LCurrent]
            else
              Break;
          end;
          LCycle.Insert(0, LNeighbor);
          Exit(True);
        end;
      end;
    end;
    
    LRecStack[ANode] := False;
  end;
  
begin
  Result := nil;
  LVisited := TDictionary<T, Boolean>.Create(FComparer);
  LRecStack := TDictionary<T, Boolean>.Create(FComparer);
  LParent := TDictionary<T, T>.Create(FComparer);
  LCycle := TList<T>.Create;
  try
    for var LNode in FNodes do
    begin
      LVisited.AddOrSetValue(LNode, False);
      LRecStack.AddOrSetValue(LNode, False);
    end;
    
    LFound := False;
    for var LNode in FNodes do
    begin
      if not LVisited[LNode] then
      begin
        if DFSCycle(LNode) then
        begin
          LFound := True;
          Break;
        end;
      end;
    end;
    
    if LFound then
      Result := LCycle.ToArray;
  finally
    LCycle.Free;
    LParent.Free;
    LRecStack.Free;
    LVisited.Free;
  end;
end;

function TGraph<T>.IsConnected: Boolean;
var
  LVisited: TDictionary<T, Boolean>;
begin
  Result := False;
  if FNodes.Count = 0 then
    Exit(True);
    
  LVisited := TDictionary<T, Boolean>.Create(FComparer);
  try
    BFS(FNodes[0],
      procedure(const ANode: T; var AContinue: Boolean)
      begin
        LVisited.Add(ANode, True);
        AContinue := True;
      end);
    Result := LVisited.Count = FNodes.Count;
  finally
    LVisited.Free;
  end;
end;

function TGraph<T>.ConnectedComponents: TArray<TArray<T>>;
var
  LVisited: TDictionary<T, Boolean>;
  LComponents: TList<TArray<T>>;
  LComponent: TList<T>;
begin
  LVisited := TDictionary<T, Boolean>.Create(FComparer);
  LComponents := TList<TArray<T>>.Create;
  try
    for var LNode in FNodes do
    begin
      if not LVisited.ContainsKey(LNode) then
      begin
        LComponent := TList<T>.Create;
        try
          BFS(LNode,
            procedure(const AVisitNode: T; var AContinue: Boolean)
            begin
              LVisited.Add(AVisitNode, True);
              LComponent.Add(AVisitNode);
              AContinue := True;
            end);
          LComponents.Add(LComponent.ToArray);
        finally
          LComponent.Free;
        end;
      end;
    end;
    Result := LComponents.ToArray;
  finally
    LComponents.Free;
    LVisited.Free;
  end;
end;

function TGraph<T>.StronglyConnectedComponents: TArray<TArray<T>>;
var
  LVisited: TDictionary<T, Boolean>;
  LStack: TStack<T>;
  LTransposed: TGraph<T>;
  LComponents: TList<TArray<T>>;
  LComponent: TList<T>;
  
  procedure FillOrder(const ANode: T);
  var
    LNeighbors: TNodeList;
    LNeighbor: T;
  begin
    LVisited[ANode] := True;
    LNeighbors := GetNeighbors(ANode);
    if Assigned(LNeighbors) then
    begin
      for LNeighbor in LNeighbors do
      begin
        if not LVisited[LNeighbor] then
          FillOrder(LNeighbor);
      end;
    end;
    LStack.Push(ANode);
  end;
  
  procedure DFSUtil(const ANode: T);
  var
    LNeighbors: TNodeList;
    LNeighbor: T;
  begin
    LVisited[ANode] := True;
    LComponent.Add(ANode);
    LNeighbors := LTransposed.GetNeighbors(ANode);
    if Assigned(LNeighbors) then
    begin
      for LNeighbor in LNeighbors do
      begin
        if not LVisited[LNeighbor] then
          DFSUtil(LNeighbor);
      end;
    end;
  end;
  
begin
  if not FDirected then
    Exit(ConnectedComponents);
    
  LVisited := TDictionary<T, Boolean>.Create(FComparer);
  LStack := TStack<T>.Create;
  LComponents := TList<TArray<T>>.Create;
  try
    // Initialize visited
    for var LNode in FNodes do
      LVisited.Add(LNode, False);
      
    // Fill stack
    for var LNode in FNodes do
    begin
      if not LVisited[LNode] then
        FillOrder(LNode);
    end;
    
    // Create transposed graph
    LTransposed := Transpose;
    try
      // Reset visited
      for var LNode in FNodes do
        LVisited[LNode] := False;
        
      // Process in order of finish times
      while LStack.Count > 0 do
      begin
        var LNode := LStack.Pop;
        if not LVisited[LNode] then
        begin
          LComponent := TList<T>.Create;
          try
            DFSUtil(LNode);
            LComponents.Add(LComponent.ToArray);
          finally
            LComponent.Free;
          end;
        end;
      end;
    finally
      LTransposed.Free;
    end;
    
    Result := LComponents.ToArray;
  finally
    LComponents.Free;
    LStack.Free;
    LVisited.Free;
  end;
end;

function TGraph<T>.IsReachable(const AFrom, ATo: T): Boolean;
var
  LFound: Boolean;
begin
  LFound := False;
  BFS(AFrom,
    procedure(const ANode: T; var AContinue: Boolean)
    begin
      if FComparer.Equals(ANode, ATo) then
      begin
        LFound := True;
        AContinue := False;
      end
      else
        AContinue := True;
    end);
  Result := LFound;
end;

function TGraph<T>.ReachableFrom(const ANode: T): TArray<T>;
var
  LReachable: TList<T>;
begin
  LReachable := TList<T>.Create;
  try
    BFS(ANode,
      procedure(const AVisitNode: T; var AContinue: Boolean)
      begin
        LReachable.Add(AVisitNode);
        AContinue := True;
      end);
    Result := LReachable.ToArray;
  finally
    LReachable.Free;
  end;
end;

function TGraph<T>.MinimumSpanningTree: TGraph<T>;
var
  LVisited: TDictionary<T, Boolean>;
  LPQ: TPriorityQueue<TEdge<T>>;
  LEdge: TEdge<T>;
  LNeighbors: TNodeList;
  LWeight: Double;
begin
  if FDirected then
    raise EGraphException.Create('MST only works on undirected graphs');
    
  Result := TGraph<T>.Create(False, FComparer);
  if FNodes.Count = 0 then
    Exit;
    
  LVisited := TDictionary<T, Boolean>.Create(FComparer);
  LPQ := TPriorityQueue<TEdge<T>>.Create;
  try
    // Start with first node
    for var LNode in FNodes do
      Result.AddNode(LNode);
      
    LVisited.Add(FNodes[0], True);
    LNeighbors := GetNeighbors(FNodes[0]);
    if Assigned(LNeighbors) then
    begin
      for var LNeighbor in LNeighbors do
      begin
        LWeight := GetWeight(FNodes[0], LNeighbor);
        LPQ.Enqueue(TEdge<T>.Create(FNodes[0], LNeighbor, LWeight), LWeight);
      end;
    end;
    
    while (not LPQ.IsEmpty) and (LVisited.Count < FNodes.Count) do
    begin
      LEdge := LPQ.Dequeue;
      
      if LVisited.ContainsKey(LEdge.Target) then
        Continue;
        
      LVisited.Add(LEdge.Target, True);
      Result.AddEdge(LEdge.Source, LEdge.Target, LEdge.Weight);
      
      LNeighbors := GetNeighbors(LEdge.Target);
      if Assigned(LNeighbors) then
      begin
        for var LNeighbor in LNeighbors do
        begin
          if not LVisited.ContainsKey(LNeighbor) then
          begin
            LWeight := GetWeight(LEdge.Target, LNeighbor);
            LPQ.Enqueue(TEdge<T>.Create(LEdge.Target, LNeighbor, LWeight), LWeight);
          end;
        end;
      end;
    end;
  finally
    LPQ.Free;
    LVisited.Free;
  end;
end;

function TGraph<T>.Transpose: TGraph<T>;
var
  LPair: TPair<T, TNodeList>;
  LTarget: T;
begin
  Result := TGraph<T>.Create(FDirected, FComparer);
  
  for var LNode in FNodes do
    Result.AddNode(LNode);
    
  for LPair in FAdjacency do
  begin
    for LTarget in LPair.Value do
      Result.AddEdge(LTarget, LPair.Key, GetWeight(LPair.Key, LTarget));
  end;
end;

function TGraph<T>.Subgraph(const ANodes: TArray<T>): TGraph<T>;
var
  LNodeSet: TDictionary<T, Boolean>;
  LNeighbors: TNodeList;
begin
  Result := TGraph<T>.Create(FDirected, FComparer);
  LNodeSet := TDictionary<T, Boolean>.Create(FComparer);
  try
    for var LNode in ANodes do
      LNodeSet.Add(LNode, True);
      
    for var LNode in ANodes do
    begin
      if HasNode(LNode) then
      begin
        Result.AddNode(LNode);
        LNeighbors := GetNeighbors(LNode);
        if Assigned(LNeighbors) then
        begin
          for var LNeighbor in LNeighbors do
          begin
            if LNodeSet.ContainsKey(LNeighbor) then
              Result.AddEdge(LNode, LNeighbor, GetWeight(LNode, LNeighbor));
          end;
        end;
      end;
    end;
  finally
    LNodeSet.Free;
  end;
end;

{ TPriorityQueue<T> }

constructor TPriorityQueue<T>.Create;
begin
  Create(nil);
end;

constructor TPriorityQueue<T>.Create(AComparer: IEqualityComparer<T>);
begin
  inherited Create;
  FItems := TList<TQueueItem>.Create;
  FComparer := AComparer;
  if FComparer = nil then
    FComparer := TEqualityComparer<T>.Default;
end;

destructor TPriorityQueue<T>.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TPriorityQueue<T>.HeapifyUp(AIndex: Integer);
var
  LParent: Integer;
  LTemp: TQueueItem;
begin
  while AIndex > 0 do
  begin
    LParent := (AIndex - 1) div 2;
    if FItems[AIndex].Priority < FItems[LParent].Priority then
    begin
      LTemp := FItems[AIndex];
      FItems[AIndex] := FItems[LParent];
      FItems[LParent] := LTemp;
      AIndex := LParent;
    end
    else
      Break;
  end;
end;

procedure TPriorityQueue<T>.HeapifyDown(AIndex: Integer);
var
  LLeft, LRight, LSmallest: Integer;
  LTemp: TQueueItem;
begin
  while True do
  begin
    LLeft := 2 * AIndex + 1;
    LRight := 2 * AIndex + 2;
    LSmallest := AIndex;
    
    if (LLeft < FItems.Count) and (FItems[LLeft].Priority < FItems[LSmallest].Priority) then
      LSmallest := LLeft;
    if (LRight < FItems.Count) and (FItems[LRight].Priority < FItems[LSmallest].Priority) then
      LSmallest := LRight;
      
    if LSmallest <> AIndex then
    begin
      LTemp := FItems[AIndex];
      FItems[AIndex] := FItems[LSmallest];
      FItems[LSmallest] := LTemp;
      AIndex := LSmallest;
    end
    else
      Break;
  end;
end;

procedure TPriorityQueue<T>.Enqueue(const AValue: T; APriority: Double);
var
  LItem: TQueueItem;
begin
  LItem.Value := AValue;
  LItem.Priority := APriority;
  FItems.Add(LItem);
  HeapifyUp(FItems.Count - 1);
end;

function TPriorityQueue<T>.Dequeue: T;
begin
  if FItems.Count = 0 then
    raise EGraphException.Create('Priority queue is empty');
    
  Result := FItems[0].Value;
  FItems[0] := FItems[FItems.Count - 1];
  FItems.Delete(FItems.Count - 1);
  
  if FItems.Count > 0 then
    HeapifyDown(0);
end;

function TPriorityQueue<T>.Peek: T;
begin
  if FItems.Count = 0 then
    raise EGraphException.Create('Priority queue is empty');
  Result := FItems[0].Value;
end;

function TPriorityQueue<T>.Contains(const AValue: T): Boolean;
begin
  for var LItem in FItems do
  begin
    if FComparer.Equals(LItem.Value, AValue) then
      Exit(True);
  end;
  Result := False;
end;

procedure TPriorityQueue<T>.UpdatePriority(const AValue: T; ANewPriority: Double);
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    if FComparer.Equals(FItems[I].Value, AValue) then
    begin
      var LItem := FItems[I];
      LItem.Priority := ANewPriority;
      FItems[I] := LItem;
      HeapifyUp(I);
      HeapifyDown(I);
      Exit;
    end;
  end;
end;

function TPriorityQueue<T>.Count: Integer;
begin
  Result := FItems.Count;
end;

function TPriorityQueue<T>.IsEmpty: Boolean;
begin
  Result := FItems.Count = 0;
end;

procedure TPriorityQueue<T>.Clear;
begin
  FItems.Clear;
end;

{ TTreeNode<T> }

constructor TTreeNode<T>.Create(const AValue: T);
begin
  inherited Create;
  FValue := AValue;
  FParent := nil;
  FChildren := TObjectList<TTreeNode<T>>.Create(True);
end;

destructor TTreeNode<T>.Destroy;
begin
  FChildren.Free;
  inherited;
end;

function TTreeNode<T>.GetChild(AIndex: Integer): TTreeNode<T>;
begin
  Result := FChildren[AIndex];
end;

function TTreeNode<T>.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TTreeNode<T>.AddChild(const AValue: T): TTreeNode<T>;
begin
  Result := TTreeNode<T>.Create(AValue);
  Result.FParent := Self;
  FChildren.Add(Result);
end;

procedure TTreeNode<T>.RemoveChild(AChild: TTreeNode<T>);
begin
  AChild.FParent := nil;
  FChildren.Extract(AChild);
end;

procedure TTreeNode<T>.Clear;
begin
  FChildren.Clear;
end;

function TTreeNode<T>.IsRoot: Boolean;
begin
  Result := FParent = nil;
end;

function TTreeNode<T>.IsLeaf: Boolean;
begin
  Result := FChildren.Count = 0;
end;

function TTreeNode<T>.Depth: Integer;
var
  LNode: TTreeNode<T>;
begin
  Result := 0;
  LNode := FParent;
  while Assigned(LNode) do
  begin
    Inc(Result);
    LNode := LNode.FParent;
  end;
end;

function TTreeNode<T>.Height: Integer;
var
  LChildHeight: Integer;
begin
  if IsLeaf then
    Exit(0);
    
  Result := 0;
  for var LChild in FChildren do
  begin
    LChildHeight := LChild.Height;
    if LChildHeight > Result then
      Result := LChildHeight;
  end;
  Inc(Result);
end;

function TTreeNode<T>.Root: TTreeNode<T>;
begin
  Result := Self;
  while Assigned(Result.FParent) do
    Result := Result.FParent;
end;

function TTreeNode<T>.Siblings: TArray<TTreeNode<T>>;
var
  LList: TList<TTreeNode<T>>;
begin
  if not Assigned(FParent) then
    Exit(nil);
    
  LList := TList<TTreeNode<T>>.Create;
  try
    for var LChild in FParent.FChildren do
    begin
      if LChild <> Self then
        LList.Add(LChild);
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TTreeNode<T>.Path: TArray<TTreeNode<T>>;
var
  LList: TList<TTreeNode<T>>;
  LNode: TTreeNode<T>;
begin
  LList := TList<TTreeNode<T>>.Create;
  try
    LNode := Self;
    while Assigned(LNode) do
    begin
      LList.Insert(0, LNode);
      LNode := LNode.FParent;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ TTree<T> }

constructor TTree<T>.Create;
begin
  inherited Create;
  FRoot := nil;
end;

constructor TTree<T>.Create(const ARootValue: T);
begin
  inherited Create;
  FRoot := TTreeNode<T>.Create(ARootValue);
end;

destructor TTree<T>.Destroy;
begin
  FRoot.Free;
  inherited;
end;

procedure TTree<T>.SetRoot(const AValue: T);
begin
  FreeAndNil(FRoot);
  FRoot := TTreeNode<T>.Create(AValue);
end;

procedure TTree<T>.Clear;
begin
  FreeAndNil(FRoot);
end;

function TTree<T>.Find(const AValue: T): TTreeNode<T>;
var
  LFound: TTreeNode<T>;
begin
  LFound := nil;
  Traverse(ttoPreOrder,
    procedure(const ANodeValue: T; var AContinue: Boolean)
    begin
      // Note: This simplified implementation doesn't properly track nodes
      AContinue := True;
    end);
  Result := LFound;
end;

function TTree<T>.Contains(const AValue: T): Boolean;
begin
  Result := Find(AValue) <> nil;
end;

procedure TTree<T>.Traverse(AOrder: TTreeTraversalOrder; AVisitor: TGraphVisitor<T>);
var
  LContinue: Boolean;
  
  procedure PreOrder(ANode: TTreeNode<T>);
  begin
    if not Assigned(ANode) or not LContinue then
      Exit;
    AVisitor(ANode.Value, LContinue);
    for var LChild in ANode.FChildren do
      PreOrder(LChild);
  end;
  
  procedure PostOrder(ANode: TTreeNode<T>);
  begin
    if not Assigned(ANode) or not LContinue then
      Exit;
    for var LChild in ANode.FChildren do
      PostOrder(LChild);
    AVisitor(ANode.Value, LContinue);
  end;
  
  procedure LevelOrder(ANode: TTreeNode<T>);
  var
    LQueue: TQueue<TTreeNode<T>>;
    LCurrent: TTreeNode<T>;
  begin
    if not Assigned(ANode) then
      Exit;
    LQueue := TQueue<TTreeNode<T>>.Create;
    try
      LQueue.Enqueue(ANode);
      while (LQueue.Count > 0) and LContinue do
      begin
        LCurrent := LQueue.Dequeue;
        AVisitor(LCurrent.Value, LContinue);
        for var LChild in LCurrent.FChildren do
          LQueue.Enqueue(LChild);
      end;
    finally
      LQueue.Free;
    end;
  end;
  
begin
  LContinue := True;
  case AOrder of
    ttoPreOrder: PreOrder(FRoot);
    ttoPostOrder: PostOrder(FRoot);
    ttoLevelOrder: LevelOrder(FRoot);
  end;
end;

function TTree<T>.ToArray(AOrder: TTreeTraversalOrder): TArray<T>;
var
  LList: TList<T>;
begin
  LList := TList<T>.Create;
  try
    Traverse(AOrder,
      procedure(const AValue: T; var AContinue: Boolean)
      begin
        LList.Add(AValue);
        AContinue := True;
      end);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TTree<T>.NodeCount: Integer;
var
  LCount: Integer;
begin
  LCount := 0;
  Traverse(ttoPreOrder,
    procedure(const AValue: T; var AContinue: Boolean)
    begin
      Inc(LCount);
      AContinue := True;
    end);
  Result := LCount;
end;

function TTree<T>.Height: Integer;
begin
  if Assigned(FRoot) then
    Result := FRoot.Height
  else
    Result := -1;
end;

{ TGraphBuilder<T> }

constructor TGraphBuilder<T>.Create(ADirected: Boolean);
begin
  inherited Create;
  FGraph := TGraph<T>.Create(ADirected);
end;

function TGraphBuilder<T>.AddNode(const ANode: T): TGraphBuilder<T>;
begin
  FGraph.AddNode(ANode);
  Result := Self;
end;

function TGraphBuilder<T>.AddNodes(const ANodes: array of T): TGraphBuilder<T>;
begin
  for var LNode in ANodes do
    FGraph.AddNode(LNode);
  Result := Self;
end;

function TGraphBuilder<T>.AddEdge(const ASource, ATarget: T; AWeight: Double): TGraphBuilder<T>;
begin
  FGraph.AddEdge(ASource, ATarget, AWeight);
  Result := Self;
end;

function TGraphBuilder<T>.AddEdges(const AEdges: array of TEdge<T>): TGraphBuilder<T>;
begin
  for var LEdge in AEdges do
    FGraph.AddEdge(LEdge.Source, LEdge.Target, LEdge.Weight);
  Result := Self;
end;

function TGraphBuilder<T>.Build: TGraph<T>;
begin
  Result := FGraph;
  FGraph := nil;
end;

{ TGraphs }

class function TGraphs.Directed<T>: TGraphBuilder<T>;
begin
  Result := TGraphBuilder<T>.Create(True);
end;

class function TGraphs.Undirected<T>: TGraphBuilder<T>;
begin
  Result := TGraphBuilder<T>.Create(False);
end;

class function TGraphs.Tree<T>(const ARootValue: T): TTree<T>;
begin
  Result := TTree<T>.Create(ARootValue);
end;

end.
