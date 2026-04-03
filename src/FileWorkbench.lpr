Program FileWorkbench;

{$mode objfpc}{$H+}
{$DEFINE UseCThreads}

Uses
  {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  lazcontrols,
  SysUtils, FormFileWorkbench,
  Tags, TagVideoNFO, TagEXIF, TagMultimedia;

  {$R *.res}

Begin
  SetHeapTraceOutput(ChangeFileExt(Application.Exename, '.trc'));
  Application.Scaled:=True;
  Application.Title:='File Workbench';
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TfrmFileWorkbench, frmFileWorkbench);
  Application.Run;
End.
