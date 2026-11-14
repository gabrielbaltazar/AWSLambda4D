unit AWSLambda4D.Runtime.LocalServer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer,
  IdHeaderList,
  IdSocketHandle,
  AWSLambda4D.Classes;

type
  EAWSLambdaLocalServer = class(Exception);

  TAWSLambda4DLocalInvocation = class
  public
    RequestId: string;
    InvocationId: string;
    Body: string;
  end;

  TAWSLambda4DLocalResult = class
  public
    RequestId: string;
    InvocationId: string;
    Body: string;
    Error: Boolean;
    ErrorType: string;
  end;

  TAWSLambda4DRuntimeLocalServer = class
  private
    FServer: TIdHTTPServer;
    FPort: Integer;
    FQueue: TObjectList<TAWSLambda4DLocalInvocation>;
    FResults: TObjectList<TAWSLambda4DLocalResult>;
    FQueueLock: TObject;
    FStopping: Boolean;
    FNextId: Int64;

    procedure HandleCommand(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure CreatePostStream(AContext: TIdContext; AHeaders: TIdHeaderList; var VPostStream: TStream);
    function GetNextInvocation: TAWSLambda4DLocalInvocation;
    function ReadRequestBody(ARequestInfo: TIdHTTPRequestInfo): string;
    procedure SetJSONResponse(AResponseInfo: TIdHTTPResponseInfo; const ABody: string; AStatusCode: Integer);
    procedure ProcessNextInvocation(AResponseInfo: TIdHTTPResponseInfo);
    procedure ProcessResponse(ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo;
      const ARequestId: string);
    procedure ProcessError(ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo;
      const ARequestId: string);
    function GetResultCount: Integer;
    function GetActive: Boolean;
  public
    constructor Create(const APort: Integer = 9001);
    destructor Destroy; override;

    procedure Start;
    procedure Stop;

    procedure AddInvocation(const ABody: string; const ARequestId: string = ''; const AInvocationId: string = '');

    function GetResult(AIndex: Integer): TAWSLambda4DLocalResult;

    property Port: Integer read FPort;
    property Active: Boolean read GetActive;
    property ResultCount: Integer read GetResultCount;
  end;

implementation

uses
  System.DateUtils;

const
  CAPIPrefix = '/2018-06-01/runtime';
  CRequestId = 'Lambda-Runtime-Aws-Request-Id';
  CInvocationId = 'Lambda-Runtime-Invocation-Id';
  CDeadLine = 'Lambda-Runtime-Deadline-Ms';
  CFunctionArn = 'Lambda-Runtime-Invoked-Function-Arn';
  CTraceId = 'Lambda-Runtime-Trace-Id';
  CErrorType = 'Lambda-Runtime-Function-Error-Type';

{ TAWSLambda4DRuntimeLocalServer }

procedure TAWSLambda4DRuntimeLocalServer.AddInvocation(const ABody, ARequestId, AInvocationId: string);
var
  LInvocation: TAWSLambda4DLocalInvocation;
begin
  LInvocation := TAWSLambda4DLocalInvocation.Create;

  TMonitor.Enter(FQueueLock);
  try
    Inc(FNextId);

    if ARequestId <> '' then
      LInvocation.RequestId := ARequestId
    else
      LInvocation.RequestId := 'local-request-' + IntToStr(FNextId);

    if AInvocationId <> '' then
      LInvocation.InvocationId := AInvocationId
    else
      LInvocation.InvocationId := 'local-invocation-' + IntToStr(FNextId);

    LInvocation.Body := ABody;
    FQueue.Add(LInvocation);
    TMonitor.PulseAll(FQueueLock);
  finally
    TMonitor.Exit(FQueueLock);
  end;
end;

constructor TAWSLambda4DRuntimeLocalServer.Create(const APort: Integer);
var
  LBinding: TIdSocketHandle;
begin
  inherited Create;

  FPort := APort;
  FNextId := 0;
  FStopping := False;

  FQueueLock := TObject.Create;

  FQueue := TObjectList<TAWSLambda4DLocalInvocation>.Create(True);
  FResults := TObjectList<TAWSLambda4DLocalResult>.Create(True);
  FServer := TIdHTTPServer.Create(nil);
  FServer.OnCommandGet := HandleCommand;
  FServer.OnCommandOther := HandleCommand;
  FServer.OnCreatePostStream := CreatePostStream;

  LBinding := FServer.Bindings.Add;
  LBinding.IP := '127.0.0.1';
  LBinding.Port := FPort;
end;

procedure TAWSLambda4DRuntimeLocalServer.CreatePostStream(AContext: TIdContext; AHeaders: TIdHeaderList;
  var VPostStream: TStream);
begin
  VPostStream := TMemoryStream.Create;
end;

destructor TAWSLambda4DRuntimeLocalServer.Destroy;
begin
  Stop;
  FServer.Free;
  FResults.Free;
  FQueue.Free;
  FQueueLock.Free;
  inherited;
end;

function TAWSLambda4DRuntimeLocalServer.GetActive: Boolean;
begin
  Result := FServer.Active;
end;

function TAWSLambda4DRuntimeLocalServer.GetNextInvocation: TAWSLambda4DLocalInvocation;
begin
  TMonitor.Enter(FQueueLock);
  try
    while (FQueue.Count = 0) and not FStopping do
      TMonitor.Wait(FQueueLock, 0);

    if FStopping then
      raise EAWSLambdaLocalServer.Create('Local runtime server is stopping.');

    Result := FQueue.Extract(FQueue[0]);
  finally
    TMonitor.Exit(FQueueLock);
  end;
end;

function TAWSLambda4DRuntimeLocalServer.GetResult(AIndex: Integer): TAWSLambda4DLocalResult;
begin
  TMonitor.Enter(FQueueLock);
  try
    if (AIndex < 0) or (AIndex >= FResults.Count) then
      raise EArgumentOutOfRangeException.Create('Invalid result index.');

    Result := TAWSLambda4DLocalResult.Create;
    Result.RequestId := FResults[AIndex].RequestId;
    Result.InvocationId := FResults[AIndex].InvocationId;
    Result.Error := FResults[AIndex].Error;
    Result.Body := FResults[AIndex].Body;
    Result.ErrorType := FResults[AIndex].ErrorType;
  finally
    TMonitor.Exit(FQueueLock);
  end;
end;

function TAWSLambda4DRuntimeLocalServer.GetResultCount: Integer;
begin
  TMonitor.Enter(FQueueLock);
  try
    Result := FResults.Count;
  finally
    TMonitor.Exit(FQueueLock);
  end;
end;

procedure TAWSLambda4DRuntimeLocalServer.HandleCommand(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  LPath: string;
  LPrefix: string;
  LRemaining: string;
  LRequestId: string;
  LAction: string;
  LSeparator: Integer;
begin
  try
    LPath := ARequestInfo.Document;

    if (ARequestInfo.Command = 'GET') and (LPath = CAPIPrefix + '/invocation/next') then
    begin
      ProcessNextInvocation(AResponseInfo);
      Exit;
    end;

    if (ARequestInfo.Command = 'POST') and (LPath = CAPIPrefix + '/init/error') then
    begin
      ProcessError(ARequestInfo, AResponseInfo, 'initialization');
      Exit;
    end;

    LPrefix := CAPIPrefix + '/invocation/';

    if (ARequestInfo.Command = 'POST') and LPath.StartsWith(LPrefix) then
    begin
      LRemaining := LPath.Substring(Length(LPrefix));
      LSeparator := LastDelimiter('/', LRemaining);

      if LSeparator <= 1 then
        raise EAWSLambdaLocalServer.Create('Invalid invocation endpoint.');

      LRequestId := Copy(LRemaining, 1, LSeparator - 1);
      LAction := Copy(LRemaining, LSeparator + 1, MaxInt);

      if LAction = 'response' then
      begin
        ProcessResponse(ARequestInfo, AResponseInfo, LRequestId);
        Exit;
      end;

      if LAction = 'error' then
      begin
        ProcessError(ARequestInfo, AResponseInfo, LRequestId);
        Exit;
      end;
    end;

    SetJSONResponse(AResponseInfo, '{"error":"Endpoint not found"}', 404);
  except
    on E: Exception do
      SetJSONResponse(AResponseInfo, '{"error":"' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}', 500);
  end;
end;

procedure TAWSLambda4DRuntimeLocalServer.ProcessError(ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo; const ARequestId: string);
var
  LResult: TAWSLambda4DLocalResult;
  LJSON: string;
  LErrorType: string;
begin
  LJSON := ReadRequestBody(ARequestInfo);
  LErrorType := ARequestInfo.RawHeaders.Values[CErrorType];
  LResult := TAWSLambda4DLocalResult.Create;

  LResult.RequestId := ARequestId;
  LResult.InvocationId := ARequestInfo.RawHeaders.Values[CInvocationId];

  LResult.Body := LJSON;
  LResult.ErrorType := LErrorType;
  LResult.Error := True;

  TMonitor.Enter(FQueueLock);
  try
    FResults.Add(LResult);
  finally
    TMonitor.Exit(FQueueLock);
  end;

  SetJSONResponse(AResponseInfo, '', 202);
end;

procedure TAWSLambda4DRuntimeLocalServer.ProcessNextInvocation(AResponseInfo: TIdHTTPResponseInfo);
var
  LInvocation: TAWSLambda4DLocalInvocation;
begin
  LInvocation := GetNextInvocation;
  try
    AResponseInfo.CustomHeaders.Values[CRequestId] := LInvocation.RequestId;
    AResponseInfo.CustomHeaders.Values[CInvocationId] := LInvocation.InvocationId;
    AResponseInfo.CustomHeaders.Values[CDeadLine] := IntToStr(DateTimeToUnix(Now, False) * 1000 + 30000);

    AResponseInfo.CustomHeaders.Values[CFunctionArn] := 'arn:aws:lambda:local:123456789012:function:LocalFunction';
    AResponseInfo.CustomHeaders.Values[CTraceId] := 'Root=1-00000000-000000000000000000000000';
    SetJSONResponse(AResponseInfo, LInvocation.Body, 200);
  finally
    LInvocation.Free;
  end;
end;

procedure TAWSLambda4DRuntimeLocalServer.ProcessResponse(ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo; const ARequestId: string);
var
  LResult: TAWSLambda4DLocalResult;
begin
  LResult := TAWSLambda4DLocalResult.Create;
  LResult.RequestId := ARequestId;
  LResult.InvocationId := ARequestInfo.RawHeaders.Values[CInvocationId];
  LResult.Body := ReadRequestBody(ARequestInfo);
  LResult.Error := False;

  TMonitor.Enter(FQueueLock);
  try
    FResults.Add(LResult);
  finally
    TMonitor.Exit(FQueueLock);
  end;

  SetJSONResponse(AResponseInfo, '', 202);
end;

function TAWSLambda4DRuntimeLocalServer.ReadRequestBody(ARequestInfo: TIdHTTPRequestInfo): string;
var
  LBytes: TBytes;
  LStream: TStream;
begin
  Result := '';
  LStream := ARequestInfo.PostStream;
  if not Assigned(LStream) then
    Exit;

  LStream.Position := 0;
  SetLength(LBytes, LStream.Size);
  if Length(LBytes) > 0 then
    LStream.ReadBuffer(LBytes[0], Length(LBytes));

  Result := TEncoding.UTF8.GetString(LBytes);
end;

procedure TAWSLambda4DRuntimeLocalServer.SetJSONResponse(AResponseInfo: TIdHTTPResponseInfo; const ABody: string;
  AStatusCode: Integer);
begin
  AResponseInfo.ResponseNo := AStatusCode;
  AResponseInfo.ContentType := 'application/json';
  AResponseInfo.CharSet := 'utf-8';
  AResponseInfo.ContentText := ABody;
end;

procedure TAWSLambda4DRuntimeLocalServer.Start;
begin
  if FServer.Active then
    Exit;

  TMonitor.Enter(FQueueLock);
  try
    FStopping := False;
  finally
    TMonitor.Exit(FQueueLock);
  end;

  FServer.Active := True;
end;

procedure TAWSLambda4DRuntimeLocalServer.Stop;
begin
  TMonitor.Enter(FQueueLock);
  try
    FStopping := True;
    TMonitor.PulseAll(FQueueLock);
  finally
    TMonitor.Exit(FQueueLock);
  end;

  if FServer.Active then
    FServer.Active := False;
end;

end.
