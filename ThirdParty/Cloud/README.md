# UniBase Cloud Storage Integration

统一的云存储接口，支持多家云服务商。

## 支持的云服务商

| 服务商 | 类型 | 说明 |
|--------|------|------|
| AWS S3 | `cspAWSS3` | Amazon Simple Storage Service |
| Azure Blob | `cspAzureBlob` | Microsoft Azure Blob Storage |
| Alibaba OSS | `cspAliOSS` | 阿里云对象存储 |
| Google Cloud | `cspGoogleCloud` | Google Cloud Storage |
| MinIO | `cspMinIO` | S3 兼容的私有云存储 |

## 使用示例

### AWS S3

```pascal
uses UniBase.Cloud.Storage;

var
  Credentials: TCloudCredentials;
  Client: ICloudStorageClient;
begin
  Credentials := TCloudCredentials.ForAWS(
    'AKIAIOSFODNN7EXAMPLE',
    'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
    'us-east-1'
  );
  
  Client := CreateCloudStorageClient(Credentials);
  
  // 上传文件
  TCloudStorageHelper.UploadFile(Client, 'my-bucket', 'docs/readme.txt', 'C:\readme.txt');
  
  // 下载文件
  TCloudStorageHelper.DownloadFile(Client, 'my-bucket', 'docs/readme.txt', 'C:\downloaded.txt');
  
  // 列出对象
  var Objects := Client.ListObjects('my-bucket', 'docs/');
  for var Obj in Objects.Objects do
    WriteLn(Obj.Key, ' - ', Obj.Size, ' bytes');
  
  // 生成预签名 URL (1小时有效)
  var Url := Client.GetPresignedUrl('my-bucket', 'docs/readme.txt', 3600);
end;
```

### Azure Blob Storage

```pascal
var
  Credentials: TCloudCredentials;
  Client: ICloudStorageClient;
begin
  Credentials := TCloudCredentials.ForAzure(
    'mystorageaccount',
    'base64accountkey...'
  );
  
  Client := CreateCloudStorageClient(Credentials);
  
  // 创建容器
  Client.CreateBucket('my-container');
  
  // 上传 Blob
  var Stream := TStringStream.Create('Hello, Azure!');
  try
    Client.PutObject('my-container', 'hello.txt', Stream, 'text/plain');
  finally
    Stream.Free;
  end;
end;
```

### 阿里云 OSS

```pascal
var
  Credentials: TCloudCredentials;
  Client: ICloudStorageClient;
begin
  Credentials := TCloudCredentials.ForAliOSS(
    'LTAIxxxxxxxx',
    'xxxxxxxxxxxxxxxxxxxxxxxx',
    'cn-hangzhou'
  );
  
  Client := CreateCloudStorageClient(Credentials);
  
  // 检查对象是否存在
  if Client.ObjectExists('my-bucket', 'data/file.json') then
  begin
    // 获取对象信息
    var Info := Client.GetObjectInfo('my-bucket', 'data/file.json');
    WriteLn('Size: ', Info.Size);
    WriteLn('Type: ', Info.ContentType);
  end;
end;
```

### MinIO (私有 S3)

```pascal
var
  Credentials: TCloudCredentials;
  Client: ICloudStorageClient;
begin
  Credentials := TCloudCredentials.ForMinIO(
    'minio.local:9000',
    'minioadmin',
    'minioadmin'
  );
  
  Client := CreateCloudStorageClient(Credentials);
  
  // 与 S3 API 兼容
  Client.CreateBucket('test-bucket');
end;
```

## 批量操作

```pascal
// 上传整个目录
var Count := TCloudStorageHelper.UploadDirectory(
  Client,
  'my-bucket',
  'backup/2024/',
  'C:\Data\Backup'
);
WriteLn('Uploaded ', Count, ' files');

// 下载整个目录
Count := TCloudStorageHelper.DownloadDirectory(
  Client,
  'my-bucket',
  'backup/2024/',
  'C:\Data\Restore'
);
WriteLn('Downloaded ', Count, ' files');

// 同步目录
Count := TCloudStorageHelper.SyncDirectory(
  Client,
  'my-bucket',
  'sync/',
  'C:\Data\Sync'
);
```

## 分片上传

```pascal
var
  UploadId: string;
  Parts: TArray<TPair<Integer, string>>;
  Stream: TFileStream;
  PartSize: Int64;
begin
  PartSize := 5 * 1024 * 1024; // 5MB per part
  
  // 初始化分片上传
  UploadId := Client.InitiateMultipartUpload('my-bucket', 'large-file.zip');
  
  // 上传各分片
  Stream := TFileStream.Create('C:\large-file.zip', fmOpenRead);
  try
    var PartNum := 1;
    while Stream.Position < Stream.Size do
    begin
      var PartStream := TMemoryStream.Create;
      try
        PartStream.CopyFrom(Stream, Min(PartSize, Stream.Size - Stream.Position));
        var ETag := Client.UploadPart('my-bucket', 'large-file.zip', UploadId, PartNum, PartStream);
        SetLength(Parts, Length(Parts) + 1);
        Parts[High(Parts)] := TPair<Integer, string>.Create(PartNum, ETag);
      finally
        PartStream.Free;
      end;
      Inc(PartNum);
    end;
  finally
    Stream.Free;
  end;
  
  // 完成上传
  Client.CompleteMultipartUpload('my-bucket', 'large-file.zip', UploadId, Parts);
end;
```

## ACL 权限

```pascal
// 设置公开读取
Client.SetObjectACL('my-bucket', 'public/image.png', aclPublicRead);

// 获取公开 URL
var PublicUrl := Client.GetPublicUrl('my-bucket', 'public/image.png');
```

## 存储类型

| 类型 | 说明 |
|------|------|
| `scStandard` | 标准存储 |
| `scInfrequentAccess` | 低频访问 |
| `scArchive` | 归档存储 |
| `scColdline` | 冷数据存储 |
| `scGlacier` | 冰川存储 |

## 注意事项

1. **凭证安全**: 不要硬编码凭证，使用环境变量或配置文件
2. **错误处理**: 网络操作应包装在 try-except 中
3. **大文件**: 超过 100MB 建议使用分片上传
4. **并发**: 批量操作建议使用多线程
5. **区域选择**: 选择离用户最近的区域以获得最佳性能
