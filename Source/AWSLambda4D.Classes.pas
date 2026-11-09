unit AWSLambda4D.Classes;

interface

type
  TAWSLambda4DRequest = class
  private
    FBody: string;
    FRequestId: string;
  public
    property RequestId: string read FRequestId write FRequestId;
    property Body: string read FBody write FBody;
  end;

  TAWSLambda4DResponse = class
  private
    FBody: string;
  public
    property Body: string read FBody write FBody;
  end;

  TAWSLambda4DContext = class
  private
    FAwsRequestId: string;
    FFunctionArn: string;
    FDeadlineMs: Int64;
    FTraceId: string;
    FInvocationId: string;
  public
    property AwsRequestId: string read FAwsRequestId write FAwsRequestId;
    property FunctionArn: string read FFunctionArn write FFunctionArn;
    property DeadlineMs: Int64 read FDeadlineMs write FDeadlineMs;
    property TraceId: string read FTraceId write FTraceId;
    property InvocationId: string read FInvocationId write FInvocationId;
  end;

implementation

end.
