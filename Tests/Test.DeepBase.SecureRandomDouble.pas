unit Test.DeepBase.SecureRandomDouble;

{*******************************************************************************
  A2-05 regression: TSecureRandom.NextDouble large-sample statistics.
  The 32-bit `1 shl 53` scaling collapse pushed outputs far outside [0,1) and
  quantized the high bits; a correct 53-bit scaling must produce a uniform
  [0,1) sample: full range, mean ~0.5, four balanced quartiles, no duplicates.
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Random;

type
  [TestFixture]
  TTestSecureRandomDoubleStats = class
  private
    const SAMPLE_SIZE = 100000;
  public
    /// <summary>All samples within [0,1) with balanced quartiles and no repeats</summary>
    [Test]
    procedure Test_NextDouble_UniformInRange_NoHighBitCollapse;
  end;

implementation

procedure TTestSecureRandomDoubleStats.Test_NextDouble_UniformInRange_NoHighBitCollapse;
var
  SR: TSecureRandom;
  Seen: TDictionary<Double, Integer>;
  I: Integer;
  V, Sum: Double;
  Quartiles: array[0..3] of Integer;
  Q: Integer;
  OutOfRange, Duplicates: Integer;
begin
  SR := TSecureRandom.Instance;
  Seen := TDictionary<Double, Integer>.Create;
  try
    Sum := 0;
    FillChar(Quartiles, SizeOf(Quartiles), 0);
    OutOfRange := 0;
    Duplicates := 0;

    for I := 0 to SAMPLE_SIZE - 1 do
    begin
      V := SR.NextDouble;
      if (V < 0.0) or (V >= 1.0) then
        Inc(OutOfRange);

      if Seen.ContainsKey(V) then
        Inc(Duplicates)
      else
        Seen.Add(V, 1);

      Sum := Sum + V;
      if (V >= 0.0) and (V < 1.0) then
      begin
        Q := Trunc(V * 4.0);
        if Q > 3 then Q := 3;
        Inc(Quartiles[Q]);
      end;
    end;

    Assert.AreEqual(0, OutOfRange,
      'Every NextDouble sample must lie in [0,1): a 32-bit shl collapse ' +
      'inflates the domain past 1.0');

    // 100k samples of U(0,1): mean ~0.5 with sigma ~0.0029, so 0.01 is ~3.4 sigma
    Assert.IsTrue(Abs((Sum / SAMPLE_SIZE) - 0.5) < 0.01,
      'Sample mean must be close to 0.5 (uniform), not collapsed');

    // Each quartile expected ~25%; allow a wide 20%-30% band (well beyond 3 sigma)
    for Q := 0 to 3 do
      Assert.IsTrue((Quartiles[Q] >= SAMPLE_SIZE * 20 div 100) and
        (Quartiles[Q] <= SAMPLE_SIZE * 30 div 100),
        Format('Quartile %d count %d is far from uniform 25%% - high-bit ' +
        'collapse signature', [Q, Quartiles[Q]]));

    Assert.AreEqual(0, Duplicates,
      '100k distinct 53-bit fractions must not repeat (dedup rate check)');
  finally
    Seen.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSecureRandomDoubleStats);

end.
