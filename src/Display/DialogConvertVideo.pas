Unit DialogConvertVideo;

{$mode ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls;

Type
  { TdlgConvertVideo }

  TdlgConvertVideo = Class(TForm)
    btnFixDateTime: TButton;
    btnStart: TButton;
    btnClose: TButton;
    edtMPG: TEdit;
    edtWMV: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    memResults: TMemo;
    pcMain: TPageControl;
    pbFiles: TProgressBar;
    tsMain: TTabSheet;
    tsResults: TTabSheet;
    Procedure btnCloseClick(Sender: TObject);
    Procedure btnFixDateTimeClick(Sender: TObject);
    Procedure btnStartClick(Sender: TObject);
    Procedure FormCreate(Sender: TObject);

    Procedure ConvertingVideo(Sender: TObject);
  Private

  Public

  End;

Implementation

Uses Tags, BufDataset, DBSUpport, ffmpegSupport, FormFileWorkbench, OSSupport,
  FileSupport, StringSupport, Process, DOS;

  {$R *.lfm}

  { TdlgConvertVideo }

Procedure TdlgConvertVideo.FormCreate(Sender: TObject);
Begin
  pcMain.ActivePage := tsMain;
  btnStart.Enabled := frmFileWorkbench.ProcessMeta;
End;

Procedure TdlgConvertVideo.ConvertingVideo(Sender: TObject);
Begin
  // TODO we can do better than this./..
  Application.ProcessMessages;
End;

Procedure TdlgConvertVideo.btnCloseClick(Sender: TObject);
Begin
  Close;
End;

Procedure TdlgConvertVideo.btnFixDateTimeClick(Sender: TObject);

  Procedure Status(AStatus: String);
  Begin
    memResults.Lines.Add(AStatus);
    frmFileWorkbench.Status := AStatus;
  End;

  Function SetFileDate(Const AFilename: String; ADate: TDateTime): Boolean;
  Var
    iAge: Longint;
  Begin
    iAge := DateTimeToFileDate(ADate);
    Result := (FileSetDate(AFilename, iAge) = 0);
  End;

Var
  oDataset: TBufDataset;
  sPath, sFile, sFileExt, sDate, sTime, sCount, sTemp, sY, sM, sD, sHH, sMM, sSS: String;
  iFields: Integer;
  dtDate, dtTime: TDateTime;
  iCount: Longint;
  bProcess: Boolean;
Begin
  oDataset := TagManager.Dataset;

  pbFiles.Style := pbstMarquee;
  frmFileWorkbench.pbMain.Position := 0;
  frmFileWorkbench.pbMain.Max := oDataset.RecordCount;

  pcMain.ActivePage := tsResults;

  Cursor := crHourglass;
  Screen.Cursor := crHourglass;

  btnStart.Enabled := False;
  btnFixDateTime.Enabled := False;
  btnClose.Enabled := False;

  memResults.Lines.Clear;
  Status(Format('%s: Starting processing %d of %d files',
    [TimeToStr(Now()), 1, oDataset.RecordCount]));

  oDataset.DisableControls;
  Try
    oDataset.First;
    While Not oDataset.EOF Do
    Begin
      // Processing
      sPath := IncludeSlash(Value(oDataset, 'Path'));
      sFile := Value(oDataset, 'Filename');
      sFileExt := Lowercase(Value(oDataset, 'FileExt'));

      iFields := Count('_', sFile);

      bProcess := False;

      If iFields = 2 Then
      Begin
        // 14UI2_20190429205709_20190429211209.mp4
        sTemp := ExtractField(sFile, '_', 1);
        sY := Copy(sTemp, 1, 4);
        sM := Copy(sTemp, 5, 2);
        sD := Copy(sTemp, 7, 2);
        sHH := Copy(sTemp, 9, 2);
        sMM := Copy(sTemp, 11, 2);
        sSS := Copy(sTemp, 13, 2);

        sDate := sY + '-' + sM + '-' + sD;
        sTime := sHH + '-' + sMM + '-' + sSS;
        sCount := '0';

        bProcess := True;
      End
      Else If (iFields = 6) Then
      Begin
        // 6MW3_PLET_W3-M_2016-ROV~AD HOC_16-10-13_13-47-47_000.mp4
        sDate := ExtractField(sFile, '_', 4);
        sTime := ExtractField(sFile, '_', 5);
        sCount := ExtractField(sFile, '_', 6);

        bProcess := True;
      End
      Else If (iFields = 7) Then
      Begin
        // JMT_VLV_UIV-15_2017-ROV~124_1_17-10-14_21-08-30_000.mp4
        sDate := ExtractField(sFile, '_', 5);
        sTime := ExtractField(sFile, '_', 6);
        sCount := ExtractField(sFile, '_', 7);

        bProcess := True;
      End;

      If bProcess Then
      Begin
        Try
          dtDate := StrToDate(sDate, 'YY-MM-DD', '-');
        Except
          bProcess := False;
          dtDate := 0;
        End;
        Try
          dtTime := StrToTime(sTime, '-');
        Except
          bProcess := False;
          dtTime := -1;
        End;

        iCount := StrToIntDef(sCount, -1);
        If iCount = -1 Then
          bProcess := False;
      End;

      If bProcess Then
      Begin
        If (dtDate > 0) And (dtTime >= 0) And (iCount >= 0) Then
        Begin
          // Assume each file is 15 minutes long
          dtTime := dtTime + iCount * (15 / (60 * 24));

          If SetFileDate(sPath + sFile + sFileExt, dtDate + dtTime) Then
            Status(Format('%s: %d of %d [%s] Modified date set to "%s"',
              [TimeToStr(Now()), oDataset.RecNo, oDataset.RecordCount, sFile +
              sFileExt, DateTimeToStr(dtDate + dtTime)]))
          Else
            Status(Format('%s: %d of %d [%s] Error changing Modified Date to "%s"',
              [TimeToStr(Now()), oDataset.RecNo, oDataset.RecordCount, sFile +
              sFileExt, DateTimeToStr(dtDate + dtTime)]));
        End
        Else
          Status(Format('%s: %d of %d [%s] Invalid Date, Time or Count',
            [TimeToStr(Now()), oDataset.RecNo, oDataset.RecordCount, sFile +
            sFileExt, DateToStr(dtDate), TimeToStr(dtTime), sCount]));
      End
      Else
        Status(Format('%s: %d of %d [%s] Not Coabis Filename Format',
          [TimeToStr(Now()), oDataset.RecNo, oDataset.RecordCount, sFile + sFileExt]));

      oDataset.Next;
      frmFileWorkbench.pbMain.Position := frmFileWorkbench.pbMain.Position + 1;

      // Ugg
      Application.ProcessMessages;
    End;
  Finally
    Status(Format('%s: Completed conversion', [TimeToStr(Now())]));

    oDataset.EnableControls;

    pbFiles.Style := pbstNormal;
    frmFileWorkbench.pbMain.Position := 0;

    Cursor := crDefault;
    Screen.Cursor := crDefault;

    btnStart.Enabled := frmFileWorkbench.ProcessMeta;
    btnFixDateTime.Enabled := True;
    btnClose.Enabled := True;
  End;
End;

Procedure TdlgConvertVideo.btnStartClick(Sender: TObject);
Var
  oDataset: TBufDataset;
  sFile, sFileExt, sPath, sCommand, sTemp: String;
  fDuration: Extended;
  oParams: TStringList;
  i: Integer;

  Function Converted: Boolean;
  Var
    oMediaInfo: TMediaInfo;
    sConvertedFile: String;
  Begin
    sConvertedFile := sPath + sFile + '.mp4';

    Result := FileExists(sConvertedFile);

    If Result Then
    Begin
      // OK, FileExists, but does the duration match to within 1 second?
      oMediaInfo := ffmpegSupport.MediaInfo(sConvertedFile);

      // Converted if < 2 sec difference (1 sec keyframe)
      If (oMediaInfo.Filename = sConvertedFile) Then
        Result := Abs(oMediaInfo.Duration - fDuration) < 2
      Else
        Result := False;
    End;
  End;

  Procedure Status(AStatus: String);
  Begin
    memResults.Lines.Add(AStatus);
    frmFileWorkbench.Status := AStatus;
  End;

Begin
  oDataset := TagManager.Dataset;

  pbFiles.Style := pbstMarquee;
  frmFileWorkbench.pbMain.Position := 0;
  frmFileWorkbench.pbMain.Max := oDataset.RecordCount;

  pcMain.ActivePage := tsResults;

  Cursor := crHourglass;
  Screen.Cursor := crHourglass;

  btnStart.Enabled := False;
  btnFixDateTime.Enabled := False;
  btnClose.Enabled := False;

  memResults.Lines.Clear;
  Status(Format('%s: Starting processing %d of %d files',
    [TimeToStr(Now()), 1, oDataset.RecordCount]));

  oDataset.DisableControls;
  Try
    oDataset.First;
    While Not oDataset.EOF Do
    Begin
      // processing
      sPath := IncludeSlash(Value(oDataset, 'Path'));
      sFile := Value(oDataset, 'Filename');
      sFileExt := Lowercase(Value(oDataset, 'FileExt'));
      fDuration := ValueAsFloat(oDataset, 'MM_Duration', -1);

      If Not IsVideo(sFileExt) Then
        Status(Format('%s: %d of %d [%s] is in a format not selected for conversion',
          [TimeToStr(Now()), oDataset.RecNo, oDataset.RecordCount, sFile + sFileExt]))
      Else If (Not Converted) Then
      Begin
        // Convert the video;
        If FFmpegPath <> '' Then
        Begin
          Status(Format('%s: %d of %d Converting [%s]', [TimeToStr(Now()),
            oDataset.RecNo, oDataset.RecordCount, sFile + sFileExt]));

          If (sFileExt = '.wmv') Or (sFileExt = '.asf') Then
            sCommand := edtWMV.Text
          Else
            sCommand := edtMPG.Text;

          oParams := TStringList.Create;
          Try
            CommandToList(sCommand, oParams);

            For i := 0 To oParams.Count - 1 Do
            Begin
              sTemp := Uppercase(oParams[i]);
              If sTemp = '%INPUT%' Then
                oParams[i] := Format('"%s"', [sPath + sFile + sFileExt])
              Else If sTemp = '%OUTPUT%' Then
                oParams[i] := Format('"%s"', [sPath + sFile + '.mp4']);
            End;

            sTemp := RunEx(IncludeSlash(FFmpegPath) + 'ffmpeg.exe', oParams,
              True, @ConvertingVideo);

            frmFileWorkbench.Status := sTemp;

            Status(Format('%s: %d of %d Converted [%s]', [TimeToStr(Now()),
              oDataset.RecNo, oDataset.RecordCount, sFile + sFileExt]));
          Finally
            oParams.Free;
          End;
        End;
      End
      Else
        Status(Format('%s: %d of %d [%s] already converted',
          [TimeToStr(Now()), oDataset.RecNo, oDataset.RecordCount, sFile + sFileExt]));

      oDataset.Next;
      frmFileWorkbench.pbMain.Position := frmFileWorkbench.pbMain.Position + 1;

      // Ugg
      Application.ProcessMessages;
    End;
  Finally
    Status(Format('%s: Completed conversion', [TimeToStr(Now())]));

    oDataset.EnableControls;

    pbFiles.Style := pbstNormal;
    frmFileWorkbench.pbMain.Position := 0;

    Cursor := crDefault;
    Screen.Cursor := crDefault;

    btnStart.Enabled := False;
    btnFixDateTime.Enabled := True;
    btnClose.Enabled := True;
  End;
End;

End.
