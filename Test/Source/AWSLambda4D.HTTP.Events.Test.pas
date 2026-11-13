unit AWSLambda4D.HTTP.Events.Test;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DUnitX.TestFramework,
  REST.Types,
  AWSLambda4D.HTTP.Events;

type
  [TestFixture]
  TAWSLambda4DHTTPEventsTest = class
  private
    function Parse(const AJSON: string): TJSONObject;
    function NewPayload: IAWSLambda4DHTTPPayloadV2;
  public
    [Test]
    procedure Content_FullExample_MatchesExpectedEvent;
    [Test]
    procedure Content_OnlyHttpPath_FillsRawPathAndRouteKey;
    [Test]
    procedure Content_OnlyRawPath_FillsHttpPathWithDefaults;
    [Test]
    procedure Content_NoRequestContext_StillHasHttpSection;
    [Test]
    procedure Content_Queries_AreEncodedAndCommaSplitIntoRepeatedParams;
    [Test]
    procedure Content_Headers_AreLowerCased;
    [Test]
    procedure Content_JsonBody_IsSerializedAsString;
    [Test]
    procedure End_FromHTTP_ReturnsRequestContext;
    [Test]
    procedure End_FromRequestContext_ReturnsPayload;
  end;

implementation

{ TAWSLambda4DHTTPEventsTest }

function TAWSLambda4DHTTPEventsTest.NewPayload: IAWSLambda4DHTTPPayloadV2;
begin
  Result := TAWSLambda4DHTTPPayloadV2.Create;
end;

function TAWSLambda4DHTTPEventsTest.Parse(const AJSON: string): TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  Assert.IsNotNull(Result);
end;

procedure TAWSLambda4DHTTPEventsTest.Content_FullExample_MatchesExpectedEvent;
var
  LPayload: IAWSLambda4DHTTPPayloadV2;
  LContext: IAWSLambda4DHTTPPayloadV2RequestContext;
  LEvent: TJSONObject;
  LCookies: TJSONArray;
begin
  LPayload := TAWSLambda4DHTTPPayloadV2.Create;
  LPayload
    .RouteKey('POST /documentos')
    .RawPath('/documentos')
    .AddQuery('id', '10,20')
    .AddQuery('situacao', 'ativo')
    .AddCookie('sessao', 'abc')
    .AddCookie('tema', 'dark')
    .AddHeader('content-type', 'application/json')
    .AddHeader('x-teste', 'valor-1,valor-2')
    .AddHeader('host', 'localhost')
    .Body('{"numero":123,"valor":150.50}')
    .IsBase64Encoded(False);

  LContext := TAWSLambda4DHTTPPayloadV2RequestContext.Create(LPayload);
  LContext
    .RequestId('local-v2-request')
    .Stage('$default')
    .HTTP
      .Method(TRESTRequestMethod.rmPOST)
      .Path('/documentos')
      .Protocol('HTTP/1.1')
      .SourceIp('127.0.0.1')
      .UserAgent('LambdaLocalTest');

  LEvent := Parse(LPayload.Content);
  try
    Assert.AreEqual('2.0', LEvent.GetValue<string>('version'));
    Assert.AreEqual('POST /documentos', LEvent.GetValue<string>('routeKey'));
    Assert.AreEqual('/documentos', LEvent.GetValue<string>('rawPath'));

    // A ordem dos parametros em um TDictionary nao e garantida.
    Assert.IsTrue(
      (LEvent.GetValue<string>('rawQueryString') = 'id=10&id=20&situacao=ativo') or
      (LEvent.GetValue<string>('rawQueryString') = 'situacao=ativo&id=10&id=20'));
    Assert.AreEqual('10,20', LEvent.GetValue<string>('queryStringParameters.id'));
    Assert.AreEqual('ativo', LEvent.GetValue<string>('queryStringParameters.situacao'));

    LCookies := LEvent.GetValue('cookies') as TJSONArray;
    Assert.AreEqual(2, LCookies.Count);

    Assert.AreEqual('application/json', LEvent.GetValue<string>('headers.content-type'));
    Assert.AreEqual('valor-1,valor-2', LEvent.GetValue<string>('headers.x-teste'));
    Assert.AreEqual('localhost', LEvent.GetValue<string>('headers.host'));

    Assert.AreEqual('local-v2-request', LEvent.GetValue<string>('requestContext.requestId'));
    Assert.AreEqual('$default', LEvent.GetValue<string>('requestContext.stage'));
    Assert.AreEqual('POST', LEvent.GetValue<string>('requestContext.http.method'));
    Assert.AreEqual('/documentos', LEvent.GetValue<string>('requestContext.http.path'));
    Assert.AreEqual('HTTP/1.1', LEvent.GetValue<string>('requestContext.http.protocol'));
    Assert.AreEqual('127.0.0.1', LEvent.GetValue<string>('requestContext.http.sourceIp'));
    Assert.AreEqual('LambdaLocalTest', LEvent.GetValue<string>('requestContext.http.userAgent'));

    Assert.AreEqual('{"numero":123,"valor":150.50}', LEvent.GetValue<string>('body'));
    Assert.IsFalse(LEvent.GetValue<Boolean>('isBase64Encoded'));
  finally
    LEvent.Free;
  end;
end;

procedure TAWSLambda4DHTTPEventsTest.Content_OnlyHttpPath_FillsRawPathAndRouteKey;
var
  LPayload: IAWSLambda4DHTTPPayloadV2;
  LContext: IAWSLambda4DHTTPPayloadV2RequestContext;
  LEvent: TJSONObject;
begin
  LPayload := TAWSLambda4DHTTPPayloadV2.Create;
  LContext := TAWSLambda4DHTTPPayloadV2RequestContext.Create(LPayload);
  LContext.HTTP.Method('post').Path('/items');

  LEvent := Parse(LPayload.Content);
  try
    Assert.AreEqual('/items', LEvent.GetValue<string>('rawPath'));
    Assert.AreEqual('POST /items', LEvent.GetValue<string>('routeKey'));
    Assert.AreEqual('POST', LEvent.GetValue<string>('requestContext.http.method'));
  finally
    LEvent.Free;
  end;
end;

procedure TAWSLambda4DHTTPEventsTest.Content_OnlyRawPath_FillsHttpPathWithDefaults;
var
  LEvent: TJSONObject;
begin
  LEvent := Parse(NewPayload.RawPath('/items').Content);
  try
    Assert.AreEqual('/items', LEvent.GetValue<string>('requestContext.http.path'));
    Assert.AreEqual('GET', LEvent.GetValue<string>('requestContext.http.method'));
    Assert.AreEqual('HTTP/1.1', LEvent.GetValue<string>('requestContext.http.protocol'));
  finally
    LEvent.Free;
  end;
end;

procedure TAWSLambda4DHTTPEventsTest.Content_NoRequestContext_StillHasHttpSection;
var
  LEvent: TJSONObject;
begin
  LEvent := Parse(NewPayload.Content);
  try
    Assert.IsNotNull(LEvent.FindValue('requestContext.http'));
    Assert.AreEqual('2.0', LEvent.GetValue<string>('version'));
  finally
    LEvent.Free;
  end;
end;

procedure TAWSLambda4DHTTPEventsTest.Content_Queries_AreEncodedAndCommaSplitIntoRepeatedParams;
var
  LEvent: TJSONObject;
begin
  LEvent := Parse(NewPayload
    .RawPath('/search')
    .AddQuery('q', 'a b')
    .Content);
  try
    Assert.AreEqual('q=a%20b', LEvent.GetValue<string>('rawQueryString'));
    Assert.AreEqual('a b', LEvent.GetValue<string>('queryStringParameters.q'));
  finally
    LEvent.Free;
  end;
end;

procedure TAWSLambda4DHTTPEventsTest.Content_Headers_AreLowerCased;
var
  LEvent: TJSONObject;
begin
  LEvent := Parse(NewPayload.AddHeader('Content-Type', 'text/plain').Content);
  try
    Assert.AreEqual('text/plain', LEvent.GetValue<string>('headers.content-type'));
  finally
    LEvent.Free;
  end;
end;

procedure TAWSLambda4DHTTPEventsTest.Content_JsonBody_IsSerializedAsString;
var
  LBody: TJSONObject;
  LEvent: TJSONObject;
begin
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('name', 'Gabriel');
    LEvent := Parse(NewPayload.Body(LBody).Content);
    try
      Assert.AreEqual('{"name":"Gabriel"}', LEvent.GetValue<string>('body'));
    finally
      LEvent.Free;
    end;
  finally
    LBody.Free;
  end;
end;

procedure TAWSLambda4DHTTPEventsTest.End_FromHTTP_ReturnsRequestContext;
var
  LPayload: IAWSLambda4DHTTPPayloadV2;
  LContext: IAWSLambda4DHTTPPayloadV2RequestContext;
begin
  LPayload := TAWSLambda4DHTTPPayloadV2.Create;
  LContext := TAWSLambda4DHTTPPayloadV2RequestContext.Create(LPayload);
  Assert.IsTrue(LContext.HTTP.&End = LContext);
end;

procedure TAWSLambda4DHTTPEventsTest.End_FromRequestContext_ReturnsPayload;
var
  LPayload: IAWSLambda4DHTTPPayloadV2;
  LContext: IAWSLambda4DHTTPPayloadV2RequestContext;
begin
  LPayload := TAWSLambda4DHTTPPayloadV2.Create;
  LContext := TAWSLambda4DHTTPPayloadV2RequestContext.Create(LPayload);
  Assert.IsTrue(LContext.&End = LPayload);
end;

end.
