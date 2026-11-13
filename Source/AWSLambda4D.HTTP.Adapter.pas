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
  TAWSLambda4DHTTPAdapter = class(TInterfacedObject, IAWSLambda4DHandler)
  private
    FHandler: IAWSLambda4DHTTPHandler;

    function BuildErrorResponse(const AStatusCode: Integer; const AMessage: string): TAWSLambda4DHTTPResponse;
    procedure ParseQueryString(const ARawQueryString: string; const AParams: TAWSLambda4DHTTPValues);
    function ParseRequest(const AEventJSON: string; out APayloadVersion: TAWSLambda4DHttpPayloadVersion):
      TAWSLambda4DHTTPRequest;
    function SerializeResponse(const AResponse: TAWSLambda4DHTTPResponse;
      const APayloadVersion: TAWSLambda4DHttpPayloadVersion): string;
  public
    constructor Create(const AHandler: IAWSLambda4DHTTPHandler);
    class function New(const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHandler;

    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  end;

implementation

uses
  AWSLambda4D.Utils;

{ TAWSLambda4DHTTPAdapter }

constructor TAWSLambda4DHTTPAdapter.Create(const AHandler: IAWSLambda4DHTTPHandler);
begin
  if AHandler = nil then
    raise Exception.Create('HTTP Handler não informado.');
  FHandler := AHandler;
end;

function TAWSLambda4DHTTPAdapter.BuildErrorResponse(const AStatusCode: Integer;
  const AMessage: string): TAWSLambda4DHTTPResponse;
var
  LJSON: TJSONObject;
begin
  Result := TAWSLambda4DHTTPResponse.Create;
  try
    Result.StatusCode := AStatusCode;
    Result.Headers.Add('content-type', 'application/json; charset=utf-8');

    LJSON := TJSONObject.Create;
    try
      LJSON.AddPair('message', AMessage);
      Result.SetBody(LJSON.ToJSON);
    finally
      LJSON.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TAWSLambda4DHTTPAdapter.Handle(const ARequest: TAWSLambda4DRequest;
  const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
var
  LHttpRequest: TAWSLambda4DHTTPRequest;
  LHttpResponse: TAWSLambda4DHTTPResponse;
  LPayloadVersion: TAWSLambda4DHttpPayloadVersion;
begin
  LHttpRequest := ParseRequest(ARequest.Body, LPayloadVersion);
  LHttpResponse := nil;
  try
    try
      LHttpResponse := FHandler.Execute(LHttpRequest);
      if LHttpResponse = nil then
        raise Exception.Create('The Handler HTTP returns a null response.');
    except
      // Entrada invalida do cliente (ex.: parametro nao conversivel): 400 com a mensagem.
      on E: EAWSLambda4DHTTPBadRequest do
        LHttpResponse := BuildErrorResponse(400, E.Message);

      on E: Exception do
        LHttpResponse := BuildErrorResponse(500, 'Internal Server Error');
    end;

    Result := TAWSLambda4DResponse.Create;
    try
      Result.Body := SerializeResponse(LHttpResponse, LPayloadVersion);
    except
      Result.Free;
      raise;
    end;
  finally
    LHttpResponse.Free;
    LHttpRequest.Free;
  end;
end;

class function TAWSLambda4DHTTPAdapter.New(const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHandler;
begin
  Result := Self.Create(AHandler);
end;

procedure TAWSLambda4DHTTPAdapter.ParseQueryString(const ARawQueryString: string; const AParams: TAWSLambda4DHTTPValues);
var
  LQuery: string;
  LPair: string;
  LName: string;
  LValue: string;
  LPosition: Integer;
  LEqualsPosition: Integer;
begin
  LQuery := ARawQueryString;
  if LQuery.StartsWith('?') then
    Delete(LQuery, 1, 1);

  while LQuery <> '' do
  begin
    LPosition := Pos('&', LQuery);

    if LPosition > 0 then
    begin
      LPair := Copy(LQuery, 1, LPosition - 1);
      Delete(LQuery, 1, LPosition);
    end
    else
    begin
      LPair := LQuery;
      LQuery := '';
    end;

    LEqualsPosition := Pos('=', LPair);

    if LEqualsPosition > 0 then
    begin
      LName := Copy(LPair, 1, LEqualsPosition - 1);
      LValue := Copy(LPair, LEqualsPosition + 1, MaxInt);
    end
    else
    begin
      LName := LPair;
      LValue := '';
    end;

    LName := TNetEncoding.URL.Decode(StringReplace(LName, '+', ' ', [rfReplaceAll]));
    LValue := TNetEncoding.URL.Decode(StringReplace(LValue, '+', ' ', [rfReplaceAll]));
    AParams.Add(LName, LValue);
  end;
end;

function TAWSLambda4DHTTPAdapter.ParseRequest(const AEventJSON: string;
  out APayloadVersion: TAWSLambda4DHttpPayloadVersion): TAWSLambda4DHTTPRequest;
var
  LJSONValue: TJSONValue;
  LEvent: TJSONObject;
  LContext: TJSONObject;
  LHttp: TJSONObject;
  LHeaders: TJSONObject;
  LMultiHeaders: TJSONObject;
  LQuery: TJSONObject;
  LMultiQuery: TJSONObject;
  LCookies: TJSONArray;
  LValue: TJSONValue;
  LBody: string;
  LVersion: string;
begin
  Result := nil;
  APayloadVersion := hpvUnknown;
  LJSONValue := TJSONObject.ParseJSONValue(AEventJSON);

  if not (LJSONValue is TJSONObject) then
  begin
    LJSONValue.Free;
    raise Exception.Create('Invalid HTTP event: expected a JSON Object.');
  end;

  LEvent := TJSONObject(LJSONValue);
  try
    try
      if LEvent = nil then
        raise Exception.Create('Evento HTTP inválido.');

      LVersion := JsonString(LEvent, 'version');
      LContext := LEvent.GetValue('requestContext') as TJSONObject;
      LHttp := nil;

      if LContext <> nil then
        LHttp := LContext.GetValue('http') as TJSONObject;

      if LVersion = '2.0' then
        APayloadVersion := hpvV2
      else
      if (LVersion = '1.0') or (LEvent.GetValue('httpMethod') <> nil) then
        APayloadVersion := hpvV1
      else
        raise Exception.Create('Unknow HTTP event version.');

      Result := TAWSLambda4DHTTPRequest.Create;

      if APayloadVersion = hpvV2 then
      begin
        if LHttp = nil then
          raise Exception.Create('requestContext.http não encontrado no evento v2.');

        Result.Method := JsonString(LHttp, 'method');
        Result.Path := JsonString(LEvent, 'rawPath');
        Result.RawQueryString := JsonString(LEvent, 'rawQueryString');

        LHeaders := LEvent.GetValue('headers') as TJSONObject;
        AddJsonValues(LHeaders, Result.Headers);

        if LEvent.GetValue('rawQueryString') <> nil then
          ParseQueryString(Result.RawQueryString, Result.QueryParams)
        else
        begin
          LQuery := LEvent.GetValue('queryStringParameters') as TJSONObject;
          AddJsonValues(LQuery, Result.QueryParams);
        end;

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
        AddJsonValues(LMultiHeaders, Result.Headers);
        AddJsonValues(LHeaders, Result.Headers, True);
        LMultiQuery := LEvent.GetValue('multiValueQueryStringParameters') as TJSONObject;
        LQuery := LEvent.GetValue('queryStringParameters') as TJSONObject;
        AddJsonValues(LMultiQuery, Result.QueryParams);
        AddJsonValues(LQuery, Result.QueryParams, True);
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

function TAWSLambda4DHTTPAdapter.SerializeResponse(const AResponse: TAWSLambda4DHTTPResponse;
  const APayloadVersion: TAWSLambda4DHttpPayloadVersion): string;
var
  LJSON: TJSONObject;
  LHeaders: TJSONObject;
  LMultiHeaders: TJSONObject;
  LCookies: TJSONArray;
  LValues: TJSONArray;
  LNames: TArray<string>;
  LName: string;
  LValue: string;
  LJoined: string;
  I: Integer;
  J: Integer;
begin
  if (AResponse.StatusCode < 100) or (AResponse.StatusCode > 599) then
    raise Exception.Create('Invalid HTTP Status Code.');

  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('statusCode', TJSONNumber.Create(AResponse.StatusCode));
    LJSON.AddPair('isBase64Encoded', TJSONBool.Create(AResponse.IsBase64Encoded));

    if AResponse.IsBase64Encoded then
      LValue := TNetEncoding.Base64.EncodeBytesToString(AResponse.Body)
    else
      LValue := TEncoding.UTF8.GetString(AResponse.Body);

    LJSON.AddPair('body', LValue);

    LNames := AResponse.Headers.Names;

    if APayloadVersion = hpvV1 then
    begin
      LMultiHeaders := TJSONObject.Create;

      for LName in LNames do
      begin
        LValues := TJSONArray.Create;

        for I := 0 to AResponse.Headers.ValueCount(LName) - 1 do
          LValues.Add(AResponse.Headers.Value(LName, I));

        LMultiHeaders.AddPair(LName, LValues);
      end;

      if AResponse.Cookies.Count > 0 then
      begin
        LValues := LMultiHeaders.GetValue('set-cookie') as TJSONArray;

        if LValues = nil then
        begin
          LValues := TJSONArray.Create;
          LMultiHeaders.AddPair('set-cookie', LValues);
        end;

        for LValue in AResponse.Cookies do
          LValues.Add(LValue);
      end;

      LJSON.AddPair('multiValueHeaders', LMultiHeaders);
    end
    else
    begin
      LHeaders := TJSONObject.Create;
      LCookies := TJSONArray.Create;

      for LName in LNames do
      begin
        if SameText(LName, 'set-cookie') then
        begin
          for I := 0 to AResponse.Headers.ValueCount(LName) - 1 do
            LCookies.Add(AResponse.Headers.Value(LName, I));

          Continue;
        end;

        LJoined := '';
        for I := 0 to AResponse.Headers.ValueCount(LName) - 1 do
        begin
          if I > 0 then
            LJoined := LJoined + ',';
          LJoined := LJoined + AResponse.Headers.Value(LName, I);
        end;

        LHeaders.AddPair(LName, LJoined);
      end;

      for J := 0 to AResponse.Cookies.Count - 1 do
        LCookies.Add(AResponse.Cookies[J]);

      LJSON.AddPair('headers', LHeaders);

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
