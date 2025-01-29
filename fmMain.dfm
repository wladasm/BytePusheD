object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'BytePusher'
  ClientHeight = 279
  ClientWidth = 463
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    463
    279)
  PixelsPerInch = 96
  TextHeight = 13
  object pbScreen: TPaintBox
    Left = 0
    Top = 0
    Width = 256
    Height = 256
    Anchors = [akLeft, akTop, akRight, akBottom]
    OnPaint = pbScreenPaint
  end
end
