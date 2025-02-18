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
  object btNextFrame: TButton
    Left = 280
    Top = 104
    Width = 161
    Height = 33
    Anchors = [akTop, akRight]
    Caption = 'Next frame'
    TabOrder = 2
    OnClick = btNextFrameClick
  end
  object btLoadROM: TButton
    Left = 280
    Top = 8
    Width = 161
    Height = 33
    Anchors = [akTop, akRight]
    Caption = 'Load ROM'
    TabOrder = 0
    OnClick = btLoadROMClick
  end
  object btRunStop: TButton
    Left = 280
    Top = 55
    Width = 161
    Height = 33
    Anchors = [akTop, akRight]
    Caption = 'Stop'
    TabOrder = 1
    OnClick = btRunStopClick
  end
  object stbStatus: TStatusBar
    Left = 0
    Top = 260
    Width = 463
    Height = 19
    Panels = <
      item
        Width = 150
      end
      item
        Width = 50
      end>
  end
  object odROM: TOpenDialog
    DefaultExt = 'BytePusher'
    Filter = 
      'BytePusher ROM files (*.BytePusher)|*.BytePusher|All files (*.*)' +
      '|*.*'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Left = 280
    Top = 216
  end
  object tmrBenchmarks: TTimer
    Enabled = False
    OnTimer = tmrBenchmarksTimer
    Left = 416
    Top = 216
  end
  object AppEvents: TApplicationEvents
    OnIdle = AppEventsIdle
    Left = 344
    Top = 216
  end
end
