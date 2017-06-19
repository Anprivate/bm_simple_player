object Form2: TForm2
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Form2'
  ClientHeight = 79
  ClientWidth = 175
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object MaskEdit1: TMaskEdit
    Left = 8
    Top = 8
    Width = 144
    Height = 27
    EditMask = '00:00:00:00;1;_'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Tahoma'
    Font.Style = []
    MaxLength = 11
    ParentFont = False
    TabOrder = 0
    Text = '  :  :  :  '
  end
  object BitBtn1: TBitBtn
    Left = 8
    Top = 44
    Width = 75
    Height = 25
    Kind = bkOK
    NumGlyphs = 2
    TabOrder = 1
  end
  object BitBtn2: TBitBtn
    Left = 89
    Top = 44
    Width = 75
    Height = 25
    Kind = bkCancel
    NumGlyphs = 2
    TabOrder = 2
  end
end
