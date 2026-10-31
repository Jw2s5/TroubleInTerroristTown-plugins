#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <morecolors>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin myinfo = {
    name = "[TTT] 特定武器拾取限制",
    author = "Jw2s5",
    description = "默认禁止拾取任何武器，只有规则允许的身份才能拾取特定武器",
    version = "2.0",
    url = ""
};

// 武器拾取规则
enum struct WeaponRestriction
{
    char WeaponName[32];    // 武器类名
    int AllowedRole;        // 允许拾取的身份（-1 = 所有人）
}

// 白名单：只有列表里的武器能被对应身份拾取，其他武器任何人都捡不了
WeaponRestriction g_Restrictions[] = {
    {"weapon_awp",      TTT_ROLE_TRAITOR},
    {"weapon_hegrenade",TTT_ROLE_TRAITOR},
    {"weapon_famas",    TTT_ROLE_TRAITOR},
    {"weapon_usp",      TTT_ROLE_TRAITOR},
    {"weapon_ump45",    TTT_ROLE_TRAITOR},
    {"weapon_mp5navy",  TTT_ROLE_TRAITOR},
    {"weapon_p228",     TTT_ROLE_TRAITOR},
    {"weapon_deagle",   -1},
    {"weapon_sg552",    -1},
    {"weapon_knife",    -1},
    {"weapon_c4",       -1},
    {"weapon_elite",    -1},
    {"weapon_flashbang",-1},
    {"weapon_fiveseven",-1}
};

// 标记数组（用于标记商店购买的叛徒武器）
bool g_bTraitorWeapon[2048];

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_team", Event_PlayerTeam);

    for (int i = 0; i < 2048; i++)
        g_bTraitorWeapon[i] = false;
}

public void OnMapStart()
{
    for (int i = 0; i < 2048; i++)
        g_bTraitorWeapon[i] = false;
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public void OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 0; i < 2048; i++)
        g_bTraitorWeapon[i] = false;
    return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (TTT_IsClientValid(client))
    {
        SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
        SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
    }
    return Plugin_Continue;
}

// ========== 拦截拾取 ==========
public Action OnWeaponCanUse(int client, int weapon)
{
    if (!IsValidEntity(weapon) || weapon >= 2048)
        return Plugin_Continue;

    if (!TTT_IsClientValid(client))
        return Plugin_Continue;

    int role = TTT_GetClientRole(client);
    char classname[32];
    GetEntityClassname(weapon, classname, sizeof(classname));

    // 1. 被标记为叛徒武器的（商店购买），只有叛徒能捡
    if (g_bTraitorWeapon[weapon])
    {
        if (role != TTT_ROLE_TRAITOR)
            return Plugin_Handled;
        return Plugin_Continue;
    }

    // 2. 在白名单里，检查身份是否匹配
    for (int i = 0; i < sizeof(g_Restrictions); i++)
    {
        if (StrEqual(classname, g_Restrictions[i].WeaponName))
        {
            if (g_Restrictions[i].AllowedRole == -1)
                return Plugin_Continue;   // -1，所有人能捡
            if (role == g_Restrictions[i].AllowedRole)
                return Plugin_Continue;   // 身份匹配，允许
            else
                return Plugin_Handled;    // 身份不匹配，拒绝
        }
    }

    // 3. 不在白名单里的武器，默认禁止
    return Plugin_Handled;
}

// ========== 标记叛徒武器（供其他插件调用） ==========
public void SetTraitorWeapon(int weapon)
{
    if (!IsValidEntity(weapon) || weapon >= 2048)
        return;

    g_bTraitorWeapon[weapon] = true;
}

public bool IsTraitorWeapon(int weapon)
{
    if (!IsValidEntity(weapon) || weapon >= 2048)
        return false;

    return g_bTraitorWeapon[weapon];
}

// ========== 注册Native ==========
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("TTT_MarkTraitorWeapon", Native_MarkTraitorWeapon);
    return APLRes_Success;
}

public int Native_MarkTraitorWeapon(Handle plugin, int numParams)
{
    int weapon = GetNativeCell(1);
    SetTraitorWeapon(weapon);
    return 0;
}