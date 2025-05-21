unit fmMain;

interface

uses
  Classes, Forms, Windows, SysUtils, Dialogs, Controls, StdCtrls, ExtCtrls,
  ComCtrls, AppEvnts, MMSystem, Menus, Buttons, ActnList, unVM, unStopwatch,
  unSound;

const
  c_ProgramName = 'BytePusher';
  c_ProgramVersion = '0.01';
  c_ProgramYear = '2025';
  c_ProgramCopyright = 'Dan Peroff';

  c_SoundBufferSize = 8 * c_BytePusherSoundBufSize;
  c_MaxSoundBuffers = 10;
  c_DefaultSoundValue = 10; // %

type
  TScreenBitmapInfo = packed record
    bmiHeader: TBitmapInfoHeader;
    bmiColors: array[Byte] of TRGBQuad;
  end;

  PScreenPixels = ^TScreenPixels;
  TScreenPixels = array[0..c_BytePusherScrHeight - 1,
    0..c_BytePusherScrWidth - 1] of Byte;

  TStatusItem = (siState = 0, siFPS, siCalcTime, siRenderTime, siDrawingTime,
    siSoundTime);

  TMainForm = class(TForm)
    pbScreen: TPaintBox;
    odSnapshot: TOpenDialog;
    stbStatus: TStatusBar;
    tmrBenchmarks: TTimer;
    AppEvents: TApplicationEvents;
    MainMenu: TMainMenu;
    miFile: TMenuItem;
    miOpen: TMenuItem;
    miSeparator1: TMenuItem;
    miExit: TMenuItem;
    miRun: TMenuItem;
    miDoRun: TMenuItem;
    miNextFrame: TMenuItem;
    miPause: TMenuItem;
    miReset: TMenuItem;
    miOptions: TMenuItem;
    miVolume: TMenuItem;
    miBenchmarks: TMenuItem;
    miHelp: TMenuItem;
    miAbout: TMenuItem;
    ActionList: TActionList;
    acOpen: TAction;
    acExit: TAction;
    acRun: TAction;
    acNextFrame: TAction;
    acPause: TAction;
    acReset: TAction;
    acBenchmarks: TAction;
    acAbout: TAction;
    pnlKeyboard: TPanel;
    pnlScreen: TPanel;
    procedure pbScreenPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tmrBenchmarksTimer(Sender: TObject);
    procedure AppEventsIdle(Sender: TObject; var Done: Boolean);
    procedure acOpenExecute(Sender: TObject);
    procedure acExitExecute(Sender: TObject);
    procedure acRunExecute(Sender: TObject);
    procedure acNextFrameExecute(Sender: TObject);
    procedure acPauseExecute(Sender: TObject);
    procedure acResetExecute(Sender: TObject);
    procedure acAboutExecute(Sender: TObject);
    procedure acBenchmarksExecute(Sender: TObject);
    procedure pnlScreenResize(Sender: TObject);
  private
    FVM: TBytePusherVM;
    FVMKeyStates: TBytePusherKeyStates;
    FScreenBitmapInfo: TScreenBitmapInfo;
    FScreenPixels: PScreenPixels;
    FSoundStreamer: TSoundStreamer;
    FSoundBuffer: TSoundBuffer;
    FSoundPos: Cardinal;
    FIsSoundEnabled: Boolean;
    FSoundVolume: Double; // 0.0 .. 1.0
    FIsSnapshotLoaded: Boolean;
    FLoadedSnapshotPath: string;
    FIsRunning: Boolean;
    FTimerFreq: Int64;
    FFramePeriod: Int64;
    FFrameTimer: Int64;
    FFrameCount: Integer;
    FPrevFrameTime: Int64;
    FPrevBenchmarksTime: Int64;
    FFrameCalcTime: TStopwatch; // for benchmarks
    FFrameRenderTime: TStopwatch; // for benchmarks
    FFrameDrawCount: Integer; // for benchmarks
    FFrameDrawingTime: TStopwatch; // for benchmarks
    FSoundSystemTime: TStopwatch; // for benchmarks
    procedure CreateScreen;
    procedure CreateKeyboard;
    procedure CreateSoundStreamer;
    procedure CreateBenchmarkTimers;
    procedure FreeBenchmarkTimers;
    procedure CreateVolumeMenu;
    procedure AutoLoadFile;
    procedure UpdateScreen;
    procedure DrawScreen(ADC: HDC; ADstX, ADstY, ADstWidth, ADstHeight: Integer);
    procedure DoVMFrame;
    procedure PlaySound;
    procedure FreeSoundBuffer;
    procedure SetIsRunning(AIsRunning: Boolean);
    procedure LoadSnapshot(const AFileName: string; ARun: Boolean);
    procedure SetStatus(AItem: TStatusItem; const AFormat: string;
      const AArgs: array of const);
    function UpdateFrameIfNeeded: Boolean;
    procedure UpdateActions; reintroduce;
    procedure UpdateStatus;
    function IsBenchmarkingActive: Boolean; inline;
    procedure UpdateBenchmarks;
    procedure ResetBenchmarks;
    procedure SoundVolumeItemClick(Sender: TObject);
    procedure VMKeyMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure VMKeyMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  Math;

procedure TMainForm.acAboutExecute(Sender: TObject);
var
  lcText: string;
begin
  { "About..." }
  lcText := Format('%s v%s'#13#13'Copyright (c) %s %s',
    [c_ProgramName, c_ProgramVersion, c_ProgramYear, c_ProgramCopyright]);
  Application.MessageBox(PChar(lcText), 'About', MB_ICONINFORMATION or MB_OK);
end;

procedure TMainForm.acBenchmarksExecute(Sender: TObject);
begin
  { "Show benchmarks" }
  if IsBenchmarkingActive then
  begin
    tmrBenchmarks.Enabled := True;
    ResetBenchmarks;
  end
  else
    tmrBenchmarks.Enabled := False;
  UpdateBenchmarks;
end;

procedure TMainForm.acExitExecute(Sender: TObject);
begin
  { "Exit" }
  Close;
end;

procedure TMainForm.acNextFrameExecute(Sender: TObject);
begin
  { "Next frame" }
  DoVMFrame;
end;

procedure TMainForm.acOpenExecute(Sender: TObject);
begin
  { "Open..." }
  if odSnapshot.Execute then
    LoadSnapshot(odSnapshot.FileName, True);
end;

procedure TMainForm.acPauseExecute(Sender: TObject);
begin
  { "Pause" }
  SetIsRunning(False);
  UpdateActions;
  UpdateStatus;
  UpdateBenchmarks;
end;

procedure TMainForm.acResetExecute(Sender: TObject);
begin
  { "Reset" }
  LoadSnapshot(FLoadedSnapshotPath, FIsRunning);
  UpdateScreen;
end;

procedure TMainForm.acRunExecute(Sender: TObject);
begin
  { "Run" }
  SetIsRunning(True);
  UpdateActions;
  UpdateStatus;
  UpdateBenchmarks;
end;

procedure TMainForm.AppEventsIdle(Sender: TObject; var Done: Boolean);
begin
  if not FIsRunning then
    Exit;

  if not UpdateFrameIfNeeded then
    Sleep(1);

  Done := False;
end;

procedure TMainForm.AutoLoadFile;
var
  lcFileToLoad: string;
begin
  {$IFDEF DEBUG}
  lcFileToLoad := 'Snapshots\Sprites.BytePusher';
  {$ENDIF}

  if ParamCount > 0 then
    lcFileToLoad := ParamStr(1);
  if (lcFileToLoad <> '') and FileExists(lcFileToLoad) then
    LoadSnapshot(lcFileToLoad, True);
end;

procedure TMainForm.CreateBenchmarkTimers;
begin
  FFrameCalcTime := TStopwatch.Create;
  FFrameRenderTime := TStopwatch.Create;
  FFrameDrawingTime := TStopwatch.Create;
  FSoundSystemTime := TStopwatch.Create;
end;

procedure TMainForm.CreateKeyboard;
const
  c_TopSpace = 25;
  c_KeySize = 50;
  c_FontSize = 14;
var
  lcRows, lcCols, lcSideSpace, i, j: Integer;
  lcKey: TBytePusherKey;
begin
  lcRows := Length(c_BytePusherKeysLayout);
  lcCols := Length(c_BytePusherKeysLayout[0]);
  lcSideSpace := (pnlKeyboard.Width - lcCols * c_KeySize) div 2;
  for i := 0 to lcRows - 1 do
    for j := 0 to lcCols - 1 do
    begin
      lcKey := c_BytePusherKeysLayout[i, j];
      with TSpeedButton.Create(pnlKeyboard) do
      begin
        Parent := pnlKeyboard;
        Caption := c_BytePusherKeyNames[lcKey];
        Tag := Ord(lcKey);
        Font.Size := c_FontSize;
        Left := lcSideSpace + c_KeySize * j;
        Top := c_TopSpace + c_KeySize * i;
        Width := c_KeySize;
        Height := c_KeySize;
        OnMouseDown := VMKeyMouseDown;
        OnMouseUp := VMKeyMouseUp;
      end;
    end;
end;

procedure TMainForm.CreateScreen;
var
  lcColor: Integer;
  lcR, lcG, lcB: Byte;
begin
  FillChar(FScreenBitmapInfo, SizeOf(FScreenBitmapInfo), 0);
  with FScreenBitmapInfo.bmiHeader do
  begin
    biSize := SizeOf(TBitmapInfoHeader);
    biWidth := c_BytePusherScrWidth;
    biHeight := -c_BytePusherScrHeight; // the first line is on top
    biPlanes := 1;
    biBitCount := 8; // 8-bit indices in the color table
    biCompression := BI_RGB;
  end;

  // create BytePusher's color table
  for lcColor := 0 to 255 do
  begin
    if lcColor < 216 then
    begin
      lcR := lcColor div 36;
      lcG := (lcColor - lcR * 36) div 6;
      lcB := lcColor mod 6;
    end
    else begin
      lcR := 0;
      lcG := 0;
      lcB := 0;
    end;

    with FScreenBitmapInfo.bmiColors[lcColor] do
    begin
      rgbRed := lcR * $33;
      rgbGreen := lcG * $33;
      rgbBlue := lcB * $33;
      // rgbReserved already zeroed
    end;
  end;

  New(FScreenPixels);
  FillChar(FScreenPixels^, SizeOf(FScreenPixels^), 0);
end;

procedure TMainForm.CreateSoundStreamer;
var
  lcParams: TSoundStreamerParams;
begin
  with lcParams do
  begin
    Channels := c_BytePusherSoundChannels;
    SamplesPerSec := c_BytePusherSamplesPerSec;
    BitsPerSample := c_BytePusherBitsPerSample;
    MaxBuffers := c_MaxSoundBuffers;
  end;
  FSoundStreamer := TSoundStreamer.Create(lcParams);
end;

procedure TMainForm.CreateVolumeMenu;

  function CreateItem(AVolume: Integer): TMenuItem;
  begin
    Result := TMenuItem.Create(MainMenu);
    miVolume.Add(Result);
    with Result do
    begin
      case AVolume of
        0: Caption := '&Mute';
        100: Caption := '1&00%';
      else
        Caption := Format('&%d%%', [AVolume]);
      end;
      Tag := AVolume;
      RadioItem := True;
      AutoCheck := True;
      OnClick := SoundVolumeItemClick;
    end;
  end; // CreateItem

var
  i, lcVolume: Integer;
  lcItem, lcActiveItem: TMenuItem;
begin
  lcActiveItem := nil; // anti-warning
  for i := 10 downto 0 do
  begin
    lcVolume := i * 10; // 0..100%
    lcItem := CreateItem(lcVolume);
    if lcVolume = c_DefaultSoundValue then
      lcActiveItem := lcItem;
  end;

  lcActiveItem.Checked := True;
  SoundVolumeItemClick(lcActiveItem);
end;

procedure TMainForm.DoVMFrame;
begin
  FVM.SetKeyStates(FVMKeyStates);

  if IsBenchmarkingActive then
    FFrameCalcTime.Start;
  try
    FVM.CalcNextFrame;
  finally
    if IsBenchmarkingActive then
      FFrameCalcTime.Stop;
  end;

  UpdateScreen;

  PlaySound;

  if IsBenchmarkingActive then
    Inc(FFrameCount);
end;

procedure TMainForm.DrawScreen(ADC: HDC; ADstX, ADstY, ADstWidth,
  ADstHeight: Integer);
begin
  if IsBenchmarkingActive then
    FFrameDrawingTime.Start;
  try
    StretchDIBits(ADC, ADstX, ADstY, ADstWidth, ADstHeight,
      0, 0, c_BytePusherScrWidth, c_BytePusherScrHeight,
        FScreenPixels, PBitmapInfo(@FScreenBitmapInfo)^, DIB_RGB_COLORS, SRCCOPY);
  finally
    if IsBenchmarkingActive then
    begin
      FFrameDrawingTime.Stop;
      Inc(FFrameDrawCount);
    end;
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  Caption := c_ProgramName;

  timeBeginPeriod(1); // for more accurate delay on Sleep(1)

  QueryPerformanceFrequency(FTimerFreq);
  FFramePeriod := FTimerFreq div c_BytePusherFPS; // 1 / c_BytePusherFPS * FTimerFreq

  FVM := TBytePusherVM.Create;
  CreateScreen;
  CreateKeyboard;
  CreateSoundStreamer;
  CreateVolumeMenu;
  CreateBenchmarkTimers;

  SetIsRunning(False);
  UpdateActions;
  UpdateStatus;
  UpdateBenchmarks;

  AutoLoadFile;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeBenchmarkTimers;
  FSoundStreamer.Free;
  Dispose(FScreenPixels);
  FVM.Free;

  timeEndPeriod(1);
end;

procedure TMainForm.FreeBenchmarkTimers;
begin
  FSoundSystemTime.Free;
  FFrameDrawingTime.Free;
  FFrameRenderTime.Free;
  FFrameCalcTime.Free;
end;

procedure TMainForm.FreeSoundBuffer;
begin
  if FSoundBuffer <> nil then
  begin
    FSoundStreamer.CancelBuffer(FSoundBuffer);
    FSoundBuffer := nil;
  end;
end;

function TMainForm.IsBenchmarkingActive: Boolean;
begin
  Result := FIsRunning and acBenchmarks.Checked;
end;

procedure TMainForm.LoadSnapshot(const AFileName: string; ARun: Boolean);
begin
  FVM.LoadSnapshot(AFileName);

  FIsSnapshotLoaded := True;
  FLoadedSnapshotPath := AFileName;
  Caption := Format('%s - %s', [ExtractFileName(FLoadedSnapshotPath), c_ProgramName]);

  SetIsRunning(ARun);

  FSoundStreamer.StopPlaying;
  FreeSoundBuffer;

  UpdateActions;
  UpdateStatus;
  UpdateBenchmarks;
end;

procedure TMainForm.pbScreenPaint(Sender: TObject);
begin
  DrawScreen(pbScreen.Canvas.Handle, 0, 0, pbScreen.ClientWidth,
    pbScreen.ClientHeight);
end;

procedure TMainForm.PlaySound;
var
  lcVMSound: PByte;
  i: Integer;
  lcSample: Byte;
begin
  if IsBenchmarkingActive then
    FSoundSystemTime.Start;
  try
    if not FSoundStreamer.IsActive then
    begin
      FreeSoundBuffer;
      Exit;
    end;

    if FSoundBuffer = nil then
    begin
      Assert((c_SoundBufferSize mod c_BytePusherSoundBufSize) = 0);
      FSoundBuffer := FSoundStreamer.GetBuffer(c_SoundBufferSize);
      if FSoundBuffer = nil then
        Exit; // max buffers allocated, no free one
      FSoundPos := 0;
    end;

    lcVMSound := FVM.GetSoundBuf;
    Assert((FSoundBuffer.Size - FSoundPos) >= c_BytePusherSoundBufSize);
    Assert((FSoundVolume >= 0.0) and (FSoundVolume <= 1.0));
    if FIsSoundEnabled then
    begin
      // volume > 0
      for i := 0 to c_BytePusherSoundBufSize - 1 do
      begin
        lcSample := Round(ShortInt(lcVMSound[i]) * FSoundVolume) + $80 {signed sample -> unsigned};
        FSoundBuffer.Data[FSoundPos] := lcSample;
        Inc(FSoundPos);
      end;
    end
    else begin
      // volume = 0, little optimization
      FillChar(FSoundBuffer.Data[FSoundPos], c_BytePusherSoundBufSize, $80 {silence} );
      Inc(FSoundPos, c_BytePusherSoundBufSize);
    end;

    if FSoundPos = FSoundBuffer.Size then
    begin
      if FIsRunning and FIsSoundEnabled then
      begin
        FSoundStreamer.PlayBuffer(FSoundBuffer);
        FSoundBuffer := nil;
      end
      else
        FSoundPos := 0; // in "next frame" mode don't play sound, just clear buffer
    end;
  finally
    if IsBenchmarkingActive then
      FSoundSystemTime.Stop;
  end;
end;

procedure TMainForm.pnlScreenResize(Sender: TObject);
var
  lcScrSize: Integer;
begin
  lcScrSize := Min(pnlScreen.Width, pnlScreen.Height);
  pbScreen.Left := (pnlScreen.Width - lcScrSize) div 2;
  pbScreen.Top := (pnlScreen.Height - lcScrSize) div 2;
  pbScreen.Width := lcScrSize;
  pbScreen.Height := lcScrSize;
end;

procedure TMainForm.ResetBenchmarks;
begin
  FFrameCount := 0;
  FFrameDrawCount := 0;
  FFrameCalcTime.Reset;
  FFrameRenderTime.Reset;
  FFrameDrawingTime.Reset;
  FSoundSystemTime.Reset;
  QueryPerformanceCounter(FPrevBenchmarksTime);
end;

procedure TMainForm.SetIsRunning(AIsRunning: Boolean);
begin
  FIsRunning := AIsRunning;
  tmrBenchmarks.Enabled := IsBenchmarkingActive;
  if FIsRunning then
  begin
    FFrameTimer := 0;
    QueryPerformanceCounter(FPrevFrameTime);
    ResetBenchmarks;
  end
  else
    FSoundStreamer.StopPlaying;
end;

procedure TMainForm.SetStatus(AItem: TStatusItem; const AFormat: string;
  const AArgs: array of const);
begin
  stbStatus.Panels[Ord(AItem)].Text := Format(AFormat, AArgs);
end;

procedure TMainForm.SoundVolumeItemClick(Sender: TObject);
var
  lcVolume: Integer;
begin
  lcVolume := (Sender as TMenuItem).Tag;
  Assert((lcVolume >= 0) and (lcVolume <= 100));
  FIsSoundEnabled := lcVolume > 0;
  FSoundVolume := lcVolume / 100;
  if not FIsSoundEnabled then
  begin
    FSoundStreamer.StopPlaying;
    FreeSoundBuffer;
  end;
end;

procedure TMainForm.tmrBenchmarksTimer(Sender: TObject);
begin
  UpdateBenchmarks;
end;

procedure TMainForm.UpdateActions;
begin
  acRun.Enabled := FIsSnapshotLoaded and not FIsRunning;
  acNextFrame.Enabled := FIsSnapshotLoaded and not FIsRunning;
  acPause.Enabled := FIsSnapshotLoaded and FIsRunning;
  acReset.Enabled := FIsSnapshotLoaded;
end;

procedure TMainForm.UpdateBenchmarks;
var
  lcCurTime: Int64;
  lcFPS, lcCalcTime, lcRenderTime, lcDrawingTime, lcSoundTime: Double;
begin
  if not IsBenchmarkingActive then
  begin
    SetStatus(siFPS, '', []);
    SetStatus(siCalcTime, '', []);
    SetStatus(siRenderTime, '', []);
    SetStatus(siDrawingTime, '', []);
    SetStatus(siSoundTime, '', []);
    Exit;
  end;

  QueryPerformanceCounter(lcCurTime);
  lcFPS := FFrameCount / ((lcCurTime - FPrevBenchmarksTime) / FTimerFreq);
  SetStatus(siFPS, 'FPS: %d', [Trunc(lcFPS)]);

  if FFrameCount > 0 then
  begin
    lcCalcTime := FFrameCalcTime.ElapsedMillisecondsF / FFrameCount;
    lcRenderTime := FFrameRenderTime.ElapsedMillisecondsF / FFrameCount;
  end
  else begin
    lcCalcTime := 0.0;
    lcRenderTime := 0.0;
  end;
  SetStatus(siCalcTime, 'VM: %.2f ms', [lcCalcTime]);
  SetStatus(siRenderTime, 'Render: %.2f ms', [lcRenderTime]);

  if FFrameDrawCount > 0 then
    lcDrawingTime := FFrameDrawingTime.ElapsedMillisecondsF / FFrameDrawCount
  else
    lcDrawingTime := 0.0;
  SetStatus(siDrawingTime, 'Draw: %.2f ms', [lcDrawingTime]);

  if FFrameCount > 0 then
    lcSoundTime := FSoundSystemTime.ElapsedMillisecondsF / FFrameCount
  else
    lcSoundTime := 0.0;
  SetStatus(siSoundTime, 'Sound: %.2f ms', [lcSoundTime]);

  ResetBenchmarks;
end;

function TMainForm.UpdateFrameIfNeeded: Boolean;
var
  lcCurTime, lcDeltaTime: Int64;
begin
  QueryPerformanceCounter(lcCurTime);
  lcDeltaTime := lcCurTime - FPrevFrameTime;
  Inc(FFrameTimer, lcDeltaTime);
  if FFrameTimer >= FFramePeriod then
  begin
    FFrameTimer := FFrameTimer mod FFramePeriod;
    DoVMFrame;
    Result := True;
  end
  else
    Result := False;
  FPrevFrameTime := lcCurTime;
end;

procedure TMainForm.UpdateScreen;
var
  lcScreenBuf: PByte;
begin
  if IsBenchmarkingActive then
    FFrameRenderTime.Start;
  try
    lcScreenBuf := FVM.GetScreenBuf;
    // Remember: all scanlines in the DIB (FScreenPixels) must be 4-byte aligned.
    // Since we have 256 bytes per line, this requirement is already met.
    Assert(((c_BytePusherScrWidth * SizeOf(Byte)) mod 4) = 0);
    Assert(SizeOf(FScreenPixels^) = c_BytePusherScrBufSize);
    Move(lcScreenBuf^, FScreenPixels^, c_BytePusherScrBufSize);
  finally
    if IsBenchmarkingActive then
      FFrameRenderTime.Stop;
  end;

  pbScreen.Invalidate;
end;

procedure TMainForm.UpdateStatus;
begin
  if not FIsSnapshotLoaded then
    SetStatus(siState, 'Snapshot not loaded', [])
  else
    if FIsRunning then
      SetStatus(siState, 'Running', [])
    else
      SetStatus(siState, 'Paused', []);
end;

procedure TMainForm.VMKeyMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  lcKey: TBytePusherKey;
begin
  lcKey := TBytePusherKey((Sender as TSpeedButton).Tag);
  FVMKeyStates[lcKey] := True;
end;

procedure TMainForm.VMKeyMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  lcKey: TBytePusherKey;
begin
  lcKey := TBytePusherKey((Sender as TSpeedButton).Tag);
  FVMKeyStates[lcKey] := False;
end;

end.
