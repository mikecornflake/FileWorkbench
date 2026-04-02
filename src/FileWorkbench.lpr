Program FileWorkbench;

{$mode objfpc}{$H+}
{$DEFINE UseCThreads}

Uses
  {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  lazcontrols,
  SysUtils,
  Tags,
  TagMultimedia,
  TagEXIF,
  TagVideoNFO, FormFileWorkbench;

  {$R *.res}

Begin
  SetHeapTraceOutput(ChangeFileExt(Application.Exename, '.trc'));
  Application.Scaled:=True;
  Application.Title:='File Workbench';
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.Run;
End.
