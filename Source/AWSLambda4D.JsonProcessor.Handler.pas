unit AWSLambda4D.JsonProcessor.Handler;

interface

uses
  System.SysUtils,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces;

type
  TJsonProcessorHandler = class(TInterfacedObject, IAWSLambda4DHandler)
  protected
    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  end;

implementation

{ TJsonProcessorHandler }

function TJsonProcessorHandler.Handle(const ARequest: TAWSLambda4DRequest;
  const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
begin
  if Pos('"forceError":true', ARequest.Body) > 0 then
    raise Exception.Create('Simulated error during JSON processing.');

  Result := TAWSLambda4DResponse.Create;
  Result.Body := Format('{"processed":true,"requestId":"%s","input":%s}', [AContext.AwsRequestId, ARequest.Body]);
end;

end.
