Unit FormFileWorkbench;

{$mode objfpc}{$H+}

Interface

Uses
  Classes, SysUtils, LazFileUtils, Windows, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, Buttons,
  Menus, ComCtrls, DBCtrls, StdCtrls, FormMain, Inifiles, FrameGrids, DBSupport,
  DB, BufDataset, DBGrids, ThreadFolderParser;

Type

  { TfrmFileWorkbench }

  TfrmFileWorkbench = Class(TfrmMain)
    btnExpression: TToolButton;
    btnProperCase: TToolButton;
    btnLowerCase: TToolButton;
    btnRecalcCount: TToolButton;
    btnRefresh: TToolButton;
    btnSearchReplace: TToolButton;
    btnSelectAll: TToolButton;
    btnUpperCase: TToolButton;
    imgToolbar: TImageList;
    memResults: TMemo;
    pcMain: TPageControl;
    pnlGrid: TPanel;
    dlgExport: TSaveDialog;
    tbToolbar: TToolBar;
    tmrRefreshUI: TTimer;
    ToolButton1: TToolButton;
    btnOpen: TToolButton;
    ToolButton2: TToolButton;
    ToolButton3: TToolButton;
    btnLoadFolder: TToolButton;
    btnInvert: TToolButton;
    btnOpenInExplorer: TToolButton;
    btnClearSelection: TToolButton;
    ToolButton4: TToolButton;
    ToolButton5: TToolButton;
    ToolButton6: TToolButton;
    btnConvertVideo: TToolButton;
    ToolButton7: TToolButton;
    btnExport: TToolButton;
    ToolButton8: TToolButton;
    btnThumbnailer: TToolButton;
    tsFiles: TTabSheet;
    tsResults: TTabSheet;
    Procedure btnClearSelectionClick(Sender: TObject);
    Procedure btnConvertVideoClick(Sender: TObject);
    Procedure btnExportClick(Sender: TObject);
    Procedure btnInvertClick(Sender: TObject);
    Procedure btnCaseRenameClick(Sender: TObject);
    Procedure btnOpenClick(Sender: TObject);
    Procedure btnShowInExplorerClick(Sender: TObject);
    Procedure btnRecalcCountClick(Sender: TObject);
    Procedure btnRefreshClick(Sender: TObject);
    Procedure btnLoadFolderClick(Sender: TObject);
    Procedure btnSelectAllClick(Sender: TObject);
    Procedure btnThumbnailerClick(Sender: TObject);
    Procedure FormActivate(Sender: TObject);
    Procedure FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
    Procedure GridStartDrag(Sender: TObject);
    Procedure tmrRefreshUITimer(Sender: TObject);
  Protected
    FLoaded: Boolean;
    FNoToAll: Boolean;
    FYesToAll: Boolean;
    FDataset: TBufDataset;
    FFolderParser: TFolderParser;
    FProcessMeta: Boolean;

    fmeGrid: TFrameGrid;
    FRootPath, FFilter: String;

    Procedure ConfirmChangeFolder(AFolder, AFilter: String);
    Procedure SetRootPath(AFolder, AMask: String);

    Procedure RefreshUI; Override;

    Procedure SetStatus(AValue: String); Override;

    Procedure FolderParserTerminated(Sender: TObject);

    Procedure InitialiseGrid;
  Public
    Constructor Create(AOwner: TComponent); Override;
    Destructor Destroy; Override;

    Procedure LoadLocalSettings(oInifile: TIniFile); Override;
    Procedure SaveLocalSettings(oInifile: TIniFile); Override;

    Procedure UpdateOptions(FFormOption: TFormOptions); Override;

    Function RenameFile(AOriginal, ADestination: String): Boolean;

    Property RootPath: String read FRootPath;
    Property Grid: TFrameGrid read fmeGrid;
    Property ProcessMeta: Boolean read FProcessMeta write FProcessMeta;
  End;

Var
  frmFileWorkbench: TfrmFileWorkbench;

Implementation

Uses
  StringSupport, FileSupport, OSSupport, Tags, uShellDragDrop, DialogScanFolder,
  DialogConvertVideo, fgl, Exporters, DialogRenameOptions, ffmpegSupport;

  {$R *.lfm}

  { TfrmFileWorkbench }

Constructor TfrmFileWorkbench.Create(AOwner: TComponent);
Begin
  Inherited Create(AOwner);

  FAlwaysSaveSettings := True;

  fmeGrid := TFrameGrid.Create(Self);
  fmeGrid.Parent := pnlGrid;
  fmeGrid.Name := 'fmeGrid';
  fmeGrid.Align := alClient;
  fmeGrid.Editable := True;
  fmeGrid.OnGridStartDrag := @GridStartDrag;

  fmeGrid.Dataset := TagManager.Dataset;
  fmeGrid.InitialiseDataset;

  FNoToAll := False;
  FYesToAll := False;

  pcMain.ActivePage := tsFiles;
  tsResults.TabVisible := False;

  FDataset := nil;

  FRootpath := IncludeSlash(Application.Location);
  FFilter := '*.*';

  FFolderParser := nil;
  FProcessMeta := True;

  RefreshUI;
End;

Destructor TfrmFileWorkbench.Destroy;
Begin
  FreeAndNil(fmeGrid);

  Inherited Destroy;
End;

Procedure TfrmFileWorkbench.FormActivate(Sender: TObject);
Var
  sFolder: String;
Begin
  Inherited;

  If Not FLoaded Then
  Begin
    TagManager.DefineTags;
    InitialiseGrid;

    If Application.ParamCount > 0 Then
    Begin
      sFolder := Application.Params[1];

      If DirectoryExists(sFolder) Then
      Begin
        Refresh;
        ConfirmChangeFolder(sFolder, FFilter);
      End;
    End;

    FLoaded := True;
  End;
End;

Procedure TfrmFileWorkbench.FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
Begin
  Inherited FormCloseQuery(Sender, CanClose);

  If Assigned(FFolderParser) Then
  Begin
    FFolderParser.Terminate;

    While Not FFolderParser.Finished Do
      Sleep(0);
  End;
End;

Procedure TfrmFileWorkbench.RefreshUI;
Var
  bThreadRunning, bHasRecords: Boolean;
Begin
  Inherited;

  FDataset := TagManager.Dataset;

  bThreadRunning := Assigned(FFolderParser);
  If bThreadRunning Then
    bThreadRunning := Not FFolderParser.Finished;

  If (bThreadRunning) And (Screen.Cursor = crDefault) Then
    Screen.Cursor := crHourglass
  Else If (Not bThreadRunning) And (Screen.Cursor = crHourglass) Then
    Screen.Cursor := crDefault;

  bHasRecords := False;
  If Assigned(FDataset) And (FDataset.Active) Then
    bHasRecords := FDataset.RecordCount > 0;

  btnRefresh.Enabled := DirectoryExists(FRootPath) And Not bThreadRunning And FDataset.Active;
  btnLoadFolder.Enabled := Not bThreadRunning;
  fmeGrid.RefreshUI;

  btnExport.Enabled := bHasRecords;

  //fmeGrid.grdSQL.Enabled := bHasRecords;
  btnSelectAll.Enabled := bHasRecords;
  btnClearSelection.Enabled := bHasRecords;
  btnInvert.Enabled := bHasRecords;

  btnOpenInExplorer.Enabled := bHasRecords;
  btnRecalcCount.Enabled := bHasRecords And (fmeGrid.SortField <> 'Count');

  btnProperCase.Enabled := bHasRecords;
  btnUpperCase.Enabled := bHasRecords;
  btnLowerCase.Enabled := bHasRecords;

  btnSearchReplace.Enabled := False;
  btnExpression.Enabled := False;

  btnConvertVideo.Enabled := bHasRecords;
  btnThumbnailer.Enabled := bHasRecords;
End;

Procedure TfrmFileWorkbench.SetStatus(AValue: String);
Var
  sStatus: String;
Begin
  sStatus := FindReplace(AValue, LineEnding, ' ');
  If sStatus <> sbMain.SimpleText Then
  Begin
    Inherited SetStatus(sStatus);

    memResults.Lines.Add(TimeToStr(Now()) + ': ' + sStatus);
    tsResults.TabVisible := True;
  End;
End;

Procedure TfrmFileWorkbench.btnSelectAllClick(Sender: TObject);
Var
  oBookmark: TBookMark;
Begin
  FDataset := TagManager.Dataset;

  fmeGrid.grdSQL.SelectedRows.Clear;

  FDataset.DisableControls;
  oBookmark := FDataset.Bookmark;
  Try
    FDataset.First;
    While Not FDataset.EOF Do
    Begin
      fmeGrid.grdSQL.SelectedRows.CurrentRowSelected := True;
      FDataset.Next;
    End;
  Finally
    If FDataset.BookmarkValid(oBookmark) Then
      FDataset.GotoBookmark(oBookmark);

    FDataset.EnableControls;
  End;
End;

Procedure TfrmFileWorkbench.btnThumbnailerClick(Sender: TObject);
Var
  sPath, sBase, sVideoFilename, sThumbnail, sPoster, sTemp: String;
  oBookmark: TBookMark;
Begin
  // TODO put all this in a thread...
  InitializeFFmpeg;

  If FFmpegAvailable Then
  Begin
    FDataset := TagManager.Dataset;
    pbMain.Max := FDataset.RecordCount;
    pbMain.Position := 0;
    pbMain.Visible := True;

    FDataset.DisableControls;
    oBookmark := FDataset.Bookmark;
    Try
      FDataset.First;
      While Not FDataset.EOF Do
      Begin
        If IsVideo(FDataset['FileExt']) Then
        Begin
          sPath := IncludeSlash(FDataset['Path']);
          sBase := sPath + FDataset['Filename'];
          sVideoFilename := sBase + FDataset['FileExt'];
          sThumbnail := sBase + '-thumb.jpg';
          sPoster := sBase + '-poster.jpg';

          If (Not FileExists(sThumbnail)) And (Not FileExists(sPoster)) Then
          Begin
            SetStatus(sThumbnail);

            sTemp := CreateThumbnail(sVideoFilename, sThumbnail);

            If Trim(sTemp) <> '' Then
            Begin
              FDataset.Edit;
              FDataset['Temp'] := sTemp;
              FDataset.Post;
            End;
          End;
        End;

        FDataset.Next;
        pbMain.Position := pbMain.Position + 1;

        // TODO: you're FIRED!
        If (pbMain.Position Mod 100) = 0 Then
        Begin
          Application.ProcessMessages;
        End;
      End;
    Finally
      If FDataset.BookmarkValid(oBookmark) Then
        FDataset.GotoBookmark(oBookmark);

      FDataset.FreeBookmark(oBookmark);

      FDataset.EnableControls;

      SetStatus('');
      pbMain.Visible := False;
    End;
  End;
End;

Procedure TfrmFileWorkbench.btnInvertClick(Sender: TObject);
Var
  bSelected: Boolean;
  oBookmark: TBookMark;
Begin
  FDataset := TagManager.Dataset;

  FDataset.DisableControls;
  oBookmark := FDataset.Bookmark;
  Try
    FDataset.First;
    While Not FDataset.EOF Do
    Begin
      bSelected := fmeGrid.grdSQL.SelectedRows.CurrentRowSelected;
      fmeGrid.grdSQL.SelectedRows.CurrentRowSelected := Not bSelected;

      FDataset.Next;
    End;
  Finally
    If FDataset.BookmarkValid(oBookmark) Then
      FDataset.GotoBookmark(oBookmark);

    FDataset.FreeBookmark(oBookmark);

    FDataset.EnableControls;
  End;
End;

Procedure TfrmFileWorkbench.btnCaseRenameClick(Sender: TObject);
Var
  oBookmark: TBookMark;
  sPath: String;
  i, iCount, iSkipped: Integer;
  iRenamed, iFailed: Integer;
  sFilename: String;
  sRelativePath, sNew: String;
  dlgOptions: TdlgRenameOptions;
  optRename: TRenameOptions;
  optCase: TCaseOperation;
Begin
  FDataset := TagManager.Dataset;
  If Not FDataset.Active Then
    Exit;

  If Not Assigned(Sender) Then
    Exit;

  If Not (Sender Is TComponent) Then
    Exit;

  optCase := TCaseOperation(TComponent(Sender).Tag);

  dlgOptions := TdlgRenameOptions.Create(Self);
  Try
    Case (optCase) Of
      coLowercase: dlgOptions.Caption := 'Change selection to lower case';
      coUppercase: dlgOptions.Caption := 'Change selection to UPPER CASE';
      coPropercase: dlgOptions.Caption := 'Change selection to Proper Case';
    End;

    optRename := [];
    If dlgOptions.ShowModal = mrOk Then
      optRename := dlgOptions.Options;
  Finally
    dlgOptions.Free;
  End;

  If optRename = [] Then
    Exit;

  Busy := True;
  Try
    i := 0;
    iSkipped := 0;
    iRenamed := 0;
    iFailed := 0;
    iCount := FDataset.RecordCount;

    If roFolders In optRename Then
    Begin
      // Can't rename the folders by iterating the file list.
      SetStatus('Renaming subfolders of ' + FRootpath);
      Application.ProcessMessages;
      RenameSubfolders(FRootPath, TRenameSubFolderOption(optCase));
      SetStatus('Renamed subfolders of ' + FRootpath);
    End;

    // But we can rename files by iterating the filelist
    oBookmark := FDataset.Bookmark;
    FDataset.DisableControls;
    fmeGrid.grdSQL.Enabled := False;
    Try
      FDataset.First;
      While Not FDataset.EOF Do
      Begin
        sPath := IncludeSlash(FDataset['Path']);

        If roFiles In optRename Then
        Begin
          sFilename := FDataset['Filename'] + FDataset['FileExt'];
          sNew := ChangeCase(sFilename, optCase);

          If sFilename = sNew Then
          Begin
            FDataset.Edit;
            Try
              Inc(iSkipped);
              FDataset['Temp'] := 'Skipped';
            Finally
              FDataset.Post;
            End;
          End
          Else If FileRename(sPath + sFilename, sPath + sNew) Then
          Begin
            Inc(iRenamed);
            FDataset.Edit;
            Try
              FDataset['Filename'] := ExtractFileNameWithoutExt(sNew);
              FDataset['FileExt'] := ExtractFileExt(sNew);

              FDataset['Temp'] := 'Renamed';
            Finally
              FDataset.Post;
            End;
          End
          Else
          Begin
            FDataset.Edit;
            Try
              Inc(iFailed);
              FDataset['Temp'] := 'Failed';
            Finally
              FDataset.Post;
            End;
          End;
        End;

        If roFolders In optRename Then
        Begin
          sRelativePath := Copy(sPath, Length(IncludeSlash(FRootpath)) + 1, Length(sPath));
          FDataset.Edit;
          Try
            If FDataset['Temp'] = '' Then
              FDataset['Temp'] := 'Renamed';

            FDataset['Path'] := IncludeSlash(FRootpath) + ChangeCase(sRelativePath, optCase);
          Finally
            FDataset.Post;
          End;
        End;

        If (i Mod 50 = 0) Then
        Begin
          SetStatus(Format(
            'Total %d files: %d renamed, %d skipped, %d failed to rename.  Last file: %s',
            [iCount, iRenamed, iSkipped, iFailed, sFilename]));
          Application.ProcessMessages;
        End;

        Inc(i);

        FDataset.Next;
      End;
    Finally
      SetStatus(Format('Total %d files: %d renamed, %d skipped, %d failed to rename',
        [iCount, iRenamed, iSkipped, iFailed]));

      If FDataset.BookmarkValid(oBookmark) Then
        FDataset.GotoBookmark(oBookmark);
      FDataset.FreeBookmark(oBookmark);

      fmeGrid.grdSQL.Enabled := True;
      FDataset.EnableControls;
    End;
  Finally
    Busy := False;
  End;
End;

Procedure TfrmFileWorkbench.btnClearSelectionClick(Sender: TObject);
Begin
  fmeGrid.grdSQL.SelectedRows.Clear;
End;

Procedure TfrmFileWorkbench.btnConvertVideoClick(Sender: TObject);
Var
  dlgConvertVideo: TdlgConvertVideo;
Begin
  dlgConvertVideo := TdlgConvertVideo.Create(Self);
  Try
    dlgConvertVideo.ShowModal;

  Finally
    dlgConvertVideo.Free;
  End;
End;

Procedure TfrmFileWorkbench.btnExportClick(Sender: TObject);
Var
  sExt: String;
  oExporter: TExporter;
Begin
  If dlgExport.Execute Then
  Begin
    sExt := Lowercase(ExtractFileExt(dlgExport.FileName));

    oExporter := ExporterFactory.CreateExporter(sExt, dlgExport.Filename);

    Try
      oExporter.BeginDocument;
      oExporter.Dataset(TagManager.Dataset, teAll);
      oExporter.EndDocument;
      oExporter.Save;
    Finally
      oExporter.Free
    End;

    If MessageDlg('Open File', 'Would you like to try and open the file?',
      mtConfirmation, mbYesNo, 0) = mrYes Then
      LaunchDocument(dlgExport.Filename);
  End;
End;

Procedure TfrmFileWorkbench.btnShowInExplorerClick(Sender: TObject);
Var
  sFilename: String;
Begin
  FDataset := TagManager.Dataset;
  If (FDataset.Active) And (Not FDataset.IsEmpty) Then
  Begin
    sFilename := FDataset['Original'];
    If (sFilename <> '') And FileExists(sFilename) Then
      LaunchFile('explorer.exe', Format('/e,/select,"%s"', [sFilename]));
  End;
End;

Procedure TfrmFileWorkbench.btnOpenClick(Sender: TObject);
Var
  sFilename: String;
Begin
  FDataset := TagManager.Dataset;
  If (FDataset.Active) And (Not FDataset.IsEmpty) Then
  Begin
    sFilename := FDataset['Original'];
    If (sFilename <> '') And FileExists(sFilename) Then
      LaunchDocument(sFilename);
  End;
End;

Type
  TPathCount = Specialize TFPGMap<String, Integer>;

Procedure TfrmFileWorkbench.btnRecalcCountClick(Sender: TObject);
Var
  oList: TPathCount;
  oBookmark: TBookMark;
  sPath: String;
  iIndex: Longint;
  iCount: Integer;
Begin
  FDataset := TagManager.Dataset;
  If FDataset.Active Then
  Begin
    oList := TPathCount.Create;
    oList.Sorted := True;
    Try
      oBookmark := FDataset.Bookmark;
      FDataset.DisableControls;
      Try
        FDataset.First;
        While Not FDataset.EOF Do
        Begin
          sPath := FDataset['Path'];
          iIndex := oList.IndexOf(sPath);

          If iIndex = -1 Then
            iCount := 0
          Else
            iCount := oList.Data[iIndex];

          iCount := iCount + 1;
          FDataset.Edit;
          FDataset['Count'] := iCount;
          FDataset.Post;

          If iIndex = -1 Then
            oList.Add(sPath, iCount)
          Else
            oList.Data[iIndex] := iCount;

          FDataset.Next;
        End;
      Finally
        If FDataset.BookmarkValid(oBookmark) Then
          FDataset.GotoBookmark(oBookmark);
        FDataset.FreeBookmark(oBookmark);

        FDataset.EnableControls;
      End;
    Finally
      oList.Free;
    End;
  End;
End;

Procedure TfrmFileWorkbench.btnRefreshClick(Sender: TObject);
Begin
  SetRootpath(FRootpath, FFilter);
End;

Procedure TfrmFileWorkbench.ConfirmChangeFolder(AFolder, AFilter: String);
Var
  oDlg: TdlgScanFolder;
Begin
  oDlg := TdlgScanFolder.Create(Self);
  Try
    // Fix issue if directory does not exist
    If DirectoryExists(AFolder) Then
      oDlg.Folder := AFolder;

    oDlg.Filter := AFilter;
    oDlg.ProcessMeta := FProcessMeta;

    If oDlg.ShowModal = mrOk Then
    Begin
      FProcessMeta := oDlg.ProcessMeta;
      SetRootPath(oDlg.Folder, oDlg.Filter);
    End;
  Finally
    oDlg.Free;
  End;
End;

Procedure TfrmFileWorkbench.btnLoadFolderClick(Sender: TObject);
Begin
  ConfirmChangeFolder(FRootpath, FFilter);
End;

Procedure TfrmFileWorkbench.GridStartDrag(Sender: TObject);
Var
  oFiles: TStringList;
  oBookmark, oRow: TBookMark;
  sFilename: String;
Begin
  oFiles := TStringList.Create;
  oFiles.Sorted := True;
  oFiles.Duplicates := dupIgnore;

  Busy := True;
  Try
    FDataset := TagManager.Dataset;

    oBookmark := FDataset.Bookmark;
    FDataset.DisableControls;
    Try
      For oRow In fmeGrid.grdSQL.SelectedRows Do
      Begin
        FDataset.GotoBookmark(oRow);
        sFilename := FDataset['Original'];
        If FileExists(sFilename) Then
          oFiles.Add(sFilename);
      End;
    Finally
      If FDataset.BookmarkValid(oBookmark) Then
        FDataset.GotoBookmark(oBookmark);

      FDataset.FreeBookmark(oBookmark);
      FDataset.EnableControls;
    End;

    DragDropCopyComplete(oFiles);
  Finally
    oFiles.Free;
    Busy := False;
  End;
End;

Procedure TfrmFileWorkbench.SetRootPath(AFolder, AMask: String);
Begin
  FRootPath := IncludeSlash(AFolder);
  FFilter := AMask;

  TagManager.ClearFiles;
  TagManager.BeginUpdate;
  InitialiseGrid;

  Status := Format('Setting RootPath="%s", Filemask="%s"', [AFolder, AMask]);

  FFolderParser := TFolderParser.Create(True);
  FFolderParser.OnTerminate := @FolderParserTerminated;
  FFolderParser.Rootpath := AFolder;
  FFolderParser.Filter := AMask;
  FFolderParser.ParseFiles := True;
  FFolderParser.ProcessMeta := FProcessMeta;
  FFolderParser.FreeOnTerminate := True;

  pbMain.Max := 1;
  pbMain.Position := 0;
  pbMain.Visible := True;

  tmrRefreshUI.Enabled := True;
  Screen.Cursor := crHourglass;

  RefreshUI;

  FFolderParser.Start;
End;

Procedure TfrmFileWorkbench.tmrRefreshUITimer(Sender: TObject);
Begin
  If Assigned(FFolderParser) And (Not FFolderParser.Finished) Then
  Begin
    Status := TimeToStr(FFolderParser.Remaining) + ' - ' + FFolderParser.Status;

    If FFolderParser.FileCount > 0 Then
    Begin
      pbMain.Visible := True;
      pbMain.Max := FFolderParser.FileCount;
      pbMain.Position := FFolderParser.FilesProcessed;
    End;
  End
  Else
  Begin
    pbMain.Position := 0;
    pbMain.Visible := False;
  End;
End;

Procedure TfrmFileWorkbench.FolderParserTerminated(Sender: TObject);
Var
  i: Integer;
  oColumn: TColumn;
Begin
  Screen.Cursor := crDefault;

  tmrRefreshUI.Enabled := False;

  pbMain.Position := 0;
  pbMain.Visible := False;
  If Assigned(FFolderParser) Then
  Begin
    Caption := Format('File Workbench: [%s: %s]', [FFilter, FRootpath]);
    Status := 'Completed scan:';
    For i := 0 To FFolderParser.ExtStats.Count - 1 Do
      If FFolderParser.ExtStats.Data[i] > 0 Then
        Status := Format('     %d with extension %s',
          [FFolderParser.ExtStats.Data[i], FFolderParser.ExtStats.Keys[i]]);

    Status := Format('%s: %d files scanned', [FRootpath, FFolderParser.FileCount]);
  End;

  // Ensure the dataset is sorted (Thread loading means it's randomised by default)
  oColumn := fmeGrid.grdSQL.Columns.ColumnByFieldname('Original');
  If Assigned(oColumn) Then
    fmeGrid.grdSQLTitleClick(oColumn);

  TagManager.EndUpdate;

  InitialiseGrid;

  FFolderParser := nil;

  RefreshUI;
End;

Procedure TfrmFileWorkbench.InitialiseGrid;
Var
  oColumn: TColumn;
  oTagDef: TMetaTag;
  i: Integer;
  bVisible: Boolean;
  sTemp: String;
Begin
  {
     A note on the visibility of columns
     All the column visibility in fmeGrid.InitialiseDBGrid(False); is
     completely overridden by the later code.

     TagManager has a list of "Visible Columns".  If a column isn't in this
     list, it's hidden. (TagManager.VisibleFields.IndexOf(sTemp) <> -1)

     I missed this, which is why I put in the 'ID" code.
  }
  // TODO I should remove 'ID' special case code, then find a way of removing
  //  the columns I want to remain hidden from the TagManager.VisibleField

  For i := 0 To fmeGrid.grdSQL.Columns.Count - 1 Do
    fmeGrid.grdSQL.Columns[i].Visible := True;

  fmeGrid.InitialiseDBGrid(False);

  For i := 0 To fmeGrid.grdSQL.Columns.Count - 1 Do
  Begin
    oColumn := fmeGrid.grdSQL.Columns[i];
    sTemp := oColumn.FieldName;
    bVisible := RightStr(oColumn.FieldName, 2) <> 'ID';
    bVisible := bVisible And (TagManager.VisibleFields.IndexOf(sTemp) <> -1);
    oColumn.Visible := bVisible;

    oTagDef := TagManager.TagDefByName(oColumn.FieldName);
    If Assigned(oTagDef) Then
    Begin
      oColumn.ReadOnly := oTagDef.ReadOnly;

      If oTagDef.ReadOnly Then
        fmeGrid.AddReadOnlyField(oTagDef.Name);
    End;
  End;
End;

Procedure TfrmFileWorkbench.LoadLocalSettings(oInifile: TIniFile);
Begin
  Inherited LoadLocalSettings(oInifile);

  FRootPath := oInifile.ReadString('Main', 'Rootpath', FRootPath);
  FFilter := oInifile.ReadString('Main', 'Filter', FFilter);
  FProcessMeta := oInifile.ReadBool('Metadata', 'Process', FProcessMeta);

  fmeGrid.LoadSettings(oInifile);
End;

Procedure TfrmFileWorkbench.SaveLocalSettings(oInifile: TIniFile);
Begin
  Inherited SaveLocalSettings(oInifile);

  oInifile.WriteString('Main', 'Rootpath', FRootPath);
  oInifile.WriteString('Main', 'Filter', FFilter);
  oInifile.WriteBool('Metadata', 'Process', FProcessMeta);

  fmeGrid.SaveSettings(oInifile);
End;

Procedure TfrmFileWorkbench.UpdateOptions(FFormOption: TFormOptions);
Begin
  Inherited UpdateOptions(FFormOption);

  If olMultilineGrid In FFormOption Then
    If fmeGrid.UseMultilineDefaults Then
      fmeGrid.AllowMultiline := FOptions.MultilineGridDefaults;
End;

Function TfrmFileWorkbench.RenameFile(AOriginal, ADestination: String): Boolean;
Var
  mrResult: TModalResult;
Begin
  Result := False;

  If (AOriginal <> ADestination) And (FileExists(AOriginal)) And (Not FNoToAll) Then
  Begin { If }
    If FYesToAll Then
      mrResult := mrYes
    Else
      mrResult := MessageDlg('Are you sure you wish to rename' + #13 + #10 +
        AOriginal + #13 + #10 + ' to ' + #13 + #10 + ADestination, mtWarning,
        [mbYes, mbNo, mbYesToAll, mbNoToAll], 0);

    If mrResult = mrYesToAll Then
      FYesToAll := True
    Else If mrResult = mrNoToAll Then
    Begin
      FNoToAll := True;

      Exit;
    End;

    If (mrResult = mrYes) Or (mrResult = mrYesToAll) Then
      If FileSupport.FileRename(AOriginal, ADestination) Then
      Begin
        tsResults.TabVisible := True;

        memResults.Lines.Add(AOriginal);
        memResults.Lines.Add(ADestination);
        memResults.Lines.Add('');
        Result := True;
      End
      Else
      Begin
        memResults.Lines.Add('');
        memResults.Lines.Add('Failed:' + AOriginal);
        memResults.Lines.Add('   New:' + ADestination);
        memResults.Lines.Add('<' + SysErrorMessage(GetLastError) + '>');
        memResults.Lines.Add('');

        ShowMessage('Failed to rename ' + #13 + #10 + AOriginal + #13 + #10 +
          ' to ' + #13 + #10 + ADestination);
      End;
  End;
End;

End.
