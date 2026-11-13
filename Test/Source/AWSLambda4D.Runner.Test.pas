unit AWSLambda4D.Runner.Test;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.HTTP.Types,
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
  end;

implementation

uses
  AWSLambda4D.HTTP.Router;

{ TAWSLambda4DRunnerTest }

procedure TAWSLambda4DRunnerTest.RunLocal_AnonymousFunction_ReceivesEventBody;
var
  LBody: string;
begin
  TAWSLambda4Runner.RunLocal(
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
  TAWSLambda4Runner.RunLocal(
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
  TAWSLambda4Runner.RunLocal(
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

  TAWSLambda4Runner.RunLocal(LHandler, '{}');
  TAWSLambda4Runner.RunLocal(LHandler, '{}');

  Assert.AreEqual(2, LCalls);
end;

end.
