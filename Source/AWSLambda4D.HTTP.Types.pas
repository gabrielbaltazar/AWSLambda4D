unit AWSLambda4D.HTTP.Types;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TAWSLambda4DHttpPayloadVersion = (hpvUnknown, hpvV1, hpvV2);

  TAWSLambda4DHTTPValues = class;

  TAWSLambda4DHTTPRequest = class
  private
    FPath: string;
    FHeaders: TAWSLambda4DHTTPValues;
    FRawQueryString: string;
    FMethod: string;
    FBody: TBytes;
    FIsBase64Encoded: Boolean;
    FQueryParams: TAWSLambda4DHTTPValues;
    FCookies: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;

    function Header(const AName: string): string;
    function HeaderCount(const AName: string): Integer;
    function HeaderValue(const AName: string; const AIndex: Integer): string;
    function QueryParam(const AName: string): string;
    function QueryParamCount(const AName: string): Integer;
    function QueryParamValue(const AName: string; const AIndex: Integer): string;
    function BodyAsString: string;

    property Method: string read FMethod write FMethod;
    property Path: string read FPath write FPath;
    property RawQueryString: string read FRawQueryString write FRawQueryString;
    property Headers: TAWSLambda4DHTTPValues read FHeaders;
    property QueryParams: TAWSLambda4DHTTPValues read FQueryParams;
    property Cookies: TList<string> read FCookies;
    property Body: TBytes read FBody write FBody;
    property IsBase64Encoded: Boolean read FIsBase64Encoded write FIsBase64Encoded;
  end;

  TAWSLambda4DHTTPResponse = class
  private
    FHeaders: TAWSLambda4DHTTPValues;
    FCookies: TList<string>;
    FBody: TBytes;
    FIsBase64Encoded: Boolean;
    FStatusCode: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetBody(const AValue: string);

    property StatusCode: Integer read FStatusCode write FStatusCode;
    property Headers: TAWSLambda4DHTTPValues read FHeaders;
    property Cookies: TList<string> read FCookies;
    property Body: TBytes read FBody write FBody;
    property IsBase64Encoded: Boolean read FIsBase64Encoded write FIsBase64Encoded;
  end;

  IAWSLambda4DHTTPHandler = interface
    ['{4A218098-9557-4D97-85F2-CAA6052FC9B1}']
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  end;

  TAWSLambda4DHTTPValues = class
  private
    FItems: TDictionary<string, TList<string>>;
  public
    constructor Create(const AIgnoreCase: Boolean = False);
    destructor Destroy; override;

    procedure Add(const AName, AValue: string);
    procedure SetValue(const AName, AValue: string);
    procedure Clear;
    function Contains(const AName: string): Boolean;
    function ValueCount(const AName: string): Integer;
    function Value(const AName: string; const AIndex: Integer = 0): string;
    function First(const AName: string): string;
    function Names: TArray<string>;
  end;

implementation

uses
  System.Generics.Defaults;

{ TAWSLambda4DHTTPResponse }

constructor TAWSLambda4DHTTPResponse.Create;
begin
  FHeaders := TAWSLambda4DHTTPValues.Create(True);
  FCookies := TList<string>.Create;
  FStatusCode := 200;
end;

destructor TAWSLambda4DHTTPResponse.Destroy;
begin
  FHeaders.Free;
  inherited;
end;

procedure TAWSLambda4DHTTPResponse.SetBody(const AValue: string);
begin
  FBody := TEncoding.UTF8.GetBytes(AValue);
end;

{ TAWSLambda4DHTTPRequest }

function TAWSLambda4DHTTPRequest.BodyAsString: string;
begin
  Result := TEncoding.UTF8.GetString(FBody);
end;

constructor TAWSLambda4DHTTPRequest.Create;
begin
  FHeaders := TAWSLambda4DHTTPValues.Create(True);
  FQueryParams := TAWSLambda4DHTTPValues.Create(False);
  FCookies := TList<string>.Create;
end;

destructor TAWSLambda4DHTTPRequest.Destroy;
begin
  FHeaders.Free;
  FQueryParams.Free;
  FCookies.Free;
  inherited;
end;

function TAWSLambda4DHTTPRequest.Header(const AName: string): string;
begin
  Result := FHeaders.First(AName);
end;

function TAWSLambda4DHTTPRequest.HeaderCount(const AName: string): Integer;
begin
  Result := FHeaders.ValueCount(AName);
end;

function TAWSLambda4DHTTPRequest.HeaderValue(const AName: string; const AIndex: Integer): string;
begin
  Result := FHeaders.Value(AName, AIndex);
end;

function TAWSLambda4DHTTPRequest.QueryParam(const AName: string): string;
begin
  Result := FQueryParams.First(AName);
end;

function TAWSLambda4DHTTPRequest.QueryParamCount(const AName: string): Integer;
begin
  Result := FQueryParams.ValueCount(AName);
end;

function TAWSLambda4DHTTPRequest.QueryParamValue(const AName: string; const AIndex: Integer): string;
begin
  Result := FQueryParams.Value(AName, AIndex);
end;

{ TAWSLambda4DHTTPValues }

procedure TAWSLambda4DHTTPValues.Add(const AName, AValue: string);
var
  LValues: TList<string>;
begin
  if not FItems.TryGetValue(AName, LValues) then
  begin
    LValues := TList<string>.Create;
    FItems.Add(AName, LValues);
  end;

  LValues.Add(AValue);
end;

procedure TAWSLambda4DHTTPValues.Clear;
var
  LValues: TList<string>;
begin
  for LValues in FItems.Values do
    LValues.Free;
  FItems.Clear;
end;

function TAWSLambda4DHTTPValues.Contains(const AName: string): Boolean;
begin
  Result := FItems.ContainsKey(AName);
end;

constructor TAWSLambda4DHTTPValues.Create(const AIgnoreCase: Boolean);
begin
  inherited Create;
  FItems := TDictionary<string, TList<string>>.Create(TStringComparer.Ordinal);
end;

destructor TAWSLambda4DHTTPValues.Destroy;
begin
  Clear;
  FItems.Free;
  inherited;
end;

function TAWSLambda4DHTTPValues.First(const AName: string): string;
begin
  Result := Value(AName, 0);
end;

function TAWSLambda4DHTTPValues.Names: TArray<string>;
var
  LPair: TPair<string, TList<string>>;
  LIndex: Integer;
begin
  SetLength(Result, FItems.Count);

  LIndex := 0;

  for LPair in FItems do
  begin
    Result[LIndex] := LPair.Key;
    Inc(LIndex);
  end;
end;

procedure TAWSLambda4DHTTPValues.SetValue(const AName, AValue: string);
var
  LValues: TList<string>;
begin
  if FItems.TryGetValue(AName, LValues) then
    LValues.Clear
  else
  begin
    LValues := TList<string>.Create;
    FItems.Add(AName, LValues);
  end;

  LValues.Add(AValue);
end;

function TAWSLambda4DHTTPValues.Value(const AName: string; const AIndex: Integer): string;
var
  LValues: TList<string>;
begin
  Result := '';

  if not FItems.TryGetValue(AName, LValues) then
    Exit;

  if (AIndex < 0) or (AIndex >= LValues.Count) then
    Exit;

  Result := LValues[AIndex];
end;

function TAWSLambda4DHTTPValues.ValueCount(const AName: string): Integer;
var
  LValues: TList<string>;
begin
  Result := 0;
  if FItems.TryGetValue(AName, LValues) then
    Result := LValues.Count;
end;

end.
