program WebHook;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D,
  WebHook.Handler in 'WebHook.Handler.pas';

var
  LRouter: IAWSLambda4DHTTPRouter;
begin
{$IFDEF MSWINDOWS}
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  LRouter := TAWSLambda4DHTTPRouter.New;
  LRouter.Post('/hook', TWebHookHandler.New);

  // Fora da Lambda (AWS_LAMBDA_RUNTIME_API ausente), simula um POST /hook e imprime a resposta no console.
  // Troque a urlHook por um endpoint seu para ver o webhook chegando.
  if TAWSLambda4Runner.SelfHosted then
    TAWSLambda4Runner.RunLocal(LRouter,
      TAWSLambda4DHTTPPayloadV2.New
        .AddHeader('content-type', 'application/json')
        .Body('{"urlHook":"https://httpbin.org/post","content":{"numero":123,"valor":150.5}}')
        .RequestContext.HTTP
          .Method('POST').Path('/hook').&End.&End)
  else
    TAWSLambda4Runner.Run(LRouter);

  System.Readln;
end.
