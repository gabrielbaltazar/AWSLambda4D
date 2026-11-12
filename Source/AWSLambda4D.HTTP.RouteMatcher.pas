unit AWSLambda4D.HTTP.RouteMatcher;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  AWSLambda4D.HTTP.Types;

type
  TAWSLambda4DHTTPRouteMatcher = class
  private
    class function SplitPath(const APath: string): TArray<string>; static;
  public
    class function TryMatch(const ARoutePattern: string; const ARequestPath: string;
      const APathParams: TAWSLambda4DHTTPValues): Boolean; static;
    class function GetSpecificity(const ARoutePattern: string): Integer; static;
  end;

implementation

class function TAWSLambda4DHTTPRouteMatcher.SplitPath(const APath: string): TArray<string>;
var
  LParts: TList<string>;
  LStart: Integer;
  LIndex: Integer;
  LPath: string;
begin
  LPath := APath.Trim;
  LParts := TList<string>.Create;
  try
    LStart := 1;
    for LIndex := 1 to Length(LPath) + 1 do
    begin
      if LIndex > Length(LPath) then
      begin
        if LIndex > LStart then
          LParts.Add(Copy(LPath, LStart, LIndex - LStart));

        Break;
      end;

      if LPath[LIndex] = '/' then
      begin
        if LIndex > LStart then
          LParts.Add(Copy(LPath, LStart, LIndex - LStart));

        LStart := LIndex + 1;
      end;
    end;

    Result := LParts.ToArray;
  finally
    LParts.Free;
  end;
end;

class function TAWSLambda4DHTTPRouteMatcher.TryMatch(const ARoutePattern: string;
  const ARequestPath: string; const APathParams: TAWSLambda4DHTTPValues): Boolean;
var
  LRouteParts: TArray<string>;
  LRequestParts: TArray<string>;
  LIndex: Integer;
  LRoutePart: string;
  LRequestPart: string;
  LParamName: string;
begin
  Result := False;
  LRouteParts := SplitPath(ARoutePattern);
  LRequestParts := SplitPath(ARequestPath);

  if Length(LRouteParts) <> Length(LRequestParts) then
    Exit;

  // Primeiro valida todos os segmentos.
  for LIndex := 0 to High(LRouteParts) do
  begin
    LRoutePart := LRouteParts[LIndex];
    LRequestPart := LRequestParts[LIndex];

    if LRoutePart.StartsWith(':') then
    begin
      // Parâmetro dinâmico.
      if (Length(LRoutePart) = 1) or (LRequestPart = '') then
        Exit;
    end
    else
    begin
      // Segmentos estáticos ignoram maiúsculas/minúsculas.
      if not SameText(LRoutePart, LRequestPart) then
        Exit;
    end;
  end;

  // Somente extrai os parâmetros quando solicitado.
  if Assigned(APathParams) then
  begin
    APathParams.Clear;

    for LIndex := 0 to High(LRouteParts) do
    begin
      LRoutePart := LRouteParts[LIndex];

      if LRoutePart.StartsWith(':') then
      begin
        LParamName := Copy(LRoutePart, 2, MaxInt);
        APathParams.Add(LParamName, LRequestParts[LIndex]);
      end;
    end;
  end;

  Result := True;
end;

class function TAWSLambda4DHTTPRouteMatcher.GetSpecificity(const ARoutePattern: string): Integer;
var
  LParts: TArray<string>;
  LPart: string;
begin
  Result := 0;
  LParts := SplitPath(ARoutePattern);

  for LPart in LParts do
  begin
    // Cada segmento estático aumenta a prioridade.
    if not LPart.StartsWith(':') then
      Inc(Result);
  end;
end;

end.
