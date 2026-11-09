unit AWSLambda4D.Runtime.API.Mock;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.Classes;

type
  EAWSLambda4DMockStop = class(Exception);

  EAWSLambda4DMockResultType = (mrtResponse, mrtError);

  TAWSLambda4DMockResult = class
  public
    ResultType: EAWSLambda4DMockResultType;
    RequestId: string;
    Body: string;
    ErrorType: string;
    ErrorMessage: string;
  end;

  TAWSLambda4DMockInvocation = class
  public
    Body: string;
    RequestId: string;
    InvocationId: string;
  end;

  TAWSLambda4DRuntimeAPIMock = class(TInterfacedObject, IAWSLambda4DRuntimeAPI)
  private
    FInvocations: TObjectList<TAWSLambda4DMockInvocation>;
    FResults: TObjectList<TAWSLambda4DMockResult>;
    FNextIndex: Integer;

    FFailOnNextInvocation: Boolean;
    FFailOnSendResponse: Boolean;
    FFailOnSendError: Boolean;
    function GetResultCount: Integer;
  protected
    function NextInvocation(out AContext: TAWSLambda4DContext): TAWSLambda4DRequest;
    procedure SendResponse(const AContext: TAWSLambda4DContext; const AResponse: TAWSLambda4DResponse);
    procedure SendError(const AContext: TAWSLambda4DContext; const AErrorType: string; const AErrorMessage: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddInvocation(const ABody: string; const ARequestId: string = ''; const AInvocationId: string = '');
    function GetResult(const AIndex: Integer): TAWSLambda4DMockResult;

    property InvocationCount: Integer read FNextIndex;
    property ResultCount: Integer read GetResultCount;
    property FailOnNextInvocation: Boolean read FFailOnNextInvocation write FFailOnNextInvocation;
    property FailOnSendResponse: Boolean read FFailOnSendResponse write FFailOnSendResponse;
    property FailOnSendError: Boolean read FFailOnSendError write FFailOnSendError;
  end;

implementation

{ TAWSLambda4DRuntimeAPIMock }

procedure TAWSLambda4DRuntimeAPIMock.AddInvocation(const ABody, ARequestId, AInvocationId: string);
var
  LInvocation: TAWSLambda4DMockInvocation;
  LIndex: Integer;
begin
  LIndex := FInvocations.Count + 1;
  LInvocation := TAWSLambda4DMockInvocation.Create;
  LInvocation.Body := ABody;

  if ARequestId <> '' then
    LInvocation.RequestId := ARequestId
  else
    LInvocation.RequestId := 'mock-request-' + IntToStr(LIndex);

  if AInvocationId <> '' then
    LInvocation.InvocationId := AInvocationId
  else
    LInvocation.InvocationId := 'mock-invocation-' + IntToStr(LIndex);

  FInvocations.Add(LInvocation);
end;

constructor TAWSLambda4DRuntimeAPIMock.Create;
begin
  FInvocations := TObjectList<TAWSLambda4DMockInvocation>.Create(True);
  FResults := TObjectList<TAWSLambda4DMockResult>.Create(True);
  FNextIndex := 0;
end;

destructor TAWSLambda4DRuntimeAPIMock.Destroy;
begin
  FResults.Free;
  FInvocations.Free;
  inherited;
end;

function TAWSLambda4DRuntimeAPIMock.GetResult(const AIndex: Integer): TAWSLambda4DMockResult;
begin
  Result := FResults[AIndex];
end;

function TAWSLambda4DRuntimeAPIMock.GetResultCount: Integer;
begin
  Result := FResults.Count;
end;

function TAWSLambda4DRuntimeAPIMock.NextInvocation(out AContext: TAWSLambda4DContext): TAWSLambda4DRequest;
var
  LInvocation: TAWSLambda4DMockInvocation;
begin
  Result := nil;
  AContext := nil;

  if FFailOnNextInvocation then
    raise Exception.Create('Simulated Runtime API connection failure.');

  // Interrompe o loop quando os eventos terminarem.
  if FNextIndex >= FInvocations.Count then
    raise EAWSLambda4DMockStop.Create('No more mock invocations.');

  LInvocation := FInvocations[FNextIndex];
  AContext := TAWSLambda4DContext.Create;
  try
    AContext.AwsRequestId := LInvocation.RequestId;
    AContext.InvocationId := LInvocation.InvocationId;
    AContext.FunctionArn := 'arn:aws:lambda:local:123456789012:function:MockFunction';
    AContext.TraceId := 'mock-trace-id';
    AContext.DeadlineMs := 9999999999999;

    Result := TAWSLambda4DRequest.Create;
    Result.RequestId := LInvocation.RequestId;
    Result.Body := LInvocation.Body;
    Inc(FNextIndex);
  except
    Result.Free;
    AContext.Free;
    AContext := nil;
    raise;
  end;
end;

procedure TAWSLambda4DRuntimeAPIMock.SendError(const AContext: TAWSLambda4DContext; const AErrorType,
  AErrorMessage: string);
begin

end;

procedure TAWSLambda4DRuntimeAPIMock.SendResponse(const AContext: TAWSLambda4DContext;
  const AResponse: TAWSLambda4DResponse);
var
  LResult: TAWSLambda4DMockResult;
begin
  if FFailOnSendResponse then
    raise Exception.Create('Simulated SendResponse failure.');

  if not Assigned(AContext) then
    raise Exception.Create('Context is required.');

  if not Assigned(AResponse) then
    raise Exception.Create('Response is required.');

  LResult := TAWSLambda4DMockResult.Create;
  LResult.ResultType := mrtResponse;
  LResult.RequestId := AContext.AwsRequestId;
  LResult.Body := AResponse.Body;
  FResults.Add(LResult);
end;

end.
