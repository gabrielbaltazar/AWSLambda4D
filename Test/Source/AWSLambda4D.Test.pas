unit AWSLambda4D.Test;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  AWSLambda4D;

type
  [TestFixture]
  TAWSLambda4DStaticApiTest = class
  private
    function Call(const AMethod: string; const APath: string): Integer;
    function OkHandler(const ATag: string): TAWSLambda4DHTTPHandlerProc;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Router_CalledTwice_ReturnsSameInstance;
    [Test]
    procedure Get_ReturnsClassForChaining;
    [Test]
    procedure Chain_AllMethods_RegisterRoutes;
    [Test]
    procedure Add_CustomMethod_RegistersRoute;
    [Test]
    procedure Chain_MixingInterfaceAndAnonymousHandlers_BothWork;
    [Test]
    procedure Reset_RemovesRoutes;
    [Test]
    procedure Add_DuplicateRoute_RaisesException;
    [Test]
    procedure RunLocal_WithPayload_ExecutesRegisteredRoute;
    [Test]
    procedure RunLocal_WithEventString_ExecutesRegisteredRoute;
  end;

implementation

type
  THandlerByInterface = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  private
    FCalls: PInteger;
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  public
    constructor Create(const ACalls: PInteger);
  end;

{ THandlerByInterface }

constructor THandlerByInterface.Create(const ACalls: PInteger);
begin
  inherited Create;
  FCalls := ACalls;
end;

function THandlerByInterface.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
begin
  Inc(FCalls^);
  Result := TAWSLambda4DHTTPResponse.Create;
  Result.StatusCode := 200;
end;

{ TAWSLambda4DStaticApiTest }

procedure TAWSLambda4DStaticApiTest.Setup;
begin
  TAWSLambda4D.Reset;
end;

procedure TAWSLambda4DStaticApiTest.TearDown;
begin
  TAWSLambda4D.Reset;
end;

function TAWSLambda4DStaticApiTest.OkHandler(const ATag: string): TAWSLambda4DHTTPHandlerProc;
begin
  Result :=
    procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
    begin
      AResponse.StatusCode := 200;
      AResponse.SetBody(ATag);
    end;
end;

function TAWSLambda4DStaticApiTest.Call(const AMethod: string; const APath: string): Integer;
var
  LRequest: TAWSLambda4DHTTPRequest;
  LResponse: TAWSLambda4DHTTPResponse;
begin
  LRequest := TAWSLambda4DHTTPRequest.Create;
  try
    LRequest.Method := AMethod;
    LRequest.Path := APath;
    LResponse := TAWSLambda4D.Router.Execute(LRequest);
    try
      Result := LResponse.StatusCode;
    finally
      LResponse.Free;
    end;
  finally
    LRequest.Free;
  end;
end;

procedure TAWSLambda4DStaticApiTest.Router_CalledTwice_ReturnsSameInstance;
begin
  Assert.IsTrue(TAWSLambda4D.Router = TAWSLambda4D.Router);
end;

procedure TAWSLambda4DStaticApiTest.Get_ReturnsClassForChaining;
begin
  Assert.IsTrue(TAWSLambda4D.Get('/a', OkHandler('a')) = TAWSLambda4D);
end;

procedure TAWSLambda4DStaticApiTest.Chain_AllMethods_RegisterRoutes;
begin
  TAWSLambda4D
    .Get('/r', OkHandler('get'))
    .Post('/r', OkHandler('post'))
    .Put('/r', OkHandler('put'))
    .Delete('/r', OkHandler('delete'))
    .Patch('/r', OkHandler('patch'));

  Assert.AreEqual(200, Call('GET', '/r'));
  Assert.AreEqual(200, Call('POST', '/r'));
  Assert.AreEqual(200, Call('PUT', '/r'));
  Assert.AreEqual(200, Call('DELETE', '/r'));
  Assert.AreEqual(200, Call('PATCH', '/r'));
  Assert.AreEqual(405, Call('OPTIONS', '/r'));
end;

procedure TAWSLambda4DStaticApiTest.Add_CustomMethod_RegistersRoute;
begin
  TAWSLambda4D.Add('OPTIONS', '/r', OkHandler('options'));
  Assert.AreEqual(200, Call('OPTIONS', '/r'));
end;

procedure TAWSLambda4DStaticApiTest.Chain_MixingInterfaceAndAnonymousHandlers_BothWork;
var
  LCalls: Integer;
begin
  LCalls := 0;

  TAWSLambda4D
    .Get('/interface', THandlerByInterface.Create(@LCalls))
    .Get('/anonymous', OkHandler('anonymous'));

  Assert.AreEqual(200, Call('GET', '/interface'));
  Assert.AreEqual(200, Call('GET', '/anonymous'));
  Assert.AreEqual(1, LCalls);
end;

procedure TAWSLambda4DStaticApiTest.Reset_RemovesRoutes;
begin
  TAWSLambda4D.Get('/r', OkHandler('get'));
  Assert.AreEqual(200, Call('GET', '/r'));

  TAWSLambda4D.Reset;
  Assert.AreEqual(404, Call('GET', '/r'));
end;

procedure TAWSLambda4DStaticApiTest.Add_DuplicateRoute_RaisesException;
begin
  TAWSLambda4D.Get('/r', OkHandler('one'));

  Assert.WillRaise(
    procedure
    begin
      TAWSLambda4D.Get('/R', OkHandler('two'));
    end,
    EArgumentException);
end;

procedure TAWSLambda4DStaticApiTest.RunLocal_WithPayload_ExecutesRegisteredRoute;
var
  LPath: string;
  LId: Integer;
begin
  LId := 0;
  TAWSLambda4D.Post('/documents/:id',
    procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
    begin
      LPath := ARequest.Path;
      LId := ARequest.PathParams.Field('id').AsInteger;
      AResponse.StatusCode := 204;
    end);

  TAWSLambda4D.RunLocal(
    TAWSLambda4DHTTPPayloadV2.New
      .RawPath('/documents/15')
      .RequestContext.HTTP.Method('POST').Path('/documents/15').&End.&End);

  Assert.AreEqual('/documents/15', LPath);
  Assert.AreEqual(15, LId);
end;

procedure TAWSLambda4DStaticApiTest.RunLocal_WithEventString_ExecutesRegisteredRoute;
var
  LCalled: Boolean;
begin
  LCalled := False;
  TAWSLambda4D.Get('/ping',
    procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
    begin
      LCalled := True;
    end);

  TAWSLambda4D.RunLocal('{"httpMethod":"GET","path":"/ping"}');

  Assert.IsTrue(LCalled);
end;

end.
