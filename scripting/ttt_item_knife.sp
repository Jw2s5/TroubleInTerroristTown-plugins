#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

public Plugin:myinfo = {
    name = "[TTT] 秒杀刀",
    author = "Jw2s5",
    description = "TTT道具 - 秒杀刀",
    version = "1.0",
    url = ""
}

#define V_KNIFEMODEL "models/weapons/ttt/v_dragn_t_new.mdl"
#define W_KNIFEMODEL "models/weapons/ttt/w_dragn_t_new.mdl"
#define ModelMaterialsFolderKnife "materials/models/weapons/v_models/dragonlord"
#define ModelsFolder "models/weapons/ttt"

#define WEAPON_BASE "weapon_knife"

int g_ItemID[3];
int v_KnifeModel;
int w_KnifeModel;

bool g_bHasKnife[MAXPLAYERS + 1];

public OnPluginStart()
{
    HookEvent("round_start", OnRoundStart);
}

public OnConfigsExecuted()
{
    for(int i = 0; i < 3; i++)
    {
        if(g_ItemID[i]) TTT_RemoveShopItem(g_ItemID[i]);
    }

    g_ItemID[0] = TTT_RegisterShopItem("匕首", ITEMTYPE_WEAPON, "只能使用一次，但可以秒杀敌人", 1, TTT_ROLE_INNOCENT, -1, -1, 0);
    g_ItemID[1] = TTT_RegisterShopItem("匕首", ITEMTYPE_WEAPON, "只能使用一次，但可以秒杀敌人", 1, TTT_ROLE_DETECTIVE, -1, -1, 0);
    g_ItemID[2] = TTT_RegisterShopItem("匕首", ITEMTYPE_WEAPON, "只能使用一次，但可以秒杀敌人", 1, TTT_ROLE_TRAITOR, -1, -1, 0);
}

public OnMapStart()
{
    TTT_AddFilesToDownloadList(ModelMaterialsFolderKnife);
    TTT_AddFilesToDownloadList(ModelsFolder, "dragn_t");
    v_KnifeModel = PrecacheModel(V_KNIFEMODEL);
    w_KnifeModel = PrecacheModel(W_KNIFEMODEL);

    LoopValidClients(client)
    {
        OnClientPutInServer(client);
    }
}

public OnPluginEnd()
{
    for(int i = 0; i < 3; i++)
    {
        if(g_ItemID[i]) TTT_RemoveShopItem(g_ItemID[i]);
    }
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    LoopValidClients(client)
    {
        g_bHasKnife[client] = false;
    }
    return Plugin_Continue;
}

public OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    g_bHasKnife[client] = false;
}

public OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    g_bHasKnife[client] = false;
}

public Action TTT_OnItemPurchase(int client, int ItemID)
{
    for(int i = 0; i < 3; i++)
    {
        if(ItemID == g_ItemID[i])
        {
            if(g_bHasKnife[client])
            {
                CPrintToChat(client, "%s您已拥有该武器！请丢掉后再购买！", TTT_TAG);
                return Plugin_Handled;
            }
            else
            {
                g_bHasKnife[client] = true;
                OnWeaponSwitchPost(client, GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon"));
                return Plugin_Continue;
            }
        }
    }
    return Plugin_Continue;
}

public Action TTT_OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if(IsClientValid(attacker) && IsPlayerAlive(attacker) && victim != attacker)
    {
        char aWeapon[32];
        GetClientWeapon(attacker, aWeapon, sizeof(aWeapon));

        if(StrEqual(aWeapon, "weapon_knife") && g_bHasKnife[attacker] && !(damagetype & DMG_BLAST))
        {
            damage = 99999.0;
            CreateTimer(0.3, RemoveKnife, attacker);
            return Plugin_Changed;
        }
    }
    return Plugin_Continue;
}

public Action RemoveKnife(Handle Timer, attacker)
{
    int knife = GetPlayerWeaponSlot(attacker, CS_SLOT_KNIFE);
    if(IsClientValid(attacker) && IsPlayerAlive(attacker) && knife != -1)
    {
        g_bHasKnife[attacker] = false;
        TTT_RemoveWeapon(attacker, knife, CS_SLOT_KNIFE);
        CreateTimer(0.1, GiveKnife, attacker);
    }
    return Plugin_Continue;
}

public Action GiveKnife(Handle Timer, attacker)
{
    if(IsClientValid(attacker) && IsPlayerAlive(attacker) && GetPlayerWeaponSlot(attacker, CS_SLOT_KNIFE) == -1)
    {
        GivePlayerItem(attacker, "weapon_knife");
    }
    return Plugin_Continue;
}

public OnWeaponSwitchPost(int client, int weapon)
{
    if(IsValidEntity(weapon))
    {
        char aWeapon[32];
        GetEntityClassname(weapon, aWeapon, sizeof(aWeapon));
        if(StrEqual(aWeapon, "weapon_knife"))
        {
            if(g_bHasKnife[client])
            {
                TTT_SetViewModel(client, v_KnifeModel);
                SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", w_KnifeModel);
            }
        }
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}