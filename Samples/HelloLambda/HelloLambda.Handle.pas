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
  THellLambdaHandle = class(TInterfacedObject, IAWSLambda4DHandler)
  protected
    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  end;

  THellLambdaHTTPHandle = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  end;

implementation

{ THellLambdaHandle }

function THellLambdaHandle.Handle(const ARequest: TAWSLambda4DRequest;
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

    Result := TAWSLambda4DResponse.Create;
    Result.Body := LJSON.ToJSON;
    System.Writeln(Result.Body);
  finally
    LJSON.Free;
  end;
end;

{ THellLambdaHTTPHandle }

function THellLambdaHTTPHandle.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LJSON: TJSONObject;
  LNowUTC: TDateTime;
begin
  Result := TAWSLambda4DHTTPResponse.Create;
  Result.StatusCode := 200;
  Result.Headers.Add('content-type', 'application/json; charset=utf-8');
  LNowUTC := TTimeZone.Local.ToUniversalTime(Now);

  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('dataAtual', FormatDateTime('yyyy-mm-dd', LNowUTC));
    LJSON.AddPair('dataHoraUtc', DateToISO8601(LNowUTC, True));
    LJSON.AddPair('timezone', 'UTC');
    Result.SetBody(LJSON.ToJSON);
  finally
    LJSON.Free;
  end;
end;

end.
