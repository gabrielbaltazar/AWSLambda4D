unit AWSLambda4D.HTTP.Types;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TAWSLambda4DHttpPayloadVersion = (hpvUnknown, hpvV1, hpvV2);

  TAWSLambda4DHTTPRequest = class
  private
    FPath: string;
    FHeaders: TDictionary<string, string>;
    FMethod: string;
    FBody: TBytes;
    FIsBase64Encoded: Boolean;
    FQueryParams: TDictionary<string, string>;
    FCookies: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;

    function Header(const AName: string): string;
    function QueryParam(const AName: string): string;
    function BodyAsString: string;

    property Method: string read FMethod write FMethod;
    property Path: string read FPath write FPath;
    property Headers: TDictionary<string, string> read FHeaders;
    property QueryParams: TDictionary<string, string> read FQueryParams;
    property Cookies: TList<string> read FCookies;
    property Body: TBytes read FBody write FBody;
    property IsBase64Encoded: Boolean read FIsBase64Encoded write FIsBase64Encoded;
  end;

  TAWSLambda4DHTTPResponse = class
  private
    FHeaders: TDictionary<string, string>;
    FCookies: TList<string>;
    FBody: TBytes;
    FIsBase64Encoded: Boolean;
    FStatusCode: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetBody(const AValue: string);

    property StatusCode: Integer read FStatusCode write FStatusCode;
    property Headers: TDictionary<string, string> read FHeaders;
    property Cookies: TList<string> read FCookies;
    property Body: TBytes read FBody write FBody;
    property IsBase64Encoded: Boolean read FIsBase64Encoded write FIsBase64Encoded;
  end;

  IAWSLambda4DHTTPHandler = interface
    ['{4A218098-9557-4D97-85F2-CAA6052FC9B1}']
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  end;

implementation

uses
  System.Generics.Defaults;

{ TAWSLambda4DHTTPResponse }

constructor TAWSLambda4DHTTPResponse.Create;
begin
  FHeaders := TDictionary<string, string>.Create;
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
  FHeaders := TDictionary<string, string>.Create(TStringComparer.Ordinal);
  FQueryParams := TDictionary<string, string>.Create(TStringComparer.Ordinal);
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
  if not FHeaders.TryGetValue(AName, Result) then
    Result := '';
end;

function TAWSLambda4DHTTPRequest.QueryParam(const AName: string): string;
begin
  if not FQueryParams.TryGetValue(AName, Result) then
    Result := '';
end;

end.
