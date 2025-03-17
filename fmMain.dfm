object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'MainForm'
  ClientHeight = 275
  ClientWidth = 500
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
  PixelsPerInch = 96
  TextHeight = 13
  object stbStatus: TStatusBar
    Left = 0
    Top = 256
    Width = 500
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
  object pnlKeyboard: TPanel
    Left = 256
    Top = 0
    Width = 244
    Height = 256
    Align = alRight
    BevelInner = bvLowered
    BevelWidth = 2
    ShowCaption = False
    TabOrder = 1
    ExplicitLeft = 248
    ExplicitTop = 11
  end
  object pnlScreen: TPanel
    Left = 0
    Top = 0
    Width = 256
    Height = 256
    Align = alClient
    BevelOuter = bvNone
    Constraints.MinHeight = 256
    Constraints.MinWidth = 256
    ShowCaption = False
    TabOrder = 0
    OnResize = pnlScreenResize
    object pbScreen: TPaintBox
      Left = 0
      Top = 0
      Width = 256
      Height = 256
      OnPaint = pbScreenPaint
    end
  end
  object odSnapshot: TOpenDialog
    DefaultExt = 'BytePusher'
    Filter = 
      'BytePusher snapshot files (*.BytePusher)|*.BytePusher|All files ' +
      '(*.*)|*.*'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Left = 16
    Top = 80
  end
  object tmrBenchmarks: TTimer
    Enabled = False
    OnTimer = tmrBenchmarksTimer
    Left = 144
    Top = 80
  end
  object AppEvents: TApplicationEvents
    OnIdle = AppEventsIdle
    Left = 80
    Top = 80
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
