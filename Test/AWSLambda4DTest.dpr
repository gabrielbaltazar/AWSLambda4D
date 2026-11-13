program AWSLambda4DTest;

{$IFDEF CI}
{$UNDEF TESTINSIGHT}
{$ENDIF}
{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF }
  {$IFNDEF TESTINSIGHT}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF }
  DUnitX.TestFramework,
  AWSLambda4D.HTTP.Router.Test in 'Source\AWSLambda4D.HTTP.Router.Test.pas',
  AWSLambda4D.HTTP.Types.Test in 'Source\AWSLambda4D.HTTP.Types.Test.pas',
  AWSLambda4D.HTTP.Adapter.Test in 'Source\AWSLambda4D.HTTP.Adapter.Test.pas';

{ keep comment here to protect the following conditional from being removed by the IDE when adding a unit }
{$IFNDEF TESTINSIGHT}
var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;
  LNunitLogger : ITestLogger;
{$ENDIF}
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
{$ELSE}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test LRunner
    LRunner := TDUnitX.CreateRunner;
    //Tell the LRunner to use RTTI to find Fixtures
    LRunner.UseRTTI := True;
    //When true, Assertions must be made during tests;
    LRunner.FailsOnNoAsserts := True;

    //tell the LRunner how we will log things
    //Log to the console window if desired
    if TDUnitX.Options.ConsoleMode <> TDunitXConsoleMode.Off then
    begin
      LLogger := TDUnitXConsoleLogger.Create(TDUnitX.Options.ConsoleMode = TDunitXConsoleMode.Quiet);
      LRunner.AddLogger(LLogger);
    end;
    //Generate an NUnit compatible XML File
    LNunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    LRunner.AddLogger(LNunitLogger);

    //Run tests
    LResults := LRunner.Execute;
    System.ExitCode := TDUnitX.ExitCodeFor(LResults);

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    // Sempre pausa ao final (fora do CI) para o resultado ficar visivel.
    System.Write('Done.. press <Enter> key to quit.');
    System.Readln;
    {$ENDIF}
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_ERRORS;
    end;
  end;
{$ENDIF}
end.
