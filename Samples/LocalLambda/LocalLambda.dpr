program LocalLambda;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.Runtime.API,
  AWSLambda4D.Runtime.LocalServer,
  AWSLambda4D.JsonProcessor.Handler;

var
  LServer: TAWSLambda4DRuntimeLocalServer;
  LAPI: IAWSLambda4DRuntimeAPI;
  LHandler: IAWSLambda4DHandler;
  LRuntime: TAWSLambda4DRuntime;
  LResult: TAWSLambda4DLocalResult;
  I: Integer;
begin
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;

  LServer := TAWSLambda4DRuntimeLocalServer.Create(9001);

  try
    Writeln('Iniciando servidor HTTP local...');

    LServer.Start;

    Writeln('Servidor ativo em 127.0.0.1:9001');
    Writeln;

    // Eventos que serão entregues pelo servidor.
    LServer.AddInvocation('{"name":"Gabriel","value":100}');
    LServer.AddInvocation('{"forceError":true}');
    LServer.AddInvocation('{"name":"Produto A","value":250}');

    // Utiliza a implementação HTTP real.
    LAPI := TAWSLambda4DRuntimeAPI.Create('127.0.0.1:9001');

    LHandler := TJsonProcessorHandler.Create;
    LRuntime := TAWSLambda4DRuntime.Create(LAPI);
    try
      Writeln('Executando Lambda Runtime...');
      Writeln;

      LRuntime.Run(LHandler, 3);

      Writeln('Execucao finalizada.');
      Writeln;

      Writeln('Resultados HTTP recebidos:');
      Writeln('--------------------------------');

      for I := 0 to LServer.ResultCount - 1 do
      begin
        LResult := LServer.GetResult(I);

        try
          Writeln('Request ID: ', LResult.RequestId);

          if LResult.Error then
          begin
            Writeln('Tipo: ERROR');
            Writeln('Error Type: ', LResult.ErrorType);
            Writeln('Body: ', LResult.Body);
          end
          else
          begin
            Writeln('Tipo: RESPONSE');
            Writeln('Body: ', LResult.Body);
          end;

          Writeln('--------------------------------');
        finally
          LResult.Free;
        end;
      end;

    finally
      LRuntime.Free;
      LHandler := nil;
      LAPI := nil;
    end;

  finally
    LServer.Stop;
    LServer.Free;
  end;

  Writeln;
  Writeln('Testes finalizados.');
  Readln;
end.

