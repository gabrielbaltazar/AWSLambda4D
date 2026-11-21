unit APIHTTPCrud.Controller;

interface

uses
  System.SysUtils,
  System.JSON,
  AWSLambda4D,
  APIHTTPCrud.Customer;

type
  // Endpoints do CRUD de clientes. Todos respondem JSON:
  //   GET    /customers        200  lista de clientes
  //   GET    /customers/:id    200  cliente | 404
  //   POST   /customers        201  cliente criado (+ cabecalho location) | 400
  //   PUT    /customers/:id    200  cliente atualizado | 400 | 404
  //   DELETE /customers/:id    200  {"id":N,"deleted":true} | 404
  // Erros: {"error":"mensagem"} com 400 (dados invalidos), 404 (nao encontrado).
  TCustomerController = class
  private
    FRepository: TCustomerRepository;

    // Escreve o JSON no response e o libera.
    procedure WriteJSON(const AResponse: TAWSLambda4DHTTPResponse; const AStatusCode: Integer;
      const AValue: TJSONValue);
    procedure WriteError(const AResponse: TAWSLambda4DHTTPResponse; const AStatusCode: Integer;
      const AMessage: string);
    function TryReadId(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
      out AId: Integer): Boolean;
    function TryReadBody(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
      out AName: string; out ABirthdayDate: TDate; out ADocument: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure List(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse);
    procedure Find(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse);
    procedure Insert(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse);
    procedure Update(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse);
    procedure Delete(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse);
  end;

implementation

uses
  System.DateUtils;

{ TCustomerController }

constructor TCustomerController.Create;
begin
  FRepository := TCustomerRepository.Create;
end;

procedure TCustomerController.WriteJSON(const AResponse: TAWSLambda4DHTTPResponse; const AStatusCode: Integer;
  const AValue: TJSONValue);
begin
  try
    AResponse.StatusCode := AStatusCode;
    AResponse.Headers.SetValue('content-type', 'application/json; charset=utf-8');
    AResponse.SetBody(AValue.ToJSON);
  finally
    AValue.Free;
  end;
end;

procedure TCustomerController.WriteError(const AResponse: TAWSLambda4DHTTPResponse; const AStatusCode: Integer;
  const AMessage: string);
var
  LJSON: TJSONObject;
begin
  LJSON := TJSONObject.Create;
  LJSON.AddPair('error', AMessage);
  WriteJSON(AResponse, AStatusCode, LJSON);
end;

function TCustomerController.TryReadId(const ARequest: TAWSLambda4DHTTPRequest;
  const AResponse: TAWSLambda4DHTTPResponse; out AId: Integer): Boolean;
begin
  Result := ARequest.PathParams.Field('id').TryAsInteger(AId);
  if not Result then
    WriteError(AResponse, 400, 'The "id" must be an integer.');
end;

function TCustomerController.TryReadBody(const ARequest: TAWSLambda4DHTTPRequest;
  const AResponse: TAWSLambda4DHTTPResponse; out AName: string; out ABirthdayDate: TDate;
  out ADocument: string): Boolean;
var
  LRoot: TJSONValue;
  LBirthday: string;
  LDateTime: TDateTime;
begin
  Result := False;
  AName := '';
  ADocument := '';
  ABirthdayDate := 0;

  LRoot := TJSONObject.ParseJSONValue(ARequest.BodyAsString);
  try
    if not (LRoot is TJSONObject) then
      WriteError(AResponse, 400, 'The request body must be a JSON object.')
    else if not LRoot.TryGetValue<string>('name', AName) or AName.Trim.IsEmpty then
      WriteError(AResponse, 400, 'The field "name" is required.')
    else if not LRoot.TryGetValue<string>('document', ADocument) or ADocument.Trim.IsEmpty then
      WriteError(AResponse, 400, 'The field "document" is required.')
    else if not LRoot.TryGetValue<string>('birthdayDate', LBirthday) or
      not TryISO8601ToDate(LBirthday, LDateTime, True) then
      WriteError(AResponse, 400, 'The field "birthdayDate" is required and must be a date like 1990-05-21.')
    else
    begin
      ABirthdayDate := DateOf(LDateTime);
      Result := True;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TCustomerController.List(const ARequest: TAWSLambda4DHTTPRequest;
  const AResponse: TAWSLambda4DHTTPResponse);
var
  LArray: TJSONArray;
  LCustomer: TCustomer;
begin
  LArray := TJSONArray.Create;
  for LCustomer in FRepository.List do
    LArray.AddElement(LCustomer.ToJSON);

  WriteJSON(AResponse, 200, LArray);
end;

procedure TCustomerController.Find(const ARequest: TAWSLambda4DHTTPRequest;
  const AResponse: TAWSLambda4DHTTPResponse);
var
  LId: Integer;
  LCustomer: TCustomer;
begin
  if not TryReadId(ARequest, AResponse, LId) then
    Exit;

  LCustomer := FRepository.Find(LId);
  if LCustomer = nil then
    WriteError(AResponse, 404, Format('Customer %d not found.', [LId]))
  else
    WriteJSON(AResponse, 200, LCustomer.ToJSON);
end;

procedure TCustomerController.Insert(const ARequest: TAWSLambda4DHTTPRequest;
  const AResponse: TAWSLambda4DHTTPResponse);
var
  LName: string;
  LBirthdayDate: TDate;
  LDocument: string;
  LCustomer: TCustomer;
begin
  if not TryReadBody(ARequest, AResponse, LName, LBirthdayDate, LDocument) then
    Exit;

  LCustomer := FRepository.Insert(LName, LBirthdayDate, LDocument);
  AResponse.Headers.SetValue('location', '/customers/' + IntToStr(LCustomer.Id));
  WriteJSON(AResponse, 201, LCustomer.ToJSON);
end;

procedure TCustomerController.Update(const ARequest: TAWSLambda4DHTTPRequest;
  const AResponse: TAWSLambda4DHTTPResponse);
var
  LId: Integer;
  LName: string;
  LBirthdayDate: TDate;
  LDocument: string;
  LCustomer: TCustomer;
begin
  if not TryReadId(ARequest, AResponse, LId) then
    Exit;

  if not TryReadBody(ARequest, AResponse, LName, LBirthdayDate, LDocument) then
    Exit;

  LCustomer := FRepository.Update(LId, LName, LBirthdayDate, LDocument);
  if LCustomer = nil then
    WriteError(AResponse, 404, Format('Customer %d not found.', [LId]))
  else
    WriteJSON(AResponse, 200, LCustomer.ToJSON);
end;

procedure TCustomerController.Delete(const ARequest: TAWSLambda4DHTTPRequest;
  const AResponse: TAWSLambda4DHTTPResponse);
var
  LId: Integer;
  LJSON: TJSONObject;
begin
  if not TryReadId(ARequest, AResponse, LId) then
    Exit;

  if not FRepository.Remove(LId) then
  begin
    WriteError(AResponse, 404, Format('Customer %d not found.', [LId]));
    Exit;
  end;

  // 200 com corpo JSON (um 204 nao teria corpo).
  LJSON := TJSONObject.Create;
  LJSON.AddPair('id', TJSONNumber.Create(LId));
  LJSON.AddPair('deleted', TJSONBool.Create(True));
  WriteJSON(AResponse, 200, LJSON);
end;

destructor TCustomerController.Destroy;
begin
  FRepository.Free;
  inherited;
end;

end.
