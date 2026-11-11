program HTTPSimulator;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D.Classes,
  AWSLambda4D.HTTP.Types,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.Runtime,
  AWSLambda4D.HTTP.Adapter,
  AWSLambda4D.InspectionHandler,
  AWSLambda4D.EventSimulator;

procedure ExecuteTest(const AVersion: string; const AEvent: string; const AAdapter: IAWSLambda4DHandler);
var
  LRequest: TAWSLambda4DRequest;
  LResponse: TAWSLambda4DResponse;
  LContext: TAWSLambda4DContext;
begin
  LRequest := TAWSLambda4DRequest.Create;
  LContext := TAWSLambda4DContext.Create;
  LResponse := nil;

  try
    LRequest.Body := AEvent;
    LRequest.RequestId := 'local-' + AVersion;

    LContext.AwsRequestId := LRequest.RequestId;

    Writeln('====================================');
    Writeln('TESTE PAYLOAD ', AVersion);
    Writeln('====================================');

    LResponse := AAdapter.Handle(LRequest, LContext);

    Writeln('Resposta do Adapter:');
    Writeln(LResponse.Body);
    Writeln;

  finally
    LResponse.Free;
    LContext.Free;
    LRequest.Free;
  end;
end;

var
  LHttpHandler: IAWSLambda4DHTTPHandler;
  LAdapter: IAWSLambda4DHandler;
begin
  try
    LHttpHandler := TAWSLambda4DInspectionHandler.Create;
    LAdapter := TAWSLambda4DHTTPAdapter.Create(LHttpHandler);

    try
      ExecuteTest('1.0', TAWSLambda4DEventSimulator.CreateV1Event, LAdapter);
      ExecuteTest('2.0', TAWSLambda4DEventSimulator.CreateV2Event, LAdapter);
    finally
      LAdapter := nil;
      LHttpHandler := nil;
    end;
  except
    on E: Exception do
    begin
      Writeln('ERRO: ', E.ClassName);
      Writeln(E.Message);
      Halt(1);
    end;
  end;

  Writeln('Pressione ENTER para finalizar...');
  Readln;
end.
