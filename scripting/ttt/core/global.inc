enum struct Ragdoll
{
    int EntityRef;
    int Victim;
    int Attacker;
    int VictimRole;
    int AttackerRole;
    int CallIcon;
    int Credits;
    int UnknownIcon;
    bool Checked;
    bool DNAPicked;
    bool Scanned;
    bool Found;
    bool Explode;
    bool HeadShot;
    float GameTime;
    char VictimName[MAX_NAME_LENGTH];
    char AttackerName[MAX_NAME_LENGTH];
    char Weaponused[32];
    char Model[PLATFORM_MAX_PATH+1];
}

enum struct Music
{
    char MUSIC_NAME[64];
    float MUSIC_LENGTH;
}

enum struct ShopItem
{
    int ItemID;
    char ItemName[32];
    int ItemType;
    char ItemDesc[64];
    int ItemCost;
    int ItemTeam;
    int ItemTeamBuyLimit;
    int ItemBuyLimit;
    int ItemTimeLimit;
}

enum struct PlayerData
{
    int Role;
    int RoleIcon;
    int CivilianIcon[MAXPLAYERS + 1];
    int DNAIcon;
    int CallTime;
    int Karma;
    int Credits;
    int Frags[2];
    int VoiceChannel;
    int DNAProcess;
    int FakeEntity;
    int DNACalled;
    int ItemBoughtTimes[128];
    int Object;
    int ClientVM[2];
    bool SpawnCheck;
    bool IsCustom;
    bool Leak;
    bool IconLeak;
    float Distance;
    float PressTime;
    float Force[3];
    float WorldPos[3];
    ArrayList DNAList;
    Handle DNACheckTimer;
    Handle DNACheckCountdownTimer;
    Handle DNAIconRemoveTimer;
}

enum struct ViewModel {
    char weapon_base[32];
    int model_index;
}

#define DeadSoundNums 9

int DetectiveNums;
int InnocentNums;
int TraitorNums;
int GameStartTime;
int RoundTime;
int TraitorTime;
int TimePassed;
int InnocentWin;
int TraitorWin;
int PlayingMusic;
int g_iMusicIndex = 0;
int TeamCanBoughtTimes[4][128];
int V_PhysicsBar;
int W_PhysicsBar;
int g_iLastTraitor[MAXPLAYERS + 1];
int g_iLastDetective[MAXPLAYERS + 1];
bool IsRoundTimeExtend, IsTraitorTimeExtend;
bool IsGameStart, IsGameEnd, IsRequiredToPlay;
bool g_bShowDeadList[MAXPLAYERS + 1];

Handle SyncHUDChannel_CrossHair = INVALID_HANDLE;
Handle SyncHUDChannel_Infomation1 = INVALID_HANDLE;
Handle SyncHUDChannel_Infomation2 = INVALID_HANDLE;
Handle SyncHUDChannel_GameStatus = INVALID_HANDLE;
Handle tShowHUD[MAXPLAYERS + 1];
Handle tGameStart = INVALID_HANDLE;
Handle tGameStartCountdown = INVALID_HANDLE;
Handle tRoundTime = INVALID_HANDLE;
Handle tTraitorTime = INVALID_HANDLE;
Handle tEndGameTime = INVALID_HANDLE;
Handle tGameMusic = INVALID_HANDLE;
Handle GameStartCountdownData;

GlobalForward g_fwOnItemPurchase;
GlobalForward g_fwOnTakeDamage;
GlobalForward g_fwOnTraceAttack;
GlobalForward g_fwOnEntityInfoHUDDisplay;
GlobalForward g_fwOnGrabEntity;

char RadioCMDs[][] =  {
    "coverme",
    "takepoint",
    "holdpos",
    "regroup",
    "followme",
    "takingfire",
    "go",
    "fallback",
    "sticktog",
    "getinpos",
    "stormfront",
    "report",
    "roger",
    "enemyspot",
    "needbackup",
    "sectorclear",
    "inposition",
    "reportingin",
    "getout",
    "negative",
    "enemydown"
};

Music MusicList[14] = 
{
    {"ttt/07_the_plot_thickens.mp3", 121.0},
    {"ttt/box15.mp3", 244.0},
    {"ttt/camp.mp3", 167.0},
    {"ttt/fuan.mp3", 115.0},
    {"ttt/horror2.mp3", 187.0},
    {"ttt/kuroi_light.mp3", 118.0},
    {"ttt/l2.mp3", 183.0},
    {"ttt/promise.mp3", 104.0},
    {"ttt/puzzle_snd_fix.mp3", 154.0},
    {"ttt/supposition.mp3", 109.0},
    {"ttt/suspicion.mp3", 118.0},
    {"ttt/themeoflaura_v2.mp3", 111.0},
    {"ttt/night_02.mp3", 204.0},
    {"ttt/silent_night_01.mp3", 279.0}
};

PlayerData g_Client[MAXPLAYERS + 1];

new String:innocent_win_sound[64] = "ttt/pingmin_win.mp3";
new String:traitor_win_sound[64] = "ttt/pantu_win.mp3";
new String:shop_buy_sound[64] = "ttt/shop_selected.wav";
new String:DetectiveIcon[32] = "detective_icon";
new String:TraitorIcon[32] = "traitor_icon";
new String:CallIcon[32] = "body_call";
new String:DNAIcon[32] = "dna_result";
new String:Buffer[64];

ArrayList g_aRagdoll;
ArrayList g_aShopItem;
ArrayList g_aViewModel;

InitDynamicArrays()
{
    g_aRagdoll = new ArrayList(sizeof(Ragdoll));
    g_aShopItem = new ArrayList(sizeof(ShopItem));
    for(int i;i < MAXPLAYERS + 1;i++)
    {
        g_Client[i].DNAList = new ArrayList(sizeof(Ragdoll));
        tShowHUD[i] = INVALID_HANDLE;
    }
    g_aViewModel = new ArrayList(sizeof(ViewModel));
}