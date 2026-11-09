unit AWSLambda4D.Runtime.Interfaces;

interface

uses
  System.SysUtils,
  AWSLambda4D.Classes;

type
  ELambdaRuntimeAPI = class(Exception);

  IAWSLambda4DHandler = interface
    ['{55CABAF2-F2DA-477B-9C58-10E2CFEDB98A}']
    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  end;

  IAWSLambda4DRuntimeAPI = interface
    ['{2D2F991F-26CF-4CB7-A256-2B93FB734583}']
    function NextInvocation(out AContext: TAWSLambda4DContext): TAWSLambda4DRequest;
    procedure SendResponse(const AContext: TAWSLambda4DContext; const AResponse: TAWSLambda4DResponse);
    procedure SendError(const AContext: TAWSLambda4DContext; const AErrorType: string; const AErrorMessage: string);
  end;

implementation

end.
