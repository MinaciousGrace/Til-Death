------------------------------------------------------
--Methods for generating IIDX-esque ClearType texts --
------------------------------------------------------
--EDIT: scores no longer needed since it grabs it for you

local stypetable = { -- Shorthand Versions of ClearType. Not Really used anywhere yet but who knows
	[1]="MFC",
	[2]="WF",
	[3]="SDP",
	[4]="PFC",
	[5]="BF",
	[6]="SDG",
	[7]="FC",
	[8]="MF",
	[9]="SDCB",
	[10]="Clear",
	[11]="Failed",
	[12]="Invalid",
	[13]="No Play",
	[14]="-", -- song is nil
	--[15]="Ragequit", -- can't implement unless there's a way to track playcounts by difficulty
};

local typetable = { -- ClearType texts
	[1]="MFC",
	[2]="WF",
	[3]="SDP",
	[4]="PFC",
	[5]="BF",
	[6]="SDG",
	[7]="FC",
	[8]="MF",
	[9]="SDCB",
	[10]="Clear",
	[11]="Failed",
	[12]="Invalid",
	[13]="No Play",
	[14]="-",
	--[15]="Ragequit", -- can't implement unless there's a way to track playcounts by difficulty
};

local typecolors = {-- colors corresponding to cleartype
	[1]		= color(colorConfig:get_data().clearType["MFC"]),
	[2]		= color(colorConfig:get_data().clearType["WF"]),
	[3] 	= color(colorConfig:get_data().clearType["SDP"]),
	[4] 	= color(colorConfig:get_data().clearType["PFC"]),
	[5]		= color(colorConfig:get_data().clearType["BF"]),
	[6]		= color(colorConfig:get_data().clearType["SDG"]),
	[7]		= color(colorConfig:get_data().clearType["FC"]),
	[8]		= color(colorConfig:get_data().clearType["MF"]),
	[9]		= color(colorConfig:get_data().clearType["SDCB"]),
	[10]	= color(colorConfig:get_data().clearType["Clear"]),
	[11]	= color(colorConfig:get_data().clearType["Failed"]),
	[12]	= color(colorConfig:get_data().clearType["Invalid"]),
	[13]	= color(colorConfig:get_data().clearType["NoPlay"]),
	[14]	= color(colorConfig:get_data().clearType["None"]),
	--[15]	= color("#e61e25"),
};


-- Methods for other uses (manually setting colors/text, etc.)
local function getClearTypeText(index)
	return typetable[index];
end;

local function getShortClearTypeText(index)
	return stypetable[index];
end;

local function getClearTypeColor(index)
	return typecolors[index];
end;

local function getClearTypeItem(clearlevel,ret)
	if ret == 0 then
		return typetable[clearlevel];
	elseif ret == 1 then
		return stypetable[clearlevel];
	elseif ret == 2 then
		return typecolors[clearlevel];
	else
		return clearlevel
	end;
end;

-- ClearTypes based on stage awards and grades.
-- Stageaward based cleartypes do not work if anything causes the stageaward to not show up (disqualification, score saving is off, etc.)
-- and will just result in "No Play" or "Clear". I migggggggggght just drop the SA usage and use raw values instead.
-- returntype 	=0 -> ClearType, 
--				=1 -> ShortClearType, 
-- 				=2 -> ClearTypeColor, 
-- 				=else -> ClearTypeLevel
local function clearTypes(stageaward,grade,playcount,misscount,returntype)
	stageaward = stageaward or 0; -- initialize everything incase some are nil
	grade = grade or 0;
	playcount = playcount or 0;
	misscount = misscount or 0;

	clearlevel = 13; -- no play

	if grade == 0 then
		if playcount == 0 then
			clearlevel = 13;
		end;
	else
		if grade == 'Grade_Failed' then -- failed
			clearlevel = 11;
		elseif stageaward == 'StageAward_SingleDigitW2'then -- SDP
			clearlevel = 3;
		elseif stageaward == 'StageAward_SingleDigitW3' then -- SDG
			clearlevel = 6;
		elseif stageaward == 'StageAward_OneW2' then -- whiteflag
			clearlevel = 2;
		elseif stageaward == 'StageAward_OneW3' then -- blackflag
			clearlevel = 5;
		elseif stageaward == 'StageAward_FullComboW1' or grade == 'Grade_Tier01' then -- MFC
			clearlevel = 1;
		elseif stageaward == 'StageAward_FullComboW2' or grade == 'Grade_Tier02'then -- PFC
			clearlevel = 4;
		elseif stageaward == 'StageAward_FullComboW3' then -- FC
			clearlevel = 7;
		else
			if misscount == 1 then 
				clearlevel = 8; -- missflag
			else
				clearlevel = 10; -- Clear
			end;
		end;
	end;
	return getClearTypeItem(clearlevel,returntype)
end;


--Returns the cleartype of the top score
function getClearType(pn,ret)
	local song
	local steps
	local profile
	local hScoreList
	local hScore
	local playCount = 0
	local stageAward
	local missCount = 0
	local grade
	song = GAMESTATE:GetCurrentSong()
	steps = GAMESTATE:GetCurrentSteps(pn)
	profile = GetPlayerOrMachineProfile(pn)
	if song ~= nil and steps ~= nil then
		hScoreList = profile:GetHighScoreList(song,steps):GetHighScores()
		hScore = hScoreList[1]
	end;
	if hScore ~= nil then
		-- 00 Utility.lua
		if not isScoreValid(pn,steps,hScore) then
			return getClearTypeItem(12,ret)
		end
		playCount = profile:GetSongNumTimesPlayed(song)
		missCount = hScore:GetTapNoteScore('TapNoteScore_Miss')+hScore:GetTapNoteScore('TapNoteScore_W5')+hScore:GetTapNoteScore('TapNoteScore_W4');
		grade = hScore:GetGrade()
		stageAward = hScore:GetStageAward()
	end;
	return clearTypes(stageAward,grade,playCount,missCount,ret); 
end;

-- Returns the cleartype given the score
function getClearTypeFromScore(pn,score,ret)
	local song
	local steps
	local profile
	local playCount = 0
	local stageAward
	local missCount = 0
	if score == nil then
		return getClearTypeItem(13,ret)
	end;
	song = GAMESTATE:GetCurrentSong()
	steps = GAMESTATE:GetCurrentSteps(pn)
	profile = GetPlayerOrMachineProfile(pn)
	if not isScoreValid(pn,steps,score) then
		return getClearTypeItem(12,ret)
	end
	if score ~= nil and song ~= nil and steps ~= nil then
		playCount = profile:GetSongNumTimesPlayed(song)
		stageAward = score:GetStageAward();
		grade = score:GetGrade();
		missCount = score:GetTapNoteScore('TapNoteScore_Miss')+score:GetTapNoteScore('TapNoteScore_W5')+score:GetTapNoteScore('TapNoteScore_W4');
	end;

	return clearTypes(stageAward,grade,playCount,missCount,ret) or typetable[12]; 
end;

-- Returns the highest cleartype
function getHighestClearType(pn,ignore,ret)
	local song
	local steps
	local profile
	local hScoreList
	local hScore
	local i = 1
	local highest = 13

	song = GAMESTATE:GetCurrentSong()
	steps = GAMESTATE:GetCurrentSteps(pn)
	profile = GetPlayerOrMachineProfile(pn)
	if song ~= nil and steps ~= nil then
		hScoreList = profile:GetHighScoreList(song,steps):GetHighScores()
	end;
	if hScoreList ~= nil then
		while i <= #hScoreList do
			if i ~= ignore then
				hScore = hScoreList[i]
				if hScore ~= nil then
					highest = math.min(highest,getClearTypeFromScore(pn,hScore,3))
				end;
			end;
			i = i+1
		end;
	end;
	if ret == 0 then
		return getClearTypeText(highest)
	elseif ret == 1 then
		return getShortClearTypeText(highest)
	elseif ret == 2 then
		return getClearTypeColor(highest)
	else
		return highest
	end;
end;
