unit AWSLambda4D.HTTP.Adapter;

interface

uses
  System.SysUtils,
  System.JSON,
  System.NetEncoding,
  System.Generics.Collections,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.HTTP.Types;

type
  TLambdaHttpAdapter = class(TInterfacedObject, IAWSLambda4DHandler)
  private
    FHandler: IAWSLambda4DHTTPHandler;

    function ParseRequest(const AEventJSON: string; out APayloadVersion: TAWSLambda4DHttpPayloadVersion):
      TAWSLambda4DHTTPRequest;
    function SerializeResponse(const AResponse: TAWSLambda4DHTTPResponse;
      const APayloadVersion: TAWSLambda4DHttpPayloadVersion): string;
  public
    constructor Create(const AHandler: IAWSLambda4DHTTPHandler);

    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  end;

implementation

uses
  AWSLambda4D.Utils;

{ TLambdaHttpAdapter }

constructor TLambdaHttpAdapter.Create(const AHandler: IAWSLambda4DHTTPHandler);
begin
  if AHandler = nil then
    raise Exception.Create('HTTP Handler não informado.');
  FHandler := AHandler;
end;

function TLambdaHttpAdapter.Handle(const ARequest: TAWSLambda4DRequest;
  const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
var
  LHttpRequest: TAWSLambda4DHTTPRequest;
  LHttpResponse: TAWSLambda4DHTTPResponse;
  LPayloadVersion: TAWSLambda4DHttpPayloadVersion;
  LResponseBody: string;
begin
  LHttpResponse := nil;
  LHttpRequest := ParseRequest(ARequest.Body, LPayloadVersion);
  try
    try
      LHttpResponse := FHandler.Execute(LHttpRequest);
      if LHttpResponse = nil then
        raise Exception.Create('O HTTP Handler retornou uma resposta nula.');
    except
      on E: Exception do
      begin
        LHttpResponse := TAWSLambda4DHTTPResponse.Create;
        LHttpResponse.StatusCode := 500;
        LHttpResponse.Headers.Add('content-type', 'application/json; charset=utf-8');
        LHttpResponse.SetBody('{"message":"Internal Server Error"}');
      end;
    end;

    LResponseBody := SerializeResponse(LHttpResponse, LPayloadVersion);

    Result := TAWSLambda4DResponse.Create;
    Result.Body := LResponseBody;
  finally
    LHttpRequest.Free;
    LHttpResponse.Free;
  end;
end;

function TLambdaHttpAdapter.ParseRequest(const AEventJSON: string;
  out APayloadVersion: TAWSLambda4DHttpPayloadVersion): TAWSLambda4DHTTPRequest;
var
  LEvent: TJSONObject;
  LContext: TJSONObject;
  LHttp: TJSONObject;
  LHeaders: TJSONObject;
  LMultiHeaders: TJSONObject;
  LQuery: TJSONObject;
  LMultiQuery: TJSONObject;
  LCookies: TJSONArray;
  LBody: string;
  LVersion: string;
  LValue: TJSONValue;
begin
  Result := nil;
  APayloadVersion := hpvUnknown;
  LEvent := TJSONObject.ParseJSONValue(AEventJSON) as TJSONObject;
  try
    if LEvent = nil then
      raise Exception.Create('Invalid HTTP Event: JSON is not an object.');

    try
      LVersion := JsonString(LEvent, 'version');
      LContext := LEvent.GetValue('requestContext') as TJSONObject;
      LHttp := nil;

      if LContext <> nil then
        LHttp := LContext.GetValue('http') as TJSONObject;

      if (LVersion = '2.0') or (LHttp <> nil) then
        APayloadVersion := hpvV2
      else
      if LEvent.GetValue('httpMethod') <> nil then
        APayloadVersion := hpvV1
      else
        raise Exception.Create('Unknow event http version.');

      Result := TAWSLambda4DHTTPRequest.Create;

      if APayloadVersion = hpvV2 then
      begin
        Result.Method := JsonString(LHttp, 'method');
        Result.Path := JsonString(LEvent, 'rawPath');

        if Result.Path = '' then
          Result.Path := JsonString(LEvent, 'path');

        LQuery := LEvent.GetValue('queryStringParameters') as TJSONObject;
        LHeaders := LEvent.GetValue('headers') as TJSONObject;
        AddJsonObjectValues(LHeaders, Result.Headers);
        AddJsonObjectValues(LQuery, Result.QueryParams);
        LCookies := LEvent.GetValue('cookies') as TJSONArray;

        if LCookies <> nil then
        begin
          for LValue in LCookies do
            Result.Cookies.Add(LValue.Value);
        end;
      end
      else
      begin
        Result.Method := JsonString(LEvent, 'httpMethod');
        Result.Path := JsonString(LEvent, 'path');
        LHeaders := LEvent.GetValue('headers') as TJSONObject;
        LMultiHeaders := LEvent.GetValue('multiValueHeaders') as TJSONObject;
        LQuery := LEvent.GetValue('queryStringParameters') as TJSONObject;
        LMultiQuery := LEvent.GetValue('multiValueQueryStringParameters') as TJSONObject;
        AddJsonObjectValues(LHeaders, Result.Headers);
        AddJsonObjectValues(LMultiHeaders, Result.Headers);
        AddJsonObjectValues(LQuery, Result.QueryParams);
        AddJsonObjectValues(LMultiQuery, Result.QueryParams);
      end;

      LBody := JsonString(LEvent, 'body');

      Result.IsBase64Encoded := JsonBoolean(LEvent, 'isBase64Encoded');

      if Result.IsBase64Encoded and (LBody <> '') then
        Result.Body := TNetEncoding.Base64.DecodeStringToBytes(LBody)
      else
        Result.Body := TEncoding.UTF8.GetBytes(LBody);
    except
      Result.Free;
      raise;
    end;
  finally
    LEvent.Free;
  end;
end;

function TLambdaHttpAdapter.SerializeResponse(const AResponse: TAWSLambda4DHTTPResponse;
  const APayloadVersion: TAWSLambda4DHttpPayloadVersion): string;
var
  LJSON: TJSONObject;
  LHeaders: TJSONObject;
  LCookies: TJSONArray;
  LPair: TPair<string, string>;
  LBody: string;
  LCookie: string;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('statusCode', TJSONNumber.Create(AResponse.StatusCode));
    LHeaders := TJSONObject.Create;
    for LPair in AResponse.Headers do
      LHeaders.AddPair(LPair.Key, LPair.Value);

    LJSON.AddPair('headers', LHeaders);

    if AResponse.IsBase64Encoded then
      LBody := TNetEncoding.Base64.EncodeBytesToString(AResponse.Body)
    else
      LBody := TEncoding.UTF8.GetString(AResponse.Body);

    LJSON.AddPair('body', LBody);
    LJSON.AddPair('isBase64Encoded', TJSONBool.Create(AResponse.IsBase64Encoded));

    if APayloadVersion = hpvV2 then
    begin
      LCookies := TJSONArray.Create;
      for LCookie in AResponse.Cookies do
        LCookies.Add(LCookie);

      if LCookies.Count > 0 then
        LJSON.AddPair('cookies', LCookies)
      else
        LCookies.Free;
    end;

    Result := LJSON.ToJSON;
  finally
    LJSON.Free;
  end;
end;

end.
