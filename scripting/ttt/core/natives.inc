stock InitForwards()
{
    g_fwOnItemPurchase = new GlobalForward("TTT_OnItemPurchase", ET_Event, Param_Cell, Param_Cell);
    g_fwOnTakeDamage = new GlobalForward("TTT_OnTakeDamage", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array);
    g_fwOnTraceAttack = new GlobalForward("TTT_OnTraceAttack", ET_Hook, Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_CellByRef, Param_CellByRef, Param_Cell, Param_Cell);
    g_fwOnEntityInfoHUDDisplay = new GlobalForward("TTT_OnEntityInfoHUDDisplay", ET_Ignore, Param_Cell, Param_Cell);
    g_fwOnGrabEntity = new GlobalForward("TTT_OnGrabEntity", ET_Event, Param_Cell, Param_Cell);
}

stock InitNatives()
{
    CreateNative("TTT_GetRoleNums", Native_GetRoleNums);
    CreateNative("TTT_GetClientRole", Native_GetClientRole);
    CreateNative("TTT_SetClientRole", Native_SetClientRole);
    CreateNative("TTT_GetClientCredits", Native_GetClientCredits);
    CreateNative("TTT_SetClientCredits", Native_SetClientCredits);
    CreateNative("TTT_SetClientLeak", Native_SetClientLeak);
    CreateNative("TTT_ForceEndRound", Native_EndRound);
    CreateNative("TTT_RegisterShopItem", Native_RegisterShopItem);
    CreateNative("TTT_RemoveShopItem", Native_RemoveShopItem);
    CreateNative("TTT_RegisterViewModel", Native_RegisterViewModel);
    CreateNative("TTT_SetViewModel", Native_SetViewModel);
    CreateNative("TTT_SetViewModelSequence", Native_SetViewModelSequence);
    CreateNative("TTT_SetViewModelCycle", Native_SetViewModelCycle);
    CreateNative("TTT_SetViewModelPlaybackRate", Native_SetViewModelPlaybackRate);
    CreateNative("TTT_CanClientUseEntity", Native_CanClientUseEntity);
    CreateNative("TTT_GetHudChannel", Native_GetHudChannel);
    CreateNative("TTT_GiveClientRadar", Native_GiveClientRadar);
    CreateNative("TTT_SetEntityGlow", Native_SetEntityGlow);
    CreateNative("TTT_GetShopItemCount", Native_GetShopItemCount);
    CreateNative("TTT_GetShopItemInfo", Native_GetShopItemInfo);
    CreateNative("TTT_IsBodyFound", Native_IsBodyFound);
}

stock Native_GetRoleNums(Handle Plugin, int Params)
{
    int role = GetNativeCell(1);
    switch(role)
    {
        case TTT_ROLE_INNOCENT : return InnocentNums;
        case TTT_ROLE_DETECTIVE : return DetectiveNums;
        case TTT_ROLE_TRAITOR : return TraitorNums;
        default : return 0
    }
}

stock Native_GetClientRole(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    if(IsClientValid(client))
        return g_Client[client].Role;
    return TTT_ROLE_NONE;
}

stock Native_SetClientRole(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    int role = GetNativeCell(2);
    if(IsClientValid(client) && IsPlayerAlive(client))
    {
        SetClientRole(client, role);
        return true;
    }
    return false;
}

stock Native_GetClientCredits(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    if(IsClientValid(client))
        return g_Client[client].Credits;
    return -1;
}

stock Native_SetClientCredits(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    int credits = GetNativeCell(2);
    if(IsClientValid(client) && credits != g_Client[client].Credits)
    {
        CPrintToChat(client, "%s你%s了 %d 点积分", TTT_TAG, (credits - g_Client[client].Credits > 0) ? "获得" : "被扣除", (credits - g_Client[client].Credits > 0) ? credits - g_Client[client].Credits : (credits - g_Client[client].Credits) * -1);
        g_Client[client].Credits = credits;
        return true;
    }
    return false;
}

stock Native_SetClientLeak(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    bool leak = GetNativeCell(2);
    if(IsClientValid(client) && IsPlayerAlive(client))
    {
        g_Client[client].Leak = leak;
        return true;
    }
    return false;
}

stock Native_EndRound(Handle Plugin, int Params)
{
    int team = GetNativeCell(1);
    TTT_EndRound(team);
}

stock Native_RegisterShopItem(Handle Plugin, int Params)
{
    char ItemName[32], ItemDesc[128];
    GetNativeString(1, ItemName, sizeof(ItemName));
    int ItemType = GetNativeCell(2);
    GetNativeString(3, ItemDesc, sizeof(ItemDesc));
    int ItemCost = GetNativeCell(4);
    int ItemTeam = GetNativeCell(5);
    int ItemTeamBuyLimit = GetNativeCell(6);
    int ItemBuyLimit = GetNativeCell(7);
    int ItemTimeLimit = GetNativeCell(8);

    ShopItem ShopList;
    ShopList.ItemID = g_aShopItem.Length + 1;
    PrintToServer("[商店注册] 物品=%s, ItemID=%d", ShopList.ItemName, ShopList.ItemID);
    Format(ShopList.ItemName, sizeof(ShopList.ItemName), ItemName);
    ShopList.ItemType = ItemType;
    Format(ShopList.ItemDesc, sizeof(ShopList.ItemDesc), ItemDesc);
    ShopList.ItemCost = ItemCost;
    ShopList.ItemTeam = ItemTeam;
    ShopList.ItemTeamBuyLimit = ItemTeamBuyLimit;
    ShopList.ItemBuyLimit = ItemBuyLimit;
    ShopList.ItemTimeLimit = ItemTimeLimit;
    g_aShopItem.PushArray(ShopList);
    return ShopList.ItemID;
}

stock Native_RemoveShopItem(Handle Plugin, int Params)
{
    int ItemID = GetNativeCell(1);
    ShopItem Item;
    for(int i;i < g_aShopItem.Length;i++)
    {
        g_aShopItem.GetArray(i, Item, sizeof(Item));
        if(Item.ItemID == ItemID)
        {
            g_aShopItem.Erase(i);
            break;
        }
    }
}

stock Native_RegisterViewModel(Handle Plugin, int Params)
{
    ViewModel ViewModelArray;
    GetNativeString(1, ViewModelArray.weapon_base, sizeof(ViewModelArray.weapon_base));
    ViewModelArray.model_index = GetNativeCell(2);

    ViewModel ViewModelArray2;
    for(int i;i < g_aViewModel.Length;i++)
    {
        g_aViewModel.GetArray(i, ViewModelArray2, sizeof(ViewModelArray2));
        if(strcmp(ViewModelArray2.weapon_base, ViewModelArray.weapon_base, false) == 0)
        {
            ViewModelArray2.model_index = ViewModelArray.model_index;
            g_aViewModel.SetArray(i, ViewModelArray2);
            return;
        }
    }
    g_aViewModel.PushArray(ViewModelArray);
}

stock Native_SetViewModel(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    if(IsClientValid(client) && IsPlayerAlive(client))
    {
        DataPack dp = new DataPack();
        dp.WriteCell(client);
        dp.WriteCell(GetNativeCell(2));
        RequestFrame(ChangeViewModel, dp);
    }
}

public ChangeViewModel(DataPack dp)
{
    dp.Reset();
    int client = dp.ReadCell();
    int model_index = dp.ReadCell();
    SetEntProp(g_Client[client].ClientVM[1], Prop_Send, "m_nModelIndex", model_index);
    CloseHandle(dp);
}

stock Native_SetViewModelSequence(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    int Sequence = GetNativeCell(2);
    if(IsClientValid(client) && IsPlayerAlive(client))
    {
        SetEntProp(g_Client[client].ClientVM[0], Prop_Data, "m_nSequence", Sequence);
    }
}

stock Native_SetViewModelCycle(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    new String:Cycle[8];
    GetNativeString(2, Cycle, sizeof(Cycle));
    if(IsClientValid(client) && IsPlayerAlive(client))
    {
        SetEntPropFloat(g_Client[client].ClientVM[0], Prop_Send, "m_flCycle", StringToFloat(Cycle));
    }
}

stock Native_SetEntityGlow(Handle plugin, int numParams)
{
    int entIndex = GetNativeCell(1);
    bool m_bGlowEnabled = GetNativeCell(2);
    int flag = GetNativeCell(3);
    int R = GetNativeCell(4);
    int G = GetNativeCell(5);
    int B = GetNativeCell(6);

    SetEntProp(entIndex, Prop_Send, "m_bGlowEnabled", m_bGlowEnabled);

    if (flag == 1) {
        SetEntProp(entIndex, Prop_Send, "m_bGlowOccluded", true);
        SetEntProp(entIndex, Prop_Send, "m_bGlowNonOccluded", false);
    } else if (flag == 2) {
        SetEntProp(entIndex, Prop_Send, "m_bGlowOccluded", true);
        SetEntProp(entIndex, Prop_Send, "m_bGlowNonOccluded", true);
    } else {
        SetEntProp(entIndex, Prop_Send, "m_bGlowOccluded", false);
        SetEntProp(entIndex, Prop_Send, "m_bGlowNonOccluded", true);
    }
    
    SetEntProp(entIndex, Prop_Send, "m_fcolorR", R);
    SetEntProp(entIndex, Prop_Send, "m_fcolorG", G);
    SetEntProp(entIndex, Prop_Send, "m_fcolorB", B);
}

stock Native_SetViewModelPlaybackRate(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    new String:PlaybackRate[8];
    GetNativeString(2, PlaybackRate, sizeof(PlaybackRate));
    if(IsClientValid(client) && IsPlayerAlive(client))
    {
        SetEntPropFloat(g_Client[client].ClientVM[0], Prop_Send, "m_flPlaybackRate", StringToFloat(PlaybackRate));
    }
}

stock Native_CanClientUseEntity(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    int entity = GetNativeCell(2);
    return CanClientUseEntity(client, entity);
}

stock any Native_GetHudChannel(Handle Plugin, int Params)
{
    int Channel = GetNativeCell(1);
    switch(Channel)
    {
        case view_as<int>(HUD_CrossHair): return SyncHUDChannel_CrossHair;
        case view_as<int>(HUD_Infomation1) : return SyncHUDChannel_Infomation1;
        case view_as<int>(HUD_Infomation2) : return SyncHUDChannel_Infomation2;
        case view_as<int>(HUD_GameStatus) : return SyncHUDChannel_GameStatus;
    }
    return SyncHUDChannel_CrossHair;
}

stock Native_GiveClientRadar(Handle Plugin, int Params)
{
    int client = GetNativeCell(1);
    if(!IsClientValid(client) || !IsPlayerAlive(client))
        return 0;
    
    float origin[3];
    GetClientAbsOrigin(client, origin);
    origin[2] += 40.0;
    
    int ent = CreateEntityByName("env_sprite");
    if(ent == -1)
        return 0;
    
    DispatchKeyValue(ent, "model", "materials/sprites/glow01.vmt");
    DispatchKeyValue(ent, "classname", "env_sprite");
    DispatchKeyValue(ent, "spawnflags", "1024");
    DispatchKeyValue(ent, "scale", "0.3");
    DispatchKeyValue(ent, "rendermode", "1");
    DispatchKeyValue(ent, "renderamt", "255");
    DispatchKeyValue(ent, "rendercolor", "255 255 0");  // 黄色标记
    
    DispatchSpawn(ent);
    TeleportEntity(ent, origin, NULL_VECTOR, NULL_VECTOR);
    
    CreateTimer(5.0, Timer_RemoveRadarMark, EntIndexToEntRef(ent));
    
    return 1;
}

public Action Timer_RemoveRadarMark(Handle timer, int ref)
{
    int ent = EntRefToEntIndex(ref);
    if(IsValidEntity(ent))
    {
        AcceptEntityInput(ent, "Kill");
    }
    return Plugin_Stop;
}

stock Native_IsBodyFound(Handle Plugin, int Params)
{
    int victim = GetNativeCell(1);
    if(!IsClientValid(victim)) return false;
    
    for(int i = 0; i < g_aRagdoll.Length; i++)
    {
        Ragdoll body;
        g_aRagdoll.GetArray(i, body, sizeof(body));
        if(body.Victim == victim)
        {
            return body.Found; // 返回这具尸体是否已经被发现
        }
    }
    return false;
}

stock Native_GetShopItemCount(Handle Plugin, int Params)
{
    return g_aShopItem.Length;
}

stock Native_GetShopItemInfo(Handle Plugin, int Params)
{
    int index = GetNativeCell(1);
    if(index < 0 || index >= g_aShopItem.Length)
        return false;

    ShopItem Item;
    g_aShopItem.GetArray(index, Item, sizeof(Item));

    SetNativeCellRef(2, Item.ItemID);
    SetNativeString(3, Item.ItemName, GetNativeCell(4));
    SetNativeCellRef(5, Item.ItemType);
    SetNativeCellRef(6, Item.ItemTeam);
    SetNativeCellRef(7, Item.ItemCost);

    return true;
}