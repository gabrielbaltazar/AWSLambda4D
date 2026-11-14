unit AWSLambda4D;

interface

uses
  AWSLambda4D.Classes,
  AWSLambda4D.HTTP.Events,
  AWSLambda4D.HTTP.Router,
  AWSLambda4D.HTTP.Types,
  AWSLambda4D.Runner,
  AWSLambda4D.Runtime.Interfaces;

type
  // Router
  TAWSLambda4DHTTPRouter = AWSLambda4D.HTTP.Router.TAWSLambda4DHTTPRouter;

  // HTTP
  TAWSLambda4DHTTPHandlerProc = AWSLambda4D.HTTP.Types.TAWSLambda4DHTTPHandlerProc;

  IAWSLambda4DHTTPHandler = AWSLambda4D.HTTP.Types.IAWSLambda4DHTTPHandler;

  IAWSLambda4DHTTPRouter = AWSLambda4D.HTTP.Types.IAWSLambda4DHTTPRouter;

  TAWSLambda4DHTTPRequest = AWSLambda4D.HTTP.Types.TAWSLambda4DHTTPRequest;

  TAWSLambda4DHTTPResponse = AWSLambda4D.HTTP.Types.TAWSLambda4DHTTPResponse;

  // HTTP Events
  IAWSLambda4DHTTPPayloadV2 = AWSLambda4D.HTTP.Events.IAWSLambda4DHTTPPayloadV2;

  TAWSLambda4DHTTPPayloadV2 = AWSLambda4D.HTTP.Events.TAWSLambda4DHTTPPayloadV2;

  // Runtime
  TAWSLambda4DRequest = AWSLambda4D.Classes.TAWSLambda4DRequest;

  TAWSLambda4DResponse = AWSLambda4D.Classes.TAWSLambda4DResponse;

  TAWSLambda4DContext = AWSLambda4D.Classes.TAWSLambda4DContext;

  TAWSLambda4DHandlerProc = AWSLambda4D.Runtime.Interfaces.TAWSLambda4DHandlerProc;

  IAWSLambda4DHandler = AWSLambda4D.Runtime.Interfaces.IAWSLambda4DHandler;

  // Runner
  TAWSLambda4Runner = AWSLambda4D.Runner.TAWSLambda4Runner;

  TAWSLambda4D = class;
  TAWSLambda4DClass = class of TAWSLambda4D;

  TAWSLambda4D = class
  private
    class var FRouter: IAWSLambda4DHTTPRouter;
  public
    class function Router: IAWSLambda4DHTTPRouter;
    // Descarta as rotas registradas (util em testes).
    class procedure Reset;

    class function Add(const AMethod: string; const APath: string;
      const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass; overload;
    class function Add(const AMethod: string; const APath: string;
      const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass; overload;

    class function Get(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass; overload;
    class function Get(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass; overload;
    class function Post(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass; overload;
    class function Post(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass; overload;
    class function Put(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass; overload;
    class function Put(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass; overload;
    class function Delete(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass; overload;
    class function Delete(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass; overload;
    class function Patch(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass; overload;
    class function Patch(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass; overload;

    // Dentro da Lambda: loop normal (0 = infinito).
    class procedure Run(const AMaxInvocations: Integer = 0);
    // Fora da Lambda: simula uma unica requisicao e imprime a resposta no console.
    // Dentro da Lambda comporta-se como Run.
    class procedure RunLocal(const APayload: IAWSLambda4DHTTPPayloadV2; const APort: Integer = 9001); overload;
    class procedure RunLocal(const AEvent: string; const APort: Integer = 9001); overload;
    class function SelfHosted: Boolean;
  end;

implementation

{ TAWSLambda4D }

class function TAWSLambda4D.Router: IAWSLambda4DHTTPRouter;
begin
  if FRouter = nil then
    FRouter := TAWSLambda4DHTTPRouter.New;
  Result := FRouter;
end;

class procedure TAWSLambda4D.Reset;
begin
  FRouter := nil;
end;

class function TAWSLambda4D.Add(const AMethod: string; const APath: string;
  const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass;
begin
  Result := Self;
  Router.Add(AMethod, APath, AHandler);
end;

class function TAWSLambda4D.Add(const AMethod: string; const APath: string;
  const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass;
begin
  Result := Self;
  Router.Add(AMethod, APath, AHandler);
end;

class function TAWSLambda4D.Get(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass;
begin
  Result := Add('GET', APath, AHandler);
end;

class function TAWSLambda4D.Get(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass;
begin
  Result := Add('GET', APath, AHandler);
end;

class function TAWSLambda4D.Post(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass;
begin
  Result := Add('POST', APath, AHandler);
end;

class function TAWSLambda4D.Post(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass;
begin
  Result := Add('POST', APath, AHandler);
end;

class function TAWSLambda4D.Put(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass;
begin
  Result := Add('PUT', APath, AHandler);
end;

class function TAWSLambda4D.Put(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass;
begin
  Result := Add('PUT', APath, AHandler);
end;

class function TAWSLambda4D.Delete(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass;
begin
  Result := Add('DELETE', APath, AHandler);
end;

class function TAWSLambda4D.Delete(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass;
begin
  Result := Add('DELETE', APath, AHandler);
end;

class function TAWSLambda4D.Patch(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): TAWSLambda4DClass;
begin
  Result := Add('PATCH', APath, AHandler);
end;

class function TAWSLambda4D.Patch(const APath: string; const AHandler: TAWSLambda4DHTTPHandlerProc): TAWSLambda4DClass;
begin
  Result := Add('PATCH', APath, AHandler);
end;

class procedure TAWSLambda4D.Run(const AMaxInvocations: Integer);
begin
  TAWSLambda4Runner.Run(Router, AMaxInvocations);
end;

class procedure TAWSLambda4D.RunLocal(const APayload: IAWSLambda4DHTTPPayloadV2; const APort: Integer);
begin
  TAWSLambda4Runner.RunLocal(Router, APayload, APort);
end;

class procedure TAWSLambda4D.RunLocal(const AEvent: string; const APort: Integer);
begin
  TAWSLambda4Runner.RunLocal(Router, AEvent, APort);
end;

class function TAWSLambda4D.SelfHosted: Boolean;
begin
  Result := TAWSLambda4Runner.SelfHosted;
end;

end.
