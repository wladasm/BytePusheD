unit unSound;

interface

uses
  Classes, MMSystem;

type
  TSoundStreamerParams = record
    Channels: Word;
    SamplesPerSec: Cardinal;
    BitsPerSample: Word;
    MaxBuffers: Integer;
  end;

  PSoundBuffer = ^TSoundBuffer;
  TSoundBuffer = record
    Header: TWaveHdr;
    Size: Cardinal;
    Data: array of Byte;
  end;

  // TODO: record -> class?
  TSoundStreamer = class(TObject)
  private
    FWaveOut: HWAVEOUT;
    FIsActive: Boolean;
    FIsVolumeSupported: Boolean;
    FIsLRVolumeSupported: Boolean;
    FMaxBuffers: Integer;
    FBuffers: TList; // of PSoundBuffer
    procedure OpenDevice(const AParams: TSoundStreamerParams);
    procedure CloseDevice;
    function Check(AErrorCode: MMRESULT): Boolean;
    procedure ShowError(AErrorCode: MMRESULT);
    function FindDoneBuffer: PSoundBuffer;
    procedure InitBuffer(ABuffer: PSoundBuffer; ASize: Cardinal);
    procedure UnprepareBuffers;
    procedure FreeBuffers;
  public
    constructor Create(const AParams: TSoundStreamerParams);
    destructor Destroy; override;
    function GetBuffer(ASize: Cardinal): PSoundBuffer;
    procedure PlayBuffer(ABuffer: PSoundBuffer);
    procedure CancelBuffer(ABuffer: PSoundBuffer);
    procedure StopPlaying;
    // not used now
    procedure SetDevVolume(const ALeftOrSingle, ARight: Single); // 0.0 .. 1.0
  public
    property IsActive: Boolean read FIsActive;
    property IsVolumeSupported: Boolean read FIsVolumeSupported; // general volume control
    property IsLRVolumeSupported: Boolean read FIsLRVolumeSupported; // separate left and right volume control
  end;

implementation

uses
  Windows, SysUtils;

{ TSoundStream }

procedure TSoundStreamer.CancelBuffer(ABuffer: PSoundBuffer);
begin
  Assert(FBuffers.IndexOf(ABuffer) >= 0);
  Assert((ABuffer.Header.dwFlags and WHDR_PREPARED) = 0);
  Assert((ABuffer.Header.dwFlags and WHDR_DONE) = 0);

  // mark the buffer as free and ready for reuse
  ABuffer.Header.dwFlags := WHDR_DONE;
end;

function TSoundStreamer.Check(AErrorCode: MMRESULT): Boolean;
begin
  Result := AErrorCode = MMSYSERR_NOERROR;
  if not Result then
  begin
    ShowError(AErrorCode);
    CloseDevice;
  end;
end;

procedure TSoundStreamer.CloseDevice;
begin
  if FIsActive then
  begin
    waveOutReset(FWaveOut);
    UnprepareBuffers;
    waveOutClose(FWaveOut);
    FIsActive := False;
  end;
end;

constructor TSoundStreamer.Create(const AParams: TSoundStreamerParams);
begin
  FMaxBuffers := AParams.MaxBuffers;
  FBuffers := TList.Create;

  OpenDevice(AParams);
end;

destructor TSoundStreamer.Destroy;
begin
  CloseDevice;

  FreeBuffers;
  Assert(FBuffers.Count = 0);
  FBuffers.Free;

  inherited;
end;

function TSoundStreamer.FindDoneBuffer: PSoundBuffer;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FBuffers.Count - 1 do
    if (PSoundBuffer(FBuffers[i]).Header.dwFlags and WHDR_DONE) <> 0 then
    begin
      Result := FBuffers[i];
      Exit;
    end;
end;

procedure TSoundStreamer.FreeBuffers;
var
  i: Integer;
  lcBuffer: PSoundBuffer;
begin
  for i := FBuffers.Count - 1 downto 0 do
  begin
    lcBuffer := PSoundBuffer(FBuffers[i]);
    FBuffers.Delete(i);
    Assert((lcBuffer.Header.dwFlags and WHDR_PREPARED) = 0);
    lcBuffer.Data := nil;
    Dispose(lcBuffer);
  end;
end;

function TSoundStreamer.GetBuffer(ASize: Cardinal): PSoundBuffer;
begin
  Assert(ASize > 0);

  if not FIsActive then
  begin
    Result := nil;
    Exit;
  end;

  Result := FindDoneBuffer;
  if Result <> nil then
  begin
    // reuse a buffer that has finished playing
    if (Result.Header.dwFlags and WHDR_PREPARED) <> 0 then
      Check(waveOutUnprepareHeader(FWaveOut, @Result.Header, SizeOf(Result.Header)));
    InitBuffer(Result, ASize);
  end
  else
    if FBuffers.Count < FMaxBuffers then
    begin
      // allocate new buffer
      New(Result);
      InitBuffer(Result, ASize);
      FBuffers.Add(Result);
    end
    else
      Result := nil; // buffer limit reached
end;

procedure TSoundStreamer.InitBuffer(ABuffer: PSoundBuffer; ASize: Cardinal);
begin
  ABuffer.Size := ASize;
  if Cardinal(Length(ABuffer.Data)) <> ASize then
    SetLength(ABuffer.Data, ASize);

  FillChar(ABuffer.Header, SizeOf(ABuffer.Header), 0);
  with ABuffer.Header do
  begin
    lpData := PAnsiChar(ABuffer.Data);
    dwBufferLength := ASize;
    dwFlags := 0;
  end;
end;

procedure TSoundStreamer.OpenDevice(const AParams: TSoundStreamerParams);
var
  lcWaveFormat: TWaveFormatEx;
  lcDevCaps: TWaveOutCaps;
begin
  FIsActive := False;

  FillChar(lcWaveFormat, SizeOf(lcWaveFormat), 0);
  with lcWaveFormat do
  begin
    wFormatTag := WAVE_FORMAT_PCM;
    nChannels := AParams.Channels;
    nSamplesPerSec := AParams.SamplesPerSec;
    wBitsPerSample := AParams.BitsPerSample;
    nBlockAlign := (nChannels * wBitsPerSample) div 8;
    nAvgBytesPerSec := nSamplesPerSec * nBlockAlign;
  end;

  if Check(waveOutOpen(@FWaveOut, WAVE_MAPPER, @lcWaveFormat, 0, 0,
    CALLBACK_NULL)) then
      FIsActive := True;

  Check(waveOutGetDevCaps(FWaveOut, @lcDevCaps, SizeOf(lcDevCaps)));
  FIsVolumeSupported := (lcDevCaps.dwSupport and WAVECAPS_VOLUME) <> 0;
  FIsLRVolumeSupported := (lcDevCaps.dwSupport and WAVECAPS_LRVOLUME) <> 0;
end;

procedure TSoundStreamer.PlayBuffer(ABuffer: PSoundBuffer);
begin
  Assert(FBuffers.IndexOf(ABuffer) >= 0);
  Assert((ABuffer.Header.dwFlags and WHDR_PREPARED) = 0);
  Assert((ABuffer.Header.dwFlags and WHDR_DONE) = 0);

  if not FIsActive then
  begin
    CancelBuffer(ABuffer);
    Exit;
  end;

  Check(waveOutPrepareHeader(FWaveOut, @ABuffer.Header, SizeOf(ABuffer.Header)));
  Check(waveOutWrite(FWaveOut, @ABuffer.Header, SizeOf(ABuffer.Header)));
end;

procedure TSoundStreamer.SetDevVolume(const ALeftOrSingle, ARight: Single);
var
  lcLeft, lcRight: Word;
  lcVolume: Cardinal;
begin
  Assert((ALeftOrSingle >= 0.0) and (ALeftOrSingle <= 1.0));
  Assert((ARight >= 0.0) and (ARight <= 1.0));
  Assert(FIsLRVolumeSupported or (ARight = 0.0));

  if not FIsActive or not FIsVolumeSupported then
    Exit;

  lcLeft := Trunc($FFFF * ALeftOrSingle);
  lcRight := Trunc($FFFF * ARight);
  lcVolume := (lcRight shl 16) or lcLeft;
  Check(waveOutSetVolume(FWaveOut, lcVolume));
end;

procedure TSoundStreamer.ShowError(AErrorCode: MMRESULT);
var
  lcErrorText: array[0..255] of Char;
begin
  Assert(AErrorCode <> MMSYSERR_NOERROR);
  if waveOutGetErrorText(AErrorCode, lcErrorText,
    Length(lcErrorText) {size in chars!} ) = MMSYSERR_NOERROR then
      MessageBox(0, PChar(Format('Sound error: %s', [lcErrorText])), 'Error',
        MB_ICONERROR or MB_OK)
  else
    MessageBox(0, 'Sound error!', 'Error', MB_ICONERROR or MB_OK);
end;

procedure TSoundStreamer.StopPlaying;
begin
  if not FIsActive then
    Exit;

  Check(waveOutReset(FWaveOut));
end;

procedure TSoundStreamer.UnprepareBuffers;
var
  i: Integer;
  lcBuffer: PSoundBuffer;
begin
  Assert(FIsActive);

  for i := 0 to FBuffers.Count - 1 do
  begin
    lcBuffer := PSoundBuffer(FBuffers[i]);
    if (lcBuffer.Header.dwFlags and WHDR_PREPARED) <> 0 then
      // unprepare and ignore possible errors
      waveOutUnprepareHeader(FWaveOut, @lcBuffer.Header, SizeOf(lcBuffer.Header));
  end;
end;

end.
