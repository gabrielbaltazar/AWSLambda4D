unit AWSLambda4D.HTTP.Types.Test;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DUnitX.TestFramework,
  AWSLambda4D.HTTP.Types;

type
  [TestFixture]
  TAWSLambda4DHTTPFieldTest = class
  private
    FValues: TAWSLambda4DHTTPValues;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure First_StillReturnsRawString;
    [Test]
    procedure Field_MissingName_ExistsIsFalseAndAsStringEmpty;
    [Test]
    procedure Field_WithIndex_ReadsNthValue;
    [Test]
    procedure AsString_ReturnsValue;
    [Test]
    procedure AsInteger_ValidValue_ReturnsInteger;
    [Test]
    procedure AsInteger_NegativeValue_ReturnsInteger;
    [Test]
    procedure AsInteger_InvalidValue_RaisesConvertError;
    [Test]
    procedure AsInteger_MissingValue_RaisesConvertError;
    [Test]
    procedure AsInteger_InvalidValue_ReturnsDefault;
    [Test]
    procedure AsInteger_MissingValue_ReturnsDefault;
    [Test]
    procedure TryAsInteger_InvalidValue_ReturnsFalse;
    [Test]
    procedure AsFloat_UsesDotAsDecimalSeparator;
    [Test]
    procedure AsFloat_InvalidValue_RaisesConvertError;
    [Test]
    procedure AsCurrency_UsesDotAsDecimalSeparator;
    [Test]
    procedure AsDateTime_Iso8601WithoutZone_ReturnsValue;
    [Test]
    procedure AsDateTime_Iso8601WithZ_ReturnsUtc;
    [Test]
    procedure AsDateTime_Iso8601WithOffset_ReturnsUtc;
    [Test]
    procedure AsDateTime_NonIsoValue_RaisesConvertError;
    [Test]
    procedure AsDate_DateOnly_ReturnsDate;
    [Test]
    procedure AsDate_DateTime_DropsTime;
    [Test]
    procedure AsDate_InvalidValue_ReturnsDefault;
  end;

implementation

procedure TAWSLambda4DHTTPFieldTest.Setup;
begin
  FValues := TAWSLambda4DHTTPValues.Create;
end;

procedure TAWSLambda4DHTTPFieldTest.TearDown;
begin
  FValues.Free;
end;

procedure TAWSLambda4DHTTPFieldTest.First_StillReturnsRawString;
begin
  FValues.Add('id', '42');
  Assert.AreEqual('42', FValues.First('id'));
end;

procedure TAWSLambda4DHTTPFieldTest.Field_MissingName_ExistsIsFalseAndAsStringEmpty;
begin
  Assert.IsFalse(FValues.Field('id').Exists);
  Assert.AreEqual('', FValues.Field('id').AsString);
end;

procedure TAWSLambda4DHTTPFieldTest.Field_WithIndex_ReadsNthValue;
begin
  FValues.Add('tag', 'a');
  FValues.Add('tag', 'b');

  Assert.AreEqual('b', FValues.Field('tag', 1).AsString);
  Assert.IsFalse(FValues.Field('tag', 2).Exists);
end;

procedure TAWSLambda4DHTTPFieldTest.AsString_ReturnsValue;
begin
  FValues.Add('name', 'Gabriel');
  Assert.AreEqual('Gabriel', FValues.Field('name').AsString);
  Assert.IsTrue(FValues.Field('name').Exists);
end;

procedure TAWSLambda4DHTTPFieldTest.AsInteger_ValidValue_ReturnsInteger;
begin
  FValues.Add('id', '42');
  Assert.AreEqual(42, FValues.Field('id').AsInteger);
end;

procedure TAWSLambda4DHTTPFieldTest.AsInteger_NegativeValue_ReturnsInteger;
begin
  FValues.Add('id', '-7');
  Assert.AreEqual(-7, FValues.Field('id').AsInteger);
end;

procedure TAWSLambda4DHTTPFieldTest.AsInteger_InvalidValue_RaisesConvertError;
begin
  FValues.Add('id', 'abc');

  Assert.WillRaise(
    procedure
    begin
      FValues.Field('id').AsInteger;
    end,
    EConvertError);
end;

procedure TAWSLambda4DHTTPFieldTest.AsInteger_MissingValue_RaisesConvertError;
begin
  Assert.WillRaise(
    procedure
    begin
      FValues.Field('id').AsInteger;
    end,
    EConvertError);
end;

procedure TAWSLambda4DHTTPFieldTest.AsInteger_InvalidValue_ReturnsDefault;
begin
  FValues.Add('id', 'abc');
  Assert.AreEqual(99, FValues.Field('id').AsInteger(99));
end;

procedure TAWSLambda4DHTTPFieldTest.AsInteger_MissingValue_ReturnsDefault;
begin
  Assert.AreEqual(99, FValues.Field('id').AsInteger(99));
end;

procedure TAWSLambda4DHTTPFieldTest.TryAsInteger_InvalidValue_ReturnsFalse;
var
  LValue: Integer;
begin
  FValues.Add('id', '1.5');
  Assert.IsFalse(FValues.Field('id').TryAsInteger(LValue));
end;

procedure TAWSLambda4DHTTPFieldTest.AsFloat_UsesDotAsDecimalSeparator;
begin
  FValues.Add('price', '12.5');
  Assert.AreEqual(12.5, FValues.Field('price').AsFloat, 0.0001);
end;

procedure TAWSLambda4DHTTPFieldTest.AsFloat_InvalidValue_RaisesConvertError;
begin
  FValues.Add('price', 'x');

  Assert.WillRaise(
    procedure
    begin
      FValues.Field('price').AsFloat;
    end,
    EConvertError);
end;

procedure TAWSLambda4DHTTPFieldTest.AsCurrency_UsesDotAsDecimalSeparator;
begin
  FValues.Add('total', '1234.56');
  Assert.AreEqual(Currency(1234.56), FValues.Field('total').AsCurrency);
end;

procedure TAWSLambda4DHTTPFieldTest.AsDateTime_Iso8601WithoutZone_ReturnsValue;
begin
  FValues.Add('at', '2024-03-15T10:30:45');
  Assert.AreEqual(EncodeDateTime(2024, 3, 15, 10, 30, 45, 0), FValues.Field('at').AsDateTime);
end;

procedure TAWSLambda4DHTTPFieldTest.AsDateTime_Iso8601WithZ_ReturnsUtc;
begin
  FValues.Add('at', '2024-03-15T10:30:45Z');
  Assert.AreEqual(EncodeDateTime(2024, 3, 15, 10, 30, 45, 0), FValues.Field('at').AsDateTime);
end;

procedure TAWSLambda4DHTTPFieldTest.AsDateTime_Iso8601WithOffset_ReturnsUtc;
begin
  FValues.Add('at', '2024-03-15T10:30:45-03:00');
  Assert.AreEqual(EncodeDateTime(2024, 3, 15, 13, 30, 45, 0), FValues.Field('at').AsDateTime);
end;

procedure TAWSLambda4DHTTPFieldTest.AsDateTime_NonIsoValue_RaisesConvertError;
begin
  FValues.Add('at', '15/03/2024');

  Assert.WillRaise(
    procedure
    begin
      FValues.Field('at').AsDateTime;
    end,
    EConvertError);
end;

procedure TAWSLambda4DHTTPFieldTest.AsDate_DateOnly_ReturnsDate;
begin
  FValues.Add('day', '2024-03-15');
  Assert.AreEqual(EncodeDate(2024, 3, 15), FValues.Field('day').AsDate);
end;

procedure TAWSLambda4DHTTPFieldTest.AsDate_DateTime_DropsTime;
begin
  FValues.Add('day', '2024-03-15T23:59:59');
  Assert.AreEqual(EncodeDate(2024, 3, 15), FValues.Field('day').AsDate);
end;

procedure TAWSLambda4DHTTPFieldTest.AsDate_InvalidValue_ReturnsDefault;
begin
  FValues.Add('day', 'nope');
  Assert.AreEqual(EncodeDate(2000, 1, 1), FValues.Field('day').AsDate(EncodeDate(2000, 1, 1)));
end;

end.
