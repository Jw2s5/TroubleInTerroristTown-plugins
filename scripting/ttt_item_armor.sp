#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <cstrike>
#include <TroubleinTerroristTown>

public Plugin:myinfo = {
    name = "[TTT] 护甲",
    author = "Jw2s5",
    description = "TTT道具 - 购买护甲（叠加）",
    version = "1.0",
    url = ""
}

int g_ItemID[3];

#define ARMOR_ADD 60  // 购买的护甲值

public OnConfigsExecuted()
{
    g_ItemID[0] = TTT_RegisterShopItem("护甲", ITEMTYPE_PassiveEquip, "增加60点护甲值", 1, TTT_ROLE_INNOCENT, -1, 1, 0);
    g_ItemID[1] = TTT_RegisterShopItem("护甲", ITEMTYPE_PassiveEquip, "增加60点护甲值", 1, TTT_ROLE_DETECTIVE, -1, 1, 0);
    g_ItemID[2] = TTT_RegisterShopItem("护甲", ITEMTYPE_PassiveEquip, "增加60点护甲值", 1, TTT_ROLE_TRAITOR, -1, 1, 0);
}

public OnPluginEnd()
{
    for(int i;i < sizeof(g_ItemID);i++)
    {
        if(g_ItemID[i]) TTT_RemoveShopItem(g_ItemID[i]);
    }
}

public Action TTT_OnItemPurchase(int client, int ItemID)
{
    if(ItemID == g_ItemID[0] || ItemID == g_ItemID[1] || ItemID == g_ItemID[2])
    {
        // 获取当前护甲值
        int currentArmor = GetEntProp(client, Prop_Send, "m_ArmorValue");
        
        // 护甲上限100
        if(currentArmor >= 100)
        {
            CPrintToChat(client, "%s护甲已满！", TTT_TAG);
            return Plugin_Handled;
        }
        
        // 叠加护甲，不超过100
        int newArmor = currentArmor + ARMOR_ADD;
        if(newArmor > 100) newArmor = 100;
        
        SetEntProp(client, Prop_Send, "m_ArmorValue", newArmor);
        SetEntProp(client, Prop_Send, "m_bHasHelmet", 1);
        
        CPrintToChat(client, "%s护甲增加了%d点，当前护甲值: %d", TTT_TAG, ARMOR_ADD, newArmor);
    }
    return Plugin_Continue;
}