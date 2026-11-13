program HelloLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D;

begin
{$IFDEF MSWINDOWS}
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  TAWSLambda4Runner.Run(
    function(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse
    begin
      Result := TAWSLambda4DResponse.Create;
      System.Writeln(ARequest.Body);
      Result.Body := '{"message":"hello"}';
    end);
end.
