program DescontoLambda;

{$APPTYPE CONSOLE}

{$R *.res}

// Handler que NAO e HTTP: recebe um evento JSON qualquer e devolve outro JSON.
//
// Evento de entrada:  {"valor": 200, "cliente": "vip"}
// Resposta:           {"valor":200.0,"cliente":"vip","descontoPercentual":10,"desconto":20.0,"total":180.0}
//
// Regras: vip = 10%, regular = 5%, qualquer outro cliente = 0%.
// Se o evento for invalido (sem "valor" ou valor negativo) a funcao lanca uma excecao e o
// Lambda registra o erro da funcao ("Function.<ClasseDaExcecao>").

uses
  System.SysUtils,
  System.Math,
  System.JSON,
  AWSLambda4D;

function PercentualDesconto(const ACliente: string): Integer;
begin
  if SameText(ACliente, 'vip') then
    Result := 10
  else if SameText(ACliente, 'regular') then
    Result := 5
  else
    Result := 0;
end;

function CalcularDesconto(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
var
  LEvento: TJSONObject;
  LResultado: TJSONObject;
  LValor: Double;
  LCliente: string;
  LPercentual: Integer;
  LDesconto: Double;
begin
  LEvento := TJSONObject.ParseJSONValue(ARequest.Body) as TJSONObject;
  try
    if LEvento = nil then
      raise EArgumentException.Create('O evento deve ser um JSON object.');

    if not LEvento.TryGetValue<Double>('valor', LValor) then
      raise EArgumentException.Create('O campo "valor" e obrigatorio.');

    if LValor < 0 then
      raise EArgumentException.Create('O campo "valor" nao pode ser negativo.');

    if not LEvento.TryGetValue<string>('cliente', LCliente) then
      LCliente := '';
  finally
    LEvento.Free;
  end;

  LPercentual := PercentualDesconto(LCliente);
  LDesconto := RoundTo(LValor * LPercentual / 100, -2);

  LResultado := TJSONObject.Create;
  try
    LResultado.AddPair('valor', TJSONNumber.Create(LValor));
    LResultado.AddPair('cliente', LCliente);
    LResultado.AddPair('descontoPercentual', TJSONNumber.Create(LPercentual));
    LResultado.AddPair('desconto', TJSONNumber.Create(LDesconto));
    LResultado.AddPair('total', TJSONNumber.Create(RoundTo(LValor - LDesconto, -2)));

    Result := TAWSLambda4DResponse.Create;
    Result.Body := LResultado.ToJSON;
  finally
    LResultado.Free;
  end;
end;

begin
{$IFDEF MSWINDOWS}
  IsConsole := False;
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}

  // Fora da Lambda (AWS_LAMBDA_RUNTIME_API ausente): testa aqui na maquina, com um evento de exemplo.
  // Dentro da Lambda: entra no loop normal e atende as invocacoes.
  if TAWSLambda4Runner.SelfHosted then
    TAWSLambda4Runner.RunLocal(CalcularDesconto, '{"valor":200,"cliente":"vip"}')
  else
    TAWSLambda4Runner.Run(CalcularDesconto);

  System.Readln;
end.
