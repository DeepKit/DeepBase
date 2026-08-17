{ ============================================================================
  DeepBase.Services.Interfaces - Service Interfaces for Dependency Injection

  Version: 1.0
  Description: Defines service interfaces to enable dependency injection and
               improve testability. These interfaces abstract static utility
               classes to allow mocking in unit tests.

  Interface Categories:
    - Cryptography: IHashService, IEncodingService, ICryptoService
    - Security: IPasswordService, IRandomService
    - Protection: IAntiTamperService, IBasicProtectionService
    - Serialization: ISerializationService
    - Math: IMathService, IStatisticsService

  Usage:
    // Register default implementations
    DeepBase.Services.Registration.RegisterDefaultServices(GlobalContainer);

    // Resolve and use
    var HashSvc := GlobalContainer.Resolve<IHashService>;
    var Hash := HashSvc.SHA256('data');

    // Mock in tests
    Container.RegisterSingleton<IHashService>(TMockHashService.Create);
  ============================================================================ }

unit DeepBase.Services.Interfaces;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.Crypto, DeepBase.Crypto.Hash;

type
  // ============================================================================
  // Hash Service Interface
  // ============================================================================

  /// <summary>
  /// Service interface for hash operations
  /// </summary>
  IHashService = interface
    ['{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5D}']

    /// <summary>Hash bytes using specified algorithm</summary>
    function HashBytes(const Data: TBytes; Algorithm: THashAlgorithm): TBytes;

    /// <summary>Hash string using specified algorithm</summary>
    function HashString(const Data: string; Algorithm: THashAlgorithm): TBytes;

    /// <summary>Hash stream using specified algorithm</summary>
    function HashStream(Stream: TStream; Algorithm: THashAlgorithm): TBytes;

    /// <summary>Hash file using specified algorithm</summary>
    function HashFile(const FileName: string; Algorithm: THashAlgorithm): TBytes;

    /// <summary>Convert hash bytes to hex string</summary>
    function HashToHex(const Hash: TBytes): string;

    // Convenience methods
    function MD5(const Data: string): string; overload;
    function MD5(const Data: TBytes): string; overload;
    function MD5File(const FileName: string): string;

    function SHA1(const Data: string): string; overload;
    function SHA1(const Data: TBytes): string; overload;

    function SHA256(const Data: string): string; overload;
    function SHA256(const Data: TBytes): string; overload;
    function SHA256File(const FileName: string): string;

    function SHA512(const Data: string): string; overload;
    function SHA512(const Data: TBytes): string; overload;

    /// <summary>Calculate HMAC</summary>
    function HMAC(const Data, Key: TBytes; Algorithm: THashAlgorithm): TBytes; overload;
    function HMAC(const Data, Key: string; Algorithm: THashAlgorithm): string; overload;
  end;

  // ============================================================================
  // Encoding Service Interface
  // ============================================================================

  /// <summary>
  /// Service interface for encoding/decoding operations
  /// </summary>
  IEncodingService = interface
    ['{B2C3D4E5-F6A7-5B6C-9D0E-1F2A3B4C5D6E}']

    // Base64
    function Base64Encode(const Data: TBytes): string; overload;
    function Base64Encode(const Data: string): string; overload;
    function Base64Decode(const Data: string): TBytes; overload;
    function Base64DecodeString(const Data: string): string;

    // Base64 URL Safe
    function Base64UrlEncode(const Data: TBytes): string; overload;
    function Base64UrlEncode(const Data: string): string; overload;
    function Base64UrlDecode(const Data: string): TBytes;
    function Base64UrlDecodeString(const Data: string): string;

    // Hex
    function HexEncode(const Data: TBytes): string; overload;
    function HexEncode(const Data: string): string; overload;
    function HexDecode(const Data: string): TBytes;
    function HexDecodeString(const Data: string): string;

    // URL
    function UrlEncode(const Data: string): string;
    function UrlDecode(const Data: string): string;

    // HTML
    function HtmlEncode(const Data: string): string;
    function HtmlDecode(const Data: string): string;
  end;

  // ============================================================================
  // Password Service Interface
  // ============================================================================

  /// <summary>
  /// Password strength level
  /// </summary>
  TPasswordStrength = (psVeryWeak, psWeak, psFair, psStrong, psVeryStrong);

  /// <summary>
  /// Service interface for password operations
  /// </summary>
  IPasswordService = interface
    ['{C3D4E5F6-A7B8-6C7D-0E1F-2A3B4C5D6E7F}']

    /// <summary>Hash password with salt</summary>
    function HashPassword(const Password: string): string; overload;
    function HashPassword(const Password, Salt: string): string; overload;

    /// <summary>Verify password against hash</summary>
    function VerifyPassword(const Password, Hash: string): Boolean;

    /// <summary>Generate random salt</summary>
    function GenerateSalt(Length: Integer = 16): string;

    /// <summary>PBKDF2 key derivation</summary>
    function PBKDF2(const Password, Salt: string; Iterations, KeyLength: Integer): TBytes;

    /// <summary>Check password strength</summary>
    function CheckStrength(const Password: string): TPasswordStrength;

    /// <summary>Generate random password</summary>
    function GeneratePassword(Length: Integer = 16; IncludeSpecial: Boolean = True): string;
  end;

  // ============================================================================
  // Random Service Interface
  // ============================================================================

  /// <summary>
  /// Service interface for random number generation
  /// </summary>
  IRandomService = interface
    ['{D4E5F6A7-B8C9-7D8E-1F2A-3B4C5D6E7F8A}']

    /// <summary>Generate random bytes</summary>
    function RandomBytes(Length: Integer): TBytes;

    /// <summary>Generate random string (alphanumeric)</summary>
    function RandomString(Length: Integer): string;

    /// <summary>Generate random hex string</summary>
    function RandomHex(Length: Integer): string;

    /// <summary>Generate random integer in range</summary>
    function RandomInt(Min, Max: Integer): Integer;

    /// <summary>Generate new GUID</summary>
    function NewGuid: string;

    /// <summary>Generate new GUID without dashes</summary>
    function NewGuidNoDashes: string;

    /// <summary>Generate secure token</summary>
    function SecureToken(Length: Integer = 32): string;

    /// <summary>Generate OTP (One-Time Password)</summary>
    function GenerateOTP(Digits: Integer = 6): string;
  end;

  // ============================================================================
  // Crypto Service Interface (AES encryption)
  // ============================================================================

  /// <summary>
  /// Service interface for symmetric encryption
  /// </summary>
  ICryptoService = interface
    ['{E5F6A7B8-C9D0-8E9F-2A3B-4C5D6E7F8A9B}']

    /// <summary>Encrypt string with key</summary>
    function Encrypt(const Data, Key: string): string;

    /// <summary>Decrypt string with key</summary>
    function Decrypt(const Data, Key: string): string;

    /// <summary>Encrypt bytes with key</summary>
    function EncryptBytes(const Data: TBytes; const Key: string): TBytes;

    /// <summary>Decrypt bytes with key</summary>
    function DecryptBytes(const Data: TBytes; const Key: string): TBytes;

    /// <summary>Encrypt with IV (for advanced use)</summary>
    function EncryptWithIV(const Data: TBytes; const Key, IV: TBytes): TBytes;

    /// <summary>Decrypt with IV (for advanced use)</summary>
    function DecryptWithIV(const Data: TBytes; const Key, IV: TBytes): TBytes;
  end;

  // ============================================================================
  // CRC Service Interface
  // ============================================================================

  /// <summary>
  /// Service interface for CRC calculations
  /// </summary>
  ICRCService = interface
    ['{F6A7B8C9-D0E1-9F0A-3B4C-5D6E7F8A9B0C}']

    /// <summary>Calculate CRC32</summary>
    function CRC32(const Data: TBytes): Cardinal; overload;
    function CRC32(const Data: string): Cardinal; overload;
    function CRC32File(const FileName: string): Cardinal;

    /// <summary>Calculate Adler32</summary>
    function Adler32(const Data: TBytes): Cardinal; overload;
    function Adler32(const Data: string): Cardinal; overload;
  end;

  // ============================================================================
  // Serialization Service Interface
  // ============================================================================

  /// <summary>
  /// Service interface for object serialization
  /// </summary>
  ISerializationService = interface
    ['{A7B8C9D0-E1F2-0A1B-4C5D-6E7F8A9B0C1D}']

    /// <summary>Serialize object to JSON</summary>
    function ObjectToJson(AObject: TObject): string;

    /// <summary>Deserialize object from JSON</summary>
    function ObjectFromJson(const Json: string; AClass: TClass): TObject;

    /// <summary>Serialize object to XML</summary>
    function ObjectToXml(AObject: TObject): string;

    /// <summary>Deserialize object from XML</summary>
    function ObjectFromXml(const Xml: string; AClass: TClass): TObject;

    /// <summary>Serialize object to bytes (binary)</summary>
    function ObjectToBytes(AObject: TObject): TBytes;

    /// <summary>Deserialize object from bytes</summary>
    function ObjectFromBytes(const Data: TBytes; AClass: TClass): TObject;

    /// <summary>Deep clone object</summary>
    function CloneObject(AObject: TObject): TObject;
  end;

  // ============================================================================
  // Statistics Service Interface
  // ============================================================================

  /// <summary>
  /// Linear regression result
  /// </summary>
  TLinearRegressionResult = record
    Slope: Double;
    Intercept: Double;
    RSquared: Double;
  end;

  /// <summary>
  /// Service interface for statistical operations
  /// </summary>
  IStatisticsService = interface
    ['{B8C9D0E1-F2A3-1B2C-5D6E-7F8A9B0C1D2E}']

    // Basic statistics
    function Mean(const Values: TArray<Double>): Double;
    function Median(const Values: TArray<Double>): Double;
    function Mode(const Values: TArray<Double>): Double;

    // Variance and standard deviation
    function Variance(const Values: TArray<Double>): Double;
    function StdDev(const Values: TArray<Double>): Double;
    function PopulationVariance(const Values: TArray<Double>): Double;
    function PopulationStdDev(const Values: TArray<Double>): Double;

    // Range
    function Min(const Values: TArray<Double>): Double;
    function Max(const Values: TArray<Double>): Double;
    function Range(const Values: TArray<Double>): Double;
    function Sum(const Values: TArray<Double>): Double;

    // Percentiles
    function Percentile(const Values: TArray<Double>; P: Double): Double;
    function Quartile1(const Values: TArray<Double>): Double;
    function Quartile3(const Values: TArray<Double>): Double;
    function IQR(const Values: TArray<Double>): Double;

    // Distribution
    function Skewness(const Values: TArray<Double>): Double;
    function Kurtosis(const Values: TArray<Double>): Double;

    // Correlation
    function Covariance(const X, Y: TArray<Double>): Double;
    function Correlation(const X, Y: TArray<Double>): Double;

    // Regression
    function LinearRegression(const X, Y: TArray<Double>): TLinearRegressionResult;

    // Z-Score
    function ZScore(Value, Mean, StdDev: Double): Double;
    function ZScores(const Values: TArray<Double>): TArray<Double>;
  end;

  // ============================================================================
  // Anti-Tamper Service Interface
  // ============================================================================

  /// <summary>
  /// Anti-tamper configuration
  /// </summary>
  TAntiTamperConfig = record
    KeyString: string;
    IntegrityKey: string;
    DatabasePath: string;
    EnableCompression: Boolean;
    EnableIntegrityCheck: Boolean;
  end;

  /// <summary>
  /// Persistence port for anti-tamper secure image storage.
  /// Implementations should live in Persistence adapters.
  /// </summary>
  IAntiTamperStorage = interface
    ['{7A4B7E88-6F26-4E2A-B66E-CCF2A7D06F1A}']
    procedure SetupDatabase(const DatabasePath: string);
    procedure SaveSecureImage(const DatabasePath, KeyName: string;
      const EncryptedImageData: TBytes; const Hash, CreatedAt: string);
    function TryLoadSecureImage(const DatabasePath, KeyName: string;
      out EncryptedImageData: TBytes; out Hash: string): Boolean;
  end;

  /// <summary>
  /// Service interface for anti-tamper operations
  /// </summary>
  IAntiTamperService = interface
    ['{C9D0E1F2-A3B4-2C3D-6E7F-8A9B0C1D2E3F}']

    /// <summary>Initialize with configuration</summary>
    procedure Initialize(const Config: TAntiTamperConfig);

    /// <summary>Setup database tables</summary>
    procedure SetupDatabase;

    /// <summary>Calculate SHA256 hash</summary>
    function CalculateSHA256(const Data: TBytes): string;

    /// <summary>Encrypt image data</summary>
    function EncryptImageData(const ImageData: TBytes): TBytes;

    /// <summary>Decrypt image data</summary>
    function DecryptImageData(const EncryptedData: TBytes): TBytes;

    /// <summary>Verify data integrity</summary>
    function VerifyImageIntegrity(const Data: TBytes; const ExpectedHash: string): Boolean;

    /// <summary>Save secure image to database</summary>
    procedure SaveSecureImage(const KeyName: string; const ImageData: TBytes);

    /// <summary>Load secure image from database</summary>
    function LoadSecureImage(const KeyName: string): TBytes;

    /// <summary>Handle security violation</summary>
    procedure HandleSecurityViolation(const Reason: string);

    /// <summary>Get default configuration</summary>
    function GetDefaultConfig: TAntiTamperConfig;
  end;

  // ============================================================================
  // Basic Protection Service Interface
  // ============================================================================

  /// <summary>
  /// Service interface for basic data protection
  /// </summary>
  IBasicProtectionService = interface
    ['{D0E1F2A3-B4C5-3D4E-7F8A-9B0C1D2E3F4A}']

    /// <summary>Get dynamic encryption key</summary>
    function GetDynamicKey: string;

    /// <summary>Encrypt sensitive string data</summary>
    function EncryptSensitiveData(const Data: string): string;

    /// <summary>Decrypt sensitive string data</summary>
    function DecryptSensitiveData(const EncryptedData: string): string;

    /// <summary>Encrypt binary data</summary>
    function EncryptBinaryData(const Data: TBytes): TBytes;

    /// <summary>Decrypt binary data</summary>
    function DecryptBinaryData(const EncryptedData: TBytes): TBytes;

    /// <summary>Calculate HMAC for data integrity</summary>
    function CalculateHMAC(const Data: string): string;

    /// <summary>Verify data integrity using HMAC</summary>
    function VerifyDataIntegrity(const Data, ExpectedHMAC: string): Boolean;

    /// <summary>Calculate file hash</summary>
    function CalculateFileHash(const FileName: string): string;

    /// <summary>Calculate data hash</summary>
    function CalculateDataHash(const Data: TBytes): string;
  end;

  // ============================================================================
  // Math Utils Service Interface
  // ============================================================================

  /// <summary>
  /// Service interface for mathematical utilities
  /// </summary>
  IMathUtilsService = interface
    ['{E1F2A3B4-C5D6-4E5F-8A9B-0C1D2E3F4A5B}']

    // Clamping
    function Clamp(Value, Min, Max: Double): Double;
    function Clamp01(Value: Double): Double;

    // Wrapping
    function Wrap(Value, Min, Max: Double): Double;
    function WrapAngle(Angle: Double): Double;

    // Sign and Abs
    function Sign(Value: Double): Integer;
    function Abs(Value: Double): Double;

    // Rounding
    function Round(Value: Double): Int64;
    function RoundTo(Value: Double; Digits: Integer): Double;
    function Floor(Value: Double): Int64;
    function Ceil(Value: Double): Int64;
    function Trunc(Value: Double): Int64;
    function Frac(Value: Double): Double;

    // Comparison
    function Approximately(A, B: Double; Epsilon: Double = 1E-10): Boolean;
    function IsZero(Value: Double; Epsilon: Double = 1E-10): Boolean;
    function IsNaN(Value: Double): Boolean;
    function IsInfinity(Value: Double): Boolean;

    // Power and roots
    function Pow(Base, Exponent: Double): Double;
    function Sqrt(Value: Double): Double;
    function Cbrt(Value: Double): Double;
    function NthRoot(Value: Double; N: Integer): Double;

    // Logarithms
    function Log(Value: Double): Double;
    function Log10(Value: Double): Double;
    function Log2(Value: Double): Double;
    function LogN(Value, Base: Double): Double;
    function Exp(Value: Double): Double;

    // Trigonometry
    function Sin(Value: Double): Double;
    function Cos(Value: Double): Double;
    function Tan(Value: Double): Double;
    function ASin(Value: Double): Double;
    function ACos(Value: Double): Double;
    function ATan(Value: Double): Double;
    function ATan2(Y, X: Double): Double;

    // Angle conversion
    function DegToRad(Degrees: Double): Double;
    function RadToDeg(Radians: Double): Double;

    // Number theory
    function GCD(A, B: Int64): Int64;
    function LCM(A, B: Int64): Int64;
    function Factorial(N: Integer): Int64;
    function IsPrime(N: Int64): Boolean;
    function NextPrime(N: Int64): Int64;

    // Mapping
    function Map(Value, InMin, InMax, OutMin, OutMax: Double): Double;
    function Lerp(A, B, T: Double): Double;
    function InverseLerp(A, B, Value: Double): Double;
  end;

  // ============================================================================
  // Interpolation Service Interface
  // ============================================================================

  /// <summary>
  /// Service interface for interpolation functions
  /// </summary>
  IInterpolationService = interface
    ['{F2A3B4C5-D6E7-5F6A-9B0C-1D2E3F4A5B6C}']

    // Basic interpolation
    function Linear(A, B, T: Double): Double;
    function Cosine(A, B, T: Double): Double;
    function Cubic(Y0, Y1, Y2, Y3, T: Double): Double;
    function Hermite(Y0, Y1, Y2, Y3, T, Tension, Bias: Double): Double;

    // Bezier curves
    function QuadraticBezier(P0, P1, P2, T: Double): Double;
    function CubicBezier(P0, P1, P2, P3, T: Double): Double;

    // Catmull-Rom spline
    function CatmullRom(P0, P1, P2, P3, T: Double): Double;

    // Smoothstep
    function Smoothstep(Edge0, Edge1, X: Double): Double;
    function Smootherstep(Edge0, Edge1, X: Double): Double;

    // Bilinear
    function Bilinear(Q11, Q21, Q12, Q22, X, Y: Double): Double;

    // Remap
    function Remap(Value, InMin, InMax, OutMin, OutMax: Double): Double;
  end;

  // ============================================================================
  // Easing Service Interface
  // ============================================================================

  /// <summary>
  /// Easing function type
  /// </summary>
  TEasingType = (
    etLinear,
    etQuadIn, etQuadOut, etQuadInOut,
    etCubicIn, etCubicOut, etCubicInOut,
    etQuartIn, etQuartOut, etQuartInOut,
    etQuintIn, etQuintOut, etQuintInOut,
    etSineIn, etSineOut, etSineInOut,
    etExpoIn, etExpoOut, etExpoInOut,
    etCircIn, etCircOut, etCircInOut,
    etElasticIn, etElasticOut, etElasticInOut,
    etBackIn, etBackOut, etBackInOut,
    etBounceIn, etBounceOut, etBounceInOut
  );

  /// <summary>
  /// Service interface for easing functions
  /// </summary>
  IEasingService = interface
    ['{A3B4C5D6-E7F8-6A7B-0C1D-2E3F4A5B6C7D}']

    /// <summary>Apply easing function</summary>
    function Ease(T: Double; EasingType: TEasingType): Double;

    // Individual easing functions
    function Linear(T: Double): Double;

    function QuadIn(T: Double): Double;
    function QuadOut(T: Double): Double;
    function QuadInOut(T: Double): Double;

    function CubicIn(T: Double): Double;
    function CubicOut(T: Double): Double;
    function CubicInOut(T: Double): Double;

    function ElasticIn(T: Double): Double;
    function ElasticOut(T: Double): Double;
    function ElasticInOut(T: Double): Double;

    function BounceIn(T: Double): Double;
    function BounceOut(T: Double): Double;
    function BounceInOut(T: Double): Double;
  end;

  // ============================================================================
  // Random Distribution Service Interface
  // ============================================================================

  /// <summary>
  /// Service interface for random distributions
  /// </summary>
  IRandomDistributionService = interface
    ['{B4C5D6E7-F8A9-7B8C-1D2E-3F4A5B6C7D8E}']

    // Uniform distribution
    function Uniform(Min, Max: Double): Double;
    function UniformInt(Min, Max: Integer): Integer;

    // Normal (Gaussian) distribution
    function Normal(Mean, StdDev: Double): Double;
    function StandardNormal: Double;

    // Other distributions
    function Exponential(Lambda: Double): Double;
    function Poisson(Lambda: Double): Integer;
    function Bernoulli(P: Double): Boolean;
    function Binomial(N: Integer; P: Double): Integer;
    function Geometric(P: Double): Integer;
    function Triangular(Min, Max, Mode: Double): Double;

    // Point generation
    procedure PointInCircle(Radius: Double; out X, Y: Double);
    procedure PointOnCircle(Radius: Double; out X, Y: Double);
    procedure PointInSphere(Radius: Double; out X, Y, Z: Double);
    procedure PointOnSphere(Radius: Double; out X, Y, Z: Double);

    // Array operations
    procedure ShuffleDoubles(var Values: TArray<Double>);
    function WeightedChoiceIndex(const Weights: TArray<Double>): Integer;
  end;

implementation

end.
