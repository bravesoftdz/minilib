unit mnXML;
{**
 *  This file is part of the "Mini Library"
 *
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}

{$M+}
{$H+}
{$IFDEF FPC}
{$mode delphi}
{$ENDIF}

interface

uses
  Classes, SysUtils, Contnrs,
  mnXMLStreams, mnXMLUtils, mnUtils;

type
  TmnBoolean = (Default, Yes, No);
  TmnXMLObject = class(TObject);

  EmnXMLException = class(Exception)
  private
    FLine: Integer;
    FColumn: Integer;
    FCode: Cardinal;
  public
    constructor Create(const Msg: string); overload;
    constructor Create(const Msg: string; Line: Integer; Column: Integer); overload;
    property Code: Cardinal read FCode write FCode;
    property Column: Integer read FColumn write FColumn;
    property Line: Integer read FLine write FLine;
  end;

  EmnXMLParserException = class(EmnXMLException);

  TmnXMLEntity = class(TCollectionItem)
  private
    FValue: string;
    FName: string;
  public
    property Name: string read FName write FName;
    property Value: string read FValue write FValue;
    function DiffLen: Integer;
  end;

  TmneReplaceRec = record
    Index: Integer; //index of item
    Pos: PChar; //pos in string;
  end;
  TmneReplaceArr = array of TmneReplaceRec;
  TEntityRenderWay = (erwEncode, erwDecode);

  TmnXMLEntities = class(TCollection)
  private
    function GetItem(Index: Integer): TmnXMLEntity;
    procedure SetItem(Index: Integer; const Value: TmnXMLEntity);
    function GetEntity(Index: string): TmnXMLEntity;
  public
    constructor Create(ItemClass: TCollectionItemClass);
    destructor Destroy; override;
    function Add: TmnXMLEntity; overload;
    function Add(const Name, Value: string): TmnXMLEntity; overload;
    function Find(const Name: string): TmnXMLEntity;
    function Encode(const Value: string): string;
    function Decode(const Name: string): string;
    property Items[Index: Integer]: TmnXMLEntity read GetItem write SetItem;
    property Entity[Index: string]: TmnXMLEntity read GetEntity; default;
    //belal
    function CreateReplaceArr(const Value: string; vWay: TEntityRenderWay): TmneReplaceArr;
    function RenderText(const vText: string; vWay: TEntityRenderWay): string;
  end;

  TmnXMLStack = class;

  TmnXMLStackNode = class(TObject)
  public
    Instance: TObject;
    Owner: TmnXMLStack;
    Prior: TmnXMLStackNode;
  end;

  TmnXMLStack = class(TObject)
  private
    FCount: Integer;
    FCurrent: TmnXMLStackNode;
    function GetCurrent: TObject;
    procedure SetCurrent(const Value: TObject);
  public
    function IsEmpty: Boolean;
    procedure Push(Instance: TObject);
    function Pop: TObject;
    procedure Delete;
    function Peek: TObject;
    property Current: TObject read GetCurrent write SetCurrent;
    property Count: Integer read FCount;
  end;

  TmnXMLAttribute = class(TmnXMLObject)
  private
    FName: string;
    FValue: string;
    function GetValue: string;
  public
    property Name: string read FName write FName; //write not sure if needed
    property Value: string read GetValue write FValue;
  end;

  TmnXMLAttributes = class(TObjectList)
  private
    function GetItem(Index: Integer): TmnXMLAttribute;
    procedure SetItem(Index: Integer; const Value: TmnXMLAttribute);
    function GetValue(Index: string): string;
    procedure SetValue(Index: string; const Value: string);
  public
    procedure SetText(Value: string);
    function Find(const Name: string): TmnXMLAttribute;
    property Items[Index: Integer]: TmnXMLAttribute read GetItem write SetItem;
    property Values[Index: string]: string read GetValue write SetValue; default;
  end;

  { TmnXMLFiler }

  TmnXMLFiler = class(TmnXMLObject)
  private
    FActive: Boolean;
    FOwned: Boolean;
    FVersion: string;
    FStream: TmnXMLStream;
    FHeader: TStringList;
    FCharset: string;
    FEntities: TmnXMLEntities;
    FStandalone: TmnBoolean;
  protected
    procedure DeclareEntities; virtual;
    procedure DoStart; virtual;
    procedure DoStop; virtual;
    function EntityEncode(const Value: string): string;
    function EntityDecode(const Value: string): string;
  public
    constructor Create; overload; virtual;
    constructor Create(Stream: TmnXMLStream; Owned: Boolean = True); overload;
    constructor Create(const FileName:string); overload;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Active: Boolean read FActive write FActive;
    property Stream: TmnXMLStream read FStream;
    property Header: TStringList read FHeader write FHeader;
    property Standalone: TmnBoolean read FStandalone write FStandalone;
    property Version: string read FVersion write FVersion;
    property Charset: string read FCharset write FCharset;
    property Entities: TmnXMLEntities read FEntities write FEntities;
  end;

implementation

procedure TmnXMLFiler.Stop;
begin
  if not FActive then
    raise EmnXMLException.Create('File already closed');
  DoStop;
  FActive := False;
end;

constructor TmnXMLFiler.Create(Stream: TmnXMLStream; Owned: Boolean);
begin
  Create;
  if Stream = nil then
    raise EmnXMLException.Create('Stream is nil');
  FStream := Stream;
  FOwned := Owned;
end;

constructor TmnXMLFiler.Create(const FileName: string);
begin
  Create(TmnXMLStream.Create(TFileStream.Create(FileName, fmOpenRead)));
end;

constructor TmnXMLFiler.Create;
begin
  inherited;
  FHeader := TStringList.Create;
  FEntities := TmnXMLEntities.Create(TmnXMLEntity);
  FVersion := '1.0';
  {$ifdef FPC}
  FCharset := 'utf-8';
  {$else}
  FCharset := 'iso-8859-1';
  {$endif}
end;

procedure TmnXMLFiler.DeclareEntities;
begin
  Entities.Add('&amp;', '&'); //must be first //belal add & and ; to name
  Entities.Add('&lt;', '<');
  Entities.Add('&gt;', '>');
  Entities.Add('&apos;', '''');
  Entities.Add('&quot;', '"');

{  Entities.Add('amp', '&'); //must be first
  Entities.Add('lt', '<');
  Entities.Add('gt', '>');
  Entities.Add('apos', '''');
  Entities.Add('quot', '"');}
end;

destructor TmnXMLFiler.Destroy;
begin
{  if Active then
    Stop;}
  if FOwned then
    FStream.Free;
  FHeader.Free;
  FEntities.Free;
  inherited;
end;

procedure TmnXMLFiler.DoStop;
begin
end;

procedure TmnXMLFiler.DoStart;
begin
end;

procedure TmnXMLFiler.Start;
begin
  if FActive then
    raise EmnXMLException.Create('File already opened');
  FActive := True;
  FEntities.Clear;
  DeclareEntities;
  DoStart;
end;

function TmnXMLFiler.EntityEncode(const Value: string): string;
//var
  //i: Integer;
begin
  Result := Entities.RenderText(Value, erwEncode);
  //Result := Value; belal
  //for i := 0 to Entities.Count - 1 do
    //Result := StringReplace(Result, Entities.Items[i].Value, '&' + Entities.Items[i].Name + ';', [rfReplaceAll]);
end;

{ TmnXMLEntities }

function TmnXMLEntities.Add: TmnXMLEntity;
begin
  Result := inherited Add as TmnXMLEntity;
end;

function TmnXMLEntities.Add(const Name, Value: string): TmnXMLEntity;
begin
  Result := Add;
  Result.Name := Name;
  Result.Value := Value;
end;

constructor TmnXMLEntities.Create(ItemClass: TCollectionItemClass);
begin
  inherited Create(ItemClass);
end;

function TmnXMLEntities.Decode(const Name: string): string;
var
  aEntity: TmnXMLEntity;
begin
  aEntity := Entity[Name];
  if aEntity <> nil then
    Result := aEntity.Value
  else
    raise EmnXMLException.Create('Entity '+ Name+ ' not found');
end;

function TmnXMLEntities.RenderText(const vText: string; vWay: TEntityRenderWay): string;
var
  arr: TmneReplaceArr;
  I, t: Integer;
  v, r, e: PChar;
  lv, ln: Integer;
begin
  arr := CreateReplaceArr(vText, vWay);
  if arr=nil then
    Result := vText
  else
  begin
    t := Length(vText);
    for I := 0 to Length(arr) - 1 do
      case vWay of
        erwEncode: Inc(t, Items[arr[i].Index].DiffLen);
        erwDecode: Inc(t, -Items[arr[i].Index].DiffLen);
      end;


    SetLength(Result, t);//add if t<>0 ???
    v := PChar(vText);
    r := PChar(Result);

    for I := 0 to Length(arr) - 1 do
    begin
      StrLCopy(r, v, arr[i].Pos-v);
      lv := Length(Items[arr[i].Index].Value);
      ln := Length(Items[arr[i].Index].Name);
      Inc(r, arr[i].Pos-v);
      case vWay of
        erwEncode:
        begin
          Inc(v, arr[i].Pos-v+lv);
          e := PChar(Items[arr[i].Index].Name);
          StrLCopy(r, e, ln);
          Inc(r, ln);
        end;
        erwDecode:
        begin
          Inc(v, arr[i].Pos-v+ln);
          e := PChar(Items[arr[i].Index].Value);
          StrLCopy(r, e, lv);
          Inc(r, lv);
        end;
      end; //case
    end; //for
    StrLCopy(r, v, MaxInt);
  end; //else
end;

function TmnXMLEntities.CreateReplaceArr(const Value: string; vWay: TEntityRenderWay): TmneReplaceArr;
  procedure _Add(vPos, vIndex: Integer; vChar: PChar);
  var
    l: Integer;
  begin
    l := Length(Result);
    if vPos=l then
      SetLength(Result, vPos+10000);
    Result[vPos].Index := vIndex;
    Result[vPos].Pos := vChar;
  end;

  procedure _QuickSort(iLo, iHi: Integer);

    procedure Swap(I, J: Integer);
    var
      rec: TmneReplaceRec;
    begin
      rec := Result[i];
      Result[i] := Result[j];
      Result[j] := rec;
    end;

    function CallProc(Idx1, Idx2: Integer; vArr: TmneReplaceArr): Integer;
    var
      p: PChar;
    begin
      //Result := vProc(List[Idx1], List[Idx2]);
      p := PChar(Value);
      Result := (vArr[Idx1].Pos-p)-(vArr[Idx2].Pos-p);
    end;

  var
    Lo, Hi: integer;
    Mid: Integer;
  begin
    Lo := iLo;
    Hi := iHi;
    Mid := ((Lo + Hi) div 2);
    repeat
      while CallProc(Lo, Mid, Result) < 0 do
        Inc(Lo);
      while CallProc(Hi, Mid, Result) > 0 do
        Dec(Hi);
      if Lo <= Hi then
      begin
        if CallProc(Hi, Lo, Result) <> 0 then
          Swap(Lo, Hi);
        Inc(Lo);
        Dec(Hi);
      end;
    until Lo > Hi;
    if Hi > iLo then
      _QuickSort(iLo, Hi);
    if Lo < iHi then
      _QuickSort(Lo, iHi);
  end;

  function GetMatchItemIndex(p: PChar; vLen: Integer): Integer;
  var
    i, j, l: Integer;
    v, t: PChar;
    aSame: Boolean;
  begin
    Result := -1;
    for I := 0 to Count - 1 do
    begin
      case vWay of
        erwEncode:
        begin
          v := PChar(Items[i].Value);
          l := Length(Items[i].Value);
        end;
        erwDecode:
        begin
          v := PChar(Items[i].Name);
          l := Length(Items[i].Name);
        end;
        else
        begin
          v := nil;
          l := MaxInt;
        end;
      end;
      if l<=vLen then
      begin
        aSame := True;
        t := p;
        for j := 0 to l-1 do
        begin
          if t^<>v^ then
          begin
            aSame := False;
            Break;
          end;
          Inc(t);
          Inc(v);
        end;
        if aSame then
        begin
          Result := i;
          Break;
        end;
      end;
    end;
  end;
var
  i, c: Integer;
  p, e: PChar;
begin
  Result := nil;
  c := 0;
  p := PChar(Value);
  e := p;
  Inc(e, Length(Value));

  while (e-p)>0 do
  begin
    i := GetMatchItemIndex(p, e-p);
    if i<>-1 then
    begin
      _Add(c, i, p);
      Inc(c);
      case vWay of
        erwEncode: Inc(p, Length(Items[i].Value));
        erwDecode: Inc(p, Length(Items[i].Name));
      end;
    end
    else
      Inc(p);
  end;

  SetLength(Result, c);
  //if c<>0 then
    //_QuickSort(0, c-1);

end;


destructor TmnXMLEntities.Destroy;
begin
  inherited;
end;

function TmnXMLEntities.Encode(const Value: string): string;
var
  aEntity: TmnXMLEntity;
begin
  aEntity := Entity[Value];
  if aEntity <> nil then
    Result := aEntity.Name
  else
    raise EmnXMLException.Create('Entity '+ Value+ ' not found');
end;

function TmnXMLEntities.Find(const Name: string): TmnXMLEntity;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
  begin
    if Items[i].Name = Name then
    begin
      Result := Items[i];
      break;
    end;
  end;
end;

function TmnXMLEntities.GetEntity(Index: string): TmnXMLEntity;
begin
  Result := Find(Index);
end;

function TmnXMLEntities.GetItem(Index: Integer): TmnXMLEntity;
begin
  Result := inherited Items[Index] as TmnXMLEntity
end;

procedure TmnXMLEntities.SetItem(Index: Integer;
  const Value: TmnXMLEntity);
begin
  inherited Items[Index] := Value
end;

{ EmnXMLException }

constructor EmnXMLException.Create(const Msg: string; Line,
  Column: Integer);
begin
  Create(Msg + #13'Line Number ' + IntToStr(Line) + ', Column ' + IntToStr(Column));
  FLine := Line;
  FColumn := Column;
end;

constructor EmnXMLException.Create(const Msg: string);
begin
  inherited;
end;

{ TmnXMLStack }

procedure TmnXMLStack.Delete;
var
  aNode: TmnXMLStackNode;
  aObject: TObject;
begin
  if FCurrent = nil then
    raise EmnXMLException.Create(sStackIsEmpty);
  aObject := FCurrent.Instance;
  aNode := FCurrent;
  FCurrent := aNode.Prior;
  Dec(FCount);
  aNode.Free;
  aObject.Free;
end;

function TmnXMLStack.GetCurrent: TObject;
begin
  if FCurrent = nil then
    raise EmnXMLException.Create(sStackIsEmpty);
  Result := FCurrent.Instance;
end;

function TmnXMLStack.IsEmpty: Boolean;
begin
  Result := FCurrent = nil;
end;

function TmnXMLStack.Peek: TObject;
begin
  if FCurrent = nil then
    raise EmnXMLException.Create(sStackIsEmpty);
  Result := FCurrent.Instance;
end;

function TmnXMLStack.Pop: TObject;
var
  aNode: TmnXMLStackNode;
begin
  if FCurrent = nil then
    raise EmnXMLException.Create(sStackIsEmpty);
  Result := FCurrent.Instance;
  aNode := FCurrent;
  FCurrent := aNode.Prior;
  aNode.Free;
  Dec(FCount);
end;

procedure TmnXMLStack.Push(Instance: TObject);
var
  aNode: TmnXMLStackNode;
begin
  aNode := TmnXMLStackNode.Create;
  aNode.Instance := Instance;
  aNode.Prior := FCurrent;
  aNode.Owner := Self;
  FCurrent := aNode;
  Inc(FCount);
end;

procedure TmnXMLStack.SetCurrent(const Value: TObject);
begin
  if FCurrent = nil then
    raise EmnXMLException.Create(sStackIsEmpty);
  FCurrent.Instance := Value;
end;

{ TmnXMLAttributes }

function TmnXMLAttributes.Find(const Name: string): TmnXMLAttribute;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
  begin
    if SameText(Name, Items[i].Name) then
    begin
      Result := Items[i];
      break;
    end;
  end;
end;

function TmnXMLAttributes.GetItem(Index: Integer): TmnXMLAttribute;
begin
  Result := inherited Items[Index] as TmnXMLAttribute;
end;

function TmnXMLAttributes.GetValue(Index: string): string;
var
  aAttribute: TmnXMLAttribute;
begin
  aAttribute := Find(Index);
  if aAttribute <> nil then
    Result := aAttribute.FValue
  else
    Result := '';
end;

procedure TmnXMLAttributes.SetItem(Index: Integer;
  const Value: TmnXMLAttribute);
begin
  inherited Items[Index] := Value;
end;

procedure TmnXMLAttributes.SetValue(Index: string; const Value: string);
var
  aAttribute: TmnXMLAttribute;
begin
  aAttribute := Find(Index);
  if aAttribute = nil then
  begin
    aAttribute := TmnXMLAttribute.Create;
    Add(aAttribute);
  end;
  aAttribute.FValue := Value
end;

procedure TmnXMLAttributes.SetText(Value: string);
var
  i: Integer;
  aStrings: TStrings;
  p: Integer;
  s: string;
  aAttribute: TmnXMLAttribute;
begin
  Clear;
  aStrings := CreateAttStrings(Value);
  try
    for i := 0 to aStrings.Count - 1 do
    begin
      s := aStrings[i];
      p := pos('=', s);
      aAttribute := TmnXMLAttribute.Create;
      aAttribute.FName := Copy(s, 1, p - 1);
      aAttribute.FValue := DequoteStr(Copy(s, p + 1, MaxInt));
      Add(aAttribute);
    end;
  finally
    aStrings.Free;
  end;
end;

{ TmnXMLAttribute }

function TmnXMLAttribute.GetValue: string;
begin
  if Self <> nil then
    Result := FValue
  else
    Result := '';
end;

function TmnXMLFiler.EntityDecode(const Value: string): string;
//var
  //i, l, cBegin, cStart, cEnd: integer;
begin
  Result := Entities.RenderText(Value, erwDecode);
  {i := 1;
  cBegin := 1;
  l := Length(Value);
  Result := '';
  while i <= l do
  begin
    if Value[i] = '&' then
    begin
      cStart := i;
      cEnd := 0;
      while i <= l do
      begin
        if Value[i] = ';' then
        begin
          cEnd := i;
          break;
        end;
        Inc(i);
      end;
      if cEnd = 0 then
        raise EmnXMLException.Create('Simicolon not found for entity');
      Result := Result + Copy(Value, cBegin, cStart - cBegin) + Entities.Decode(Copy(Value, cStart + 1, cEnd - cStart - 1));
      cBegin := i + 1;
    end;
    Inc(i);
  end;
  Result := Result + Copy(Value, cBegin, MaxInt);}
end;

{ TmnXMLEntity }

function TmnXMLEntity.DiffLen: Integer;
begin
  Result := Length(Name)-Length(Value);
end;

end.
