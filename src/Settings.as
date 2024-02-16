
[Setting hidden]
bool S_ShowWindow = true;

// does this do anything?
[Setting hidden]
bool S_UseGhostLayer = true;

[Setting category="General" name="Log Level"]
#if DEV
LogLevel S_LogLevel = LogLevel::Debug;
#else
LogLevel S_LogLevel = LogLevel::Info;
#endif

[Setting category="General" name="Show Ghost Save Notifications?"]
bool S_ShowSaveNotifications = true;

[Setting category="General" name="Enable in Editor"]
bool S_EnableInEditor = false;

[Setting category="General" name="Draw Letterbox Bars (hides glitched gfx)"]
bool S_DrawLetterboxBars = false;

[Setting category="General" name="Mute / Soften Engine Sounds when Scrubbing"]
bool S_SoftenEngineSounds = true;

[Setting category="General" name="Volume DB: Engine Sounds when Scrubbing" min=-60 max=0]
float S_EngineSoundsDB = -20.;

// [Setting category="General" name="Swap the play/pause button with the reset ghosts button"]
// bool S_SwapPauseAndRestart = false;

[Setting category="General" name="Suppress unlock timeline prompt"]
bool S_SuppressUnlockTimelinePrompt = false;

[Setting category="General" name="Hide set offset in advanced tools"]
bool S_HideSetOffset = true;

[Setting category="General" name="Autoload favorited players?" description="Automatically load ghosts from favorited players when entering a map. \\$d88Limited to a maximum of 10.\\$z"]
bool S_AutoloadFavoritedPlayers = false;

enum KeyboardShape
{
	Rectangle,
	Ellipse,
	Compact,
}

[Setting category="Ghost Inputs" name="Show Inputs while Spectating Ghosts?"]
bool S_ShowInputsWhileSpectatingGhosts = true;

[Setting category="Ghost Inputs" name="Show Ghost Inputs when UI is hidden?"]
bool S_ShowInputsWhenUIHidden = false;

[Setting category="Ghost Inputs" name="Show Steering %?"]
bool S_ShowSteeringPct = true;

[Setting category="Ghost Inputs" name="Hide Ghost Inputs when only 1 ghost is loaded?" description="Because Dashboard already shows it in this case."]
bool S_HideInputsIfOnlyGhost = true;

[Setting category="Ghost Inputs" name="Height (relative to screen)" min=0 max=1 drag]
float S_InputsHeight = 0.147;

[Setting category="Ghost Inputs" name="Position X (relative to screen)" min=0 max=1 drag]
float S_InputsPosX = 0.5;

[Setting category="Ghost Inputs" name="Position Y (relative to screen)" min=0 max=1 drag]
float S_InputsPosY = 0.03;

[Setting category="Ghost Inputs" name="Shape"]
KeyboardShape Setting_Keyboard_Shape = KeyboardShape::Rectangle;

[Setting category="Ghost Inputs" name="Empty fill color" color]
vec4 Setting_Keyboard_EmptyFillColor = vec4(0, 0, 0, 0.7f);

[Setting category="Ghost Inputs" name="Fill color" color]
vec4 Setting_Keyboard_FillColor = vec4(1, 0.2f, 0.6f, 1);

[Setting category="Ghost Inputs" name="Border color" color]
vec4 Setting_Keyboard_BorderColor = vec4(1, 1, 1, 1);

[Setting category="Ghost Inputs" name="Border width" drag min=0 max=10]
float Setting_Keyboard_BorderWidth = 1.0f;

[Setting category="Ghost Inputs" name="Border radius" drag min=0 max=50]
float Setting_Keyboard_BorderRadius = 2.0f;

[Setting category="Ghost Inputs" name="Spacing" drag min=0 max=100]
float Setting_Keyboard_Spacing = 10.0f;

[Setting category="Ghost Inputs" name="Inactive alpha" drag min=0 max=1]
float Setting_Keyboard_InactiveAlpha = 0.4f;

[Setting category="Ghost Opacity" name="Solo: Set Ghost Opacity?"]
bool S_SetGhostAlphaTo1 = false;

[Setting category="Ghost Opacity" name="Online: Set Ghost Opacity?"]
bool S_GhostOpacityOverrideOnline = false;

[Setting category="Ghost Opacity" name="Ghost Opacity Override (TimeAttack)" min=0 max=1 drag]
float S_GhostOpacityTimeAttack = 0.9;

[Setting category="Ghost Opacity" name="Ghost Opacity Override (Solo)" min=0 max=1 drag]
float S_GhostOpacitySolo = 0.9;

void DrawGhostOpacityControls(bool compact = false) {
	S_GhostOpacityOverrideOnline = UI::Checkbox(compact ? "##setghostopac" : "Set Ghost Opacity", S_GhostOpacityOverrideOnline);
	if (compact) AddSimpleTooltip("Set Ghost Opacity");
	UI::SameLine();
	UI::PushItemWidth(75);
	UI::BeginDisabled(!S_GhostOpacityOverrideOnline);
	S_GhostOpacitySolo = UI::SliderFloat("##ghostopac", S_GhostOpacitySolo, 0, 1);
	UI::EndDisabled();
	UI::PopItemWidth();
	// if (S_GhostOpacityOverrideOnline) S_GhostOpacityTimeAttack = S_GhostOpacitySolo;
}
