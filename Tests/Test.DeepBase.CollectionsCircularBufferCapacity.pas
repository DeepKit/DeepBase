{ ============================================================================
  Test.DeepBase.CollectionsCircularBufferCapacity - A2-07 / B-COL-01 regression

  TCircularBuffer<T>.Create must reject ACapacity <= 0 with the module's own
  ECollectionException: a zero-capacity instance makes every mod FCapacity in
  Push/GetItem a divide-by-zero and turns writes out of bounds.
  ============================================================================ }

unit Test.DeepBase.CollectionsCircularBufferCapacity;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Collections;

type
  [TestFixture]
  TTestCircularBufferCapacityA207 = class
  public
    [Test]
    procedure Test_Create_ZeroCapacity_RaisesECollectionException;

    [Test]
    procedure Test_Create_NegativeCapacity_RaisesECollectionException;

    [Test]
    procedure Test_Factory_ZeroCapacity_RaisesECollectionException;

    [Test]
    procedure Test_Capacity_One_PushPopWrap;

    [Test]
    procedure Test_Capacity_Two_OverwriteOldest;

    [Test]
    procedure Test_Capacity_N_BoundaryWrapAndCount;
  end;

implementation

{ TTestCircularBufferCapacityA207 }

procedure TTestCircularBufferCapacityA207.Test_Create_ZeroCapacity_RaisesECollectionException;
begin
  Assert.WillRaise(
    procedure
    var
      Buf: TCircularBuffer<Integer>;
    begin
      Buf := TCircularBuffer<Integer>.Create(0);
      try
        Buf.Push(1); // must never get here
      finally
        Buf.Free;
      end;
    end, ECollectionException);
end;

procedure TTestCircularBufferCapacityA207.Test_Create_NegativeCapacity_RaisesECollectionException;
begin
  Assert.WillRaise(
    procedure
    var
      Buf: TCircularBuffer<Integer>;
    begin
      Buf := TCircularBuffer<Integer>.Create(-7);
      try
        Buf.Push(1);
      finally
        Buf.Free;
      end;
    end, ECollectionException);
end;

procedure TTestCircularBufferCapacityA207.Test_Factory_ZeroCapacity_RaisesECollectionException;
begin
  Assert.WillRaise(
    procedure
    var
      Buf: TCircularBuffer<string>;
    begin
      Buf := TCollections.CircularBuffer<string>(0);
      Buf.Free;
    end, ECollectionException);
end;

procedure TTestCircularBufferCapacityA207.Test_Capacity_One_PushPopWrap;
var
  Buf: TCircularBuffer<Integer>;
  Value: Integer;
begin
  Buf := TCircularBuffer<Integer>.Create(1);
  try
    Buf.Push(42);
    Assert.IsTrue(Buf.IsFull);
    Assert.AreEqual(1, Buf.Count);
    // overwrite-oldest at capacity 1 must keep mod-1 arithmetic sane
    Buf.Push(43);
    Assert.AreEqual(1, Buf.Count);
    Assert.AreEqual(43, Buf.Peek);
    Assert.IsTrue(Buf.TryPop(Value));
    Assert.AreEqual(43, Value);
    Assert.IsTrue(Buf.IsEmpty);
  finally
    Buf.Free;
  end;
end;

procedure TTestCircularBufferCapacityA207.Test_Capacity_Two_OverwriteOldest;
var
  Buf: TCircularBuffer<Integer>;
begin
  Buf := TCircularBuffer<Integer>.Create(2);
  try
    Buf.Push(10);
    Buf.Push(20);
    Buf.Push(30); // overwrites oldest (10)
    Assert.AreEqual(2, Buf.Count);
    Assert.AreEqual(20, Buf[0]);
    Assert.AreEqual(30, Buf[1]);
  finally
    Buf.Free;
  end;
end;

procedure TTestCircularBufferCapacityA207.Test_Capacity_N_BoundaryWrapAndCount;
var
  Buf: TCircularBuffer<Integer>;
  I: Integer;
begin
  Buf := TCircularBuffer<Integer>.Create(8);
  try
    for I := 1 to 20 do
      Buf.Push(I);
    Assert.AreEqual(8, Buf.Count);
    // last 8 pushes retained, oldest-first order across the wrap
    for I := 0 to 7 do
      Assert.AreEqual(13 + I, Buf[I]);
  finally
    Buf.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCircularBufferCapacityA207);

end.
