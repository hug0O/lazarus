{
 *****************************************************************************
 *                                                                           *
 *  See the file COPYING.modifiedLGPL, included in this distribution,        *
 *  for details about the copyright.                                         *
 *                                                                           *
 *  This program is distributed in the hope that it will be useful,          *
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
 *                                                                           *
 *****************************************************************************

  Author: Mattias Gaertner

  Abstract:
    Interface to the IDE messages (below the source editor).
}
unit MsgIntf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LCLProc, TextTools, IDECommands;
  
type

  { TIDEMessageLine

    The IDE (TOutputFilter) parses each message line.
    If it sees FPC output, it fills the Parts property and set various
    Name=Value pairs.

      Name    | Value
      --------|-----------------------------------------------------------------
      Stage    Indicates what part of the build process the message
               belongs to. Common values are 'FPC', 'Linker' or 'make'
      Type     For FPC: 'Hint', 'Note', 'Warning', 'Error', 'Fatal', 'Panic',
               'Compiling', 'Assembling'
               For make: 'entering directory', 'leaving directory'
               For Linker:
      Line     An integer for the linenumber as given by FPC in brackets.
      Column   An integer for the column as given by FPC in brackets.
      Message  The message text without other parsed items.


    Example:
      Message written by FPC:
        unit1.pas(21,3) Warning: unit buttons not used

      Creates the following lines in Parts:
        Stage=FPC
        Type=Warning
        Line=21
        Column=3
        Message=unit buttons not used
        
    You can access them via:
      if ALine.Parts.Values['Stage']='FPC' then ...
  }

  TIDEMessageLine = class
  private
    FDirectory: string;
    FMsg: string;
    FOriginalIndex: integer;
    FParts: TStrings;
    FPosition: integer;
    FVisiblePosition: integer;
    procedure SetDirectory(const AValue: string);
    procedure SetMsg(const AValue: string);
  public
    constructor Create;
    destructor Destroy; override;
    property Msg: string read FMsg write SetMsg;
    property Directory: string read FDirectory write SetDirectory;
    property Position: integer read FPosition write FPosition; // position in all available messages
    property VisiblePosition: integer read FVisiblePosition write FVisiblePosition;// filtered position
    property OriginalIndex: integer read FOriginalIndex write FOriginalIndex;// unsorted, unfiltered position
    property Parts: TStrings read FParts write FParts;
  end;

  TOnFilterLine = procedure(MsgLine: TIDEMessageLine; var Show: boolean) of object;
  
  { TIDEMessageLineList }

  TIDEMessageLineList = class
  private
    FItems: TFPList;
    function GetCount: integer;
    function GetItems(Index: integer): TIDEMessageLine;
    function GetParts(Index: integer): TStrings;
    procedure SetParts(Index: integer; const AValue: TStrings);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Add(const Msg: string): integer;
    function Add(Item: TIDEMessageLine): integer;
    procedure Delete(Index: Integer);
  public
    property Count: integer read GetCount;
    property Items[Index: integer]: TIDEMessageLine read GetItems; default;
    property Parts[Index: integer]: TStrings read GetParts write SetParts;
  end;

  { TIDEMsgQuickFixItem }
  
  TIMQFExecuteMethod = procedure(Sender: TObject; Msg: TIDEMessageLine) of object;
  TIMQFExecuteProc = procedure(Sender: TObject; Msg: TIDEMessageLine);

  TIDEMsgQuickFixItem = class(TPersistent)
  private
    FCaption: string;
    FName: string;
    FOnExecuteMethod: TIMQFExecuteMethod;
    FOnExecuteProc: TIMQFExecuteProc;
    FRegExpression: string;
    FRegExprModifiers: string;
    function GetCaption: string;
    procedure SetCaption(const AValue: string);
    procedure SetName(const AValue: string);
    procedure SetRegExpression(const AValue: string);
    procedure SetRegExprModifiers(const AValue: string);
  public
    procedure Execute(const Msg: TIDEMessageLine); virtual;
    function IsApplicable(Line: TIDEMessageLine): boolean; virtual;
  public
    property Name: string read FName write SetName;
    property Caption: string read GetCaption write SetCaption;
    property RegExpression: string read FRegExpression write SetRegExpression;
    property RegExprModifiers: string read FRegExprModifiers write SetRegExprModifiers;
    property OnExecuteMethod: TIMQFExecuteMethod read FOnExecuteMethod write FOnExecuteMethod;
    property OnExecuteProc: TIMQFExecuteProc read FOnExecuteProc write FOnExecuteProc;
  end;
  
  { TIDEMsgQuickFixItems }

  TIDEMsgQuickFixItems = class(TPersistent)
  private
    FItems: TFPList;
    function GetCount: integer;
    function GetItems(Index: integer): TIDEMsgQuickFixItem;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Add(Item: TIDEMsgQuickFixItem): integer;
    procedure Remove(Item: TIDEMsgQuickFixItem);
    function IndexOfName(const Name: string): integer;
    function FindByName(const Name: string): TIDEMsgQuickFixItem;
    function NewName(const StartValue: string): string;
  public
    property Count: integer read GetCount;
    property Items[Index: integer]: TIDEMsgQuickFixItem read GetItems; default;
  end;
  
var
  IDEMsgQuickFixes: TIDEMsgQuickFixItems; // initialized by the IDE
  
procedure RegisterIDEMsgQuickFix(Item: TIDEMsgQuickFixItem);
function RegisterIDEMsgQuickFix(const Name, Caption, RegExpr: string;
  const ExecuteMethod: TIMQFExecuteMethod;
  const ExecuteProc: TIMQFExecuteProc): TIDEMsgQuickFixItem; overload;

implementation

procedure RegisterIDEMsgQuickFix(Item: TIDEMsgQuickFixItem);
begin
  IDEMsgQuickFixes.Add(Item);
end;

function RegisterIDEMsgQuickFix(const Name, Caption, RegExpr: string;
  const ExecuteMethod: TIMQFExecuteMethod; const ExecuteProc: TIMQFExecuteProc
  ): TIDEMsgQuickFixItem;
begin
  Result:=TIDEMsgQuickFixItem.Create;
  Result.Name:=Name;
  Result.Caption:=Caption;
  Result.RegExpression:=RegExpr;
  Result.OnExecuteMethod:=ExecuteMethod;
  Result.OnExecuteProc:=ExecuteProc;
  IDEMsgQuickFixes.Add(Result);
end;

{ TIDEMsgQuickFixItem }

function TIDEMsgQuickFixItem.GetCaption: string;
begin
  if FCaption<>'' then
    Result:=FCaption
  else
    Result:=FName;
end;

procedure TIDEMsgQuickFixItem.SetCaption(const AValue: string);
begin
  if FCaption=AValue then exit;
  FCaption:=AValue;
end;

procedure TIDEMsgQuickFixItem.SetName(const AValue: string);
begin
  if FName=AValue then exit;
  FName:=AValue;
end;

procedure TIDEMsgQuickFixItem.SetRegExpression(const AValue: string);
begin
  if FRegExpression=AValue then exit;
  FRegExpression:=AValue;
end;

procedure TIDEMsgQuickFixItem.SetRegExprModifiers(const AValue: string);
begin
  if FRegExprModifiers=AValue then exit;
  FRegExprModifiers:=AValue;
end;

procedure TIDEMsgQuickFixItem.Execute(const Msg: TIDEMessageLine);
begin
  if Assigned(OnExecuteMethod) then
    OnExecuteMethod(Self,Msg);
  if Assigned(OnExecuteProc) then
    OnExecuteProc(Self,Msg);
end;

function TIDEMsgQuickFixItem.IsApplicable(Line: TIDEMessageLine): boolean;
begin
  Result:=false;
  if RegExpression='' then exit;
  Result:=REMatches(Line.Msg,RegExpression,RegExprModifiers);
end;

{ TIDEMsgQuickFixItems }

function TIDEMsgQuickFixItems.GetItems(Index: integer): TIDEMsgQuickFixItem;
begin
  Result:=TIDEMsgQuickFixItem(FItems[Index]);
end;

function TIDEMsgQuickFixItems.GetCount: integer;
begin
  Result:=FItems.Count;
end;

constructor TIDEMsgQuickFixItems.Create;
begin
  FItems:=TFPList.Create;
end;

destructor TIDEMsgQuickFixItems.Destroy;
begin
  Clear;
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TIDEMsgQuickFixItems.Clear;
var
  i: Integer;
begin
  for i:=Count-1 downto 0 do Items[i].Free;
end;

function TIDEMsgQuickFixItems.Add(Item: TIDEMsgQuickFixItem): integer;
begin
  Item.Name:=NewName(Item.Name);
  Result:=FItems.Add(Item);
end;

procedure TIDEMsgQuickFixItems.Remove(Item: TIDEMsgQuickFixItem);
begin
  FItems.Remove(Item);
end;

function TIDEMsgQuickFixItems.IndexOfName(const Name: string): integer;
begin
  for Result:=0 to Count-1 do
    if CompareText(Items[Result].Name,Name)=0 then exit;
  Result:=-1;
end;

function TIDEMsgQuickFixItems.FindByName(const Name: string
  ): TIDEMsgQuickFixItem;
var
  i: LongInt;
begin
  i:=IndexOfName(Name);
  if i>=0 then
    Result:=Items[i]
  else
    Result:=nil;
end;

function TIDEMsgQuickFixItems.NewName(const StartValue: string): string;
begin
  Result:=CreateFirstIdentifier(StartValue);
  while IndexOfName(Result)>=0 do
    Result:=CreateNextIdentifier(Result);
end;

{ TIDEMessageLine }

procedure TIDEMessageLine.SetDirectory(const AValue: string);
begin
  if FDirectory = AValue then
    exit;
  FDirectory := AValue;
end;

procedure TIDEMessageLine.SetMsg(const AValue: string);
begin
  if FMsg = AValue then
    exit;
  FMsg := AValue;
end;

constructor TIDEMessageLine.Create;
begin
  FPosition := -1;
  FVisiblePosition := -1;
end;

destructor TIDEMessageLine.Destroy;
begin
  FParts.Free;
  inherited Destroy;
end;

{ TIDEMessageLineList }

function TIDEMessageLineList.GetCount: integer;
begin
  Result:=FItems.Count;
end;

function TIDEMessageLineList.GetItems(Index: integer): TIDEMessageLine;
begin
  Result:=TIDEMessageLine(FItems[Index]);
end;

function TIDEMessageLineList.GetParts(Index: integer): TStrings;
begin
  Result:=Items[Index].Parts;
end;

procedure TIDEMessageLineList.SetParts(Index: integer; const AValue: TStrings);
begin
  Items[Index].Parts:=AValue;
end;

constructor TIDEMessageLineList.Create;
begin
  FItems:=TFPList.Create;
end;

destructor TIDEMessageLineList.Destroy;
begin
  Clear;
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TIDEMessageLineList.Clear;
var
  i: Integer;
begin
  for i:=0 to FItems.Count-1 do TObject(FItems[i]).Free;
  FItems.Clear;
end;

function TIDEMessageLineList.Add(const Msg: string): integer;
var
  Item: TIDEMessageLine;
begin
  Item:=TIDEMessageLine.Create;
  Item.Msg:=Msg;
  Result:=Add(Item);
end;

function TIDEMessageLineList.Add(Item: TIDEMessageLine): integer;
begin
  Result:=FItems.Add(Item);
  Item.OriginalIndex:=Result;
end;

procedure TIDEMessageLineList.Delete(Index: Integer);
begin
  TObject(FItems[Index]).Free;
  FItems.Delete(Index);
end;

end.

