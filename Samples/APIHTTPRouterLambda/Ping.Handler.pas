unit Ping.Handler;

interface

uses
  AWSLambda4D.HTTP.Types;

type
  TPingHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  public
    class function New: IAWSLambda4DHTTPHandler;
  end;

implementation

uses
  System.SysUtils;

{ TPingHandler }

function TPingHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LId: string;
  LNumero: Integer;
begin
  LId := ARequest.PathParams.Field('id').AsString;
  LNumero := ARequest.PathParams.Field('numero').AsInteger;
  Result := TAWSLambda4DHTTPResponse.Create;
  Result.StatusCode := 200;
  Result.Headers.Add('redis', 'muito bom');
  Result.SetBody(Format('{"message":"pong %s %d"}', [LId, LNumero]));
end;

class function TPingHandler.New: IAWSLambda4DHTTPHandler;
begin
  Result := Self.Create;
end;

end.
