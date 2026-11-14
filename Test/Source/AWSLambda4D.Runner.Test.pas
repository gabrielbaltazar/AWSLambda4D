unit AWSLambda4D.Runner.Test;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.HTTP.Types,
  AWSLambda4D.HTTP.Events,
  AWSLambda4D.Runner;

type
  [TestFixture]
  TAWSLambda4DRunnerTest = class
  public
    [Test]
    procedure RunLocal_AnonymousFunction_ReceivesEventBody;
    [Test]
    procedure RunLocal_HandlerRaises_DoesNotRaise;
    [Test]
    procedure RunLocal_HTTPHandler_ReceivesRoutedRequest;
    [Test]
    procedure RunLocal_CalledTwice_RunsEachTime;
    [Test]
    procedure RunLocal_RouterWithPayloadBuilder_ReceivesRequestFromPayload;
    [Test]
    procedure RunLocal_NilPayload_RaisesException;
    [Test]
    procedure RunLocal_HTTPAnonymousFunctionWithEvent_ReceivesRequest;
    [Test]
    procedure RunLocal_HTTPAnonymousFunctionWithPayload_ReceivesRequest;
    [Test]
    procedure RunLocal_NilHTTPFunction_RaisesException;
  end;

implementation

uses
  AWSLambda4D.HTTP.Router;

{ TAWSLambda4DRunnerTest }

procedure TAWSLambda4DRunnerTest.RunLocal_AnonymousFunction_ReceivesEventBody;
var
  LBody: string;
begin
  TAWSLambda4DRunner.RunLocal(
    function(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse
    begin
      LBody := ARequest.Body;
      Result := TAWSLambda4DResponse.Create;
      Result.Body := '{"ok":true}';
    end,
    '{"name":"Gabriel"}');

  Assert.AreEqual('{"name":"Gabriel"}', LBody);
end;

procedure TAWSLambda4DRunnerTest.RunLocal_HandlerRaises_DoesNotRaise;
var
  LCalled: Boolean;
begin
  LCalled := False;

  // A falha do handler e reportada como erro da Lambda, nao como excecao do RunLocal.
  TAWSLambda4DRunner.RunLocal(
    function(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse
    begin
      LCalled := True;
      raise EInvalidOp.Create('boom');
    end,
    '{}');

  Assert.IsTrue(LCalled);
end;

procedure TAWSLambda4DRunnerTest.RunLocal_HTTPHandler_ReceivesRoutedRequest;
var
  LPath: string;
begin
  TAWSLambda4DRunner.RunLocal(
    TAWSLambda4DHTTPRouter.New.Get('/ping',
      function(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse
      begin
        LPath := ARequest.Path;
        Result := TAWSLambda4DHTTPResponse.Create;
        Result.SetBody('pong');
      end),
    '{"httpMethod":"GET","path":"/ping"}');

  Assert.AreEqual('/ping', LPath);
end;

procedure TAWSLambda4DRunnerTest.RunLocal_CalledTwice_RunsEachTime;
var
  LCalls: Integer;
  LHandler: TAWSLambda4DHandlerProc;
begin
  LCalls := 0;
  LHandler :=
    function(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse
    begin
      Inc(LCalls);
      Result := TAWSLambda4DResponse.Create;
    end;

  TAWSLambda4DRunner.RunLocal(LHandler, '{}');
  TAWSLambda4DRunner.RunLocal(LHandler, '{}');

  Assert.AreEqual(2, LCalls);
end;

procedure TAWSLambda4DRunnerTest.RunLocal_RouterWithPayloadBuilder_ReceivesRequestFromPayload;
var
  LRouter: IAWSLambda4DHTTPRouter;
  LPayload: IAWSLambda4DHTTPPayloadV2;
  LContext: IAWSLambda4DHTTPPayloadV2RequestContext;
  LId: Integer;
  LQuery: string;
begin
  LId := 0;
  LQuery := '';
  LRouter := TAWSLambda4DHTTPRouter.New;
  LRouter.Post('/documents/:id',
    function(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse
    begin
      LId := ARequest.PathParams.Field('id').AsInteger;
      LQuery := ARequest.QueryParam('status');
      Result := TAWSLambda4DHTTPResponse.Create;
    end);

  LPayload := TAWSLambda4DHTTPPayloadV2.Create;
  LPayload.RawPath('/documents/15').AddQuery('status', 'active');
  LContext := TAWSLambda4DHTTPPayloadV2RequestContext.Create(LPayload);
  LContext.HTTP.Method('POST').Path('/documents/15');

  TAWSLambda4DRunner.RunLocal(LRouter, LPayload);

  Assert.AreEqual(15, LId);
  Assert.AreEqual('active', LQuery);
end;

procedure TAWSLambda4DRunnerTest.RunLocal_NilPayload_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TAWSLambda4DRunner.RunLocal(TAWSLambda4DHTTPRouter.New, IAWSLambda4DHTTPPayloadV2(nil));
    end,
    EArgumentNilException);
end;

procedure TAWSLambda4DRunnerTest.RunLocal_HTTPAnonymousFunctionWithEvent_ReceivesRequest;
var
  LPath: string;
begin
  TAWSLambda4DRunner.RunLocal(
    function(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse
    begin
      LPath := ARequest.Path;
      Result := TAWSLambda4DHTTPResponse.Create;
      Result.SetBody('pong');
    end,
    '{"httpMethod":"GET","path":"/ping"}');

  Assert.AreEqual('/ping', LPath);
end;

procedure TAWSLambda4DRunnerTest.RunLocal_HTTPAnonymousFunctionWithPayload_ReceivesRequest;
var
  LMethod: string;
  LPath: string;
begin
  TAWSLambda4DRunner.RunLocal(
    function(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse
    begin
      LMethod := ARequest.Method;
      LPath := ARequest.Path;
      Result := TAWSLambda4DHTTPResponse.Create;
    end,
    TAWSLambda4DHTTPPayloadV2.New
      .RawPath('/items')
      .RequestContext.HTTP.Method('POST').Path('/items').&End.&End);

  Assert.AreEqual('POST', LMethod);
  Assert.AreEqual('/items', LPath);
end;

procedure TAWSLambda4DRunnerTest.RunLocal_NilHTTPFunction_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TAWSLambda4DRunner.RunLocal(TAWSLambda4DHTTPHandlerProc(nil), '{}');
    end,
    EArgumentNilException);
end;

end.
