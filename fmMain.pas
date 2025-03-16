unit fmMain;

interface

uses
  Classes, Forms, Windows, SysUtils, Dialogs, Controls, StdCtrls, ExtCtrls,
  ComCtrls, AppEvnts, MMSystem, Menus, ActnList, unVM, unStopwatch;

type
  TScreenBitmapInfo = packed record
    bmiHeader: TBitmapInfoHeader;
    bmiColors: array[Byte] of TRGBQuad;
  end;

  PScreenPixels = ^TScreenPixels;
  TScreenPixels = array [0..c_BytePusherScrHeight - 1,
    0..c_BytePusherScrWidth - 1] of Byte;

  TStatusItem = (siState = 0, siFPS, siCalcTime, siRenderTime, siDrawingTime);

  TMainForm = class(TForm)
    pbScreen: TPaintBox;
    odROM: TOpenDialog;
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
    miSound: TMenuItem;
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
    acSound: TAction;
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
    procedure acSoundExecute(Sender: TObject);
    procedure acAboutExecute(Sender: TObject);
    procedure acBenchmarksExecute(Sender: TObject);
    procedure pnlScreenResize(Sender: TObject);
  private
    FVM: TBytePusherVM;
    FScreenBitmapInfo: TScreenBitmapInfo;
    FScreenPixels: PScreenPixels;
    FIsROMLoaded: Boolean;
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
    procedure CreateScreen;
    procedure UpdateScreen(AVMScreenBuf: PByte);
    procedure DrawScreen(ADC: HDC; ADstX, ADstY, ADstWidth, ADstHeight: Integer);
    procedure DoVMFrame;
    procedure SetIsRunning(AIsRunning: Boolean);
    procedure LoadROM(const AFileName: string; ARun: Boolean);
    procedure SetStatus(AItem: TStatusItem; const AFormat: string;
      const AArgs: array of const);
    procedure UpdateFrameIfNeeded(ACanSleep: Boolean);
    procedure UpdateActions; reintroduce;
    procedure UpdateStatus(AForceRunning: Boolean = False);
    procedure UpdateBenchmarks;
  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  Math;

procedure TMainForm.acAboutExecute(Sender: TObject);
begin
  { "About..." }
  // TODO: about dialog
end;

procedure TMainForm.acBenchmarksExecute(Sender: TObject);
begin
  { "Show benchmarks" }
  if FIsRunning and acBenchmarks.Checked then
  begin
    tmrBenchmarks.Enabled := True;
    FFrameCount := 0;
    FFrameDrawCount := 0;
    FFrameCalcTime.Reset;
    FFrameRenderTime.Reset;
    FFrameDrawingTime.Reset;
    QueryPerformanceCounter(FPrevBenchmarksTime);
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
  if odROM.Execute then
    LoadROM(odROM.FileName, True);
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
  // TODO: reset VM
end;

procedure TMainForm.acRunExecute(Sender: TObject);
begin
  { "Run" }
  SetIsRunning(True);
  UpdateActions;
  UpdateStatus;
  UpdateBenchmarks;
end;

procedure TMainForm.acSoundExecute(Sender: TObject);
begin
  { "Play sound" }
  // do nothing
end;

procedure TMainForm.AppEventsIdle(Sender: TObject; var Done: Boolean);
begin
  UpdateFrameIfNeeded(True);
  Done := False;
end;

procedure TMainForm.CreateScreen;
var
  lcColor: Integer;
  lcR, lcG, lcB: Byte;
begin
  FillChar(FScreenBitmapInfo, SizeOf(TScreenBitmapInfo), 0);
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
  FillChar(FScreenPixels^, SizeOf(TScreenPixels), 0);
end;

procedure TMainForm.DoVMFrame;
begin
  if FIsRunning and acBenchmarks.Checked then
    FFrameCalcTime.Start;
  FVM.CalcNextFrame;
  if FIsRunning and acBenchmarks.Checked then
    FFrameCalcTime.Stop;

  UpdateScreen(FVM.GetScreenBuf);
end;

procedure TMainForm.DrawScreen(ADC: HDC; ADstX, ADstY, ADstWidth,
  ADstHeight: Integer);
begin
  StretchDIBits(ADC, ADstX, ADstY, ADstWidth, ADstHeight,
    0, 0, c_BytePusherScrWidth, c_BytePusherScrHeight,
      FScreenPixels, PBitmapInfo(@FScreenBitmapInfo)^, DIB_RGB_COLORS, SRCCOPY);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  timeBeginPeriod(1); // for more accurate delay on Sleep(1)

  QueryPerformanceFrequency(FTimerFreq);
  FFramePeriod := FTimerFreq div c_BytePusherFPS; // 1 / c_BytePusherFPS * FTimerFreq

  FVM := TBytePusherVM.Create;
  CreateScreen;

  FFrameCalcTime := TStopwatch.Create;
  FFrameRenderTime := TStopwatch.Create;
  FFrameDrawingTime := TStopwatch.Create;

  SetIsRunning(False);
  UpdateActions;
  UpdateStatus;
  UpdateBenchmarks;

  {$IFDEF DEBUG}
  if FileExists('ROMs\Sprites.BytePusher') then
    LoadROM('ROMs\Sprites.BytePusher', True);
  {$ENDIF}
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FFrameDrawingTime.Free;
  FFrameRenderTime.Free;
  FFrameCalcTime.Free;

  Dispose(FScreenPixels);
  FVM.Free;

  timeEndPeriod(1);
end;

procedure TMainForm.LoadROM(const AFileName: string; ARun: Boolean);
begin
  FVM.LoadSnapshot(AFileName);
  FIsROMLoaded := True;
  SetIsRunning(ARun);
  UpdateActions;
  UpdateStatus;
  UpdateBenchmarks;
end;

procedure TMainForm.pbScreenPaint(Sender: TObject);
begin
  if FIsRunning and acBenchmarks.Checked then
    FFrameDrawingTime.Start;
  DrawScreen(pbScreen.Canvas.Handle, 0, 0, pbScreen.ClientWidth,
    pbScreen.ClientHeight);
  if FIsRunning and acBenchmarks.Checked then
  begin
    FFrameDrawingTime.Stop;
    Inc(FFrameDrawCount);
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

procedure TMainForm.SetIsRunning(AIsRunning: Boolean);
begin
  FIsRunning := AIsRunning;
  tmrBenchmarks.Enabled := FIsRunning and acBenchmarks.Checked;
  if FIsRunning then
  begin
    FFrameTimer := 0;
    FFrameCount := 0;
    FFrameDrawCount := 0;
    FFrameCalcTime.Reset;
    FFrameRenderTime.Reset;
    FFrameDrawingTime.Reset;
    QueryPerformanceCounter(FPrevFrameTime);
    FPrevBenchmarksTime := FPrevFrameTime;
  end;
end;

procedure TMainForm.SetStatus(AItem: TStatusItem; const AFormat: string;
  const AArgs: array of const);
begin
  stbStatus.Panels[Ord(AItem)].Text := Format(AFormat, AArgs);
end;

procedure TMainForm.tmrBenchmarksTimer(Sender: TObject);
begin
  UpdateBenchmarks;
end;

procedure TMainForm.UpdateActions;
begin
  acRun.Enabled := FIsROMLoaded and not FIsRunning;
  acNextFrame.Enabled := FIsROMLoaded and not FIsRunning;
  acPause.Enabled := FIsROMLoaded and FIsRunning;
  acReset.Enabled := FIsROMLoaded;
end;

procedure TMainForm.UpdateBenchmarks;
var
  lcCurTime: Int64;
  lcFPS, lcCalcTime, lcRenderTime, lcDrawingTime: Double;
begin
  if not FIsRunning or not acBenchmarks.Checked then
  begin
    SetStatus(siFPS, '', []);
    SetStatus(siCalcTime, '', []);
    SetStatus(siRenderTime, '', []);
    SetStatus(siDrawingTime, '', []);
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
  FFrameCalcTime.Reset;
  FFrameRenderTime.Reset;

  if FFrameDrawCount > 0 then
    lcDrawingTime := FFrameDrawingTime.ElapsedMillisecondsF / FFrameDrawCount
  else
    lcDrawingTime := 0.0;
  SetStatus(siDrawingTime, 'Draw: %.2f ms', [lcDrawingTime]);
  FFrameDrawCount := 0;
  FFrameDrawingTime.Reset;

  FFrameCount := 0;
  QueryPerformanceCounter(FPrevBenchmarksTime);
end;

procedure TMainForm.UpdateFrameIfNeeded(ACanSleep: Boolean);
var
  lcCurTime, lcDeltaTime: Int64;
begin
  if not FIsRunning then
    Exit;

  QueryPerformanceCounter(lcCurTime);
  lcDeltaTime := lcCurTime - FPrevFrameTime;
  Inc(FFrameTimer, lcDeltaTime);
  if FFrameTimer >= FFramePeriod then
  begin
    FFrameTimer := FFrameTimer mod FFramePeriod;
    DoVMFrame;
    if acBenchmarks.Checked then
      Inc(FFrameCount);
  end
  else
    if ACanSleep then
      Sleep(1);
  FPrevFrameTime := lcCurTime;
end;

procedure TMainForm.UpdateScreen(AVMScreenBuf: PByte);
begin
  if FIsRunning and acBenchmarks.Checked then
    FFrameRenderTime.Start;
  // Remember: all scanlines in the DIB (FScreenPixels) must be 4-byte aligned.
  // Since we have 256 bytes per line, this requirement is already met.
  Assert(((c_BytePusherScrWidth * SizeOf(Byte)) mod 4) = 0);
  Assert(SizeOf(FScreenPixels^) = c_BytePusherScrBufSize);
  Move(AVMScreenBuf^, FScreenPixels^, c_BytePusherScrBufSize);
  if FIsRunning and acBenchmarks.Checked then
    FFrameRenderTime.Stop;

  pbScreen.Invalidate;
end;

procedure TMainForm.UpdateStatus(AForceRunning: Boolean);
begin
  if not FIsROMLoaded then
    SetStatus(siState, 'ROM not loaded', [])
  else
    if FIsRunning or AForceRunning then
      SetStatus(siState, 'Running', [])
    else
      SetStatus(siState, 'Paused', []);
end;

end.
