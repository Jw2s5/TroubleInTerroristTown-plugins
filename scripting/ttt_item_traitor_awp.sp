#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

public Plugin:myinfo = {
    name = "[TTT] 叛徒AWP",
    author = "Jw2s5",
    description = "TTT道具 - 叛徒专属AWP",
    version = "1.0",
    url = ""
}

#define WEAPON_BASE "weapon_awp"
#define WEAPON_SLOT CS_SLOT_PRIMARY

int g_ItemID;

#define AWP_DAMAGE 150.0

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("AWP", ITEMTYPE_WEAPON, "威力强大的狙击枪! 仅6发子弹", 1, TTT_ROLE_TRAITOR, -1, -1, 0);
}

public OnMapStart()
{
    LoopValidClients(client)
    {
        OnClientPutInServer(client);
    }
}

public OnPluginEnd()
{
    if(g_ItemID) TTT_RemoveShopItem(g_ItemID);
}

public OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
}

public OnWeaponSwitchPost(int client, int weapon)
{
    // 使用默认模型
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
            if (StrEqual(classname, WEAPON_BASE))
            {
                CPrintToChat(client, "%s您已拥有该武器！请丢掉后再购买！", TTT_TAG);
                return Plugin_Handled;
            }
            else
            {
                CS_DropWeapon(client, before_weapon, false);
            }
        }
        int wepent = GivePlayerItem(client, WEAPON_BASE);
        TTT_SetWeaponClip(wepent, 6);
        TTT_SetPlayerAmmo(client, wepent, 0);  // 修复：补上0
    }
    return Plugin_Continue;
}

public Action TTT_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if(TTT_IsClientValid(attacker) && IsPlayerAlive(attacker) && victim != attacker)
    {
        char aWeapon[32];
        GetClientWeapon(attacker, aWeapon, sizeof(aWeapon));
        if(StrEqual(aWeapon, WEAPON_BASE))
        {
            damage = AWP_DAMAGE / 0.35;
            return Plugin_Changed;
        }
    }
    return Plugin_Continue;
}