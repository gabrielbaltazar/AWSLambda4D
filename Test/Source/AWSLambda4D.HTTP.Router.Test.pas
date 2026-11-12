unit AWSLambda4D.HTTP.Router.Test;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  AWSLambda4D.HTTP.Types,
  AWSLambda4D.HTTP.Router;

type
  [TestFixture]
  TAWSLambda4DHTTPRouterTest = class
  private
    FRouter: IAWSLambda4DHTTPRouter;

    function SendRequest(const AMethod: string; const APath: string): TAWSLambda4DHTTPResponse;
    function BodyOf(const AResponse: TAWSLambda4DHTTPResponse): string;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    // Despacho por metodo
    [Test]
    procedure Get_RegisteredRoute_ExecutesHandler;
    [Test]
    procedure Post_RegisteredRoute_ExecutesHandler;
    [Test]
    procedure Put_RegisteredRoute_ExecutesHandler;
    [Test]
    procedure Delete_RegisteredRoute_ExecutesHandler;
    [Test]
    procedure Patch_RegisteredRoute_ExecutesHandler;
    [Test]
    procedure Add_CustomMethod_ExecutesHandler;
    [Test]
    procedure SamePath_DifferentMethods_DispatchToEachHandler;

    // Maiusculas / minusculas
    [Test]
    procedure Execute_PathWithDifferentCase_MatchesRoute;
    [Test]
    procedure Execute_MethodWithDifferentCase_MatchesRoute;
    [Test]
    procedure Add_MethodInLowerCase_MatchesUpperCaseRequest;

    // Caminhos
    [Test]
    procedure Execute_TrailingSlash_MatchesRoute;
    [Test]
    procedure Execute_DifferentSegmentCount_ReturnsNotFound;
    [Test]
    procedure Execute_RootRoute_MatchesRootPath;

    // Parametros de rota
    [Test]
    procedure Execute_DynamicSegment_ExtractsPathParam;
    [Test]
    procedure Execute_DynamicSegment_PreservesParamValueCase;
    [Test]
    procedure Execute_MultipleDynamicSegments_ExtractsAllParams;

    // Prioridade
    [Test]
    procedure Execute_StaticAndDynamicRoute_StaticWinsRegisteredFirst;
    [Test]
    procedure Execute_StaticAndDynamicRoute_StaticWinsRegisteredLast;

    // Erros HTTP
    [Test]
    procedure Execute_UnknownPath_ReturnsNotFound;
    [Test]
    procedure Execute_NotFound_ReturnsJsonErrorBody;
    [Test]
    procedure Execute_PathExistsWithOtherMethod_ReturnsMethodNotAllowed;
    [Test]
    procedure Execute_EmptyRouter_ReturnsNotFound;
    [Test]
    procedure Execute_NoMatch_ClearsPathParams;

    // Registro
    [Test]
    procedure Add_ReturnsSameRouterForChaining;
    [Test]
    procedure Add_DuplicateRoute_RaisesException;
    [Test]
    procedure Add_DuplicateRouteWithDifferentCase_RaisesException;
    [Test]
    procedure Add_NilHandler_RaisesException;
    [Test]
    procedure Add_EmptyMethod_RaisesException;
    [Test]
    procedure Add_EmptyPath_RaisesException;
  end;

implementation

uses
  System.Generics.Collections;

type
  // Handler falso: devolve um corpo identificavel e registra a chamada.
  TStubHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  private
    FTag: string;
    FCalls: Integer;
    FParams: TDictionary<string, string>;
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  public
    constructor Create(const ATag: string);
    destructor Destroy; override;

    function ParamValue(const AName: string): string;
    property Calls: Integer read FCalls;
  end;

{ TStubHandler }

constructor TStubHandler.Create(const ATag: string);
begin
  inherited Create;
  FTag := ATag;
  FParams := TDictionary<string, string>.Create;
end;

destructor TStubHandler.Destroy;
begin
  FParams.Free;
  inherited;
end;

function TStubHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LName: string;
begin
  Inc(FCalls);

  FParams.Clear;
  for LName in ARequest.PathParams.Names do
    FParams.AddOrSetValue(LName, ARequest.PathParams.First(LName));

  Result := TAWSLambda4DHTTPResponse.Create;
  Result.StatusCode := 200;
  Result.SetBody(FTag);
end;

function TStubHandler.ParamValue(const AName: string): string;
begin
  if not FParams.TryGetValue(AName, Result) then
    Result := '';
end;

{ TAWSLambda4DHTTPRouterTest }

procedure TAWSLambda4DHTTPRouterTest.Setup;
begin
  FRouter := TAWSLambda4DHTTPRouter.New;
end;

procedure TAWSLambda4DHTTPRouterTest.TearDown;
begin
  FRouter := nil;
end;

function TAWSLambda4DHTTPRouterTest.BodyOf(const AResponse: TAWSLambda4DHTTPResponse): string;
begin
  Result := TEncoding.UTF8.GetString(AResponse.Body);
end;

function TAWSLambda4DHTTPRouterTest.SendRequest(const AMethod: string;
  const APath: string): TAWSLambda4DHTTPResponse;
var
  LRequest: TAWSLambda4DHTTPRequest;
begin
  LRequest := TAWSLambda4DHTTPRequest.Create;
  try
    LRequest.Method := AMethod;
    LRequest.Path := APath;
    Result := FRouter.Execute(LRequest);
  finally
    LRequest.Free;
  end;
end;

{ Despacho por metodo }

procedure TAWSLambda4DHTTPRouterTest.Get_RegisteredRoute_ExecutesHandler;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Get('/ping', TStubHandler.Create('get'));

  LResponse := SendRequest('GET', '/ping');
  try
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.AreEqual('get', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Post_RegisteredRoute_ExecutesHandler;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Post('/items', TStubHandler.Create('post'));

  LResponse := SendRequest('POST', '/items');
  try
    Assert.AreEqual('post', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Put_RegisteredRoute_ExecutesHandler;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Put('/items', TStubHandler.Create('put'));

  LResponse := SendRequest('PUT', '/items');
  try
    Assert.AreEqual('put', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Delete_RegisteredRoute_ExecutesHandler;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Delete('/items', TStubHandler.Create('delete'));

  LResponse := SendRequest('DELETE', '/items');
  try
    Assert.AreEqual('delete', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Patch_RegisteredRoute_ExecutesHandler;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Patch('/items', TStubHandler.Create('patch'));

  LResponse := SendRequest('PATCH', '/items');
  try
    Assert.AreEqual('patch', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Add_CustomMethod_ExecutesHandler;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Add('OPTIONS', '/items', TStubHandler.Create('options'));

  LResponse := SendRequest('OPTIONS', '/items');
  try
    Assert.AreEqual('options', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.SamePath_DifferentMethods_DispatchToEachHandler;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter
    .Get('/items', TStubHandler.Create('list'))
    .Post('/items', TStubHandler.Create('create'));

  LResponse := SendRequest('GET', '/items');
  try
    Assert.AreEqual('list', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;

  LResponse := SendRequest('POST', '/items');
  try
    Assert.AreEqual('create', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

{ Maiusculas / minusculas }

procedure TAWSLambda4DHTTPRouterTest.Execute_PathWithDifferentCase_MatchesRoute;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Get('/ping', TStubHandler.Create('pong'));

  LResponse := SendRequest('GET', '/PING');
  try
    Assert.AreEqual(200, LResponse.StatusCode);
    Assert.AreEqual('pong', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_MethodWithDifferentCase_MatchesRoute;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Get('/ping', TStubHandler.Create('pong'));

  LResponse := SendRequest('get', '/ping');
  try
    Assert.AreEqual('pong', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Add_MethodInLowerCase_MatchesUpperCaseRequest;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Add('get', '/ping', TStubHandler.Create('pong'));

  LResponse := SendRequest('GET', '/ping');
  try
    Assert.AreEqual('pong', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

{ Caminhos }

procedure TAWSLambda4DHTTPRouterTest.Execute_TrailingSlash_MatchesRoute;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Get('/ping', TStubHandler.Create('pong'));

  LResponse := SendRequest('GET', '/ping/');
  try
    Assert.AreEqual(200, LResponse.StatusCode);
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_DifferentSegmentCount_ReturnsNotFound;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Get('/users/:id', TStubHandler.Create('user'));

  LResponse := SendRequest('GET', '/users');
  try
    Assert.AreEqual(404, LResponse.StatusCode);
  finally
    LResponse.Free;
  end;

  LResponse := SendRequest('GET', '/users/1/orders');
  try
    Assert.AreEqual(404, LResponse.StatusCode);
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_RootRoute_MatchesRootPath;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Get('/', TStubHandler.Create('root'));

  LResponse := SendRequest('GET', '/');
  try
    Assert.AreEqual('root', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

{ Parametros de rota }

procedure TAWSLambda4DHTTPRouterTest.Execute_DynamicSegment_ExtractsPathParam;
var
  LStub: TStubHandler;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  LStub := TStubHandler.Create('user');
  FRouter.Get('/users/:id', LStub);

  LResponse := SendRequest('GET', '/users/42');
  try
    Assert.AreEqual(1, LStub.Calls);
    Assert.AreEqual('42', LStub.ParamValue('id'));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_DynamicSegment_PreservesParamValueCase;
var
  LStub: TStubHandler;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  LStub := TStubHandler.Create('user');
  FRouter.Get('/users/:id', LStub);

  LResponse := SendRequest('GET', '/USERS/AbC');
  try
    Assert.AreEqual('AbC', LStub.ParamValue('id'));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_MultipleDynamicSegments_ExtractsAllParams;
var
  LStub: TStubHandler;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  LStub := TStubHandler.Create('order');
  FRouter.Get('/users/:userId/orders/:orderId', LStub);

  LResponse := SendRequest('GET', '/users/7/orders/99');
  try
    Assert.AreEqual('7', LStub.ParamValue('userId'));
    Assert.AreEqual('99', LStub.ParamValue('orderId'));
  finally
    LResponse.Free;
  end;
end;

{ Prioridade }

procedure TAWSLambda4DHTTPRouterTest.Execute_StaticAndDynamicRoute_StaticWinsRegisteredFirst;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter
    .Get('/users/me', TStubHandler.Create('me'))
    .Get('/users/:id', TStubHandler.Create('byId'));

  LResponse := SendRequest('GET', '/users/me');
  try
    Assert.AreEqual('me', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;

  LResponse := SendRequest('GET', '/users/10');
  try
    Assert.AreEqual('byId', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_StaticAndDynamicRoute_StaticWinsRegisteredLast;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter
    .Get('/users/:id', TStubHandler.Create('byId'))
    .Get('/users/me', TStubHandler.Create('me'));

  LResponse := SendRequest('GET', '/users/me');
  try
    Assert.AreEqual('me', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

{ Erros HTTP }

procedure TAWSLambda4DHTTPRouterTest.Execute_UnknownPath_ReturnsNotFound;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Get('/ping', TStubHandler.Create('pong'));

  LResponse := SendRequest('GET', '/unknown');
  try
    Assert.AreEqual(404, LResponse.StatusCode);
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_NotFound_ReturnsJsonErrorBody;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  LResponse := SendRequest('GET', '/unknown');
  try
    Assert.AreEqual('application/json; charset=utf-8', LResponse.Headers.First('content-type'));
    Assert.AreEqual('{"error":"Not Found"}', BodyOf(LResponse));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_PathExistsWithOtherMethod_ReturnsMethodNotAllowed;
var
  LStub: TStubHandler;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  LStub := TStubHandler.Create('get');
  FRouter.Get('/items', LStub);

  LResponse := SendRequest('DELETE', '/items');
  try
    Assert.AreEqual(405, LResponse.StatusCode);
    Assert.AreEqual('{"error":"Method Not Allowed"}', BodyOf(LResponse));
    Assert.AreEqual(0, LStub.Calls);
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_EmptyRouter_ReturnsNotFound;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  LResponse := SendRequest('GET', '/anything');
  try
    Assert.AreEqual(404, LResponse.StatusCode);
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPRouterTest.Execute_NoMatch_ClearsPathParams;
var
  LRequest: TAWSLambda4DHTTPRequest;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter.Get('/users/:id', TStubHandler.Create('user'));

  LRequest := TAWSLambda4DHTTPRequest.Create;
  try
    LRequest.Method := 'POST';
    LRequest.Path := '/users/5';
    LResponse := FRouter.Execute(LRequest);
    try
      Assert.AreEqual(405, LResponse.StatusCode);
      Assert.AreEqual(0, Length(LRequest.PathParams.Names));
    finally
      LResponse.Free;
    end;
  finally
    LRequest.Free;
  end;
end;

{ Registro }

procedure TAWSLambda4DHTTPRouterTest.Add_ReturnsSameRouterForChaining;
var
  LResult: IAWSLambda4DHTTPRouter;
begin
  LResult := FRouter.Get('/a', TStubHandler.Create('a'));

  Assert.IsTrue(LResult = FRouter);
  Assert.IsTrue(LResult.Post('/b', TStubHandler.Create('b')) = FRouter);
end;

procedure TAWSLambda4DHTTPRouterTest.Add_DuplicateRoute_RaisesException;
begin
  FRouter.Get('/ping', TStubHandler.Create('one'));

  Assert.WillRaise(
    procedure
    begin
      FRouter.Get('/ping', TStubHandler.Create('two'));
    end,
    EArgumentException);
end;

procedure TAWSLambda4DHTTPRouterTest.Add_DuplicateRouteWithDifferentCase_RaisesException;
begin
  FRouter.Get('/ping', TStubHandler.Create('one'));

  Assert.WillRaise(
    procedure
    begin
      FRouter.Add('get', '/PING', TStubHandler.Create('two'));
    end,
    EArgumentException);
end;

procedure TAWSLambda4DHTTPRouterTest.Add_NilHandler_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FRouter.Get('/ping', nil);
    end,
    EArgumentNilException);
end;

procedure TAWSLambda4DHTTPRouterTest.Add_EmptyMethod_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FRouter.Add('  ', '/ping', TStubHandler.Create('x'));
    end,
    EArgumentException);
end;

procedure TAWSLambda4DHTTPRouterTest.Add_EmptyPath_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FRouter.Get('', TStubHandler.Create('x'));
    end,
    EArgumentException);
end;

end.
