program APIHTTPCrud;

{$APPTYPE CONSOLE}

{$R *.res}

// CRUD de clientes (GET lista, GET por id, POST, PUT, DELETE) com dados simulados em memoria.

uses
  System.SysUtils,
  AWSLambda4D,
  APIHTTPCrud.Customer in 'APIHTTPCrud.Customer.pas',
  APIHTTPCrud.Controller in 'APIHTTPCrud.Controller.pas';

// Simula uma requisicao do API Gateway (HTTP API, payload v2) e imprime a resposta no console.
procedure Simulate(const AMethod: string; const APath: string; const ABody: string = '');
var
  LPayload: IAWSLambda4DHTTPPayloadV2;
begin
  Writeln;
  Writeln('>>> ', AMethod, ' ', APath, ' ', ABody);

  LPayload := TAWSLambda4DHTTPPayloadV2.New.RawPath(APath);
  if ABody <> '' then
    LPayload.AddHeader('content-type', 'application/json').Body(ABody);
  LPayload.RequestContext.HTTP.Method(AMethod).Path(APath);

  TAWSLambda4D.RunLocal(LPayload);
end;

var
  LController: TCustomerController;
begin
{$IFDEF MSWINDOWS}
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  LController := TCustomerController.Create;
  try
    TAWSLambda4D
      .Get('/customers', LController.List)
      .Get('/customers/:id', LController.Find)
      .Post('/customers', LController.Insert)
      .Put('/customers/:id', LController.Update)
      .Delete('/customers/:id', LController.Delete);

    // Fora da Lambda (AWS_LAMBDA_RUNTIME_API ausente), percorre o CRUD simulando requisicoes.
    // Os dados ficam em memoria e persistem entre uma simulacao e outra.
    if TAWSLambda4D.SelfHosted then
    begin
      Simulate('GET', '/customers');
      Simulate('GET', '/customers/1');
      Simulate('POST', '/customers', '{"name":"Carlos Lima","birthdayDate":"1990-05-21","document":"555.666.777-88"}');
      Simulate('GET', '/customers/4');
      Simulate('PUT', '/customers/4', '{"name":"Carlos A. Lima","birthdayDate":"1990-05-21","document":"555.666.777-88"}');
      Simulate('DELETE', '/customers/4');
      Simulate('GET', '/customers/4');
      Simulate('POST', '/customers', '{"name":"","birthdayDate":"x"}');
      Simulate('GET', '/customers/abc');

      System.Readln;
    end
    else
      TAWSLambda4D.Run;
  finally
    TAWSLambda4D.Reset;
    LController.Free;
  end;
end.
