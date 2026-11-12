program APIHTTPRouterLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D.HTTP.Types,
  AWSLambda4D.HTTP.Router,
  AWSLambda4D.Runner,
  Ping.Handler in 'Ping.Handler.pas';

var
  LRouter: IAWSLambda4DHTTPRouter;
  LPing: IAWSLambda4DHTTPHandler;
begin
  LRouter := TAWSLambda4DHTTPRouter.New;
  LPing := TPingHandler.New;

  LRouter.Get('/ping', LPing)
    .Get('/ping/:id', LPing);

  TAWSLambda4Runner.Run(LRouter);
end.
