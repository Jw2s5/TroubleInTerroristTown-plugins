#include <sourcemod>
#include <cstrike>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 强制 Clantag",
    author = "Jw2s5",
    description = "强制所有玩家和BOT使用服务器的clan tag",
    version = "1.0",
    url = ""
}

bool g_bAlive[MAXPLAYERS + 1];

char g_sLastTag[MAXPLAYERS + 1][32];

public OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_spawn", Event_PlayerSpawn);
    
    // 每 0.5 秒更新一次
    CreateTimer(0.1, Timer_UpdateTags, _, TIMER_REPEAT);
}

public OnClientPutInServer(int client)
{
    g_sLastTag[client][0] = '\0';
    g_bAlive[client] = false;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        g_sLastTag[i][0] = '\0';
        g_bAlive[i] = false;
    }
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    if(IsClientValid(victim))
    {
        g_bAlive[victim] = false;
    }
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(IsClientValid(client))
    {
        g_bAlive[client] = true;
    }
    return Plugin_Continue;
}

public Action Timer_UpdateTags(Handle timer)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsClientValid(i))
            continue;
        
        if(IsClientSourceTV(i))
            continue;
        
        char tag[32];
        
        if(IsPlayerAlive(i))
        {
            Format(tag, sizeof(tag), "存活");
        }
        else
        {
            Format(tag, sizeof(tag), "死亡");
        }
        
        // 只在 tag 变化时设置，避免重复触发
        if(!StrEqual(g_sLastTag[i], tag))
        {
            CS_SetClientClanTag(i, tag);
            strcopy(g_sLastTag[i], sizeof(g_sLastTag[]), tag);
        }
    }
    return Plugin_Continue;
}

stock bool IsClientValid(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}