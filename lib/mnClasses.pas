unit mnClasses;
{**
 *  This file is part of the "Mini Library"
 *
 * @license   modifiedLGPL (modified of http://www.gnu.org/licenses/lgpl.html)
 *            See the file COPYING.MLGPL, included in this distribution,
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}

{$IFDEF FPC}
{$MODE delphi}
{$ENDIF}
{$M+}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, DateUtils, Types, Contnrs;

type

  { GItems }

  GItems<_Object_{$ifndef FPC}: class{$endif}> = class(TObjectList)
  private
    function GetItem(Index: Integer): _Object_;
  public
    property Items[Index: Integer]: _Object_ read GetItem; default;
    procedure Added(Item: _Object_); virtual;
    function Add(Item: _Object_): Integer;
    procedure Created; virtual;
    procedure AfterConstruction; override;
  end;

  {$ifdef FPC}
  GNamedItems<_Object_> = class(GItems<_Object_>)
  private
  public
    function Find(const Name: string): _Object_;
    function IndexOfName(vName: string): Integer;
  end;
  {$endif}
{
  FreePascal:

    TMyItems = class(specialize GItems<TMyObject>)

  Delphi:

    TMyItems = class(GItems<TMyObject>)
}
implementation

function GItems<_Object_>.GetItem(Index: Integer): _Object_;
begin
  Result := _Object_(inherited Items[Index]);
end;

procedure GItems<_Object_>.Added(Item: _Object_);
begin
end;

function GItems<_Object_>.Add(Item: _Object_): Integer;
begin
  inherited Add(Item);
  Added(Item);
end;

procedure GItems<_Object_>.Created;
begin
end;

procedure GItems<_Object_>.AfterConstruction;
begin
  inherited;
  Created;
end;

{$ifdef FPC}
{ GNamedItems }

function  GNamedItems<_Object_>.Find(const Name: string): _Object_;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
  begin
    if SameText(Items[i].Name, Name) then
    begin
      Result := Items[i];
      break;
    end;
  end;
end;

function GNamedItems<_Object_>.IndexOfName(vName: string): Integer;
var
  i: integer;
begin
  Result := -1;
  if vName <> '' then
    for i := 0 to Count - 1 do
    begin
      if SameText(Items[i].Name, vName) then
      begin
        Result := i;
        break;
      end;
    end;
end;
{$endif}

end.