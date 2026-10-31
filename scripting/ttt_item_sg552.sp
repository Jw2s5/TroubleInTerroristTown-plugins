#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 颠倒SG552",
    author = "Jw2s5",
    description = "TTT道具 - 攻击敌人时治疗而非伤害",
    version = "1.0",
    url = ""
}

#define WEAPON_BASE "weapon_sg552"
#define WEAPON_SLOT CS_SLOT_PRIMARY

#define HEAL_AMOUNT 5.0
#define MAX_HEALTH 115
#define FIRE_RATE 0.1

int g_ItemID;

// 标记的武器实体
ArrayList g_aMarkedWeapons;

// 独立的 HUD 通道
Handle g_hSyncSG552 = INVALID_HANDLE;

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("颠倒SG552", ITEMTYPE_WEAPON, "攻击敌人时治疗而非伤害", 1, TTT_ROLE_TRAITOR, -1, 1, 0);
}

public OnPluginEnd()
{
    if(g_ItemID) TTT_RemoveShopItem(g_ItemID);
    if(g_aMarkedWeapons != null) delete g_aMarkedWeapons;
    if(g_hSyncSG552 != INVALID_HANDLE) delete g_hSyncSG552;
}

public OnPluginStart()
{
    g_aMarkedWeapons = new ArrayList();
    g_hSyncSG552 = CreateHudSynchronizer();
    
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("weapon_fire", Event_WeaponFire);
}

public OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
}

public OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if(g_aMarkedWeapons != null) g_aMarkedWeapons.Clear();
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if(g_aMarkedWeapons != null) g_aMarkedWeapons.Clear();
    return Plugin_Continue;
}

public Action TTT_OnItemPurchase(int client, int ItemID)
{
    if(ItemID == g_ItemID)
    {
        int before_weapon = GetPlayerWeaponSlot(client, WEAPON_SLOT);
        if(before_weapon != -1)
        {
            char classname[32];
            GetEntityClassname(before_weapon, classname, sizeof(classname));
            if(StrEqual(classname, WEAPON_BASE))
            {
                CPrintToChat(client, "%s您已拥有该武器！", TTT_TAG);
                return Plugin_Handled;
            }
            else
            {
                CS_DropWeapon(client, before_weapon, false);
            }
        }
        
        int wepent = GivePlayerItem(client, WEAPON_BASE);
        if(IsValidEntity(wepent))
        {
            TTT_SetWeaponClip(wepent, 50);
            TTT_SetPlayerAmmo(client, wepent, 0);
            
            // 标记这把武器
            g_aMarkedWeapons.Push(EntIndexToEntRef(wepent));
        }
    }
    return Plugin_Continue;
}

// ===== 武器切换时设置射速 =====
public OnWeaponSwitch(int client, int weapon)
{
    if(!IsValidEntity(weapon))
        return;
    
    char classname[32];
    GetEntityClassname(weapon, classname, sizeof(classname));
    
    if(StrEqual(classname, WEAPON_BASE) && IsMarkedWeapon(weapon))
    {
        SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + FIRE_RATE);
    }
}

// ===== 开火时设置射速 =====
public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(!IsClientValid(client))
        return Plugin_Continue;
    
    int iWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
    if(!IsValidEntity(iWeapon))
        return Plugin_Continue;
    
    char classname[32];
    GetEntityClassname(iWeapon, classname, sizeof(classname));
    
    if(StrEqual(classname, WEAPON_BASE) && IsMarkedWeapon(iWeapon))
    {
        SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.18);
    }
    
    return Plugin_Continue;
}

// ===== HUD 显示武器名称（独立通道）=====
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Continue;
    
    // 只有叛徒能看到标记
    if(TTT_GetClientRole(client) != TTT_ROLE_TRAITOR)
        return Plugin_Continue;
    
    int iWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
    if(!IsValidEntity(iWeapon))
        return Plugin_Continue;
    
    if(IsMarkedWeapon(iWeapon))
    {
        SetHudTextParams(-1.0, 0.9, 0.1, 255, 100, 100, 255);
        ShowSyncHudText(client, g_hSyncSG552, "[颠倒SG552]");
    }
    
    return Plugin_Continue;
}

bool IsMarkedWeapon(int weapon)
{
    if(g_aMarkedWeapons == null) return false;
    
    int ref = EntIndexToEntRef(weapon);
    for(int i = 0; i < g_aMarkedWeapons.Length; i++)
    {
        if(g_aMarkedWeapons.Get(i) == ref)
            return true;
    }
    return false;
}

public Action TTT_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if(!IsClientValid(attacker) || !IsPlayerAlive(attacker))
        return Plugin_Continue;
    
    if(!IsClientValid(victim) || !IsPlayerAlive(victim))
        return Plugin_Continue;
    
    if(attacker == victim)
        return Plugin_Continue;
    
    // 检查当前武器
    int iWeapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
    if(!IsValidEntity(iWeapon))
        return Plugin_Continue;
    
    char classname[32];
    GetEntityClassname(iWeapon, classname, sizeof(classname));
    if(!StrEqual(classname, WEAPON_BASE))
        return Plugin_Continue;
    
    // ===== 关键：只对标记的武器生效 =====
    if(!IsMarkedWeapon(iWeapon))
        return Plugin_Continue;
    // ====================================
    
    if(damagetype & DMG_BLAST)
        return Plugin_Continue;
    
    // 治疗
    int health = GetClientHealth(victim);
    int newHealth = health + RoundToNearest(HEAL_AMOUNT);
    
    if(newHealth > MAX_HEALTH)
        newHealth = MAX_HEALTH;
    
    if(newHealth > health)
    {
        SetEntityHealth(victim, newHealth);
    }
    
    return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}