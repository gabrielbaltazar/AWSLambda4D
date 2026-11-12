unit AWSLambda4D.HTTP.Types;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TAWSLambda4DHttpPayloadVersion = (hpvUnknown, hpvV1, hpvV2);

  TAWSLambda4DHTTPValues = class;

  // Valor de um parametro (path, query, header) com leitura tipada.
  // AsXxx levanta EConvertError se o valor nao existir ou for invalido;
  // AsXxx(ADefault) devolve ADefault nesses casos; TryAsXxx devolve False.
  // Datas e horas seguem o formato ISO 8601 e sao devolvidas em UTC
  // quando o texto informa fuso horario (Z ou +hh:mm).
  TAWSLambda4DHTTPField = record
  private
    FName: string;
    FValue: string;
    FExists: Boolean;
    procedure RaiseConvertError(const ATypeName: string);
  public
    constructor Create(const AName, AValue: string; const AExists: Boolean);

    function Exists: Boolean;

    function AsString: string;

    function TryAsInteger(out AValue: Integer): Boolean;
    function AsInteger: Integer; overload;
    function AsInteger(const ADefault: Integer): Integer; overload;

    function TryAsFloat(out AValue: Double): Boolean;
    function AsFloat: Double; overload;
    function AsFloat(const ADefault: Double): Double; overload;

    function TryAsCurrency(out AValue: Currency): Boolean;
    function AsCurrency: Currency; overload;
    function AsCurrency(const ADefault: Currency): Currency; overload;

    function TryAsDateTime(out AValue: TDateTime): Boolean;
    function AsDateTime: TDateTime; overload;
    function AsDateTime(const ADefault: TDateTime): TDateTime; overload;

    function TryAsDate(out AValue: TDateTime): Boolean;
    function AsDate: TDateTime; overload;
    function AsDate(const ADefault: TDateTime): TDateTime; overload;
  end;

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
    FPathParams: TAWSLambda4DHTTPValues;
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
    property PathParams: TAWSLambda4DHTTPValues read FPathParams;
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

  IAWSLambda4DHTTPRouter = interface(IAWSLambda4DHTTPHandler)
    ['{F3857F4E-BCBD-4EA0-93E9-FD3E708C60D8}']
    function Add(const AMethod: string; const APath: string;
      const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Get(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Post(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Put(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Delete(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
    function Patch(const APath: string; const AHandler: IAWSLambda4DHTTPHandler): IAWSLambda4DHTTPRouter;
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
    function Field(const AName: string; const AIndex: Integer = 0): TAWSLambda4DHTTPField;
    function Names: TArray<string>;
  end;

implementation

uses
  System.Generics.Defaults,
  System.DateUtils;

{ TAWSLambda4DHTTPField }

constructor TAWSLambda4DHTTPField.Create(const AName, AValue: string; const AExists: Boolean);
begin
  FName := AName;
  FValue := AValue;
  FExists := AExists;
end;

procedure TAWSLambda4DHTTPField.RaiseConvertError(const ATypeName: string);
begin
  if not FExists then
    raise EConvertError.CreateFmt('Parameter ''%s'' was not found.', [FName]);

  raise EConvertError.CreateFmt('Parameter ''%s'' has value ''%s'', which is not a valid %s.',
    [FName, FValue, ATypeName]);
end;

function TAWSLambda4DHTTPField.Exists: Boolean;
begin
  Result := FExists;
end;

function TAWSLambda4DHTTPField.AsString: string;
begin
  Result := FValue;
end;

function TAWSLambda4DHTTPField.TryAsInteger(out AValue: Integer): Boolean;
begin
  Result := FExists and TryStrToInt(FValue, AValue);
  if not Result then
    AValue := 0;
end;

function TAWSLambda4DHTTPField.AsInteger: Integer;
begin
  if not TryAsInteger(Result) then
    RaiseConvertError('Integer');
end;

function TAWSLambda4DHTTPField.AsInteger(const ADefault: Integer): Integer;
begin
  if not TryAsInteger(Result) then
    Result := ADefault;
end;

function TAWSLambda4DHTTPField.TryAsFloat(out AValue: Double): Boolean;
begin
  Result := FExists and TryStrToFloat(FValue, AValue, TFormatSettings.Invariant);
  if not Result then
    AValue := 0;
end;

function TAWSLambda4DHTTPField.AsFloat: Double;
begin
  if not TryAsFloat(Result) then
    RaiseConvertError('Float');
end;

function TAWSLambda4DHTTPField.AsFloat(const ADefault: Double): Double;
begin
  if not TryAsFloat(Result) then
    Result := ADefault;
end;

function TAWSLambda4DHTTPField.TryAsCurrency(out AValue: Currency): Boolean;
begin
  Result := FExists and TryStrToCurr(FValue, AValue, TFormatSettings.Invariant);
  if not Result then
    AValue := 0;
end;

function TAWSLambda4DHTTPField.AsCurrency: Currency;
begin
  if not TryAsCurrency(Result) then
    RaiseConvertError('Currency');
end;

function TAWSLambda4DHTTPField.AsCurrency(const ADefault: Currency): Currency;
begin
  if not TryAsCurrency(Result) then
    Result := ADefault;
end;

function TAWSLambda4DHTTPField.TryAsDateTime(out AValue: TDateTime): Boolean;
begin
  Result := FExists and (not FValue.IsEmpty) and TryISO8601ToDate(FValue, AValue, True);
  if not Result then
    AValue := 0;
end;

function TAWSLambda4DHTTPField.AsDateTime: TDateTime;
begin
  if not TryAsDateTime(Result) then
    RaiseConvertError('ISO 8601 date/time');
end;

function TAWSLambda4DHTTPField.AsDateTime(const ADefault: TDateTime): TDateTime;
begin
  if not TryAsDateTime(Result) then
    Result := ADefault;
end;

function TAWSLambda4DHTTPField.TryAsDate(out AValue: TDateTime): Boolean;
begin
  Result := TryAsDateTime(AValue);
  if Result then
    AValue := DateOf(AValue);
end;

function TAWSLambda4DHTTPField.AsDate: TDateTime;
begin
  if not TryAsDate(Result) then
    RaiseConvertError('ISO 8601 date');
end;

function TAWSLambda4DHTTPField.AsDate(const ADefault: TDateTime): TDateTime;
begin
  if not TryAsDate(Result) then
    Result := ADefault;
end;

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
  FPathParams := TAWSLambda4DHTTPValues.Create(False);
  FCookies := TList<string>.Create;
end;

destructor TAWSLambda4DHTTPRequest.Destroy;
begin
  FHeaders.Free;
  FQueryParams.Free;
  FCookies.Free;
  FPathParams.Free;
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

function TAWSLambda4DHTTPValues.Field(const AName: string; const AIndex: Integer): TAWSLambda4DHTTPField;
begin
  Result := TAWSLambda4DHTTPField.Create(AName, Value(AName, AIndex),
    (AIndex >= 0) and (AIndex < ValueCount(AName)));
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
