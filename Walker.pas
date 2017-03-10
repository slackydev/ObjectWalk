{==============================================================================]
  Author: Jarl K. Holta
  Project: ObjectWalk
  Project URL: https://github.com/WarPie/ObjectWalk
  License: GNU LGPL (https://www.gnu.org/licenses/lgpl-3.0.en.html)
[==============================================================================}
{==============================================================================]
  This is an early version, there might exist bugs. It also means that
  variable-, type-, function-names and the structure in this file is not final.

  Over time there might come several changes, mainly for the better.

  Debug defines:
    OW:DEBUG       -> Nothing atm..
    OW:DEBUG_WORDY -> Will write some text, for example if it can't find a DTM
    OW:SMARTDEBUG  -> Will draw to the smartimage.
    OW:DEBUG_TIMES -> Will write some timings..
[==============================================================================}
{$include_once SRL/OSR.simba}
{$I minimap.pas}
{$I MMDTM.pas}

type
  TPathPoint = record
    Objects: TMMDTM;
    Dest: TPointArray; //one set of objects can cover several points.
  end;
  TMMPath = array of TPathPoint;

  TObjectWalk = record
    Types: TIntegerArray;
    MaxOffset, MaxInaccuracy, MaxScale: Double;
  end;


const
  //16 high pitch colors that should genrally show well on the minimap.
  COLOR_LIST16: TIntegerArray = [
      $0000ff, $00ff44, $eeff00, $ff0066, $6666ff, $55ffff, $f5ff66, $ff66a3,
      $00bbff, $5555DD, $ff5500, $dd00ff, $66d6ff, $85ff66, $ff9966, $eb66ff
  ];

(*
  Initalizes the walker with some presets
*)
procedure TObjectWalk.Init();
var
  i,j: Int32;
  mp:TPoint;
begin
  self.MaxOffset := 15;          //How much the minimap can offset in relation to the compass.
  self.MaxInaccuracy := 2.7;     //With rotation, slightly inaccurate object finding and other defomities, we need to allow a little inaccuracy.
  self.MaxScale := 1.13;         //minimap scales, from 0.95 to 1.05 (10%), so we allow 13% scaling of our feature points (3% more than what can be, to be on the safeside).
end;


(*
 Meh.. these two methods aren't really used, but I might need them for
 debugging later on
*)
function TObjectWalk.FindObjects(ObjIds: TIntegerArray): TMMObjectsArray; static;
var typ:Int32;
begin
  for typ in ObjIds do
    Result += TMMObjects([EMinimapObject(typ), Minimap.FindObj(MMObjRecords[typ])]);
end;

function TObjectWalk.FindObjects(DTM: TMMDTM): TMMObjectsArray; static; overload;
var
  i:Int32;
  test:TIntegerArray;
begin
  for i:=0 to High(DTM) do
  begin
    if test.Find(Ord(DTM[i].typ)) >= 0 then
      Continue;

    Result += TMMObjects([DTM[i].typ, Minimap.FindObj(MMObjRecords[DTM[i].typ])]);
    test += Ord(DTM[i].typ);
  end;
end;


(*
  Ugh.. the input points gotta be scaled and rotated in relation to where we found
  the DTM, it's scale, and the minimap-offset-to-compass
*)
function TObjectWalk.AdjustPoint(pt:TPoint; mp:TMMDTMPoint; theta,scale:Double): TPoint; static;
var
  p:PPoint;
begin
  p.R := Hypot(pt.y, pt.x) * scale;
  p.T := ArcTan2(pt.y, pt.x) + (PI + theta + minimap.GetCompassAngle(False));
  Result := Point(Round(mp.x + p.r * Cos(p.t)), Round(mp.y + p.r * Sin(p.t)));
end;

function TObjectWalk.AdjustBlindPoint(pt:TPoint; theta,scale:Double): TPoint; static;
var
  p:PPoint;
begin
  pt -= minimap.Center;
  p.R := Hypot(pt.y, pt.x) * scale;
  p.T := ArcTan2(pt.y, pt.x) + (PI + theta + minimap.GetCompassAngle(False));
  Result := Point(Round(minimap.Center.x + p.r * Cos(p.t)), Round(minimap.Center.y + p.r * Sin(p.t)));
end;

(*
  Simple method to find a dtm
*)
function TObjectWalk.FindDTM(out Res:TMMDTMResult; DTM:TMMDTM; MaxTime:Int32=3500): Boolean; constref;
var
  t:Int64;
begin
  Res := [];
  t := GetTickCount()+MaxTime;
  while (GetTickCount() < t) and (Res.DTM = []) do
  begin
    Res := DTM.RotateToCompass().Find(self.MaxOffset, self.MaxScale, self.MaxInaccuracy);
    if Res.DTM = [] then Wait(60);
  end;
  Result := Res.DTM <> [];
end;

(*
  Just a neat function to have..
  It locates the "goal" point taking into account all minimap transformations..
  Then it returns the distance from you (at minimap center) to this point.
*)
function TObjectWalk.DistanceTo(Goal:TPoint; DTM:TMMDTM): Double; constref;
var
  F:TMMDTMResult;
  other,me:TPoint;
  i:Int32;
begin
  Goal.x -= DTM[0].x;
  Goal.y -= DTM[0].y;
  me := minimap.Center;
  if not self.FindDTM(F, DTM) then
    Exit(-1);

  other := self.AdjustPoint(Goal, F.DTM[0], F.theta, F.scale);
  Result := Hypot(me.x-other.x, me.y-other.y);
end;

(*
  Yeah.. this one is supersimple, with no real random at all (it's a prototype after all).
*)
procedure TObjectWalk.WalkTo(pt:TPoint{$IFDEF OW:SMARTDEBUG}; step:TPoint; DTM:TMMDTM{$ENDIF}); constref;
begin
  {$IFDEF OW:SMARTDEBUG}self.DebugDTM(step, DTM, Smart.Image);{$ENDIF}
  Mouse.Click(pt, 1);

  while minimap.IsFlagPresent(800) do
  begin
    {$IFDEF OW:SMARTDEBUG}
      self.DebugDTM(step, DTM, Smart.Image);
      Wait(7);
    {$ELSE}
      Wait(70);
    {$ENDIF}
  end;

  {$IFDEF OW:SMARTDEBUG}
    smart.Image.DrawClear(0);
  {$ENDIF}
end;

(*
  This is your best friend. It will walk the minimap up, down, and sideways, yo!
*)
function TObjectWalk.Walk(Path:TMMPath): Boolean; constref;
var
  i,_:Int32;
  step,pt:TPoint;
  F:TMMDTMResult;
  theta,scale:Double;
begin
  theta := PI;
  scale := 1;

  for i:=0 to High(Path) do
    for step in Path[i].Dest do
    begin
      if Length(Path[i].Objects) = 0 then //blind step
      begin
        pt := self.AdjustBlindPoint(step, theta, scale);
        self.WalkTo(pt.Random(4,4){$IFDEF OW:SMARTDEBUG},step,Path[i].Objects{$ENDIF});
        continue;
      end;

      for _:=0 to 19 do
      begin
        {$IFDEF OW:SMARTDEBUG}
          if not self.DebugDTM(step, Path[i].Objects, Smart.Image) then
            Smart.Image.DrawClear(0);
        {$ENDIF}

        if not self.FindDTM(F,Path[i].Objects) then
        begin
          {$IFDEF OW:DEBUG_WORDY}WriteLn('Warning: Unable to find DTM ', i);{$ENDIF}
          Exit(False);
        end;

        pt.x := step.x - Path[i].Objects[0].x;
        pt.y := step.y - Path[i].Objects[0].y;
        pt := self.AdjustPoint(pt, F.DTM[0], F.theta, F.scale);
        
        {$IFDEF OW:SMARTDEBUG}
          Smart.Image.DrawClear(0);
        {$ENDIF}

        if srl.PointInPoly(pt, MINIMAP_POLYGON) then Break;
        Wait(50);
      end;
      if not srl.PointInPoly(pt, MINIMAP_POLYGON) then
      begin
        {$IFDEF OW:DEBUG_WORDY}WriteLn('Warning: Point out of Range ', pt);{$ENDIF}
        Exit(False);
      end;

      self.WalkTo(pt{$IFDEF OW:SMARTDEBUG},step,Path[i].Objects{$ENDIF});

      theta := F.theta;
      scale := F.scale;
    end;
  Result := True;
end;



(*==| FOR DEBUGGING BELLOW THIS LINE |========================================*)
(*============================================================================*)

var
  __MMMask__:TPointArray := ReturnPointsNotInTPA(Minimap.MaskTPA, GetTPABounds(Minimap.MaskTPA));


procedure TObjectWalk.DebugMinimap(im:TMufasaBitmap; offset:TPoint=[0,0]; Clear:Boolean=True); constref;
var
  objects: T2DPointArray;
  color,i:Int32;
  pt:TPoint;
  b:TBox;
  {$IFDEF OW:DEBUG_TIMES} t:TDateTime;{$ENDIF}
begin
  for i:=0 to High(MMObjRecords) do
  begin
    {$IFDEF OW:DEBUG_TIMES}t := Now();{$ENDIF}
    objects += Minimap.FindObj(MMObjRecords[i]);
    {$IFDEF OW:DEBUG_TIMES}WriteLn('Finding ', EMinimapObject(i), ' used: ', FormatDateTime('z', Now()-t),'ms');{$ENDIF}
  end;

  if Clear and (offset = [0,0]) then im.DrawTPA(__MMMask__, 0);
  for i:=0 to High(objects) do
    for pt in objects[i] do
    begin
      color := COLOR_LIST16[i mod 16];
      pt += offset;
      try
      Im.DrawTPA(TPAFromBox(Box(pt,1,1)), color);
      except
      end;
    end;
end;


function TObjectWalk.DebugDTM(Goal:TPoint; DTM:TMMDTM; im:TMufasaBitmap; offset:TPoint=[0,0]; Clear:Boolean=True): Boolean; constref;
var
  F:TMMDTMResult;
  line:TPointArray;
  found,p,q:TPoint;
  i,color:Int32;
begin
  if Length(DTM) = 0 then Exit();
  Result := True;
  Goal.x -= DTM[0].x;
  Goal.y -= DTM[0].y;

  if not self.FindDTM(F, DTM) then
  begin
    {$IFDEF OW:DEBUG_WORDY}WriteLn('Unable to find DTM!');{$ENDIF}
    Exit(False);
  end;

  found := self.AdjustPoint(Goal, F.DTM[0], F.theta, F.scale);
  found.Offset(offset);
  if Clear and (offset = [0,0]) then im.DrawTPA(__MMMask__, 0);

  Im.DrawTPA(TPAFromBox(Box(found,1,1)), COLOR_LIST16[0]);
  line := TPAFromLine(found.x, found.y, Minimap.Center.x, Minimap.Center.y);
  for i:=3 to High(line)-1 with 4 do
  begin
    Im.SetPixel(line[i+0].x, line[i+0].y, $FFFFFF);
    Im.SetPixel(line[i+1].x, line[i+1].y, $FFFFFF);
  end;

  for i:=0 to High(F.DTM) do
  begin
    p := F.DTM[i];
    p += offset;
    color := COLOR_LIST16[(i+1) mod 16];
    try
    Im.DrawTPA(TPAFromBox(Box(p,1,1)), color);
    except
    end;
    Im.DrawTPA(TPAFromLine(p.x,p.y,Minimap.Center.x,Minimap.Center.y), $999999);
  end;
end;

