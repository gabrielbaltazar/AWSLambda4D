unit AWSLambda4D.Utils;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.JSON,
  AWSLambda4D.HTTP.Types;

procedure AddJsonObjectValues(const ASource: TJSONObject; const ADestination: TDictionary<string, string>);
procedure AddJsonValues(const ASource: TJSONObject; const ADestination: TAWSLambda4DHTTPValues;
  const AOnlyMissing: Boolean = False);
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

procedure AddJsonValues(const ASource: TJSONObject; const ADestination: TAWSLambda4DHTTPValues;
  const AOnlyMissing: Boolean = False);
var
  LPair: TJSONPair;
  LArray: TJSONArray;
  I: Integer;
begin
  if ASource = nil then
    Exit;

  for LPair in ASource do
  begin
    if AOnlyMissing and ADestination.Contains(LPair.JsonString.Value) then
      Continue;

    if LPair.JsonValue is TJSONArray then
    begin
      LArray := TJSONArray(LPair.JsonValue);
      for I := 0 to LArray.Count - 1 do
        ADestination.Add(LPair.JsonString.Value, LArray.Items[I].Value);
    end
    else
      ADestination.Add(LPair.JsonString.Value, LPair.JsonValue.Value);
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
  if LValue <> nil then
    Result := LValue.Value;
end;

end.
