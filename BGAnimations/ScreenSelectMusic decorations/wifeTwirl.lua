-- **Initialize the point tables that will be used to calculate scores**
if #scoringTypes[1].PointTable == 0 then
	initPointTables() -- boop
end

if not isJudgeSame() then
	ms.ok("Updating point tables for: J"..GetTimingDifficulty())
	updatePointTables()
end


if playerConfig:get_data(pn_to_profile_slot(PLAYER_1)).OneShotMirror then
	local modslevel = topscreen  == "ScreenEditOptions" and "ModsLevel_Stage" or "ModsLevel_Preferred"
	local playeroptions = GAMESTATE:GetPlayerState(PLAYER_1):GetPlayerOptions(modslevel)
	playeroptions:Mirror( false )
end

local frameX = 10
local frameY = 250+capWideScale(get43size(120),120)
local frameWidth = capWideScale(get43size(455),455)
local scoreType = themeConfig:get_data().global.DefaultScoreType
local Meta
local bestscore
local song
local alreadybroadcasted

-- **Set the stage... and... curtains**
local update = false
local t = Def.ActorFrame{
	BeginCommand=cmd(queuecommand,"Set"),
	OffCommand=cmd(bouncebegin,0.2;xy,-500,0;diffusealpha,0),
	OnCommand=cmd(bouncebegin,0.2;xy,0,0;diffusealpha,1),
	SetCommand=function(self)
		self:finishtweening()
		if getTabIndex() == 0 then
			self:queuecommand("On")
			update = true
		else 
			self:queuecommand("Off")
			update = false
		end
	end,
	TabChangedMessageCommand=cmd(queuecommand,"Set"),
}

-- Updated but still need a better system for this
t[#t+1] = LoadFont("Common Large") .. {
	InitCommand=cmd(xy,18,SCREEN_BOTTOM-225;visible,true;halign,0;zoom,0.4;maxwidth,capWideScale(get43size(360),360)/capWideScale(get43size(0.45),0.45)),
	BeginCommand=function(self)
		self:settext(getCurRateDisplayString())
	end,
	CodeMessageCommand=function(self,params)
		local rate = getCurRateValue()
		if params.Name == "PrevScore" and rate < 2 and  getTabIndex() == 0 then
			GAMESTATE:GetSongOptionsObject('ModsLevel_Preferred'):MusicRate(rate+0.1)
			MESSAGEMAN:Broadcast("CurrentRateChanged")
		elseif params.Name == "NextScore" and rate > 0.7 and  getTabIndex() == 0 then
			GAMESTATE:GetSongOptionsObject('ModsLevel_Preferred'):MusicRate(rate-0.1)
			MESSAGEMAN:Broadcast("CurrentRateChanged")
		end
		self:settext(getCurRateDisplayString())
	end,
}

-- Temporary update control tower; it would be nice if the basic song/step change commands were thorough and explicit and non-redundant
t[#t+1] = Def.Actor{
	SetCommand=function(self)
		if song and not alreadybroadcasted then 		-- if this is true it means we've just exited a pack's songlist into the packlist
			song = GAMESTATE:GetCurrentSong()			-- also apprently true if we're tabbing around within a songlist and then stop...
			MESSAGEMAN:Broadcast("UpdateChart")			-- ms.ok(whee:GetSelectedSection( )) -- use this later to detect pack changes
			MESSAGEMAN:Broadcast("RefreshChartInfo")
		else
			alreadybroadcasted = false
		end
	end,
	CurrentStepsP1ChangedMessageCommand=function(self)	
		song = GAMESTATE:GetCurrentSong()			
		MESSAGEMAN:Broadcast("UpdateChart")
		alreadybroadcasted = true
	end,
	CurrentSongChangedMessageCommand=cmd(queuecommand,"Set"),
}

t[#t+1] = Def.Actor{
	SetCommand=function(self)		
		if song then 
			local steps = GAMESTATE:GetCurrentSteps(PLAYER_1)
				getCurKey()
			if steps:GetStepsType() == "StepsType_Dance_Single"	 then
				msTableChartUpdate(song, steps)
				Meta = getCurChart().ChartMeta
				bestscore = getRateScoresBestScore(getCurRateScores(), scoreType, "Grade_Failed") 	-- look for the best non-fail score on the current rate
				if not bestscore then 
					bestscore = getAlternativeBestRateScores(scoreType)		-- if nothing is found loop through the score table to find the best non-fail score
				end															-- if still nothing is found, display the best failed score found starting with the
				MESSAGEMAN:Broadcast("RefreshChartInfo")					-- currently selected rate and then descending downwards from the highest rate played
			end
		end
	end,
	UpdateChartMessageCommand=cmd(queuecommand,"Set"),
	CurrentRateChangedMessageCommand=function()
		bestscore = getRateScoresBestScore(getCurRateScores(), scoreType, "Grade_Failed") 	-- look for the best non-fail score on the current rate
		if not bestscore then 
			bestscore = getAlternativeBestRateScores(scoreType)		-- if nothing is found loop through the score table to find the best non-fail score
		end		
	end,
}

t[#t+1] = Def.ActorFrame{
	-- **frames/bars**
	Def.Quad{InitCommand=cmd(xy,frameX,frameY-76;zoomto,110,94;halign,0;valign,0;diffuse,color("#333333CC");diffusealpha,0.66)},			--Upper Bar
	Def.Quad{InitCommand=cmd(xy,frameX,frameY+18;zoomto,frameWidth+4,50;halign,0;valign,0;diffuse,color("#333333CC");diffusealpha,0.66)},	--Lower Bar
	Def.Quad{InitCommand=cmd(xy,frameX,frameY-76;zoomto,8,144;halign,0;valign,0;diffuse,getMainColor('highlight');diffusealpha,0.5)},		--Side Bar (purple streak on the left)

	-- **Score related stuff** These need to be updated with rate changed commands
	-- Percent score
	LoadFont("Common Large")..{
		InitCommand=cmd(xy,frameX+55,frameY+50;zoom,0.6;halign,0.5;maxwidth,125;valign,1),
		BeginCommand=cmd(queuecommand,"Set"),
		SetCommand=function(self)
			if song and bestscore then
				if isFallbackScoreType() == true then
					self:settextf("%05.2f%%", bestscore.ScoreTable[getfallbackscoreType()].Percent)
					self:diffuse(getGradeColor(bestscore.Metadata.Grade))
				else
					self:settextf("%05.2f%%", bestscore.ScoreTable[scoreType].Percent)
					self:diffuse(getGradeColor(bestscore.Metadata.Grade))
				end
			else
				self:settext("")
			end
		end,
		RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
		CurrentRateChangedMessageCommand=cmd(queuecommand,"Set"),
	},
	
	-- ScoreType for the given score being displayed
	LoadFont("Common Normal")..{
		InitCommand=cmd(xy,frameX+125,frameY+50;zoom,0.5;halign,1;valign,1),
		BeginCommand=cmd(queuecommand,"Set"),
		SetCommand=function(self)
			if song and bestscore then 
				if isFallbackScoreType() == true then
					self:settext(scoringToText(getfallbackscoreType()).."*")
				else
					self:settext(scoringToText(scoreType))
				end
			else
				self:settext("")
			end
		end,
		CurrentRateChangedMessageCommand=cmd(queuecommand,"Set"),
		RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
	},
	
	-- Rate for the displayed score
	LoadFont("Common Normal")..{
		InitCommand=cmd(xy,frameX+55,frameY+58;zoom,0.5;halign,0.5),
		BeginCommand=cmd(queuecommand,"Set"),
		SetCommand=function(self)
			if song and bestscore then 
			local rate = bestscore.Metadata.Rate
				if getCurRateString() ~= rate then
					self:settext("("..rate..")")
				else
					self:settext(rate)
				end
			else
				self:settext("")
			end
		end,
		CurrentRateChangedMessageCommand=cmd(queuecommand,"Set"),
		RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
	},
	
	-- Date score achieved on
	LoadFont("Common Normal")..{
		InitCommand=cmd(xy,frameX+175,frameY+49;zoom,0.4;halign,0),
		BeginCommand=cmd(queuecommand,"Set"),
		SetCommand=function(self)
			if song and bestscore then
					self:settext(bestscore.Metadata.DateAchieved)
				else
					self:settext("")
				end
		end,
		CurrentRateChangedMessageCommand=cmd(queuecommand,"Set"),
		RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
	},

	-- MaxCombo
	LoadFont("Common Normal")..{
		InitCommand=cmd(xy,frameX+175,frameY+35;zoom,0.4;halign,0),
		BeginCommand=cmd(queuecommand,"Set"),
		SetCommand=function(self)
			if song and bestscore then
				self:settextf("Max Combo: %d", bestscore.Metadata.MaxCombo)
			else
				self:settext("")
			end
		end,
		CurrentRateChangedMessageCommand=cmd(queuecommand,"Set"),
		RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
	},
	-- **End score related stuff**
	
	-- ChartKey, mostly being displayed for debug/checking purposes
	LoadFont("Common Normal")..{
		InitCommand=cmd(xy,frameX+100,frameY+24;zoom,0.4;halign,0),
		BeginCommand=cmd(queuecommand,"Set"),
		SetCommand=function(self)
			if song then
				self:settext(GAMESTATE:GetCurrentSteps(PLAYER_1):GetWifeChartKey())
			else
				self:settext("")
			end
		end,
		RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
	},
	-- LoadFont("Common Normal")..{
		-- InitCommand=cmd(xy,frameX+100,frameY+4;zoom,0.4;halign,0),
		-- ChartInfoMessageCommand=function(self, msg)
			-- self:settext(msg.ChartKey)
		-- end
	-- },
}

-- "Radar values" aka basic chart information
local function radarPairs(i)
	local o = Def.ActorFrame{
		LoadFont("Common Normal")..{
			InitCommand=cmd(xy,frameX+13,frameY-52+13*i;zoom,0.5;halign,0;maxwidth,120),
			SetCommand=function(self)
				if song then
					self:settext(ms.RelevantRadarsShort[i])
				else
					self:settext("")
				end
			end,
			RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
		},
		LoadFont("Common Normal")..{
			InitCommand=cmd(xy,frameX+105,frameY+-52+13*i;zoom,0.5;halign,1;maxwidth,60),
			SetCommand=function(self)
				if song then		
					self:settext(Meta.RadarValues[ms.RelevantRadars[i]])
				else
					self:settext("")
				end
			end,
			RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
		},
		
		LoadFont("Common Normal")..{														-- doesnt look nice on the general screen will move it later to the simfile tab i guess
			InitCommand=cmd(xy,frameX+80,frameY+-52+13*i;zoom,0.5;halign,0;maxwidth,50),
			SetCommand=function(self)
				if song and i ~= 1 then					
					--pself:settextf("%4.1f%%", Meta.RadarValues[ms.RelevantRadars[i]]/Meta.RadarValues[ms.RelevantRadars[1]]*100) 
				else
					self:settext("")
				end
			end,
			RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
			
		},
	}
	return o
end

-- Create the radar values
for i=1,5 do
	t[#t+1] = radarPairs(i)
end

-- Difficulty value ("meter"), need to change this later
t[#t+1] = LoadFont("Common Large") .. {
	InitCommand=cmd(xy,frameX+58,frameY-62;halign,0.5;zoom,0.6;maxwidth,110/0.6);
	BeginCommand=cmd(queuecommand,"Set");
	SetCommand=function(self)
		if song then
			local meter = GAMESTATE:GetCurrentSteps(PLAYER_1):GetMeter()
			self:settext(meter)
			self:diffuse(byDifficultyMeter(meter))
		else
			self:settext("")
		end
	end;
	RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
}

-- Song duration
t[#t+1] = LoadFont("Common Large") .. {
	InitCommand=cmd(xy,(capWideScale(get43size(384),384))+62,SCREEN_BOTTOM-85;visible,true;halign,1;zoom,capWideScale(get43size(0.6),0.6);maxwidth,capWideScale(get43size(360),360)/capWideScale(get43size(0.45),0.45));
	BeginCommand=cmd(queuecommand,"Set");
	SetCommand=function(self)
		if song then
			self:settext(SecondsToMMSS(Meta.Duration))
			self:diffuse(getSongLengthColor(Meta.Duration))
		else
			self:settext("")
		end
	end;
	RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
}

-- BPM display/label not sure why this was never with the chart info in the first place
t[#t+1] = Def.BPMDisplay {
	File=THEME:GetPathF("BPMDisplay", "bpm"),
	Name="BPMDisplay",
	InitCommand=cmd(xy,capWideScale(get43size(384),384)+62,SCREEN_BOTTOM-100;halign,1;zoom,0.50),
	SetCommand=function(self)
		if song then 
			self:visible(1)
			self:SetFromSong(song)
		else
			self:visible(0)
		end
	end,
	RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
}

t[#t+1] = LoadFont("Common Normal") .. {
	SetCommand = function(self)
		if song then
			self:settext("BPM")
		else
			self:settext("")
		end
	end,
	InitCommand=cmd(xy,capWideScale(get43size(384),384)+41,SCREEN_BOTTOM-100;halign,1;zoom,0.50),
	RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
}

-- CDtitle, need to figure out a better place for this later
t[#t+1] = Def.Sprite {
	InitCommand=cmd(xy,337,150;halign,0.5;valign,1),
	SetCommand=function(self)
		self:finishtweening()
		if GAMESTATE:GetCurrentSong() then
			local song = GAMESTATE:GetCurrentSong()	
			if song then
				if song:HasCDTitle() then
					self:visible(true)
					self:Load(song:GetCDTitlePath())
				else
					self:visible(false)
				end
			else
				self:visible(false)
			end;
			local height = self:GetHeight()
			local width = self:GetWidth()
			
			if height >= 60 and width >= 75 then
				if height*(75/60) >= width then
				self:zoom(60/height)
				else
				self:zoom(75/width)
				end
			elseif height >= 60 then
				self:zoom(60/height)
			elseif width >= 75 then
				self:zoom(75/width)
			else
				self:zoom(1)
			end;
		else
		self:visible(false)
		end;
	end,
	BeginCommand=cmd(queuecommand,"Set"),
	RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
}

-- test actor
t[#t+1] = LoadFont("Common Large") .. {
	InitCommand=cmd(xy,frameX,frameY-62;halign,0;zoom,0.5);
	BeginCommand=cmd(queuecommand,"Set");
	SetCommand=function(self)
		--File.Write(song:GetSongDir().."keyrecord.txt", GAMESTATE:GetCurrentSteps(PLAYER_1):GetWifeChartKeyRecord())
		self:settext("")
	end,
	CurrentStepsP1ChangedMessageCommand=cmd(queuecommand,"Set"),
	RefreshChartInfoMessageCommand=cmd(queuecommand,"Set"),
}






return t