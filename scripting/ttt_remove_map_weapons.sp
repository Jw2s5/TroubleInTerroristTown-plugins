#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 清除地图自带武器",
    author = "Jw2s5",
    description = "开局删除地图里所有地面可拾取武器",
    version = "1.0",
    url = ""
}

#define WEAPON_PREFIX "weapon_"

char g_sExcludeList[][] = {
    "weapon_c4",        // C4 是 TTT 物理棒，不能删
    "weapon_knife"      // 小刀是默认武器，不能删
};

int g_iRemovedCount = 0;

public OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public OnMapStart()
{
    CreateTimer(0.5, Timer_RemoveMapWeapons, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(0.5, Timer_RemoveMapWeapons, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action Timer_RemoveMapWeapons(Handle timer)
{
    g_iRemovedCount = 0;

    int ent = -1;
    while((ent = FindEntityByClassname(ent, "weapon_*")) != -1)
    {
        // 跳过无效实体
        if(!IsValidEntity(ent))
            continue;

        // 跳过被玩家持有/掉落的武器（有 owner 的）
        int owner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
        if(owner > 0 && owner <= MaxClients)
            continue;

        char classname[64];
        GetEntityClassname(ent, classname, sizeof(classname));

        // 检查排除列表
        bool bExclude = false;
        for(int i = 0; i < sizeof(g_sExcludeList); i++)
        {
            if(StrEqual(classname, g_sExcludeList[i]))
            {
                bExclude = true;
                break;
            }
        }
        if(bExclude)
            continue;

        // 删除
        AcceptEntityInput(ent, "Kill");
        g_iRemovedCount++;
    }

    if(g_iRemovedCount > 0)
    {
        PrintToServer("[TTT] 已清除 %d 个地图自带武器", g_iRemovedCount);
    }

    return Plugin_Stop;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}