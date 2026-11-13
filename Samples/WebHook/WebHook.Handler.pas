unit WebHook.Handler;

interface

uses
  AWSLambda4D;

type
  // POST /hook
  // Body: {"urlHook": "https://...", "content": { ... } | [ ... ]}
  // Dispara um POST com o "content" para a "urlHook".
  //   - sucesso: 204 sem corpo;
  //   - falha ao chamar a urlHook (rede ou status diferente de 2xx): 500 com {"error": "mensagem"};
  //   - body invalido (JSON malformado, sem urlHook ou sem content object/array): 400 com {"error": "mensagem"}.
  TWebHookHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  private
    function ErrorResponse(const AStatusCode: Integer; const AMessage: string): TAWSLambda4DHTTPResponse;
    procedure PostContent(const AUrl: string; const AContent: string);
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  public
    class function New: IAWSLambda4DHTTPHandler;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient;

const
  CConnectionTimeoutMs = 5000;
  CResponseTimeoutMs = 15000;

{ TWebHookHandler }

class function TWebHookHandler.New: IAWSLambda4DHTTPHandler;
begin
  Result := Self.Create;
end;

function TWebHookHandler.ErrorResponse(const AStatusCode: Integer; const AMessage: string): TAWSLambda4DHTTPResponse;
var
  LJSON: TJSONObject;
begin
  Result := TAWSLambda4DHTTPResponse.Create;
  Result.StatusCode := AStatusCode;
  Result.Headers.Add('content-type', 'application/json; charset=utf-8');

  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('error', AMessage);
    Result.SetBody(LJSON.ToJSON);
  finally
    LJSON.Free;
  end;
end;

procedure TWebHookHandler.PostContent(const AUrl: string; const AContent: string);
var
  LClient: THTTPClient;
  LBody: TStringStream;
  LResponse: IHTTPResponse;
begin
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := CConnectionTimeoutMs;
    LClient.ResponseTimeout := CResponseTimeoutMs;

    LBody := TStringStream.Create(AContent, TEncoding.UTF8);
    try
      LResponse := LClient.Post(AUrl, LBody, nil,
        TNetHeaders.Create(TNetHeader.Create('Content-Type', 'application/json')));
    finally
      LBody.Free;
    end;

    if (LResponse.StatusCode < 200) or (LResponse.StatusCode > 299) then
      raise Exception.CreateFmt('The webhook returned HTTP %d %s.', [LResponse.StatusCode, LResponse.StatusText]);
  finally
    LClient.Free;
  end;
end;

function TWebHookHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LRoot: TJSONValue;
  LUrl: string;
  LContent: TJSONValue;
begin
  LRoot := TJSONObject.ParseJSONValue(ARequest.BodyAsString);
  try
    if not (LRoot is TJSONObject) then
      Exit(ErrorResponse(400, 'The request body must be a JSON object.'));

    if not LRoot.TryGetValue<string>('urlHook', LUrl) or LUrl.Trim.IsEmpty then
      Exit(ErrorResponse(400, 'The field "urlHook" is required.'));

    LContent := LRoot.FindValue('content');
    if not ((LContent is TJSONObject) or (LContent is TJSONArray)) then
      Exit(ErrorResponse(400, 'The field "content" must be a JSON object or a JSON array.'));

    try
      PostContent(LUrl, LContent.ToJSON);
    except
      on E: Exception do
        Exit(ErrorResponse(500, E.Message));
    end;

    Result := TAWSLambda4DHTTPResponse.Create;
    Result.StatusCode := 204;
  finally
    LRoot.Free;
  end;
end;

end.
