{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit MiniLib;

{$warn 5023 off : no warning about unused units}
interface

uses
  HTMLProcessor, PHPProcessor, PHPUtils, GUIMsgBox, mnFonts, ColorUtils, 
  SynHighlighterApache, SynHighlighterXHTML, SynHighlighterFirebird, 
  SynHighlighterSARD, SynHighlighterD, SynHighlighterConfig, 
  SynHighlighterStdSQL, mnSynHighlighterCpp, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('MiniLib', @Register);
end.
