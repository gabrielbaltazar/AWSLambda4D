unit HelloLambda.Handle;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.HTTP.Types;

type
  THelloLambdaHandle = class(TInterfacedObject, IAWSLambda4DHandler)
  protected
    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  public
    class function New: IAWSLambda4DHandler;
  end;

implementation

{ THelloLambdaHandle }

function THelloLambdaHandle.Handle(const ARequest: TAWSLambda4DRequest;
  const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
var
  LJSON: TJSONObject;
  LNowUTC: TDateTime;
begin
  LNowUTC := TTimeZone.Local.ToUniversalTime(Now);
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('currentDate', FormatDateTime('yyyy"-"mm"-"dd"', LNowUTC));
    LJSON.AddPair('currentDateUtc', DateToISO8601(LNowUTC, True));
    LJSON.AddPair('timezone', 'UTC');
    LJSON.AddPair('awsRequestId', AContext.AwsRequestId);
    LJSON.AddPair('functionArn', AContext.FunctionArn);
    LJSON.AddPair('traceId', AContext.TraceId);
    LJSON.AddPair('invocationId', AContext.InvocationId);
    LJSON.AddPair('requestId', ARequest.RequestId);

    System.Writeln('Oi! To passando aqui');
    System.Writeln('BODY: ' + ARequest.Body);

    Result := TAWSLambda4DResponse.Create;
    Result.Body := LJSON.ToJSON;
  finally
    LJSON.Free;
  end;
end;

class function THelloLambdaHandle.New: IAWSLambda4DHandler;
begin
  Result := Self.Create;
end;

end.
