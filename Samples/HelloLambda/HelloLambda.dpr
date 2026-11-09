program HelloLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D.Classes in '..\..\Source\AWSLambda4D.Classes.pas',
  AWSLambda4D.Runtime.Interfaces in '..\..\Source\AWSLambda4D.Runtime.Interfaces.pas',
  AWSLambda4D.Runtime in '..\..\Source\AWSLambda4D.Runtime.pas',
  AWSLambda4D.Runtime.API in '..\..\Source\AWSLambda4D.Runtime.API.pas';

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
