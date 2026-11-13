program APIHTTPRouterLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D;

var
  LRouter: IAWSLambda4DHTTPRouter;
  LPayload: IAWSLambda4DHTTPPayloadV2;
begin
{$IFDEF MSWINDOWS}
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  LRouter := TAWSLambda4DHTTPRouter.New;
  LRouter.Get('ping',
    function(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse
    begin
      Result := TAWSLambda4DHTTPResponse.Create;
      Result.StatusCode := 200;
      Result.SetBody('{"message":"pong"}');
    end);

  // Fora da Lambda (AWS_LAMBDA_RUNTIME_API ausente), simula uma unica requisicao
  // do API Gateway (HTTP API, payload v2) e imprime a resposta no console.
  if TAWSLambda4Runner.SelfHosted then
  begin
    TAWSLambda4Runner.RunLocal(LRouter,
      TAWSLambda4DHTTPPayloadV2.New
        .RawPath('/ping')
        .RequestContext.HTTP
          .Method('GET').Path('/ping').&End.&End);
  end
  else
    TAWSLambda4Runner.Run(LRouter);

  System.Readln;
end.
