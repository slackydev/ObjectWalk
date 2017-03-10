program test;
{$hints off}
{$define SMART}
{$define OW:SMARTDEBUG}
{$define OW:DEBUG_WORDY}
{$I SRL/OSR.simba}
{$I ObjectWalk/Walker.simba}

const
  DEBUG_POINTS = False;

var
  Walker: TObjectWalk;
  colors:TIntegerArray;
  path:TMMPath;
  DTM:TMMDTM;

procedure Init();
begin
  srl.Debugging := False;
  Smart.EnableDrawing := True;
  Smart.JavaPath := 'D:\Java7-32\bin\javaw.exe';
  Smart.Init();
end;

procedure LoadFallyPath();
begin
  SetLength(Path, 5);
  path[0].Objects := [[mmTree, 585, 68],[mmRed, 655, 122],[mmRed, 634, 129]];
  path[0].Dest    := [[620,86], [620, 133]];
  path[1].Objects := [[mmLadder, 661, 102],[mmLadder, 589, 92],[mmRed, 666, 118]];
  path[1].Dest    := [[642,137]];
  path[2].Objects := [[mmRed, 665, 65],[mmTree, 661, 118],[mmLadder, 659, 49]];
  path[2].Dest    := [[620,133]];
  path[3].Objects := [[mmPalmTree, 688, 115],[mmTree, 651,91],[mmTree, 638,132]];
  path[3].Dest    := [[620,133]];
  path[4].Objects := [[mmTree, 623, 82],[mmRock, 658, 128],[mmTree, 611, 112]];
  path[4].Dest    := [[612, 128], [597, 142]];
end;

var
  d:Double;
  t:TDateTime;
begin
  Init();

  //Start in fally bank (close to guild mine)
  if not DEBUG_POINTS then
  begin
    Walker.Init();
    LoadFallyPath();
    WriteLn Walker.Walk(path);
  end else
  begin

    while True do
    begin
      Walker.DebugMinimap(smart.Image);
      Smart.Image.DrawTPA(TPAFromCircle(642,84, 63), 1118740);
    end;

  end;
end.
