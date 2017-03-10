{==============================================================================]
  Author: Jarl K. Holta
  Project: ObjectWalk
  Project URL: https://github.com/WarPie/ObjectWalk
  License: GNU LGPL (https://www.gnu.org/licenses/lgpl-3.0.en.html)
[==============================================================================}
type
  TMMDTMPoint = record
    typ: EMinimapObject;
    x,y: Int32;
  end;
  TMMDTM = array of TMMDTMPoint;

  TMMObjects = record
    typ: EMinimapObject;
    TPA: TPointArray;
  end;
  TMMObjectsArray = array of TMMObjects;

  TMMDTMResult = record
    DTM: TMMDTM;
    scale,theta: Double;
  end;
  TMMDTMResultArray = array of TMMDTMResult;

  

//implementation
{$ifndef codeinsight}
operator := (var Left:TMMDTMPoint; Right:TPoint): TMMDTMPoint;
begin
  Left.x := Right.x;
  Left.y := Right.y;
  Result := Left;
end;

operator := (var Left:TPoint; Right:TMMDTMPoint): TPoint;
begin
  Left.x := Right.x;
  Left.y := Right.y;
end;
{$endif}


function TMMDTM.RotateToCompass(): TMMDTM; constref;
var
  i:Int32;
  pt:TPoint;
begin
  SetLength(Result, Length(self));
  for i:=0 to High(self) do
  begin
    pt := Point(self[i].x,self[i].y);
    pt := RotatePoint(pt, Minimap.GetCompassAngle(False), self[0].x,self[0].y);
    Result[i].x := pt.x;
    Result[i].y := pt.y;
    Result[i].typ := self[i].typ;
  end;
end;

(*
  This is our magic friend that made it all possible. It's where it all started.

  Note to self:
    Can we return many results, and sort them from the "expected" location when
    walking? this should make walking pretty much flawless, even tho duplicates exists.

    For anything else, we'd just use the first result, and assume the user has
    defined enough objects to never return duplicates.
*)
function TMMDTM.FindEx(Objects:TMMObjectsArray; MaxAngle:Double=180; MaxScale:Double=1.15; MaxEps:Double=3): TMMDTMResultArray; constref;
type
  TNode = record
    typ:EMinimapObject;
    R,T:Double;
  end;
var
  i,j,k,reslen:Int32;
  expectDist, foundDist, expectAngle, foundAngle: Double;
  newA, newD, offset, scale:Double;
  pts:array of TNode;
  candidates, TPA, tmp:TPointArray;
  output: TMMDTM;
  mp, pt, newPt:TPoint;

  function GetObjectPoints(typ:EMinimapObject; out points: TPointArray): Boolean;
  var i:Int32;
  begin
    for i:=0 to High(Objects) do
      if Objects[i].typ = typ then
      begin
        points := Copy(Objects[i].TPA);
        Result := True;
      end;
  end;

  function Nearest(TPA:TPointArray; p:TPoint): TPoint;
  var q:TPoint; d,h:Double = 9999999;
  begin
    for q in TPA do
    begin
      h := Hypot(q.x-p.x,q.y-p.y);
      if h < d then
      begin
        d := h;
        Result := q;
      end;
    end;
  end;
begin
  if Length(self) < 2 then
    Exit();

  MaxAngle := Radians(MaxAngle);

  for i:=1 to High(self) do
  begin
    pt.x := self[i].x - self[0].x;
    pt.y := self[i].y - self[0].y;

    pts += TNode([
      self[i].typ,
      Hypot(pt.y, pt.x),
      ArcTan2(pt.y, pt.x)
    ]);
  end;

  for i:=0 to High(Objects) do
    if (Objects[i].typ = self[0].typ) then
    begin
      candidates := objects[i].TPA;
      break;
    end;


  for i:=0 to High(candidates) do
  begin
    //assumed mainPoint
    mp := candidates[i];

    //grab inital points to start of
    expectDist  := pts[0].R;
    expectAngle := pts[0].T; //this is 1

    if not GetObjectPoints(pts[0].typ, TPA) then Exit();
    FilterPointsDist(TPA, expectDist*1/MaxScale, expectDist*MaxScale, mp.x,mp.y);

    //loop init
    SetLength(output, 2);
    output[0] := mp;
    output[0].typ := self[0].typ;

    for k:=0 to High(TPA) do //all of these are point[1] candidates
    begin
      TPA[k].Offset(Point(-mp.x,-mp.y)); //points are relative to mp.

      foundDist := Hypot(TPA[k].x,TPA[k].y);
      scale := 1+(foundDist-expectDist) / expectDist;
      foundAngle := ArcTan2(TPA[k].y, TPA[k].x);
      offset := srl.DeltaAngle(foundAngle, expectAngle, PI*2);

      if Abs(offset) > MaxAngle then
        continue;

      output[1] := TPA[k] + mp;
      output[1].typ := self[1].typ; //this is 2

      for j:=1 to High(pts) do
      begin
        //build expected location:
        newA := pts[j].T + offset;
        newD := pts[j].R * scale;
        newPt := Point(mp.x+Round(newD * Cos(newA)), mp.y+Round(newD * Sin(newA)));

        //lookup the nearest point to that location:
        if not GetObjectPoints(pts[j].typ, tmp) then Exit();
        pt := Nearest(tmp, newPt);

        if Hypot(pt.x-newPt.x, pt.y-newPt.y) < MaxEps then
          output += TMMDTMPoint([pts[j].typ, pt.x,pt.y])
        else
          break;
      end;

      if Length(output) = Length(self) then
      begin
        reslen := Length(result);
        SetLength(Result, reslen+1);
        Result[reslen].DTM   := output;
        Result[reslen].scale := scale;
        Result[reslen].theta := offset;
      end;
      
      SetLength(output, 2);
    end;
  end;
end;

(*
  This is the function above, just does us the favor of finding minimap objects first. 
  It will only look for the objects that is used in the "DTM" (TMMDTM)
*)
function TMMDTM.Find(var Match:TMMDTMResult; MaxAngle:Double=180; MaxScale:Double=1.15; MaxEps:Double=3): Boolean; constref;
var
  i:Int32;
  test:TIntegerArray;
  MMObjects:TMMObjectsArray;
  matches: TMMDTMResultArray;
begin
  for i:=0 to High(self) do
  begin
    if test.Find(Ord(self[i].typ)) >= 0 then Continue;
    test += Ord(self[i].typ);
  end;

  for i in Test do
    MMObjects += TMMObjects([EMinimapObject(i), Minimap.FindObj(MMObjRecords[i])]);
  
  matches := self.FindEx(MMObjects, MaxAngle,MaxScale,MaxEps);
  Result := Length(matches) > 0;
  if Result then
    Match := matches[0];
end;

(*
  This is the function above, just does us the favor of finding minimap objects first. 
  It will only look for the objects that is used in the "DTM" (TMMDTM)
*)
function TMMDTM.Find(var Matches:TMMDTMResultArray; MaxAngle:Double=180; MaxScale:Double=1.15; MaxEps:Double=3): Boolean; constref; overload;
var
  i:Int32;
  test:TIntegerArray;
  MMObjects:TMMObjectsArray;
begin
  for i:=0 to High(self) do
  begin
    if test.Find(Ord(self[i].typ)) >= 0 then Continue;
    test += Ord(self[i].typ);
  end;

  for i in Test do
    MMObjects += TMMObjects([EMinimapObject(i), Minimap.FindObj(MMObjRecords[i])]);
  
  Matches := self.FindEx(MMObjects, MaxAngle,MaxScale,MaxEps);
  Result := Length(matches) > 0;
end;
