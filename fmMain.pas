unit fmMain;

interface

uses
  Classes, Forms, Windows, SysUtils, Dialogs, Controls, StdCtrls, ExtCtrls,
  ComCtrls, AppEvnts, MMSystem, Menus, Buttons, ActnList, unVM, unStopwatch;

const
  c_ProgramName = 'BytePusher';
  c_ProgramVersion = '0.01';
  c_ProgramYear = '2025';
  c_ProgramCopyright = 'Dan Peroff';

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
    FVMKeyStates: TBytePusherKeyStates;
    FScreenBitmapInfo: TScreenBitmapInfo;
    FScreenPixels: PScreenPixels;
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
    procedure CreateScreen;
    procedure CreateKeyboard;
    procedure UpdateScreen;
    procedure DrawScreen(ADC: HDC; ADstX, ADstY, ADstWidth, ADstHeight: Integer);
    procedure DoVMFrame;
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

procedure TMainForm.acSoundExecute(Sender: TObject);
begin
  { "Play sound" }
  // do nothing
end;

procedure TMainForm.AppEventsIdle(Sender: TObject; var Done: Boolean);
begin
  if not FIsRunning then
    Exit;

  if not UpdateFrameIfNeeded then
    Sleep(1);

  Done := False;
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
  FVM.SetKeyStates(FVMKeyStates);

  if IsBenchmarkingActive then
    FFrameCalcTime.Start;
  FVM.CalcNextFrame;
  if IsBenchmarkingActive then
    FFrameCalcTime.Stop;

  UpdateScreen;

  if IsBenchmarkingActive then
    Inc(FFrameCount);
end;

procedure TMainForm.DrawScreen(ADC: HDC; ADstX, ADstY, ADstWidth,
  ADstHeight: Integer);
begin
  if IsBenchmarkingActive then
    FFrameDrawingTime.Start;
  StretchDIBits(ADC, ADstX, ADstY, ADstWidth, ADstHeight,
    0, 0, c_BytePusherScrWidth, c_BytePusherScrHeight,
      FScreenPixels, PBitmapInfo(@FScreenBitmapInfo)^, DIB_RGB_COLORS, SRCCOPY);
  if IsBenchmarkingActive then
  begin
    FFrameDrawingTime.Stop;
    Inc(FFrameDrawCount);
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

  FFrameCalcTime := TStopwatch.Create;
  FFrameRenderTime := TStopwatch.Create;
  FFrameDrawingTime := TStopwatch.Create;

  SetIsRunning(False);
  UpdateActions;
  UpdateStatus;
  UpdateBenchmarks;

  {$IFDEF DEBUG}
  if FileExists('Snapshots\Sprites.BytePusher') then
    LoadSnapshot('Snapshots\Sprites.BytePusher', True);
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
  UpdateActions;
  UpdateStatus;
  UpdateBenchmarks;
end;

procedure TMainForm.pbScreenPaint(Sender: TObject);
begin
  DrawScreen(pbScreen.Canvas.Handle, 0, 0, pbScreen.ClientWidth,
    pbScreen.ClientHeight);
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
  acRun.Enabled := FIsSnapshotLoaded and not FIsRunning;
  acNextFrame.Enabled := FIsSnapshotLoaded and not FIsRunning;
  acPause.Enabled := FIsSnapshotLoaded and FIsRunning;
  acReset.Enabled := FIsSnapshotLoaded;
end;

procedure TMainForm.UpdateBenchmarks;
var
  lcCurTime: Int64;
  lcFPS, lcCalcTime, lcRenderTime, lcDrawingTime: Double;
begin
  if not IsBenchmarkingActive then
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

  if FFrameDrawCount > 0 then
    lcDrawingTime := FFrameDrawingTime.ElapsedMillisecondsF / FFrameDrawCount
  else
    lcDrawingTime := 0.0;
  SetStatus(siDrawingTime, 'Draw: %.2f ms', [lcDrawingTime]);

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
  lcScreenBuf := FVM.GetScreenBuf;
  // Remember: all scanlines in the DIB (FScreenPixels) must be 4-byte aligned.
  // Since we have 256 bytes per line, this requirement is already met.
  Assert(((c_BytePusherScrWidth * SizeOf(Byte)) mod 4) = 0);
  Assert(SizeOf(FScreenPixels^) = c_BytePusherScrBufSize);
  Move(lcScreenBuf^, FScreenPixels^, c_BytePusherScrBufSize);
  if IsBenchmarkingActive then
    FFrameRenderTime.Stop;

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
