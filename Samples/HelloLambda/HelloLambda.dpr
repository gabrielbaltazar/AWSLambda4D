program HelloLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D.Runner,
  HelloLambda.Handle in 'HelloLambda.Handle.pas';

begin
{$IFDEF MSWINDOWS}
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  TAWSLambda4Runner.Run(THelloLambdaHandle.New);
end.
