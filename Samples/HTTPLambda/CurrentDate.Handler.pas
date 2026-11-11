unit CurrentDate.Handler;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON,
  AWSLambda4D.HTTP.Adapter,
  AWSLambda4D.HTTP.Types;

type
  TCurrentDateHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  public
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  end;

implementation

function TCurrentDateHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LJSON: TJSONObject;
  LNowUTC: TDateTime;
begin
  Result := TAWSLambda4DHTTPResponse.Create;
  try
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
  except
    Result.Free;
    raise;
  end;
end;

end.

