Unit TagFileSystem;

{$mode objfpc}{$H+}

Interface

Uses
  Classes, SysUtils, Tags, DB;

Type
  // This is a list of the File System metadata tags found in all files

  // These are treated differently to the other metadata readers as this data
  // is ALWAYS loaded, whereas the other readers can be turned on or off

  // As such, this is not "registered" with the TagManager, the TagManager
  // handles TTagFileSystem independently

  { TTagFileSystem }

  TTagFileSystem = Class(TMetaFileHandler)
  Protected
    Procedure SetTag(AName: String; AValue: Variant); Override;
  Public
    Constructor Create; Override;
    Destructor Destroy; Override;

    Function Name: String; Override;

    Function ParseFile(sFilename: String): Boolean; Override;
  End;

Implementation

{ TTagFileSystem }

Procedure TTagFileSystem.SetTag(AName: String; AValue: Variant);
Var
  oTag: TMetaTag;
Begin
  // Don't make these columns visible (which is what happens in the base class)
  oTag := TagByName(AName);
  If Assigned(oTag) Then
  Begin
    oTag.Value := AValue;
    FHasTags := True;
  End;
End;

Constructor TTagFileSystem.Create;
Begin
  Inherited Create;

  // Also contains FileRenamer internal fields. Logically should be separate to FileSystem
  // But easier to bundle them here

  AddTag('Count', ftInteger);
  AddTag('Filename', ftString, 260);
  AddTag('FileExt', ftString, 52, True);

  AddTag('Tag', ftString, 52, True);
  AddTag('Colour_ID', ftString, 52, True);
  AddTag('Temp', ftString, 4096);

  AddTag('Date', ftDateTime, -1, True);
  AddTag('Size', ftLargeint, -1, True);
  // TODO: Include other attributes

  AddTag('Path', ftString, 520, True);
  AddTag('Parent', ftString, 260, True);
  AddTag('Parent2', ftString, 260, True);
  AddTag('Original', ftString, 520, True);
End;

Destructor TTagFileSystem.Destroy;
Begin
  Inherited Destroy;
End;

Function TTagFileSystem.Name: String;
Begin
  Result := 'File System';
End;

Function TTagFileSystem.ParseFile(sFilename: String): Boolean;
Begin
  Result := Inherited ParseFile(sFilename);
  FHasTags := True;
End;

End.
