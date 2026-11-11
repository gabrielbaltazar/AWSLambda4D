unit AWSLambda4D.InspectionHandler;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Classes,
  AWSLambda4D.HTTP.Types,
  AWSLambda4D.HTTP.Adapter;

type
  TAWSLambda4DInspectionHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  end;

implementation

{ TAWSLambda4DInspectionHandler }

function TAWSLambda4DInspectionHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LJSON: TJSONObject;
  LBody: string;
begin
  Result := TAWSLambda4DHTTPResponse.Create;
  try
    Result.StatusCode := 200;
    Result.Headers.Add('content-type', 'application/json; charset=utf-8');
    LBody := TEncoding.UTF8.GetString(ARequest.Body);
    LJSON := TJSONObject.Create;
    try
      LJSON.AddPair('method', ARequest.Method);
      LJSON.AddPair('path', ARequest.Path);
      LJSON.AddPair('rawQueryString', ARequest.RawQueryString);

      // Primeiro valor de cada coleção.
      LJSON.AddPair('headerXTeste', ARequest.Headers.First('x-teste'));
      LJSON.AddPair('queryId', ARequest.QueryParams.First('id'));
      LJSON.AddPair('cookieSessao', ARequest.Cookies.First);
      LJSON.AddPair('body', LBody);
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
