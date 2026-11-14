unit AWSLambda4D.Runtime.API.Test;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DUnitX.TestFramework,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.Runtime.API,
  AWSLambda4D.Runtime.LocalServer;

type
  [TestFixture]
  TAWSLambda4DRuntimeAPITest = class
  private
    FServer: TAWSLambda4DRuntimeLocalServer;
    FAPI: IAWSLambda4DRuntimeAPI;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure NextInvocation_FillsRequestFromBodyAndId;
    [Test]
    procedure NextInvocation_FillsContextFromHeaders;
    [Test]
    procedure NextInvocation_DeadlineMs_IsTakenFromTheHeader;
  end;

implementation

const
  CPort = 9003;

{ TAWSLambda4DRuntimeAPITest }

procedure TAWSLambda4DRuntimeAPITest.Setup;
begin
  FServer := TAWSLambda4DRuntimeLocalServer.Create(CPort);
  FServer.Start;
  FAPI := TAWSLambda4DRuntimeAPI.New('127.0.0.1:' + IntToStr(CPort));
end;

procedure TAWSLambda4DRuntimeAPITest.TearDown;
begin
  FAPI := nil;
  FServer.Stop;
  FServer.Free;
end;

procedure TAWSLambda4DRuntimeAPITest.NextInvocation_FillsRequestFromBodyAndId;
var
  LRequest: TAWSLambda4DRequest;
  LContext: TAWSLambda4DContext;
begin
  FServer.AddInvocation('{"name":"Gabriel"}', 'req-1');

  LRequest := FAPI.NextInvocation(LContext);
  try
    Assert.AreEqual('{"name":"Gabriel"}', LRequest.Body);
    Assert.AreEqual('req-1', LRequest.RequestId);
  finally
    LRequest.Free;
    LContext.Free;
  end;
end;

procedure TAWSLambda4DRuntimeAPITest.NextInvocation_FillsContextFromHeaders;
var
  LRequest: TAWSLambda4DRequest;
  LContext: TAWSLambda4DContext;
begin
  FServer.AddInvocation('{}', 'req-2', 'inv-2');

  LRequest := FAPI.NextInvocation(LContext);
  try
    Assert.AreEqual('req-2', LContext.AwsRequestId);
    Assert.AreEqual('inv-2', LContext.InvocationId);
    Assert.IsTrue(LContext.FunctionArn.StartsWith('arn:aws:lambda:'), 'FunctionArn');
    Assert.IsFalse(LContext.TraceId.IsEmpty, 'TraceId');
  finally
    LRequest.Free;
    LContext.Free;
  end;
end;

procedure TAWSLambda4DRuntimeAPITest.NextInvocation_DeadlineMs_IsTakenFromTheHeader;
var
  LRequest: TAWSLambda4DRequest;
  LContext: TAWSLambda4DContext;
  LNowMs: Int64;
begin
  FServer.AddInvocation('{}');

  LRequest := FAPI.NextInvocation(LContext);
  try
    LNowMs := DateTimeToUnix(Now, False) * 1000;

    // O servidor local informa um prazo de ~30 s a partir do momento da invocacao.
    Assert.IsTrue(LContext.DeadlineMs > LNowMs, 'DeadlineMs deve estar no futuro');
    Assert.IsTrue(LContext.DeadlineMs <= LNowMs + 35000, 'DeadlineMs deve ser ~30 s a frente');
  finally
    LRequest.Free;
    LContext.Free;
  end;
end;

end.
