Unit Tags;

{$mode objfpc}{$H+}
{$WARN 5024 off : Parameter "$1" not used}

Interface

Uses
  Classes, SysUtils, DB, DBSupport, BufDataset, Menus, fgl, Contnrs;

Const
  BLANK = '<blank>';

Type

  { TMetaTag }

  TMetaTag = Class(TObject)
  Public
    Name: String;
    FieldType: TFieldType;
    Size: Integer;
    ReadOnly: Boolean;
    Value: Variant;
    Hidden: Boolean;

    Constructor Create(AName: String; AFieldType: TFieldType; ASize: Integer = -1;
      AReadOnly: Boolean = False; AHidden: Boolean = False);
  End;

  TMetaTagList = Specialize TFPGMapObject<String, TMetaTag>;

  { TMetaFileHandler }

  TMetaFileHandler = Class(TObject)
  Protected
    FCommon: TMetaFileHandler;
    FTags: TMetaTagList;
    FFilter: String;
    FHasTags: Boolean;
    FFilename: String;

    Procedure ClearTags;

    Function GetTag(AName: String): Variant;
    Procedure SetTag(AName: String; AValue: Variant); Virtual;
  Public
    Constructor Create; Virtual;
    Destructor Destroy; Override;

    Procedure AddTag(AName: String; AFieldType: TFieldType; ASize: Integer = -1;
      AReadOnly: Boolean = False; AHidden: Boolean = False);

    Function Writeable: Boolean; Virtual;

    Function Name: String; Virtual;

    Function ParseFile(AFilename: String): Boolean; Virtual;
    Function Update(AFilename: String; ATags, AValues: Array Of String): Boolean;
    Function Commit: Boolean; Virtual;

    Function TagByName(AName: String): TMetaTag;

    Property HasTags: Boolean read FHasTags;
    Property Filename: String read FFilename;
    Property Filter: String read FFilter write FFilter;

    Property Tags: TMetaTagList read FTags;
    Property Tag[AName: String]: Variant read GetTag write SetTag;

    Property Common: TMetaFileHandler read FCommon write FCommon;
  End;

  TMetaFileHandlerClass = Class Of TMetaFileHandler;
  TMetaFileHandlerList = Specialize TFPGObjectList<TMetaFileHandler>;

  { TTagManager }

  TTagManager = Class(TObject)
  Private
    FMetaFileHandlerClassByExt: TFPHashList; // The Factory

    FFiles: TMemTable;
    FFileSystemTags: TMetaFileHandler;
    FMetaFileHandlers: TMetaFileHandlerList;
    // Contains a unique instance of each created MetaFileHandler
    FVisibleFields: TStringList;

    FDBLock: TRTLCriticalSection;

    Function GetDataset: TBufDataset;

    Function GetMetaFileHandler(AIndex: Integer): TMetaFileHandler;
    Function GetTag(AName: String): Variant;
    Procedure SetTag(AName: String; AValue: Variant);

    Procedure DoGetMemo(Sender: TField; Var aText: String; DisplayText: Boolean);
    Procedure DoSetText(Sender: TField; Const aText: String);
  Public
    Constructor Create;
    Destructor Destroy; Override;

    Procedure BeginUpdate;
    Procedure EndUpdate;

    Procedure DefineTags;
    Function TagDefByName(AName: String): TMetaTag;

    Procedure ParseFile(ACommon: TMetaFileHandler; ATags: TMetaFileHandlerList);
    Procedure AppendFile(ATags: TMetaFileHandlerList);
    Procedure ClearFiles;

    Procedure Register(AMetaFileHandler: TMetaFileHandlerClass; AFileExt: Array Of String);

    Function Update(AFilename, ATag, AValue: String): Boolean; Overload;
    Function Update(AFilename: String; ATags, AValues: Array Of String): Boolean; Overload;

    Property Dataset: TBufDataset read GetDataset;
    Property MetaFileHandlers: TMetaFileHandlerList read FMetaFileHandlers;
    Property Tag[AName: String]: Variant read GetTag write SetTag;
    Property VisibleFields: TStringList read FVisibleFields;
  End;

Function TagManager: TTagManager;

Implementation

Uses
  StringSupport, TagFileSystem;

Var
  lTagManager: TTagManager;
  lVisibleFieldLock: TRTLCriticalSection;

Function TagManager: TTagManager;
Begin
  If Not assigned(lTagManager) Then
    lTagManager := TTagManager.Create;

  Result := lTagManager;
End;

{ TMetaTag }

Constructor TMetaTag.Create(AName: String; AFieldType: TFieldType; ASize: Integer;
  AReadOnly: Boolean; AHidden: Boolean = False);
Begin
  Name := AName;
  FieldType := AFieldType;
  Size := ASize;
  ReadOnly := AReadOnly;
  Value := Null;
  Hidden := AHidden;
End;

{ TMetaFileHandler }

Constructor TMetaFileHandler.Create;
Begin
  FTags := TMetaTagList.Create(True);

  FHasTags := False;

  FFilter := '';
  FCommon := nil;
End;

Destructor TMetaFileHandler.Destroy;
Begin
  FreeAndNil(FTags);

  Inherited Destroy;
End;

Function TMetaFileHandler.Writeable: Boolean;
Begin
  Result := False;
End;

Function TMetaFileHandler.ParseFile(AFilename: String): Boolean;
Begin
  Result := False;
  FFilename := AFilename;

  ClearTags;
End;

Function TMetaFileHandler.Update(AFilename: String; ATags, AValues: Array Of String): Boolean;
Var
  i: Integer;
  oTag: TMetaTag;
  sTag, sValue: String;
Begin
  Result := False;

  If Not Writeable Then
    Exit;

  For i := Low(ATags) To High(ATags) Do
  Begin
    sTag := ATags[i];
    sValue := AValues[i];

    oTag := TagByName(sTag);
    If Assigned(oTag) Then
    Begin
      oTag.Value := sValue;
      Result := True;
    End;
  End;

  If Result Then
  Begin
    FFilename := AFilename;

    Result := Commit;
  End;
End;

Function TMetaFileHandler.Commit: Boolean;
Begin
  Result := False;
End;

Function TMetaFileHandler.TagByName(AName: String): TMetaTag;
Var
  oTemp: TMetaTag;
Begin
  Result := nil;

  If FTags.TryGetData(AName, oTemp) Then
    Result := oTemp;
End;

Function TMetaFileHandler.Name: String;
Begin
  Result := BLANK;
End;

Function TMetaFileHandler.GetTag(AName: String): Variant;
Var
  oTag: TMetaTag;
Begin
  oTag := TagByName(AName);
  If Assigned(oTag) Then
    Result := oTag.Value
  Else
    Result := Null;
End;

Procedure TMetaFileHandler.SetTag(AName: String; AValue: Variant);
Var
  oTag: TMetaTag;
Begin
  oTag := TagByName(AName);
  If Assigned(oTag) Then
  Begin
    oTag.Value := AValue;

    If AValue <> Null Then
    Begin
      FHasTags := True;

      If Not oTag.Hidden Then
      Begin
        EnterCriticalsection(lVisibleFieldLock);
        Try
          TagManager.VisibleFields.Add(AName);
        Finally
          LeaveCriticalsection(lVisibleFieldLock);
        End;
      End;
    End;
  End;
End;

Procedure TMetaFileHandler.ClearTags;
Var
  i: Integer;
Begin
  FHasTags := False;

  For i := 0 To FTags.Count - 1 Do
    FTags.Data[i].Value := Null;
End;

Procedure TMetaFileHandler.AddTag(AName: String; AFieldType: TFieldType;
  ASize: Integer; AReadOnly: Boolean; AHidden: Boolean);
Var
  oMetaTag: TMetaTag;
Begin
  oMetaTag := TMetaTag.Create(AName, AFieldType, ASize, AReadOnly, AHidden);
  FTags.Add(AName, oMetaTag);
End;

{ TTagManager }

Function TTagManager.GetDataset: TBufDataset;
Begin
  Result := FFiles.Table;
End;

Constructor TTagManager.Create;
Begin
  // The TMetaFileHandler Factory
  FMetaFileHandlerClassByExt := TFPHashList.Create;

  // Unique list of MetaFileHandlers
  FMetaFileHandlers := TMetaFileHandlerList.Create(True);

  FFiles := TMemTable.Create;

  FFileSystemTags := TTagFileSystem.Create;

  FVisibleFields := TStringList.Create;
  FVisibleFields.Sorted := True;
  FVisibleFields.Duplicates := dupIgnore;

  InitCriticalSection(FDBLock);
End;

Destructor TTagManager.Destroy;
Begin
  DoneCriticalSection(FDBLock);

  FreeAndNil(FVisibleFields);
  FreeAndNil(FFileSystemTags);
  FreeAndNil(FFiles);
  FreeAndNil(FMetaFileHandlers);  // OwnsObjects := True
  FreeAndNil(FMetaFileHandlerClassByExt);

  Inherited Destroy;
End;

Procedure TTagManager.BeginUpdate;
Begin
  FVisibleFields.Clear;
  FFiles.Table.DisableControls;
End;

Procedure TTagManager.EndUpdate;
Begin

  // Add these at the end to stop some pointless searches during the processing
  FVisibleFields.Add('Count');
  FVisibleFields.Add('Filename');
  FVisibleFields.Add('FileExt');
  FVisibleFields.Add('Tag');
  FVisibleFields.Add('Temp');
  FVisibleFields.Add('Date');
  FVisibleFields.Add('Size');
  FVisibleFields.Add('Path');

  FFiles.Table.EnableControls;
End;

Procedure TTagManager.Register(AMetaFileHandler: TMetaFileHandlerClass; AFileExt: Array Of String);
Var
  oMetaFileHandler: TMetaFileHandler;
  sExt, sFilter: String;
Begin
  oMetaFileHandler := AMetaFileHandler.Create;
  FMetaFileHandlers.Add(oMetaFileHandler);

  sFilter := '';
  For sExt In AFileExt Do
  Begin
    If sFilter = '' Then
      sFilter := Format('*%s', [sExt])
    Else
      sFilter := Format('%s;*%s', [sFilter, sExt]);

    FMetaFileHandlerClassByExt.Add(Lowercase(sExt), Pointer(AMetaFileHandler));
  End;

  oMetaFileHandler.Filter := sFilter;
End;

Procedure TTagManager.DefineTags;
Var
  i: Integer;
  oField: TField;
  oTag: TMetaTag;
  oMetaFileHandler: TMetaFileHandler;
Begin
  If FFiles.Active Then
    FFiles.Close;

  For i := 0 To FFileSystemTags.Tags.Count - 1 Do
  Begin
    oTag := FFileSystemTags.Tags.Data[i];
    FFiles.AddField(oTag.Name, oTag.FieldType, oTag.Size);
  End;

  For oMetaFileHandler In FMetaFileHandlers Do
    For i := 0 To oMetaFileHandler.Tags.Count - 1 Do
    Begin
      oTag := oMetaFileHandler.Tags.Data[i];
      Try
        If Not FFiles.HasField(oTag.Name) Then
          FFiles.AddField(oTag.Name, oTag.FieldType, oTag.Size);
      Except
      End;
    End;

  FFiles.Open;

  For oField In FFiles.Table.Fields Do
  Begin
    oField.OnSetText := @DoSetText;

    If oField.DataType = ftMemo Then
      oField.OnGetText := @DoGetMemo;
  End;
End;

Function TTagManager.TagDefByName(AName: String): TMetaTag;
Var
  oTemp: TMetaTag;
  oMetaFileHandler: TMetaFileHandler;
Begin
  Result := nil;

  If FFileSystemTags.Tags.TryGetData(AName, oTemp) Then
    Result := oTemp
  Else
    For oMetaFileHandler In FMetaFileHandlers Do
      If oMetaFileHandler.Tags.TryGetData(AName, oTemp) Then
      Begin
        Result := oTemp;
        Break;
      End;
End;

Function TTagManager.GetMetaFileHandler(AIndex: Integer): TMetaFileHandler;
Begin
  Result := FMetaFileHandlers[AIndex];
End;

Function TTagManager.GetTag(AName: String): Variant;
Var
  oMetaTag: TMetaTag;
Begin
  oMetaTag := TagDefByName(AName);
  If Assigned(oMetaTag) Then
    Result := oMetaTag.Value
  Else
    Result := Null;
End;

Procedure TTagManager.SetTag(AName: String; AValue: Variant);
Var
  oMetaTag: TMetaTag;
Begin
  oMetaTag := TagDefByName(AName);
  If Assigned(oMetaTag) Then
    oMetaTag.Value := AValue;
End;

Procedure TTagManager.DoGetMemo(Sender: TField; Var aText: String; DisplayText: Boolean);
Begin
  aText := Sender.AsString;
End;

Procedure TTagManager.DoSetText(Sender: TField; Const aText: String);
Var
  sField, sOriginal: String;
Begin
  If Assigned(Sender) And FFiles.Table.Active Then
  Begin
    sField := Sender.FieldName;
    sOriginal := FFiles.Table['Original'];

    If (sField <> 'Count') And (sField <> 'Temp') Then
    Begin
      // TODO: EditMode=Bulk v Immediate code to go here
      // TODO: Need to confirm if this Field is valid to be edited for this FileExt
      // TODO: Design decision - do we want to block edit if no tag
      //       Or automatically try to add a Tag?

      // Current thinking - try to add tag
      Sender.Value := aText;

      If Not Update(sOriginal, sField, aText) Then
      Begin
        // Mark the change for future Bulk Update
        FFiles.Table.FieldByName('Colour_ID').AsString := 'Orange';
      End;
    End;
  End;
End;

Procedure TTagManager.ParseFile(ACommon: TMetaFileHandler; ATags: TMetaFileHandlerList);
Var
  oMetaFileHandler: TMetaFileHandler;
  sExt: String;
  sFilename, sTemp: String;
  oClass: TMetaFileHandlerClass;
  i: Integer;
Begin
  // This routine needs to be threadsafe - use only local or passed variables

  sExt := ACommon.Tag['FileExt'];
  sFilename := ACommon.Tag['Original'];

  // TODO, I want to implement refreh: Do I need to clear all Tags first?
  ACommon.Tag['Temp'] := '';
  ACommon.Tag['Tag'] := '';

  // Iterate over all TMetaFileHandler's, apply each one that applies
  For i := 0 To FMetaFileHandlerClassByExt.Count - 1 Do
  Begin
    sTemp := FMetaFileHandlerClassByExt.NameOfIndex(i);
    If CompareText(sTemp, sExt)=0 Then
    Begin
      oClass := TMetaFileHandlerClass(FMetaFileHandlerClassByExt.Items[i]);
      oMetaFileHandler := oClass.Create;
      ATags.Add(oMetaFileHandler);

      oMetaFileHandler.Common := ACommon;
      oMetaFileHandler.ParseFile(sFilename);

      If oMetaFileHandler.HasTags Then
        If ACommon.Tag['Tag'] = '' Then
          ACommon.Tag['Tag'] := oMetaFileHandler.Name
        Else
          ACommon.Tag['Tag'] := ACommon.Tag['Tag'] + ', ' + oMetaFileHandler.Name;
    End;
  End;
End;

Procedure TTagManager.AppendFile(ATags: TMetaFileHandlerList);
Var
  oMetaFileHandler: TMetaFileHandler;
  oTag: TMetaTag;
  i: Integer;
Begin
  EnterCriticalsection(FDBLock);
  Try
    FFiles.Table.DisableControls;
    Try
      If Not (FFiles.Table.State In [dsEdit, dsInsert]) Then
      Begin
        FFiles.Table.Append;
        Try
          For oMetaFileHandler In ATags Do
            If oMetaFileHandler.HasTags Then
              For i := 0 To oMetaFileHandler.Tags.Count - 1 Do
              Begin
                oTag := oMetaFileHandler.Tags.Data[i];
                If oTag.Value <> Null Then
                  FFiles.Table[oTag.Name] := oTag.Value;
              End;
        Finally
          FFiles.Table.Post;
        End;
      End
      Else
        Raise Exception.Create('TTagManager.AppendFile: Unable to append new record');
    Finally
      FFiles.Table.EnableControls;
    End;
  Finally
    LeaveCriticalsection(FDBLock);
  End;
End;

Procedure TTagManager.ClearFiles;
Begin
  FFiles.ClearAllRecords;
  FVisibleFields.Clear;
End;

Function TTagManager.Update(AFilename, ATag, AValue: String): Boolean;
Begin
  Result := Update(AFilename, [ATag], [AValue]);
End;

Function TTagManager.Update(AFilename: String; ATags, AValues: Array Of String): Boolean;
Var
  sExt, sTemp: String;
  oMetaFileHandler: TMetaFileHandler;
  iHandler: Integer;
  oClass: TMetaFileHandlerClass;
Begin
  // TODO: Complete the writing of tags (Needs testing to establish current limitations)
  Result := False;

  sExt := Lowercase(FFiles.Table['FileExt']);

  // Iterate over all TMetaFileHandler's, apply each one that applies
  For iHandler := 0 To FMetaFileHandlerClassByExt.Count - 1 Do
  Begin
    sTemp := FMetaFileHandlerClassByExt.NameOfIndex(iHandler);
    If sTemp = sExt Then
    Begin
      oClass := TMetaFileHandlerClass(FMetaFileHandlerClassByExt.Items[iHandler]);
      oMetaFileHandler := oClass.Create;
      Try
        If Assigned(oMetaFileHandler) And (oMetaFileHandler.Writeable) Then
        Begin
          Result := Result Or oMetaFileHandler.Update(AFilename, ATags, AValues);
        End;
      Finally
        oMetaFileHandler.Free;
      End;
    End;
  End;
End;

Initialization
  lTagManager := nil;
  InitCriticalSection(lVisibleFieldLock);

Finalization
  FreeAndNil(lTagManager);
  DoneCriticalsection(lVisibleFieldLock);
End.
