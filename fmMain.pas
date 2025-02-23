unit fmMain;

interface

uses
  Classes, Forms, Windows, SysUtils, Graphics, Dialogs, Controls, StdCtrls,
  ExtCtrls, ComCtrls, AppEvnts, MMSystem, unVM, unStopwatch;

type
  PScreenPixels = ^TScreenPixels;
  TScreenPixels = array [0..c_BytePusherScrHeight - 1, 0..c_BytePusherScrWidth - 1] of TRGBTriple;
  TStatusItem = (siState = 0, siFPS, siCalcTime, siRenderTime, siDrawingTime);

  TMainForm = class(TForm)
    pbScreen: TPaintBox;
    btNextFrame: TButton;
    odROM: TOpenDialog;
    btLoadROM: TButton;
    btRunStop: TButton;
    stbStatus: TStatusBar;
    tmrBenchmarks: TTimer;
    AppEvents: TApplicationEvents;
    procedure pbScreenPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btNextFrameClick(Sender: TObject);
    procedure btLoadROMClick(Sender: TObject);
    procedure btRunStopClick(Sender: TObject);
    procedure tmrBenchmarksTimer(Sender: TObject);
    procedure AppEventsIdle(Sender: TObject; var Done: Boolean);
  private
    FVM: TBytePusherVM;
    FScreenBuf: TBitmap;
    FScreenPixels: PScreenPixels;
    FScreenPal: array [Byte] of TRGBTriple;
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
    procedure PreparePalette;
    procedure UpdateScreen(AVMScreenBuf: PByte);
    procedure DoVMFrame;
    procedure SetIsRunning(AIsRunning: Boolean);
    procedure LoadROM(const AFileName: string; ARun: Boolean);
    procedure SetStatus(AItem: TStatusItem; const AFormat: string;
      const AArgs: array of const);
    procedure UpdateButtons;
    procedure UpdateStatus(AForceRunning: Boolean = False);
  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.AppEventsIdle(Sender: TObject; var Done: Boolean);
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
    Dec(FFrameTimer, FFramePeriod);
    DoVMFrame;
    Inc(FFrameCount);
  end
  else
    Sleep(1);
  FPrevFrameTime := lcCurTime;
  Done := False;
end;

procedure TMainForm.btLoadROMClick(Sender: TObject);
begin
  if odROM.Execute then
    LoadROM(odROM.FileName, True);
end;

procedure TMainForm.btNextFrameClick(Sender: TObject);
begin
  UpdateStatus(True);
  DoVMFrame;
  UpdateStatus;
end;

procedure TMainForm.btRunStopClick(Sender: TObject);
begin
  SetIsRunning(not FIsRunning);
  UpdateButtons;
  UpdateStatus;
end;

procedure TMainForm.CreateScreen;
var
  lcDC: HDC;
  lcBMI: TBitmapInfo;
  lcBitmap: HBITMAP;
  lcPixels: PScreenPixels;
  // y, x, yy, xx: Integer;
  // lcPxl: TRGBTriple;
begin
  lcDC := GetDC(0);
  if lcDC = 0 then
    RaiseLastOSError;

  FillChar(lcBMI, SizeOf(lcBMI), 0);
  lcBMI.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  lcBMI.bmiHeader.biWidth := c_BytePusherScrWidth;
  lcBMI.bmiHeader.biHeight := -c_BytePusherScrHeight; // the first line is on top
  lcBMI.bmiHeader.biPlanes := 1;
  lcBMI.bmiHeader.biBitCount := 24; // R, G, B
  lcBMI.bmiHeader.biCompression := BI_RGB;

  lcPixels := nil;
  lcBitmap := CreateDIBSection(lcDC, lcBMI, DIB_RGB_COLORS, Pointer(lcPixels), 0, 0);
  ReleaseDC(0, lcDC);
  if (lcBitmap = 0) or (lcPixels = nil) then
    RaiseLastOSError;

  // TODO: use 8 bit palette instead of RGB values
  FScreenBuf := TBitmap.Create;
  FScreenBuf.Handle := lcBitmap;
  // Remember that all scanlines in DIB (lcPixels) must be aligned on 4 bytes!
  // We have 256*3 bytes per line there, so don't need to think about it.
  FScreenPixels := lcPixels;

  {
  for y := 0 to c_BytePusherScrHeight - 1 do
    for x := 0 to c_BytePusherScrWidth - 1 do
    begin
      yy := y div 16;
      xx := x div 16;
      if yy = 0 then
      begin
        lcPxl.rgbtBlue := 255;
        lcPxl.rgbtGreen := 0;
        lcPxl.rgbtRed := 0;
      end
      else if xx = 0 then
      begin
        lcPxl.rgbtBlue := 255;
        lcPxl.rgbtGreen := 0;
        lcPxl.rgbtRed := 255;
      end
      else if (xx mod 2 = 0) xor (yy mod 2 = 0) then
      begin
        lcPxl.rgbtBlue := 0;
        lcPxl.rgbtGreen := 0;
        lcPxl.rgbtRed := 255;
      end
      else
      begin
        lcPxl.rgbtBlue := 0;
        lcPxl.rgbtGreen := 255;
        lcPxl.rgbtRed := 0;
      end;

      FScreenPixels^[y, x] := lcPxl;
    end;
  }
end;

procedure TMainForm.DoVMFrame;
begin
  FFrameCalcTime.Start;
  FVM.CalcNextFrame;
  FFrameCalcTime.Stop;

  UpdateScreen(FVM.GetScreenBuf);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FVM := TBytePusherVM.Create;
  CreateScreen;
  PreparePalette;

  FFrameCalcTime := TStopwatch.Create;
  FFrameRenderTime := TStopwatch.Create;
  FFrameDrawingTime := TStopwatch.Create;

  timeBeginPeriod(1); // for more accurate delay on Sleep(1)

  QueryPerformanceFrequency(FTimerFreq);
  FFramePeriod := FTimerFreq div c_BytePusherFPS; // 1 / c_BytePusherFPS * FTimerFreq

  SetIsRunning(False);
  UpdateButtons;
  UpdateStatus;

  {$IFDEF DEBUG}
  if FileExists('ROMs\Sprites.BytePusher') then
    LoadROM('ROMs\Sprites.BytePusher', True);
  {$ENDIF}
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  timeEndPeriod(1);

  FFrameDrawingTime.Free;
  FFrameRenderTime.Free;
  FFrameCalcTime.Free;

  FScreenBuf.Free;
  FVM.Free;
end;

procedure TMainForm.LoadROM(const AFileName: string; ARun: Boolean);
begin
  FVM.LoadSnapshot(AFileName);
  FIsROMLoaded := True;
  SetIsRunning(ARun);
  UpdateButtons;
  UpdateStatus;
end;

procedure TMainForm.pbScreenPaint(Sender: TObject);
begin
  if FIsRunning then
    FFrameDrawingTime.Start;
  pbScreen.Canvas.StretchDraw(pbScreen.ClientRect, FScreenBuf);
  if FIsRunning then
  begin
    FFrameDrawingTime.Stop;
    Inc(FFrameDrawCount);
  end;
end;

procedure TMainForm.PreparePalette;
var
  i: Integer;
  lcR, lcG, lcB: Byte;
begin
  for i := 0 to 255 do
  begin
    if i < 216 then
    begin
      lcR := i div 36;
      lcG := (i - lcR * 36) div 6;
      lcB := i mod 6;
    end
    else begin
      lcR := 0;
      lcG := 0;
      lcB := 0;
    end;
    FScreenPal[i].rgbtRed := lcR * $33;
    FScreenPal[i].rgbtGreen := lcG * $33;
    FScreenPal[i].rgbtBlue := lcB * $33;
  end;
end;

procedure TMainForm.SetIsRunning(AIsRunning: Boolean);
begin
  FIsRunning := AIsRunning;
  tmrBenchmarks.Enabled := FIsRunning;
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
var
  lcCurTime: Int64;
  lcFPS, lcCalcTime, lcRenderTime, lcDrawingTime: Double;
begin
  QueryPerformanceCounter(lcCurTime);
  lcFPS := FFrameCount / ((lcCurTime - FPrevBenchmarksTime) / FTimerFreq);
  SetStatus(siFPS, 'FPS: %d', [Trunc(lcFPS)]);

  if FFrameCount > 0 then
  begin
    lcCalcTime := FFrameCalcTime.ElapsedMilliseconds / FFrameCount;
    lcRenderTime := FFrameRenderTime.ElapsedMilliseconds / FFrameCount;
  end
  else begin
    lcCalcTime := 0.0;
    lcRenderTime := 0.0;
  end;
  SetStatus(siCalcTime, 'VM: %.2f ms', [lcCalcTime]);
  SetStatus(siRenderTime, 'Render: %.2f ms', [lcRenderTime]);

  if FFrameDrawCount > 0 then
    lcDrawingTime := FFrameDrawingTime.ElapsedMilliseconds / FFrameDrawCount
  else
    lcDrawingTime := 0.0;
  SetStatus(siDrawingTime, 'Draw: %.2f ms', [lcDrawingTime]);

  FFrameCount := 0;
  FFrameDrawCount := 0;
  FFrameDrawingTime.Restart;
  FFrameRenderTime.Restart;
  FFrameCalcTime.Restart;
  QueryPerformanceCounter(FPrevBenchmarksTime);
end;

procedure TMainForm.UpdateButtons;
begin
  btLoadROM.Enabled := not FIsRunning;
  btRunStop.Enabled := FIsROMLoaded;
  if not FIsROMLoaded or FIsRunning then
    btRunStop.Caption := 'Stop'
  else
    btRunStop.Caption := 'Run';
  btNextFrame.Enabled := FIsROMLoaded and not FIsRunning;
end;

procedure TMainForm.UpdateScreen(AVMScreenBuf: PByte);
var
  y, x, i: Integer;
begin
  FFrameRenderTime.Start;
  i := 0;
  // TODO: flat FScreenPixels
  for y := 0 to c_BytePusherScrHeight - 1 do
    for x := 0 to c_BytePusherScrWidth - 1 do
    begin
      FScreenPixels[y, x] := FScreenPal[(AVMScreenBuf + i)^];
      Inc(i);
    end;
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
      SetStatus(siState, 'Stopped', []);

  if not FIsRunning then
  begin
    SetStatus(siFPS, '', []);
    SetStatus(siCalcTime, '', []);
    SetStatus(siRenderTime, '', []);
    SetStatus(siDrawingTime, '', []);
  end;
end;

end.
