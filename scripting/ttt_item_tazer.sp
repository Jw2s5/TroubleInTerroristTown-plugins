#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

#pragma semicolon 1

public Plugin:myinfo = {
    name = "[TTT] 电击枪",
    author = "Jw2s5, Modified",
    description = "TTT道具电击枪",
    version = "1.0",
    url = ""
}

#define WEAPON_BASE       "weapon_p228"
#define WEAPON_SLOT       CS_SLOT_SECONDARY

#define V_TAZER_MODEL     "models/weapons/c_csgo_taser.mdl"
#define W_TAZER_MODEL     "models/weapons/csgo_world/w_eq_taser.mdl"

#define SND_DRAW          "csgo/taser/taser_draw.wav"
#define SND_HIT           "csgo/taser/taser_hit.wav"
#define SND_SHOOT         "csgo/taser/taser_shoot.wav"

int g_ItemID;
int g_iVModel;
int g_iWModel;

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("电击枪", ITEMTYPE_WEAPON, "击中目标后立即电死", 1, TTT_ROLE_TRAITOR, -1, 1, 0);
}

public OnPluginEnd()
{
    if(g_ItemID) TTT_RemoveShopItem(g_ItemID);
}

public OnPluginStart()
{
    AddTempEntHook("Shotgun Shot", Hook_ShotgunShot);
    HookEvent("weapon_fire", Event_WeaponFire);
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if(!IsClientValid(client))
        return Plugin_Continue;

    char weapon[32];
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    if(StrEqual(weapon, WEAPON_BASE))
    {
        StopSound(client, SNDCHAN_WEAPON, "weapons/p228-1.wav");
        StopSound(client, SNDCHAN_WEAPON, "weapons/p228-2.wav");
    }
    return Plugin_Continue;
}

public OnMapStart()
{
    g_iVModel = PrecacheModel(V_TAZER_MODEL, true);
    g_iWModel = PrecacheModel(W_TAZER_MODEL, true);

    TTT_RegisterViewModel(WEAPON_BASE, g_iVModel);

    PrecacheSound(SND_DRAW, true);
    PrecacheSound(SND_HIT, true);
    PrecacheSound(SND_SHOOT, true);

    char buffer[256];
    Format(buffer, sizeof(buffer), "sound/%s", SND_DRAW);
    AddFileToDownloadsTable(buffer);
    Format(buffer, sizeof(buffer), "sound/%s", SND_HIT);
    AddFileToDownloadsTable(buffer);
    Format(buffer, sizeof(buffer), "sound/%s", SND_SHOOT);
    AddFileToDownloadsTable(buffer);
}

public OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);
}

public OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    SDKUnhook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);
}

public OnWeaponSwitchPost(int client, int weapon)
{
    if(!IsValidEntity(weapon))
        return;

    char classname[32];
    GetEntityClassname(weapon, classname, sizeof(classname));
    if(StrEqual(classname, WEAPON_BASE))
    {
        SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", g_iWModel);
        EmitSoundToClient(client, SND_DRAW);
    }
}

public OnWeaponDropPost(int client, int weapon)
{
    if(!IsValidEntity(weapon))
        return;

    char classname[32];
    GetEntityClassname(weapon, classname, sizeof(classname));
    if(StrEqual(classname, WEAPON_BASE))
        RequestFrame(ChangeWepModel, weapon);
}

public ChangeWepModel(int weapon)
{
    if(IsValidEntity(weapon))
        SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", g_iWModel);
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
            TTT_SetWeaponClip(wepent, 3);
            TTT_SetPlayerAmmo(client, wepent, 0);
        }
    }
    return Plugin_Continue;
}

public Action Hook_ShotgunShot(const char[] te_name, const int[] Players, int numClients, float delay)
{
    int client = TE_ReadNum("m_iPlayer") + 1;
    if(!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Continue;

    char classname[32];
    int iWeapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
    if(!IsValidEntity(iWeapon))
        return Plugin_Continue;

    GetEntityClassname(iWeapon, classname, sizeof(classname));

    if(StrEqual(classname, WEAPON_BASE))
    {
        int clip = GetEntProp(iWeapon, Prop_Send, "m_iClip1");
        if(clip > 0)
        {
            EmitSoundToAll(SND_SHOOT, iWeapon, SNDCHAN_WEAPON, _, _, 0.1);
        }
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public Action TTT_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if(!IsClientValid(attacker) || !IsPlayerAlive(attacker))
        return Plugin_Continue;

    if(!IsClientValid(victim) || !IsPlayerAlive(victim))
        return Plugin_Continue;

    if(attacker == victim)
        return Plugin_Continue;

    char classname[32];
    GetClientWeapon(attacker, classname, sizeof(classname));
    if(!StrEqual(classname, WEAPON_BASE))
        return Plugin_Continue;

    if(damagetype & DMG_BLAST)
        return Plugin_Continue;

    EmitSoundToClient(attacker, SND_HIT);

    SetEntityRenderMode(victim, RENDER_TRANSCOLOR);
    SetEntityRenderColor(victim, 0, 255, 0, 255);

    SDKHooks_TakeDamage(victim, inflictor, attacker, 9999.0, DMG_SHOCK);

    return Plugin_Handled;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}