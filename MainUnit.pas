unit MainUnit;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.Buttons,
  System.ImageList, Vcl.ImgList, Vcl.ExtCtrls, ShellAPI, SHLobj, Vcl.StdCtrls,
  UnitClip, UnitChannel, ComObj, GMFBridgeLib_TLB, ActiveX,
  DirectShow9, dsutil, MMsystem, inifiles, Vcl.Mask, StrUtils;

const
  WM_BRIDGE = WM_USER + 1;

type
  TForm1 = class(TForm)
    TrackBarPosition: TTrackBar;
    ImageList1: TImageList;
    PanelButtons: TPanel;
    ImagePlay: TImage;
    ImageLoop: TImage;
    ImageSetIn: TImage;
    ImageSetOut: TImage;
    ImageGotoIn: TImage;
    ImageStepB: TImage;
    ImageStepF: TImage;
    ImageGotoOut: TImage;
    Timer1: TTimer;
    GroupBoxFile: TGroupBox;
    LabelIn: TLabel;
    PanelIn: TPanel;
    Label2: TLabel;
    LabelOut: TLabel;
    PanelOut: TPanel;
    Label4: TLabel;
    PanelDur: TPanel;
    PanelNow: TPanel;
    ImageToStart: TImage;
    ImageToEnd: TImage;
    PanelTill: TPanel;
    procedure FormResize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure OnNotify(var Message: TMessage); message WM_BRIDGE;
    procedure ImagePlayClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    function OpenNewFile(FileName: string): boolean;
    procedure Timer1Timer(Sender: TObject);
    procedure ImageSetInClick(Sender: TObject);
    procedure ImageSetOutClick(Sender: TObject);
    procedure TrackBarPositionChange(Sender: TObject);
    procedure PanelNowDblClick(Sender: TObject);
    procedure ImageLoopClick(Sender: TObject);
    procedure ImageGotoInClick(Sender: TObject);
    procedure ImageGotoOutClick(Sender: TObject);
    procedure ImageStepBClick(Sender: TObject);
    procedure ImageStepFClick(Sender: TObject);
    procedure ImageToStartClick(Sender: TObject);
    procedure ImageToEndClick(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
  private
    procedure WMDROPFILES(var Message: TWMDROPFILES); message WM_DROPFILES;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

  PlayChannel: TOneChannel;
  Duration: Int64;
  LastSettedPosition: Int64;
  use_in_out: boolean;

implementation

{$R *.dfm}

uses TCReq;

function CheckRegistered: boolean;
var
  K: HKEY;
begin
  result := Winapi.Windows.RegOpenKey(HKEY_CLASSES_ROOT,
    PChar('\TypeLib\{5CE27AC5-940C-4199-8746-01FE1F12A12E}'), K)
    = ERROR_SUCCESS;
  if result then
    Winapi.Windows.RegCloseKey(K)
end;

function TCtoString(inTC: longint): string;
var
  iHours, iMinutes, iSeconds, iFrames, tmp: longint;
begin
  tmp := inTC;
  iHours := tmp div 90000;
  tmp := tmp mod 90000;
  iMinutes := tmp div 1500;
  tmp := tmp mod 1500;
  iSeconds := tmp div 25;
  iFrames := tmp mod 25;
  TCtoString := format('%.2u', [iHours]) + ':' + format('%.2u', [iMinutes]) +
    ':' + format('%.2u', [iSeconds]) + ':' + format('%.2u', [iFrames]);
end;

function TryStringToTC(InString: string; var TC: longint): boolean;
var
  tmpStr: string;
  iHours, iMin, iSec, iFrames: longint;
  position: integer;
begin
  iHours := 0;
  iMin := 0;
  iSec := 0;
  tmpStr := StringReplace(ReverseString(InString), ' ', '0', [rfReplaceAll]);
  tmpStr := StringReplace(tmpStr, '_', '0', [rfReplaceAll]);
  position := pos(':', tmpStr);
  if position > 0 then
  begin
    if not TryStrToInt(ReverseString(LeftStr(tmpStr, position - 1)), iFrames)
    then
      iFrames := -1;
    tmpStr := MidStr(tmpStr, position + 1, 1000);
    position := pos(':', tmpStr);
    if position > 0 then
    begin
      if not TryStrToInt(ReverseString(LeftStr(tmpStr, position - 1)), iSec)
      then
        iSec := -1;
      tmpStr := MidStr(tmpStr, position + 1, 1000);
      position := pos(':', tmpStr);
      if position > 0 then
      begin
        if not TryStrToInt(ReverseString(LeftStr(tmpStr, position - 1)), iMin)
        then
          iMin := -1;
        tmpStr := MidStr(tmpStr, position + 1, 1000);
        if not TryStrToInt(ReverseString(tmpStr), iHours) then
          iHours := -1;
      end
      else if not TryStrToInt(ReverseString(tmpStr), iMin) then
        iMin := -1;
    end
    else if not TryStrToInt(ReverseString(tmpStr), iSec) then
      iSec := -1;
  end
  else if not TryStrToInt(ReverseString(tmpStr), iFrames) then
    iFrames := -1;
  TC := iFrames + 25 * (iSec + 60 * (iMin + 60 * iHours));
  TryStringToTC := (iFrames >= 0) and (iSec >= 0) and (iMin >= 0) and
    (iHours >= 0);
end;

// 0 - loop active, 1 - loop inactive, 2 - set in, 3 - set out
// 4 - goto in, 5 - step back, 6 - play, 7 - stop, 8 - step forward
// 9 - goto out
procedure TForm1.FormCreate(Sender: TObject);
var
  Ini: TIniFile;
  tmpStr: string;
  i: integer;
  tmpBm: TBitMap;
begin
  Form1.Color := RGB(70, 70, 70);
  PanelButtons.Color := RGB(50, 50, 50);

  ImageList1.GetBitmap(1, ImageLoop.Picture.Bitmap);
  ImageList1.GetBitmap(2, ImageSetIn.Picture.Bitmap);
  ImageList1.GetBitmap(3, ImageSetOut.Picture.Bitmap);
  ImageList1.GetBitmap(4, ImageGotoIn.Picture.Bitmap);
  ImageList1.GetBitmap(5, ImageStepB.Picture.Bitmap);
  ImageList1.GetBitmap(6, ImagePlay.Picture.Bitmap);
  ImageList1.GetBitmap(8, ImageStepF.Picture.Bitmap);
  ImageList1.GetBitmap(9, ImageGotoOut.Picture.Bitmap);
  ImageList1.GetBitmap(10, ImageToStart.Picture.Bitmap);
  ImageList1.GetBitmap(11, ImageToEnd.Picture.Bitmap);

  CoInitialize(nil);

  try
    if not CheckRegistered then
      raise EMyOwnException.Create('GFMBridge.dll не зарегистрирован');

    Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'setup.ini');
    try
      i := GetFileVersion(Application.ExeName);
      tmpStr := Ini.ReadString('common', 'player_id', '');
      Self.Caption := format('Blackmagic simple clip player. V%d.%d (%s)',
        [i div $10000, i mod $10000, tmpStr]);

      Form1.Left := Ini.ReadInteger('common', 'left', 0);
      Form1.Top := Ini.ReadInteger('common', 'top', 0);

      PlayChannel := TOneChannel.Create;
      tmpStr := Ini.ReadString('common', 'video_guid', '');
      PlayChannel.VideoBMGUID := StringToGUID(tmpStr);
      tmpStr := Ini.ReadString('common', 'audio_guid', '');
      PlayChannel.AudioBMGUID := StringToGUID(tmpStr);
      PlayChannel.ClipCount := 1;

      use_in_out := Ini.ReadBool('common', 'use_in_out', true);

      ImageLoop.Tag := Ini.ReadInteger('common', 'loop', 0);
      tmpBm := TBitMap.Create;
      if ImageLoop.Tag = 1 then
        ImageList1.GetBitmap(0, tmpBm)
      else
        ImageList1.GetBitmap(1, tmpBm);
      ImageLoop.Picture.Bitmap := tmpBm;
      FreeAndNil(tmpBm);

      if not use_in_out then
      begin
        PanelIn.Enabled := false;
        PanelIn.Visible := false;
        PanelOut.Enabled := false;
        PanelOut.Visible := false;
        LabelIn.Enabled := false;
        LabelIn.Visible := false;
        LabelOut.Caption := 'To end:';
        PanelTill.Enabled := true;
        PanelTill.Visible := true;
        ImageSetIn.Enabled := false;
        ImageSetIn.Visible := false;
        ImageSetOut.Enabled := false;
        ImageSetOut.Visible := false;
        ImageGotoIn.Enabled := false;
        ImageGotoIn.Visible := false;
        ImageGotoOut.Enabled := false;
        ImageGotoOut.Visible := false;
        TrackBarPosition.ShowSelRange := false;
      end;

      tmpStr := Ini.ReadString('common', 'filename', '');
      OpenNewFile(tmpStr);
    finally
      Ini.Free;
    end;

    DragAcceptFiles(Self.Handle, true);
  except
    on E: Exception do
    begin
      ShowMessage(E.ClassName + ' ошибка с сообщением : ' + E.Message);
      Application.Terminate;
    end;
  end;

  Timer1.Enabled := true;
  Self.DoubleBuffered := true;
end;

procedure TForm1.FormDestroy(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(ExtractFilePath(Application.ExeName) + 'setup.ini');
  try
    Ini.WriteInteger('common', 'left', Form1.Left);
    Ini.WriteInteger('common', 'top', Form1.Top);
    if PlayChannel.ActiveClip <> nil then
      Ini.WriteString('common', 'filename', PlayChannel.ActiveClip.FileName);
    Ini.WriteInteger('common', 'loop', ImageLoop.Tag);
  finally
    Ini.Free;
  end;

  FreeAndNil(PlayChannel);
  CoUninitialize();
end;

procedure TForm1.FormKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #32 then
  begin
    ImagePlayClick(Self);
  end;
end;

procedure TForm1.FormResize(Sender: TObject);
begin
  Form1.Height := 255;
  TrackBarPosition.Left := 8;
  TrackBarPosition.Width := Form1.ClientWidth - 16;
  PanelButtons.Left := (Form1.ClientWidth - PanelButtons.Width) div 2;
  GroupBoxFile.Left := (Form1.ClientWidth - GroupBoxFile.Width) div 2;
end;

procedure TForm1.ImageGotoInClick(Sender: TObject);
var
  tmpPos: Int64;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) then
  begin
    tmpPos := Int64(TrackBarPosition.SelStart) * 400000;
    PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
      AM_SEEKING_AbsolutePositioning, tmpPos, AM_SEEKING_NoPositioning);
    PlayChannel.PauseRenderGraph;
    TrackBarPosition.position := TrackBarPosition.SelStart;
    PanelNow.Caption := TCtoString(TrackBarPosition.SelStart);
  end;
end;

procedure TForm1.ImageGotoOutClick(Sender: TObject);
var
  tmpPos: Int64;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) then
  begin
    tmpPos := Int64(TrackBarPosition.SelEnd) * 400000;
    PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
      AM_SEEKING_AbsolutePositioning, tmpPos, AM_SEEKING_NoPositioning);
    PlayChannel.PauseRenderGraph;
    TrackBarPosition.position := TrackBarPosition.SelEnd;
    PanelNow.Caption := TCtoString(TrackBarPosition.SelEnd);
  end;
end;

procedure TForm1.ImageLoopClick(Sender: TObject);
var
  tmpBm: TBitMap;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) then
  begin
    tmpBm := TBitMap.Create;
    if ImageLoop.Tag = 0 then
    begin
      ImageList1.GetBitmap(0, tmpBm);
      ImageLoop.Picture.Bitmap := tmpBm;
      ImageLoop.Tag := 1;
    end
    else
    begin
      ImageList1.GetBitmap(1, tmpBm);
      ImageLoop.Picture.Bitmap := tmpBm;
      ImageLoop.Tag := 0;
    end;
    FreeAndNil(tmpBm);
  end;
end;

procedure TForm1.ImagePlayClick(Sender: TObject);
var
  tmpBm: TBitMap;
  tmpPos: Int64;
begin
  tmpBm := TBitMap.Create;
  case PlayChannel.CurrentStatus of
    Pause:
      begin
        if ImageLoop.Tag = 1 then // loop mode
        begin
          if (TrackBarPosition.position < TrackBarPosition.SelStart) or
            (TrackBarPosition.position >= TrackBarPosition.SelEnd) then
            TrackBarPosition.position := TrackBarPosition.SelStart;
          PlayChannel.ActiveClip.StartPos :=
            Int64(TrackBarPosition.SelStart) * 400000;
          PlayChannel.ActiveClip.StopPos :=
            Int64(TrackBarPosition.SelEnd) * 400000;
          tmpPos := Int64(TrackBarPosition.position) * 400000;
          PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
            AM_SEEKING_AbsolutePositioning, PlayChannel.ActiveClip.StopPos,
            AM_SEEKING_AbsolutePositioning);
        end
        else
        begin
          if TrackBarPosition.position >= TrackBarPosition.SelEnd - 2 then
          begin
            TrackBarPosition.position := TrackBarPosition.SelStart;
            tmpPos := Int64(TrackBarPosition.position) * 400000;
            PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
              AM_SEEKING_AbsolutePositioning, tmpPos, AM_SEEKING_NoPositioning);
          end
          else
          begin
            tmpPos := Int64(TrackBarPosition.position) * 400000;
            PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
              AM_SEEKING_AbsolutePositioning, tmpPos, AM_SEEKING_NoPositioning);
          end;
        end;

        LastSettedPosition := tmpPos div 400000;

        PlayChannel.PauseRenderGraph;
        PlayChannel.RunRenderGraph;
        ImageList1.GetBitmap(7, tmpBm);
        ImagePlay.Picture.Bitmap := tmpBm;
      end;
    Play:
      begin
        PlayChannel.PauseRenderGraph;
        tmpPos := Duration * 400000;
        PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
          AM_SEEKING_NoPositioning, tmpPos, AM_SEEKING_AbsolutePositioning);
        PlayChannel.PauseRenderGraph;
        ImageList1.GetBitmap(6, tmpBm);
        ImagePlay.Picture.Bitmap := tmpBm;
      end;
  end;
  FreeAndNil(tmpBm);
end;

procedure TForm1.ImageSetInClick(Sender: TObject);
var
  NowTime: Int64;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) then
  begin
    NowTime := PlayChannel.GetCurrentTime;
    if NowTime < 0 then
      NowTime := NowTime + Duration
    else
      NowTime := NowTime + LastSettedPosition;

    PlayChannel.ActiveClip.StartPos := NowTime * 400000;

    PanelIn.Caption := TCtoString(NowTime);
    TrackBarPosition.SelStart := NowTime;
  end;
end;

procedure TForm1.ImageSetOutClick(Sender: TObject);
var
  NowTime: Int64;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) then
  begin
    NowTime := PlayChannel.GetCurrentTime;
    if NowTime < 0 then
      NowTime := NowTime + Duration
    else
      NowTime := NowTime + LastSettedPosition;

    PlayChannel.ActiveClip.StopPos := NowTime * 400000;

    PanelOut.Caption := TCtoString(NowTime);
    TrackBarPosition.SelEnd := NowTime;
  end;
end;

procedure TForm1.ImageStepBClick(Sender: TObject);
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) and (TrackBarPosition.position > 0) then
    TrackBarPosition.position := TrackBarPosition.position - 1;
end;

procedure TForm1.ImageStepFClick(Sender: TObject);
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) and
    (TrackBarPosition.position < Duration - 1) then
    TrackBarPosition.position := TrackBarPosition.position + 1;
end;

procedure TForm1.ImageToEndClick(Sender: TObject);
var
  tmpPos: Int64;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) then
  begin
    tmpPos := (Duration - 1) * 400000;
    PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
      AM_SEEKING_AbsolutePositioning, tmpPos, AM_SEEKING_NoPositioning);
    PlayChannel.PauseRenderGraph;
    TrackBarPosition.position := Duration - 1;
    PanelNow.Caption := TCtoString(Duration - 1);
    PanelTill.Caption := TCtoString(1);
  end;
end;

procedure TForm1.ImageToStartClick(Sender: TObject);
var
  tmpPos: Int64;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) then
  begin
    tmpPos := 0;
    PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
      AM_SEEKING_AbsolutePositioning, tmpPos, AM_SEEKING_NoPositioning);
    PlayChannel.PauseRenderGraph;
    TrackBarPosition.position := 0;
    PanelNow.Caption := TCtoString(0);
    PanelTill.Caption := TCtoString(Duration);
  end;
end;

procedure TForm1.OnNotify(var Message: TMessage);
var
  tmpBm: TBitMap;
begin
  if PlayChannel.CurrentStatus = Play then
  begin
    if ImageLoop.Tag = 1 then // if loop
    begin
      LastSettedPosition := PlayChannel.ActiveClip.StartPos div 400000;
      PlayChannel.JumpToNext(true);
    end;
  end;
end;

function TForm1.OpenNewFile(FileName: string): boolean;
var
  tmpClip: TOneClip;
  tr: boolean;
  ots: boolean;
  tmpBm: TBitMap;
begin
  ots := Timer1.Enabled;
  Timer1.Enabled := false;

  tr := false;
  if fileexists(FileName) then
  begin
    try
      PlayChannel.ReCreate;
      PlayChannel.SetNotify(Self.Handle, WM_BRIDGE);
      tmpClip := PlayChannel.GetUnusedClip;
      tmpClip.FileName := FileName;
      PlayChannel.PrepareSourceGraph(tmpClip);
      tmpClip.StartPos := 0;
      tmpClip.pSeeking.GetDuration(tmpClip.StopPos);
      PlayChannel.PrepareRenderGraph(tmpClip);
      PlayChannel.PauseRenderGraph;
      GroupBoxFile.Caption := FileName;
      Duration := tmpClip.StopPos div 400000;
      TrackBarPosition.Max := Duration - 1;
      PanelNow.Caption := TCtoString(0);
      PanelIn.Caption := TCtoString(0);
      PanelTill.Caption := TCtoString(Duration);
      PanelDur.Caption := TCtoString(Duration);
      PanelOut.Caption := TCtoString(Duration - 1);
      TrackBarPosition.position := 0;
      TrackBarPosition.SelStart := 0;
      TrackBarPosition.SelEnd := TrackBarPosition.Max;
      LastSettedPosition := 0;

      tmpBm := TBitMap.Create;
      ImageList1.GetBitmap(6, tmpBm);
      ImagePlay.Picture.Bitmap := tmpBm;
      FreeAndNil(tmpBm);

      tr := true;
    except
      PlayChannel.ReCreate;
    end;
  end;
  OpenNewFile := tr;
  Timer1.Enabled := ots;
end;

procedure TForm1.PanelNowDblClick(Sender: TObject);
var
  TC: integer;
  tmpPos: Int64;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) then
  begin
    Form2.MaskEdit1.Text := PanelNow.Caption;
    if Form2.ShowModal = mrOk then
    begin
      if TryStringToTC(Form2.MaskEdit1.Text, TC) and (TC < Duration) then
      begin
        tmpPos := Int64(TC) * 400000;
        PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
          AM_SEEKING_AbsolutePositioning, tmpPos, AM_SEEKING_NoPositioning);
        PlayChannel.PauseRenderGraph;
        TrackBarPosition.position := TC;
        PanelNow.Caption := TCtoString(TC);
        PanelTill.Caption := TCtoString(Duration - TC);
      end;
    end;
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  NowTime: Int64;
  tmpBm: TBitMap;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Play) then
  begin
    NowTime := PlayChannel.GetCurrentTime;
    if NowTime < 0 then
      NowTime := NowTime + PlayChannel.ActiveClip.StopPos div 400000
    else
      NowTime := NowTime + LastSettedPosition;

    if (ImageLoop.Tag = 0) and (NowTime = TrackBarPosition.SelEnd + 1) then
    begin
      Form1.TrackBarPosition.position := TrackBarPosition.SelEnd;
      Form1.PanelNow.Caption := TCtoString(TrackBarPosition.SelEnd);
      Form1.PanelTill.Caption := TCtoString(0);

      PlayChannel.PauseRenderGraph;
      tmpBm := TBitMap.Create;
      ImageList1.GetBitmap(6, tmpBm);
      ImagePlay.Picture.Bitmap := tmpBm;
      FreeAndNil(tmpBm);
    end
    else
    begin
      if Form1.TrackBarPosition.position <> NowTime then
        Form1.TrackBarPosition.position := NowTime;
      Form1.PanelNow.Caption := TCtoString(NowTime);
      Form1.PanelTill.Caption := TCtoString(Duration - NowTime);
    end;
  end;
end;

procedure TForm1.TrackBarPositionChange(Sender: TObject);
var
  tmpPos: Int64;
begin
  if (PlayChannel <> nil) and (PlayChannel.ActiveClip <> nil) and
    (PlayChannel.CurrentStatus = Pause) then
  begin
    Form1.PanelNow.Caption := TCtoString(TrackBarPosition.position);
    Form1.PanelTill.Caption := TCtoString(Duration - TrackBarPosition.position);
    LastSettedPosition := TrackBarPosition.position;
    tmpPos := Int64(TrackBarPosition.position) * Int64(400000);
    PlayChannel.ActiveClip.pSeeking.SetPositions(tmpPos,
      AM_SEEKING_AbsolutePositioning, tmpPos, AM_SEEKING_NoPositioning);
    PlayChannel.PauseRenderGraph;
  end;
end;

procedure TForm1.WMDROPFILES(var Message: TWMDROPFILES);
var
  NumFiles: longint;
  buffer: array [0 .. 255] of Char;
  i: integer;
begin
  { How many files are being dropped }
  NumFiles := DragQueryFile(Message.Drop, $FFFFFFFF, nil, 0);
  { Accept the dropped files }
  for i := 0 to (NumFiles - 1) do
  begin
    DragQueryFile(Message.Drop, i, @buffer, sizeof(buffer));
    // if fileexists(buffer) and (UpperCase(ExtractFileExt(buffer)) = '.AVI') then
    if fileexists(buffer) then
    begin
      OpenNewFile(buffer);
      break;
    end;
  end;
  // for
end;

end.
