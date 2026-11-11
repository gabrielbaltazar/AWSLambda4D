program HTTPLambda;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  AWSLambda4D.HTTP.Types,
  CurrentDate.Handler in 'CurrentDate.Handler.pas';

var
  LRequest: TAWSLambda4DHTTPRequest;
  LResponse: TAWSLambda4DHTTPResponse;
  LHandler: IAWSLambda4DHTTPHandler;
begin
  LHandler := TCurrentDateHandler.Create;
  LResponse := nil;
  LRequest := TAWSLambda4DHTTPRequest.Create;
  try
    try
      // Simula uma requisição HTTP GET
      LRequest.Method := 'GET';
      LRequest.Path := '/data-atual';
      LRequest.RawQueryString := '';

      // Invoca diretamente o HTTP Handler
      LResponse := LHandler.Execute(LRequest);

      // Exibe o resultado
      Writeln('HTTP Status: ', LResponse.StatusCode);
      Writeln;
      Writeln('Response Body:');
      Writeln(TEncoding.UTF8.GetString(LResponse.Body));
    except
      on E: Exception do
      begin
        Writeln('ERRO: ', E.ClassName);
        Writeln(E.Message);
      end;
    end;
  finally
    LResponse.Free;
    LRequest.Free;
  end;

  Writeln;
  Writeln('Pressione ENTER para finalizar...');
  Readln;
end.
