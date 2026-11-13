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
  end;

implementation

uses
  AWSLambda4D.Classes,
  AWSLambda4D.HTTP.Adapter,
  AWSLambda4D.Runtime,
  AWSLambda4D.Runtime.API;

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

end.
