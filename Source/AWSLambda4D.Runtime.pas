unit AWSLambda4D.Runtime;

interface

uses
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces;

type
  TAWSLambda4DRuntime = class
  private
    FAPI: IAWSLambda4DRuntimeAPI;

    procedure ProcessInvocation(const AHandler: IAWSLambda4DHandler);
  public
    constructor Create(const AAPI: IAWSLambda4DRuntimeAPI);

    procedure Run(const AHandler: IAWSLambda4DHandler; const AMaxInvocations: Integer = 0);
  end;

implementation

uses
  System.SysUtils;

{ TAWSLambda4DRuntime }

constructor TAWSLambda4DRuntime.Create(const AAPI: IAWSLambda4DRuntimeAPI);
begin
  if AAPI = nil then
    raise ELambdaRuntimeAPI.Create('Lambda Runtime API implementation is required.');
  FAPI := AAPI;
end;

procedure TAWSLambda4DRuntime.ProcessInvocation(const AHandler: IAWSLambda4DHandler);
var
  LRequest: TAWSLambda4DRequest;
  LResponse: TAWSLambda4DResponse;
  LContext: TAWSLambda4DContext;
begin
  LRequest := nil;
  LResponse := nil;
  LContext := nil;
  try
    // 1. Busca a próxima invocação.
    LRequest := FAPI.NextInvocation(LContext);
    if not Assigned(LRequest) then
      raise ELambdaRuntimeAPI.Create('Runtime API returned an empty request.');

    if not Assigned(LContext) then
      raise ELambdaRuntimeAPI.Create('Runtime API returned an empty context.');

    // 2. Executa a função de negócio.
    try
      LResponse := AHandler.Handle(LRequest, LContext);
      if not Assigned(LResponse) then
        raise ELambdaRuntimeAPI.Create('Handler returned an empty response.');

    except
      on E: Exception do
      begin
        // 3. Comunica o erro à AWS.
        FAPI.SendError(LContext, 'Function.' + E.ClassName, E.Message);
        Exit;
      end;
    end;

    // 4. Envia a resposta para a AWS.
    FAPI.SendResponse(LContext, LResponse);
  finally
    // 5. Libera os objetos da invocação.
    LResponse.Free;
    LRequest.Free;
    LContext.Free;
  end;
end;

procedure TAWSLambda4DRuntime.Run(const AHandler: IAWSLambda4DHandler; const AMaxInvocations: Integer = 0);
var
  LCount: Integer;
begin
  if AHandler = nil then
    raise ELambdaRuntimeAPI.Create('Lambda Handler implementation is required.');

  if AMaxInvocations < 0 then
    raise ELambdaRuntimeAPI.Create('Maximum invocations cannot be negative.');

  LCount := 0;
  // Loop principal do Runtime.
  while (AMaxInvocations = 0) or (LCount < AMaxInvocations) do
  begin
    ProcessInvocation(AHandler);
    Inc(LCount);
  end;
end;

end.
