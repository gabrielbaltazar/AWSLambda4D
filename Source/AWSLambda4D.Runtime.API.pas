unit AWSLambda4D.Runtime.API;

interface

uses
  System.SysUtils,
  System.Net.HttpClient,
  System.Net.URLClient,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces;

type
  TAWSLambda4DRuntimeAPI = class(TInterfacedObject, IAWSLambda4DRuntimeAPI)
  private
    FBaseURL: string;
    FHTTPClient: THTTPClient;

    function GetHeader(const AHeaders: TNetHeaders; const AName: string): string;
    function BuildURL(const APath: string): string;
    procedure CheckResponse(const AResponse: IHTTPResponse; const AOperation: string);
    function BuildErrorJSON(const AErrorType: string; const AErrorMessage: string): string;
    function Post(const AURL: string; const ABody: string; const AHeaders: TNetHeaders): IHTTPResponse;
  protected
    function NextInvocation(out AContext: TAWSLambda4DContext): TAWSLambda4DRequest;
    procedure SendResponse(const AContext: TAWSLambda4DContext; const AResponse: TAWSLambda4DResponse);
    procedure SendError(const AContext: TAWSLambda4DContext; const AErrorType: string; const AErrorMessage: string);
  public
    constructor Create; overload;
    class function New: IAWSLambda4DRuntimeAPI; overload;
    constructor Create(const ABaseUrl: string); overload;
    class function New(const ABaseUrl: string): IAWSLambda4DRuntimeAPI; overload;
    destructor Destroy; override;
  end;

implementation

uses
  System.Classes,
  System.JSON;

const
  CAPIVersion = '/2018-06-01';
  CHeaderRequestId = 'Lambda-Runtime-Aws-Request-Id';
  CHeaderInvocationId = 'Lambda-Runtime-Invocation-Id';
  CHeaderDeadline = 'Lambda-Runtime-Deadline-Ms';
  CHeaderFunctionArn = 'Lambda-Runtime-Invoked-Function-Arn';
  CHeaderTraceId = 'Lambda-Runtime-Trace-Id';
  CHeaderErrorType = 'Lambda-Runtime-Function-Error-Type';

{ TAWSLambda4DRuntimeAPI }

function TAWSLambda4DRuntimeAPI.BuildErrorJSON(const AErrorType, AErrorMessage: string): string;
var
  LJSON: TJSONObject;
  LStackTrace: TJSONArray;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('errorMessage', AErrorMessage);
    LJSON.AddPair('errorType', AErrorType);
    LStackTrace := TJSONArray.Create;
    LJSON.AddPair('stackTrace', LStackTrace);
    Result := LJSON.ToJSON;
  finally
    LJSON.Free;
  end;
end;

function TAWSLambda4DRuntimeAPI.BuildURL(const APath: string): string;
begin
  Result := FBaseURL + CAPIVersion + APath;
end;

procedure TAWSLambda4DRuntimeAPI.CheckResponse(const AResponse: IHTTPResponse; const AOperation: string);
var
  LBody: string;
begin
  if not Assigned(AResponse) then
    raise ELambdaRuntimeAPI.CreateFmt('Empty HTTP response during operation: %s', [AOperation]);

  if (AResponse.StatusCode < 200) or (AResponse.StatusCode >= 300) then
  begin
    LBody := AResponse.ContentAsString(TEncoding.UTF8);
    raise ELambdaRuntimeAPI.CreateFmt('AWS Lambda Runtime API error. Operation: %s. HTTP: %d. Body: %s',
      [AOperation, AResponse.StatusCode, LBody]);
  end;
end;

constructor TAWSLambda4DRuntimeAPI.Create(const ABaseUrl: string);
begin
  if ABaseUrl = '' then
    raise ELambdaRuntimeAPI.Create('Lambda Runtime API address is required.');

  FBaseURL := ABaseURL;
  if not FBaseURL.StartsWith('http://') then
    FBaseURL := 'http://' + FBaseURL;
  FBaseURL := FBaseURL.TrimRight(['/']);
  FHTTPClient := THTTPClient.Create;
end;

constructor TAWSLambda4DRuntimeAPI.Create;
begin
  FBaseURL := GetEnvironmentVariable('AWS_LAMBDA_RUNTIME_API');
  if FBaseURL = '' then
    raise ELambdaRuntimeAPI.Create('Environment variable AWS_LAMBDA_RUNTIME_API not defined.');

  FBaseURL := 'http://' + FBaseURL;
  FHTTPClient := THTTPClient.Create;
end;

destructor TAWSLambda4DRuntimeAPI.Destroy;
begin
  FHTTPClient.Free;
  inherited;
end;

function TAWSLambda4DRuntimeAPI.GetHeader(const AHeaders: TNetHeaders; const AName: string): string;
var
  LHeader: TNetHeader;
begin
  Result := '';

  for LHeader in AHeaders do
  begin
    if SameText(LHeader.Name, AName) then
    begin
      Result := LHeader.Value;
      Exit;
    end;
  end;
end;

class function TAWSLambda4DRuntimeAPI.New(const ABaseUrl: string): IAWSLambda4DRuntimeAPI;
begin
  Result := Self.Create(ABaseUrl);
end;

class function TAWSLambda4DRuntimeAPI.New: IAWSLambda4DRuntimeAPI;
begin
  Result := Self.Create;
end;

function TAWSLambda4DRuntimeAPI.NextInvocation(out AContext: TAWSLambda4DContext): TAWSLambda4DRequest;
var
  LResponse: IHTTPResponse;
  LURL: string;
  LDeadline: string;
  LOutValue: Int64;
begin
  Result := nil;
  AContext := nil;
  AContext := TAWSLambda4DContext.Create;
  try
    LURL := BuildURL('/runtime/invocation/next');

    // Esta chamada precisa permanecer bloqueada aguardando uma nova invocação.
    LResponse := FHTTPClient.Get(LURL);

    CheckResponse(LResponse, 'NextInvocation');
    AContext.AwsRequestId := GetHeader(LResponse.Headers, CHeaderRequestId);
    AContext.InvocationId := GetHeader(LResponse.Headers, CHeaderInvocationId);
    AContext.FunctionArn := GetHeader(LResponse.Headers, CHeaderFunctionArn);
    AContext.TraceId := GetHeader(LResponse.Headers, CHeaderTraceId);
    LDeadline := GetHeader(LResponse.Headers, CHeaderDeadline);

    AContext.DeadlineMs := 0;
    if TryStrToInt64(LDeadline, LOutValue) then
      AContext.DeadlineMs := LOutValue;

    if AContext.AwsRequestId = '' then
      raise ELambdaRuntimeAPI.Create('AWS request ID was not returned by Runtime API.');

    Result := TAWSLambda4DRequest.Create;
    Result.RequestId := AContext.AwsRequestId;
    Result.Body := LResponse.ContentAsString(TEncoding.UTF8);
  except
    Result.Free;
    AContext.Free;
    AContext := nil;
    raise;
  end;
end;

function TAWSLambda4DRuntimeAPI.Post(const AURL, ABody: string; const AHeaders: TNetHeaders): IHTTPResponse;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Result := FHTTPClient.Post(AURL, LStream, nil, AHeaders);
  finally
    LStream.Free;
  end;
end;

procedure TAWSLambda4DRuntimeAPI.SendError(const AContext: TAWSLambda4DContext; const AErrorType,
  AErrorMessage: string);
var
  LHeaders: TNetHeaders;
  LHTTPResponse: IHTTPResponse;
  LURL: string;
  LErrorJSON: string;
begin
  if not Assigned(AContext) then
    raise ELambdaRuntimeAPI.Create('Lambda context is required.');

  if AContext.AwsRequestId = '' then
    raise ELambdaRuntimeAPI.Create('AWS request ID is empty.');

  SetLength(LHeaders, 2);
  LHeaders[0].Name := 'Content-Type';
  LHeaders[0].Value := 'application/json';
  LHeaders[1].Name := CHeaderErrorType;
  LHeaders[1].Value := AErrorType;

  if AContext.InvocationId <> EmptyStr then
  begin
    SetLength(LHeaders, 3);
    LHeaders[2].Name := CHeaderInvocationId;
    LHeaders[2].Value := AContext.InvocationId;
  end;

  LURL := BuildURL('/runtime/invocation/' + AContext.AwsRequestId + '/error');
  LErrorJSON := BuildErrorJSON(AErrorType, AErrorMessage);
  LHTTPResponse := Post(LURL, LErrorJSON, LHeaders);
  CheckResponse(LHTTPResponse, 'SendError');
end;

procedure TAWSLambda4DRuntimeAPI.SendResponse(const AContext: TAWSLambda4DContext;
  const AResponse: TAWSLambda4DResponse);
var
  LHeaders: TNetHeaders;
  LHTTPResponse: IHTTPResponse;
  LURL: string;
begin
  if not Assigned(AContext) then
    raise ELambdaRuntimeAPI.Create('Lambda context is required.');

  if not Assigned(AResponse) then
    raise ELambdaRuntimeAPI.Create('Lambda response is required.');

  if AContext.AwsRequestId = '' then
    raise ELambdaRuntimeAPI.Create('AWS request ID is empty.');

  SetLength(LHeaders, 1);
  LHeaders[0].Name := 'Content-Type';
  LHeaders[0].Value := 'application/json';

  if AContext.InvocationId <> EmptyStr then
  begin
    SetLength(LHeaders, 2);
    LHeaders[1].Name := CHeaderInvocationId;
    LHeaders[1].Value := AContext.InvocationId;
  end;

  LURL := BuildURL('/runtime/invocation/' + AContext.AwsRequestId + '/response');
  LHTTPResponse := Post(LURL, AResponse.Body, LHeaders);
  CheckResponse(LHTTPResponse, 'SendResponse');
end;

end.
