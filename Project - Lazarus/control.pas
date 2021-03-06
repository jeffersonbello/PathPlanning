unit control;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  lNet, IniPropStorage, ExtCtrls, lNetComponents, StdCtrls,configSimTwo,
  robotmainfunctions,Grids, AStar, windows, RStar;

type
  TJointState = record
    Theta, W: double;
  end;

  TRGB32= record
    b,g,r,a: byte;
  end;
  pTRGB32 = ^TRGB32;

  { TFcontrol }

  TFcontrol = class(TForm)
    btn_cliqueAqui: TButton;
    Button5: TButton;
    CBM: TCheckBox;
    CBMPC: TCheckBox;
    Edit36: TEdit;
    GroupBox6: TGroupBox;
    GroupBox7: TGroupBox;
    GTXYT: TCheckBox;
    EB_Vref: TEdit;
    Edit10: TEdit;
    Edit11: TEdit;
    Edit12: TEdit;
    Edit13: TEdit;
    Edit14: TEdit;
    Edit15: TEdit;
    Edit16: TEdit;
    Edit17: TEdit;
    Edit18: TEdit;
    Edit19: TEdit;
    Edit20: TEdit;
    Edit21: TEdit;
    Edit22: TEdit;
    Edit23: TEdit;
    Edit24: TEdit;
    Edit25: TEdit;
    Edit26: TEdit;
    Edit27: TEdit;
    Edit28: TEdit;
    Edit29: TEdit;
    Edit30: TEdit;
    Edit31: TEdit;
    Edit32: TEdit;
    Edit33: TEdit;
    Edit34: TEdit;
    Edit35: TEdit;
    Edit39: TEdit;
    Edit4: TEdit;
    Edit5: TEdit;
    Edit6: TEdit;
    Edit7: TEdit;
    Edit8: TEdit;
    Edit9: TEdit;
    GroupBox5: TGroupBox;
    IniPropStorage1: TIniPropStorage;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label14: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Label17: TLabel;
    Label18: TLabel;
    Label19: TLabel;
    Label20: TLabel;
    Label21: TLabel;
    Label22: TLabel;
    Label23: TLabel;
    Label24: TLabel;
    Label25: TLabel;
    Label26: TLabel;
    Label27: TLabel;
    Label28: TLabel;
    Label29: TLabel;
    Label30: TLabel;
    Label31: TLabel;
    Label32: TLabel;
    label_memoriaFisicaTotal: TLabel;
    label_memoriaFisicaLivre: TLabel;
    label_memoriaFisicaOcupada: TLabel;
    label_percentMemoriaLivre: TLabel;
    label_percentMemoriaOcup: TLabel;
    label_NIteracao: TLabel;
    label_status: TLabel;
    label_tempoTotal: TLabel;
    label_mediaGeral: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    RadioButton4: TRadioButton;
    Start: TButton;
    CB_SimTwo: TCheckBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    EB_PositionY: TEdit;
    EB_Theta: TEdit;
    EB_PositionX: TEdit;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    RadioButton2: TRadioButton;
    RadioButton3: TRadioButton;
    RadioButton1: TRadioButton;
    SGObs: TStringGrid;
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    Timer1: TTimer;
    Timer2: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure CB_SimTwoChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure GroupBox6Click(Sender: TObject);
    procedure GroupBox7Click(Sender: TObject);
    procedure GTXYTChange(Sender: TObject);
    procedure label_NIteracaoClick(Sender: TObject);
    procedure label_statusClick(Sender: TObject);
    procedure RadioButton4Change(Sender: TObject);
    procedure StartClick(Sender: TObject);
    //procedure TimerTimer(Sender: TObject);
    procedure RadioButton3Change(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);

  private

    { private declarations }
  public
    stringlist: TStringList;
    formatseting: TFormatSettings;
  end;


var
   SpeedMax: double;
   Fcontrol: TFcontrol;

implementation

{ TFcontrol }

procedure TFcontrol.RadioButton3Change(Sender: TObject);
begin
  if RadioButton3.Checked=False then begin
    Button1.Enabled:=False;
    Button2.Enabled:=False;
    Button3.Enabled:=False;
    Button4.Enabled:=False;
  end else begin
    Button1.Enabled:=True;
    Button2.Enabled:=True;
    Button3.Enabled:=True;
    Button4.Enabled:=True;
  end;
  if ((RadioButton2.Checked=False)and(RadioButton4.Checked=False)) then begin
    CBM.Enabled:=False;
    CBMPC.Enabled:=False;
    GTXYT.Enabled:=False;
  end else if (RadioButton2.Checked=True) then begin
    CBM.Enabled:=True;
    CBMPC.Enabled:=True;
    GTXYT.Enabled:=True;
    CBM.Checked:=False;
    CBMPC.Checked:=False;
    GTXYT.Checked:=False;
    RadioButton4.Checked:=False;
    RadioButton1.Checked:=False;
    RadioButton3.Checked:=False;
  end else if (RadioButton4.Checked=True) then begin
    CBM.Enabled:=True;
    CBMPC.Enabled:=True;
    GTXYT.Enabled:=True;
    CBM.Checked:=False;
    CBMPC.Checked:=False;
    GTXYT.Checked:=False;
    RadioButton2.Checked:=False;
    RadioButton1.Checked:=False;
    RadioButton3.Checked:=False;
  end;
end;

procedure TFcontrol.Timer1Timer(Sender: TObject);
var v_MS: TMemoryStatus;                                       // Quando clicado o botão de análise, será iniciado o time para calcular as informações pertinentes da mémoria. O primeiro passo para isso é criar uma variável para que possa manipular e gravar essas informações

begin

GlobalMemoryStatus(v_MS);                                        // O restantes das labels é apenas de atribuição dos valores obtidos no calculo de mémoria livre, ocupada e total. Eu implementei 11 verificações, mas no final só considerei 4 importantes. Caso queira liberar mais informações,só descomentar.

label_memoriaFisicaTotal.Caption:='Physical Memory (Total): ' + FloatToStr((v_MS.dwTotalPhys/1024)/1024) + ' MB';
label_memoriaFisicaLivre.Caption:='Physical Memory (Free): ' + FloatToStr((v_MS.dwAvailPhys/1024)/1024) + ' MB';
label_memoriaFisicaOcupada.Caption:='Physical Memory (Occupied): ' + FloatToStr(((v_MS.dwTotalPhys - v_MS.dwAvailPhys)/1024)/1024) + ' MB';
label_percentMemoriaLivre.Caption:='Percentage of Memory (Free): ' + FloatToStr(100 - v_MS.dwMemoryLoad) + ' %';
label_percentMemoriaOcup.Caption:='Percentage of Memory (Occupied): ' + FloatToStr(v_MS.dwMemoryLoad) + ' %';


//Label4.Caption:='MBs de páginação de Arquivo: ' + FloatToStr((v_MS.dwTotalPageFile/1024)/1024) + ' MB';
//Label5.Caption:='MBs de páginação de Arquivo (Ocupados): ' + FloatToStr(((v_MS.dwTotalPageFile - v_MS.dwAvailPageFile)/ 1024)/1024)+ ' MB';
//Label6.Caption:='MBs de páginação de Arquivo (Livres): ' + FloatToStr((v_MS.dwAvailPageFile/ 1024)/1024)+ ' MB';
//Label7.Caption:='MBs de espaço de endereços (TOTAL): ' + FloatToStr((v_MS.dwTotalVirtual + v_MS.dwAvailVirtual/1024)/1024)+ ' MB';
//Label8.Caption:='MBs de espaço de endereços (Ocupados): ' + FloatToStr((v_MS.dwTotalVirtual/1024)/1024)+ ' MB';
//Label9.Caption:='MBs de espaço de endereços (Livres): ' + FloatToStr((v_MS.dwAvailVirtual/1024)/1024)+ ' MB';
end;

procedure TFcontrol.Timer2Timer(Sender: TObject);
begin

  label_tempoTotal.Caption:='Total Time: ' + FormatDateTime('S:ZZZ', totalTime) +' (ms)';
  label_mediaGeral.Caption:='General Average: ' + FormatDateTime('S:ZZZ', totalTime/interactionControl) +' (ms)';
  label_NIteracao.Caption:='Number of Iterations: '+ intToStr(interactionControl);

end;

procedure TFcontrol.FormCreate(Sender: TObject);
var pnt: TGridCoord;
begin
  RadioButton3.Checked:=False;
  RadioButton1.Checked:=True;
  RadioButton2.Checked:=False;
  RadioButton4.Checked:=False;
  Inicialize_Variables;
  stringlist := TStringList.Create;
  //Load Configuration
  loadConfig();
  //Reset Model
  resetModel();
end;

procedure TFcontrol.FormDestroy(Sender: TObject);
begin
  stringlist.Free;
end;

procedure TFcontrol.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var i: integer;
begin
  Fconfig.UDP.Disconnect;
end;

procedure TFcontrol.Button1Click(Sender: TObject);
begin
    KeyState.up:=true;
    KeyState.down:=false;
    KeyState.left:=false;
    KeyState.right:=false;
end;

procedure TFcontrol.Button2Click(Sender: TObject);
begin
    KeyState.up:=false;
    KeyState.down:=true;
    KeyState.left:=false;
    KeyState.right:=false;
end;

procedure TFcontrol.Button3Click(Sender: TObject);
begin
    KeyState.up:=false;
    KeyState.down:=false;
    KeyState.left:=false;
    KeyState.right:=true;
end;

procedure TFcontrol.Button4Click(Sender: TObject);
begin
    KeyState.up:=false;
    KeyState.down:=false;
    KeyState.left:=true;
    KeyState.right:=false;
end;

procedure TFcontrol.Button5Click(Sender: TObject);
begin
  goState:=0;
  irobot := 0;
  THETA:=0;
  t := 0;
  y:=0.8;
  x:=0;
end;

procedure TFcontrol.CB_SimTwoChange(Sender: TObject);
begin
  if CB_SimTwo.Checked then begin
    Fconfig.UDP.Listen(StrToInt(Fconfig.Edit3.Text));
  end else begin
    Fconfig.UDP.Disconnect;

  end;
end;

procedure TFcontrol.Button6Click(Sender: TObject);
begin



end;




procedure TFcontrol.FormShow(Sender: TObject);
var i: integer;
    FSettings: TFormatSettings;
begin
  FSettings.DecimalSeparator:='.';
  SpeedMax:=strtofloat(EB_Vref.Text, FSettings);
  formatseting:=DefaultFormatSettings;
  formatseting.DecimalSeparator:=',';
  if CB_SimTwo.Checked then begin
    Fconfig.UDP.Listen(StrToInt(Fconfig.Edit3.Text));
  end;
  setInitialState;
end;

procedure TFcontrol.GroupBox6Click(Sender: TObject);
begin

end;

procedure TFcontrol.GroupBox7Click(Sender: TObject);
begin

end;

procedure TFcontrol.GTXYTChange(Sender: TObject);
begin
  // memoria
  Timer1.Enabled:=True;                                                             // Por padrão, a analise por segundo está parada, apenas depois que apertar o botão ANALISAR que a mesma será ativa
  Timer2.Enabled:=True;
  // Tempo
  //label_status.Caption:='Modificou o Status com Sucesso';
  //beginAnalysis;                                                                    // Chamada da função que capturará as informações de tempo gasto na execução de 6 iterações, com delay de 1/2 segundo e no final apresentará a média
  //label_tempoTotal.Caption:='Modificou o Tempo total com Sucesso';
  //label_mediaGeral.Caption:='Modificou a media Geral com Sucesso';
  //label_NIteracao.Caption:='Number of Iterations: '+ intToStr(interactionControl);
end;

procedure TFcontrol.label_NIteracaoClick(Sender: TObject);
begin

end;

procedure TFcontrol.label_statusClick(Sender: TObject);
begin

end;


procedure TFcontrol.RadioButton4Change(Sender: TObject);
begin

end;

procedure TFcontrol.StartClick(Sender: TObject);
begin
  Fconfig.Show;
end;


initialization

  {$I control.lrs}

end.

