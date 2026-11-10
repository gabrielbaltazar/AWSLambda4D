program HelloLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.Runtime.LocalServer,
  AWSLambda4D.Runtime.API,
  AWSLambda4D.Runtime,
  HelloLambda.Handle in 'HelloLambda.Handle.pas';

var
//  LServer: TAWSLambda4DRuntimeLocalServer;
  LAPI: IAWSLambda4DRuntimeAPI;
  LHandler: IAWSLambda4DHandler;
  LRuntime: TAWSLambda4DRuntime;
begin
{$IFDEF MSWINDOWS}
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

//  LServer := TAWSLambda4DRuntimeLocalServer.Create;
  try
//    LServer.Start;
//    LServer.AddInvocation('');
//    LAPI := TAWSLambda4DRuntimeAPI.New('127.0.0.1:9001');
    LAPI := TAWSLambda4DRuntimeAPI.New;

    LHandler := THellLambdaHandle.Create;
    LRuntime := TAWSLambda4DRuntime.Create(LAPI);
    try
      LRuntime.Run(LHandler, 1);
    finally
      LRuntime.Free;
    end;
  finally
//    LServer.Stop;
//    LServer.Free;
  end;
end.
