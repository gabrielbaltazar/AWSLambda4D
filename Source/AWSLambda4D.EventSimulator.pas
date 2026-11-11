unit AWSLambda4D.EventSimulator;

interface

type
  TAWSLambda4DEventSimulator = class
  public
    class function CreateV1Event: string; static;
    class function CreateV2Event: string; static;
  end;

implementation

{ TAWSLambda4DEventSimulator }

class function TAWSLambda4DEventSimulator.CreateV1Event: string;
begin
  Result :=
    '{' +
      '"version":"1.0",' +
      '"resource":"/documentos",' +
      '"path":"/documentos",' +
      '"httpMethod":"POST",' +

      '"headers":{' +
        '"content-type":"application/json",' +
        '"x-teste":"valor-1"' +
      '},' +

      '"multiValueHeaders":{' +
        '"content-type":["application/json"],' +
        '"x-teste":["valor-1","valor-2"],' +
        '"cookie":["sessao=abc; tema=dark"]' +
      '},' +

      '"queryStringParameters":{' +
        '"id":"10"' +
      '},' +

      '"multiValueQueryStringParameters":{' +
        '"id":["10","20"],' +
        '"situacao":["ativo"]' +
      '},' +

      '"requestContext":{' +
        '"requestId":"local-v1-request",' +
        '"stage":"dev",' +
        '"identity":{' +
          '"sourceIp":"127.0.0.1",' +
          '"userAgent":"LambdaLocalTest"' +
        '}' +
      '},' +

      '"body":"{\"numero\":123,\"valor\":150.50}",' +
      '"isBase64Encoded":false' +
    '}';
end;

class function TAWSLambda4DEventSimulator.CreateV2Event: string;
begin
  Result :=
    '{' +
      '"version":"2.0",' +
      '"routeKey":"POST /documentos",' +
      '"rawPath":"/documentos",' +
      '"rawQueryString":"id=10&id=20&situacao=ativo",' +

      '"cookies":[' +
        '"sessao=abc",' +
        '"tema=dark"' +
      '],' +

      '"headers":{' +
        '"content-type":"application/json",' +
        '"x-teste":"valor-1,valor-2",' +
        '"host":"localhost"' +
      '},' +

      '"queryStringParameters":{' +
        '"id":"10,20",' +
        '"situacao":"ativo"' +
      '},' +

      '"requestContext":{' +
        '"requestId":"local-v2-request",' +
        '"stage":"$default",' +
        '"http":{' +
          '"method":"POST",' +
          '"path":"/documentos",' +
          '"protocol":"HTTP/1.1",' +
          '"sourceIp":"127.0.0.1",' +
          '"userAgent":"LambdaLocalTest"' +
        '}' +
      '},' +

      '"body":"{\"numero\":123,\"valor\":150.50}",' +
      '"isBase64Encoded":false' +
    '}';
end;

end.
