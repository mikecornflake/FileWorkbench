Unit ThreadFolderParser;

{$mode objfpc}{$H+}

Interface

Uses
  Classes, SysUtils, Tags, fgl;

Type
  TFileData = Class
    Parent, Parent2: String;
    Filename: String;
    Ext: String;
    Path: String;
    Date: TDateTime;
    Size: Int64;
    Count: Integer;
  End;

  TExtStats = Specialize TFPGMap<String, Integer>; // sExt, Count
  TFilesList = Specialize TFPGMapObject<String, TFileData>;

  TFolderParser = Class;

  { TFileParser }

  TFileParser = Class(TThread)
  Private
    FFolderParser: TFolderParser;
    FFilename: String;
    FFileData: TFileData;
    FFileHandlers: TMetaFileHandlerList;
    FFileSystemTags: TMetaFileHandler;
    FProcessMeta: Boolean;
    Procedure DoAppendFile;
    Procedure DoSafeParseFile;
    Procedure ParseFile;
  Public
    Constructor Create(CreateSuspended: Boolean; AFolderParser: TFolderParser);
    Destructor Destroy; Override;

    Procedure Execute; Override;
    Property ProcessMeta: Boolean read FProcessMeta write FProcessMeta;
  End;

  { TFolderParser }

  TFolderParser = Class(TThread)
  Private
    FAccessCriticalSection: TRTLCriticalSection;
    FFileCount: Integer;
    FFilesProcessed: Integer;
    FParseFiles: Boolean;
    FProcessMeta: Boolean;
    FRootpath, FFilter: String;
    FStatus: String;
    FExtStats: TExtStats;
    FFiles: TFilesList;
    FFileThreadsRunning: Integer;
    FStarted, FRemaining: TDateTime;

    Procedure DoParseFolder(AFolder: String);
    Procedure DoFileThreadTerminated(Sender: TObject);
  Public
    Constructor Create(CreateSuspended: Boolean);
    Destructor Destroy; Override;

    Procedure Execute; Override;

    Procedure Pop(Var AFilename: String; Var AFiledata: TFileData);

    Property Rootpath: String read FRootpath write FRootpath;
    Property Filter: String read FFilter write FFilter;
    Property FilesProcessed: Integer read FFilesProcessed;
    Property FileCount: Integer read FFileCount;
    Property Remaining: TDateTime read FRemaining;
    Property Status: String read FStatus write FStatus;

    Property ParseFiles: Boolean read FParseFiles write FParseFiles;
    Property ProcessMeta: Boolean read FProcessMeta write FProcessMeta;

    Property ExtStats: TExtStats read FExtStats;
    Property Files: TFilesList read FFiles;
  End;

Const
  GThreadCount: Integer = 48;

Implementation

Uses
  FileSupport, StringSupport, TagFileSystem;

  { TFileParser }

Constructor TFileParser.Create(CreateSuspended: Boolean; AFolderParser: TFolderParser);
Begin
  Inherited Create(CreateSuspended);
  FFolderParser := AFolderParser;
  FFilename := '';
  FFileData := nil;
  FProcessMeta := True;
End;

Destructor TFileParser.Destroy;
Begin
  FreeAndNil(FFileData);
  Inherited Destroy;
End;

Procedure TFileParser.Execute;
Begin
  While Not Terminated And Not (FFolderParser.Finished) And (FFolderParser.Files.Count > 0) Do
  Begin
    FFolderParser.Pop(FFilename, FFileData);

    If Assigned(FFileData) Then
    Begin
      ParseFile;
      FreeAndNil(FFileData);
    End;

    ThreadSwitch;
  End;
End;

Procedure TFileParser.ParseFile;
Var
  sTemp: String;
Begin
  FFileHandlers := TMetaFileHandlerList.Create(True);
  Try
    FFileSystemTags := TTagFileSystem.Create;
    FFileHandlers.Add(FFileSystemTags);

    FFileSystemTags.Tag['Filename'] := FFileData.Filename;
    FFileSystemTags.Tag['FileExt'] := FFileData.Ext;
    FFileSystemTags.Tag['Path'] := FFileData.Path;
    FFileSystemTags.Tag['Date'] := FFileData.Date;
    FFileSystemTags.Tag['Size'] := FFileData.Size;
    FFileSystemTags.Tag['Count'] := FFileData.Count;
    FFileSystemTags.Tag['Parent'] := FFileData.Parent;
    FFileSystemTags.Tag['Parent2'] := FFileData.Parent2;

    FFileSystemTags.Tag['Original'] := FFilename;

    sTemp := Format('Parsing File (%d of %d): %s', [FFolderParser.FilesProcessed,
      FFolderParser.FileCount, FFilename]);
    FFolderParser.Status := sTemp;

    If Not Terminated Then
      If FProcessMeta Then
        TagManager.ParseFile(FFileSystemTags, FFileHandlers);

    If Not Terminated Then
      Synchronize(@DoAppendFile);
  Finally
    FreeAndNil(FFileHandlers);
  End;
End;

Procedure TFileParser.DoSafeParseFile;
Begin

End;

Procedure TFileParser.DoAppendFile;
Begin
  TagManager.AppendFile(FFileHandlers);
End;

{ TFolderParser }

Constructor TFolderParser.Create(CreateSuspended: Boolean);
Begin
  Inherited Create(CreateSuspended);
  FRootpath := '';
  FFilter := '*.*';
  FFileCount := -1;
  FFilesProcessed := -1;
  FStatus := '';
  FFileThreadsRunning := 0;
  FProcessMeta := True;

  FExtStats := TExtStats.Create;
  FExtStats.Sorted := True;

  FFiles := TFilesList.Create(False);
  FFiles.Sorted := True;
  FFiles.Duplicates := dupError;

  FParseFiles := False;
End;

Destructor TFolderParser.Destroy;
Begin
  While FFiles.Count > 0 Do
  Begin
    FFiles.Data[FFiles.Count - 1].Free;
    FFiles.Delete(FFiles.Count - 1);
  End;
  FreeAndNil(FFiles);
  FreeAndNil(FExtStats);

  Inherited Destroy;
End;

Procedure TFolderParser.Execute;
Var
  iExtCount, iExt: Integer;
  sExt: String;
  i: Integer;
  oThread: TFileParser;
  iThreadCount: Integer;
  iCPUCount: Integer;
Begin
  FExtStats.Clear;
  FFiles.Clear;
  FStarted := Now;

  If (FFilter <> '*.*') Then
  Begin
    iExtCount := Count(';', FFilter);

    iExt := 0;
    While (iExt <= iExtCount) Do
    Begin
      sExt := ExtractField(FFilter, ';', iExt);
      FExtStats.Add(FindReplace(sExt, '*', ''), 0);

      Inc(iExt);
    End;
  End;

  FFileCount := 0;
  FFilesProcessed := 0;

  // Scan all the folders
  DoParseFolder(FRootpath);

  If FParseFiles Then
  Begin
    FFileThreadsRunning := 0;

    iCPUCount := GetCPUCount;
    iThreadCount := GThreadCount;

    If GThreadCount > iCPUCount Then
    Begin
      If iCPUCount >= 3 Then
        iThreadCount := Trunc(0.75* iCPUCount)
      Else
        iThreadCount := 1;
    End;

    FStatus := Format('%d threads will be created', [iThreadCount]);

    InitCriticalSection(FAccessCriticalSection);
    Try
      For i := 0 To iThreadCount - 1 Do
        If FFiles.Count > 0 Then
        Begin
          oThread := TFileParser.Create(True, Self);
          oThread.ProcessMeta := FProcessMeta;
          oThread.FreeOnTerminate := True;
          oThread.OnTerminate := @DoFileThreadTerminated;
          Inc(FFileThreadsRunning);

          oThread.Start;
        End;

      While (Not Terminated) And (FFileThreadsRunning > 0) Do
        ThreadSwitch;
    Finally
      DoneCriticalsection(FAccessCriticalSection);
    End;
  End;
End;

Procedure TFolderParser.Pop(Var AFilename: String; Var AFiledata: TFileData);
Var
  i: Integer;
  dtTemp: TDateTime;
Begin
  EnterCriticalSection(FAccessCriticalSection);
  Try
    AFilename := '';
    AFiledata := nil;

    If FFiles.Count > 0 Then
    Begin
      i := FFiles.Count - 1;
      AFilename := FFiles.Keys[i];
      AFiledata := FFiles.Data[i];
      FFiles.Delete(i);

      FFilesProcessed := FFileCount - i;
      dtTemp := Now - FStarted;
      FRemaining := dtTemp * ((FFileCount / FFilesProcessed) - 1);
    End;
  Finally
    LeaveCriticalsection(FAccessCriticalSection);
  End;
End;

Procedure TFolderParser.DoParseFolder(AFolder: String);
Var
  srSearch: TSearchRec;
  iError: Integer;
  iFileCountInFolder: Integer;
  sExt, sFilename: String;
  iExt: Longint;
  oFileData: TFileData;
  sParent, sParent2: String;
  iMaxLevel: Integer;

  Function FolderAtLevel(iLevel: Integer): String;
  Begin
    If iLevel > 0 Then
      Result := ExtractField(AFolder, PathDelim, iLevel)
    Else
      Result := '';
  End;

Begin
  FStatus := Format('Parsing folder: %s', [AFolder]);
  AFolder := IncludeSlash(AFolder);

  // First. Parse The Folders in this folder
  iError := SysUtils.FindFirst(AFolder + '*.*', faDirectory, srSearch);
  Try
    While (iError = 0) Do
    Begin
      If (srSearch.Name <> '.') And (srSearch.Name <> '..') And
        ((srSearch.Attr And faDirectory) = faDirectory) Then
        DoParseFolder(AFolder + srSearch.Name);

      iError := SysUtils.FindNext(srSearch);
    End;
  Finally
    SysUtils.FindClose(srSearch);
  End;

  // And now we process the files in this Folder
  iMaxLevel := Count(PathDelim, AFolder);
  sParent := FolderAtLevel(iMaxLevel - 1);
  sParent2 := FolderAtLevel(iMaxLevel - 2);
  iFileCountInFolder := 0;

  iError := SysUtils.FindFirst(AFolder + '*.*', faAnyFile, srSearch);
  Try
    While (iError = 0) Do
    Begin
      If (srSearch.Name <> '.') And (srSearch.Name <> '..') And
        ((srSearch.Attr And faDirectory) <> faDirectory) Then
      Begin
        sExt := ExtractFileExt(srSearch.Name);
        iExt := FExtStats.IndexOf(sExt);
        If (iExt = -1) And (FFilter = '*.*') Then
          iExt := FExtStats.Add(sExt, 0);

        If iExt <> -1 Then
        Begin
          sFilename := AFolder + srSearch.Name;
          FFileCount := FFileCount + 1;
          iFileCountInFolder := iFileCountInFolder + 1;  // Number of files in this folder
          FStatus := Format('Found %d files:  %s', [FFileCount, sFilename]);

          oFileData := TFileData.Create;
          oFileData.Filename := ChangeFileExt(srSearch.Name, '');
          oFileData.Date := FileDateToDateTime(srSearch.Time);
          oFileData.Size := srSearch.Size;
          oFileData.Ext := sExt;
          oFileData.Path := AFolder;

          oFileData.Count := iFileCountInFolder;
          oFileData.Parent := sParent;
          oFileData.Parent2 := sParent2;

          FFiles.Add(sFilename, oFileData);

          FExtStats.Data[iExt] := FExtStats.Data[iExt] + 1;
        End;
      End;

      iError := SysUtils.FindNext(srSearch);
    End;
  Finally
    SysUtils.FindClose(srSearch);
  End;
End;

Procedure TFolderParser.DoFileThreadTerminated(Sender: TObject);
Begin
  Dec(FFileThreadsRunning);

  ThreadSwitch;
End;

End.
