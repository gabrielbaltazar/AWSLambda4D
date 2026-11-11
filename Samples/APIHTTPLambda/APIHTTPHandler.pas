unit APIHTTPHandler;

interface

uses
  System.JSON,
  AWSLambda4D.HTTP.Types;

type
  TAPIHTTPHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  public
    class function New: IAWSLambda4DHTTPHandler;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils;

{ TAPIHTTPHandler }

function TAPIHTTPHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LJSON: TJSONObject;
  LNowUTC: TDateTime;
begin
  LNowUTC := TTimeZone.Local.ToUniversalTime(Now);
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('dataAtual', FormatDateTime('yyyy-mm-dd', LNowUTC));
    LJSON.AddPair('dataHoraUtc', DateToISO8601(LNowUTC, True));
    LJSON.AddPair('timezone', 'UTC');
    Result := TAWSLambda4DHTTPResponse.Create;
    Result.StatusCode := 201;
    Result.Headers.Add('content-type', 'application/json; charset=utf-8');
    Result.Headers.Add('location', '1');
    Result.SetBody(LJSON.ToJSON);
  finally
    LJSON.Free;
  end;
end;

class function TAPIHTTPHandler.New: IAWSLambda4DHTTPHandler;
begin
  Result := Self.Create;
end;

end.
