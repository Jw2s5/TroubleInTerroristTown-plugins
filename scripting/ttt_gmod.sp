#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 出生点转换",
    author = "Jw2s5",
    description = "info_player_start转换",
    version = "1.1",
    url = ""
}

int g_iStartCount = 0;

public OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
    CreateTimer(0.1, Timer_ConvertSpawns, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ConvertSpawns(Handle timer)
{
    g_iStartCount = 0;

    int ent = -1;
    int deletedCT = 0;
    while((ent = FindEntityByClassname(ent, "info_player_counterterrorist")) != -1)
    {
        AcceptEntityInput(ent, "Kill");
        deletedCT++;
    }
    if(deletedCT > 0)
    {
        PrintToServer("[TTT] 已删除 %d 个原有的 info_player_counterterrorist", deletedCT);
    }

    ent = -1;
    while((ent = FindEntityByClassname(ent, "info_player_start")) != -1)
    {
        g_iStartCount++;
    }

    if(g_iStartCount == 0)
        return Plugin_Stop;

    ent = -1;
    while((ent = FindEntityByClassname(ent, "info_player_start")) != -1)
    {
        float origin[3], angles[3];
        GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origin);
        GetEntPropVector(ent, Prop_Send, "m_angRotation", angles);

        int newSpawn = CreateEntityByName("info_player_terrorist");
        if(newSpawn != -1)
        {
            DispatchSpawn(newSpawn);
            TeleportEntity(newSpawn, origin, angles, NULL_VECTOR);
        }
    }

    PrintToServer("[TTT] 已转换 %d 个 info_player_start 为 T 出生点", g_iStartCount);
    return Plugin_Stop;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if(g_iStartCount > 0)
    {
        return Plugin_Continue;
    }

    CreateTimer(0.1, Timer_ConvertSpawns, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}