unit unVM;

interface

type
  TBytePusherKey = (bpkKey0, bpkKey1, bpkKey2, bpkKey3, bpkKey4, bpkKey5,
    bpkKey6, bpkKey7, bpkKey8, bpkKey9, bpkKeyA, bpkKeyB, bpkKeyC, bpkKeyD,
    bpkKeyE, bpkKeyF);

const
  c_BytePusherAddrSize = 3 * SizeOf(Byte);
  c_BytePusherCmdSize = 3 * c_BytePusherAddrSize;
  c_BytePusherMemSize = 256 * 256 * 256;
  c_BytePusherMemAlloc = c_BytePusherMemSize + c_BytePusherCmdSize - 1;

  c_BytePusherScrWidth = 256;
  c_BytePusherScrHeight = 256;
  c_BytePusherScrBufSize = c_BytePusherScrWidth * c_BytePusherScrHeight * SizeOf(Byte);
  c_BytePusherFPS = 60;

  c_BytePusherKeyNames: array[TBytePusherKey] of string = ('0', '1', '2', '3',
    '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F');
  c_BytePusherKeysLayout: array[0..3, 0..3] of TBytePusherKey = (
    (bpkKey1, bpkKey2, bpkKey3, bpkKeyC),
    (bpkKey4, bpkKey5, bpkKey6, bpkKeyD),
    (bpkKey7, bpkKey8, bpkKey9, bpkKeyE),
    (bpkKeyA, bpkKey0, bpkKeyB, bpkKeyF));

type
  TBytePusherKeyStates = array[TBytePusherKey] of Boolean;

  TBytePusherVM = class(TObject)
  private
    FMem: array[0..c_BytePusherMemAlloc - 1] of Byte;
    procedure ZeroMemory;
  public
    procedure SetKeyStates(const AStates: TBytePusherKeyStates);
    procedure CalcNextFrame;
    function GetScreenBuf: PByte;
    procedure LoadSnapshot(const AFileName: string);
  end;

implementation

uses
  Classes, SysUtils;

function Get3(AMem: PByte; AAddr: Cardinal): Cardinal; inline;
begin
  Assert(AAddr <= (c_BytePusherMemAlloc - c_BytePusherAddrSize));
  Result := (AMem[AAddr] shl 16) or (AMem[AAddr + 1] shl 8) or AMem[AAddr + 2];
end;

{ TBytePusherVM }

procedure TBytePusherVM.CalcNextFrame;
var
  lcPC: Cardinal;
  i: Integer;
begin
  lcPC := Get3(@FMem, 2);

  // Addr 6: A value of XXYY means: audio sample ZZ is at address XXYYZZ

  for i := 1 to 65536 do
  begin
    FMem[Get3(@FMem, lcPC + 3)] := FMem[Get3(@FMem, lcPC)];
    lcPC := Get3(@FMem, lcPC + 6);
  end;

  // TODO: play sound
end;

function TBytePusherVM.GetScreenBuf: PByte;
var
  lcScr: Cardinal;
begin
  lcScr := FMem[5] shl 16;
  Assert(lcScr <= (c_BytePusherMemSize - c_BytePusherScrBufSize));
  Result := @FMem[lcScr];
end;

procedure TBytePusherVM.LoadSnapshot(const AFileName: string);
var
  lcFile: TFileStream;
  lcSize: Int64;
begin
  try
    lcFile := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      lcSize := lcFile.Size;
      if lcSize = 0 then
        raise Exception.Create('File is empty, nothing to load');
      if lcSize > c_BytePusherMemSize then
        raise Exception.Create('File size is too large');

      ZeroMemory;
      lcFile.ReadBuffer(FMem[0], lcSize);
    finally
      lcFile.Free;
    end;
  except
    on E: Exception do
      raise Exception.Create('Error loading snapshot. ' + E.Message);
  end;
end;

procedure TBytePusherVM.SetKeyStates(const AStates: TBytePusherKeyStates);

  function EncodeStates(AFirst, ALast: TBytePusherKey): Byte;
  var
    lcKey: TBytePusherKey;
  begin
    Assert((Ord(ALast) - Ord(AFirst) + 1) = 8);
    Result := 0;
    for lcKey := AFirst to ALast do
      if AStates[lcKey] = True then
        Result := Result or (1 shl (Ord(lcKey) - Ord(AFirst)));
  end;  // EncodeStates

begin
  FMem[0] := EncodeStates(bpkKey8, bpkKeyF);
  FMem[1] := EncodeStates(bpkKey0, bpkKey7);
end;

procedure TBytePusherVM.ZeroMemory;
begin
  FillChar(FMem[0], Length(FMem), 0);
end;

end.
