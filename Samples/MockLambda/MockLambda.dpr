program MockLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D.Runtime,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.Runtime.API,
  AWSLambda4D.Runtime.API.Mock,
  AWSLambda4D.JsonProcessor.Handler;

var
  I: Integer;
  LMockObject: TAWSLambda4DRuntimeAPIMock;
  LAPI: IAWSLambda4DRuntimeAPI;
  LHandler: IAWSLambda4DHandler;
  LRuntime: TAWSLambda4DRuntime;
  LResult: TAWSLambda4DMockResult;

begin
  LMockObject := TAWSLambda4DRuntimeAPIMock.Create;
  LAPI := LMockObject;
  LHandler := TJsonProcessorHandler.Create;
  LRuntime := TAWSLambda4DRuntime.Create(LAPI);
  try
    // Primeira invocação: sucesso.
    LMockObject.AddInvocation('{"name":"Gabriel","value":100}');
    // Segunda invocação: erro.
    LMockObject.AddInvocation('{"forceError":true}');
    // Terceira invocação: sucesso.
    LMockObject.AddInvocation('{"name":"Produto A","value":250}');

    Writeln('Iniciando testes do Lambda Runtime...');
    Writeln;

    try
      LRuntime.Run(LHandler);
    except
      on E: EAWSLambda4DMockStop do
        Writeln('Fim das invocacoes simuladas.');
    end;

    Writeln;
    Writeln('Resultados:');
    Writeln('--------------------------------');

    for I := 0 to LMockObject.ResultCount - 1 do
    begin
      LResult := LMockObject.GetResult(I);

      Writeln('Request ID: ', LResult.RequestId);

      case LResult.ResultType of
        mrtResponse:
          begin
            Writeln('Tipo: RESPONSE');
            Writeln('Body: ', LResult.Body);
          end;

        mrtError:
          begin
            Writeln('Tipo: ERROR');
            Writeln('Erro: ', LResult.ErrorType);
            Writeln('Mensagem: ', LResult.ErrorMessage);
          end;
      end;

      Writeln('--------------------------------');
    end;

    Writeln;
    Writeln('Invocacoes processadas: ', LMockObject.InvocationCount);
    Writeln('Resultados registrados: ', LMockObject.ResultCount);
  finally
    LRuntime.Free;
    LHandler := nil;
    LAPI := nil;
  end;

  Readln;
end.
