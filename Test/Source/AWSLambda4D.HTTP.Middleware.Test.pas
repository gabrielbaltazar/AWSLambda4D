unit AWSLambda4D.HTTP.Middleware.Test;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  AWSLambda4D;

type
  [TestFixture]
  TAWSLambda4DHTTPMiddlewareTest = class
  private
    FRouter: IAWSLambda4DHTTPRouter;
    FLog: TList<string>;

    function Send(const AMethod: string; const APath: string): TAWSLambda4DHTTPResponse;
    function Trace(const AName: string): TAWSLambda4DHTTPMiddlewareProc;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Use_MiddlewaresRunInRegistrationOrderAroundTheRoute;
    [Test]
    procedure Use_BeforePart_CanChangeTheRequestSeenByTheRoute;
    [Test]
    procedure Use_AfterPart_CanChangeTheResponse;
    [Test]
    procedure Use_NotCallingNext_StopsTheChainAndKeepsTheMiddlewareResponse;
    [Test]
    procedure Use_UnknownPath_MiddlewaresStillRunAndSeeTheNotFound;
    [Test]
    procedure Use_PathParams_AreAvailableAfterNext;
    [Test]
    procedure Use_RouteResponse_IsFullyPreservedThroughTheChain;
    [Test]
    procedure Use_MiddlewareRaises_ExceptionPropagates;
    [Test]
    procedure Use_RouteRaises_ExceptionPassesThroughMiddlewaresAndNothingLeaks;
    [Test]
    procedure Use_InterfaceMiddleware_Works;
    [Test]
    procedure Use_ReturnsRouterForChaining;
    [Test]
    procedure Use_NilMiddleware_RaisesException;
    [Test]
    procedure Use_OnStaticClass_RegistersOnTheSharedRouter;
  end;

  [TestFixture]
  TAWSLambda4DHTTPResponseAssignTest = class
  public
    [Test]
    procedure Assign_CopiesStatusBodyHeadersCookiesAndBase64Flag;
    [Test]
    procedure Assign_ReplacesPreviousContent;
    [Test]
    procedure Assign_NilSource_RaisesException;
  end;

implementation

type
  TTagMiddleware = class(TInterfacedObject, IAWSLambda4DHTTPMiddleware)
  protected
    procedure Execute(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
      const ANext: TProc);
  end;

{ TTagMiddleware }

procedure TTagMiddleware.Execute(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
  const ANext: TProc);
begin
  ANext();
  AResponse.Headers.Add('x-tag', 'from-class');
end;

{ TAWSLambda4DHTTPMiddlewareTest }

procedure TAWSLambda4DHTTPMiddlewareTest.Setup;
begin
  FRouter := TAWSLambda4DHTTPRouter.New;
  FLog := TList<string>.Create;
end;

procedure TAWSLambda4DHTTPMiddlewareTest.TearDown;
begin
  FRouter := nil;
  FLog.Free;
  TAWSLambda4D.Reset;
end;

function TAWSLambda4DHTTPMiddlewareTest.Send(const AMethod: string; const APath: string): TAWSLambda4DHTTPResponse;
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

function TAWSLambda4DHTTPMiddlewareTest.Trace(const AName: string): TAWSLambda4DHTTPMiddlewareProc;
begin
  Result :=
    procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
      const ANext: TProc)
    begin
      FLog.Add(AName + ':before');
      ANext();
      FLog.Add(AName + ':after');
    end;
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_MiddlewaresRunInRegistrationOrderAroundTheRoute;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter
    .Use(Trace('A'))
    .Use(Trace('B'))
    .Get('/r',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        FLog.Add('route');
      end);

  LResponse := Send('GET', '/r');
  LResponse.Free;

  Assert.AreEqual('A:before,B:before,route,B:after,A:after', string.Join(',', FLog.ToArray));
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_BeforePart_CanChangeTheRequestSeenByTheRoute;
var
  LSeen: string;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter
    .Use(
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
        const ANext: TProc)
      begin
        ARequest.Headers.Add('x-user', 'gabriel');
        ANext();
      end)
    .Get('/r',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        LSeen := ARequest.Header('x-user');
      end);

  LResponse := Send('GET', '/r');
  LResponse.Free;

  Assert.AreEqual('gabriel', LSeen);
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_AfterPart_CanChangeTheResponse;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter
    .Use(
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
        const ANext: TProc)
      begin
        ANext();
        AResponse.Headers.Add('access-control-allow-origin', '*');
        AResponse.StatusCode := 202;
      end)
    .Get('/r',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        AResponse.SetBody('hello');
      end);

  LResponse := Send('GET', '/r');
  try
    Assert.AreEqual(202, LResponse.StatusCode);
    Assert.AreEqual('*', LResponse.Headers.First('access-control-allow-origin'));
    Assert.AreEqual('hello', TEncoding.UTF8.GetString(LResponse.Body));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_NotCallingNext_StopsTheChainAndKeepsTheMiddlewareResponse;
var
  LRouteCalled: Boolean;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  LRouteCalled := False;
  FRouter
    .Use(
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
        const ANext: TProc)
      begin
        AResponse.StatusCode := 401;
        AResponse.SetBody('{"error":"unauthorized"}');
      end)
    .Use(Trace('never'))
    .Get('/r',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        LRouteCalled := True;
      end);

  LResponse := Send('GET', '/r');
  try
    Assert.AreEqual(401, LResponse.StatusCode);
    Assert.AreEqual('{"error":"unauthorized"}', TEncoding.UTF8.GetString(LResponse.Body));
    Assert.IsFalse(LRouteCalled);
    Assert.AreEqual(0, FLog.Count);
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_UnknownPath_MiddlewaresStillRunAndSeeTheNotFound;
var
  LStatusAfterNext: Integer;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  LStatusAfterNext := 0;
  FRouter.Use(
    procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
      const ANext: TProc)
    begin
      ANext();
      LStatusAfterNext := AResponse.StatusCode;
    end);

  LResponse := Send('GET', '/nothing');
  try
    Assert.AreEqual(404, LStatusAfterNext);
    Assert.AreEqual(404, LResponse.StatusCode);
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_PathParams_AreAvailableAfterNext;
var
  LBefore: string;
  LAfter: string;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter
    .Use(
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
        const ANext: TProc)
      begin
        LBefore := ARequest.PathParams.First('id');
        ANext();
        LAfter := ARequest.PathParams.First('id');
      end)
    .Get('/users/:id',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
      end);

  LResponse := Send('GET', '/users/42');
  LResponse.Free;

  Assert.AreEqual('', LBefore, 'antes do roteamento');
  Assert.AreEqual('42', LAfter, 'depois do roteamento');
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_RouteResponse_IsFullyPreservedThroughTheChain;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter
    .Use(Trace('A'))
    .Post('/r',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        AResponse.StatusCode := 201;
        AResponse.Headers.Add('location', '/r/1');
        AResponse.Headers.Add('x-multi', 'a');
        AResponse.Headers.Add('x-multi', 'b');
        AResponse.Cookies.Add('session=abc');
        AResponse.IsBase64Encoded := True;
        AResponse.SetBody('created');
      end);

  LResponse := Send('POST', '/r');
  try
    Assert.AreEqual(201, LResponse.StatusCode);
    Assert.AreEqual('/r/1', LResponse.Headers.First('location'));
    Assert.AreEqual(2, LResponse.Headers.ValueCount('x-multi'));
    Assert.AreEqual('b', LResponse.Headers.Value('x-multi', 1));
    Assert.AreEqual(1, LResponse.Cookies.Count);
    Assert.AreEqual('session=abc', LResponse.Cookies[0]);
    Assert.IsTrue(LResponse.IsBase64Encoded);
    Assert.AreEqual('created', TEncoding.UTF8.GetString(LResponse.Body));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_MiddlewareRaises_ExceptionPropagates;
begin
  FRouter
    .Use(
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
        const ANext: TProc)
      begin
        raise EInvalidOp.Create('boom');
      end)
    .Get('/r',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
      end);

  Assert.WillRaise(
    procedure
    begin
      Send('GET', '/r').Free;
    end,
    EInvalidOp);
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_RouteRaises_ExceptionPassesThroughMiddlewaresAndNothingLeaks;
begin
  // O DUnitX falha o teste por vazamento se os responses intermediarios nao forem liberados.
  FRouter
    .Use(Trace('A'))
    .Get('/r',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        raise EInvalidOp.Create('boom');
      end);

  Assert.WillRaise(
    procedure
    begin
      Send('GET', '/r').Free;
    end,
    EInvalidOp);

  Assert.AreEqual('A:before', string.Join(',', FLog.ToArray), 'a parte "after" nao roda quando a rota falha');
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_InterfaceMiddleware_Works;
var
  LResponse: TAWSLambda4DHTTPResponse;
begin
  FRouter
    .Use(TTagMiddleware.Create as IAWSLambda4DHTTPMiddleware)
    .Get('/r',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
      end);

  LResponse := Send('GET', '/r');
  try
    Assert.AreEqual('from-class', LResponse.Headers.First('x-tag'));
  finally
    LResponse.Free;
  end;
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_ReturnsRouterForChaining;
begin
  Assert.IsTrue(FRouter.Use(Trace('A')) = FRouter);
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_NilMiddleware_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FRouter.Use(IAWSLambda4DHTTPMiddleware(nil));
    end,
    EArgumentNilException);

  Assert.WillRaise(
    procedure
    begin
      FRouter.Use(TAWSLambda4DHTTPMiddlewareProc(nil));
    end,
    EArgumentNilException);
end;

procedure TAWSLambda4DHTTPMiddlewareTest.Use_OnStaticClass_RegistersOnTheSharedRouter;
var
  LRequest: TAWSLambda4DHTTPRequest;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  TAWSLambda4D.Reset;
  TAWSLambda4D
    .Use(Trace('static'))
    .Get('/r',
      procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        FLog.Add('route');
      end);

  LRequest := TAWSLambda4DHTTPRequest.Create;
  try
    LRequest.Method := 'GET';
    LRequest.Path := '/r';
    LResponse := TAWSLambda4D.Router.Execute(LRequest);
    LResponse.Free;
  finally
    LRequest.Free;
  end;

  Assert.AreEqual('static:before,route,static:after', string.Join(',', FLog.ToArray));
end;

{ TAWSLambda4DHTTPResponseAssignTest }

procedure TAWSLambda4DHTTPResponseAssignTest.Assign_CopiesStatusBodyHeadersCookiesAndBase64Flag;
var
  LSource: TAWSLambda4DHTTPResponse;
  LTarget: TAWSLambda4DHTTPResponse;
begin
  LSource := TAWSLambda4DHTTPResponse.Create;
  LTarget := TAWSLambda4DHTTPResponse.Create;
  try
    LSource.StatusCode := 418;
    LSource.IsBase64Encoded := True;
    LSource.SetBody('teapot');
    LSource.Headers.Add('a', '1');
    LSource.Headers.Add('a', '2');
    LSource.Cookies.Add('c=1');

    LTarget.Assign(LSource);

    Assert.AreEqual(418, LTarget.StatusCode);
    Assert.IsTrue(LTarget.IsBase64Encoded);
    Assert.AreEqual('teapot', TEncoding.UTF8.GetString(LTarget.Body));
    Assert.AreEqual(2, LTarget.Headers.ValueCount('a'));
    Assert.AreEqual('c=1', LTarget.Cookies[0]);

    // E uma copia: alterar a origem depois nao afeta o destino.
    LSource.Headers.Add('a', '3');
    Assert.AreEqual(2, LTarget.Headers.ValueCount('a'));
  finally
    LTarget.Free;
    LSource.Free;
  end;
end;

procedure TAWSLambda4DHTTPResponseAssignTest.Assign_ReplacesPreviousContent;
var
  LSource: TAWSLambda4DHTTPResponse;
  LTarget: TAWSLambda4DHTTPResponse;
begin
  LSource := TAWSLambda4DHTTPResponse.Create;
  LTarget := TAWSLambda4DHTTPResponse.Create;
  try
    LTarget.Headers.Add('old', 'x');
    LTarget.Cookies.Add('old=1');
    LSource.Headers.Add('new', 'y');

    LTarget.Assign(LSource);

    Assert.IsFalse(LTarget.Headers.Contains('old'));
    Assert.AreEqual('y', LTarget.Headers.First('new'));
    Assert.AreEqual(0, LTarget.Cookies.Count);
  finally
    LTarget.Free;
    LSource.Free;
  end;
end;

procedure TAWSLambda4DHTTPResponseAssignTest.Assign_NilSource_RaisesException;
var
  LTarget: TAWSLambda4DHTTPResponse;
begin
  LTarget := TAWSLambda4DHTTPResponse.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        LTarget.Assign(nil);
      end,
      EArgumentNilException);
  finally
    LTarget.Free;
  end;
end;

end.
