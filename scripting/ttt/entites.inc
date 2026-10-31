InitEntities(int entity)
{
    if(IsValidEntity(entity))
    {
        char classname[64];
        GetEntityClassname(entity, classname, sizeof(classname));
        
        if(StrEqual(classname, "func_buyzone"))
        {
            AcceptEntityInput(entity, "Kill");
        }
        else if(StrEqual(classname, "hostage_entity"))
        {
            AcceptEntityInput(entity, "Kill");
        }
        else if(StrEqual(classname, "func_hostage_rescue"))
        {
            AcceptEntityInput(entity, "Kill");
        }
        else if(StrEqual(classname, "func_bomb_target"))
        {
            AcceptEntityInput(entity, "Kill");
        }
        else if(StrEqual(classname, "info_player_counterterrorist"))
        {
            // 强制把所有 CT 出生点变成 T 出生点
            SetEntPropString(entity, Prop_Data, "m_iClassname", "info_player_terrorist");
        }
        else if(StrEqual(classname, "prop_physics") || StrEqual(classname, "prop_physics_multiplayer") || StrEqual(classname, "func_physbox"))
        {
            // 取消物理道具的碰撞，防止卡住
            SetEntProp(entity, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_NONE);
        }
    }
}

public OnEntitySpawned(entity)
{
    new Owner = GetEntPropEnt(entity, Prop_Send, "m_hOwner");
    if (IsClientValid(Owner))
    {
        // 记录玩家的第一人称视图模型（Default ViewModel）
        if (GetEntProp(entity, Prop_Send, "m_nViewModelIndex") == 0)
        {
            g_Client[Owner].ClientVM[0] = entity;
        }
        // 记录玩家的自定义视图模型（Custom ViewModel）
        else if (GetEntProp(entity, Prop_Send, "m_nViewModelIndex") == 1)
        {
            g_Client[Owner].ClientVM[1] = entity;
        }
    }
}