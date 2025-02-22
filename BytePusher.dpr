program BytePusher;

uses
  Forms,
  fmMain in 'fmMain.pas' {MainForm},
  unVM in 'unVM.pas',
  unStopwatch in 'unStopwatch.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
