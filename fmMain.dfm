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
  Menu = MainMenu
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
        Width = 115
      end
      item
        Width = 50
      end
      item
        Width = 95
      end
      item
        Width = 95
      end
      item
        Width = 95
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
  object MainMenu: TMainMenu
    Left = 16
    Top = 16
    object miFile: TMenuItem
      Caption = 'File'
      object miOpen: TMenuItem
        Action = acOpen
      end
      object miSeparator1: TMenuItem
        Caption = '-'
      end
      object miExit: TMenuItem
        Action = acExit
      end
    end
    object miRun: TMenuItem
      Caption = 'Run'
      object miDoRun: TMenuItem
        Action = acRun
      end
      object miNextFrame: TMenuItem
        Action = acNextFrame
      end
      object miPause: TMenuItem
        Action = acPause
      end
      object miReset: TMenuItem
        Action = acReset
      end
    end
    object miOptions: TMenuItem
      Caption = 'Options'
      object miSound: TMenuItem
        Action = acSound
        AutoCheck = True
      end
      object miBenchmarks: TMenuItem
        Action = acBenchmarks
        AutoCheck = True
      end
    end
    object miHelp: TMenuItem
      Caption = 'Help'
      object miAbout: TMenuItem
        Action = acAbout
      end
    end
  end
  object ActionList: TActionList
    Left = 80
    Top = 16
    object acOpen: TAction
      Caption = 'Open...'
      OnExecute = acOpenExecute
    end
    object acExit: TAction
      Caption = 'Exit'
      OnExecute = acExitExecute
    end
    object acRun: TAction
      Caption = 'Run'
      OnExecute = acRunExecute
    end
    object acNextFrame: TAction
      Caption = 'Next frame'
      OnExecute = acNextFrameExecute
    end
    object acPause: TAction
      Caption = 'Pause'
      OnExecute = acPauseExecute
    end
    object acReset: TAction
      Caption = 'Reset'
      OnExecute = acResetExecute
    end
    object acSound: TAction
      AutoCheck = True
      Caption = 'Play sound'
      Checked = True
      OnExecute = acSoundExecute
    end
    object acBenchmarks: TAction
      AutoCheck = True
      Caption = 'Show benchmarks'
      Checked = True
      OnExecute = acBenchmarksExecute
    end
    object acAbout: TAction
      Caption = 'About...'
      OnExecute = acAboutExecute
    end
  end
end
