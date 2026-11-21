unit APIHTTPCrud.Customer;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections;

type
  // Cliente simulado. Campos no JSON: id, name, birthdayDate (yyyy-mm-dd) e document.
  TCustomer = class
  private
    FId: Integer;
    FName: string;
    FBirthdayDate: TDate;
    FDocument: string;
  public
    function ToJSON: TJSONObject;

    property Id: Integer read FId;
    property Name: string read FName write FName;
    property BirthdayDate: TDate read FBirthdayDate write FBirthdayDate;
    property Document: string read FDocument write FDocument;
  end;

  // "Banco de dados" em memoria: os dados duram enquanto o processo viver (na Lambda, enquanto o
  // ambiente de execucao estiver "quente") e nao sao compartilhados entre instancias.
  TCustomerRepository = class
  private
    FItems: TObjectList<TCustomer>;
    FNextId: Integer;

    procedure Seed;
  public
    constructor Create;
    destructor Destroy; override;

    function List: TArray<TCustomer>;
    function Find(const AId: Integer): TCustomer;
    function Insert(const AName: string; const ABirthdayDate: TDate; const ADocument: string): TCustomer;
    // Devolve nil quando o id nao existe.
    function Update(const AId: Integer; const AName: string; const ABirthdayDate: TDate;
      const ADocument: string): TCustomer;
    function Remove(const AId: Integer): Boolean;
  end;

const
  CDateFormat = 'yyyy-mm-dd';

implementation

{ TCustomer }

function TCustomer.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('id', TJSONNumber.Create(FId));
    Result.AddPair('name', FName);
    Result.AddPair('birthdayDate', FormatDateTime(CDateFormat, FBirthdayDate));
    Result.AddPair('document', FDocument);
  except
    Result.Free;
    raise;
  end;
end;

{ TCustomerRepository }

constructor TCustomerRepository.Create;
begin
  inherited Create;
  FItems := TObjectList<TCustomer>.Create(True);
  FNextId := 1;
  Seed;
end;

destructor TCustomerRepository.Destroy;
begin
  FItems.Free;
  inherited;
end;

procedure TCustomerRepository.Seed;
begin
  Insert('Maria Silva', EncodeDate(1985, 3, 12), '123.456.789-09');
  Insert('Joao Souza', EncodeDate(1992, 11, 30), '987.654.321-00');
  Insert('Ana Pereira', EncodeDate(1978, 7, 4), '111.222.333-44');
end;

function TCustomerRepository.List: TArray<TCustomer>;
begin
  Result := FItems.ToArray;
end;

function TCustomerRepository.Find(const AId: Integer): TCustomer;
var
  LCustomer: TCustomer;
begin
  for LCustomer in FItems do
    if LCustomer.Id = AId then
      Exit(LCustomer);

  Result := nil;
end;

function TCustomerRepository.Insert(const AName: string; const ABirthdayDate: TDate;
  const ADocument: string): TCustomer;
begin
  Result := TCustomer.Create;
  Result.FId := FNextId;
  Result.Name := AName;
  Result.BirthdayDate := ABirthdayDate;
  Result.Document := ADocument;

  FItems.Add(Result);
  Inc(FNextId);
end;

function TCustomerRepository.Update(const AId: Integer; const AName: string; const ABirthdayDate: TDate;
  const ADocument: string): TCustomer;
begin
  Result := Find(AId);
  if Result = nil then
    Exit;

  Result.Name := AName;
  Result.BirthdayDate := ABirthdayDate;
  Result.Document := ADocument;
end;

function TCustomerRepository.Remove(const AId: Integer): Boolean;
var
  LCustomer: TCustomer;
begin
  LCustomer := Find(AId);
  Result := LCustomer <> nil;
  if Result then
    FItems.Remove(LCustomer);
end;

end.
