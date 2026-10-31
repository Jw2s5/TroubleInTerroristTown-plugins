#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 叛徒雷达",
    author = "Jw2s5, Modified",
    description = "TTT道具 - 循环显示地图雷达20秒，冷却30秒",
    version = "2.0",
    url = ""
}

#define RADAR_SHOW_TIME   20.0
#define RADAR_COOLDOWN    30.0
#define SOUND_RADAR       "ttt/i see you scary voice.mp3"

int g_ItemID;

bool g_bHasRadar[MAXPLAYERS + 1];
bool g_bRadarActive[MAXPLAYERS + 1];
int  g_iRadarCountdown[MAXPLAYERS + 1];
Handle g_hRadarLoopTimer[MAXPLAYERS + 1];
Handle g_hRadarTickTimer[MAXPLAYERS + 1];

public OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("player_death", Event_PlayerDeath);
}

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("高级雷达", ITEMTYPE_PassiveEquip, "打开地图雷达20秒", 1, TTT_ROLE_TRAITOR, -1, 1, 0);
}

public void OnMapStart()
{
    PrecacheSound(SOUND_RADAR, true);

    char buffer[256];
    Format(buffer, sizeof(buffer), "sound/%s", SOUND_RADAR);
    AddFileToDownloadsTable(buffer);
}

public OnPluginEnd()
{
    if(g_ItemID) TTT_RemoveShopItem(g_ItemID);
    for(int client = 1; client <= MaxClients; client++)
    {
        ResetPlayerRadar(client);
    }
}

public Action TTT_OnItemPurchase(int client, int ItemID)
{
    if(ItemID == g_ItemID)
    {
        if(g_bHasRadar[client])
        {
            CPrintToChat(client, "%s您本回合已购买过该道具！", TTT_TAG);
            return Plugin_Handled;
        }

        g_bHasRadar[client] = true;
        CPrintToChat(client, "%s{yellow}叛徒雷达已启动！{default}循环显示雷达", TTT_TAG);

        StartRadarShow(client);
    }
    return Plugin_Continue;
}

void StartRadarShow(int client)
{
    if(!TTT_IsClientValid(client))
        return;

    g_bRadarActive[client] = true;
    ClearFlash(client);

    PlaySoundToAll();

    g_iRadarCountdown[client] = 0;

    if(g_hRadarTickTimer[client] != INVALID_HANDLE && IsValidHandle(g_hRadarTickTimer[client]))
        KillTimer(g_hRadarTickTimer[client]);
    g_hRadarTickTimer[client] = INVALID_HANDLE;

    if(g_hRadarLoopTimer[client] != INVALID_HANDLE && IsValidHandle(g_hRadarLoopTimer[client]))
        KillTimer(g_hRadarLoopTimer[client]);
    g_hRadarLoopTimer[client] = CreateTimer(RADAR_SHOW_TIME, Timer_ShowEnd, client);
}

public Action Timer_ShowEnd(Handle timer, int client)
{
    g_hRadarLoopTimer[client] = INVALID_HANDLE;

    if(!TTT_IsClientValid(client) || !g_bHasRadar[client])
        return Plugin_Stop;

    if(!IsPlayerAlive(client))
        return Plugin_Stop;

    g_bRadarActive[client] = false;
    RestoreFlash(client);

    g_iRadarCountdown[client] = RoundToNearest(RADAR_COOLDOWN);
    StartTickTimer(client);

    g_hRadarLoopTimer[client] = CreateTimer(RADAR_COOLDOWN, Timer_CooldownEnd, client);

    return Plugin_Stop;
}

public Action Timer_CooldownEnd(Handle timer, int client)
{
    g_hRadarLoopTimer[client] = INVALID_HANDLE;

    if(!TTT_IsClientValid(client) || !g_bHasRadar[client])
        return Plugin_Stop;

    if(!IsPlayerAlive(client))
        return Plugin_Stop;

    StartRadarShow(client);

    return Plugin_Stop;
}

void StartTickTimer(int client)
{
    if(g_hRadarTickTimer[client] != INVALID_HANDLE && IsValidHandle(g_hRadarTickTimer[client]))
        KillTimer(g_hRadarTickTimer[client]);

    g_hRadarTickTimer[client] = CreateTimer(1.0, Timer_RadarTick, client, TIMER_REPEAT);
}

public Action Timer_RadarTick(Handle timer, int client)
{
    if(!TTT_IsClientValid(client) || !g_bHasRadar[client])
    {
        g_hRadarTickTimer[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    if(g_iRadarCountdown[client] > 0)
        g_iRadarCountdown[client]--;

    if(g_iRadarCountdown[client] <= 0)
    {
        g_hRadarTickTimer[client] = INVALID_HANDLE;
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

void ClearFlash(int client)
{
    if(!TTT_IsClientValid(client)) return;
    SetEntPropFloat(client, Prop_Send, "m_flFlashDuration", 0.0);
    SetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha", 0.0);
}

void RestoreFlash(int client)
{
    if(!TTT_IsClientValid(client)) return;
    SetEntPropFloat(client, Prop_Send, "m_flFlashDuration", 3600.0);
    SetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha", 0.5);
}

void PlaySoundToAll()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!TTT_IsClientValid(i)) continue;
        EmitSoundToClient(i, SOUND_RADAR, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, _, 1.0);
    }
}

void ResetPlayerRadar(int client)
{
    g_bHasRadar[client] = false;
    g_bRadarActive[client] = false;
    g_iRadarCountdown[client] = 0;

    if(g_hRadarLoopTimer[client] != INVALID_HANDLE && IsValidHandle(g_hRadarLoopTimer[client]))
        KillTimer(g_hRadarLoopTimer[client]);
    g_hRadarLoopTimer[client] = INVALID_HANDLE;

    if(g_hRadarTickTimer[client] != INVALID_HANDLE && IsValidHandle(g_hRadarTickTimer[client]))
        KillTimer(g_hRadarTickTimer[client]);
    g_hRadarTickTimer[client] = INVALID_HANDLE;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for(int client = 1; client <= MaxClients; client++)
        ResetPlayerRadar(client);
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    for(int client = 1; client <= MaxClients; client++)
        ResetPlayerRadar(client);
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(TTT_IsClientValid(client))
        ResetPlayerRadar(client);
    return Plugin_Continue;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("TTT_HasRadarItem", Native_HasRadarItem);
    CreateNative("TTT_GetRadarCountdown", Native_GetRadarCountdown);
    return APLRes_Success;
}

public int Native_HasRadarItem(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if(!TTT_IsClientValid(client)) return false;
    return g_bHasRadar[client];
}

public int Native_GetRadarCountdown(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if(!TTT_IsClientValid(client)) return 0;
    return g_iRadarCountdown[client];
}