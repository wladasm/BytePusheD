unit fmMain;

interface

uses
  Classes, Forms, Windows, SysUtils, Graphics, Dialogs, Controls, StdCtrls,
  ExtCtrls, ComCtrls, AppEvnts, MMSystem, unVM;

const
  stState = 0;
  stFPS = 1;

type
  PScreenPixels = ^TScreenPixels;
  TScreenPixels = array [0..c_BytePusherScrHeight - 1, 0..c_BytePusherScrWidth - 1] of TRGBTriple;

  TMainForm = class(TForm)
    pbScreen: TPaintBox;
    btNextFrame: TButton;
    odROM: TOpenDialog;
    btLoadROM: TButton;
    btRunStop: TButton;
    stbStatus: TStatusBar;
    tmrFPS: TTimer;
    ApplicationEvents: TApplicationEvents;
    procedure pbScreenPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btNextFrameClick(Sender: TObject);
    procedure btLoadROMClick(Sender: TObject);
    procedure btRunStopClick(Sender: TObject);
    procedure tmrFPSTimer(Sender: TObject);
    procedure ApplicationEventsIdle(Sender: TObject; var Done: Boolean);
  private
    FVM: TBytePusherVM;
    FScreenBuf: TBitmap;
    FScreenPixels: PScreenPixels;
    FScreenPal: array [Byte] of TRGBTriple;
    FROMIsLoaded: Boolean;
    FIsRunning: Boolean;
    FTimerFreq: Int64;
    FFramePeriod: Int64;
    FFrameTimer: Int64;
    FFrameCount: Integer;
    FPrevTime: Int64;
    FPrevFPSTime: Int64;
    procedure CreateScreen;
    procedure PreparePalette;
    procedure UpdateScreen(AVMScreenBuf: PByte);
    procedure SetIsRunning(AIsRunning: Boolean);
    procedure DoVMFrame;
    procedure UpdateButtons;
    procedure UpdateStatus(AForceRunning: Boolean = False);
  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.ApplicationEventsIdle(Sender: TObject; var Done: Boolean);
var
  lcCurTime, lcDeltaTime: Int64;
begin
  if not FIsRunning then
    Exit;

  QueryPerformanceCounter(lcCurTime);
  lcDeltaTime := lcCurTime - FPrevTime;
  Inc(FFrameTimer, lcDeltaTime);
  if FFrameTimer >= FFramePeriod then
  begin
    Dec(FFrameTimer, FFramePeriod);
    DoVMFrame;
    Inc(FFrameCount);
  end
  else
    Sleep(1);
  FPrevTime := lcCurTime;
  Done := False;
end;

procedure TMainForm.btLoadROMClick(Sender: TObject);
begin
  if odROM.Execute then
  begin
    FVM.LoadSnapshot(odROM.FileName);
    FROMIsLoaded := True;
    SetIsRunning(True);
    UpdateButtons;
    UpdateStatus;
  end;
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
  FVM.CalcNextFrame;
  UpdateScreen(FVM.GetScreenBuf);
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FVM := TBytePusherVM.Create;
  CreateScreen;
  PreparePalette;

  timeBeginPeriod(1); // for more accurate delay on Sleep(1)

  QueryPerformanceFrequency(FTimerFreq);
  FFramePeriod := FTimerFreq div c_BytePusherFPS; // 1 / c_BytePusherFPS * FTimerFreq

  SetIsRunning(False);
  UpdateButtons;
  UpdateStatus;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  timeEndPeriod(1);

  FScreenBuf.Free;
  FVM.Free;
end;

procedure TMainForm.pbScreenPaint(Sender: TObject);
begin
  pbScreen.Canvas.StretchDraw(pbScreen.ClientRect, FScreenBuf);
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
  tmrFPS.Enabled := FIsRunning;
  if FIsRunning then
  begin
    FFrameTimer := 0;
    FFrameCount := 0;
    QueryPerformanceCounter(FPrevTime);
    FPrevFPSTime := FPrevTime;
  end;
end;

procedure TMainForm.tmrFPSTimer(Sender: TObject);
var
  lcCurTime: Int64;
  lcFPS: Double;
begin
  QueryPerformanceCounter(lcCurTime);
  lcFPS := FFrameCount / ((lcCurTime - FPrevFPSTime) / FTimerFreq);
  stbStatus.Panels[stFPS].Text := Format('FPS: %d', [Trunc(lcFPS)]);
  FFrameCount := 0;
  QueryPerformanceCounter(FPrevFPSTime);
end;

procedure TMainForm.UpdateButtons;
begin
  btLoadROM.Enabled := not FIsRunning;
  btRunStop.Enabled := FROMIsLoaded;
  if not FROMIsLoaded or FIsRunning then
    btRunStop.Caption := 'Stop'
  else
    btRunStop.Caption := 'Run';
  btNextFrame.Enabled := FROMIsLoaded and not FIsRunning;
end;

procedure TMainForm.UpdateScreen(AVMScreenBuf: PByte);
var
  y, x, i: Integer;
begin
  i := 0;
  // TODO: flat FScreenPixels
  for y := 0 to c_BytePusherScrHeight - 1 do
    for x := 0 to c_BytePusherScrWidth - 1 do
    begin
      FScreenPixels[y, x] := FScreenPal[(AVMScreenBuf + i)^];
      Inc(i);
    end;

  pbScreen.Invalidate;
end;

procedure TMainForm.UpdateStatus(AForceRunning: Boolean);
begin
  if not FROMIsLoaded then
    stbStatus.Panels[stState].Text := 'ROM not loaded'
  else
    if FIsRunning then
      stbStatus.Panels[stState].Text := 'Running'
    else
      stbStatus.Panels[stState].Text := 'Stopped';

  if not FIsRunning then
    stbStatus.Panels[stFPS].Text := '';
end;

end.
