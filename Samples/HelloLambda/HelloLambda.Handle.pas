unit HelloLambda.Handle;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.JSON,
  AWSLambda4D.Classes,
  AWSLambda4D.Runtime.Interfaces,
  AWSLambda4D.HTTP.Types;

type
  THelloLambdaHandle = class(TInterfacedObject, IAWSLambda4DHandler)
  protected
    function Handle(const ARequest: TAWSLambda4DRequest; const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
  end;

implementation

{ THelloLambdaHandle }

function THelloLambdaHandle.Handle(const ARequest: TAWSLambda4DRequest;
  const AContext: TAWSLambda4DContext): TAWSLambda4DResponse;
var
  LJSON: TJSONObject;
  LNowUTC: TDateTime;
begin
  LNowUTC := TTimeZone.Local.ToUniversalTime(Now);
  LJSON := TJSONObject.Create;
  try
    LJSON.AddPair('currentDate', FormatDateTime('yyyy"-"mm"-"dd"', LNowUTC));
    LJSON.AddPair('currentDateUtc', DateToISO8601(LNowUTC, True));
    LJSON.AddPair('timezone', 'UTC');

    Result := TAWSLambda4DResponse.Create;
    Result.Body := LJSON.ToJSON;
    System.Writeln(Result.Body);
  finally
    LJSON.Free;
  end;
end;

end.
