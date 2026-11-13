unit AWSLambda4D.Runner;

interface

uses
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.HTTP.Types;

type
  TAWSLambda4Runner = class
  private
    class procedure RunLocalInvocation(const AHandler: IAWSLambda4DHandler; const AEvent: string;
      const APort: Integer); static;
  public
    class function SelfHosted: Boolean;

    class procedure Run(const AHandler: IAWSLambda4DHTTPHandler; const AMaxInvocations: Integer = 0); overload;
    class procedure Run(const AHandler: IAWSLambda4DHandler; const AMaxInvocations: Integer = 0); overload;
    class procedure Run(const AHandler: TAWSLambda4DHandlerProc; const AMaxInvocations: Integer = 0); overload;

    // Mesmo codigo para desenvolvimento e producao:
    // - Fora da Lambda (AWS_LAMBDA_RUNTIME_API nao definida; Windows ou Linux): sobe o servidor
    //   local que emula a Runtime API, entrega AEvent como unica invocacao, executa o handler,
    //   imprime a resposta no console e retorna.
    // - Dentro da Lambda (AWS_LAMBDA_RUNTIME_API definida): ignora AEvent/APort e executa o
    //   loop normal (Run).
    class procedure RunLocal(const AHandler: TAWSLambda4DHandlerProc; const AEvent: string;
      const APort: Integer = 9001); overload;
    class procedure RunLocal(const AHandler: IAWSLambda4DHandler; const AEvent: string;
      const APort: Integer = 9001); overload;
    class procedure RunLocal(const AHandler: IAWSLambda4DHTTPHandler; const AEvent: string;
      const APort: Integer = 9001); overload;
  end;

implementation

uses
  System.SysUtils,
  AWSLambda4D.Classes,
  AWSLambda4D.HTTP.Adapter,
  AWSLambda4D.Runtime,
  AWSLambda4D.Runtime.API,
  AWSLambda4D.Runtime.LocalServer;

type
  TAWSLambda4DProcHandler = class(TInterfacedObject, IAWSLambda4DHandler)
  private
    FProc: TAWSLambda4DHandlerProc;
  protected
    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  public
    constructor Create(const AProc: TAWSLambda4DHandlerProc);
    // Devolve a interface (e nao a instancia) para que a contagem de referencias libere o objeto.
    class function New(const AProc: TAWSLambda4DHandlerProc): IAWSLambda4DHandler;
  end;

{ TAWSLambda4DProcHandler }

constructor TAWSLambda4DProcHandler.Create(const AProc: TAWSLambda4DHandlerProc);
begin
  if not Assigned(AProc) then
    raise EArgumentNilException.Create('AHandler');
  inherited Create;
  FProc := AProc;
end;

class function TAWSLambda4DProcHandler.New(const AProc: TAWSLambda4DHandlerProc): IAWSLambda4DHandler;
begin
  Result := Self.Create(AProc);
end;

function TAWSLambda4DProcHandler.Handle(const ARequest: TAWSLambda4DRequest;
  const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
begin
  Result := FProc(ARequest, AContext);
end;

{ TAWSLambda4Runner }

class procedure TAWSLambda4Runner.Run(const AHandler: IAWSLambda4DHTTPHandler; const AMaxInvocations: Integer = 0);
var
  LAPI: IAWSLambda4DRuntimeAPI;
  LAdapter: IAWSLambda4DHandler;
  LRuntime: TAWSLambda4DRuntime;
begin
  LAPI := TAWSLambda4DRuntimeAPI.New;
  LAdapter := TAWSLambda4DHTTPAdapter.New(AHandler);
  LRuntime := TAWSLambda4DRuntime.Create(LAPI);
  try
    LRuntime.Run(LAdapter, AMaxInvocations);
  finally
    LRuntime.Free;
    LAdapter := nil;
    LAPI := nil;
  end;
end;

class procedure TAWSLambda4Runner.Run(const AHandler: IAWSLambda4DHandler; const AMaxInvocations: Integer);
var
  LRuntimeAPI: IAWSLambda4DRuntimeAPI;
  LRuntime: TAWSLambda4DRuntime;
begin
  LRuntimeAPI := TAWSLambda4DRuntimeAPI.New;
  LRuntime := TAWSLambda4DRuntime.Create(LRuntimeAPI);
  try
    LRuntime.Run(AHandler, AMaxInvocations);
  finally
    LRuntime.Free;
  end;
end;

class procedure TAWSLambda4Runner.Run(const AHandler: TAWSLambda4DHandlerProc; const AMaxInvocations: Integer);
begin
  Run(TAWSLambda4DProcHandler.New(AHandler), AMaxInvocations);
end;

class procedure TAWSLambda4Runner.RunLocalInvocation(const AHandler: IAWSLambda4DHandler; const AEvent: string;
  const APort: Integer);
var
  LServer: TAWSLambda4DRuntimeLocalServer;
  LResult: TAWSLambda4DLocalResult;
  LAPI: IAWSLambda4DRuntimeAPI;
  LRuntime: TAWSLambda4DRuntime;
begin
  LServer := TAWSLambda4DRuntimeLocalServer.Create(APort);
  try
    LServer.Start;
    LServer.AddInvocation(AEvent);

    LAPI := TAWSLambda4DRuntimeAPI.New('127.0.0.1:' + IntToStr(APort));
    LRuntime := TAWSLambda4DRuntime.Create(LAPI);
    try
      LRuntime.Run(AHandler, 1);
    finally
      LRuntime.Free;
    end;

    if LServer.ResultCount = 0 then
      Exit;

    LResult := LServer.GetResult(0);
    try
      if LResult.Error then
        Writeln('[RunLocal] ERROR ', LResult.ErrorType, ': ', LResult.Body)
      else
        Writeln('[RunLocal] Response: ', LResult.Body);
    finally
      LResult.Free;
    end;
  finally
    LServer.Stop;
    LServer.Free;
  end;
end;

class function TAWSLambda4Runner.SelfHosted: Boolean;
var
  LEnvironment: string;
begin
  // Na Lambda a variavel e definida pela AWS; fora dela, executa contra o servidor local.
  LEnvironment := GetEnvironmentVariable('AWS_LAMBDA_RUNTIME_API');
  Result := LEnvironment = '';
end;

class procedure TAWSLambda4Runner.RunLocal(const AHandler: IAWSLambda4DHandler; const AEvent: string;
  const APort: Integer);
begin
  if SelfHosted then
    RunLocalInvocation(AHandler, AEvent, APort)
  else
    Run(AHandler);
end;

class procedure TAWSLambda4Runner.RunLocal(const AHandler: TAWSLambda4DHandlerProc; const AEvent: string;
  const APort: Integer);
begin
  RunLocal(TAWSLambda4DProcHandler.New(AHandler), AEvent, APort);
end;

class procedure TAWSLambda4Runner.RunLocal(const AHandler: IAWSLambda4DHTTPHandler; const AEvent: string;
  const APort: Integer);
begin
  RunLocal(TAWSLambda4DHTTPAdapter.New(AHandler), AEvent, APort);
end;

end.
