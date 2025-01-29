unit fmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, unVM;

type
  PScreenPixels = ^TScreenPixels;
  TScreenPixels = array [0..c_BytePusherScrHeight - 1, 0..c_BytePusherScrWidth - 1] of TRGBTriple;

  TMainForm = class(TForm)
    pbScreen: TPaintBox;
    procedure pbScreenPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FScreenBuf: TBitmap;
    FScreenPixels: PScreenPixels;
    FScreenPal: array [Byte] of TRGBTriple;
    procedure CreateScreen;
    procedure PreparePalette;
  public

  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

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

procedure TMainForm.FormCreate(Sender: TObject);
begin
  CreateScreen;
  PreparePalette;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FScreenBuf.Free;
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

end.
