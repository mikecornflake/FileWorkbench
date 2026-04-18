Unit TagEXIF;

{$mode objfpc}{$H+}

Interface

Uses
  Classes, SysUtils, Tags, DB, fpeMetadata, fpeTags, fpeGlobal;

Type

  { TTagEXIF }

  TTagEXIF = Class(TMetaFileHandler)
  Protected
    FFields: TStringList;
    FImgInfo: TImgInfo;
  Public
    Constructor Create; Override;
    Destructor Destroy; Override;

    Function Name: String; Override;
    Function Writeable: Boolean; Override;

    Function ParseFile(sFilename: String): Boolean; Override;
  End;

Implementation

{ TTagEXIF }

Constructor TTagEXIF.Create;
Var
  sMetaTag: String;
  i: Integer;
Begin
  Inherited Create;

  FImgInfo := TImgInfo.Create;

  FFields := TStringList.Create;
  FFields.Add('EXIF_Author=XPAuthor');
  FFields.Add('EXIF_Comments=XPComment');
  FFields.Add('EXIF_DateTimeOriginal=DateTimeOriginal');
  FFields.Add('EXIF_Keywords=XPKeywords');
  FFields.Add('EXIF_Make=Make');
  FFields.Add('EXIF_Model=Model');
  FFields.Add('EXIF_Software=Software');
  FFields.Add('EXIF_Subject=XPSubject');
  FFields.Add('EXIF_Title=XPTitle');
  FFields.Add('EXIF_Width=EXIFImageWidth');
  FFields.Add('EXIF_Height=EXIFImageHeight');

  // Add the special cases
  AddTag('EXIF_DateTimeOriginal', ftString, 25, True);
  AddTag('EXIF_Width', ftInteger, -1, True);
  AddTag('EXIF_Height', ftInteger, -1, True);

  // Add the simple strings
  For i := 0 To FFields.Count - 1 Do
  Begin
    sMetaTag := FFields.Names[i];

    If FTags.IndexOf(sMetaTag) = -1 Then
      AddTag(sMetaTag, ftString, 100);
  End;

  // IPTC (Early adoption, may need to extend FFields usage in ParseFile)
  AddTag('IPTC_Caption', ftString, 100);

  // Finally the summary fields
  AddTag('EXIF', ftString, 4096, True, True);
  AddTag('EXIF_IPTC', ftString, 4096, True, True);
End;

Destructor TTagEXIF.Destroy;
Begin
  FreeAndNil(FImgInfo);
  FreeAndNil(FFields);

  Inherited Destroy;
End;

Function TTagEXIF.Name: String;

  Function AddTag(sInput: String; sAdd: String): String;
  Begin
    If sInput = '' Then
      Result := sAdd
    Else
      Result := sInput + ', ' + sAdd;
  End;

Begin
  Result := '';

  If FImgInfo.HasExif Then
    Result := AddTag(Result, 'EXIF');

  If FImgInfo.HasIptc Then
    Result := AddTag(Result, 'IPTC');
End;

Function TTagEXIF.Writeable: Boolean;
Begin
  Result := True;
End;

Function TTagEXIF.ParseFile(sFilename: String): Boolean;

  Procedure SetMetaFromExif(AMetaTag, AExifTag: String);
  Var
    oTag: fpeTags.TTag;
  Begin
    oTag := FImgInfo.ExifData.TagByName[AExifTag];
    If assigned(oTag) Then
      Tag[AMetaTag] := oTag.AsString;
  End;

Var
  sMetaTag, sExifTag: String;
  i: Integer;
  oTemp: TStringList;
Begin
  Result := Inherited ParseFile(sFilename);

  If Not FileExists(sFilename) Then
    Exit;

  FImgInfo.LoadFromFile(sFilename);

  If FImgInfo.HasExif Then
  Begin
    For i := 0 To FFields.Count - 1 Do
    Begin
      sMetaTag := FFields.Names[i];
      sExifTag := FFields.ValueFromIndex[i];

      SetMetaFromExif(sMetaTag, sExifTag);
    End;

    oTemp := TStringList.Create;
    Try
      FImgInfo.ExifData.ExportOptions :=
        [eoShowTagName, eoDecodeValue, eoTruncateBinary, eoBinaryAsASCII];
      FImgInfo.ExifData.ExportToStrings(oTemp, '=');

      Tag['EXIF'] := oTemp.Text;
    Finally
      oTemp.Free;
    End;

    FHasTags := True;
  End;

  If FImgInfo.HasIptc Then
  Begin
    oTemp := TStringList.Create;
    Try
      FImgInfo.IptcData.ExportToStrings(oTemp, [eoShowTagName, eoDecodeValue,
        eoTruncateBinary, eoBinaryAsASCII], '=');

      Tag['EXIF_IPTC'] := oTemp.Text;

      // Easier than querying FImgInfo.IptcData...
      Tag['IPTC_Caption'] := oTemp.Values['Image caption'];
    Finally
      oTemp.Free;
    End;
  End;
End;

Initialization
  TagManager.Register(TTagEXIF, ['.jpg', '.jpeg', '.tiff']);

End.
