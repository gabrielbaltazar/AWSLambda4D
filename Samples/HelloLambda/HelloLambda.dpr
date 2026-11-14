program HelloLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D;

function HelloWorld(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
begin
  Result := TAWSLambda4DResponse.Create;
  System.Writeln(ARequest.Body);
  Result.Body := '{"message":"hello"}';
end;

begin
{$IFDEF MSWINDOWS}
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  if TAWSLambda4DRunner.SelfHosted then
    TAWSLambda4DRunner.RunLocal(HelloWorld, '{"name":"Gabriel"}')
  else
    TAWSLambda4DRunner.Run(HelloWorld);

  System.Readln;
end.
