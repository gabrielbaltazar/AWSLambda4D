unit AWSLambda4D.HTTP.Adapter.Test;

interface

uses
  System.SysUtils,
  System.JSON,
  DUnitX.TestFramework,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.HTTP.Types,
  AWSLambda4D.HTTP.Router,
  AWSLambda4D.HTTP.Adapter;

type
  [TestFixture]
  TAWSLambda4DHTTPAdapterTest = class
  private
    FAdapter: IAWSLambda4DHandler;

    function Invoke(const AEvent: string): TJSONObject;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Handle_ValidPathParam_ReturnsHandlerResponse;
    [Test]
    procedure Handle_InvalidPathParam_Returns400WithConversionMessage;
    [Test]
    procedure Handle_UnexpectedException_Returns500Generic;
  end;

implementation

type
  TParamHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  end;

  TFailingHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  end;

{ TParamHandler }

function TParamHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
begin
  Result := TAWSLambda4DHTTPResponse.Create;
  Result.StatusCode := 200;
  Result.SetBody(IntToStr(ARequest.PathParams.Field('id').AsInteger));
end;

{ TFailingHandler }

function TFailingHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
begin
  raise EInvalidOp.Create('secret internal detail');
end;

{ TAWSLambda4DHTTPAdapterTest }

procedure TAWSLambda4DHTTPAdapterTest.Setup;
var
  LRouter: IAWSLambda4DHTTPRouter;
begin
  LRouter := TAWSLambda4DHTTPRouter.New;
  LRouter.Get('/users/:id', TParamHandler.Create());
  LRouter.Get('/boom', TFailingHandler.Create());

  FAdapter := TAWSLambda4DHTTPAdapter.New(LRouter);
end;

procedure TAWSLambda4DHTTPAdapterTest.TearDown;
begin
  FAdapter := nil;
end;

function TAWSLambda4DHTTPAdapterTest.Invoke(const AEvent: string): TJSONObject;
var
  LRequest: TAWSLambda4DRequest;
  LContext: TAWSLambda4DContext;
  LResponse: TAWSLambda4DResponse;
begin
  LRequest := TAWSLambda4DRequest.Create;
  LContext := TAWSLambda4DContext.Create;
  try
    LRequest.Body := AEvent;
    LResponse := FAdapter.Handle(LRequest, LContext);
    try
      Result := TJSONObject.ParseJSONValue(LResponse.Body) as TJSONObject;
    finally
      LResponse.Free;
    end;
  finally
    LContext.Free;
    LRequest.Free;
  end;
end;

procedure TAWSLambda4DHTTPAdapterTest.Handle_ValidPathParam_ReturnsHandlerResponse;
var
  LJSON: TJSONObject;
begin
  LJSON := Invoke('{"httpMethod":"GET","path":"/users/42"}');
  try
    Assert.AreEqual(200, LJSON.GetValue<Integer>('statusCode'));
    Assert.AreEqual('42', LJSON.GetValue<string>('body'));
  finally
    LJSON.Free;
  end;
end;

procedure TAWSLambda4DHTTPAdapterTest.Handle_InvalidPathParam_Returns400WithConversionMessage;
var
  LJSON: TJSONObject;
  LBody: TJSONObject;
begin
  LJSON := Invoke('{"httpMethod":"GET","path":"/users/abc"}');
  try
    Assert.AreEqual(400, LJSON.GetValue<Integer>('statusCode'));

    LBody := TJSONObject.ParseJSONValue(LJSON.GetValue<string>('body')) as TJSONObject;
    try
      Assert.AreEqual('Parameter ''id'' has value ''abc'', which is not a valid Integer.',
        LBody.GetValue<string>('message'));
    finally
      LBody.Free;
    end;
  finally
    LJSON.Free;
  end;
end;

procedure TAWSLambda4DHTTPAdapterTest.Handle_UnexpectedException_Returns500Generic;
var
  LJSON: TJSONObject;
begin
  LJSON := Invoke('{"httpMethod":"GET","path":"/boom"}');
  try
    Assert.AreEqual(500, LJSON.GetValue<Integer>('statusCode'));
    Assert.AreEqual('{"message":"Internal Server Error"}', LJSON.GetValue<string>('body'));
  finally
    LJSON.Free;
  end;
end;

end.
