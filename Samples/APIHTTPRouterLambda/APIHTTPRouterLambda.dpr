program APIHTTPRouterLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D;

procedure MiddlewareLog(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
  const ANext: TProc);
begin
  Writeln('-> ', ARequest.Method, ' ', ARequest.Path);
  ANext();
  Writeln('<- ', AResponse.StatusCode);
end;

begin
{$IFDEF MSWINDOWS}
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  TAWSLambda4D
    // Middleware: roda antes e depois de toda rota (aqui, um log simples da requisicao).
    .Use(MiddlewareLog)
    .Get('ping',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        AResponse.StatusCode := 200;
        AResponse.SetBody('{"message":"pong"}');
        Writeln('Rota ping executada');
      end);

  // Fora da Lambda (AWS_LAMBDA_RUNTIME_API ausente), simula uma unica requisicao
  // do API Gateway (HTTP API, payload v2) e imprime a resposta no console.
  if TAWSLambda4D.SelfHosted then
  begin
    TAWSLambda4D.RunLocal(TAWSLambda4DHTTPPayloadV2.New
      .RawPath('/ping')
      .RequestContext.HTTP
        .Method('GET').Path('/ping').&End.&End);
  end
  else
    TAWSLambda4D.Run;

  System.Readln;
end.
