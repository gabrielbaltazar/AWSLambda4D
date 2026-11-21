<p align="center">
  <img src="Images/logo.png" alt="AWSLambda4D" width="420">
</p>

# AWSLambda4D

[English](README.md) | **Português**

**AWSLambda4D é uma biblioteca para rodar funções Delphi nativas dentro do AWS Lambda.**

Ela implementa a [Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html) para que um
executável Delphi (compilado para Linux 64 bits e chamado `bootstrap`) rode como um *custom runtime* do AWS Lambda. Você
escreve a função em Delphi, sem interpretador e sem precisar de imagem de container, e a biblioteca cuida do ciclo
buscar evento → executar → responder que o Lambda espera.

- Handlers simples para qualquer evento do Lambda (JSON na entrada, JSON na saída).
- Uma camada HTTP tipada para o API Gateway (HTTP API v2 e REST API v1) e para Lambda Function URLs.
- Um router enxuto com parâmetros de rota (`/users/:id`) e leitura tipada de parâmetros (`AsInteger`, `AsDateTime`, ...).
- Funções anônimas **ou** classes para os seus handlers, como preferir.
- O mesmo executável roda na sua máquina (Windows ou Linux) contra um servidor local embutido, para você testar a
  função antes de subir.

## Sumário

- [Como funciona](#como-funciona)
- [Qual interface de handler devo usar?](#qual-interface-de-handler-devo-usar)
- [Exemplos](#exemplos)
  - [HelloLambda: um handler simples](#hellolambda-um-handler-simples)
  - [APIHTTPLambda: um handler HTTP](#apihttplambda-um-handler-http)
  - [APIHTTPRouterLambda: um router](#apihttprouterlambda-um-router)
- [Lendo dados da requisição com tipos](#lendo-dados-da-requisição-com-tipos)
- [Rodando localmente antes de subir](#rodando-localmente-antes-de-subir)
- [Compilando e publicando](#compilando-e-publicando)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Testes](#testes)

## Como funciona

Um custom runtime do Lambda é só um programa que conversa por HTTP com um endpoint publicado pela AWS na variável de
ambiente `AWS_LAMBDA_RUNTIME_API`. A cada invocação ele precisa:

1. `GET  /2018-06-01/runtime/invocation/next` para receber o evento (e cabeçalhos como o id da requisição);
2. executar o seu código;
3. `POST /2018-06-01/runtime/invocation/{id}/response` com o resultado, ou `.../error` se houve falha.

O AWSLambda4D implementa esse ciclo:

```
                +------------------------- seu executável (bootstrap) --------------------------+
                |                                                                                |
 AWS Lambda <---+--> TAWSLambda4DRuntimeAPI <--> TAWSLambda4DRuntime <--> seu handler           |
 (Runtime API)  |       (cliente HTTP)              (o loop)             IAWSLambda4DHandler     |
                |                                                        ou, por cima dele,      |
                |                                                        IAWSLambda4DHTTPHandler |
                +--------------------------------------------------------------------------------+
```

- `TAWSLambda4DRunner` (unit `AWSLambda4D.Runner`) é o ponto de entrada do seu programa. `Run` inicia o loop.
- Se o seu handler lançar uma exceção, o runtime a informa ao Lambda como erro da função
  (`Function.<ClasseDaExceção>`) e continua atendendo a próxima invocação.
- Em eventos HTTP, o `TAWSLambda4DHTTPAdapter` fica entre o runtime e o seu código: ele converte o JSON do API Gateway
  em uma requisição tipada, chama o seu handler HTTP e serializa a resposta no formato que o API Gateway espera.
- O runtime é dono dos objetos de requisição, resposta e contexto de cada invocação e os libera para você. O seu
  handler cria e devolve uma **nova** resposta e não deve liberar a requisição nem o contexto.

Basta incluir a unit `AWSLambda4D` no `uses` para ter os principais tipos.

## Qual interface de handler devo usar?

Existem dois níveis. Os dois podem ser implementados como classe **ou** passados como função anônima.

| | `IAWSLambda4DHandler` | `IAWSLambda4DHTTPHandler` |
|---|---|---|
| Método | `Handle(ARequest, AContext): TAWSLambda4DResponse` | `Execute(ARequest): TAWSLambda4DHTTPResponse` |
| Tipo da função anônima | `TAWSLambda4DHandlerProc` | `TAWSLambda4DHTTPHandlerProc` |
| Entrada | O evento bruto como string JSON (`ARequest.Body`) mais o contexto do Lambda (`AContext`: id da requisição, ARN da função, prazo, trace id) | Uma requisição HTTP já interpretada: método, caminho, parâmetros de rota e de query, cabeçalhos, cookies, corpo |
| Saída | Uma string bruta (`Result.Body`) que o Lambda devolve como resultado da função | Uma resposta HTTP: status, cabeçalhos, cookies, corpo |
| Formatos de evento | Qualquer um: invocação direta, SQS, SNS, S3, EventBridge, um payload próprio... | Eventos HTTP do API Gateway (HTTP API v2, REST API v1) e de Lambda Function URLs |
| Leitura do evento | Você faz o parse do JSON | Já feito; suporta payload v1 e v2 |
| Erros | Uma exceção vira erro da função no Lambda | Uma exceção vira HTTP `500 Internal Server Error`; um parâmetro tipado inválido vira `400` com a mensagem da conversão |
| Como executar | `TAWSLambda4DRunner.Run(handler)` | `TAWSLambda4DRunner.Run(httpHandler)` (o adapter é incluído para você) |

**Use `IAWSLambda4DHandler` quando** a função *não* é um endpoint HTTP: ela reage a mensagens de fila, upload de
arquivos, agendamentos ou invocações diretas, ou quando você precisa de controle total sobre o evento bruto e o
contexto do Lambda.

**Use `IAWSLambda4DHTTPHandler` quando** a função fica atrás de um API Gateway ou de uma Function URL e você está
construindo uma API web. Você trabalha com `Method`, `Path`, `PathParams`, `QueryParams`, `Headers` e `StatusCode` em
vez de interpretar na mão o JSON do gateway. Com várias rotas, use o router (`IAWSLambda4DHTTPRouter`), que também é
um `IAWSLambda4DHTTPHandler`.

## Exemplos

Os três exemplos estão em `Samples/`. Eles também mostram como rodar o mesmo código localmente (veja
[Rodando localmente antes de subir](#rodando-localmente-antes-de-subir)).

### HelloLambda: um handler simples

**Com função anônima** (`Samples/HelloLambda/HelloLambda.dpr`):

```pascal
program HelloLambda;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AWSLambda4D;

function HelloWorld(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
begin
  Result := TAWSLambda4DResponse.Create;
  System.Writeln(ARequest.Body);                 // o evento bruto
  Result.Body := '{"message":"hello"}';
end;

begin
  if TAWSLambda4DRunner.SelfHosted then
    TAWSLambda4DRunner.RunLocal(HelloWorld, '{"name":"Gabriel"}')   // na sua máquina
  else
    TAWSLambda4DRunner.Run(HelloWorld);                             // no AWS Lambda
end.
```

`HelloWorld` pode ser uma função comum (como acima) ou um `function(...) begin ... end` escrito direto na chamada de
`Run`; os dois são um `TAWSLambda4DHandlerProc`.

**Com classe de handler** (`Samples/HelloLambda/HelloLambda.Handle.pas`):

```pascal
type
  THelloLambdaHandle = class(TInterfacedObject, IAWSLambda4DHandler)
  protected
    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  public
    class function New: IAWSLambda4DHandler;
  end;

function THelloLambdaHandle.Handle(const ARequest: TAWSLambda4DRequest;
  const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
var
  LJSON: TJSONObject;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('timezone', 'UTC');
    LJSON.AddPair('awsRequestId', AContext.AwsRequestId);   // contexto do Lambda
    LJSON.AddPair('functionArn', AContext.FunctionArn);
    Result := TAWSLambda4DResponse.Create;
    Result.Body := LJSON.ToJSON;
  finally
    LJSON.Free;
  end;
end;

class function THelloLambdaHandle.New: IAWSLambda4DHandler;
begin
  Result := Self.Create;
end;
```

e no `.dpr`:

```pascal
TAWSLambda4DRunner.Run(THelloLambdaHandle.New);
```

Prefira a classe quando o handler tem dependências, estado, ou código suficiente para merecer uma unit própria e
testes unitários.

#### O request e o contexto

Um `TAWSLambda4DHandlerProc` (ou `IAWSLambda4DHandler.Handle`) recebe dois objetos. Resumindo: use o **request** para
decidir *o que* processar, e o **contexto** para *registrar, rastrear e controlar o tempo*.

| | `TAWSLambda4DRequest` | `TAWSLambda4DContext` |
|---|---|---|
| O que é | O evento que disparou a função | Metadados da invocação, fornecidos pelo Lambda |
| De onde vem | Do corpo da resposta da Runtime API | Dos cabeçalhos dessa mesma resposta |
| Muda conforme | Quem chamou a função (S3, fila, agendamento, invocação direta) | Cada execução |
| Campos | `Body`, `RequestId` | `AwsRequestId`, `InvocationId`, `FunctionArn`, `TraceId`, `DeadlineMs` |

**`TAWSLambda4DRequest`** é a sua entrada de negócio:

- `Body` é o evento como string JSON. Você mesmo faz o parse (por exemplo com `System.JSON`).
- `RequestId` repete o `AwsRequestId` do contexto.

**`TAWSLambda4DContext`** não faz parte dos dados de entrada; ele responde "quem, onde e até quando":

- `AwsRequestId`: id único da invocação. Escreva-o nas linhas de log para achar tudo de uma execução no CloudWatch.
- `InvocationId`: identificador da invocação informado pela Runtime API.
- `FunctionArn`: a função que está rodando (nome, conta, região e alias podem ser extraídos dele).
- `TraceId`: id de rastreamento (X-Ray), para propagar a outros serviços.
- `DeadlineMs`: o instante em que a execução será interrompida, em milissegundos desde 1970 (UTC).

```pascal
function Processar(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
var
  LRestanteMs: Int64;
begin
  Writeln('[', AContext.AwsRequestId, '] evento: ', ARequest.Body);

  // Quanto tempo falta antes de o Lambda interromper a função
  LRestanteMs := AContext.DeadlineMs - DateTimeToUnix(Now, False) * 1000;   // System.DateUtils
  if LRestanteMs < 2000 then
    raise Exception.Create('Sem tempo suficiente para processar o evento.');

  Result := TAWSLambda4DResponse.Create;      // a função devolve um NOVO response
  Result.Body := '{"ok":true}';
end;
```

O runtime é dono do request, do contexto e do response de cada invocação e os libera para você; a função apenas devolve
um novo `TAWSLambda4DResponse` (o `Body` dele é o resultado da função) e não deve liberar os dois parâmetros.

Os handlers HTTP (`IAWSLambda4DHTTPHandler`) recebem só o `TAWSLambda4DHTTPRequest`; o contexto do Lambda não é repassado
a eles.

### APIHTTPLambda: um handler HTTP

Um único `IAWSLambda4DHTTPHandler` responde a todas as requisições, seja qual for o caminho.

**Com classe de handler** (`Samples/APIHTTPLambda`):

```pascal
type
  TAPIHTTPHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  public
    class function New: IAWSLambda4DHTTPHandler;
  end;

function TAPIHTTPHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LJSON: TJSONObject;
begin
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('timezone', 'UTC');
    Result := TAWSLambda4DHTTPResponse.Create;
    Result.StatusCode := 201;
    Result.Headers.Add('content-type', 'application/json; charset=utf-8');
    Result.SetBody(LJSON.ToJSON);
  finally
    LJSON.Free;
  end;
end;
```

```pascal
var
  LHttpHandler: IAWSLambda4DHTTPHandler;
begin
  LHttpHandler := TAPIHTTPHandler.Create;
  TAWSLambda4DRunner.Run(LHttpHandler);
end.
```

**Com função anônima** (`TAWSLambda4DHTTPHandlerProc`):

```pascal
TAWSLambda4DRunner.Run(
  procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
  begin
    AResponse.StatusCode := 201;
    AResponse.Headers.Add('content-type', 'application/json; charset=utf-8');
    AResponse.SetBody('{"timezone":"UTC"}');
  end);
```

A função anônima HTTP é uma **procedure**: a biblioteca cria o objeto `AResponse` para você (status `200` por padrão) e
você só o preenche; não há nada para criar nem devolver. Se a procedure lançar uma exceção, o response é liberado e a
exceção segue o tratamento HTTP habitual. (O `TAWSLambda4DHandlerProc`, que não é HTTP, é diferente: é uma função que
devolve um novo `TAWSLambda4DResponse`.)

O `RunLocal` aceita a mesma procedure nas execuções locais, com uma string de evento ou com o builder de payload.

### APIHTTPRouterLambda: um router

O router despacha pelo método HTTP e pelo caminho. Cada rota recebe um `IAWSLambda4DHTTPHandler` (uma classe) ou uma
função anônima.

**Com funções anônimas** (`Samples/APIHTTPRouterLambda/APIHTTPRouterLambda.dpr`):

```pascal
var
  LRouter: IAWSLambda4DHTTPRouter;
begin
  LRouter := TAWSLambda4DHTTPRouter.New;
  LRouter.Get('ping',
    procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
    begin
      AResponse.StatusCode := 200;
      AResponse.SetBody('{"message":"pong"}');
    end);

  if TAWSLambda4DRunner.SelfHosted then
    TAWSLambda4DRunner.RunLocal(LRouter,
      TAWSLambda4DHTTPPayloadV2.New
        .RawPath('/ping')
        .RequestContext.HTTP
          .Method('GET').Path('/ping').&End.&End)
  else
    TAWSLambda4DRunner.Run(LRouter);
end.
```

**Com classes de handler** (`Samples/APIHTTPRouterLambda/Ping.Handler.pas`), misturando os dois estilos e usando
parâmetros de rota:

```pascal
type
  TPingHandler = class(TInterfacedObject, IAWSLambda4DHTTPHandler)
  protected
    function Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
  public
    class function New: IAWSLambda4DHTTPHandler;
  end;

function TPingHandler.Execute(const ARequest: TAWSLambda4DHTTPRequest): TAWSLambda4DHTTPResponse;
var
  LId: string;
  LNumero: Integer;
begin
  LId := ARequest.PathParams.Field('id').AsString;
  LNumero := ARequest.PathParams.Field('numero').AsInteger;   // tipado; 400 se não for inteiro
  Result := TAWSLambda4DHTTPResponse.Create;
  Result.StatusCode := 200;
  Result.SetBody(Format('{"message":"pong %s %d"}', [LId, LNumero]));
end;
```

```pascal
LRouter
  .Get('/ping', procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
    begin
      AResponse.SetBody('{"message":"pong"}');
    end)
  .Get('/ping/:id/:numero', TPingHandler.New);
```

Comportamento do router:

- Métodos: `Get`, `Post`, `Put`, `Delete`, `Patch` e `Add('OPTIONS', ...)` para qualquer outro método. As chamadas podem ser encadeadas.
- Segmentos que começam com `:` são parâmetros de rota, lidos com `ARequest.PathParams.Field('nome')`.
- A comparação de método e caminho **não diferencia maiúsculas de minúsculas** (`/PING` casa com `/ping`); os valores
  dos parâmetros mantêm a caixa original. A barra final é ignorada.
- Quando várias rotas casam, vence a que tem mais segmentos estáticos (`/users/me` vence `/users/:id`).
- Sem rota para o caminho, responde `404 Not Found`; com rota para o caminho mas em outro método, responde `405 Method Not Allowed`.
- Registrar o mesmo método e caminho duas vezes lança uma exceção.

> **Atenção:** passar um construtor sem parênteses, como em `LRouter.Get('/x', TMeuHandler.Create)`, é ambíguo entre a
> sobrecarga de classe e a de função. Escreva `TMeuHandler.Create()` ou use uma `class function New` que devolve a
> interface, como nos exemplos.

### Sem criar um router: `TAWSLambda4D`

Se você não quer criar e guardar uma variável de router, use a classe estática `TAWSLambda4D` (no estilo do framework
[Horse](https://github.com/HashLoad/horse)). Cada chamada registra uma rota em um único router do processo e devolve a
própria classe, então as chamadas podem ser encadeadas:

```pascal
uses
  AWSLambda4D;

begin
  TAWSLambda4D
    .Get('/ping', procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        AResponse.SetBody('{"message":"pong"}');
      end)
    .Post('/ping', TPingPostHandler.New)          // classes também funcionam
    .Run;                                         // no AWS Lambda
end.
```

Para simular uma requisição na sua máquina, termine o encadeamento com `RunLocal` e o builder de payload (ou uma
string de evento):

```pascal
TAWSLambda4D
  .Get('/ping', LHandler1)
  .Post('/ping', LHandler2)
  .RunLocal(TAWSLambda4DHTTPPayloadV2.New
    .RawPath('/ping')
    .RequestContext.HTTP.Method('POST').Path('/ping').&End.&End);
```

`Get`, `Post`, `Put`, `Delete`, `Patch` e `Add(método, caminho, ...)` recebem um `IAWSLambda4DHTTPHandler` ou uma
função anônima e se comportam como os métodos do router acima. `TAWSLambda4D.Router` devolve o router interno e
`TAWSLambda4D.Reset` descarta as rotas registradas (útil em testes). Dentro do Lambda, `RunLocal` se comporta como `Run`.

### Middlewares

Um middleware roda **antes e/ou depois** da rota, como no Horse e em outros frameworks HTTP. Registre-o com `Use` (na
`TAWSLambda4D` ou em um router); ele recebe a requisição, a resposta e uma procedure `ANext` que executa o próximo passo
da cadeia (o próximo middleware e, no fim, a rota):

```pascal
TAWSLambda4D
  .Use(
    procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
      const ANext: TProc)
    begin
      Writeln('-> ', ARequest.Method, ' ', ARequest.Path);      // antes da rota
      ANext();                                                  // executa a rota
      AResponse.Headers.Add('access-control-allow-origin', '*'); // depois da rota
    end)
  .Get('/ping', LPingHandler)
  .Run;
```

- Os middlewares rodam na ordem em que foram registrados: com `Use(A).Use(B)` a ordem é `A antes, B antes, rota,
  B depois, A depois`.
- **Não chamar `ANext`** interrompe a cadeia: a rota não é executada e o `AResponse` do próprio middleware é devolvido.
  É assim que um middleware de autenticação responde `401`.
- A parte "depois" enxerga a resposta final, inclusive o `404`/`405` que o router gera quando nenhuma rota casa.
- Os middlewares rodam antes do roteamento; por isso `ARequest.PathParams` só é preenchido depois de `ANext`.
- Uma exceção lançada por um middleware ou pela rota se propaga normalmente (`500`, ou `400` para erro de parâmetro
  tipado); a parte "depois" é ignorada.
- Um middleware também pode ser uma classe que implementa `IAWSLambda4DHTTPMiddleware` (`procedure Execute(ARequest,
  AResponse, ANext)`), passada ao mesmo `Use`.
- Os middlewares são globais: rodam para todas as rotas registradas naquele router.

## Lendo dados da requisição com tipos

`PathParams`, `QueryParams` e `Headers` oferecem `First('nome')`, que devolve a string bruta, e `Field('nome')`, que
devolve um valor tipado:

```pascal
ARequest.PathParams.Field('id').AsInteger
ARequest.QueryParams.Field('price').AsFloat
ARequest.QueryParams.Field('total').AsCurrency
ARequest.QueryParams.Field('from').AsDate          // ISO 8601: 2024-03-15
ARequest.QueryParams.Field('at').AsDateTime        // ISO 8601: 2024-03-15T10:30:45-03:00
ARequest.QueryParams.Field('name').AsString
```

- `AsInteger`, `AsFloat`, `AsCurrency`, `AsDate`, `AsDateTime`, `AsString`; float e currency usam `.` como separador decimal.
- Se o valor não existe ou é inválido, `AsXxx` lança `EAWSLambda4DHTTPBadRequest`; o adapter HTTP a converte em uma
  resposta `400` cujo corpo é `{"message":"<mensagem da conversão>"}`. Qualquer outra exceção vira um `500` genérico.
- `AsXxx(Padrão)` devolve o valor padrão em vez de lançar exceção; `TryAsXxx(out Valor)` devolve `False`; `Exists`
  informa se o parâmetro foi enviado.
- Datas com fuso horário (`Z` ou `+hh:mm`) são devolvidas em UTC.

## Rodando localmente antes de subir

`TAWSLambda4DRunner.SelfHosted` é `True` quando a variável `AWS_LAMBDA_RUNTIME_API` **não** está definida, isto é,
quando você não está dentro do Lambda. Nesse caso o `RunLocal` sobe um servidor local que emula a Runtime API (porta
padrão `9001`), entrega um evento, executa o seu handler, imprime o resultado no console e retorna. Dentro do Lambda
você chama `Run` normalmente. Funciona no Windows e no Linux.

```pascal
if TAWSLambda4DRunner.SelfHosted then
  TAWSLambda4DRunner.RunLocal(handler, '{"name":"Gabriel"}')   // evento como string JSON
else
  TAWSLambda4DRunner.Run(handler);
```

Para funções HTTP você pode descrever a requisição de forma fluente, em vez de escrever à mão o JSON do API Gateway
(formato de payload 2.0). `Content` devolve o JSON gerado, se quiser vê-lo:

```pascal
LPayload := TAWSLambda4DHTTPPayloadV2.New
  .RawPath('/documents/15')
  .AddQuery('status', 'active')
  .AddHeader('content-type', 'application/json')
  .Body('{"number":123}');
LPayload.RequestContext.HTTP.Method('POST').Path('/documents/15');

TAWSLambda4DRunner.RunLocal(LRouter, LPayload);
```

Valores separados por vírgula viram parâmetros repetidos (`AddQuery('id', '10,20')` gera `id=10&id=20`). Mantenha uma
variável com o payload enquanto usa `RequestContext`/`HTTP`, pois os pais encadeados são guardados por referência fraca.

## Compilando e publicando

1. Compile o projeto para **Linux 64 bits** (exige o SDK de Linux do Delphi / PAServer).
2. Chame o executável de `bootstrap` e compacte em um zip.
3. Crie a função Lambda com um custom runtime (`provided.al2023`), envie o zip e, para HTTP, associe um API Gateway
   HTTP API ou uma Function URL.

São os passos padrão de qualquer custom runtime da AWS; a biblioteca não acrescenta nada além do executável. Use
`ReportMemoryLeaksOnShutdown := True` durante o desenvolvimento para detectar vazamentos de memória.

## Estrutura do projeto

| Caminho | Conteúdo |
|---|---|
| `Source/AWSLambda4D.pas` | Unit de fachada: aliases dos principais tipos; normalmente basta `uses AWSLambda4D` |
| `Source/AWSLambda4D.Runner.pas` | `TAWSLambda4DRunner`: `Run`, `RunLocal`, `SelfHosted` |
| `Source/AWSLambda4D.Runtime*.pas` | O loop, o cliente da Runtime API, um mock e o servidor local |
| `Source/AWSLambda4D.HTTP.*.pas` | Tipos HTTP, adapter (API Gateway v1/v2), router, route matcher e o builder de evento v2 |
| `Samples/` | `HelloLambda`, `APIHTTPLambda`, `APIHTTPRouterLambda`, além de `LocalLambda` e `MockLambda` |
| `Test/` | Projeto de testes DUnitX |

## Testes

O projeto `Test/AWSLambda4DTest.dproj` usa DUnitX (router, parâmetros tipados, adapter HTTP, runner e builder de
evento). Compile e execute pela IDE do Delphi ou com `msbuild Test\AWSLambda4DTest.dproj /p:Platform=Win64`.
