unit mnSocketStreams;
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
  Classes,
  SysUtils,
  StrUtils,
  mnStreams,
  mnSockets;

const
  cReadTimeout = 15000;
  cDataBuffSize = 8192;
  cBufferSize = 1024;

type
  EmnStreamException = class(Exception);
  
  { TmnSocketStream }

  TmnSocketStream = class(TStream)
  private
    FTimeout: Integer;
    FSocket: TmnCustomSocket;
    function GetConnected: Boolean;
    procedure FreeSocket;
  protected
    procedure DoError(S: string); virtual;
    function CreateSocket: TmnCustomSocket; virtual;
  public
    constructor Create(vSocket: TmnCustomSocket = nil); virtual;
    destructor Destroy; override;
    procedure Connect;
    procedure Disconnect;
    procedure Shutdown;
    function WaitToRead(Timeout: Longint = -1): Boolean; //select
    function WaitToWrite(Timeout: Longint = -1): Boolean; //select
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    property Socket: TmnCustomSocket read FSocket;
    property Timeout: Integer read FTimeout write FTimeout;
    property Connected: Boolean read GetConnected;
  end;

  { TmnConnectionStream }

  TmnConnectionStream = class(TmnSocketStream)
  private
    FBuffer: PChar;
    FPos: PChar;
    FEnd: PChar;
    FBufferSize: Cardinal;
    FEOFOnError: Boolean;
    FEOF: Boolean;
    FEndOfLine: string;
  protected
    procedure DoError(S: string); override;
  public
    constructor Create(vSocket: TmnCustomSocket = nil); override;
    destructor Destroy; override;
    procedure LoadBuffer;

    function Read(var Buffer; Count: Longint): Longint; override;
    procedure ReadUntil(const UntilStr: string; var Result: string; var Matched: Boolean);
//    function Write(const Buffer; Count: Longint): Longint;

    function ReadLn(const EOL: string): string; overload;
    function ReadLn: string; overload;
    procedure ReadCommand(var Command: string; var Params: string);
    function ReadStream(Dest: TStream): Longint;
    procedure ReadStrings(Value: TStrings; EOL: string); overload;
    procedure ReadStrings(Value: TStrings); overload;
    function WriteStream(Source: TStream): Longint;
    function WriteString(const Value: string): Cardinal;
    function WriteStrings(const Value: TStrings; EOL: string): Cardinal; overload;
    function WriteStrings(const Value: TStrings): Cardinal; overload;
    function WriteLn(const Value: string; EOL: string): Cardinal; overload;
    function WriteLn(const Value: string): Cardinal; overload;
    function WriteEOL(EOL: string): Cardinal; overload;
    function WriteEOL: Cardinal; overload;
    procedure WriteCommand(const Command: string; const Params: string = '');
    //EOFOnError:True socket not raise an error just make EOF flag
    property EOFOnError: Boolean read FEOFOnError write FEOFOnError default False;
    property EndOfLine: string read FEndOfLine write FEndOfLine;
  end;

implementation

{ TmnStream }

destructor TmnSocketStream.Destroy;
begin
  try
    Disconnect;
  finally
    inherited;
  end;
end;

function TmnSocketStream.Write(const Buffer; Count: Longint): Longint;
begin
  Result := 0;
  if not Connected then
    DoError('SocketStream not connected')
  else if WaitToWrite(FTimeout) then
  begin
    if Socket.Send(Buffer, Count) >= erClosed then
    begin
      FreeSocket;
      Result := 0;
    end
    else
      Result := Count;
  end
  else
  begin
    FreeSocket;
    Result := 0;
  end
end;

function TmnSocketStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := 0;
  if not Connected then
    DoError('SocketStream not connected')
  else
  begin
    if WaitToRead(FTimeout) then
    begin
      if (Socket = nil) or (Socket.Receive(Buffer, Count) >= erClosed) then
      begin
        FreeSocket;
        Result := 0;
      end
      else
        Result := Count;
    end
    else
    begin
      FreeSocket;
      Result := 0;
    end;
  end;
end;

function TmnSocketStream.Seek(Offset: Integer; Origin: Word): Longint;
begin
{$IFDEF FPC}
  Result := 0;
{$ENDIF}  
  raise Exception.Create('not supported')
end;

constructor TmnSocketStream.Create(vSocket: TmnCustomSocket);
begin
  inherited Create;
  FSocket := vSocket;
  FTimeout := cReadTimeout;
end;

function TmnSocketStream.WaitToRead(Timeout: Integer): Boolean;
var
  err:TmnError;
begin
  err := Socket.Select(Timeout, slRead); 
  Result := err = erNone;
end;

procedure TmnSocketStream.Disconnect;
begin
  Shutdown;//may be not but in slow matchine disconnect to take as effects as need (POS in 98) 
  FreeSocket;
end;

function TmnSocketStream.GetConnected: Boolean;
begin
  Result := (Socket <> nil);
end;

{ TmnConnectionStream }

function TmnConnectionStream.WriteString(const Value: string): Cardinal;
begin
  Result := Write(Pointer(Value)^, Length(Value));
end;

function TmnConnectionStream.WriteStrings(const Value: TStrings): Cardinal;
begin
  Result := WriteStrings(Value, EndOfLine);
end;

function TmnConnectionStream.WriteStream(Source: TStream): Longint;
const
  BufferSize = 4 * 1024;
var
  aBuffer: pchar;
  n: Integer;
begin
  GetMem(aBuffer, BufferSize);
  Result := 0;
  try
    repeat
      n := Source.Read(aBuffer^, BufferSize);
      if n > 0 then
        Write(aBuffer^, n);
      Inc(Result, n);
    until (n < BufferSize) or not Connected;
  finally
    FreeMem(aBuffer, BufferSize);
  end;
end;

function TmnConnectionStream.WriteLn(const Value: string; EOL: string): Cardinal;
begin
  Result := WriteString(Value + EOL);
end;

function TmnConnectionStream.WriteStrings(const Value: TStrings; EOL: string): Cardinal;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to Value.Count - 1 do
  begin
    if Value[i] <> '' then //stupid delphi always add empty line in last of TStringList
      Result := Result + WriteLn(Value[i], EOL);
  end;
end;

procedure TmnConnectionStream.ReadCommand(var Command, Params: string);
var
  s: string;
  p: Integer;
begin
  s := ReadLn;
  p := Pos(' ', s);
  if p > 0 then
  begin
    Command := Copy(s, 1, p - 1);
    Params := Copy(s, p + 1, MaxInt);
  end
  else
  begin
    Command := s;
    Params := '';
  end;
end;

function TmnConnectionStream.ReadLn: string;
begin
  Result := ReadLn(EndOfLine);
end;

procedure TmnConnectionStream.ReadStrings(Value: TStrings; EOL: string);
var
  s:string;
begin
  while Connected do
  begin
    S := ReadLn;
    if S <> '' then
      Value.Add(S);
  end;
end;

{function TmnConnectionStream.Write(const Buffer; Count: Integer): Longint;
begin
  Result := inherited Write(Buffer, Count);
end;}

procedure TmnConnectionStream.WriteCommand(const Command, Params: string);
begin
  if Params <> '' then
    WriteLn(UpperCase(Command) + ' ' + Params)
  else
    WriteLn(UpperCase(Command));
end;

function TmnConnectionStream.WriteEOL: Cardinal;
begin
  Result := WriteEOL(EndOfLine);  
end;

function TmnConnectionStream.WriteLn(const Value: string): Cardinal;
begin
  Result := WriteLn(Value, EndOfLine);
end;

function TmnConnectionStream.ReadStream(Dest: TStream): Longint;
const
  BufferSize = 4 * 1024;
var
  aBuffer: pchar;
  n: Integer;
begin
  {$ifdef FPC} //less hint in fpc
  aBuffer := nil;
  {$endif}
  GetMem(aBuffer, BufferSize);
  Result := 0;
  try
    repeat
      n := Read(aBuffer^, BufferSize);
      if n > 0 then
        Dest.Write(aBuffer^, n);
      Inc(Result, n);
    until (n < BufferSize) or not Connected;
  finally
    FreeMem(aBuffer, BufferSize);
  end;
end;

procedure TmnConnectionStream.ReadStrings(Value: TStrings);
begin
  ReadStrings(Value, EndOfLine);
end;

function TmnConnectionStream.WriteEOL(EOL: string): Cardinal;
begin
  Result := WriteString(EOL);
end;

{ TmnConnectionStream }

procedure TmnConnectionStream.DoError(S: string);
begin
  if FEOFOnError then
    FEOF := True
  else
    inherited;
end;

constructor TmnConnectionStream.Create(vSocket: TmnCustomSocket);
begin
  inherited;
  EndOfLine := sEndOfLine;
  FBufferSize := cBufferSize;
  GetMem(FBuffer, FBufferSize);
  FPos := FBuffer;
  FEnd := FBuffer;
end;

destructor TmnConnectionStream.Destroy;
begin
  FreeMem(FBuffer, FBufferSize);
  FBuffer := nil;
  inherited;
end;

procedure TmnConnectionStream.LoadBuffer;
var
  aSize: Cardinal;
begin
  if FPos < FEnd then
    raise EmnStreamException.Create('Buffer is not empty to load');
  FPos := FBuffer;
  aSize := inherited Read(FBuffer^, FBufferSize);
  FEnd := FPos + aSize;
  if aSize = 0 then
    FEOF := True;
end;

function TmnConnectionStream.Read(var Buffer; Count: Integer): Longint;
var
  c: Longint;
  P: PChar;
  aCount:Integer;
begin
  P := @Buffer;
  aCount := 0;
  while (Count > 0) and Connected do
  begin
    c := FEnd - FPos;
    if c = 0 then
    begin
      LoadBuffer;
      Continue;
    end;
    if c > Count then // is FBuffer enough for Count
      c := Count;
    Count := Count - c;
    aCount := aCount + c;
    System.Move(FPos^, P^, c);
    Inc(P, c);
    Inc(FPos, c);
  end;
  Result := aCount;
end;

function TmnConnectionStream.ReadLn(const EOL: string): string;
var
  aMatched: Boolean;
begin
  aMatched := False;
  ReadUntil(EOL, Result, aMatched);
  if aMatched and (Result <> '') then
    Result := LeftStr(Result, Length(Result) - Length(EOL));
end;

procedure TmnConnectionStream.ReadUntil(const UntilStr: string; var Result: string; var Matched: Boolean);
var
  P: PChar;
  function CheckBuffer: Boolean;
  begin
    if not (FPos < FEnd) then
      LoadBuffer;
    Result := (FPos < FEnd);
  end;
var
  idx, l: Integer;
  t: string;
begin
  if UntilStr = '' then
    raise Exception.Create('UntilStr is empty!');
  Idx := 1;
  Matched := False;
  l := Length(UntilStr);
  Result := '';
  while not Matched and CheckBuffer do
  begin
    P := FPos;
    while P < FEnd do
    begin
      if UntilStr[idx] = P^ then
        Inc(Idx)
      else
        Idx := 1;
      Inc(P);
      if Idx > l then
      begin
        Matched := True;
        break;
      end;
    end;
    SetString(t, FPos, P - FPos);
    Result := Result + t;
    FPos := P;
  end;
end;

procedure TmnSocketStream.Connect;
begin
  if Connected then
    raise EmnStreamException.Create('Already connected');
  if FSocket <> nil then
    raise EmnStreamException.Create('Socket must be nil');
  FSocket := CreateSocket;
  if FSocket = nil then
    raise EmnStreamException.Create('Connected fail');
end;

function TmnSocketStream.CreateSocket: TmnCustomSocket;
begin
  Result := nil;//if server connect no need to create socket
end;

function TmnSocketStream.WaitToWrite(Timeout: Integer): Boolean;
begin
  Result := Socket.Select(Timeout, slWrite) = erNone;
end;

procedure TmnSocketStream.FreeSocket;
begin
  FreeAndNil(FSocket);
end;

procedure TmnSocketStream.DoError(S: string);
begin
  raise EmnStreamException.Create(S);
end;

procedure TmnSocketStream.Shutdown;
begin
  if Socket <> nil then
    Socket.Shutdown(sdBoth);
end;

end.
