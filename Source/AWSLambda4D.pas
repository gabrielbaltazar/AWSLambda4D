unit AWSLambda4D;

interface

uses
  AWSLambda4D.Classes,
  AWSLambda4D.HTTP.Router,
  AWSLambda4D.HTTP.Types,
  AWSLambda4D.Runner,
  AWSLambda4D.Runtime.Interfaces;

type
  // Router
  TAWSLambda4DHTTPRouter = AWSLambda4D.HTTP.Router.TAWSLambda4DHTTPRouter;

  // HTTP
  TAWSLambda4DHTTPHandlerProc = AWSLambda4D.HTTP.Types.TAWSLambda4DHTTPHandlerProc;

  IAWSLambda4DHTTPHandler = AWSLambda4D.HTTP.Types.IAWSLambda4DHTTPHandler;

  IAWSLambda4DHTTPRouter = AWSLambda4D.HTTP.Types.IAWSLambda4DHTTPRouter;

  TAWSLambda4DHTTPRequest = AWSLambda4D.HTTP.Types.TAWSLambda4DHTTPRequest;

  TAWSLambda4DHTTPResponse = AWSLambda4D.HTTP.Types.TAWSLambda4DHTTPResponse;

  // Runtime
  TAWSLambda4DRequest = AWSLambda4D.Classes.TAWSLambda4DRequest;

  TAWSLambda4DResponse = AWSLambda4D.Classes.TAWSLambda4DResponse;

  TAWSLambda4DContext = AWSLambda4D.Classes.TAWSLambda4DContext;

  TAWSLambda4DHandlerProc = AWSLambda4D.Runtime.Interfaces.TAWSLambda4DHandlerProc;

  IAWSLambda4DHandler = AWSLambda4D.Runtime.Interfaces.IAWSLambda4DHandler;

  // Runner
  TAWSLambda4Runner = AWSLambda4D.Runner.TAWSLambda4Runner;

implementation

end.
