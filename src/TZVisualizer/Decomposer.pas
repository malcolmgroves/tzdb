(*
* Copyright (c) 2010, Ciobanu Alexandru
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of this library nor the
*       names of its contributors may be used to endorse or promote products
*       derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*)

unit Decomposer;
interface
uses SysUtils, DateUtils, TimeSpan,
     Generics.Collections;

type
  TDecomposedPeriod = record
  private
    FStartsAt, FEndsAt: TDateTime;
    FType: TLocalTimeType;
    FAbbrv,
      FName: string;
    FBias: TTimeSpan;
  public
    property StartsAt: TDateTime read FStartsAt;
    property EndsAt: TDateTime read FEndsAt;
    property LocalType: TLocalTimeType read FType;
    property Abbreviation: string read FAbbrv;
    property DisplayName: string read FName;
    property Bias: TTimeSpan read FBias;
  end;

function Decompose(const ATimeZone: TTimeZone; const AYear: Word): TList<TDecomposedPeriod>;

implementation

function ProcessPeriod(
  const ATZ: TTimeZone;
  const AStart: TDateTime;
  out AEnd: TDateTime;
  out AType: TLocalTimeType;
  out AAbbr, ADisp: string;
  out ABias: TTimeSpan): Boolean;
var
  LYearOfStart: Word;
begin
  Result := false;
  LYearOfStart := YearOf(AStart);

  { Get the type of the local time in the starting time. Continue with the whole
    period that has the same type. }
  AType := ATZ.GetLocalTimeType(AStart);

  if (AType = lttStandard) or (AType = lttDaylight) then
  begin
    AAbbr := ATZ.GetAbbreviation(AStart);
    ADisp := ATZ.GetDisplayName(AStart);
    ABias := ATZ.GetUtcOffset(AStart);
  end;

  { --------------- Progress by hours }
  AEnd := AStart;
  while (ATZ.GetLocalTimeType(AEnd) = AType) and
        ((AType in [lttInvalid, lttAmbiguous]) or ((ATZ.GetDisplayName(AEnd) = ADisp) and
        (ATZ.GetUTCOffset(AEnd) = ABias))) do
  begin
    { Increase by an hour }
    AEnd := IncHour(AEnd, 1);

    { We reached the year's end }
    if YearOf(AEnd) <> LYearOfStart then
      break;
  end;

  { Remove the hour to be on the change spot }
  AEnd := IncHour(AEnd, -1);

  { ------------------- Progress by minutes }
  while (ATZ.GetLocalTimeType(AEnd) = AType) and
        ((AType in [lttInvalid, lttAmbiguous]) or ((ATZ.GetDisplayName(AEnd) = ADisp) and
        (ATZ.GetUTCOffset(AEnd) = ABias))) do
  begin
    { Increase by an hour }
    AEnd := IncMinute(AEnd, 1);

    { We reached the year's end }
    if YearOf(AEnd) <> LYearOfStart then
      break;
  end;

  { Remove the hour to be on the change spot }
  AEnd := IncMinute(AEnd, -1);

  { ------------------- Progress by second }
  while (ATZ.GetLocalTimeType(AEnd) = AType) and
        ((AType in [lttInvalid, lttAmbiguous]) or ((ATZ.GetDisplayName(AEnd) = ADisp) and
        (ATZ.GetUTCOffset(AEnd) = ABias))) do
  begin
    { Increase by an hour }
    AEnd := IncSecond(AEnd, 1);

    { We reached the year's end }
    if YearOf(AEnd) <> LYearOfStart then
    begin
      Result := true;
      break;
    end;
  end;

  { Remove the hour to be on the change spot }
  AEnd := IncSecond(AEnd, -1);
end;

function Decompose(const ATimeZone: TTimeZone; const AYear: Word): TList<TDecomposedPeriod>;
var
  LShoudStop: Boolean;
  LStart, LEnd: TDateTime;
  LType: TLocalTimeType;
  LAbbrv, LDispName: string;
  LBias: TTimeSpan;
  LRec: TDecomposedPeriod;
begin
  { Start the process from the beggining of the year }
  LStart := EncodeDateTime(AYear, MonthJanuary, 1, 0, 0, 0, 0);
  Result := TList<TDecomposedPeriod>.Create();

  LShoudStop := false;

  while (not LShoudStop) do
  begin
    LShoudStop := ProcessPeriod(ATimeZone, LStart, LEnd, LType, LAbbrv, LDispName, LBias);

    { Create a decomposed period }
    LRec.FStartsAt := LStart;
    LRec.FEndsAt := LEnd;
    LRec.FType := LType;
    LRec.FAbbrv := LAbbrv;
    LRec.FName := LDispName;
    LRec.FBias := LBias;

    { Push the period }
    Result.Add(LRec);

    { Adjust the start to the new end }
    LStart := IncSecond(LEnd, 1);
  end;
end;

end.
