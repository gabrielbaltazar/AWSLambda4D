unit AWSLambda4D.HTTP.Router;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  AWSLambda4D.HTTP.Types,
  AWSLambda4D.HTTP.RouteMatcher;

type
  TAWSLambda4DHTTPRoute = class
  public
    FMethod: string;
    FPath: string;
    FSpecificity: Integer;
    FHandler: IAWSLambda4DHTTPHandler;
  public
    constructor Create(const AMethod: string; const APath: string; const AHandler: IAWSLambda4DHTTPHandler);

    property Method: string read FMethod;
    property Path: string read FPath;
    property Specificity: Integer read FSpecificity;
    property Handler: IAWSLambda4DHTTPHandler read FHandler;
  end;

  TAWSLambda4DHTTPRouter = class(TInterfacedObject, IAWSLambda4DHTTPRouter)
  private
    FRoutes: TObjectList<TAWSLambda4DHTTPRoute>;

    procedure RegisterRoute(const AMethod: string; const APath: string; const AHandler: IAWSLambda4DHTTPHandler);
    function CreateErrorResponse(const AStatusCode: Integer; const AMessage: string): TAWSLambda4DHTTPResponse;
  public
    constructor Create;
    class function New: IAWSLambda4DHTTPRouter;
    destructor Destroy; override;

    function Add(const AMethod: string; const APath: string;
      const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Get(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Post(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Put(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Delete(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Patch(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  end;

implementation

uses
  System.JSON;

constructor TAWSLambda4DHTTPRoute.Create(const AMethod: string; const APath: string;
  const AHandler: IAWSLambda4DHTTPHandler);
begin
  inherited Create;
  FMethod := UpperCase(AMethod);
  FPath := APath;
  FHandler := AHandler;
  FSpecificity := TAWSLambda4DHTTPRouteMatcher.GetSpecificity(APath);
end;

constructor TAWSLambda4DHTTPRouter.Create;
begin
  inherited Create;
  FRoutes := TObjectList<TAWSLambda4DHTTPRoute>.Create(True);
end;

destructor TAWSLambda4DHTTPRouter.Destroy;
begin
  FRoutes.Free;
  inherited;
end;

procedure TAWSLambda4DHTTPRouter.RegisterRoute(const AMethod: string; const APath: string;
  const AHandler: IAWSLambda4DHTTPHandler);
var
  LRoute: TAWSLambda4DHTTPRoute;
begin
  if AHandler = nil then
    raise EArgumentNilException.Create('AHandler');

  if APath = '' then
    raise EArgumentException.Create('Route path cannot be empty');

  for LRoute in FRoutes do
  begin
    if (LRoute.Method = UpperCase(AMethod)) and SameStr(LRoute.Path, APath) then
      raise EArgumentException.CreateFmt('Route already registered: %s %s', [AMethod, APath]);
  end;

  FRoutes.Add(TAWSLambda4DHTTPRoute.Create(AMethod, APath, AHandler));
end;

function TAWSLambda4DHTTPRouter.Add(const AMethod: string; const APath: string;
  const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
begin
  Result := Self;
  RegisterRoute(AMethod, APath, AHandler);
end;

function TAWSLambda4DHTTPRouter.Get(const APath: string;
  const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
begin
  Result := Self;
  Add('GET', APath, AHandler);
end;

class function TAWSLambda4DHTTPRouter.New: IAWSLambda4DHTTPRouter;
begin
  Result := Self.Create;
end;

function TAWSLambda4DHTTPRouter.Post(const APath: string;
  const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
begin
  Result := Self;
  Add('POST', APath, AHandler);
end;

function TAWSLambda4DHTTPRouter.Put(const APath: string;
  const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
begin
  Result := Self;
  Add('PUT', APath, AHandler);
end;

function TAWSLambda4DHTTPRouter.Delete(const APath: string;
  const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
begin
  Result := Self;
  Add('DELETE', APath, AHandler);
end;

function TAWSLambda4DHTTPRouter.Patch(const APath: string;
  const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
begin
  Result := Self;
  Add('PATCH', APath, AHandler);
end;

function TAWSLambda4DHTTPRouter.CreateErrorResponse(const AStatusCode: Integer;
  const AMessage: string): TAWSLambda4DHTTPResponse;
var
  LJSON: TJSONObject;
begin
  Result := TAWSLambda4DHTTPResponse.Create;
  try
    Result.StatusCode := AStatusCode;
    Result.Headers.Add('content-type', 'application/json; charset=utf-8');

    LJSON := TJSONObject.Create;
    try
      LJSON.AddPair('error', AMessage);
      Result.SetBody(LJSON.ToJSON);
    finally
      LJSON.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TAWSLambda4DHTTPRouter.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LRoute: TAWSLambda4DHTTPRoute;
  LBestRoute: TAWSLambda4DHTTPRoute;
  LPathMatched: Boolean;
  LBestSpecificity: Integer;
  LMethod: string;
begin
  LMethod := UpperCase(ARequest.Method);

  LBestRoute := nil;
  LBestSpecificity := -1;
  LPathMatched := False;

  ARequest.PathParams.Clear;

  // Localiza a rota mais específica compatível
  // com o caminho e o método HTTP.
  for LRoute in FRoutes do
  begin
    if TAWSLambda4DHTTPRouteMatcher.TryMatch(LRoute.Path, ARequest.Path, ARequest.PathParams) then
    begin
      LPathMatched := True;
      if (LRoute.Method = LMethod) and (LRoute.Specificity > LBestSpecificity) then
      begin
        LBestRoute := LRoute;
        LBestSpecificity := LRoute.Specificity;
      end;
    end;
  end;

  if LBestRoute <> nil then
  begin
    // Recupera os parâmetros da rota escolhida.
    TAWSLambda4DHTTPRouteMatcher.TryMatch(LBestRoute.Path, ARequest.Path, ARequest.PathParams);
    Exit(LBestRoute.Handler.Execute(ARequest));
  end;

  ARequest.PathParams.Clear;

  if LPathMatched then
    Exit(CreateErrorResponse(405, 'Method Not Allowed'));

  Result := CreateErrorResponse(404, 'Not Found');
end;

end.

