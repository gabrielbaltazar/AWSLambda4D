<p align="center">
  <img src="Images/logo.png" alt="AWSLambda4D" width="420">
</p>

# AWSLambda4D

**English** | [Português](README.pt-BR.md)

**AWSLambda4D is a library for running native Delphi functions on AWS Lambda.**

It implements the [Lambda Runtime API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html) so that a Delphi
executable (compiled for Linux 64-bit and named `bootstrap`) can run as an AWS Lambda *custom runtime*. You write the
function in Delphi, with no interpreter and no container image required, and the library takes care of the
poll → run → reply loop that Lambda expects.

- Plain handlers for any Lambda event (JSON in, JSON out).
- A typed HTTP layer for API Gateway (HTTP API v2 and REST API v1) and Lambda Function URLs.
- A small router with path parameters (`/users/:id`) and typed parameter reading (`AsInteger`, `AsDateTime`, ...).
- Anonymous functions **or** classes for your handlers, your choice.
- The same executable can run on your own machine (Windows or Linux) against a built-in local server, so you can try
  the function before uploading it.

## Table of contents

- [How it works](#how-it-works)
- [Which handler interface should I use?](#which-handler-interface-should-i-use)
- [Examples](#examples)
  - [HelloLambda: a plain handler](#hellolambda-a-plain-handler)
  - [APIHTTPLambda: an HTTP handler](#apihttplambda-an-http-handler)
  - [APIHTTPRouterLambda: a router](#apihttprouterlambda-a-router)
- [Reading request data with types](#reading-request-data-with-types)
- [Running locally before deploying](#running-locally-before-deploying)
- [Building and deploying](#building-and-deploying)
- [Project layout](#project-layout)
- [Tests](#tests)

## How it works

A Lambda custom runtime is just a program that talks HTTP to an endpoint that AWS publishes in the
`AWS_LAMBDA_RUNTIME_API` environment variable. For every invocation it must:

1. `GET  /2018-06-01/runtime/invocation/next` to receive the event (and headers such as the request id);
2. run your code;
3. `POST /2018-06-01/runtime/invocation/{id}/response` with the result, or `.../error` if it failed.

AWSLambda4D implements that loop:

```
                +-------------------------- your executable (bootstrap) --------------------------+
                |                                                                                  |
 AWS Lambda <---+--> TAWSLambda4DRuntimeAPI <--> TAWSLambda4DRuntime <--> your handler             |
 (Runtime API)  |        (HTTP client)              (the loop)            IAWSLambda4DHandler      |
                |                                                         or, on top of it,        |
                |                                                         IAWSLambda4DHTTPHandler  |
                +----------------------------------------------------------------------------------+
```

- `TAWSLambda4DRunner` (unit `AWSLambda4D.Runner`) is the entry point of your program. `Run` starts the loop.
- If your handler raises an exception, the runtime reports it to Lambda as a function error
  (`Function.<ExceptionClass>`) and keeps serving the next invocation.
- For HTTP events, `TAWSLambda4DHTTPAdapter` sits between the runtime and your code: it parses the API Gateway JSON into
  a typed request, calls your HTTP handler and serializes the response back to the format API Gateway expects.
- The runtime owns the request, response and context objects of each invocation and frees them for you. Your handler
  creates and returns a **new** response object and must not free the request or the context.

Add the single unit `AWSLambda4D` to your `uses` clause to get the main types.

## Which handler interface should I use?

There are two levels. Both can be implemented as a class **or** passed as an anonymous function.

| | `IAWSLambda4DHandler` | `IAWSLambda4DHTTPHandler` |
|---|---|---|
| Method | `Handle(ARequest, AContext): TAWSLambda4DResponse` | `Execute(ARequest): TAWSLambda4DHTTPResponse` |
| Anonymous function type | `TAWSLambda4DHandlerProc` | `TAWSLambda4DHTTPHandlerProc` |
| Input | The raw event as a JSON string (`ARequest.Body`) plus the Lambda context (`AContext`: request id, function ARN, deadline, trace id) | A parsed HTTP request: method, path, path/query parameters, headers, cookies, body |
| Output | A raw string (`Result.Body`) that Lambda returns as the function result | An HTTP response: status code, headers, cookies, body |
| Event formats | Anything: direct invoke, SQS, SNS, S3, EventBridge, a custom payload... | HTTP events from API Gateway (HTTP API v2, REST API v1) and Lambda Function URLs |
| Event parsing | You parse the JSON yourself | Done for you; supports payload v1 and v2 |
| Errors | An exception becomes a Lambda function error | An exception becomes an HTTP `500 Internal Server Error`; a bad typed parameter becomes `400` with the conversion message |
| Run with | `TAWSLambda4DRunner.Run(handler)` | `TAWSLambda4DRunner.Run(httpHandler)` (the adapter is added for you) |

**Use `IAWSLambda4DHandler` when** the function is *not* an HTTP endpoint: it reacts to queue messages, file uploads,
schedules or direct invocations, or when you need full control over the raw event and the Lambda context.

**Use `IAWSLambda4DHTTPHandler` when** the function sits behind API Gateway or a Function URL and you are building
a web API. You work with `Method`, `Path`, `PathParams`, `QueryParams`, `Headers` and `StatusCode` instead of
hand-parsing the gateway JSON. When you have several routes, use the router (`IAWSLambda4DHTTPRouter`), which is
itself an `IAWSLambda4DHTTPHandler`.

## Examples

All three samples live in `Samples/`. They also show how to run the same code locally (see
[Running locally before deploying](#running-locally-before-deploying)).

### HelloLambda: a plain handler

**With an anonymous function** (`Samples/HelloLambda/HelloLambda.dpr`):

```pascal
program HelloLambda;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AWSLambda4D;

function HelloWorld(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
begin
  Result := TAWSLambda4DResponse.Create;
  System.Writeln(ARequest.Body);                 // the raw event
  Result.Body := '{"message":"hello"}';
end;

begin
  if TAWSLambda4DRunner.SelfHosted then
    TAWSLambda4DRunner.RunLocal(HelloWorld, '{"name":"Gabriel"}')   // on your machine
  else
    TAWSLambda4DRunner.Run(HelloWorld);                             // on AWS Lambda
end.
```

`HelloWorld` can be a plain function (as above) or an inline `function(...) begin ... end` passed to `Run`; both are a
`TAWSLambda4DHandlerProc`.

**With a handler class** (`Samples/HelloLambda/HelloLambda.Handle.pas`):

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
    LJSON.AddPair('awsRequestId', AContext.AwsRequestId);   // Lambda context
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

and in the `.dpr`:

```pascal
TAWSLambda4DRunner.Run(THelloLambdaHandle.New);
```

Prefer a class when the handler has dependencies, state, or enough code to deserve its own unit and unit tests.

#### The request and the context

A `TAWSLambda4DHandlerProc` (or `IAWSLambda4DHandler.Handle`) receives two objects. In short: use the **request** to
decide *what* to process, and the **context** to *log, trace and watch the time*.

| | `TAWSLambda4DRequest` | `TAWSLambda4DContext` |
|---|---|---|
| What it is | The event that triggered the function | Metadata about this invocation, provided by Lambda |
| Where it comes from | The body of the Runtime API response | The headers of that same response |
| Changes with | Who invoked the function (S3, queue, schedule, direct invoke) | Each execution |
| Fields | `Body`, `RequestId` | `AwsRequestId`, `InvocationId`, `FunctionArn`, `TraceId`, `DeadlineMs` |

**`TAWSLambda4DRequest`** is your business input:

- `Body` is the event as a JSON string. Parse it yourself (for example with `System.JSON`).
- `RequestId` repeats the `AwsRequestId` of the context.

**`TAWSLambda4DContext`** is not part of your input data; it answers "who, where and until when":

- `AwsRequestId`: unique id of the invocation. Write it in your log lines to find everything about one execution in CloudWatch.
- `InvocationId`: invocation identifier reported by the Runtime API.
- `FunctionArn`: the function being run (name, account, region and alias can be taken from it).
- `TraceId`: tracing id (X-Ray), to propagate to other services.
- `DeadlineMs`: the instant the execution will be cut, in milliseconds since 1970 (UTC).

```pascal
function Process(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
var
  LRemainingMs: Int64;
begin
  Writeln('[', AContext.AwsRequestId, '] event: ', ARequest.Body);

  // How much time is left before Lambda interrupts the function
  LRemainingMs := AContext.DeadlineMs - DateTimeToUnix(Now, False) * 1000;   // System.DateUtils
  if LRemainingMs < 2000 then
    raise Exception.Create('Not enough time left to process the event.');

  Result := TAWSLambda4DResponse.Create;      // the function returns a NEW response
  Result.Body := '{"ok":true}';
end;
```

The runtime owns the request, the context and the response of each invocation and frees them for you; the function only
returns a new `TAWSLambda4DResponse` (its `Body` is the function result) and must not free the two parameters.

HTTP handlers (`IAWSLambda4DHTTPHandler`) receive only the `TAWSLambda4DHTTPRequest`; the Lambda context is not passed to
them.

### APIHTTPLambda: an HTTP handler

A single `IAWSLambda4DHTTPHandler` answers every request, whatever the path.

**With a handler class** (`Samples/APIHTTPLambda`):

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

**With an anonymous function** (`TAWSLambda4DHTTPHandlerProc`):

```pascal
TAWSLambda4DRunner.Run(
  procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
  begin
    AResponse.StatusCode := 201;
    AResponse.Headers.Add('content-type', 'application/json; charset=utf-8');
    AResponse.SetBody('{"timezone":"UTC"}');
  end);
```

The HTTP anonymous function is a **procedure**: the library creates the `AResponse` object for you (status `200` by
default) and you only fill it in; there is nothing to create or return. If the procedure raises an exception, the
response is freed and the exception follows the usual HTTP handling. (The non-HTTP `TAWSLambda4DHandlerProc` is
different: it is a function that returns a new `TAWSLambda4DResponse`.)

`RunLocal` accepts the same procedure for local runs, with an event string or with the payload builder.

### APIHTTPRouterLambda: a router

The router dispatches by HTTP method and path. Each route takes either an `IAWSLambda4DHTTPHandler` (a class) or an
anonymous function.

**With anonymous functions** (`Samples/APIHTTPRouterLambda/APIHTTPRouterLambda.dpr`):

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

**With handler classes** (`Samples/APIHTTPRouterLambda/Ping.Handler.pas`), mixing both styles and using path
parameters:

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
  LNumero := ARequest.PathParams.Field('numero').AsInteger;   // typed; 400 if it is not an integer
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

Router behavior:

- Methods: `Get`, `Post`, `Put`, `Delete`, `Patch`, and `Add('OPTIONS', ...)` for any other method. Calls can be chained.
- Segments starting with `:` are path parameters, read with `ARequest.PathParams.Field('name')`.
- Method and path matching are **case-insensitive** (`/PING` matches `/ping`); parameter values keep their case.
  A trailing slash is ignored.
- When several routes match, the one with more static segments wins (`/users/me` beats `/users/:id`).
- No route for the path answers `404 Not Found`; a route for the path but another method answers `405 Method Not Allowed`.
- Registering the same method and path twice raises an exception.

> **Note:** passing a constructor without parentheses, as in `LRouter.Get('/x', TMyHandler.Create)`, is ambiguous between
> the class overload and the function overload. Write `TMyHandler.Create()` or use a `New` class function that returns
> the interface, as the samples do.

### Without creating a router: `TAWSLambda4D`

If you do not want to create and keep a router variable, use the static `TAWSLambda4D` class (in the style of the
[Horse](https://github.com/HashLoad/horse) framework). Each call registers a route on a single router of the process
and returns the class, so calls can be chained:

```pascal
uses
  AWSLambda4D;

begin
  TAWSLambda4D
    .Get('/ping', procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse)
      begin
        AResponse.SetBody('{"message":"pong"}');
      end)
    .Post('/ping', TPingPostHandler.New)          // classes work too
    .Run;                                         // on AWS Lambda
end.
```

To simulate a request on your machine, end the chain with `RunLocal` and the payload builder (or an event string):

```pascal
TAWSLambda4D
  .Get('/ping', LHandler1)
  .Post('/ping', LHandler2)
  .RunLocal(TAWSLambda4DHTTPPayloadV2.New
    .RawPath('/ping')
    .RequestContext.HTTP.Method('POST').Path('/ping').&End.&End);
```

`Get`, `Post`, `Put`, `Delete`, `Patch` and `Add(method, path, ...)` take an `IAWSLambda4DHTTPHandler` or an anonymous
function and behave like the router methods above. `TAWSLambda4D.Router` returns the underlying router and
`TAWSLambda4D.Reset` discards the registered routes (useful in tests). Inside Lambda, `RunLocal` behaves like `Run`.

### Middlewares

A middleware runs **before and/or after** the route, like in Horse and other HTTP frameworks. Register it with `Use`
(on `TAWSLambda4D` or on a router); it receives the request, the response and a `ANext` procedure that runs the next step
of the chain (the next middleware and, in the end, the route):

```pascal
TAWSLambda4D
  .Use(
    procedure(const ARequest: TAWSLambda4DHTTPRequest; const AResponse: TAWSLambda4DHTTPResponse;
      const ANext: TProc)
    begin
      Writeln('-> ', ARequest.Method, ' ', ARequest.Path);      // before the route
      ANext();                                                  // runs the route
      AResponse.Headers.Add('access-control-allow-origin', '*'); // after the route
    end)
  .Get('/ping', LPingHandler)
  .Run;
```

- Middlewares run in the order they were registered: with `Use(A).Use(B)` the order is `A before, B before, route,
  B after, A after`.
- **Not calling `ANext`** stops the chain: the route is not executed and the middleware's own `AResponse` is returned.
  This is how you answer `401` in an authentication middleware.
- The "after" part sees the final response, including the `404`/`405` produced by the router when no route matches.
- Middlewares run before routing, so `ARequest.PathParams` is only filled after `ANext`.
- An exception raised by a middleware or by the route propagates as usual (`500`, or `400` for a typed parameter error);
  the "after" part is skipped.
- A middleware can also be a class that implements `IAWSLambda4DHTTPMiddleware` (`procedure Execute(ARequest, AResponse,
  ANext)`), passed to the same `Use`.
- Middlewares are global; they run for every route registered on that router.

## Reading request data with types

`PathParams`, `QueryParams` and `Headers` offer `First('name')`, which returns the raw string, and `Field('name')`,
which returns a typed value:

```pascal
ARequest.PathParams.Field('id').AsInteger
ARequest.QueryParams.Field('price').AsFloat
ARequest.QueryParams.Field('total').AsCurrency
ARequest.QueryParams.Field('from').AsDate          // ISO 8601: 2024-03-15
ARequest.QueryParams.Field('at').AsDateTime        // ISO 8601: 2024-03-15T10:30:45-03:00
ARequest.QueryParams.Field('name').AsString
```

- `AsInteger`, `AsFloat`, `AsCurrency`, `AsDate`, `AsDateTime`, `AsString`; floats and currency use `.` as the decimal separator.
- If the value is missing or invalid, `AsXxx` raises `EAWSLambda4DHTTPBadRequest`; the HTTP adapter turns it into a
  `400` response whose body is `{"message":"<conversion message>"}`. Any other exception becomes a generic `500`.
- `AsXxx(Default)` returns the default instead of raising; `TryAsXxx(out Value)` returns `False`; `Exists` tells whether
  the parameter was sent.
- Dates with a time zone (`Z` or `+hh:mm`) are returned in UTC.

## Running locally before deploying

`TAWSLambda4DRunner.SelfHosted` is `True` when the `AWS_LAMBDA_RUNTIME_API` variable is **not** defined, that is, when
you are not inside Lambda. In that case `RunLocal` starts a local server that emulates the Runtime API (default port
`9001`), delivers one event, runs your handler, prints the result to the console and returns. Inside Lambda you call
`Run` as usual. This works on Windows and on Linux.

```pascal
if TAWSLambda4DRunner.SelfHosted then
  TAWSLambda4DRunner.RunLocal(handler, '{"name":"Gabriel"}')   // event as a JSON string
else
  TAWSLambda4DRunner.Run(handler);
```

For HTTP functions you can describe the request fluently instead of writing the API Gateway JSON by hand (payload
format 2.0). `Content` returns the generated JSON if you want to see it:

```pascal
LPayload := TAWSLambda4DHTTPPayloadV2.New
  .RawPath('/documents/15')
  .AddQuery('status', 'active')
  .AddHeader('content-type', 'application/json')
  .Body('{"number":123}');
LPayload.RequestContext.HTTP.Method('POST').Path('/documents/15');

TAWSLambda4DRunner.RunLocal(LRouter, LPayload);
```

Values separated by commas become repeated parameters (`AddQuery('id', '10,20')` produces `id=10&id=20`). Keep a variable
holding the payload while you use `RequestContext`/`HTTP`, as the chained parents are held by weak references.

## Building and deploying

1. Compile the project for **Linux 64-bit** (needs the Delphi Linux SDK / PAServer).
2. Name the executable `bootstrap` and zip it.
3. Create the Lambda function with a custom runtime (`provided.al2023`), upload the zip, and, for HTTP, attach an API
   Gateway HTTP API or a Function URL.

These are the standard steps for any AWS custom runtime; the library does not add anything beyond the executable. Use
`ReportMemoryLeaksOnShutdown := True` during development to catch leaks.

## Project layout

| Path | Contents |
|---|---|
| `Source/AWSLambda4D.pas` | Facade unit: aliases for the main types; `uses AWSLambda4D` is usually enough |
| `Source/AWSLambda4D.Runner.pas` | `TAWSLambda4DRunner`: `Run`, `RunLocal`, `SelfHosted` |
| `Source/AWSLambda4D.Runtime*.pas` | The loop, the Runtime API client, a mock and the local server |
| `Source/AWSLambda4D.HTTP.*.pas` | HTTP types, adapter (API Gateway v1/v2), router, route matcher and the v2 event builder |
| `Samples/` | `HelloLambda`, `APIHTTPLambda`, `APIHTTPRouterLambda`, `APIHTTPCrud` (in-memory CRUD with GET/POST/PUT/DELETE), plus `LocalLambda` and `MockLambda` |
| `Test/` | DUnitX test project |

## Tests

The `Test/AWSLambda4DTest.dproj` project uses DUnitX (router, typed parameters, HTTP adapter, runner and event
builder). Build and run it from the Delphi IDE or with `msbuild Test\AWSLambda4DTest.dproj /p:Platform=Win64`.
