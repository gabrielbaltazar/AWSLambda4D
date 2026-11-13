program APIHTTPRouterLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D;

var
  LRouter: IAWSLambda4DHTTPRouter;
begin
  LRouter := TAWSLambda4DHTTPRouter.New;
  LRouter.Get('ping',
    function(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse
    begin
      Result := TAWSLambda4DHTTPResponse.Create;
      Result.StatusCode := 200;
      Result.SetBody('{"message":"pong"}');
    end);

  TAWSLambda4Runner.Run(LRouter);
end.
