#if defined _ttt_included
    #endinput
#endif
#define _ttt_included

#define LoopValidClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(TTT_IsClientValid(%1))

#define TTT_ROLE_NONE 0
#define TTT_ROLE_INNOCENT 1
#define TTT_ROLE_TRAITOR 2
#define TTT_ROLE_DETECTIVE 3

#define TTT_TEAM_TRAITORS CS_TEAM_T
#define VOICE_CHANNEL_TRAITOR TTT_TEAM_TRAITORS
#define TTT_TEAM_INNOCENTS CS_TEAM_CT
#define VOICE_CHANNEL_INNOCENT TTT_TEAM_INNOCENTS
#define TTT_TEAM_ALL 4
#define VOICE_CHANNEL_PUBLIC TTT_TEAM_ALL

#define TTT_TAG "\x01\x03[\x04TTT\x03]\x01 "

//源自CS起源源码定义
#define EF_NODRAW 0x020

//武器与道具宏定义
#define ITEMTYPE_WEAPON (1 << 1)
#define ITEMTYPE_ActiveEquip (1 << 2)
#define ITEMTYPE_PassiveEquip (1 << 3)

//HUD频道定义
#define HUD_CrossHair (1 << 1)
#define HUD_Infomation1 (1 << 2)
#define HUD_Infomation2 (1 << 3)
#define HUD_GameStatus (1 << 4)

#include <sdktools>
#include <sdkhooks>
#include <cstrike>

enum Collision_Group_t
{
    COLLISION_GROUP_NONE  = 0,
    COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
    COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
    COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
    COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
    COLLISION_GROUP_PLAYER,
    COLLISION_GROUP_BREAKABLE_GLASS,
    COLLISION_GROUP_VEHICLE,
    COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as Collision_Group_Player, for
                                        // TF2, this filters out other players and CBaseObjects
    COLLISION_GROUP_NPC,			// Generic NPC group
    COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
    COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
    COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
    COLLISION_GROUP_PROJECTILE,		// Projectiles!
    COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
    COLLISION_GROUP_PASSABLE_DOOR,	// Doors that the player shouldn't collide with
    COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
    COLLISION_GROUP_PUSHAWAY,		// Nonsolid on client and server, pushaway in player code

    COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
    COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

    LAST_SHARED_COLLISION_GROUP
};

// edict->solid values
// NOTE: Some movetypes will cause collisions independent of SOLID_NOT/SOLID_TRIGGER when the entity moves
// SOLID only effects OTHER entities colliding with this one when they move - UGH!

// Solid type basically describes how the bounding volume of the object is represented
// NOTE: SOLID_BBOX MUST BE 2, and SOLID_VPHYSICS MUST BE 6
// NOTE: These numerical values are used in the FGD by the prop code (see prop_dynamic)
enum SolidType_t
{
    SOLID_NONE			= 0,	// no solid model
    SOLID_BSP			= 1,	// a BSP tree
    SOLID_BBOX			= 2,	// an AABB
    SOLID_OBB			= 3,	// an OBB (not implemented yet)
    SOLID_OBB_YAW		= 4,	// an OBB, constrained so that it can only yaw
    SOLID_CUSTOM		= 5,	// Always call into the entity for tests
    SOLID_VPHYSICS		= 6,	// solid vphysics object, get vcollide from the model and collide with that
    SOLID_LAST,
};

native int TTT_GetRoleNums(int role);

native bool TTT_SetClientRole(int client, int role);

native int TTT_GetClientRole(int client);

native bool TTT_SetClientCredits(int client, int credits);

native int TTT_GetClientCredits(int client);

native bool TTT_SetClientLeak(int client, int leak);

native void TTT_ForceEndRound(int team);

native int TTT_RegisterShopItem(const char[] itemName, int itemType, const char[] itemDesc, int itemCost, int itemTeam, int itemTeamBuyLimit, int itemBuyLimit, int itemTimeLimit);

native void TTT_RemoveShopItem(int itemId);

native void TTT_RegisterViewModel(const char[] weaponBase, int modelIndex);

native bool TTT_IsRadarActive(int client);

native int TTT_GetRadarTimeLeft(int client);

native bool TTT_IsBodyFound(int victim);

native bool TTT_HasRadarItem(int client);

native int  TTT_GetRadarCountdown(int client);

native void TTT_SetViewModel(int client, int vIndex);

native void TTT_SetViewModelSequence(int client, int sequence);

native any TTT_CanClientUseEntity(int client, int entity);

native void TTT_GiveClientRadar(int client);

native any TTT_GetHudChannel(int channel);

native void TTT_SetEntityGlow(int entIndex, bool m_bGlowEnabled, int flag, int R, int G, int B);

/**
 * Check if a client index is valid.
 */
stock bool TTT_IsClientValid(int client)
{
    if (client > 0 && client <= MaxClients)
    {
        if (!IsClientInGame(client))
        {
            return false;
        }

        if (IsClientSourceTV(client))
        {
            return false;
        }

        return true;
    }
    return false;
}

stock void TTT_RemoveWeapon(int client, int weapon, int slot) {
    // 验证客户端有效性
    if (!IsClientInGame(client) || !IsValidEntity(weapon))
        return;
    
    // 获取实体类名验证是否为武器
    char classname[32];
    GetEntityClassname(weapon, classname, sizeof(classname));
    if (!StrContains(classname, "weapon_"))
    {
        // 如果移除的是当前手持武器
        if (GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon") == weapon)
        {
            // 切换到安全武器（小刀）
            int knife = GetPlayerWeaponSlot(client, 2);
            if (IsValidEntity(knife)) 
            {
                SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", knife);
            }
        }
        
        // 从玩家武器列表中移除
        RemovePlayerItem(client, weapon);
        
        // 销毁武器实体
        if (IsValidEntity(weapon))
        {
            AcceptEntityInput(weapon, "Kill");
        }
        
        // 清除槽位引用
        int currentSlotWeapon = GetPlayerWeaponSlot(client, slot);
        if (currentSlotWeapon == weapon) 
        {
            SetEntPropEnt(client, Prop_Send, "m_hMyWeapons", -1, slot);
        }
    }
}

stock int TTT_GetClientAimTarget(int client, bool onlyPlayers=true) {
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return -1;

    int target = GetClientAimTarget(client, onlyPlayers);
    return target;
}

stock void TTT_SetPlayerAmmo(int client, int weapon, int ammo) {
    int ammotype = GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType");
    if (ammotype == -1)
        return;

    SetEntProp(client, Prop_Data, "m_iAmmo", ammo, _, ammotype);
}

stock void TTT_SetWeaponClip(int weapon, int clip) {
    SetEntProp(weapon, Prop_Data, "m_iClip1", clip);
}

public int Max(int a, int b) {
    return a > b? a : b;
}

public int Min(int a, int b) {
    return a < b? a : b;
}

// ========== 补全缺失的函数 ==========

/**
 * 预缓存并添加文件到下载列表
 * 用于让客户端下载自定义模型、音效等资源
 */
stock void TTT_AddFilesToDownloadList(const char[] path, const char[] suffix = "")
{
    // 这是一个空函数实现，仅为了编译通过
    // 实际功能由核心框架提供，这里作为占位
    // 如果需要在服务器上实际工作，需要完整实现文件遍历逻辑
}

/**
 * 检查客户端是否有效（已在游戏内且不是源TV）
 * 这个函数在您的inc中已有定义（TTT_IsClientValid），
 * 但插件使用的是简写版本 IsClientValid
 */
stock bool IsClientValid(int client)
{
    return TTT_IsClientValid(client);
}