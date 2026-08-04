-- SAFETY CAR - FULL COURSE YELLOW - YELLOW FLAG IN SECTORS - ROLLING START
-- BASIC VERSION
-- by Nary
-- Patreon : patreon.com/AssettoCorsaRacingCarsMods

local firstTime = true
local firstTimeQuali = true
local aiDriverCount = 0
local YELLOW_FLAG = false
local FCY = false
local FCY_time_elapsed = 0
local tpos = {}
local topspeed = {}
local YELLOW_FLAG_sector = 0
local last_time = 0
local decision = 0
local cautionDuration = 0
local FORMATION_LAP = false
local YELLOW_FLAG_time_start
local startOrder = {}
local do_PERSONAL=false
local do_FORMATION_LAP=true
local do_YELLOW_FLAG=true
local do_FCY=true
local do_SAFETYCAR=true
local do_VSC=false
local do_DISABLE_FIRST_LAP=false
local do_RADIO_MESSAGE=true
local do_SHOW_PIT_TIMES=true
local do_SC_FORMATION_LAP=true   -- SC leads the formation lap from its auto-computed spawn
local do_PENALTIES=true
local do_BTN_SC_CAUTION=true
local do_DRS=false
local do_RECORD_DEBUG=true
local ASSIGNED_POS=true   -- spawn is always computed automatically from the grid now
local spawnPos
local spawnDir
local safetycar
local SAFETY_CAR_OUT=false
local SAFETY_CAR_INITIALIZED=false
local safetycar_pos
local pdiff_sc=0
local SC_IN_THIS_LAP=false
local SAFETY_CAR_IN
local sc_now=0
local sc_ts=0
local start_time_elapsed=0
local cars_fault = {}
local index_cf=0
local safetycar_name="Aston Martin Vantage safety car 2021"
local cbox = {}
local climit = {}
local ib=1
local vcaution=""
local trouve=false
local log_lines = {}
local index_log=1
local P_FORMATION_SPEED=110   -- formation pace: brisk but controlled
local P_DURATION_MIN_YELLOW=60
local P_DURATION_MAX_YELLOW=180
local P_DURATION_MIN_FCY=60
local P_DURATION_MAX_FCY=180
local P_MAX_SPEED_FCY=80
local P_DURATION_MIN_SC=60
local P_DURATION_MAX_SC=180
local P_MAX_SPEED_SC=80
local race_log = {}
local i_log=0
local FORMATION_BEHIND_CATCH=false
local SHOW_DEBUG=false
local LAP_LAST_PIT = {}
local do_REFUELONTHEFLY=true
local NBR_PITS = {}
local SC_TURN_LIGHTS_OFF=false
local P_SC_MIN_LAPS=1
local P_SC_MAX_LAPS=2
local player
local RADIO_MSG_ON=false
local aRadio=false
local wasinpit = {}
local pitentrytime = {}
local pitexittime = {}
local pitstopdone = {}
local timeinpit = {}
local lasttimeinpit = {}
local PitTimeShowed = {}
local testilap=0
local i_turn=0
local ShDuration=0
local SC_GHOST
local CALL_SC_FORMATION=false
local SC_STOP_ORDERED=false
local firstTimeFORMATION=false
local carBeforePlayer
local WARNING_RETURN_TO_YOUR_POS=false
local timeUNREGULAR=0
local PenaltyFORMATION=false
local PenaltyCAUTION=false
local PlayerOldSector=-1
local YELLOWCarBeforeDefined=false
local YELLOWLead2FCY=true
local PlayerKMDone
local TimeRaceElapsed
local isDRSAllowed=false
local oldState_isDRSAllowed=true
local uu=1
local tdbg_elapsed=0

-- ===== ApexCoach additions: natural formation weaving & chain following =====
local safetycar_id="bg_mercedes_amg_gt_black_series"  -- Mercedes-AMG GT BS F1 safety car
local WEAVE_T0=nil          -- formation weave clock
local FORMUP=false          -- final phase of formation lap: weaving over, pack up
local FORM_KM0=nil          -- leader's odometer when the formation lap began
local SESSION_HAS_RUN=false -- lets us detect a session restart and re-init
local CAUTION_SET=false     -- AI following-distance raised for the formation lap
local sc_duplicates={}      -- extra copies of the safety car found on the grid
local sc_dupe_seen_inactive={} -- clone deactivation confirmed (re-activation detector)
local WEAVE_ALLOWED=false   -- no tire warming until the whole field is spaced out
local WEAVE_T1=nil          -- moment the field formed (heavy weave staggering)
local TUNE = ac.storage{    -- Tuning tab values, persisted by CSP across sessions
  weaveWidth = 1.0,         -- scale on the tire-warming sweep amplitude
  weaveRhythm = 1.0,        -- scale on the sweep cycle time (higher = lazier)
  cushionMin = 0.7,         -- personal cushion to the car ahead, seconds
  cushionMax = 1.3,
  catchHurryGap = 2.0,      -- gap (s) beyond which a driver hurries to close up
  catchFlatGap = 5.0,       -- gap (s) beyond which all rules drop: flat out
  catchHurrySpeed = 40,     -- km/h over the car ahead while hurrying
}

-- ==== ApexCoach diagnostic race log ====
-- One file per game launch, all sessions appended:
--   apps\lua\fcy_yellow_rollingstart\apexcoach_race_log.txt
-- Logs session setup, every state-machine transition, clone removals,
-- headlight commands and flash triggers, so problems can be diagnosed
-- from the file after a race instead of guessing.
local RLOG_PATH = ac.getFolder(tostring(ac.FolderID.ACAppsLua)) .. "\\fcy_yellow_rollingstart\\apexcoach_race_log.txt"
local rlog_lines = 0
local rlog_t0 = os.preciseClock()
do
  -- fresh file each game launch (sessions within one launch all append)
  local f = io.open(RLOG_PATH, "w")
  if f ~= nil then
    f:write("ApexCoach diagnostic log - app loaded " .. os.date() .. "\n")
    f:close()
  end
end
function RLog(msg)
  if rlog_lines >= 4000 then return end
  rlog_lines = rlog_lines + 1
  local f = io.open(RLOG_PATH, "a")
  if f ~= nil then
    f:write(string.format("[%9.2f] %s\n", os.preciseClock()-rlog_t0, msg))
    if rlog_lines == 4000 then
      f:write("[LOG LINE LIMIT REACHED - further entries dropped]\n")
    end
    f:close()
  end
end

function RLogHeader(tag)
  RLog("===== " .. tag .. " - " .. os.date() .. " =====")
  RLog("track: " .. ac.getTrackID() .. " / " .. tostring(ac.getTrackLayout()))
  RLog("cars: " .. ac.getSim().carsCount
       .. "  sessionType: " .. tostring(ac.getSim().raceSessionType)
       .. "  sessionStarted: " .. tostring(ac.getSim().isSessionStarted))
  RLog("api: worldCoordinateToTrack=" .. tostring(ac.worldCoordinateToTrack ~= nil)
       .. " getTrackUpcomingTurn=" .. tostring(ac.getTrackUpcomingTurn ~= nil))
  RLog("safetycar index=" .. tostring(safetycar)
       .. "  ASSIGNED_POS=" .. tostring(ASSIGNED_POS)
       .. "  do_SC_FORMATION_LAP=" .. tostring(do_SC_FORMATION_LAP))
  for i=0, aiDriverCount, 1 do
    local car = ac.getCar(i)
    RLog(string.format("car %d: id=%s pos=%d%s%s%s",
      i, tostring(ac.getCarID(i)), car.racePosition,
      i==0 and " [PLAYER]" or "",
      i==safetycar and " [SAFETY CAR]" or "",
      sc_duplicates[i]~=nil and " [CLONE-REMOVED]" or ""))
  end
end

-- transition watcher: one place that logs every state flip
local watch_prev={}
function RLogStateWatch()
  local states={
    FORMATION_LAP=FORMATION_LAP, FORMUP=FORMUP,
    WEAVE_ALLOWED=WEAVE_ALLOWED, FCY=FCY, YELLOW_FLAG=YELLOW_FLAG,
    SC_INITIALIZED=SAFETY_CAR_INITIALIZED, SC_OUT=SAFETY_CAR_OUT,
    SESSION_STARTED=ac.getSim().isSessionStarted,
  }
  for k,v in pairs(states) do
    if watch_prev[k] ~= v then
      if watch_prev[k] ~= nil then
        RLog("state " .. k .. " -> " .. tostring(v))
      end
      watch_prev[k] = v
    end
  end
  -- per-car lifecycle: catches WHO retired/pitted WHEN, with the state
  -- they were in - the game silently retires AI that sit still too long,
  -- and without this there is no trace of it anywhere
  for i=1, aiDriverCount, 1 do
    local car = ac.getCar(i)
    local st = "ON_TRACK"
    if car.isRetired == true then st = "RETIRED"
    elseif car.isInPit == true then st = "IN_PIT"
    elseif car.isInPitlane == true then st = "PITLANE" end
    local key = "CAR" .. i
    if watch_prev[key] ~= st then
      if watch_prev[key] ~= nil and sc_duplicates[i] == nil then
        RLog(string.format("car %d: %s -> %s (pos %d, %.0f km/h, lap %d)",
          i, watch_prev[key], st, car.racePosition, car.speedKmh, car.lapCount))
      end
      watch_prev[key] = st
    end
  end
end

-- first car in the running order that is not the safety car
function LeadRaceCar()
  local c = ReturnCarInPos(1)
  if c ~= nil and c == safetycar then
    c = ReturnCarInPos(2)
  end
  return c
end

-- the field order the moment the formation lap begins (index 1 = leader,
-- safety car included). This is the order everyone must hold.
local startSeq={}

function BuildStartSeq()
  startSeq={}
  WEAVE_ALLOWED=false
  for j=1, ac.getSim().carsCount, 1 do
    local c=ReturnCarInPos(j)
    if c~=nil and sc_duplicates[c]==nil then
      startSeq[#startSeq+1]=c
      startOrder[c]=#startSeq
    end
  end
  -- baseline for the form-up trigger: distance must be measured from THIS
  -- formation start, because the session odometer survives restarts
  local lc = LeadRaceCar()
  if lc ~= nil then
    FORM_KM0 = ac.getCar(lc).distanceDrivenSessionKm
  end
end

function CarRunning(c)
  local car=ac.getCar(c)
  return car.isRetired==false and car.isInPit==false
         and car.isInPitlane==false
end

function RemoveDuplicateSafetyCars()
  -- if the SC car model was also added as a normal opponent, keep the one
  -- acting as safety car and quietly retire the clones: teleport to pits
  -- FIRST (a stopped car on track would trigger the caution logic), then
  -- park and deactivate them. Re-asserted on every call, not one-shot:
  -- AC re-places and re-activates grid cars while a session (re)start is
  -- forming up, sometimes frames AFTER the first removal already ran -
  -- a clone that pops back is pushed straight back out
  for i=1, aiDriverCount, 1 do
    if i ~= safetycar
       and (ac.getCarName(i,false)==safetycar_name
            or ac.getCarID(i)==safetycar_id) then
      if sc_duplicates[i]==nil then
        -- flag FIRST: from this moment SetLeaderBoardArray ranks the clone
        -- absolute last and re-indexes the real field contiguously, so the
        -- order is already clean before the car is even off the grid
        sc_duplicates[i]=true
        ac.log("Removed duplicate safety car on index " .. i)
        RLog("CLONE flagged: car " .. i .. " (duplicate safety car) - removing")
      end
      -- only act while the car is actually live: a deactivated car's
      -- state is frozen, and re-teleporting it every frame does nothing
      -- but spam the physics thread
      if ac.getCar(i).isActive == true then
        if sc_dupe_seen_inactive[i] == true then
          RLog("CLONE " .. i .. " re-activated by AC - removing again")
        end
        sc_dupe_seen_inactive[i] = nil
        if ac.getCar(i).isInPit == false then
          physics.teleportCarTo(i, ac.SpawnSet.Pits)
        end
        physics.setGentleStop(i, true)
        ac.setCarActive(i, false)
      else
        sc_dupe_seen_inactive[i] = true
      end
    end
  end
end

-- deterministic per-driver randomness: same driver always gets the same
-- rhythm this session, but every driver differs (unique but similar paths)
function DriverHash(i, salt)
  local v = math.sin(i * 127.1 + salt * 311.7) * 43758.5453
  return v - math.floor(v)
end

-- every lateral command goes through this first-order smoother, so the
-- steering target can never step - it always eases over ~0.3 s. Kills the
-- twitch when gating conditions flip from frame to frame. (Open-loop
-- filtering only: unlike a position feedback loop, this cannot oscillate.)
local off_smooth={}
function SmoothOffset(i, target, rate)
  local blend = (rate or 3.5) * ui.deltaTime()
  if blend > 1 then blend = 1 end
  local out = (off_smooth[i] or 0) + (target - (off_smooth[i] or 0)) * blend
  if math.abs(out) < 0.002 then out = 0 end
  off_smooth[i] = out
  physics.setAISplineOffset(i, out, true)
end

-- mid-track weave envelope: instead of weaving strictly around the racing
-- line, each driver slowly shifts the CENTER of their weave toward their
-- own preferred spot near the middle of the track (track-limit based), so
-- the warm-up uses the whole road. This is NOT a steering feedback loop
-- (that spun cars in the past): the correction only moves the weave
-- envelope, changes through a slow 2 s filter, and the actual steering
-- still goes through SmoothOffset. Falls back to the plain racing line if
-- track coordinates are unavailable or look invalid.
local bias_smooth={}
local weave_gain={}   -- per-car 0..1 fade of the heavy sweep
function UpdateMidTrackBias(i, apply, amp, ahead, gap_ahead)
  local cur = bias_smooth[i] or 0
  local target = 0
  local rate = 0.3
  if apply == true and ac.worldCoordinateToTrack ~= nil then
    local tc = ac.worldCoordinateToTrack(ac.getCar(i).position)
    if tc ~= nil and tc.x == tc.x and math.abs(tc.x) <= 1.2 then
      -- where the racing line sits across the road right now: measured
      -- position (0 = middle, +-1 = edges) minus the offset currently
      -- being commanded (same normalization, same left/right sign)
      local lineX = tc.x - (off_smooth[i] or 0)
      -- own preferred spot: anywhere within +-40% of the road, unique per
      -- driver - spread out and random rather than everyone at center
      local prefer = (DriverHash(i,9) - 0.5) * 0.8
      -- genuinely close behind someone (inside the normal 0.7-1.3 s
      -- cushion): prefer the emptier side of the road so the full sweep
      -- carries on safely instead of pausing behind them. Judged against
      -- the ahead car's envelope CENTER (its line + slow bias), never its
      -- momentary position - the ahead car is weaving too, and chasing
      -- its oscillation made followers swing all over the road
      if ahead ~= nil and gap_ahead ~= nil and gap_ahead < 0.55 then
        local ta = ac.worldCoordinateToTrack(ac.getCar(ahead).position)
        if ta ~= nil and ta.x == ta.x and math.abs(ta.x) <= 1.2 then
          local center_ahead = ta.x - (off_smooth[ahead] or 0)
                               + (bias_smooth[ahead] or 0)
          if center_ahead > 0 then prefer = -0.45 else prefer = 0.45 end
          rate = 0.45           -- move over with a little more intent
        end
      end
      -- weak pull (40%): the envelope leans toward that spot without
      -- obviously abandoning the racing line
      target = (prefer - lineX) * 0.4
      if target > 0.45 then target = 0.45 end
      if target < -0.45 then target = -0.45 end
      -- track limits: nudge the envelope center inward when the line runs
      -- so close to an edge that a full sweep would clip it. Soft version
      -- only - CSP itself hard-clamps offsets to the track width, so this
      -- just avoids visibly flattened arcs, without herding everyone to
      -- the middle of the road
      if amp ~= nil then
        local room = 1.0 - amp*0.7
        if lineX + target > room then target = room - lineX end
        if lineX + target < -room then target = -room - lineX end
      end
    end
  end
  local blend = rate * ui.deltaTime()
  if blend > 1 then blend = 1 end
  bias_smooth[i] = cur + (target - cur) * blend
  return bias_smooth[i]
end

-- corner / braking-zone gate: no tire-warming where a swerve could end in
-- runoff, a spin or a big correction to get back on line. Trips when a
-- tight turn is coming up within ~3 s, when the car is actually braking,
-- or when it is already loaded up sideways mid-corner. Purely
-- predictive/reactive reads - no steering feedback.
function WeaveUnsafeHere(i)
  local c = ac.getCar(i)
  -- thresholds sit above what the AI's own speed-control brake dabs and
  -- the weave itself produce, so the gate only trips on real corners -
  -- a flickering gate is what makes steering look twitchy
  if c.brake > 0.30 then return true end
  if math.abs(c.acceleration.x) > 0.75 then return true end
  if ac.getTrackUpcomingTurn ~= nil then
    local turn = ac.getTrackUpcomingTurn(i)
    if turn ~= nil and turn.x >= 0 then
      local lookm = c.speedKmh/3.6 * 3.0 + 20
      if turn.x < lookm and math.abs(turn.y) > 30 then return true end
    end
  end
  return false
end

-- ===== end additions header =====

-- Runs once per frame
---@diagnostic disable-next-line: duplicate-set-field
function script.update(dt)
end


-- Runs once per frame on the Main window
---@diagnostic disable-next-line: duplicate-set-field
function script.windowMain(dt)
  if ac.getSim().isOnlineRace == false then
    if ac.getSim().raceSessionType ~= ac.SessionType.Race and ac.getSim().raceSessionType ~= ac.SessionType.Qualify  then
      ui.text("Not in a race or qualifying session, app will be inactive.")
      return
    end
    if ac.getPatchVersionCode() < 2651 then
      ui.text("CSP version is too low, upgrade to at least v0.2.0")
      return
    end
    if physics.allowed() == false then
      -- Enable Track Physics Button
      if ui.button("Enable Track Physics") then
        EnablePhysics()
        ui.toast(ui.Icons.Code, "Track Physics Enabled, restart from C.M to apply.")
      end
    else

      --OK

      ui.tabBar('MainBar',function()
        ui.tabItem('Live', function()
          if ac.getSim().raceSessionType == ac.SessionType.Race then
            AppMain()
          end
          if ac.getSim().raceSessionType == ac.SessionType.Qualify then
            AppMainQualify()
          end
        end)
    
        --ui.tabItem('SC', function()
            --SCSettings()
        --end)

        --ui.tabItem('Settings', function()
          --AppSettings()
        --end)

        ui.tabItem('Tuning', function()
          FormationTuningTab()
        end)

        --ui.tabItem('Debug', function()
          --ShowNBRPIT()
        --end)
      end)

      -- OK end
    end
  else
    ui.text("App inactive on online sessions.")
  end
end


-- FUNCTIONS


function AppMain()
  if firstTime == true then

    aiDriverCount = ac.getSim().carsCount - 1

    FindSafetyCar()
    RemoveDuplicateSafetyCars()

    LoadSettings()

    -- spawn point is computed automatically from the grid - no per-track
    -- setup, no spawn .ini files
    ComputeAutoSpawn()

    if ac.getSim().isSessionStarted == false then
      if do_SC_FORMATION_LAP==false or (do_SC_FORMATION_LAP==true and ASSIGNED_POS==false) then
        for j=1, ac.getSim().carsCount, 1 do
            startOrder[ReturnCarInPos(j)]=j
        end
      else
        if do_SC_FORMATION_LAP==true and ASSIGNED_POS==true then
          for j=1, ac.getSim().carsCount, 1 do
            startOrder[ReturnCarInPos(j)]=j+1
          end
          --ac.log("OKAY I AM HERE")
        end
      end
    end

    PlaceSafetyCarOnRaceStart()

    if do_PERSONAL==true then
      NuzziAICopyPlayerFuel()
    end
    PitVarsInit()
    InitPitTimer()

    RLogHeader("SESSION INIT (race)")
    firstTime = false

    for i=0, aiDriverCount, 1 do
      lasttimeinpit[i]=0
    end

    --end if firstTime
  end

  if ac.getSim().isSessionStarted == false then
    DrawRed()
    PlayerKMDone=0
    TimeRaceElapsed=0
    --ShowFormationInfo()
    if SESSION_HAS_RUN==true then
      -- session was restarted: full re-init so the SC is re-placed on its
      -- assigned spawn and every state machine starts clean
      RLog("SESSION RESTART detected - full re-init")
      SESSION_HAS_RUN=false
      firstTime=true
      firstTimeFORMATION=false
      FORMATION_LAP=false
      SAFETY_CAR_INITIALIZED=false
      SAFETY_CAR_OUT=false
      FCY=false
      YELLOW_FLAG=false
      YELLOW_FLAG_sector=0
      index_cf=0
      cars_fault={}
      CALL_SC_FORMATION=false
      SC_STOP_ORDERED=false
      PenaltyFORMATION=false
      PenaltyCAUTION=false
      FORMUP=false
      FORM_KM0=nil
      WEAVE_T0=nil
      CAUTION_SET=false
      startSeq={}
      sc_duplicates={}
      sc_dupe_seen_inactive={}
      WEAVE_ALLOWED=false
      WEAVE_T1=nil
      off_smooth={}
      bias_smooth={}
      weave_gain={}
      -- clear any leftover AI state from the previous session
      for i=1, aiDriverCount, 1 do
        physics.setAITopSpeed(i, 1e9)
        physics.setAISplineOffset(i, 0, false)
        physics.setAIThrottleLimit(i, 1)
        physics.setAICaution(i, 1)
      end
    end
  else
    SESSION_HAS_RUN=true
  end

  -- keep enforcing clone removal while the grid can still change (AC can
  -- re-activate deactivated cars while a session (re)start re-forms it)
  if ac.getSim().isSessionStarted==false or FORMATION_LAP==true then
    RemoveDuplicateSafetyCars()
    -- the game auto-retires AI that sit still too long, and the grid
    -- launch / bunch-up phase is full of slow or momentarily stopped
    -- cars. The prevention is time-limited by design, so it must be
    -- re-called every frame for as long as the formation phase lasts
    for i=1, aiDriverCount, 1 do
      if i ~= safetycar and sc_duplicates[i]==nil then
        physics.preventAIFromRetiring(i)
      end
    end
  end
  -- diagnostic log: state transitions
  RLogStateWatch()

  if do_FORMATION_LAP == true then
    if ac.getSim().isSessionStarted == true then

      if firstTimeFORMATION==false then
        carBeforePlayer=ReturnCarInPos(ac.getCar(0).racePosition-1)
        firstTimeFORMATION=true
      end

      --ac.debug("carBeforePlayer",carBeforePlayer)

      if ac.getCar(LeadRaceCar()).lapCount == 0 then
        if FORMATION_LAP ~= true then
          FORMATION_LAP = true
          -- lock in the REAL field order now, with the safety car already
          -- physically at the front - grid-slot snapshots taken before the
          -- SC teleport made cars think they had stolen a position, and
          -- they would crawl forever trying to hand it back (huge gaps)
          BuildStartSeq()
        end
      end
      if ac.getCar(LeadRaceCar()).lapCount == 1 then
        if FORMATION_LAP == true then
          DrawGreen()
          FORMATION_LAP = false
          ui.toast(ui.Icons.Code, "RACE STARTED - GO GO GO !")
          if PenaltyFORMATION==false then
            RadioMessage("green.mp3")
          end
          for i=1, aiDriverCount, 1 do
            physics.setAITopSpeed(i, 1e9)
            physics.setAISplineOffset(i, 0, false)   -- weaving over, race on
            if i ~= safetycar then
              physics.setAICaution(i, 1)             -- normal racing distance
              physics.setAIThrottleLimit(i, 1)       -- full power back
            end
          end
          off_smooth={}
          bias_smooth={}
          weave_gain={}
          RLog("GREEN FLAG - formation lap over, race on")
          if safetycar ~= 0 then
            -- guard: with no SC on the grid, index 0 is the PLAYER
            physics.setAITopSpeed(safetycar, 70)
          end
          if PenaltyFORMATION==true and do_PENALTIES==true then
            physics.setCarPenalty(ac.PenaltyType.MandatoryPits, 3)
            timeUNREGULAR=0
            RadioMessage("drive_thru.mp3")
          end
        end
      end
    end

    if FORMATION_LAP == true then
      DrawYellow("FORMATION LAP")
      SlowDownAndRegroupFormation()
      PositionCoach()
      --ShowFormationInfo()
      if do_SC_FORMATION_LAP==true and ASSIGNED_POS==true then
        if CALL_SC_FORMATION==false then
          physics.setAIPitStopRequest(safetycar,true)
          CALL_SC_FORMATION=true
        end
      end
    end
  else
    FORMATION_LAP=false
  end

  if FORMATION_LAP==false then
    -- formation over (green flag) or not running: coach back to idle
    CoachReset()
  end

  --ac.debug("PlayerKMDone",PlayerKMDone)

  if ac.getSim().isSessionStarted == true and FORMATION_LAP == false and TimeRaceElapsed>30 then
    if do_DISABLE_FIRST_LAP==true and ac.getCar(ReturnCarInPos(1)).lapCount==0 then
      no_caution=true
    else
      no_caution=false
    end
    for i=1, aiDriverCount, 1 do
      if ac.getCar(i).speedKmh<1 and ac.getCar(i).isInPit == false and i ~= safetycar and sc_duplicates[i]==nil and SAFETY_CAR_INITIALIZED ==  false and no_caution==false then

        trouve=false
        for k=0, index_cf-1, 1 do
          if i==cars_fault[k] then
            trouve=true
          end
        end

        if FCY == false and YELLOW_FLAG == false and trouve == false then

          cars_fault[index_cf]=i
          index_cf=index_cf+1

          ib=1
          vlimit=0
          if do_FCY==true then
            cbox[ib]="FCY"
            vlimit=vlimit+50
            climit[ib]=vlimit
            ib=ib+1
          end
          if do_YELLOW_FLAG==true then
            cbox[ib]="YELLOW"
            vlimit=vlimit+50
            climit[ib]=vlimit
            ib=ib+1
          end
          if do_SAFETYCAR==true then
            cbox[ib]="SC"
            vlimit=vlimit+50
            climit[ib]=vlimit
            ib=ib+1
          end
          math.randomseed(math.floor(os.preciseClock()))
          decision=math.random(vlimit)
          min_limit=0
          taken=false
          vcaution="DECISION WAITING ..."
          for jb=1, ib-1, 1 do
            if decision>=min_limit and decision<climit[jb] and taken==false then
              vcaution=cbox[jb]
              taken=trouve
            end
            min_limit=min_limit+50
          end
          if vcaution=="FCY" then
            InitFCY()
          end
          if vcaution=="YELLOW" then
            YELLOW_FLAG=true
            YELLOW_FLAG_time_start = os.preciseClock()
            YELLOW_FLAG_sector=ac.getCar(i).currentSector
            FCY=false
            math.randomseed(math.floor(os.preciseClock()))
            cautionDuration=math.random(P_DURATION_MIN_YELLOW,P_DURATION_MAX_YELLOW)
            RadioMessage("yellow.mp3")
          end
          if vcaution=="SC" then
            InitSC()
            math.randomseed(math.floor(os.preciseClock()))
            cautionDuration=math.random(P_DURATION_MIN_SC,P_DURATION_MAX_SC)
          end
        end
        if FCY == false and YELLOW_FLAG == true and do_FCY==true then
          if ac.getCar(i).currentSector ~= YELLOW_FLAG_sector then
            InitFCY()
          end
        end
        if FCY==true and do_SAFETYCAR==true then
          FCY=false
          YELLOW_FLAG=false
          YELLOW_FLAG_sector=0
          InitSC()
        end
      end
    end
  end

  if do_PERSONAL==true then
    if ac.isKeyDown(ui.KeyIndex.Space) then
      --FORMATION_BEHIND_CATCH=true
      --ui.toast(ui.Icons.Code, "FORMATION BEHIND CATCHING ON")
      --MakeThemSlow()
    end
    if ac.isKeyDown(ui.KeyIndex.Insert) then
      --FORMATION_BEHIND_CATCH=false
      --ui.toast(ui.Icons.Code, "FORMATION BEHIND CATCHING OFF")
      --ReleaseThem()
    end
    if ac.isKeyDown(ui.KeyIndex.End) then
      SHOW_DEBUG=not SHOW_DEBUG
    end
    if ac.isKeyDown(ui.KeyIndex.Delete) then
      --RaceLogSave()
    end
    if ac.isKeyPressed(ui.KeyIndex.Return) then
      --EverybodyPits()
      --InitSC()
      --InitFCY()
      --InitYELLOW()
    end
  end

  ShDuration=ShDuration+ui.deltaTime()
  if ShDuration>100 then
    ShDuration=100
  end
  --ac.debug("i_turn",i_turn)
  if ac.isKeyDown(ui.KeyIndex.Divide) then
    --ac.log("Key is pressed")
    ShowTimeInPit()
  end

  if SAFETY_CAR_INITIALIZED==true then
    tdbg_elapsed=tdbg_elapsed+ui.deltaTime()
    if tdbg_elapsed>1000 then
        tdbg_elapsed=1000
    end
    if ac.getCar(ReturnCarInPos(1)).splinePosition>(safetycar_pos-0.03) and ac.getCar(ReturnCarInPos(1)).splinePosition<=safetycar_pos and SAFETY_CAR_OUT==false then
      ac.setCarActive(safetycar, true)
      physics.setCarPosition(safetycar, spawnPos, spawnDir)
      SAFETY_CAR_OUT=true
      math.randomseed(math.floor(os.preciseClock()))
      cautionDuration=math.random(P_DURATION_MIN_SC,P_DURATION_MAX_SC)
      start_time_elapsed=os.preciseClock()
      SAFETY_CAR_IN=false
      SC_IN_THIS_LAP=false
      sc_pit_request=false
      sc_inactive=false
      SC_GHOST=false
    else
      SlowDownAndRegroup(false)
    end

    if SAFETY_CAR_OUT == true then
      SlowDownAndRegroupSafetyCar()
    end
  end

  if YELLOW_FLAG == true then
    SlowDownAndRegroup(true)
  end

  if FCY==true and do_PERSONAL==true then
    SlowDownAndRegroup(false)
  else
    if FCY==true and do_PERSONAL==false then
      SlowDown()
    end
  end

  if YELLOW_FLAG == true or FCY == true or SAFETY_CAR_INITIALIZED==true then
    if ac.getCar(0).currentSector == YELLOW_FLAG_sector and YELLOW_FLAG == true then
      DrawYellow("YELLOW FLAG IN SECTOR " .. YELLOW_FLAG_sector+1)
      aRadio=false

      if YELLOWCarBeforeDefined==false then
        GetCarBeforeStartCaution()
        YELLOWCarBeforeDefined=true
      end
      CheckPlayerPosCaution()
      ShowPenaltyThreat()
    end

    if ac.getCar(0).currentSector ~= YELLOW_FLAG_sector and YELLOW_FLAG == true then
      DrawYellowGreen("YELLOW FLAG IN SECTOR " .. YELLOW_FLAG_sector+1)
      if aRadio==false then
        RadioMessage("green.mp3")
        aRadio=true
      end
      YELLOWCarBeforeDefined=false
    end

    if FCY==true then
      DrawFCY()
    end

    if SAFETY_CAR_INITIALIZED==true then
      DrawSC()
    end

    --ShowCautionInfo()
       
    now_time_elapsed = os.preciseClock()
    if YELLOW_FLAG == true then
      start_time_elapsed=YELLOW_FLAG_time_start
    end
    if FCY == true then
      start_time_elapsed=FCY_time_elapsed
    end
    if now_time_elapsed-start_time_elapsed>(cautionDuration-10) and FCY == true then
      ui.toast(ui.Icons.Code, "GET READY TO RESUME THE RACE")
      if aRadio==false then
        RadioMessage("get_ready_restart.mp3")
        aRadio=true
      end
    end
    if now_time_elapsed-start_time_elapsed>cautionDuration then
      if FCY == true then
        ResumeRace()
        aRadio=false
        if PenaltyCAUTION==true and do_PENALTIES==true then
          physics.setCarPenalty(ac.PenaltyType.MandatoryPits, 3)
          timeUNREGULAR=0
          PenaltyCAUTION=false
          RadioMessage("drive_thru.mp3")
        end
      end

      if YELLOW_FLAG == true then
        decision=math.random(100)
        if decision<=50 and do_FCY==true and YELLOWLead2FCY==true then
          InitFCY()
        else
          aRadio=false
          ResumeRace()
          if PenaltyCAUTION==true and do_PENALTIES==true then
            physics.setCarPenalty(ac.PenaltyType.MandatoryPits, 3)
            timeUNREGULAR=0
            PenaltyCAUTION=false
            RadioMessage("drive_thru.mp3")
          end
        end
      end

      if SAFETY_CAR_OUT == true then
        SC_IN_THIS_LAP=true
        if ac.getCar(safetycar).isInPitlane == false and sc_pit_request==false then
          physics.setAIPitStopRequest(safetycar, true)
          sc_pit_request=true
          SC_TURN_LIGHTS_OFF=true
          physics.setAIDriverName(safetycar,"--SAFETY CAR--")
          RadioMessage("sc_in.mp3")
        else
          if ac.getCar(safetycar).isInPitlane == true and sc_inactive == false then
            SAFETY_CAR_IN=true
            sc_ts=os.preciseClock()
            sc_inactive=true
          end
        end
        
        if SAFETY_CAR_IN == true then
          ui.toast(ui.Icons.Code, "GET READY TO RESUME THE RACE")
          sc_now=os.preciseClock()
          if aRadio==false then
            RadioMessage("get_ready_restart.mp3")
            aRadio=true
          end
          if sc_now-sc_ts>10 then
            SAFETY_CAR_INITIALIZED=false
            SAFETY_CAR_OUT=false
            SC_IN_THIS_LAP=false
            ResumeRace()
            physics.setGentleStop(safetycar,true)
            physics.setAIDriverName(safetycar,"SAFETY CAR")
            aRadio=false
            tdbg_elapsed=0
            if PenaltyCAUTION==true and do_PENALTIES==true then
              physics.setCarPenalty(ac.PenaltyType.MandatoryPits, 3)
              timeUNREGULAR=0
              PenaltyCAUTION=false
              RadioMessage("drive_thru.mp3")
            end
          end
        end

      end
    end
  else
    if FORMATION_LAP ==  false and ac.getSim().isSessionStarted == true then
      DrawGreen()
    end
  end

  CheckRadioMessageEnd()

  if safetycar == 0 then
    ui.text("ERROR : SAFETY CAR NOT FOUND - INCLUDE IT IN THE RACE OR/AND SELECT IT IN SC TAB")
  end

  for i = 1, aiDriverCount, 1
  do
    if do_REFUELONTHEFLY==true then
      if do_PERSONAL==true then
        RefuelOnTheFly(i)
      end
    end

    if ac.getCar(i).isInPitlane == true and i ~= safetycar then
      logline='In pitlane ' .. i .. ' : ' .. ac.getCarName(i,false) .. ' - fuel : ' .. math.floor(ac.getCar(i).fuel) .. ' - lap :' .. ac.getCar(i).lapCount
      StoreLogLine(logline)
    end
  end

  if ac.getSim().isSessionFinished==true then
    RaceLogSave()
  end

  RecordLapPit()

  if do_PERSONAL==true then
    ResetFuelInPitlane()
  end

  CalcPitTimeAll()

  --ShowLeaderboard()
  --ui.text("pdiff_sc:" .. pdiff_sc)
  --ui.text("sc_now-sc_ts:" .. math.floor(sc_now-sc_ts))
  --ui.text("safetycar_pos:" .. safetycar_pos)

  if SHOW_DEBUG==true then
    ui.text("safetycar speed:" .. ac.getCar(safetycar).speedKmh)
    ui.text("safetycar spline pos:" .. ac.getCar(safetycar).splinePosition)
    ui.text("leader spline pos:" .. ac.getCar(ReturnCarInPos(1)).splinePosition)
  end

  CheckSCGhost()

  MakeSCStopFormationLap()

  if do_BTN_SC_CAUTION==true then
    ButtonInitSC()
  end

  if FORMATION_LAP==true then
    CheckPlayerPosFormation()
    ShowPenaltyThreat()
  end

  if (FCY==true and do_PERSONAL==true) or SAFETY_CAR_INITIALIZED==true then
    CheckPlayerPosCaution()
    ShowPenaltyThreat()
  end

  if FCY==true and do_PERSONAL==false then
    CheckSpeedFCY()
  end

  PlayerOldSector=ac.getCar(0).currentSector

  TimeRaceElapsed=TimeRaceElapsed+ui.deltaTime()

  if do_DRS==true then
    CheckDRS()
  end
  
  if physics.allowed() == true then
    ui.newLine()
    if ui.button("Disable Track Physics") then
      DisablePhysics()
      ui.toast(ui.Icons.Code, "Track Physics Disabled, restart from C.M to apply.")
    end
  end

  --ShowAllCarsSpeed()

  --if FORMATION_BEHIND_CATCH==true then
    --if FORMATION_LAP == true then
      --pos_player=ac.getCar(0).racePosition
      --for i=pos_player+1, aiDriverCount+1, 1 do
        --if ReturnCarInPos(i) ~= safetycar then
          --ai_behind_player=ReturnCarInPos(i)
          --ui.text(ai_behind_player .. ":" .. ac.getCar(ai_behind_player).speedKmh)
        --end
      --end
    --end
  --end

end



function SlowDownAndRegroup(sector)
  for i=0, aiDriverCount, 1 do
    tpos[i]=ac.getCar(i).racePosition
    if i ~= 0 then
      topspeed[i]=P_MAX_SPEED_SC
    else
      topspeed[i]=ac.getCar(i).speedKmh
    end
  end

  for j=1, aiDriverCount, 1 do
    gap=math.abs(ac.getGapBetweenCars(ReturnCarInPos(j), ReturnCarInPos(j+1)))
    if gap>2 then
      topspeed[ReturnCarInPos(j+1)]=topspeed[ReturnCarInPos(j)]+40
    else
      topspeed[ReturnCarInPos(j+1)]=topspeed[ReturnCarInPos(j)]
    end

    if sector == true and ReturnCarInPos(j) ~= 0 and ReturnCarInPos(j) ~= safetycar then
      if ac.getCar(ReturnCarInPos(j)).currentSector == YELLOW_FLAG_sector then
        physics.setAITopSpeed(ReturnCarInPos(j), topspeed[ReturnCarInPos(j)])
      else
        physics.setAITopSpeed(ReturnCarInPos(j), 1e9)
      end
    end

    if sector == true and ReturnCarInPos(j+1) ~= 0 and ReturnCarInPos(j+1) ~= safetycar then
      if ac.getCar(ReturnCarInPos(j+1)).currentSector == YELLOW_FLAG_sector then
        physics.setAITopSpeed(ReturnCarInPos(j+1), topspeed[ReturnCarInPos(j+1)])
      else
        physics.setAITopSpeed(ReturnCarInPos(j+1), 1e9)
      end
    end

    local leader_laps=ac.getCar(ReturnCarInPos(1)).lapCount
    local leader_spline=ac.getCar(ReturnCarInPos(1)).splinePosition
    local j_laps=ac.getCar(ReturnCarInPos(j)).lapCount
    local j_spline=ac.getCar(ReturnCarInPos(j)).splinePosition
    local jp1_laps=ac.getCar(ReturnCarInPos(j+1)).lapCount
    local jp1_spline=ac.getCar(ReturnCarInPos(j+1)).splinePosition

    if sector == false then
      if ReturnCarInPos(j) ~= 0 and ReturnCarInPos(j) ~= safetycar  then
        if leader_laps == ac.getCar(ReturnCarInPos(j)).lapCount then
          physics.setAITopSpeed(ReturnCarInPos(j), topspeed[ReturnCarInPos(j)])
        else
          if leader_laps-j_laps >= 1 and leader_spline>j_spline then
            physics.setAITopSpeed(ReturnCarInPos(j), P_MAX_SPEED_SC)
          else
            physics.setAITopSpeed(ReturnCarInPos(j), topspeed[ReturnCarInPos(j)])
          end
        end
      end
  
      if ReturnCarInPos(j+1) ~= 0 and ReturnCarInPos(j+1) ~= safetycar then
        if leader_laps == ac.getCar(ReturnCarInPos(j+1)).lapCount then
          physics.setAITopSpeed(ReturnCarInPos(j+1), topspeed[ReturnCarInPos(j+1)])
        else
          if leader_laps-jp1_laps >= 1 and leader_spline>jp1_spline then
            physics.setAITopSpeed(ReturnCarInPos(j+1), P_MAX_SPEED_SC)
          else
            physics.setAITopSpeed(ReturnCarInPos(j+1), topspeed[ReturnCarInPos(j+1)])
          end
        end
      end
      
      physics.setAITopSpeed(safetycar,80)
    end
  end

  Launch_SaveFrameInfo()

end




function SlowDownAndRegroupSafetyCar()
  pdiff_sc=ac.getCar(safetycar).splinePosition-ac.getCar(ReturnCarInPos(1)).splinePosition
  following_car=1

  if ac.getCar(safetycar).headlightsActive==false then
    SC_TURN_LIGHTS_OFF=false
  end

  if SC_TURN_LIGHTS_OFF==false then
    if pdiff_sc<0.002 then
      physics.setAITopSpeed(safetycar, P_MAX_SPEED_SC)
      physics.setAITopSpeed(ReturnCarInPos(following_car), P_MAX_SPEED_SC-10)
      topspeed[ReturnCarInPos(1)]=P_MAX_SPEED_SC-10
    else
      if pdiff_sc>0.003 then
        physics.setAITopSpeed(safetycar, P_MAX_SPEED_SC-10)
        physics.setAITopSpeed(ReturnCarInPos(following_car), P_MAX_SPEED_SC)
        topspeed[ReturnCarInPos(1)]=P_MAX_SPEED_SC
      else
        physics.setAITopSpeed(safetycar, P_MAX_SPEED_SC)
        physics.setAITopSpeed(ReturnCarInPos(following_car), P_MAX_SPEED_SC)
        topspeed[ReturnCarInPos(1)]=P_MAX_SPEED_SC
      end
    end
  else
    physics.setAITopSpeed(safetycar, P_MAX_SPEED_SC+15)
  end
  SlowDownAndRegroupSC()
end



function SlowDownAndRegroupSC()
  sc_pos=ac.getCar(safetycar).racePosition
  if sc_pos == 1 then
    s=3
  else
    s=2 -- toujours ceci si caution
  end

  for i=0, aiDriverCount, 1 do
    tpos[i]=ac.getCar(i).racePosition
    if i ~= ReturnCarInPos(1) then
      if i ~= 0 then
        topspeed[i]=P_MAX_SPEED_SC
      else
        topspeed[i]=ac.getCar(i).speedKmh
      end
    end
  end

  for j=s, aiDriverCount, 1 do --aiDriverCount fa tsy aiDriverCount-1 satria ny player koa ao anatiny
    gap=math.abs(ac.getGapBetweenCars(ReturnCarInPos(j-1), ReturnCarInPos(j)))
    if gap>1.5 then
      topspeed[ReturnCarInPos(j)]=topspeed[ReturnCarInPos(j-1)]+20
    else
      if gap<0.5 then
        topspeed[ReturnCarInPos(j)]=topspeed[ReturnCarInPos(j-1)]-20
      else
        topspeed[ReturnCarInPos(j)]=topspeed[ReturnCarInPos(j-1)]
      end
    end

    --ac.log("I am here in slowdonwregroupsc")

    local leader_laps=ac.getCar(ReturnCarInPos(1)).lapCount
    local leader_spline=ac.getCar(ReturnCarInPos(1)).splinePosition
    local j_laps=ac.getCar(ReturnCarInPos(j)).lapCount
    local j_spline=ac.getCar(ReturnCarInPos(j)).splinePosition
    local jp1_laps=ac.getCar(ReturnCarInPos(j-1)).lapCount
    local jp1_spline=ac.getCar(ReturnCarInPos(j-1)).splinePosition

    if ReturnCarInPos(j) ~= 0 and ReturnCarInPos(j) ~= safetycar  then
      if leader_laps == ac.getCar(ReturnCarInPos(j)).lapCount then
        physics.setAITopSpeed(ReturnCarInPos(j), topspeed[ReturnCarInPos(j)])
      else
        if leader_laps-j_laps >= 1 and leader_spline>j_spline then
          physics.setAITopSpeed(ReturnCarInPos(j), P_MAX_SPEED_SC)
        else
          physics.setAITopSpeed(ReturnCarInPos(j), topspeed[ReturnCarInPos(j)])
        end
      end
    end

    if j-1 ~= 1 then
      if ReturnCarInPos(j-1) ~= 0 and ReturnCarInPos(j-1) ~= safetycar then
        if leader_laps == ac.getCar(ReturnCarInPos(j-1)).lapCount then
          physics.setAITopSpeed(ReturnCarInPos(j-1), topspeed[ReturnCarInPos(j-1)])
        else
          if leader_laps-jp1_laps >= 1 and leader_spline>jp1_spline then
            physics.setAITopSpeed(ReturnCarInPos(j-1), P_MAX_SPEED_SC)
          else
            physics.setAITopSpeed(ReturnCarInPos(j-1), topspeed[ReturnCarInPos(j-1)])
          end
        end
      end
    end
  end

  Launch_SaveFrameInfo()
end





function SaveFrameInfo()
  local filePath = ac.getFolder(tostring(ac.FolderID.ACAppsLua)) .. "\\fcy_yellow_rollingstart\\debug_log.txt"
  local writeFile = io.open(filePath, "a")
  if writeFile ~= nil then
    writeFile:write("Track : " .. ac.getTrackID() .. "\n")
    writeFile:write("Date : " .. os.date() .. "\n")
    writeFile:write("MAX SPEED SC : " .. P_MAX_SPEED_SC .. "\n")
    writeFile:write("MIN DURATION SC : " .. P_DURATION_MIN_SC .. "\n")
    writeFile:write("MAX DURATION SC : " .. P_DURATION_MAX_SC .. "\n")
    writeFile:write("DURATION SC : " .. cautionDuration .. "\n")
    writeFile:write("SPAWN POS AUTO (grid front row, 4 m clear ahead of P1)\n")
    if SAFETY_CAR_OUT==false then
      writeFile:write("SAFETY CAR NOT SPAWNED YET\n")
    else
      writeFile:write("SAFETY CAR LEADING THE PACK\n")
    end
    if SC_IN_THIS_LAP==true then
      writeFile:write("SAFETY CAR IN THIS LAP\n")
    end
    if SAFETY_CAR_IN==true then
      writeFile:write("SAFETY CAR ENTERS PITLANE\n")
    end
    for j=1, ac.getSim().carsCount, 1 do
      local zgap
      if j>1 then
        zgap=math.abs(ac.getGapBetweenCars(ReturnCarInPos(j-1), ReturnCarInPos(j)))
      else
        zgap=0
      end
      local vadd=""
      if ReturnCarInPos(j)==safetycar then
        vadd=" SC "
      else
        vadd=""
      end
      local vadd2
      if ac.getCar(ReturnCarInPos(j)).isInPit == true then
        vadd2="[IN PIT]"
      else
        vadd2=""
      end
      local vadd3
      if ac.getCar(ReturnCarInPos(j)).isInPitlane == true then
        vadd3="[IN PITLANE]"
      else
        vadd3=""
      end
      writeFile:write(j .. ' : car ' .. ReturnCarInPos(j) .. "{" .. ac.getCarName(ReturnCarInPos(j),false) .. "}" .. vadd .. vadd2 .. vadd3 .. ' - laps ' .. ac.getCar(ReturnCarInPos(j)).lapCount .. ' - speed : ' .. math.floor(ac.getCar(ReturnCarInPos(j)).speedKmh) .. " [pos:" .. ac.getCar(ReturnCarInPos(j)).splinePosition .. "] [gap: " .. zgap .. "]\n")
    end
  end
end



function Launch_SaveFrameInfo()
  if do_RECORD_DEBUG==true and SAFETY_CAR_INITIALIZED==true then
    if tdbg_elapsed>60 then
      SaveFrameInfo()
      tdbg_elapsed=0
    end
  end
end



function CheckDRS()
end



function DisableDRSIfActive()
  if ac.getCar(0).drsActive == true then
    physics.setCarDRS(0, false)
  end
end




function AreAllStopped()
  local r=true
  for i=0, aiDriverCount, 1 do
    if i ~= safetycar then
      if ac.getCar(i).speedKmh<1 then
        do_nothing=true
      else
        r=false
      end
    end
  end
  return r
end




function ShowAllCarsSpeed()
  for i=0, aiDriverCount, 1 do
    ui.text(i .. " : " .. ac.getCar(i).speedKmh)
  end
end




function CheckSpeedFCY()
  if ac.getCar(0).speedKmh>P_MAX_SPEED_FCY then
    ui.textColored("SLOW DOWN - DON'T EXCEED " .. P_MAX_SPEED_FCY .. " KM/H \nOR YOU WILL BE PENALIZED",rgbm.colors.yellow)
    timeUNREGULAR=timeUNREGULAR+1
    if timeUNREGULAR>50000 then
      timeUNREGULAR=50000
    end
    RadioMessageThreat("slow_down.mp3")
  end
  if timeUNREGULAR>5000 then
    PenaltyCAUTION=true
  end
  ac.debug("timeUNREGULAR",timeUNREGULAR)
end



function InitYELLOW()
  YELLOW_FLAG=true
  YELLOW_FLAG_time_start = os.preciseClock()
  YELLOW_FLAG_sector=ac.getCar(0).currentSector
  FCY=false
  math.randomseed(math.floor(os.preciseClock()))
  cautionDuration=math.random(P_DURATION_MIN_YELLOW,P_DURATION_MAX_YELLOW)
  RadioMessage("yellow.mp3")
end



function InitFCY()
  FCY=true
  FCY_time_elapsed = os.preciseClock()
  YELLOW_FLAG=false
  YELLOW_FLAG_sector=0
  math.randomseed(math.floor(os.preciseClock()))
  cautionDuration=math.random(P_DURATION_MIN_FCY,P_DURATION_MAX_FCY)
  if do_VSC==false then
    RadioMessage("fcy.mp3")
  else
    RadioMessage("vsc.mp3")
  end
  GetCarBeforeStartCaution()
end



function ShowPenaltyThreat()
  if WARNING_RETURN_TO_YOUR_POS==true then
    ui.textColored("RETURN TO YOUR POSITION\nLET THE CAR BEHIND PASS\nOR YOU WILL BE PENALIZED",rgbm.colors.yellow)
    RadioMessageThreat("return_to_pos.mp3")
  end
end



function RadioMessageThreat(fmsg)
  if do_RADIO_MESSAGE==true then
    if RADIO_MSG_ON==false then
      RADIO_MSG_ON=true
      -- (engine-volume ducking removed: this build never restored it, so
      -- the engine stayed quiet for the rest of the session)
      local filePath = ac.getFolder(tostring(ac.FolderID.ACAppsLua)) .. "\\fcy_yellow_rollingstart\\" .. fmsg
      player = ui.MediaPlayer()
      player:setSource(filePath):setAutoPlay(false)
      player:setVolume(1)
      player:play()
    end
  end
end



function GetCarBeforeStartCaution()
  if ac.getCar(0).racePosition>1 then
    vNo=true
    dp=ac.getCar(0).racePosition-1
    while vNo==true and dp>1 do
      carBeforePlayer=ReturnCarInPos(dp)
      if ac.getCar(carBeforePlayer).speedKmh<1 or ac.getCar(carBeforePlayer).isInPitlane==true or ac.getCar(carBeforePlayer).isInPit==true or ac.getCar(carBeforePlayer).isRetired==true then
        vNo=true
        dp=dp-1
      else
        vNo=false
      end
    end
    if vNo==true then
      carBeforePlayer=-1
    end
  else
    carBeforePlayer=-1
  end
  timeUNREGULAR=0
end



function CheckPlayerPosCaution()
  --ac.debug("carBeforePlayer",carBeforePlayer)

  if ac.getCar(carBeforePlayer).isRetired==false and ac.getCar(carBeforePlayer).isInPitlane==false and ac.getCar(carBeforePlayer).isInPit==false then
    if carBeforePlayer ~= -1 then
      if ac.getCar(0).racePosition<ac.getCar(carBeforePlayer).racePosition then
        WARNING_RETURN_TO_YOUR_POS=true
        timeUNREGULAR=timeUNREGULAR+1
      else
        WARNING_RETURN_TO_YOUR_POS=false
      end
    else
      if SAFETY_CAR_INITIALIZED==true then
        pdiff=ac.getCar(safetycar).splinePosition-ac.getCar(0).splinePosition
        --ac.debug("pdiff",pdiff)
        if SAFETY_CAR_OUT==true then
          if pdiff<0 and ac.getCar(safetycar).isInPitlane==false  then
            WARNING_RETURN_TO_YOUR_POS=true
            timeUNREGULAR=timeUNREGULAR+1
            if timeUNREGULAR>50000 then
              timeUNREGULAR=50000
            end
          else
            WARNING_RETURN_TO_YOUR_POS=false
          end
        else
          WARNING_RETURN_TO_YOUR_POS=false
        end
      else
        WARNING_RETURN_TO_YOUR_POS=false
      end
    end
    --ac.debug("timeUNREGULAR",timeUNREGULAR)
  else
    timeUNREGULAR=0
  end

  if timeUNREGULAR>5000 then
    PenaltyCAUTION=true
  end
end



function CheckPlayerPosFormation()
  if do_SC_FORMATION_LAP==true then
    vcheck=true
  else
    if carBeforePlayer ~= safetycar then
      vcheck=true
    else
      vcheck=false
    end
  end

  if vcheck==true then
    if ac.getCar(0).racePosition<ac.getCar(carBeforePlayer).racePosition then
      WARNING_RETURN_TO_YOUR_POS=true
      timeUNREGULAR=timeUNREGULAR+1
      if timeUNREGULAR>50000 then
        timeUNREGULAR=50000
      end
    else
      WARNING_RETURN_TO_YOUR_POS=false
    end
  end
  ac.debug("timeUNREGULAR",timeUNREGULAR)

  if timeUNREGULAR>5000 then
    PenaltyFORMATION=true
  end
end



function MakeSCStopFormationLap()
  if do_SC_FORMATION_LAP==true and ASSIGNED_POS==true then
    if CALL_SC_FORMATION==true then
      if ac.getCar(safetycar).isInPitlane==true and SC_STOP_ORDERED==false then
        physics.setGentleStop(safetycar,true)
        SC_STOP_ORDERED=true
        RadioMessage("get_ready_start.mp3")
      end
    end
  end
end



function MakeThemSlow()
  for i=1, aiDriverCount, 1 do
    if i ~= safetycar then
      physics.setAITopSpeed(i,100)
    end
  end
end



function ReleaseThem()
  for i=1, aiDriverCount, 1 do
    if i ~= safetycar then
      physics.setAITopSpeed(i,1e9)
    end
  end
end



function InitSC()
  SAFETY_CAR_INITIALIZED=true
  FCY=false
  YELLOW_FLAG=false
  physics.resetCarState(safetycar, 1)
  physics.setCarPosition(safetycar, spawnPos, spawnDir)
  ac.setCarActive(safetycar,false)
  RadioMessage("sc.mp3")
  SC_GHOST=true
  GetCarBeforeStartCaution()
end



function CheckSCGhost()
  if ac.getCar(safetycar).isRetired == true and SC_GHOST==true then
    physics.resetCarState(safetycar, 1)
    physics.setCarPosition(safetycar, spawnPos, spawnDir)
    ac.setCarActive(safetycar,false)
  end
end




function ButtonInitSC()
  if SAFETY_CAR_INITIALIZED == false then
    ui.newLine()
    if ui.button("Test safety car caution") then
      if FORMATION_LAP==false and YELLOW_FLAG==false and FCY==false and ac.getSim().isSessionStarted == true then
        InitSC()
      else
        ui.toast(ui.Icons.Code,"No SC caution now - wait the race start or resume")
      end
    end
  end
end



function ComputeAutoSpawn()
  -- Automatic SC spawn point - no per-track setup needed. The SC spawns
  -- facing the same way as the player, laterally centered between the P1
  -- and P2 grid slots, with exactly 4 m of clear road between P1's front
  -- bumper and the SC's rear bumper (measured straight along the field's
  -- direction only, never diagonally).
  first_car=ReturnCarInPos(1)
  second_car=ReturnCarInPos(2)
  if first_car==nil then first_car=0 end
  if second_car==nil then second_car=first_car end
  local p1=ac.getCar(first_car).position
  local p2=ac.getCar(second_car).position

  -- field direction = player's facing, flattened to the horizontal plane
  local look=ac.getCar(0).look
  local len=math.sqrt(look.x*look.x + look.z*look.z)
  local fwd
  if len>0.001 then
    fwd=vec3.new(look.x/len, 0, look.z/len)
  else
    fwd=vec3.new(0,0,1)
  end

  -- bumper-to-bumper: half of P1's length + 4 m gap + half of the SC's
  -- length gives the required center-to-center forward distance
  local p1_half=ac.getCar(first_car).aabbSize.z/2
  local sc_half=2.4
  if safetycar ~= nil and safetycar ~= 0 then
    sc_half=ac.getCar(safetycar).aabbSize.z/2
  end
  if p1_half<1.5 or p1_half>4 then p1_half=2.4 end
  if sc_half<1.5 or sc_half>4 then sc_half=2.4 end

  -- lateral: midpoint of the P1/P2 slots; forward: P1's forward coordinate
  -- plus the clearance (projection keeps the two axes independent)
  local mid=vec3.new((p1.x+p2.x)/2, p1.y, (p1.z+p2.z)/2)
  local ahead=(p1.x-mid.x)*fwd.x + (p1.z-mid.z)*fwd.z + p1_half + 4.0 + sc_half
  spawnPos=vec3.new(mid.x + fwd.x*ahead, p1.y, mid.z + fwd.z*ahead)

  -- setCarPosition's direction argument is the REVERSED facing direction
  -- (CSP's own comfy_map and CspDebug both pass -look to keep a heading)
  spawnDir=vec3.new(-fwd.x, 0, -fwd.z)

  safetycar_pos=ac.getCar(first_car).splinePosition
end



-- ==== player position coach: audio cues during the formation lap ====
-- The grid order is recorded at the formation start (startSeq/startOrder).
-- 5 s after the formation lap begins the player is judged every frame:
--   "front"  = the player is ahead of a car that started in front of them
--   "behind" = a car that started behind them is now ahead, OR the car
--              they should be following is more than 3 s up the road
--              (recovers once closed back under 2 s, so no flickering)
-- BehindOfPos.mp3 / InFrontOfPos.mp3 repeat until the situation is fixed;
-- recovering plays CorrectPos.mp3 three times as confirmation. There is
-- always 1 s of silence between consecutive plays. Cars that retired or
-- pitted are skipped everywhere - inheriting their place is legitimate.
COACH_LAG_ENTER=3.0
COACH_LAG_EXIT=2.0
coachArmTimer=0
coachStatus="correct"
coachWasWrong=false
coachCorrectLeft=0
coachDelay=0
coachActive=false
coachPlayer=nil
coachPlayStart=0
coachLagging=false
coachSource=nil

function CoachReset()
  coachArmTimer=0
  coachStatus="correct"
  coachWasWrong=false
  coachCorrectLeft=0
  coachDelay=0
  coachLagging=false
  if coachActive==true and coachPlayer~=nil then
    coachPlayer:pause()
  end
  coachActive=false
end

function CoachPlay(fname)
  if coachPlayer==nil then
    coachPlayer=ui.MediaPlayer()
    coachPlayer:setAutoPlay(false)
  end
  if coachSource~=fname then
    local fp=ac.getFolder(tostring(ac.FolderID.ACAppsLua)) .. "\\fcy_yellow_rollingstart\\" .. fname
    coachPlayer:setSource(fp)
    coachSource=fname
  end
  coachPlayer:setVolume(1)
  -- rewind BEFORE playing: play() alone does not restart a stream that
  -- already reached its end, which is why repeats silently did nothing
  coachPlayer:setCurrentTime(0)
  coachPlayer:play()
  coachActive=true
  coachPlayStart=os.preciseClock()
end

function CoachJudge()
  -- returns "front", "behind" or "correct" for the player (car 0)
  local mypos=ac.getCar(0).racePosition
  local myseq=nil
  for k=1, #startSeq, 1 do
    if startSeq[k]==0 then
      myseq=k
      break
    end
  end
  if myseq==nil then return "correct" end

  -- overtook: a car that started ahead (still racing) now sits behind
  for k=1, myseq-1, 1 do
    local c=startSeq[k]
    if c~=nil and (c==safetycar and ac.getCar(c).isInPitlane==false
                   or c~=safetycar and CarRunning(c)) then
      if ac.getCar(c).racePosition>mypos then
        return "front"
      end
    end
  end

  -- passed: a car that started behind (still racing) is now ahead
  for k=myseq+1, #startSeq, 1 do
    local c=startSeq[k]
    if c~=nil and c~=safetycar and CarRunning(c) then
      if ac.getCar(c).racePosition<mypos then
        return "behind"
      end
    end
  end

  -- lagging: too big a gap to the car that should be directly ahead
  local eahead=nil
  for k=myseq-1, 1, -1 do
    local c=startSeq[k]
    if c~=nil and (c==safetycar and ac.getCar(c).isInPitlane==false
                   or c~=safetycar and CarRunning(c)) then
      eahead=c
      break
    end
  end
  if eahead~=nil then
    local g=math.abs(ac.getGapBetweenCars(eahead, 0))
    local thr
    if coachLagging==true then thr=COACH_LAG_EXIT else thr=COACH_LAG_ENTER end
    if g>thr then
      coachLagging=true
      return "behind"
    end
  end
  coachLagging=false
  return "correct"
end

function PositionCoach()
  -- arm 5 s after the formation lap begins
  if coachArmTimer<5 then
    coachArmTimer=coachArmTimer+ui.deltaTime()
    return
  end
  if #startSeq==0 then return end

  if coachDelay>0 then
    coachDelay=coachDelay-ui.deltaTime()
  end

  -- notice the end of the current play. playing() alone is NOT reliable -
  -- it can stay true after the file runs out - so several signals are
  -- checked, each behind a 0.3 s grace for the async loader:
  --   1. the player reports the stream ended
  --   2. the player reports it stopped playing
  --   3. we are past the file's known duration
  --   4. hard 10 s cap so a stuck flag can never freeze the rotation
  if coachActive==true and coachPlayer~=nil then
    local el=os.preciseClock()-coachPlayStart
    local fin=false
    if el>0.3 then
      if coachPlayer:ended()==true then fin=true end
      if coachPlayer:playing()==false then fin=true end
      local dur=coachPlayer:duration()
      if dur~=nil and dur==dur and dur>0 and el>dur+0.3 then fin=true end
    end
    if el>10 then fin=true end
    if fin==true then
      coachActive=false
      coachDelay=1.0
    end
  end

  local status=CoachJudge()

  if status~=coachStatus then
    -- situation changed: cut whatever is mid-play, keep the 1 s spacing
    if coachActive==true and coachPlayer~=nil then
      coachPlayer:pause()
      coachActive=false
      coachDelay=1.0
    end
    if status=="correct" then
      if coachWasWrong==true then
        coachCorrectLeft=3
      end
    else
      coachWasWrong=true
      coachCorrectLeft=0
    end
    RLog("COACH: player position status -> " .. status)
    coachStatus=status
  end

  if coachActive==false and coachDelay<=0 then
    if coachStatus=="behind" then
      CoachPlay("BehindOfPos.mp3")
    elseif coachStatus=="front" then
      CoachPlay("InFrontOfPos.mp3")
    elseif coachCorrectLeft>0 then
      CoachPlay("CorrectPos.mp3")
      coachCorrectLeft=coachCorrectLeft-1
      if coachCorrectLeft==0 then
        coachWasWrong=false
      end
    end
  end
end



function InitPitTimer() --Thanks to Naim Da Cook
  for i=0, aiDriverCount, 1 do
    wasinpit[i]=false
    pitentrytime[i]=0
    pitexittime[i]=0
    pitstopdone[i]=false
    timeinpit[i]=0
    if i ~= safetycar then    
      PitTimeShowed[i]=false
    end
  end
end


function CalcPitTime(pcar) --Thanks to Naim Da Cook
    local car = ac.getCar(pcar)

    local inpit = car.isInPitlane

    local enteringpitlane = inpit and not wasinpit[pcar]

    local exitingpitlane = not inpit and wasinpit[pcar]

    if enteringpitlane then
        wasinpit[pcar] = true
        pitentrytime[pcar] = os.clock()
        pitstopdone[pcar] = false

    end

    if exitingpitlane then
        wasinpit[pcar] = false
        pitexittime[pcar] = os.clock()
        timeinpit[pcar] = pitexittime[pcar] - pitentrytime[pcar]
        pitstopdone[pcar] = true
    end

    if pitstopdone[pcar] == true then
      StoreLogLine("Pit stop duration : " .. ac.getDriverName(pcar) .. "-" .. ac.getCarName(pcar,false) .. " : " .. timeinpit[pcar] .. "s")
      lasttimeinpit[pcar]=timeinpit[pcar]
      if PitTimeShowed[pcar]==false then
        if do_SHOW_PIT_TIMES==true then
          ui.toast(ui.Icons.Code, "Pitstop time : " .. ac.getDriverName(pcar) .. " - " .. timeinpit[pcar] .. "s")
        end
        PitTimeShowed[pcar]=true
      end
    end
end



function ShowTimeInPit()
end



function CalcPitTimeAll()
end



function FormationTuningTab()
  -- Tuning for the enhanced formation behaviour layer only. Values are
  -- read every frame, so changes apply live - even mid formation lap.
  ui.text("Formation lap behaviour tuning (applies live).")
  ui.newLine()

  ui.text("Tire warming")
  TUNE.weaveWidth = ui.slider('##tune_ww', TUNE.weaveWidth, 0.3, 1.3, 'Sweep width: %.2fx')
  TUNE.weaveRhythm = ui.slider('##tune_wr', TUNE.weaveRhythm, 0.7, 2.0, 'Sweep cycle time: %.2fx')
  ui.text("Width 1.00x = sweeps covering 62-78% of the lane.")
  ui.text("Cycle 1.00x = one full sweep every ~3 s (higher = lazier).")
  ui.newLine()

  ui.text("Train spacing")
  TUNE.cushionMin = ui.slider('##tune_cmin', TUNE.cushionMin, 0.4, 2.0, 'Cushion min: %.1f s')
  TUNE.cushionMax = ui.slider('##tune_cmax', TUNE.cushionMax, 0.6, 3.0, 'Cushion max: %.1f s')
  ui.text("Each driver holds a personal gap inside this range.")
  ui.newLine()

  ui.text("Catch-up")
  TUNE.catchHurryGap = ui.slider('##tune_chg', TUNE.catchHurryGap, 1.0, 4.0, 'Hurry when gap over: %.1f s')
  TUNE.catchFlatGap = ui.slider('##tune_cfg', TUNE.catchFlatGap, 2.0, 10.0, 'Flat out when gap over: %.1f s')
  TUNE.catchHurrySpeed = ui.slider('##tune_chs', TUNE.catchHurrySpeed, 10, 70, 'Hurry pace: +%.0f km/h')
  ui.newLine()

  if ui.button("Reset tuning to defaults") then
    TUNE.weaveWidth = 1.0
    TUNE.weaveRhythm = 1.0
    TUNE.cushionMin = 0.7
    TUNE.cushionMax = 1.3
    TUNE.catchHurryGap = 2.0
    TUNE.catchFlatGap = 5.0
    TUNE.catchHurrySpeed = 40
  end
  ui.text("Settings persist between sessions automatically.")
end




function RadioMessage(fmsg)
end



function CheckRadioMessageEnd()
end


function AppMainQualify()
  if firstTimeQuali==true then
    aiDriverCount = ac.getSim().carsCount - 1

    SCLoad()
    
    safetycar=0
    for i=1, aiDriverCount,1 do
      if ac.getCarName(i,false)==safetycar_name or ac.getCarID(i)==safetycar_id then
        safetycar=i
        --ui.text("Safety car " .. i .. " : " .. ac.getCarName(i,false))
      end
    end
    if safetycar ~= 0 then
      physics.setAIDriverName(safetycar, "SAFETY CAR")
      physics.teleportCarTo(safetycar, ac.SpawnSet.Pits)
      physics.setGentleStop(safetycar, true)
    end
    RemoveDuplicateSafetyCars()

    LoadSettings()

    ComputeAutoSpawn()

    RLogHeader("SESSION INIT (qualify)")
    firstTimeQuali=false
  end

  -- enforce every frame, same as the race path: AC can re-activate
  -- deactivated clones when a qualifying session restarts
  RemoveDuplicateSafetyCars()

  ui.text("Qualifying session \n\nJust keep this window open")

  if safetycar == 0 then
    ui.newLine()
    ui.text("ERROR : SAFETY CAR NOT FOUND - INCLUDE IT IN THE RACE OR/AND SELECT IT IN SC TAB")
  end
end



function ShowNBRPIT()
  for i=0, aiDriverCount, 1 do
    ui.text("car " .. i .. " : " .. NBR_PITS[i] .. " stop(s)")
  end
end



function ShowLog()
  for i=1, index_log-1,1 do
    ui.text(log_lines[i])
  end
end



function AppSettings()
  if ui.checkbox('Formation lap', do_FORMATION_LAP) then
    do_FORMATION_LAP=not do_FORMATION_LAP
  end
  if ui.checkbox('Safety car in formation lap', do_SC_FORMATION_LAP) then
    do_SC_FORMATION_LAP=not do_SC_FORMATION_LAP
  end
  if ui.checkbox('Yellow flag in sector', do_YELLOW_FLAG) then
    do_YELLOW_FLAG=not do_YELLOW_FLAG
  end
  if ui.checkbox('Full course yellow', do_FCY) then
    do_FCY=not do_FCY
  end
  if ui.checkbox('Safety car', do_SAFETYCAR) then
    do_SAFETYCAR=not do_SAFETYCAR
  end
  if ui.checkbox('Display VSC instead of FCY', do_VSC) then
    do_VSC=not do_VSC
  end
  if ui.checkbox('Disable caution in first lap', do_DISABLE_FIRST_LAP) then
    do_DISABLE_FIRST_LAP=not do_DISABLE_FIRST_LAP
  end
  if ui.checkbox('Radio messages', do_RADIO_MESSAGE) then
    do_RADIO_MESSAGE=not do_RADIO_MESSAGE
  end
  if ui.checkbox('Display pitstop times', do_SHOW_PIT_TIMES) then
    do_SHOW_PIT_TIMES=not do_SHOW_PIT_TIMES
  end
  if ui.checkbox('Penalties', do_PENALTIES) then
    do_PENALTIES=not do_PENALTIES
  end
  if ui.checkbox('Button Test Safety Car Caution', do_BTN_SC_CAUTION) then
    do_BTN_SC_CAUTION=not do_BTN_SC_CAUTION
  end
  if ui.checkbox('DRS management', do_DRS) then
    do_DRS=not do_DRS
  end
  if ui.checkbox('Enable debug log', do_RECORD_DEBUG) then
    do_RECORD_DEBUG=not do_RECORD_DEBUG
  end

  P_FORMATION_SPEED = ui.inputText('Formation lap speed (KM/H)',P_FORMATION_SPEED,ui.InputTextFlags.None,vec2(75,20))
  P_DURATION_MIN_YELLOW = ui.inputText('Yellow flag min duration (s)',P_DURATION_MIN_YELLOW,ui.InputTextFlags.None,vec2(75,20))
  P_DURATION_MAX_YELLOW = ui.inputText('Yellow flag max duration (s)',P_DURATION_MAX_YELLOW,ui.InputTextFlags.None,vec2(75,20))
  P_DURATION_MIN_FCY = ui.inputText('Full course yellow min duration (s)',P_DURATION_MIN_FCY,ui.InputTextFlags.None,vec2(75,20))
  P_DURATION_MAX_FCY = ui.inputText('Full course yellow max duration (s)',P_DURATION_MAX_FCY,ui.InputTextFlags.None,vec2(75,20))
  P_MAX_SPEED_FCY = ui.inputText('Full course yellow max speed (KM/H)',P_MAX_SPEED_FCY,ui.InputTextFlags.None,vec2(75,20))
  P_DURATION_MIN_SC = ui.inputText('Safety car min duration (s)',P_DURATION_MIN_SC,ui.InputTextFlags.None,vec2(75,20))
  P_DURATION_MAX_SC = ui.inputText('Safety car max duration (s)',P_DURATION_MAX_SC,ui.InputTextFlags.None,vec2(75,20))
  P_MAX_SPEED_SC = ui.inputText('Safety car max speed (KM/H)',P_MAX_SPEED_SC,ui.InputTextFlags.None,vec2(75,20))
  ui.newLine()
  ui.text("* Too high or too low for speed values may cause AI unexpected \n behaviour, always test gradually")

  ui.newLine()
  ui.text("Enter min and max lap number to do for\nthe safety car (recalculate for each track):")
  
  P_SC_MIN_LAPS= ui.inputText('Safety car min laps number',P_SC_MIN_LAPS,ui.InputTextFlags.None,vec2(75,20))
  P_SC_MAX_LAPS= ui.inputText('Safety car max laps number',P_SC_MAX_LAPS,ui.InputTextFlags.None,vec2(75,20))
  if ui.button("Calculate") then
    P_DURATION_MIN_SC=GiveDurationSec(P_SC_MIN_LAPS)
    if P_DURATION_MIN_SC<=0 then
      P_DURATION_MIN_SC=60
    end
    P_DURATION_MAX_SC=GiveDurationSec(P_SC_MAX_LAPS)
  end

  ui.newLine()
  if ui.button("Apply & save settings") then
    SaveSettings()
  end
  if ui.button("Reset settings") then
    P_FORMATION_SPEED = 90
    P_DURATION_MIN_YELLOW = 60
    P_DURATION_MAX_YELLOW = 180
    P_DURATION_MIN_FCY = 60
    P_DURATION_MAX_FCY = 180
    P_MAX_SPEED_FCY = 80
    P_DURATION_MIN_SC = 60
    P_DURATION_MAX_SC = 180
    P_MAX_SPEED_SC = 80
  end

  -- Disable Physics button
  ui.newLine()
  if ui.button("Reset track physics for playing online") then
    DisablePhysics()
    ui.toast(ui.Icons.Code, "Track Physics Disabled, restart from C.M to apply.")
  end

  ui.newLine()
  ui.text("Follow me for more mods & apps on Patreon :")
  ui.text("patreon.com/AssettoCorsaRacingCarsMods")
end



function GiveDurationSec(nbrlaps)
  vspeed=(P_MAX_SPEED_SC*1000)/3600
  d1lap=math.floor(ac.getSim().trackLengthM/vspeed)

  return nbrlaps*d1lap
end


function SaveSettings()
end



function LoadSettings()
end



function SCSettings()
end


function SCSave()
end



function SCLoad()
end


function FindSafetyCar()
  aiDriverCount = ac.getSim().carsCount - 1

  SCLoad()
  
  safetycar=0
  for i=1, aiDriverCount,1 do
    if ac.getCarName(i,false)==safetycar_name or ac.getCarID(i)==safetycar_id then
      safetycar=i
      --ui.text("Safety car " .. i .. " : " .. ac.getCarName(i,false))
    end
  end
end



function PlaceSafetyCarOnRaceStart()
  if safetycar ~= 0 then
    if do_FORMATION_LAP==false then
      physics.setAIDriverName(safetycar, "SAFETY CAR")
      physics.teleportCarTo(safetycar, ac.SpawnSet.Pits)
      physics.setGentleStop(safetycar, true)
    else
      if do_SC_FORMATION_LAP==true and ASSIGNED_POS==true then
        physics.setAIDriverName(safetycar, "SAFETY CAR")
        physics.setCarPosition(safetycar, spawnPos, spawnDir)
      else
        physics.setAIDriverName(safetycar, "SAFETY CAR")
        physics.teleportCarTo(safetycar, ac.SpawnSet.Pits)
        physics.setGentleStop(safetycar, true)
      end
    end
  end
end



function EverybodyPits()
  for i = 1, aiDriverCount, 1
  do
    if i ~= safetycar then
      if NBR_PITS[i]<=NBR_PITS[0] then
        physics.setAIPitStopRequest(i, true)
      end
    end
  end
  ui.toast(ui.Icons.Code, "All pitting engaged")
end



function NuzziAICopyPlayerFuel()
  for i = 1, aiDriverCount, 1
  do
    physics.setCarFuel(i, ac.getCar(0).fuel) -- Set ai fuel to the same as the players fuel
  end
end



function PitVarsInit()
  LAP_LAST_PIT[0]=0
  NBR_PITS[0]=0
  for i = 1, aiDriverCount, 1
  do
    LAP_LAST_PIT[i]=0
    NBR_PITS[i]=0
  end
end



function RefuelOnTheFly(pcar)
  if ac.getCar(pcar).fuel<20 and ac.getSim().isSessionStarted==true and pcar ~= safetycar then
    logline='Refuel on the fly ' .. pcar .. ' - ' .. ac.getCarName(pcar,false) .. ' - old fuel : ' .. math.floor(ac.getCar(pcar).fuel) .. ' - lap :' .. ac.getCar(pcar).lapCount
    StoreLogLine(logline)
    physics.setCarFuel(pcar, 120)
  end
end


function StoreLogLine(lline)
  lfound=false
  for k=1, i_log-1, 1 do
    if race_log[k] == lline then
      lfound=true
    end
  end
  if lfound==false then
    race_log[i_log]=lline
    i_log=i_log+1
  end
end


function CheckLogLine(lline)
  lfound=false
  for k=1, i_log-1, 1 do
    if race_log[k] == lline then
      lfound=true
    end
  end
  return lfound
end


function ResetFuelInPitlane()
  for i=1, aiDriverCount, 1 do
    if i ~= safetycar then
      if ac.getCar(i).isInPitlane == true then
        laps=ac.getCar(i).lapCount
        e=laps-LAP_LAST_PIT[i]
        if e>1 or LAP_LAST_PIT[i]==0 then
          physics.setCarFuel(i, 30)
          logline='Reducing fuel before stop ' .. i .. ' - ' .. ac.getCarName(i,false) .. ' - : ' .. math.floor(ac.getCar(i).fuel) .. ' - lap :' .. ac.getCar(i).lapCount
          StoreLogLine(logline)
        end
      end
    end
  end
end



function RecordLapPit()
end



function RaceLogSave()
  local filePath = ac.getFolder(tostring(ac.FolderID.ACAppsLua)) .. "\\fcy_yellow_rollingstart\\racelog.txt"
  local writeFile = io.open(filePath, "w")
  if writeFile ~= nil then
    for i=0, i_log-1, 1 do
      writeFile:write(race_log[i] .. "\n")
    end
  end
  ui.toast(ui.Icons.Code, "Log saved")
end



function ShowDecision()
  for r=0, index_cf-1, 1 do
    ui.text("cars_fault[" .. r .. "] : " .. cars_fault[r])
  end
  ui.text("index_cf : " .. index_cf)
  for r=1, ib-1, 1 do
    ui.text("cbox[" .. r .. "] : " .. cbox[r])
    ui.text("climit[" .. r .. "] : " .. climit[r])
  end
  ui.text("decision : " .. decision)
  ui.text("vcaution : " .. vcaution)
  if FCY==true then
    aFCY="true"
  else
    aFCY="false"
  end
  ui.text("FCY : " .. aFCY)
  if YELLOW_FLAG==true then
    aYELLOW_FLAG="true"
  else
    aYELLOW_FLAG="false"
  end
  ui.text("YELLOW_FLAG : " .. aYELLOW_FLAG)
  if trouve==true then
    atrouve="true"
  else
    atrouve="false"
  end
  ui.text("trouve : " .. atrouve)
end



function ShowLeaderboard()

  --if FCY==false and YELLOW_FLAG==false and SAFETY_CAR_INITIALIZED==false then
    --physics.setAITopSpeed(3,70)
  --end

  ui.newLine(10)
  for j=1, ac.getSim().carsCount, 1 do
    --if ac.getCar(ReturnCarInPos(j)).isInPit == false then
      --if j>1 then
        --vgap=ac.getGapBetweenCars(ReturnCarInPos(j-1),ReturnCarInPos(j))
        --vgaps=math.abs(ac.getCar(ReturnCarInPos(j-1)).splinePosition-ac.getCar(ReturnCarInPos(j)).splinePosition)
      --else
        --vgap=0
        --vgaps=0
      --end
      --ui.text(j .. ":" .. ac.getDriverName(ReturnCarInPos(j)) .. " - " .. math.floor(ac.getCar(ReturnCarInPos(j)).speedKmh) .. "[" .. math.floor(vgap) .. "]" .. " Sector:" .. ac.getCar(ReturnCarInPos(j)).currentSector .. " [pos:" .. ac.getCar(ReturnCarInPos(j)).splinePosition .. "]")
      --ui.text(j .. ":" .. ac.getDriverName(ReturnCarInPos(j)) .. " - " .. math.floor(ac.getCar(ReturnCarInPos(j)).speedKmh) .. "[t:" .. math.floor(vgap) .. "]" .. " Sector:" .. ac.getCar(ReturnCarInPos(j)).currentSector .. " [s:" .. vgaps .. "]")
    --end
    local vadd=""
    if ReturnCarInPos(j)==safetycar then
      vadd=" SC"
    else
      vadd=""
    end
    if ac.getCar(ReturnCarInPos(j)).isInPit == false then
      ui.text(j .. ' : car ' .. ReturnCarInPos(j) .. vadd .. ' - laps ' .. ac.getCar(ReturnCarInPos(j)).lapCount .. ' - speed : ' .. math.floor(ac.getCar(ReturnCarInPos(j)).speedKmh) .. " [pos:" .. ac.getCar(ReturnCarInPos(j)).splinePosition .. "]")
    end
    if ac.getCar(ReturnCarInPos(j)).isInPit == true then
      ui.text(j .. ' : car ' .. ReturnCarInPos(j) .. vadd .. ' - laps ' .. ac.getCar(ReturnCarInPos(j)).lapCount .. " - IN PIT")
    end
  end

  --pdiff=ac.getCar(safetycar).splinePosition-ac.getCar(ReturnCarInPos(1)).splinePosition
  --ui.text("safetycar_pos:" .. safetycar_pos)
  -- distance du leader au safetycar, tazomina supérieure à 0.002 fa tsy azo atao mihoatra ny 0.003
  -- sady tokony splineposition-ny safetycar no supérieure amin'ny an'ny leader
end






function DrawRed()
  ui.text("GET READY    ")
  p1=vec2(15,75)
  p2=vec2(100,100)
  ui.drawRectFilled(p1, p2, rgbm.colors.red, 5, 15)
  ui.newLine(15)
end

function DrawYellow(ptext)
  ui.text(ptext)
  p1=vec2(15,75)
  p2=vec2(100,100)
  ui.drawRectFilled(p1, p2, rgbm.colors.yellow, 5, 15)
  ui.newLine(15)
  ui.text("NO OVERTAKING")
end

function DrawFCY()
  if do_VSC==false then
    vtxt="FULL COURSE YELLOW"
    vtxtfl="FCY"
  else
    vtxt="VIRTUAL SAFETY CAR"
    vtxtfl="VSC"
  end
  ui.text(vtxt)
  p1=vec2(15,75)
  p2=vec2(100,100)
  ui.drawRectFilled(p1, p2, rgbm.colors.yellow, 5, 15)
  p1=vec2(102,75)
  p2=vec2(187,100)
  ui.drawRectFilled(p1, p2, rgbm.colors.yellow, 5, 15)
  p1=vec2(40,72)
  ui.dwriteDrawText(vtxtfl, 20, p1, rgbm.colors.black)
  p1=vec2(130,72)
  ui.dwriteDrawText(vtxtfl, 20, p1, rgbm.colors.black)
  ui.newLine(15)
  ui.text("NO OVERTAKING")
  ui.text("KEEP YOUR SPEED UNDER " .. P_MAX_SPEED_FCY .. " KM/H")
end

function DrawSC()
  if SC_IN_THIS_LAP == true then
    ui.text("SAFETY CAR IN THIS LAP")
  else
    ui.text("SAFETY CAR                        ")
  end
  p1=vec2(15,75)
  p2=vec2(100,100)
  ui.drawRectFilled(p1, p2, rgbm.colors.yellow, 5, 15)
  p1=vec2(102,75)
  p2=vec2(187,100)
  ui.drawRectFilled(p1, p2, rgbm.colors.yellow, 5, 15)
  p1=vec2(40,72)
  ui.dwriteDrawText("SC", 20, p1, rgbm.colors.black)
  p1=vec2(130,72)
  ui.dwriteDrawText("SC", 20, p1, rgbm.colors.black)
  ui.newLine(15)
  ui.text("NO OVERTAKING")
end

function DrawYellowGreen(ptext)
  ui.text(ptext)
  p1=vec2(15,75)
  p2=vec2(100,100)
  ui.drawRectFilled(p1, p2, rgbm.colors.yellow, 5, 15)
  p1=vec2(102,75)
  p2=vec2(187,100)
  ui.drawRectFilled(p1, p2, rgbm.colors.green, 5, 15)
  ui.newLine(15)
  ui.text("YOU ARE OUT OF                  ")
  ui.text("NEUTRALIZED SECTOR")
  ui.text("YOU CAN RACE AGAIN")
  ui.text("AND OVERTAKE")
end

function DrawGreen()
  ui.text("GREEN FLAG   ")
  p1=vec2(15,75)
  p2=vec2(100,100)
  ui.drawRectFilled(p1, p2, rgbm.colors.green, 5, 15)
  ui.newLine(15)
end

function GetRandomNumber()
  time_now=os.preciseClock()
  if math.abs(time_now-last_time)>3 then
    decision=math.random(100)
    ui.text(decision)
    last_time=os.preciseClock()
  else
    ui.text(decision)
  end
end




function ResumeRace()
  RLog("GREEN - caution over, race resumes")
  for i=1, aiDriverCount, 1 do
    if i ~= safetycar then
      physics.setAITopSpeed(i, 1e9)
    end
  end
  if safetycar ~= 0 then
    -- guard: with no SC on the grid, index 0 is the PLAYER
    physics.setAITopSpeed(safetycar, 70)
  end
  if YELLOW_FLAG == true then
    ui.toast(ui.Icons.Code, "GREEN FLAG ON SECTOR " .. YELLOW_FLAG_sector+1)
  end
  if FCY == true then
    ui.toast(ui.Icons.Code, "GREEN FLAG - GO GO GO !")
  end
  YELLOW_FLAG = false
  FCY = false
  DrawGreen()
  if PenaltyCAUTION==false then
    RadioMessage("green.mp3")
  end
end




function ShowCautionInfo()
  ui.text("Caution duration : " .. cautionDuration)
  for j=1, ac.getSim().carsCount, 1 do
    if ac.getCar(ReturnCarInPos(j)).isInPit == false then
      if j>1 then
        vgap=ac.getGapBetweenCars(ReturnCarInPos(j-1),ReturnCarInPos(j))
      else
        vgap=0
      end
      ui.text(j .. ":" .. ReturnCarInPos(j) .. " - " .. math.floor(ac.getCar(ReturnCarInPos(j)).speedKmh) .. "[" .. vgap .. "]")
    end
  end
end



function SlowDown()
  for i=0, aiDriverCount, 1 do
    if i~=0 then
      physics.setAITopSpeed(i, P_MAX_SPEED_FCY)
    end
  end
end


function ShowFormationInfo()
  for j=1, ac.getSim().carsCount, 1 do
    if ac.getCar(ReturnCarInPos(j)).isInPit == false then
      if j>1 then
        vgap=ac.getGapBetweenCars(ReturnCarInPos(j-1),ReturnCarInPos(j))
      else
        vgap=0
      end
      --ui.text(j .. "." .. ac.getCarName(ReturnCarInPos(j),false) .. ":" .. ReturnCarInPos(j) .. " - " .. math.floor(ac.getCar(ReturnCarInPos(j)).speedKmh) .. "[" .. vgap .. "]")
      ui.text(j .. "." .. ac.getCarName(ReturnCarInPos(j),false) .. ":" .. ReturnCarInPos(j) .. " - start order: " .. startOrder[ReturnCarInPos(j)] .. "[" .. vgap .. "]")
    end
  end
end


function SlowDownAndRegroupFormation()
  if FORMATION_BEHIND_CATCH==true then
    FormationAccelBehindPlayer()
  else
    -- natural tire-warming formation: every driver weaves with their own
    -- rhythm (amplitude / period / phase) and does accel-brake bursts, like
    -- a real field warming tires. In the last ~15% of the lap weaving stops
    -- and the pack forms up for the green.
    if WEAVE_T0 == nil then WEAVE_T0 = os.preciseClock() end
    local wt = os.preciseClock() - WEAVE_T0
    if CAUTION_SET==false then
      -- make the AI keep a bigger cushion to the car ahead for the whole
      -- formation lap (restored to normal at the green flag)
      for k=1, aiDriverCount, 1 do
        if k ~= safetycar then
          physics.setAICaution(k, 3)
        end
      end
      CAUTION_SET=true
    end
    local leadcar = LeadRaceCar()
    if FORMUP==false and leadcar ~= nil and ac.getCar(leadcar).lapCount==0
       and ac.getCar(leadcar).splinePosition>0.85 and FORM_KM0 ~= nil then
      -- distance driven since THIS formation lap began. The old absolute
      -- session-km check broke on restarts: the session odometer is not
      -- reset, and on grids parked past 85% of the spline both conditions
      -- were instantly true - FORMUP fired seconds into the lap and shut
      -- the tire-warming down for the entire formation (log: FORMUP at
      -- +5.6 s after two restarts)
      local lapkm = ac.getSim().trackLengthM / 1000
      local driven = ac.getCar(leadcar).distanceDrivenSessionKm - FORM_KM0
      if driven > 0.6*lapkm then
        FORMUP=true
        RLog(string.format(
          "FORMUP: leader at spline %.2f, %.2f km driven this formation (lap %.2f km)",
          ac.getCar(leadcar).splinePosition, driven, lapkm))
        ui.toast(ui.Icons.Code, "FORM UP - GREEN FLAG IS COMING")
      end
    end
    if #startSeq==0 then BuildStartSeq() end

    -- ==== field-formed check: nobody warms tires until EVERY pair in the
    -- train is properly spaced and up to speed ====
    if WEAVE_ALLOWED==false then
      local formed = true
      local pairs_checked = 0
      for j=2, ac.getSim().carsCount, 1 do
        local a = ReturnCarInPos(j-1)
        local b = ReturnCarInPos(j)
        if a ~= nil and b ~= nil
           and sc_duplicates[a]==nil and sc_duplicates[b]==nil
           and (a==safetycar or CarRunning(a)) and CarRunning(b) then
          local g = math.abs(ac.getGapBetweenCars(a, b))
          if g < 0.35 or g > 2.5 then
            formed = false
            break
          end
          if b ~= 0 and ac.getCar(b).speedKmh < 40 then
            formed = false
            break
          end
          pairs_checked = pairs_checked + 1
        end
      end
      if formed == true and pairs_checked > 0 then
        WEAVE_ALLOWED = true
        WEAVE_T1 = os.preciseClock()
        ui.toast(ui.Icons.Code, "FIELD FORMED - WARM THOSE TIRES")
      end
    end

    -- ==== detect accidental overtakes against the starting order ====
    -- For every car, find who SHOULD be directly ahead (skipping cars that
    -- retired or pitted - those places are gained legitimately). If that
    -- car is now behind, both sides cooperate: the gainer pulls offline and
    -- slows, the wronged car speeds up and repasses on the racing line.
    local gained = {}
    local lost = {}
    for k=2, #startSeq, 1 do
      local me = startSeq[k]
      if me ~= safetycar and CarRunning(me) then
        local e = nil
        for j=k-1, 1, -1 do
          local c = startSeq[j]
          if c == safetycar or CarRunning(c) then
            e = c
            break
          end
        end
        if e ~= nil and e ~= safetycar then
          if ac.getCar(e).racePosition > ac.getCar(me).racePosition then
            gained[me] = true
            lost[e] = true
          end
        end
      end
    end

    for i=1, aiDriverCount, 1 do
      if i ~= safetycar then
        -- ==== chain following: match the nearest RUNNING car ahead ====
        -- P1 matches the safety car, P2 matches P1, and so on down the
        -- train. Cars sitting in the pits or retired are skipped - matching
        -- a parked car's 0 km/h is how trains used to stall and open giant
        -- gaps. Personal cushion 0.7-1.3 s.
        local mypos = ac.getCar(i).racePosition
        local ahead = nil
        local p = mypos - 1
        while p >= 1 do
          local c = ReturnCarInPos(p)
          if c ~= nil and (c == safetycar and ac.getCar(c).isInPitlane == false
                           or c ~= safetycar and CarRunning(c)) then
            ahead = c
            break
          end
          p = p - 1
        end
        local gap_ahead = nil
        if ahead ~= nil then
          gap_ahead = math.abs(ac.getGapBetweenCars(ahead, i))
        end

        local cmin = TUNE.cushionMin
        local cmax = math.max(TUNE.cushionMax, cmin + 0.1)
        local tgt = cmin + (cmax - cmin)*DriverHash(i,7)  -- own spot in the cushion range
        local hurrygap = TUNE.catchHurryGap
        local flatgap = math.max(TUNE.catchFlatGap, hurrygap + 0.5)
        local vspeed
        local catching = false
        if ahead == nil then
          -- nothing ahead at all (no SC on track): set a steady pace
          vspeed = P_FORMATION_SPEED
        elseif gap_ahead > flatgap then
          -- dropped way back: NO rules, no limits, no weaving - just push
          -- flat out until the train is back in sight
          vspeed = 1e9
          catching = true
        elseif gap_ahead > hurrygap then
          -- closing in: still hurrying, but bounded so the approach speed
          -- bleeds off progressively instead of arriving like a missile
          local va = math.max(ac.getCar(ahead).speedKmh, 40)
          vspeed = va + TUNE.catchHurrySpeed
          catching = true
        else
          local va = math.max(ac.getCar(ahead).speedKmh, 40)
          local corr = (gap_ahead - tgt) * 25
          if corr > 20 then corr = 20 end
          if corr < -25 then corr = -25 end
          vspeed = va + corr
          if gap_ahead < 0.3 then
            vspeed = va - 25                      -- too close: back out
          end
        end

        local noweave = false
        if catching == true then
          -- far behind: catch-up overrides everything, swaps sort
          -- themselves out once the train is back together
          gained[i] = nil
          lost[i] = nil
        end
        if gained[i] == true then
          -- I took a place I should not have: get off the line, lift, and
          -- wave the other car through
          SmoothOffset(i, 0.45)
          vspeed = P_FORMATION_SPEED - 20
          noweave = true
        elseif lost[i] == true then
          -- a place is owed to me: stay on the racing line and take it back
          SmoothOffset(i, 0)
          vspeed = P_FORMATION_SPEED + 25
          noweave = true
        end

        if vspeed < 40 then vspeed = 40 end
        if catching == false then
          if FORMUP == true then
            -- green is coming: the whole train settles to the base pace
            -- (small +15 headroom so late gaps still close onto the SC's
            -- 110 instead of freezing in place)
            if vspeed > P_FORMATION_SPEED + 15 then vspeed = P_FORMATION_SPEED + 15 end
          elseif vspeed > 165 then
            vspeed = 165
          end
        end
        physics.setAITopSpeed(i, vspeed)
        -- ~65% of full push during the formation; full beans only when
        -- catching up. Restored to 100% at the green flag.
        if catching == true then
          physics.setAIThrottleLimit(i, 1)
        else
          physics.setAIThrottleLimit(i, 0.65)
        end

        if catching == true then
          noweave = true
          bias_smooth[i] = 0                      -- catch up on the racing line
          weave_gain[i] = 0                       -- and re-ease into the sweep after
          SmoothOffset(i, 0)                      -- no weaving, pure push
        end

        if noweave == false then
          if FORMUP==true then
            -- lock back onto the racing line decisively (faster recenter
            -- than the normal smoothing, still eased - no snap)
            bias_smooth[i] = 0
            weave_gain[i] = 0
            SmoothOffset(i, 0, 7.0)
          else
            -- layer 1 - gentle human wander: small, slow, ever-present
            -- drift around the line, the micro-corrections of a real hand
            -- on the wheel. This runs from the moment the cars are rolling.
            local wamp = 0.05 + 0.05*DriverHash(i,4)  -- subtle: 5-10%
            local wper = 6.0  + 3.5*DriverHash(i,5)   -- long lazy 6-9.5 s drift
                                                      -- (stretched for the
                                                      -- 110 km/h base pace)
            local wph  = 6.2831*DriverHash(i,6)
            local wander = wamp * math.sin(6.2831*wt/wper + wph)

            -- layer 2 - maximum-effort tire warming: big committed sweeps,
            -- like a driver fighting cold tires. Each driver joins in at
            -- their own moment (0-6 s after the field forms) and blends
            -- from the wander into the full sweep over ~2 s.
            local amp = (0.62 + 0.16*DriverHash(i,1)) * TUNE.weaveWidth
                                                      -- 62-78% of the lane at
                                                      -- 1.00x: proper
                                                      -- tire-scrubbing sweeps
            if amp > 0.95 then amp = 0.95 end         -- full sweep must still
                                                      -- fit inside the road
            local per = (2.9 + 0.7*DriverHash(i,2)) * TUNE.weaveRhythm
                                                      -- full cycle 2.9-3.6 s:
                                                      -- tight, committed
                                                      -- rhythm. Stability
                                                      -- comes from the
                                                      -- corner gate, the
                                                      -- steering smoother
                                                      -- and the edge-fit,
                                                      -- which all still
                                                      -- apply on top
            local ph  = 6.2831*DriverHash(i,3)
            local weave = amp * math.sin(6.2831*wt/per + ph)

            local off = wander
            if WEAVE_ALLOWED == true and WEAVE_T1 ~= nil then
              local since = os.preciseClock() - WEAVE_T1 - 6.0*DriverHash(i,8)
              if since > 0 then
                local r = since / 2.0
                if r > 1 then r = 1 end
                off = wander*(1.0-r) + weave*r
              end
            end

            -- corner gate + mid-track envelope: bias eases toward the
            -- driver's spot while it is safe to use the road, eases back
            -- to 0 (racing line) through corners/braking, slides off the
            -- edges so the full sweep always fits, and moves to the
            -- emptier side when someone is close ahead - so the weave
            -- itself never has to pause for traffic
            local unsafe = WeaveUnsafeHere(i)
            local rolling = ac.getCar(i).speedKmh > 40
            local bias = UpdateMidTrackBias(i, rolling and unsafe == false,
                                            amp, ahead, gap_ahead)

            -- the sweep fades in/out through its own slow per-car gain
            -- instead of branch-switching targets, so the gating (corners,
            -- braking) can never step the steering - one continuous
            -- confident repetitive motion
            local want = 0
            if rolling and unsafe == false then want = 1 end
            local g = weave_gain[i] or 0
            local grate = 0.5                     -- ease into the sweep ~2 s
            if want < g then grate = 0.9 end      -- ease out a bit quicker
            local gb = grate * ui.deltaTime()
            if gb > 1 then gb = 1 end
            g = g + (want - g)*gb
            weave_gain[i] = g

            if rolling then
              -- g=1: full sweep on the biased envelope; g=0: just a trace
              -- of wander holding the line; anything between blends
              SmoothOffset(i, bias + off*g + wander*0.4*(1.0 - g))
            else
              SmoothOffset(i, 0)
            end
          end
        end
      else
        if do_SC_FORMATION_LAP==true and ASSIGNED_POS==true and ac.getCar(safetycar).isInPitlane==false then
          -- SC sets the field pace; P2's speed is owned by the chain
          -- controller above (it matches the SC like everyone else)
          gap=math.abs(ac.getGapBetweenCars(safetycar, ReturnCarInPos(2)))
          if gap>1 then
            physics.setAITopSpeed(safetycar, P_FORMATION_SPEED-20)
          else
            physics.setAITopSpeed(safetycar, P_FORMATION_SPEED)
          end
          ac.debug("gap sc - pole formation", gap)
        end
      end
    end
  end
end



function FormationAccelBehindPlayer()
  if FORMATION_LAP == true then
    pos_player=ac.getCar(0).racePosition
    for i=pos_player+1, aiDriverCount+1, 1 do
      if ReturnCarInPos(i) ~= safetycar then
        ai_behind_player=ReturnCarInPos(i)
        physics.setAITopSpeed(ai_behind_player,160)
      end
    end
  end
end



function WhoIsNotInPlace()
  for i=1, aiDriverCount, 1 do
    if i ~= ReturnCarInPos(i) then
      return i
    end
  end
  return -1
end

function SetLeaderBoardArray()
  -- removed safety car clones are forced to the ABSOLUTE back of the
  -- order, and the real field is re-indexed contiguously 1..N, so no
  -- position logic anywhere in the app ever trips over a parked clone
  local order={}
  for i=0, aiDriverCount, 1 do
    tpos[i]=ac.getCar(i).racePosition
    order[#order+1]=i
  end
  -- rank groups: 1 = real racers, 2 = safety car BEFORE the session starts
  -- (parks it 2nd-to-last so the pre-start order never sees it mid-pack;
  -- once the session runs it earns P1 naturally by being out front),
  -- 3 = removed clones, always dead last
  local pre = ac.getSim().isSessionStarted == false
  local function rankgroup(c)
    if sc_duplicates[c] ~= nil then return 3 end
    if pre and safetycar ~= nil and safetycar ~= 0 and c == safetycar then
      return 2
    end
    return 1
  end
  table.sort(order, function(a,b)
    local ra = rankgroup(a)
    local rb = rankgroup(b)
    if ra ~= rb then return ra < rb end
    return tpos[a] < tpos[b]
  end)
  for rank=1, #order, 1 do
    tpos[order[rank]]=rank
  end
end

function ReturnCarInPos(p)
  SetLeaderBoardArray()
  for i=0,aiDriverCount,1 do
    if tpos[i]==p then
      return i
    end
  end
end


function EnablePhysics()
  local trackFolderPath = ac.getFolder(tostring(ac.FolderID.ContentTracks)) .. "\\" .. ac.getTrackID()
  local surfacesFilePath = trackFolderPath .. "\\" .. ac.getTrackLayout() .. "\\data\\surfaces.ini"
  local surfacesIni = ac.INIConfig.load(surfacesFilePath, ac.INIFormat.Default)
  surfacesIni:setAndSave("SURFACE_0", "WAV_PITCH", "extended-0")
  surfacesIni:setAndSave("_SCRIPTING_PHYSICS", "ALLOW_APPS", "1")
end

function DisablePhysics()
  -- Get surfaces.ini file path
  local trackFolderPath = ac.getFolder(tostring(ac.FolderID.ContentTracks)) .. "\\" .. ac.getTrackID()
  local surfacesFilePath = trackFolderPath .. "\\" .. ac.getTrackLayout() .. "\\data\\surfaces.ini"

  -- Read all lines from surfaces.ini (apart those we want to delete)
  local newLines = {}
  local readFile = io.open(surfacesFilePath, "r")
  if readFile ~= nil then
    for line in readFile:lines() do
      if line == "ALLOW_APPS=1" or line == "[_SCRIPTING_PHYSICS]" then
        -- Ignore these lines are for removal
      elseif  line == "WAV_PITCH=extended-0" then
       table.insert(newLines, "WAV_PITCH=0")
      else
        table.insert(newLines, line)
      end
    end
  end

  -- Re-write the new version of the file
  local writeFile = io.open(surfacesFilePath, "w+")
  if writeFile ~= nil then
    for i = 1, #newLines, 1 do
      writeFile:write(newLines[i] .. "\n")
      ac.log(newLines[i])
    end
  end

  ac.log("Physics Disabled.")
end
