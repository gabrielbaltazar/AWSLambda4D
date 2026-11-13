unit AWSLambda4D.Runner;

interface

uses
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.HTTP.Types;

type
  TAWSLambda4Runner = class
  public
    class procedure Run(const AHandler: IAWSLambda4DHTTPHandler; const AMaxInvocations: Integer = 0); overload;
    class procedure Run(const AHandler: IAWSLambda4DHandler; const AMaxInvocations: Integer = 0); overload;
    class procedure Run(const AHandler: TAWSLambda4DHandlerProc; const AMaxInvocations: Integer = 0); overload;
  end;

implementation

uses
  System.SysUtils,
  AWSLambda4D.Classes,
  AWSLambda4D.HTTP.Adapter,
  AWSLambda4D.Runtime,
  AWSLambda4D.Runtime.API;

type
  // Adapta uma funcao anonima para IAWSLambda4DHandler.
  TAWSLambda4DProcHandler = class(TInterfacedObject, IAWSLambda4DHandler)
  private
    FProc: TAWSLambda4DHandlerProc;
  protected
    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  public
    constructor Create(const AProc: TAWSLambda4DHandlerProc);
  end;

{ TAWSLambda4DProcHandler }

constructor TAWSLambda4DProcHandler.Create(const AProc: TAWSLambda4DHandlerProc);
begin
  if not Assigned(AProc) then
    raise EArgumentNilException.Create('AHandler');
  inherited Create;
  FProc := AProc;
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
  Run(IAWSLambda4DHandler(TAWSLambda4DProcHandler.Create(AHandler)), AMaxInvocations);
end;

end.
