program APIHTTPLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D,
  APIHTTPHandler in 'APIHTTPHandler.pas';

var
  LHttpHandler: IAWSLambda4DHTTPHandler;
begin
  try
    LHttpHandler := TAPIHTTPHandler.Create;
    TAWSLambda4DRunner.Run(LHttpHandler);
  except
    on E: Exception do
    begin
      Writeln(ErrOutput, E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
