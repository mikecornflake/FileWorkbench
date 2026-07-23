Unit TagMultimedia;

{$mode objfpc}{$H+}

Interface

Uses
  Classes, SysUtils, Tags, DB;

Type
  TTagMedia = Class(TMetaFileHandler)
  Public
    Constructor Create; Override;
    Destructor Destroy; Override;

    Function Name: String; Override;

    Function ParseFile(sFilename: String): Boolean; Override;
  End;

Implementation

Uses
  ffmpegSupport, FileSupport;

  { TTagMedia }

Constructor TTagMedia.Create;
Begin
  Inherited Create;

  AddTag('MM_File_Format', ftString, 100, True);
  AddTag('MM_Width', ftInteger, -1, True);
  AddTag('MM_Height', ftInteger, -1, True);
  AddTag('MM_Duration', ftFloat, -1, True);
  AddTag('MM_Streams', ftInteger, -1, True);
  AddTag('MM_VID_Codec', ftString, 100, True);
  AddTag('MM_VID_Stream', ftInteger, -1, True);
  AddTag('MM_VID_Profile', ftString, 100, True);
  AddTag('MM_VID_pixfmt', ftString, 100, True);
  AddTag('MM_AUD_Codec', ftString, 100, True);
  AddTag('MM_AUD_Stream', ftInteger, -1, True);
  AddTag('MM_SUB_Codec', ftString, 100, True);
  AddTag('MM_SUB_Stream', ftInteger, -1, True);
  AddTag('MM', ftString, 4096, True, True);
End;

Destructor TTagMedia.Destroy;
Begin
  Inherited Destroy;
End;

Function TTagMedia.Name: String;
Begin
  Result := 'ffprobe';
End;

Function TTagMedia.ParseFile(sFilename: String): Boolean;
Var
  oMediaInfo: TMediaInfo;
  sExt: String;
Begin
  Result := Inherited ParseFile(sFilename);

  If FileExists(sFilename) Then
  Begin
    If (FFmpeg.Available) Then
    Begin
      sExt := ExtractFileExt(sFilename);

      oMediaInfo := FFmpeg.MediaInfo(sFilename);

      If oMediaInfo.Filename = sFilename Then
      Begin
        Tag['MM'] := oMediaInfo.RAW;

        Tag['MM_File_Format'] := oMediaInfo.Format;
        Tag['MM_Streams'] := oMediaInfo.StreamCount;

        If oMediaInfo.Width <> 0 Then
          Tag['MM_Width'] := oMediaInfo.Width;

        If oMediaInfo.Height <> 0 Then
          Tag['MM_Height'] := oMediaInfo.Height;

        If Not IsImage(sExt) Then
        Begin
          Tag['MM_Duration'] := oMediaInfo.Duration;

          If oMediaInfo.V_Stream <> -1 Then
          Begin
            Tag['MM_VID_Codec'] := oMediaInfo.V_Codec;
            Tag['MM_VID_Stream'] := oMediaInfo.V_Stream;

            Tag['MM_VID_Profile'] := oMediaInfo.V_Profile;
            Tag['MM_VID_pixfmt'] := oMediaInfo.V_pixfmt;

          End;
        End;

        If oMediaInfo.A_Stream <> -1 Then
        Begin
          Tag['MM_AUD_Codec'] := oMediaInfo.A_Codec;
          Tag['MM_AUD_Stream'] := oMediaInfo.A_Stream;
        End;

        If oMediaInfo.S_Stream <> -1 Then
        Begin
          Tag['MM_SUB_Codec'] := oMediaInfo.S_Codec;
          Tag['MM_SUB_Stream'] := oMediaInfo.S_Stream;
        End;

        FHasTags := True;
      End;
    End;
  End;
End;

Initialization
  TagManager.Register(TTagMedia, FileExtVideo);
  TagManager.Register(TTagMedia, FileExtImage);
  TagManager.Register(TTagMedia, FileExtAudio);

End.
