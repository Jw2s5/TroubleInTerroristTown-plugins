#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

public Plugin:myinfo = {
    name = "[TTT] 强化撬棍",
    author = "Jw2s5",
    description = "TTT道具 - 强化撬棍",
    version = "1.0",
    url = ""
}

#define V_CROWBARMODEL "models/weapons/v_crowbar.mdl"
#define W_CROWBARMODEL "models/weapons/w_crowbar.mdl"
#define HIT_SOUND "ttt/body_impact_hard.wav"
#define HITWALL_SOUND "ttt/crowbar_hitwall.wav"
#define ModelMaterialsFolderCrowbar "materials/models/weapons/v_models/crowbar"
#define ModelsFolder "models/weapons/ttt"

#define WEAPON_BASE "weapon_knife"

int g_ItemID;
int v_CrowbarModel;
int w_CrowbarModel;

enum struct PlayerData {
    bool EnhanceCrowbar;
    int buttons;
}

PlayerData g_Client[MAXPLAYERS + 1];

public OnPluginStart()
{
    AddNormalSoundHook(HookKnifeSound);
    HookEvent("round_start", OnRoundStart);
    HookEvent("weapon_fire", OnWeaponFire);

    LoopValidClients(client)
    {
        OnClientPutInServer(client);
    }
}

public OnConfigsExecuted()
{
    g_ItemID = TTT_RegisterShopItem("强化撬棍", ITEMTYPE_PassiveEquip, "增加撬棍的伤害及击退能力", 1, TTT_ROLE_TRAITOR, -1, 1, 0);
}

public OnMapStart()
{
    char buffer[64];
    Format(buffer, sizeof(buffer), "sound/%s", HIT_SOUND);
    AddFileToDownloadsTable(buffer);
    Format(buffer, sizeof(buffer), "sound/%s", HITWALL_SOUND);
    AddFileToDownloadsTable(buffer);
    TTT_AddFilesToDownloadList(ModelMaterialsFolderCrowbar);
    TTT_AddFilesToDownloadList(ModelsFolder, "crowbar");
    PrecacheSound(HIT_SOUND);
    PrecacheSound(HITWALL_SOUND);
    v_CrowbarModel = PrecacheModel(V_CROWBARMODEL);
    w_CrowbarModel = PrecacheModel(W_CROWBARMODEL);

    TTT_RegisterViewModel(WEAPON_BASE, v_CrowbarModel);

    LoopValidClients(client)
    {
        OnClientPutInServer(client);
    }
}

public OnPluginEnd()
{
    if(g_ItemID) TTT_RemoveShopItem(g_ItemID);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    LoopValidClients(client)
    {
        g_Client[client].EnhanceCrowbar = false;
        g_Client[client].buttons = 0;
    }
    return Plugin_Continue;
}

public OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    g_Client[client].EnhanceCrowbar = false;
    g_Client[client].buttons = 0;
}

public OnClientDisconnect(int client)
{
    SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    g_Client[client].EnhanceCrowbar = false;
    g_Client[client].buttons = 0;
}

// ===== 自己维护 buttons，不依赖主插件 =====
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(!IsClientValid(client))
        return Plugin_Continue;

    g_Client[client].buttons = buttons;
    return Plugin_Continue;
}
// ==========================================

public Action TTT_OnItemPurchase(int client, int ItemID)
{
    if(ItemID == g_ItemID)
    {
        if(g_Client[client].EnhanceCrowbar)
        {
            CPrintToChat(client, "%s您已拥有该武器！请丢掉后再购买！", TTT_TAG);
            return Plugin_Handled;
        }
        else
        {
            g_Client[client].EnhanceCrowbar = true;
            return Plugin_Continue;
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

        if(StrEqual(aWeapon, "weapon_knife") && !(damagetype & DMG_BLAST))
        {
            if(g_Client[attacker].buttons & IN_ATTACK)
            {
                damage = 10.0;
                if(g_Client[attacker].EnhanceCrowbar) damage = 45.0;
                return Plugin_Changed;
            }
            else if(g_Client[attacker].buttons & IN_ATTACK2)
            {
                float Origin[3][3], Velocity[3];
                GetClientAbsOrigin(attacker, Origin[0]);
                GetClientAbsOrigin(victim, Origin[1]);
                MakeVectorFromPoints(Origin[0], Origin[1], Velocity);
                NormalizeVector(Velocity, Velocity);
                ScaleVector(Velocity, g_Client[attacker].EnhanceCrowbar ? 1000.0 : 200.0);
                TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, Velocity);
                return Plugin_Handled;
            }
        }
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
            TTT_SetViewModel(client, v_CrowbarModel);
            SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", w_CrowbarModel);
            RequestFrame(InitKnifeFireSpeed, client);
        }
    }
}

public Action HookKnifeSound(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH],
int &entity, int &channel, float &volume, int &level, int &pitch, int &flags,
char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
    if(IsValidEntity(entity))
    {
        int owner = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");
        if(IsClientValid(owner))
        {
            if(StrContains(sample, "knife_hitwall") > -1)
            {
                EmitSoundToAll(HITWALL_SOUND, entity, SNDCHAN_WEAPON);
                return Plugin_Stop;
            }
            if(StrContains(sample, "knife_stab") > -1)
            {
                EmitSoundToAll(HIT_SOUND, entity, SNDCHAN_WEAPON);
                return Plugin_Stop;
            }
        }
    }
    return Plugin_Continue;
}

public Action OnWeaponFire(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    RequestFrame(InitKnifeFireSpeed, client);
    return Plugin_Continue;
}

stock InitKnifeFireSpeed(int client)
{
    if(IsClientValid(client) && IsPlayerAlive(client))
    {
        int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
        if(IsValidEntity(iWeapon))
        {
            decl String:Buffer[32];
            GetEntityClassname(iWeapon, Buffer, sizeof(Buffer));
            if (StrEqual(Buffer, "weapon_knife"))
            {
                SetEntPropFloat(iWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.55);
                SetEntPropFloat(iWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 0.7);
            }
        }
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    return APLRes_Success;
}