unit AStar;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ExtCtrls, Grids,Messages,math,IniFiles,LCLIntf, windows,ComCtrls,
  ActnList, Spin, Menus, IniPropStorage, robotmainfunctions, EditBtn,DecConsts, dynmatrix;


  type
  TRoundObstacle=record
    x,y,r: double;
    used: boolean;
  end;                                         //tipo Vetor Pontos de Trjetória

 procedure SatFieldLimits(var x,y: double); // função que configura os limites do campo

 //função pra criar melhor trajetória - Também é a função de chamada do A*
 function RobotBestPath(tg_x, tg_y:double; var traj: TTrajectory; var avoid: Tavoid): boolean;

var
  avoided_x,avoided_y: array [0..MaxSpheres-1] of double;
  avoided: array [0..MaxSpheres-1] of boolean;

// %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% //
//                      AStar definitions                        //
// %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% //

const
  AStarSlack = 0.1;   //total space where the robot can actually move around

  // A* modificado constantes para controlar se queremos activo ao não as diferentes modificações

  distancia:=true;
  choque:=true;
  rasto:=true;
  dirreccao:=true;
  dinamica:=true;
// A* modificado peso para as diferentes mudanças de direcção;
  d1:= 16134;
  d2:= 32268;
  d3:= 48302;
  d4:= 65536;

  //Total de largura e comprimento do campo
  TotalFieldWidth = (FieldWidth - 2*(RSpace+AStarSlack));
  TotalFieldLength = (FieldLength - 2*(RSpace+AStarSlack));

  AStarGridYSize = 90;
  AStarGridCellSize=(TotalFieldWidth/(AStarGridYSize));
  //AStarGridXSize = 115;
  AStarGridXSize = (round((TotalFieldLength/AStarGridCellSize)+2)div 2)*2;

  AStarVirgin = 0;
  AStarObstacle = 1;
  AStarClosed = 2;
  AStarOpen = 3;
  AStarGoals=1;

  FixedPointConst = 65536;
  sqrt2=round(1.4142135623730950488016887242097 * FixedPointConst);

type
  TGridCoord = record
    x,y: Smallint;
  end;

// A* modificado para ter um ponto com as coordenadas no mundo real
  TworldCoord = record
    x,y: double;
  end;

  TNeighbour = record
    x,y: Smallint;
    dist: integer;
  end;

const
  nilCoord: TGridCoord = (x:0; y:0); //coordenada do meio do campo
  EightWayNeighbours: array[0..7] of TNeighbour =
    ((x:1;  y:0; dist:FixedPointConst), (x:1;  y:-1; dist:sqrt2), (x:0; y:-1; dist:FixedPointConst), (x:-1; y:-1; dist:sqrt2),
     (x:-1; y:0; dist:FixedPointConst), (x:-1; y:1; dist:sqrt2),  (x:0; y:1; dist:FixedPointConst),  (x:1;  y:1; dist:sqrt2));

type
  PAStarCell = ^TAStarCell;
  TAStarCell = record
                     G,H: integer;
                     ParentDir: smallint;
                     HeapIdx: smallint;
                     MyCoord,ParentCoord: TGridCoord;
               end;

  TAStarGridState = array[0..AStarGridXSize-1, 0..AStarGridYSize-1] of byte;
  TAStarGrid = array[0..AStarGridXSize-1, 0..AStarGridYSize-1] of TAStarCell;

  TAStarHeapArray = record
                      data: array[0 .. 2047] of PAStarCell;
                      count: integer;
                    end;

  TAStarProfile = record
    RemovePointFromAStarList_count: integer;
    RemoveBestFromAStarList_count: integer;
    AddToAStarList_count: integer;
    HeapArrayTotal: integer;
    comparesTotal: integer;
    iter: integer;
    path_points: integer;
    path_distance: double;
    time: double;
  end;

  TAStarMap = record
    InitialPoint, TargetPoint: TGridCoord;
    Grid: TAStarGrid;
    GridState: TAStarGridState;
    HeapArray: TAStarHeapArray;
    Profile: TAStarProfile;
    EucliDistK: double;
  end;

  procedure AStarClear(var iMap: TAStarMap);
  procedure AStarInit(var iMap: TAStarMap);
  procedure AStarStep(var iMap: TAStarMap);
  procedure AStarGo(var iMap: TAStarMap);
  procedure RecalcSqrtCache(var iMap: TAStarMap);
  procedure DrawAStarGrid4x(var Map: TAStarMap; Img: TImage);
  procedure DrawAStarGrid4xPath(var Map: TAStarMap; Img: TImage);
  procedure setInitialState;
  procedure AStarWorldToGrid(wx,wy: double; var pnt: TGridCoord);


var
  AStarMap: TAStarMap;
  CalcHCache: array[0..AStarGridXSize-1, 0..AStarGridYSize-1] of integer;
Eightwaydinamic: array[0..7] of integer ;
implementation
uses control;

{ TFAStar }

/////////////////////////////////////////////////AStar Code/////////////////////////////////////////////////

procedure AStarGridToWorld(var pnt: TGridCoord; var wx,wy: double);
begin
  wx := (pnt.x - (AStarGridXSize div 2)) * AStarGridCellSize + AStarGridCellSize / 2;
  wy := (pnt.y - (AStarGridYSize div 2)) * AStarGridCellSize + AStarGridCellSize / 2;
end;

procedure AStarWorldToGrid(wx,wy: double; var pnt: TGridCoord);
begin
  pnt.x := round(wx / AStarGridCellSize + AStarGridXSize div 2);
  if pnt.x < 0 then pnt.x := 0;
  if pnt.x >= AStarGridXSize then pnt.x := AStarGridXSize - 1;
  pnt.y := round(wy / AStarGridCellSize + AStarGridYSize div 2);
  if pnt.y < 0 then pnt.y := 0;
  if pnt.y >= AStarGridYSize then pnt.y := AStarGridYSize - 1;
end;

procedure RecalcSqrtCache(var iMap: TAStarMap);
var x, y: integer;
begin
  for x := 0 to AStarGridXSize-1 do begin
    for y := 0 to AStarGridYSize-1 do begin
      CalcHCache[x,y] := round(sqrt(x * x * 1.0 + y * y) * iMap.EucliDistK * FixedPointConst);
      iMap.Grid[x,y].MyCoord.x := x;
      iMap.Grid[x,y].MyCoord.y := y;
    end;
  end;
end;

//A* modificado para encontrar o ponto de choque

function meetingpoint(xr,yr,v,xa,ya,vxa,vya : double; var xf,yf: double) :boolean ;
var  t,vxr,a,b,vrx,vry,n,xrf,yrf,r:double;
     sair:boolean;
begin
 t:=0;
 sair:=true;
 r:=0.2;
if (sqrt(vxa*vxa+vya*vya)<0.1) then
begin
    xf:=xa;
    yf:=ya;
    result:=true;
    exit;
end;
 
while (t<2) do begin
  t:=t+0.05;
  xf:=xa+vxa*t;
  yf:=ya+vya*t;

   if (xf<(AStarGridXSize*AStarGridCellSize/2)) and (xf>(-AStarGridXSize*AStarGridCellSize/2)) and
   (yf<(AStarGridYSize*AStarGridCellSize/2)) and  (yf>(-AStarGridYSize*AStarGridCellSize/2)) then
    begin
    a:=xf-xr;
  b:=yf-yr;
  n:=sqrt(a*a+b*b);
  if (n=0) then begin
        result:=false;
        exit;
        end;
  vrx:=a*v/n;
  vry:=b*v/n;
  xrf:=xr+vrx*t;
  yrf:=yr+vry*t;
 // ler.add( floattostr(xrf)+'-  h - '+floattostr(yrf)+' t '+floattostr(t));
 //  ler.SaveToFile(ficheiro);
  if (sqrt((xrf-xf)*(xrf-xf)+(yrf-yf)*(yrf-yf))<r) then  begin
     result:=true;
     exit;
     end;
  end else
     begin

     result:=false;
     exit;
     end;


end;

//A* modificado calculo do novo raio em função da distancia ao robot

function rcalc(var r:double;dist:double) : double;
begin
   if dist<mindist then result:=r else
   if dist>maxdist then result:=0 else
   result:=r*dist/(mindist-maxdist)+r-(mindist)*r/(mindist-maxdist);

end;


//A* modificado função para fazer  a rotação das coordenadas em função do angulo do movimento
function rotdouble(x,y:double; teta:double): TworldCoord ;
begin
  result.x:=cos(teta)*x-sin(teta)*y;
  result.y:=sin(teta)*x+cos(teta)*y;


end;

//A* modificado cria os rastos dos obstaculos, esse rasto é uma elipse.

procedure AddAStarObstacleTrail(x, y, r:double; vx,vy: double; var grid: TAStarGridState);
var i: integer;
    dx,vf,tet,dy,dy1,vallorfuzzy,valorfuzzy1,valorfuzzyextra,relipse,j,er: double;
    celrod:Tworldcoord;
    ptl:Tgridcoord;
begin
// o rasto é propocional à velocidade, isto é quanto maior é a velocidade maior vai ser o comprimento da elipse
 Vf:=sqrt(vx*vx+vy*vy);

    if vf>0.01 then begin
       if vf>=vfuzzymax  then relipse:=belipsemax*AStarGridCellSize
       else relipse:=(vf*belipsemax/vfuzzymax)*AStarGridCellSize;

//calcula o angulo em que está a move-se.
       if  abs(vx)<0.01 then
            if vy>0 then tet:=pi/2 else tet:=-pi/2 else
            if abs(vy)<0.01 then
            begin
              if vx>0 then tet:=0 else tet:=pi;
            end else tet:=arctan(vy/vx);
              er:=0;

// vai por como obstaculo as bordas da elipse
      repeat
           j:=0;
           repeat
             dy:=sqrt((1 - (j*j)/((r+relipse-er)*(r+relipse-er)))*(r-er)*(r-er));
             celrod:=rotdouble(j,dy,tet);
              AStarWorldToGrid(celrod.x+x, celrod.y+y, ptl);
              grid[ptl.x,ptl.y]:=AStarObstacle;
             celrod:=rotdouble(j,-dy,tet);
              AStarWorldToGrid(celrod.x+x, celrod.y+y, ptl);
              grid[ptl.x,ptl.y]:=AStarObstacle;
             j:=j+0.02;
           until (j>(r+relipse-er));
           er:=0.01+er;
      until er>0.06;


           end else
           AStarDrawCircle(x, y, r, Grid);

end;

// A* modificado procedimento que põe uma circunferência à volta do target de modo a só chegar a ele atravês do angulo pretendido
procedure AStarDrawCircleTarget(cx, cy, radius,angle: double; var grid: TAStarGridState);
var x, y: integer;
    ptl, pbr, cur_pnt: TGridCoord;
    wx,wy,tet,distancia: double;
begin
  AStarWorldToGrid(cx - radius, cy - radius, ptl);
  AStarWorldToGrid(cx + radius, cy + radius, pbr);
  for x := ptl.x to pbr.x do begin
    cur_pnt.x := x;
    for y := ptl.y to pbr.y do begin
      cur_pnt.y := y;
      AStarGridToWorld(cur_pnt, wx, wy);
      tet:=ATan2(wx-cx, wy-cy);
      if (tet<=(angle+amp)) and (tet>=(angle-tet)) then begin
       end else
       begin
      distancia:=Dist(wx - cx, wy - cy);
      if  (distancia< (radius)) and (distancia>(AStarGridCellSize*1.9)) then begin
        grid[cur_pnt.x, cur_pnt.y] := AStarObstacle;
       end;
      end;
    end;
  end;
end;



procedure AStarClear(var iMap: TAStarMap);
var i: integer;
begin
  // clear the grid, set all nodes to state "virgin"
  FillChar(iMap.GridState,sizeof(TAStarGridState), ord(AStarVirgin));

  // Build the wall around the grid,
  // this way, we don't have to worry about the frontier conditions
  for i:=0 to AStarGridXSize-1 do begin
    iMap.GridState[i,0]:= AStarObstacle;
    iMap.GridState[i,AStarGridYSize-1]:= AStarObstacle;
  end;

  for i:=0 to AStarGridYSize-1 do begin
    iMap.GridState[0,i]:= AStarObstacle;
    iMap.GridState[AStarGridXSize-1,i]:= AStarObstacle;
  end;

  // clear the heap
  iMap.HeapArray.Count := 0;
end;

function GridCoordIsEqual( G1,G2: TGridCoord): boolean;
begin
  if (g1.x = g2.x) and (g1.y = g2.y) then result := true
  else result := false;
end;

function GridCoordIsNil( G1: TGridCoord): boolean;
begin
  if (g1.x = 0) and (g1.y = 0) then result := true
  else result := false;
end;

// ---------------------------------------------------------------
//     Heap Operations

function CalcHeapCost(var Map: TAStarMap; idx: integer): integer;
begin
  with Map.HeapArray.data[idx]^ do begin
    result := G + H;
  end;
end;

procedure SwapHeapElements(var Map: TAStarMap; idx1, idx2: integer);
var ptr1, ptr2: PAStarCell;
begin
  ptr1 := Map.HeapArray.data[idx1];
  ptr2 := Map.HeapArray.data[idx2];
  ptr1^.HeapIdx := idx2;
  ptr2^.HeapIdx := idx1;
  Map.HeapArray.data[idx1] := ptr2;
  Map.HeapArray.data[idx2] := ptr1;
end;

procedure UpdateHeapPositionByPromotion(var Map: TAStarMap; idx: integer);
var parent_idx: integer;
    node_cost: integer;
begin
  // if we are on the first node, there is no way to promote
  if idx = 0 then exit;
  // calc node cost
  node_cost := CalcHeapCost(Map, idx);
  // repeat until we can promote no longer
  while true do begin
    // if we are on the first node, there is no way to promote
    if idx = 0 then exit;

    parent_idx := (idx - 1) div 2;
    // if the parent is better than we are, there will be no promotion
    if CalcHeapCost(Map, parent_idx) < node_cost then exit;
    // if not, just promote it
    SwapHeapElements(Map, idx, parent_idx);
    idx:= parent_idx;
  end;
end;

// update one node after increasing its cost
procedure UpdateHeapPositionByDemotion(var Map: TAStarMap; idx: integer);
var c1, c2, cost: integer;
    idx_child, new_idx: integer;
begin

  cost := CalcHeapCost(Map, idx);

  while true do begin

    idx_child := idx * 2 + 1;
    // if the node has no childs, there is no way to demote
    if idx_child >= Map.HeapArray.count then exit;

    // calc our cost and the first node cost
    c1 := CalcHeapCost(Map, idx_child);
    // if there is only one child, just compare with this one
    if idx_child + 1 >= Map.HeapArray.count then begin
      // if we are better than this child, then no demotion
      if cost < c1 then exit;
      // if not, then do the demotion
      SwapHeapElements(Map, idx, idx_child);
      exit;
    end;

    // calc the second node cost
    c2 := CalcHeapCost(Map, idx_child + 1);

    // select the best node to demote to
    new_idx := idx;
    if c2 < cost then begin
      if c1 < c2 then begin
        new_idx := idx_child;
      end else begin
        new_idx := idx_child + 1;
      end;
    end else if c1 < cost then begin
      new_idx := idx_child;
    end;

    // if there is no better child, just return
    if new_idx = idx then exit;

    // if we want to demote, then swap the elements
    SwapHeapElements(Map, idx, new_idx);
    idx := new_idx;
  end;
end;

procedure RemoveBestFromAStarList(var iMap: TAStarMap; out Pnt: TGridCoord);
begin
  inc(iMap.Profile.RemoveBestFromAStarList_count);

  with iMap.HeapArray do begin
    // return the first node
    Pnt := data[0]^.MyCoord;
    // move the last node into the first position
    data[count - 1]^.HeapIdx := 0;
    data[0] := data[count - 1];
    // update the array size
    Dec(count);
  end;
  // re-sort that "first" node
  UpdateHeapPositionByDemotion(iMap,0);
end;

procedure AddToAStarList( var Map: TAStarMap; Pnt: TGridCoord);
var idx: integer;
begin
  inc(Map.Profile.AddToAStarList_count);

  // update the grid state
  Map.GridState[Pnt.x, Pnt.y]:=AStarOpen;

  // insert at the bottom of the heap
  idx := Map.HeapArray.count;
  Map.HeapArray.data[idx] := @Map.Grid[Pnt.x,Pnt.y];
  Map.Grid[Pnt.x,Pnt.y].HeapIdx := idx;
  Inc(Map.HeapArray.count);

  // update by promotion up to the right place
  UpdateHeapPositionByPromotion(Map, idx);
end;

function CalcH(var Map: TAStarMap; Pi, Pf: TGridCoord): integer;  inline;
begin
  Result:= CalcHCache[Abs(Pi.x-Pf.x), Abs(Pi.y-Pf.y)];
end;

procedure AStarStep(var iMap: TAStarMap);
var curPnt, NewPnt: TGridCoord;
    ith, NeighboursCount: integer;
    newG: integer;
    newdist: integer;
begin
  inc(iMap.Profile.iter);
  inc(iMap.Profile.HeapArrayTotal, iMap.HeapArray.count);

  RemoveBestFromAStarList(iMap,curPnt);
  iMap.GridState[curPnt.x,curPnt.Y]:=AStarClosed;

  NeighboursCount := 8;
  for ith:=0 to NeighboursCount-1 do begin
    NewPnt.x := CurPnt.x + EightWayNeighbours[ith].x;
    NewPnt.y := CurPnt.y + EightWayNeighbours[ith].y;

    case iMap.GridState[NewPnt.x, NewPnt.y] of
      AStarClosed: continue;

      AStarVirgin: begin
        with iMap.Grid[NewPnt.x, NewPnt.y] do begin;
          ParentDir := ith;
// A* modificado 
	   if dinamica then begin
          dif:=abs(Map.Grid[CurPnt.x, CurPnt.y].ParentDir-ith);
           G := Map.Grid[CurPnt.x, CurPnt.y].G +EightWayNeighbours[ith].dist+Eightwaydinamic[dif];
          end else

          G := iMap.Grid[CurPnt.x, CurPnt.y].G + EightWayNeighbours[ith].dist;
          H := CalcH(iMap, NewPnt, iMap.TargetPoint);
        end;
        AddToAStarList(iMap,NewPnt);
      end;

      AStarOpen: begin
//A* modificado
        if dinamica then begin
          dif:=abs(Map.Grid[CurPnt.x, CurPnt.y].ParentDir-ith);

          newG := Map.Grid[CurPnt.x, CurPnt.y].G +EightWayNeighbours[ith].dist+Eightwaydinamic[dif];
          end else
     
        newG := iMap.Grid[CurPnt.x, CurPnt.y].G + EightWayNeighbours[ith].dist;
        if newG < iMap.Grid[NewPnt.x, NewPnt.y].G then begin
          iMap.Grid[NewPnt.x, NewPnt.y].G := newG;
          iMap.Grid[NewPnt.x, NewPnt.y].ParentDir := ith;
          UpdateHeapPositionByPromotion(iMap, iMap.Grid[NewPnt.x, NewPnt.y].HeapIdx);
        end;
      end;
    end;
  end;
end;

// check if the given point is inside an obstacle and move it to the closest open space
procedure AStarCheckBoundary(var pnt: TGridCoord; var Map: TAStarMap);
var i, j, x, y: integer;
begin
  // if we are not inside an obstacle, just return
  if Map.GridState[pnt.x,pnt.y] <> AStarObstacle then exit;

  for i := 1 to AStarGridXSize - 1 do begin
    for j := 7 downto 0 do begin
      x := pnt.x + EightWayNeighbours[j].x * i;
      y := pnt.y + EightWayNeighbours[j].y * i;
      if (x >= 0) and (y >= 0) and (x < AStarGridXSize) and (y < AStarGridYSize) then begin
        if Map.GridState[x,y] <> AStarObstacle then begin
          pnt.x := x;
          pnt.y := y;
          exit;
        end;
      end;
    end;
  end;
end;

procedure AStarCheckBoundaries(var Map: TAStarMap);
begin
  AStarCheckBoundary(Map.InitialPoint, Map);
  AStarCheckBoundary(Map.TargetPoint, Map);
end;

procedure AStarInit(var iMap: TAStarMap);
begin
  zeromemory(@(iMap.Profile),sizeof(iMap.Profile));
  AddToAStarList(iMap, iMap.InitialPoint);
  iMap.Grid[iMap.InitialPoint.x, iMap.InitialPoint.y].H:= CalcH( iMap, iMap.InitialPoint, iMap.TargetPoint);
end;

procedure AStarGo(var iMap: TAStarMap);
begin
  AStarCheckBoundaries(iMap);
  AStarInit(iMap);
  while true do begin
    AStarStep(iMap);

    if iMap.GridState[iMap.TargetPoint.x, iMap.TargetPoint.y] = AStarClosed then break;
    // there is no path
    if iMap.HeapArray.count = 0 then break;
  end;
end;

procedure NextPnt(var Map: TAStarMap; var pnt: TGridCoord);
var dir: integer;
begin
  dir := Map.Grid[pnt.x, pnt.y].ParentDir;
  if (dir<0) or (dir>7) then exit; //TODO isto nao deve acontecer, só deve haver dir entre 0 e 7
  pnt.x := pnt.x - EightWayNeighbours[dir].x;
  pnt.y := pnt.y - EightWayNeighbours[dir].y;
end;

procedure AStarBuildTrajectory(st_x,st_y,tg_x,tg_y: double; var Map: TAStarMap; var traj: TTrajectory);
var px, py, last_px, last_py: double;
    cur_pnt, st_pnt, tg_pnt: TGridCoord;
    done: boolean;
    pixx1, pixy1, ite_count: integer;
begin
  traj.count := 0;

  AStarWorldToGrid(st_x, st_y, st_pnt);
  AStarWorldToGrid(tg_x, tg_y, tg_pnt);

  cur_pnt := Map.TargetPoint;
  if GridCoordIsEqual(st_pnt, cur_pnt) then
    NextPnt(Map, cur_pnt);

  last_px := st_x;
  last_py := st_y;

  done := false;
  traj.distance := 0;
  ite_count := 0;
  while not done do begin
    if GridCoordIsEqual(tg_pnt, cur_pnt) then begin
      px := tg_x;
      py := tg_y;
      done := true;
    end else begin
      AStarGridToWorld(cur_pnt, px, py);
      if GridCoordIsEqual(Map.InitialPoint, cur_pnt) then begin
        done := true;
      end else begin
        NextPnt(Map, cur_pnt);
      end;
    end;

    // fail-safe to cover path not found cases
    Inc(ite_count);
    if ite_count >= 256 then begin
      break;
    end;

    if traj.count < MaxTrajectoryCount then begin
      with traj.pts[traj.count] do begin
        x := px;
        y := py;
        teta := 0;
        teta_power := 0;
      end;
      Inc(traj.count);
    end;
    traj.distance := traj.distance + Dist(px - last_px, py - last_py);
    last_px := px;
    last_py := py;
  end;
end;

procedure AStarGetBestPath(st_x,st_y,tg_x,tg_y: double; var traj: TTrajectory; var obs: array of TRoundObstacle; num_obs: integer);
var i, x, y: integer;
    ptl, pbr, cur_pnt: TGridCoord;
    wx,wy: double;
xmet,ymet:double;
obspnt: TGridCoord;
begin
  AStarClear(AStarMap);
// A* modificado 
 if direccao then AStarDrawCircleTarget(tg_x, tg_y, cd ,2,AStarMap.GridState);
 

  for i := 0 to num_obs - 1 do begin
// A* modificado   
    if  choque then begin
    if (meetingpoint (st_x,st_y,SpeedMax/2,obs[i].x,obs[i].y,obs[i].vx,obs[i].vy,xmet,ymet)) then begin
     AStarWorldToGrid(xmet, ymet, obspnt);
     if distancia then  obs[i].r:=rcalc(obs[i].r,dist(xmet-st_x,ymet-st_y));
     if rasto then AddAStarObstacleTrail(xmet, ymet, obs[i].r,obs[i].vx,obs[i].vy, AStarMap.GridState,AStarMap.GridFuzzy);

  
      AStarDrawCircle(xmet, ymet, obs[i].r, AStarMap.GridState);

      end
      end
    else begin
    if distancia then  obs[i].r:=rcalc(obs[i].r,dist(obs[i].x-st_x,obs[i].y-st_y));
        with obs[i] do begin
      AStarWorldToGrid(x - r, y - r, ptl);
      AStarWorldToGrid(x + r, y + r, pbr);
    end;
    for x := ptl.x to pbr.x do begin
      cur_pnt.x := x;
      for y := ptl.y to pbr.y do begin
        cur_pnt.y := y;
        AStarGridToWorld(cur_pnt, wx, wy);
        if Dist(wx - obs[i].x, wy - obs[i].y) < obs[i].r then begin
          AStarMap.GridState[cur_pnt.x,cur_pnt.y] := AStarObstacle;
        end;
      end;
    end;
    end;
  end;

    

 

  // use the target as starting point for the AStar. The advantages are:
  // - usually the place where the robot wants to go to is more crowded than the
  //      the place it is at. AStar works better when the target is the point with
  //      more space around it
  // - we need just a few steps of the trajectory to give to the controller. If we
  //      start at the "target" of the AStar we can do this easily without having
  //      to follow it all the way to the starting point
  AStarWorldToGrid(tg_x, tg_y, AStarMap.InitialPoint);
  AStarWorldToGrid(st_x, st_y, AStarMap.TargetPoint);

  AStarGo(AStarMap);
  AStarBuildTrajectory(st_x,st_y,tg_x,tg_y, AStarMap, traj);
end;

// -----------------------------------------------------------------------
//     Obstacle avoidance code

procedure SatFieldLimits(var x,y: double);
begin
  if x > MaxFieldX then x := MaxFieldX;
  if x < -MaxFieldX then x := -MaxFieldX;
  if y > MaxFieldY then y := MaxFieldY;
  if y < -MaxFieldY then y := -MaxFieldY;
end;

function inside_field(x,y: double): boolean;
begin
  result := (abs(x) < MaxFieldX) and (abs(y) < MaxFieldY);
end;

function CalcIntersectionPoint(x1,y1,x2,y2: double; var vx,vy: double ; obs: TRoundObstacle): boolean;
var p,q,ma,mb,a,b,c,k,delta: double;
begin
  p:=x2-x1;
  q:=y2-y1;

  ma:=x1-obs.x;
  mb:=y1-obs.y;

  a:=p*p+q*q;
  b:=2*ma*p+2*mb*q;
  c:=ma*ma+mb*mb-obs.r*obs.r;

  delta:=b*b-4*a*c;

  if delta<0 then begin
    result:=false;
    exit;
  end;

  delta:=sqrt(delta)/(2*a);

  k:=-b/(2*a);
  if (k-delta>1) or (k+delta<0) then begin
    result:=false;
    exit;
  end;
  k:=k-delta;

  vx:=x1+k*p;
  vy:=y1+k*q;

  result:=true;
end;

// create a "trajectory" with only one segment to tx,ty
procedure BuildSimpleTrajectory(var traj: TTrajectory; sx,sy,tx,ty: double);
begin
  traj.count := 1;
  traj.distance := Dist(tx-sx, ty-sy);
  with traj.pts[0] do begin
    x := tx;
    y := ty;
    teta := 0;
    teta_power := 0;
  end;
end;

// checks for obstacles in a segment
function ObstacleInSegment(st_x,st_y,tg_x,tg_y: double; var obs: array of TRoundObstacle; num_obs: integer): boolean;
var ix,iy: double;
    i: integer;
begin
  result := true;
  for i:=0 to Num_obs-1 do begin
    // if we are inside the obstacle, then we definitely intersect
    if (dist(st_x-obs[i].x,st_y-obs[i].y)<obs[i].r) then exit;
    if CalcIntersectionPoint(st_x,st_y,tg_x,tg_y,ix,iy,obs[i]) then exit;
  end;
  result := false;
end;


procedure GetBestPath(st_x,st_y,tg_x,tg_y: double; var traj: TTrajectory; var obs: array of TRoundObstacle; num_obs: integer);
var i: integer;
    pixx1,pixy1,pixx2,pixy2: integer;
begin
  // if there are no obstacles in this segment, just return a simple trajectory straight to it
  if not ObstacleInSegment(st_x,st_y,tg_x,tg_y,obs,num_obs) then begin
    BuildSimpleTrajectory(traj, st_x, st_y, tg_x, tg_y);
    exit;
  end;

  AStarGetBestPath(st_x, st_y, tg_x, tg_y, traj, obs, num_obs);
end;

function RobotBestPath(tg_x, tg_y:double; var traj: TTrajectory; var avoid: Tavoid): boolean;
var obs: array[0..MaxSpheres+5] of TRoundObstacle;
    i,nobs: integer;
    dball,r1: double;
    initial_tgx,initial_tgy,d1,d2,d: double;
    tmpx,tmpy: double;
    pixx1,pixx2,pixy1,pixy2: integer;
    found_path, target_inside: boolean;
    raio: double;
begin
  result := true;

  if Dist(RPoseSimTwo.x - tg_x, RPoseSimTwo.y - tg_y) < AStarGridCellSize/2 then begin
    BuildSimpleTrajectory(traj,RPoseSimTwo.x,RPoseSimTwo.y,tg_x,tg_y);
    exit;
  end;

  nobs := 0;
  raio:=2;

  SatFieldLimits(tg_x, tg_y);

    obs[nobs].x := avoid[0,0];
    obs[nobs].y := avoid[1,0];
    obs[nobs].r := raio*avoid[2,0];
    inc(nobs);
    obs[nobs].x := avoid[0,1];
    obs[nobs].y := avoid[1,1];
    obs[nobs].r := raio*avoid[2,1];
    inc(nobs);
    obs[nobs].x := avoid[0,2];
    obs[nobs].y := avoid[1,2];
    obs[nobs].r := raio*avoid[2,2];
    inc(nobs);
    obs[nobs].x := avoid[0,3];
    obs[nobs].y := avoid[1,3];
    obs[nobs].r := raio*avoid[2,3];
    inc(nobs);
    obs[nobs].x := avoid[0,4];
    obs[nobs].y := avoid[1,4];
    obs[nobs].r := raio*avoid[2,4];
    inc(nobs);
    obs[nobs].x := avoid[0,5];
    obs[nobs].y := avoid[1,5];
    obs[nobs].r := raio*avoid[2,5];
    inc(nobs);
    obs[nobs].x := avoid[0,6];
    obs[nobs].y := avoid[1,6];
    obs[nobs].r := raio*avoid[2,6];
    inc(nobs);
    obs[nobs].x := avoid[0,7];
    obs[nobs].y := avoid[1,7];
    obs[nobs].r := raio*avoid[2,7];
    inc(nobs);
    obs[nobs].x := avoid[0,8];
    obs[nobs].y := avoid[1,8];
    obs[nobs].r := raio*avoid[2,8];
    inc(nobs);
    obs[nobs].x := avoid[0,9];
    obs[nobs].y := avoid[1,9];
    obs[nobs].r := raio*avoid[2,9];
    inc(nobs);
    obs[nobs].x := avoid[0,10];
    obs[nobs].y := avoid[1,10];
    obs[nobs].r := raio*avoid[2,10];
    inc(nobs);
    obs[nobs].x := avoid[0,11];
    obs[nobs].y := avoid[1,11];
    obs[nobs].r := raio*avoid[2,11];
    inc(nobs);

  GetBestPath(RPoseSimTwo.x, RPoseSimTwo.y, tg_x, tg_y, traj, obs, nobs);

end;

procedure setInitialState;
var i,j: integer;
    x,y: Smallint;
    pnt: TGridCoord;
begin
  AStarClear(AStarMap);
  with AStarMap.InitialPoint do begin
    AStarWorldToGrid(-4,1.5,pnt);
    x:=pnt.x;
    y:=pnt.y;
  end;

  with AStarMap.TargetPoint do begin
    AStarWorldToGrid(4,1.5,pnt);
    x:=pnt.x;
    y:=pnt.y;
  end;
end;

procedure DrawAStarGrid4xPath(var Map: TAStarMap; Img: TImage);
var x, y, xm, ym, dir: integer;
begin
  Img.Canvas.Brush.Color:=clblue;
  with map do begin

    Profile.path_distance := 0;
    Profile.path_points := 0;

    xm:=TargetPoint.x;
    ym:=TargetPoint.y;

    while true do begin
      if (xm = InitialPoint.x) and (ym = InitialPoint.y) then break;
      x := xm * 4;
      y := ym * 4;
      Img.Canvas.FillRect(x, y, x+3, y+3);

      inc(Profile.path_points);

      with Grid[xm,ym] do begin
        Profile.path_distance := Profile.path_distance + sqrt(sqr(xm - ParentCoord.x) + sqr(ym - ParentCoord.y));
        xm:= ParentCoord.x;
        ym:= ParentCoord.y;
      end;
    end;
  end;
end;

procedure DrawAStarGrid4x(var Map: TAStarMap; Img: TImage);
var i,x,y, ix, iy: integer;
    mag: integer;
begin
  mag := 4;
  Img.Canvas.Brush.Color:=clblack;
  //Img.Canvas.FillRect(0, 0, Img.Width, Img.Height);

  //Img.Canvas.FillRect(Map.InitialPoint.x, MAp.InitialPoint.y, Img.Width, Img.Height);

  with map do begin
    for iy:=0 to AStarGridYSize-1 do begin
      y := mag * iy;
      for ix:=0 to AStarGridXSize-1 do begin
        x := mag *ix;
        case GridState[ix, iy] of
          AStarVirgin: begin //data:=whiteData;
            Img.Canvas.Brush.Color:=clwhite;
            Img.Canvas.FillRect(x, y, x+3, y+3);
          end;
          AStarObstacle: begin //data:=zerodata;
            Img.Canvas.Brush.Color:=clblack;
            Img.Canvas.FillRect(x, y, x+3, y+3);
          end;
          AStarClosed: begin // red
            Img.Canvas.Brush.Color:=clred;
            Img.Canvas.FillRect(x, y, x+3, y+3);
          end;
          AStarOpen: begin //green
            Img.Canvas.Brush.Color:=clgreen;
            Img.Canvas.FillRect(x, y, x+3, y+3);
          end;
        end;
      end;
    end;
  end;

  Img.Canvas.Brush.Color:=clyellow;
  //x:=Map.InitialPoint.x * mag;
  //y:=Map.InitialPoint.y * mag;
  Img.Canvas.FillRect(x, y, x+3, y+3);

  //x:=Map.TargetPoint.x * mag;
  //y:=Map.TargetPoint.y * mag;
  Img.Canvas.FillRect(x, y, x+3, y+3);

  Img.Repaint;
end;

initialization

AStarMap.EucliDistK := 1.3;
//A* modificado peso para as mudanças de direcção;

   
  Eightwaydinamic[0]:=0;
  Eightwaydinamic[1]:=d1;
  Eightwaydinamic[2]:=d2;
  Eightwaydinamic[3]:=d3;
  Eightwaydinamic[4]:=d4;
  Eightwaydinamic[5]:=d3;
  Eightwaydinamic[6]:=d2;
  Eightwaydinamic[7]:=d1;
RecalcSqrtCache(AStarMap);

end.

