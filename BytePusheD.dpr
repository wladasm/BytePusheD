program BytePusheD;

uses
  Forms,
  fmMain in 'fmMain.pas' {MainForm},
  unVM in 'unVM.pas',
  unStopwatch in 'unStopwatch.pas',
  unSound in 'unSound.pas';

{$R *.res}

begin
  {$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
  {$ENDIF}

  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'BytePusheD';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
