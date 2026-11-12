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
begin
  LId := ARequest.PathParams.First('id');
  Result := TAWSLambda4DHTTPResponse.Create;
  Result.StatusCode := 200;
  Result.SetBody(Format('{"message":"pong %s"}', [LId]));
end;

class function TPingHandler.New: IAWSLambda4DHTTPHandler;
begin
  Result := Self.Create;
end;

end.
