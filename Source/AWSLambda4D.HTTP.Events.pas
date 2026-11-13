unit AWSLambda4D.HTTP.Events;

interface

uses
  System.JSON,
  System.Generics.Collections,
  REST.Types;

type
  IAWSLambda4DHTTPPayloadV2RequestContext = interface;

  IAWSLambda4DHTTPPayloadV2 = interface
    ['{1915937F-6141-4181-AD37-3B6D5CE2A075}']
    function RawPath(const AValue: string): IAWSLambda4DHTTPPayloadV2;
    function RouteKey(const AValue: string): IAWSLambda4DHTTPPayloadV2;
    function AddQuery(const AName, AValue: string): IAWSLambda4DHTTPPayloadV2;
    function AddHeader(const AName, AValue: string): IAWSLambda4DHTTPPayloadV2;
    function AddCookie(const AName, AValue: string): IAWSLambda4DHTTPPayloadV2;
    function Body(const AValue: string): IAWSLambda4DHTTPPayloadV2; overload;
    function Body(const AValue: TJSONValue): IAWSLambda4DHTTPPayloadV2; overload;
    function IsBase64Encoded(const AValue: Boolean): IAWSLambda4DHTTPPayloadV2;
    function RequestContext: IAWSLambda4DHTTPPayloadV2RequestContext;
    function Content: string;
  end;

  IAWSLambda4DHTTPPayloadV2HTTP = interface
    ['{97EBCFE8-FDB1-43E4-9476-8E9F613C2619}']
    function Method(const AValue: TRESTRequestMethod): IAWSLambda4DHTTPPayloadV2HTTP; overload;
    function Method(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP; overload;
    function Path(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
    function Protocol(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
    function SourceIp(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
    function UserAgent(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
    function &End: IAWSLambda4DHTTPPayloadV2RequestContext;
  end;

  IAWSLambda4DHTTPPayloadV2RequestContext = interface
    ['{B759024A-FC78-40DB-B9A9-877DB4C0581C}']
    function RequestId(const AValue: string): IAWSLambda4DHTTPPayloadV2RequestContext;
    function Stage(const AValue: string): IAWSLambda4DHTTPPayloadV2RequestContext;
    function HTTP: IAWSLambda4DHTTPPayloadV2HTTP;
    function &End: IAWSLambda4DHTTPPayloadV2;
  end;

  TAWSLambda4DHTTPPayloadV2 = class(TInterfacedObject, IAWSLambda4DHTTPPayloadV2)
  private
    FRawPath: string;
    FRouteKey: string;
    FQueries: TDictionary<string, string>;
    FHeaders: TDictionary<string, string>;
    FCookies: TDictionary<string, string>;
    FBody: string;
    FIsBase64Encoded: Boolean;
    FRequestContext: IAWSLambda4DHTTPPayloadV2RequestContext;
  protected
    function RawPath(const AValue: string): IAWSLambda4DHTTPPayloadV2;
    function RouteKey(const AValue: string): IAWSLambda4DHTTPPayloadV2;
    function AddQuery(const AName, AValue: string): IAWSLambda4DHTTPPayloadV2;
    function AddHeader(const AName, AValue: string): IAWSLambda4DHTTPPayloadV2;
    function AddCookie(const AName, AValue: string): IAWSLambda4DHTTPPayloadV2;
    function Body(const AValue: string): IAWSLambda4DHTTPPayloadV2; overload;
    function Body(const AValue: TJSONValue): IAWSLambda4DHTTPPayloadV2; overload;
    function IsBase64Encoded(const AValue: Boolean): IAWSLambda4DHTTPPayloadV2;
    function RequestContext: IAWSLambda4DHTTPPayloadV2RequestContext;
    function Content: string;
  public
    constructor Create;
    class function New: IAWSLambda4DHTTPPayloadV2;
    destructor Destroy; override;
  end;

  TAWSLambda4DHTTPPayloadV2HTTP = class(TInterfacedObject, IAWSLambda4DHTTPPayloadV2HTTP)
  private
    [Weak]
    FParent: IAWSLambda4DHTTPPayloadV2RequestContext;
    FMethod: string;
    FPath: string;
    FProtocol: string;
    FSourceIp: string;
    FUserAgent: string;
  protected
    function Method(const AValue: TRESTRequestMethod): IAWSLambda4DHTTPPayloadV2HTTP; overload;
    function Method(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP; overload;
    function Path(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
    function Protocol(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
    function SourceIp(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
    function UserAgent(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
    function &End: IAWSLambda4DHTTPPayloadV2RequestContext;
  public
    constructor Create(const AParent: IAWSLambda4DHTTPPayloadV2RequestContext);
  end;

  TAWSLambda4DHTTPPayloadV2RequestContext = class(TInterfacedObject, IAWSLambda4DHTTPPayloadV2RequestContext)
  private
    [Weak]
    FParent: IAWSLambda4DHTTPPayloadV2;
    FHTTP: IAWSLambda4DHTTPPayloadV2HTTP;
    FRequestId: string;
    FStage: string;
  protected
    function RequestId(const AValue: string): IAWSLambda4DHTTPPayloadV2RequestContext;
    function Stage(const AValue: string): IAWSLambda4DHTTPPayloadV2RequestContext;
    function HTTP: IAWSLambda4DHTTPPayloadV2HTTP;
    function &End: IAWSLambda4DHTTPPayloadV2;
  public
    constructor Create(const AParent: IAWSLambda4DHTTPPayloadV2);
  end;

implementation

uses
  System.SysUtils,
  System.NetEncoding;

// O codificador de URL do Delphi escreve espaco como '+'; usa %20 para nao haver ambiguidade.
function EncodeQueryPart(const AValue: string): string;
begin
  Result := TNetEncoding.URL.Encode(AValue).Replace('+', '%20');
end;

// Se o campo ja existe, junta o novo valor com virgula (como o API Gateway faz com valores repetidos).
procedure AddJoined(const AObject: TJSONObject; const AName, AValue: string);
var
  LCurrent: TJSONValue;
  LJoined: string;
begin
  LCurrent := AObject.GetValue(AName);
  if LCurrent = nil then
  begin
    AObject.AddPair(AName, AValue);
    Exit;
  end;

  LJoined := LCurrent.Value + ',' + AValue;
  AObject.RemovePair(AName).Free;
  AObject.AddPair(AName, LJoined);
end;

{ TAWSLambda4DHTTPPayloadV2 }

constructor TAWSLambda4DHTTPPayloadV2.Create;
begin
  inherited Create;
  FQueries := TDictionary<string, string>.Create;
  FHeaders := TDictionary<string, string>.Create;
  FCookies := TDictionary<string, string>.Create;
end;

destructor TAWSLambda4DHTTPPayloadV2.Destroy;
begin
  FQueries.Free;
  FHeaders.Free;
  FCookies.Free;
  inherited;
end;

function TAWSLambda4DHTTPPayloadV2.RawPath(const AValue: string): IAWSLambda4DHTTPPayloadV2;
begin
  Result := Self;
  FRawPath := AValue;
end;

function TAWSLambda4DHTTPPayloadV2.RequestContext: IAWSLambda4DHTTPPayloadV2RequestContext;
begin
  if not Assigned(FRequestContext) then
    FRequestContext := TAWSLambda4DHTTPPayloadV2RequestContext.Create(Self);
  Result := FRequestContext;
end;

function TAWSLambda4DHTTPPayloadV2.RouteKey(const AValue: string): IAWSLambda4DHTTPPayloadV2;
begin
  Result := Self;
  FRouteKey := AValue;
end;

function TAWSLambda4DHTTPPayloadV2.AddQuery(const AName, AValue: string): IAWSLambda4DHTTPPayloadV2;
begin
  Result := Self;
  FQueries.AddOrSetValue(AName, AValue);
end;

function TAWSLambda4DHTTPPayloadV2.AddHeader(const AName, AValue: string): IAWSLambda4DHTTPPayloadV2;
begin
  Result := Self;
  FHeaders.AddOrSetValue(AName, AValue);
end;

function TAWSLambda4DHTTPPayloadV2.AddCookie(const AName, AValue: string): IAWSLambda4DHTTPPayloadV2;
begin
  Result := Self;
  FCookies.AddOrSetValue(AName, AValue);
end;

function TAWSLambda4DHTTPPayloadV2.Body(const AValue: string): IAWSLambda4DHTTPPayloadV2;
begin
  Result := Self;
  FBody := AValue;
end;

function TAWSLambda4DHTTPPayloadV2.Body(const AValue: TJSONValue): IAWSLambda4DHTTPPayloadV2;
begin
  Result := Self;
  // Guarda o JSON serializado: o TJSONValue continua pertencendo a quem o criou.
  if AValue = nil then
    FBody := ''
  else
    FBody := AValue.ToJSON;
end;

function TAWSLambda4DHTTPPayloadV2.IsBase64Encoded(const AValue: Boolean): IAWSLambda4DHTTPPayloadV2;
begin
  Result := Self;
  FIsBase64Encoded := AValue;
end;

class function TAWSLambda4DHTTPPayloadV2.New: IAWSLambda4DHTTPPayloadV2;
begin
  Result := Self.Create;
end;

function TAWSLambda4DHTTPPayloadV2.Content: string;
var
  LEvent: TJSONObject;
  LHeaders: TJSONObject;
  LQuery: TJSONObject;
  LContext: TJSONObject;
  LHttp: TJSONObject;
  LCookies: TJSONArray;
  LPair: TPair<string, string>;
  LRequestContext: TAWSLambda4DHTTPPayloadV2RequestContext;
  LHTTPData: TAWSLambda4DHTTPPayloadV2HTTP;
  LMethod: string;
  LPath: string;
  LProtocol: string;
  LRawPath: string;
  LRouteKey: string;
  LRawQuery: string;
  LValue: string;
begin
  LRequestContext := nil;
  LHTTPData := nil;
  if FRequestContext <> nil then
  begin
    LRequestContext := FRequestContext as TAWSLambda4DHTTPPayloadV2RequestContext;
    if LRequestContext.FHTTP <> nil then
      LHTTPData := LRequestContext.FHTTP as TAWSLambda4DHTTPPayloadV2HTTP;
  end;

  // Valores padrao para o que nao foi informado.
  LMethod := 'GET';
  LProtocol := 'HTTP/1.1';
  LPath := '';
  if LHTTPData <> nil then
  begin
    if LHTTPData.FMethod <> '' then
      LMethod := UpperCase(LHTTPData.FMethod);
    if LHTTPData.FProtocol <> '' then
      LProtocol := LHTTPData.FProtocol;
    LPath := LHTTPData.FPath;
  end;

  // Um dos dois caminhos basta para preencher o outro.
  LRawPath := FRawPath;
  if LRawPath = '' then
    LRawPath := LPath;
  if LPath = '' then
    LPath := LRawPath;

  LRouteKey := FRouteKey;
  if LRouteKey = '' then
    LRouteKey := LMethod + ' ' + LRawPath;

  // Valores separados por virgula viram parametros repetidos (id=10&id=20).
  LRawQuery := '';
  for LPair in FQueries do
    for LValue in LPair.Value.Split([',']) do
    begin
      if LRawQuery <> '' then
        LRawQuery := LRawQuery + '&';
      LRawQuery := LRawQuery + EncodeQueryPart(LPair.Key) + '=' + EncodeQueryPart(LValue);
    end;

  LEvent := TJSONObject.Create;
  try
    LEvent.AddPair('version', '2.0');
    LEvent.AddPair('routeKey', LRouteKey);
    LEvent.AddPair('rawPath', LRawPath);
    LEvent.AddPair('rawQueryString', LRawQuery);

    if FCookies.Count > 0 then
    begin
      LCookies := TJSONArray.Create;
      LEvent.AddPair('cookies', LCookies);
      for LPair in FCookies do
        LCookies.Add(LPair.Key + '=' + LPair.Value);
    end;

    // Nomes de cabecalhos viajam em minusculas no payload v2.
    LHeaders := TJSONObject.Create;
    LEvent.AddPair('headers', LHeaders);
    for LPair in FHeaders do
      AddJoined(LHeaders, LowerCase(LPair.Key), LPair.Value);

    if FQueries.Count > 0 then
    begin
      LQuery := TJSONObject.Create;
      LEvent.AddPair('queryStringParameters', LQuery);
      for LPair in FQueries do
        LQuery.AddPair(LPair.Key, LPair.Value);
    end;

    LContext := TJSONObject.Create;
    LEvent.AddPair('requestContext', LContext);
    if (LRequestContext <> nil) and (LRequestContext.FRequestId <> '') then
      LContext.AddPair('requestId', LRequestContext.FRequestId);
    if (LRequestContext <> nil) and (LRequestContext.FStage <> '') then
      LContext.AddPair('stage', LRequestContext.FStage);

    LHttp := TJSONObject.Create;
    LContext.AddPair('http', LHttp);
    LHttp.AddPair('method', LMethod);
    LHttp.AddPair('path', LPath);
    LHttp.AddPair('protocol', LProtocol);
    if (LHTTPData <> nil) and (LHTTPData.FSourceIp <> '') then
      LHttp.AddPair('sourceIp', LHTTPData.FSourceIp);
    if (LHTTPData <> nil) and (LHTTPData.FUserAgent <> '') then
      LHttp.AddPair('userAgent', LHTTPData.FUserAgent);

    if FBody <> '' then
      LEvent.AddPair('body', FBody);
    LEvent.AddPair('isBase64Encoded', TJSONBool.Create(FIsBase64Encoded));

    Result := LEvent.ToJSON;
  finally
    LEvent.Free;
  end;
end;

{ TAWSLambda4DHTTPPayloadV2HTTP }

constructor TAWSLambda4DHTTPPayloadV2HTTP.Create(const AParent: IAWSLambda4DHTTPPayloadV2RequestContext);
begin
  inherited Create;
  FParent := AParent;
end;

function TAWSLambda4DHTTPPayloadV2HTTP.Method(const AValue: TRESTRequestMethod): IAWSLambda4DHTTPPayloadV2HTTP;
begin
  Result := Self;
  FMethod := RESTRequestMethodToString(AValue);
end;

function TAWSLambda4DHTTPPayloadV2HTTP.Method(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
begin
  Result := Self;
  FMethod := AValue;
end;

function TAWSLambda4DHTTPPayloadV2HTTP.Path(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
begin
  Result := Self;
  FPath := AValue;
end;

function TAWSLambda4DHTTPPayloadV2HTTP.Protocol(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
begin
  Result := Self;
  FProtocol := AValue;
end;

function TAWSLambda4DHTTPPayloadV2HTTP.SourceIp(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
begin
  Result := Self;
  FSourceIp := AValue;
end;

function TAWSLambda4DHTTPPayloadV2HTTP.UserAgent(const AValue: string): IAWSLambda4DHTTPPayloadV2HTTP;
begin
  Result := Self;
  FUserAgent := AValue;
end;

function TAWSLambda4DHTTPPayloadV2HTTP.&End: IAWSLambda4DHTTPPayloadV2RequestContext;
begin
  Result := FParent;
end;

{ TAWSLambda4DHTTPPayloadV2RequestContext }

constructor TAWSLambda4DHTTPPayloadV2RequestContext.Create(const AParent: IAWSLambda4DHTTPPayloadV2);
begin
  inherited Create;
  FParent := AParent;

  // Registra-se no payload para que Content inclua o requestContext.
  if (AParent <> nil) and ((AParent as TObject) is TAWSLambda4DHTTPPayloadV2) then
    TAWSLambda4DHTTPPayloadV2(AParent as TObject).FRequestContext := Self;
end;

function TAWSLambda4DHTTPPayloadV2RequestContext.RequestId(
  const AValue: string): IAWSLambda4DHTTPPayloadV2RequestContext;
begin
  Result := Self;
  FRequestId := AValue;
end;

function TAWSLambda4DHTTPPayloadV2RequestContext.Stage(const AValue: string): IAWSLambda4DHTTPPayloadV2RequestContext;
begin
  Result := Self;
  FStage := AValue;
end;

function TAWSLambda4DHTTPPayloadV2RequestContext.HTTP: IAWSLambda4DHTTPPayloadV2HTTP;
begin
  if FHTTP = nil then
    FHTTP := TAWSLambda4DHTTPPayloadV2HTTP.Create(Self);
  Result := FHTTP;
end;

function TAWSLambda4DHTTPPayloadV2RequestContext.&End: IAWSLambda4DHTTPPayloadV2;
begin
  Result := FParent;
end;

end.
