{==============================================================================]
  Author: Jarl K. Holta
  Project: ObjectWalk
  Project URL: https://github.com/WarPie/ObjectWalk
  License: GNU LGPL (https://www.gnu.org/licenses/lgpl-3.0.en.html)
[==============================================================================}
type
  EMinimapObject = (
    mmLadder, mmTree, mmDeadTree, mmPalmTree, mmFlax, mmBoulder, mmHenge,
    mmCactus, mmMaple, mmRock, mmRed
  );

  MMObjDef = record
    Colors:TIntegerArray;
    Tol: Int32;
    SplitX, SplitY: Int32;
    AvgNumOfPoints, AvgTol: Int32;
  end;


const
  MINIMAP_POLYGON: TPointArray = [
    [571,77], [571,67], [575,54], [581,43], [587,35], [598,25], [609,18],
    [628,11], [645,10], [658,11], [671,15], [683,22], [692,29], [702,40],
    [709,50], [713,63], [713,65], [713,82], [708,105],[702,115],[670,135],
    [660,145],[658,151],[651,158],[633,158],[628,154],[625,151],[623,145],
    [613,135],[601,128],[584,117],[578,110],[573,96]
  ];

(*
  Filters points so you only end up with points actually on the minimap..
  This works unlike the broken one in SRL/SRL #BlameOlly
  Note: It's slow.. so, don't use it in any high performance methods.
*)
procedure TMinimap.FilterPointsFix(var TPA:TPointArray); static;
var
  tmp:TPointArray;
  i,c:Int32;
begin
  SetLength(tmp, Length(TPA));
  for i:=0 to High(TPA) do
    if srl.PointInPoly(TPA[i], MINIMAP_POLYGON) then
      tmp[Inc(c)-1] := TPA[i];
  TPA := tmp;
  SetLength(TPA, c);
end;


//inspired by function in ObjectDTM (by euph..)
function TMinimap.FindObjEx(Obj:MMObjDef; Bounds:TBox; OnMinimapCheck:Boolean=True): TPointArray;
var
  i,avgN,lo,hi,color: Int32;
  TPA,TmpRes: TPointArray;
  ATPA: T2DPointArray;
  mid: TPoint;
begin
  SetLength(ATPA, Length(Obj.Colors));

  for i:=0 to High(Obj.Colors) do
    FindColorsTolerance(ATPA[i], Obj.Colors[i], Bounds.x1, Bounds.y1, Bounds.x2, Bounds.y2, Obj.Tol);

  avgN := Obj.AvgNumOfPoints;
  for i:=0 to High(ATPA) do
    for TPA in ClusterTPAEx(ATPA[i], Obj.SplitX, Obj.SplitY) do
    begin
      if not InRange(Length(TPA), avgN - Obj.AvgTol, avgN + Obj.AvgTol) then
        Continue;
      mid := MiddleTPA(TPA);
      if (not OnMinimapCheck) or srl.PointInPoly(mid, MINIMAP_POLYGON) then
        TmpRes += mid;
    end;

  //clearning duplicates and neighbouring points by simply merging them into 1
  for TPA in ClusterTPA(TmpRes, 2) do Result += MiddleTPA(TPA);
end;


function TMinimap.FindObj(Obj: MMObjDef): TPointArray;
begin                //       MM area
  Result := FindObjEx(Obj, [570,9,714,159]);
end;


function UniqueColors(colors:TIntegerArray; Tolerance:Int32=5): TIntegerArray;
var 
  i,j:Int32;
  similar:Boolean;
begin
  for i:=0 to High(colors) do
  begin
    for j:=i+1 to High(colors) do
      if similar := SimilarColors(colors[i],colors[j], tolerance) then
        Break;
    if not similar then
      Result += colors[i];
  end;
end;


(*
 Based on a function in ObjectDTM (by euph..)
 The object definitions might not work properly, this is a rough sketch.
 The colors comment is what I've used to calibrate tolerances.
 
 The more colors we add the lower tolerance we can use, the more the merrier, up to a point.
*)
var
  MMObjRecords: array [EMinimapObject] of MMObjDef;
begin
  {colors: 1717603,1783655,6976,6993,865128}
  with MMObjRecords[mmLadder] do
  begin
    Colors := [928084];
    Tol := 30;
    SplitX := 2; SplitY := 2;
    AvgNumOfPoints := 32; AvgTol := 19;
  end;

  with MMObjRecords[mmTree] do
  begin
    Colors := UniqueColors([1258044,7983,602944,271914,1391694,140343,2310221,933949]);
    Tol := 18; //stem
    SplitX := 2; SplitY := 2;
    AvgNumOfPoints := 7; AvgTol := 6;
  end;

  with MMObjRecords[mmDeadTree] do
  begin
    Colors := UniqueColors([2346,1188400,2305857,6452,1387330,267550]);
    Tol := 20;
    SplitX := 2; SplitY := 2;
    AvgNumOfPoints := 20; AvgTol := 8;
  end;

  with MMObjRecords[mmPalmTree] do
  begin
    Colors := UniqueColors([1384586,3445,137352,2633365,463487]);
    Tol := 20;
    SplitX := 1; SplitY := 1;
    AvgNumOfPoints := 4; AvgTol := 3;
  end;

  with MMObjRecords[mmFlax] do
  begin
    Colors := [9398872];
    Tol := 1; //not tweaked
    SplitX := 2; SplitY := 2;
    AvgNumOfPoints := 6; AvgTol := 3;
  end;

  //3757702, 1920118, 3890578
  with MMObjRecords[mmBoulder] do
  begin
    Colors := [2905476];
    Tol := 30; //partially tweaked
    SplitX := 1; SplitY := 1;
    AvgNumOfPoints := 37; AvgTol := 18;
  end;

  with MMObjRecords[mmHenge] do
  begin
    Colors := [4409670];
    Tol := 1; //not tweaked
    SplitX := 1; SplitY := 1;
    AvgNumOfPoints := 9; AvgTol := 6;
  end;

  //5013585
  with MMObjRecords[mmCactus] do
  begin
    Colors := [5013585];
    Tol := 30;
    SplitX := 1; SplitY := 1;
    AvgNumOfPoints := 80; AvgTol := 50;
  end;

  with MMObjRecords[mmMaple] do
  begin
    Colors := [999524];
    Tol := 1; //not tweaked
    SplitX := 1; SplitY := 1;
    AvgNumOfPoints := 17; AvgTol := 5;
  end;

  {colors: 5923680,7429746,7365990,4869977,7365990}
  with MMObjRecords[mmRock] do
  begin
    Colors := UniqueColors([5923680,7429746,7365990,4869977,7365990,3884104]);
    Tol := 20;
    SplitX := 1; SplitY := 1;
    AvgNumOfPoints := 34; AvgTol := 18;
  end;

  with MMObjRecords[mmRed] do
  begin
    Colors := [240];
    Tol := 22;
    SplitX := 1; SplitY := 1;
    AvgNumOfPoints := 8; AvgTol := 6;
  end;
end;









