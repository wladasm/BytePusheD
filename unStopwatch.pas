unit unStopwatch;

interface

type
  TStopwatch = class(TObject)
  private
    FStartTime: Int64;
    FElapsed: Int64;
    FIsRunning: Boolean;
    class function GetFrequency: Int64; static;
    class function GetTimestamp: Int64; static;
  public
    constructor Create;
    procedure Start;
    procedure Stop;
    procedure Reset;
    procedure Restart;
    function ElapsedMilliseconds: Int64;
    function ElapsedTicks: Int64;
    class function StartNew: TStopwatch; static;
  public
    property IsRunning: Boolean read FIsRunning;
    class property Frequency: Int64 read GetFrequency;
  end;

implementation

uses
  Windows;

var
  VFrequency: Int64;

class function TStopwatch.GetFrequency: Int64;
begin
  Result := VFrequency;
end;

class function TStopwatch.GetTimestamp: Int64;
begin
  QueryPerformanceCounter(Result);
end;

constructor TStopwatch.Create;
begin
  FStartTime := 0;
  FElapsed := 0;
  FIsRunning := False;
end;

procedure TStopwatch.Start;
begin
  if not FIsRunning then
  begin
    FIsRunning := True;
    FStartTime := GetTimestamp;
  end;
end;

procedure TStopwatch.Stop;
begin
  if FIsRunning then
  begin
    Inc(FElapsed, GetTimestamp - FStartTime);
    FIsRunning := False;
  end;
end;

procedure TStopwatch.Reset;
begin
  FElapsed := 0;
  FIsRunning := False;
end;

procedure TStopwatch.Restart;
begin
  FElapsed := 0;
  FIsRunning := True;
  FStartTime := GetTimestamp;
end;

function TStopwatch.ElapsedMilliseconds: Int64;
begin
  if FIsRunning then
    Result := (FElapsed + (GetTimestamp - FStartTime)) * 1000 div Frequency
  else
    Result := FElapsed * 1000 div Frequency;
end;

function TStopwatch.ElapsedTicks: Int64;
begin
  if FIsRunning then
    Result := FElapsed + (GetTimestamp - FStartTime)
  else
    Result := FElapsed;
end;

class function TStopwatch.StartNew: TStopwatch;
begin
  Result := TStopwatch.Create;
  Result.Start;
end;

initialization
  QueryPerformanceFrequency(VFrequency);

end.

