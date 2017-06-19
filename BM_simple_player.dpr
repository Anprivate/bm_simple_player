program BM_simple_player;

uses
  Vcl.Forms,
  MainUnit in 'MainUnit.pas' {Form1},
  UnitChannel in 'UnitChannel.pas',
  UnitClip in 'UnitClip.pas',
  TCReq in 'TCReq.pas' {Form2};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm2, Form2);
  Application.Run;
end.
