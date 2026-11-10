unit AWSLambda4D.Utils;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.JSON;

procedure AddJsonObjectValues(const ASource: TJSONObject; const ADestination: TDictionary<string, string>);
function JsonBoolean(const AObject: TJSONObject; const AName: string): Boolean;
function JsonString(const AObject: TJSONObject; const AName: string; const ADefault: string = ''): string;

implementation

procedure AddJsonObjectValues(const ASource: TJSONObject; const ADestination: TDictionary<string, string>);
var
  LPair: TJSONPair;
  LValue: string;
begin
  if ASource = nil then
    Exit;

  for LPair in ASource do
  begin
    if LPair.JsonValue is TJSONArray then
    begin
      LValue := '';

      for var I := 0 to TJSONArray(LPair.JsonValue).Count - 1 do
      begin
        if LValue <> '' then
          LValue := LValue + ',';

        LValue := LValue + TJSONArray(LPair.JsonValue).Items[I].Value;
      end;
    end
    else
      LValue := LPair.JsonValue.Value;

    ADestination.AddOrSetValue(LPair.JsonString.Value, LValue);
  end;
end;

function JsonBoolean(const AObject: TJSONObject; const AName: string): Boolean;
begin
  Result := SameText(JsonString(AObject, AName), 'true');
end;

function JsonString(const AObject: TJSONObject; const AName: string; const ADefault: string = ''): string;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if AObject = nil then
    Exit;

  LValue := AObject.GetValue(AName);
  if LValue = nil then
    Exit;

  if LValue is TJSONString then
    Result := LValue.Value
  else
    Result := LValue.ToJSON;
end;

end.
