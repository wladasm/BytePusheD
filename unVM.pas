unit unVM;

interface

const
  c_BytePusherCmdSize = 3 * 3;
  c_BytePusherMemSize = 256 * 256 * 256;
  c_BytePusherMemAlloc = c_BytePusherMemSize + c_BytePusherCmdSize - 1;
  c_BytePusherScrWidth = 256;
  c_BytePusherScrHeight = 256;

type
  TBytePusherVM = class(TObject)
  private
    FMem: array [0..c_BytePusherMemAlloc - 1] of Byte;
    procedure ZeroMemory;
    function Get3(AAddr: Cardinal): Cardinal;
  public
    constructor Create;
    destructor Destroy; override;
    procedure CalcNextFrame;
    function GetScreenBuf: PByte;
    procedure LoadSnapshot(const AFileName: string);
  end;

implementation

uses
  Classes, SysUtils;

{ TBytePusherVM }

procedure TBytePusherVM.CalcNextFrame;
var
  lcPC: Cardinal;
  i: Integer;
begin
  // TODO: set key states
  FMem[0] := 0;
  FMem[1] := 0;

  lcPC := Get3(2);

  // Addr 5: A value of ZZ means: pixel(XX, YY) is at address ZZYYXX
  // Addr 6: A value of XXYY means: audio sample ZZ is at address XXYYZZ

  for i := 1 to 65536 do
  begin
    FMem[Get3(lcPC + 3)] := FMem[Get3(lcPC)];
    lcPC := Get3(lcPC + 6);
  end;

  // TODO: play sound
end;

constructor TBytePusherVM.Create;
begin

end;

destructor TBytePusherVM.Destroy;
begin

  inherited;
end;

function TBytePusherVM.Get3(AAddr: Cardinal): Cardinal;
begin
  Assert(AAddr < c_BytePusherMemSize);
  Result := (FMem[AAddr] shl 16) or (FMem[AAddr + 1] shl 8) or FMem[AAddr + 2];
end;

function TBytePusherVM.GetScreenBuf: PByte;
var
  lcScr: Cardinal;
begin
  lcScr := FMem[5] shl 16;
  Assert(lcScr < c_BytePusherMemSize);
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

procedure TBytePusherVM.ZeroMemory;
var
  i: Integer;
begin
  for i := 0 to Length(FMem) - 1 do
    FMem[i] := 0;
end;

end.
