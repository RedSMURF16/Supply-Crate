/*
*
*	Supply Crate by RedSMURF
*
*
*	Description:
*       This plugin adds a menu from where you can choose different crate types, it got "Ammo Crates" for supplying ammunition, "Grenades Crates" for supplying grenades, and Market Crates for selling items.
*       All crates are fully customizable with settings like Capacity, Mode, Cooldown, etc..
*       Players can interact with crates by pressing E (IN_USE) while being in the distance range set in g_eSetting[SETTING_CRATE_RANGE]
*
*
*	Cvars:
*		None
*
*	Commands:
*       say /sc                     "Opens the Crates menu."
*       say_team /sc                "Opens the Crates menu."
*       say /supplycrate            "Opens the Crates menu."
*       say_team /supplycrate       "Opens the Crates menu."
*       sc_reload                   "Reloads the configuration file."
*       supplycrate_reload          "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*       v2.0: Major rework with performance improvements and new mechanics,
*             Improved crate placement logic for natural alignment with ground and walls,
*             Crates might refill after a certain duration,
*             Added activation delay after round start,
*             Crates can break or explode from damage,
*             CRATE_FACTOR is used with AMMO CRATES to scale the supplied ammo.
*       v2.1: Added team-restricted crates (T, CT, Both or Disabled),
*             Added reCrate chance machanics for destroyed crates,
*             Improved rendering logic
*       v2.2: Switched CRATE_MODE to Bitflags for cleaner multi-option support
*             CRATE_FACTOR is now used by grenades crates for scaling
*             Added CRATE_FACTOR_MAX for ammo crates to control maximum supply
*       v2.3: Added weapon interaction list for crates,
*             Precached busting metal sounds and gibs for maps that do not support them
*       v2.4: added FLAG_ACTIVE_DURATION, improved round-start logic
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT             32
#define MEMBER_AMMO_TYPE    49
#define BREAK_FLAG_METAL    2
#define CRATE_KEY           8421
#define CRATE_ARRAY_ITEM    pev_iuser1

/**
 *  Crate animation sequences.
 */
#define CRATE_SEQ_IDLE          0
#define CRATE_SEQ_OPENCLOSE     1

/**
 *  Crate Bitflag Armor.
 */
#define CRATE_FLAG_VEST         (1 << 0)
#define CRATE_FLAG_VESTHELM     (1 << 1)

/**
 *  Crate Bitflag Ammo.
 */
#define CRATE_FLAG_AMMO         (1 << 2)

/**
 *  Crate Bitflag Grenades.
 */
#define CRATE_FLAG_HE           (1 << 2)
#define CRATE_FLAG_FB1          (1 << 3)
#define CRATE_FLAG_FB2          (1 << 4)
#define CRATE_FLAG_SMOKE        (1 << 5)

#define XO_CBASEPLAYER          5
#define XO_CBASEPLAYERWEAPON    4

new const PLUGIN_VERSION[]          = "2.4"
new const Float:DELAY_ON_CONNECT    = 1.0
new const ERROR_FILE[]              = "SupplyCrate_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_CRATE
}

enum
{
    DTYPE_FLOAT,
    DTYPE_FLOAT_RANGE,
    DTYPE_INT,
    DTYPE_INT_RANGE,
    DTYPE_BOOL,
    DTYPE_FLAGS,
    DTYPE_VECTOR,
    DTYPE_VECTOR_FLOAT,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_STRING_SPRITE,
    DTYPE_VECTOR_LIST
}

enum
{
    FLAG_BREAK              = (1 << 0),
    FLAG_EXPLODE            = (1 << 1),
    FLAG_REFILL             = (1 << 2),
    FLAG_ACTIVE_DELAY       = (1 << 3),
    FLAG_ACTIVE_DURATION    = (1 << 4),

    FLAG_SHOW               = (1 << 5),
    FLAG_DEAD               = (1 << 6),
    FLAG_GHOST              = (1 << 7),
    FLAG_SELECT             = (1 << 8),
    FLAG_ACTIVE             = (1 << 9),
    FLAG_GROUND             = (1 << 10)
}

enum
{
    STATUS_DEFAULT,
    STATUS_FORCE_ENABLE,
    STATUS_FORCE_DISABLE
}

enum
{
    SHOW_DEFAULT,
    SHOW_FORCE_SHOW,
    SHOW_FORCE_HIDE
}

enum
{
    TEAM_NONE,
    TEAM_T,
    TEAM_CT,
    TEAM_BOTH
}

enum
{
    CRATE_NEVER,
    CRATE_DELAY,
    CRATE_ROUND_START
}

enum
{
    WEAPON_ALL,
    WEAPON_ONLY,
    WEAPON_EXCEPT
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_GIB[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_CLASS,
    SETTING_DEFAULT_FLAGS,
    SETTING_DEFAULT_TEAM,
    SETTING_DEFAULT_MODE,

    Float:SETTING_DEFAULT_REFILL[2],
    Float:SETTING_DEFAULT_COOLDOWN,
    Float:SETTING_DEFAULT_CAPACITY,

    SETTING_DEFAULT_CRATE_MODE,
    Float:SETTING_DEFAULT_SPAWN[2],
    Float:SETTING_DEFAULT_CRATE_CHANCE,

    Float:SETTING_DEFAULT_ACTIVE_DELAY[2],
    Float:SETTING_DEFAULT_ACTIVE_DURATION[2],
    Float:SETTING_DEFAULT_ACTIVE_COOLDOWN[2],

    Float:SETTING_DEFAULT_HEALTH[2],
    SETTING_DEFAULT_ARMOR[2],
    Float:SETTING_DEFAULT_FACTOR,
    Float:SETTING_DEFAULT_FACTOR_MAX,
    Float:SETTING_DEFAULT_EXPLODE_DAMAGE[2],
    Float:SETTING_DEFAULT_EXPLODE_RADIUS[2],
    SETTING_DEFAULT_WEAPON_MODE,
    SETTING_DEFAULT_WEAPON_LIST[31],

    Float:SETTING_MINS[3],
    Float:SETTING_MAXS[3],

    bool:SETTING_CRATE_LOAD,
    Float:SETTING_CRATE_RANGE,
    Float:SETTING_CRATE_CHECK,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
    Float:SETTING_OFFSET_STEP,
    SETTING_GHOST_ALPHA,

    Float:SETTING_BREAK_VELO_Z[2],
    SETTING_BREAK_VELO_RANDOM[2],
    SETTING_BREAK_COUNT[2],
    SETTING_BREAK_LIFE[2],

    SETTING_SPRITE_ZEROGXPLODE,
    Array:SETTING_SOUND_METAL,
    SETTING_SOUND_BUTTON4[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_LOCKED[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_CLIP[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_CHCHING[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_NAV[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_ALERT[MAX_RESOURCE_PATH_LENGTH],

    SETTING_COLOR_ACTIVE[3],
    SETTING_COLOR_INACTIVE[3]
}

enum _:CRATE
{
    CRATE_ID,
    CRATE_ITEM,
    CRATE_CLASS,
    CRATE_FLAGS,
    CRATE_STATUS,
    CRATE_SHOW,
    CRATE_TEAM,
    CRATE_MODE,
    CRATE_NAME[MAX_VALUE_LENGTH],
    CRATE_MODEL[MAX_RESOURCE_PATH_LENGTH],

    Float:CRATE_ORIGIN[3],
    Float:CRATE_ANGLES[3],
    Float:CRATE_MINS[3],
    Float:CRATE_MAXS[3],

    Float:CRATE_REFILL[2],
    Float:CRATE_COOLDOWN,
    Float:CRATE_CAPACITY,
    Float:CRATE_FRAMERATE,
    Float:CRATE_CAPACITY_MAX,

    CRATE_CRATE_MODE,
    Float:CRATE_SPAWN[2],
    Float:CRATE_CRATE_CHANCE,
    Float:CRATE_NEXT_SPAWN,

    Float:CRATE_ACTIVE_DELAY[2],
    Float:CRATE_ACTIVE_DURATION[2],
    Float:CRATE_ACTIVE_COOLDOWN[2],

    Float:CRATE_HEALTH[2],
    CRATE_ARMOR[2],
    Float:CRATE_FACTOR,
    Float:CRATE_FACTOR_MAX,
    Float:CRATE_EXPLODE_DAMAGE[2],
    Float:CRATE_EXPLODE_RADIUS[2],

    Float:CRATE_NEXT_USE,
    Float:CRATE_NEXT_EMPTY,
    Float:CRATE_NEXT_REFILL,
    Float:CRATE_NEXT_ENABLE,
    Float:CRATE_NEXT_DISABLE,

    CRATE_WEAPON_MODE,
    bool:CRATE_WEAPON_LIST[31]
}

enum _:PLAYER_DATA
{
    PDATA_CRATE_GHOST,
    PDATA_CRATE_MENU,
    PDATA_CRATE_USE,
    bool:PDATA_CRATE_ACTION,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET
}

enum
{
    CLASS_AMMO,
    CLASS_GRENADES,
    CLASS_MARKET
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT,

    SOUND_BUTTON4,
    SOUND_LOCKED,
    SOUND_CLIP,
    SOUND_CHCHING,
    SOUND_METAL
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_STATUS,
    MENU_REMOVE,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_STATUS,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE,
    STATUS_ALL_DEFAULT
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    ROTATE_RIGHT,
    ROTATE_LEFT,

    ROTATE_GROUND = 3,
    ROTATE_PLACE
}

new Float:g_fDirections[][] =
{
    {-1.0, 0.0, 0.0},
    {1.0, 0.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, -1.0},
    {0.0, 0.0, 1.0}
}

new const g_iWeaponMaxBP[] =
{
    0,      52,     0,    90,     0,    32,     0,   100,    90,     1,
    120,   100,   100,    90,    90,    90,   100,   120,    30,   120,
    200,    32,    90,   120,    90,     0,    35,    90,    90,     0,
    100
}

new const g_iWeaponMarket[] =
{
    0,     600,  2200,  2750,   300,  3000,     0,  1400,  3500,   300,
    800,   750,  1700,  4200,  2000,  2250,   500,   400,  4750,  1500,
    5750, 1700,  3100,  1250,  5000,   200,   650,  2500,  3500,     0,
    2350
}

new g_szMenuHandler[][] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerStatus",
    "menuHandlerRemove",
    "menuHandlerRotate"
}

new g_szCN[][32] =
{
    "supplyCrate_ammo",
    "supplyCrate_grenades",
    "supplyCrate_market"
}

new Array:g_aCrate,
    Array:g_aCrateConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead = false,
    g_iCrate,
    g_iCrateConfig,
    g_iAmmoPickup, g_iWeapPickup,
    g_iMaxPlayers

new g_szStatus[][] = {"CRATE_DEFAULT", "CRATE_ENABLED", "CRATE_DISABLED"}
new g_szStatusChat[][] = {"CRATE_CHAT_DEFAULT", "CRATE_CHAT_ENABLED", "CRATE_CHAT_DISABLED"}
new g_szStatusColor[][] = {"\d", "\y", "\r"}

public plugin_init()
{
    register_plugin("Supply Crate", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("say /sc",               "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /sc",          "cmdMenu", ADMIN_RCON)
    register_clcmd("say /supplycrate",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /supplycrate", "cmdMenu", ADMIN_RCON)
    register_concmd("sc_reload",            "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")
    register_concmd("supplycrate_reload",   "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")

    register_dictionary("SupplyCrate.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    register_forward(FM_AddToFullPack, "fwdAddToFullPack", 1)
    RegisterHam(Ham_Spawn, "info_target", "fwdSpawn", 1)
    RegisterHam(Ham_TakeDamage, "info_target", "fwdTakeDamage")
    RegisterHam(Ham_TraceAttack, "info_target", "fwdTraceAttack", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_logevent("eventRoundStart", 2, "1=Round_Start")
    g_iAmmoPickup = get_user_msgid("AmmoPickup")
    g_iWeapPickup = get_user_msgid("WeapPickup")

    set_task(0.1, "crateTask", .flags = "b")

    crateInit()
    g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
    g_aCrate = ArrayCreate(CRATE)
    g_aCrateConfig = ArrayCreate(CRATE)
    g_eSettings[SETTING_SOUND_METAL] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)

    precache_model("models/metalplategibs.mdl")
    precache_sound("debris/metal1.wav")
    precache_sound("debris/metal2.wav")
    precache_sound("debris/metal3.wav")
    precache_sound("debris/bustmetal1.wav")
    precache_sound("debris/bustmetal2.wav")

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aCrate)
    ArrayDestroy(g_aCrateConfig)
    ArrayDestroy(g_eSettings[SETTING_SOUND_METAL])
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1)
    || !is_user_alive(id)
    || g_ePlayerData[id][PDATA_CRATE_GHOST] )
        return PLUGIN_HANDLED

    crateSound(id, SOUND_MENU_NAV)
    crateMenu(id, MENU_ROOT)

    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public client_command(id)
{
    if ( !g_ePlayerData[id][PDATA_CRATE_GHOST] )
        return PLUGIN_CONTINUE

    new szCmd[16]
    read_argv(0, szCmd, charsmax(szCmd))

    if ( contain(szCmd, "weapon_") != -1
    || equal(szCmd, "invnext")
    || equal(szCmd, "invprev")
    || equal(szCmd, "lastinv") )
        return PLUGIN_HANDLED

    return PLUGIN_CONTINUE
}

public eventRoundStart()
{
    if ( !g_iCrate )
        return PLUGIN_HANDLED

    new eCrate[CRATE]

    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        crateReset(eCrate)

        if ( eCrate[CRATE_SHOW] != SHOW_DEFAULT
        || eCrate[CRATE_CRATE_MODE] != CRATE_ROUND_START )
        {
            ArraySetArray(g_aCrate, i, eCrate)
            continue
        }

        if ( eCrate[CRATE_CRATE_CHANCE] >= random_float(0.0, 1.0) )
        {
            eCrate[CRATE_FLAGS] |= (FLAG_SHOW | FLAG_ACTIVE)
            crateState(eCrate, true, true)
        }
        else
        {
            eCrate[CRATE_FLAGS] &= ~(FLAG_SHOW | FLAG_ACTIVE)
            crateState(eCrate, false, false)
        }

        ArraySetArray(g_aCrate, i, eCrate)
    }

    return PLUGIN_HANDLED
}

stock ReadFile()
{
    if ( g_bFileWasRead )
    {
        for ( new id = 1; id <= g_iMaxPlayers; id ++ )
            if ( is_user_connected(id))
                UpdateData(id)

        ArrayClear(g_eSettings[SETTING_SOUND_METAL])
        ArrayClear(g_aCrateConfig)
        g_iCrateConfig = 0
    }

    new g_szFileName[MAX_RESOURCE_PATH_LENGTH]
    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/SupplyCrate.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE],
        szKey[MAX_VALUE_LENGTH],
        szValue[MAX_RESOURCE_PATH_LENGTH],
        eCrate[CRATE], iSection = SECTION_NONE, iLine, iPos

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax(szData), "[", "")
                    replace(szData, charsmax(szData), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                    }
                    else
                    {
                        if ( g_iCrateConfig )
                            ArrayPushArray(g_aCrateConfig, eCrate)

                        copy(eCrate[CRATE_NAME], charsmax(eCrate[CRATE_NAME]), szData)
                        copy(eCrate[CRATE_MODEL], charsmax(eCrate[CRATE_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
                        eCrate[CRATE_CLASS]                 = g_eSettings[SETTING_DEFAULT_CLASS]
                        eCrate[CRATE_FLAGS]                 = g_eSettings[SETTING_DEFAULT_FLAGS]
                        eCrate[CRATE_TEAM]                  = g_eSettings[SETTING_DEFAULT_TEAM]
                        eCrate[CRATE_MODE]                  = g_eSettings[SETTING_DEFAULT_MODE]

                        eCrate[CRATE_REFILL][0]             = g_eSettings[SETTING_DEFAULT_REFILL][0]
                        eCrate[CRATE_REFILL][1]             = g_eSettings[SETTING_DEFAULT_REFILL][1]
                        eCrate[CRATE_COOLDOWN]              = g_eSettings[SETTING_DEFAULT_COOLDOWN]
                        eCrate[CRATE_CAPACITY]              = g_eSettings[SETTING_DEFAULT_CAPACITY]
                        eCrate[CRATE_FRAMERATE]             = (2.15 + (eCrate[CRATE_COOLDOWN] - 0.5) / (40.0 - 0.5) * (3.25 - 2.15)) / eCrate[CRATE_COOLDOWN]

                        eCrate[CRATE_CRATE_MODE]            = g_eSettings[SETTING_DEFAULT_CRATE_MODE]
                        eCrate[CRATE_SPAWN][0]              = g_eSettings[SETTING_DEFAULT_SPAWN][0]
                        eCrate[CRATE_SPAWN][1]              = g_eSettings[SETTING_DEFAULT_SPAWN][1]
                        eCrate[CRATE_CRATE_CHANCE]          = g_eSettings[SETTING_DEFAULT_CRATE_CHANCE]

                        eCrate[CRATE_ACTIVE_DELAY][0]       = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][0]
                        eCrate[CRATE_ACTIVE_DELAY][1]       = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][1]
                        eCrate[CRATE_ACTIVE_DURATION][0]    = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][0]
                        eCrate[CRATE_ACTIVE_DURATION][1]    = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][1]
                        eCrate[CRATE_ACTIVE_COOLDOWN][0]    = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][0]
                        eCrate[CRATE_ACTIVE_COOLDOWN][1]    = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][1]

                        eCrate[CRATE_HEALTH][0]             = g_eSettings[SETTING_DEFAULT_HEALTH][0]
                        eCrate[CRATE_HEALTH][1]             = g_eSettings[SETTING_DEFAULT_HEALTH][1]
                        eCrate[CRATE_ARMOR][0]              = g_eSettings[SETTING_DEFAULT_ARMOR][0]
                        eCrate[CRATE_ARMOR][1]              = g_eSettings[SETTING_DEFAULT_ARMOR][1]
                        eCrate[CRATE_FACTOR]                = g_eSettings[SETTING_DEFAULT_FACTOR]
                        eCrate[CRATE_FACTOR_MAX]            = g_eSettings[SETTING_DEFAULT_FACTOR_MAX]
                        eCrate[CRATE_EXPLODE_DAMAGE][0]     = g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE][0]
                        eCrate[CRATE_EXPLODE_DAMAGE][1]     = g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE][1]
                        eCrate[CRATE_EXPLODE_RADIUS][0]     = g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS][0]
                        eCrate[CRATE_EXPLODE_RADIUS][1]     = g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS][1]

                        eCrate[CRATE_WEAPON_MODE]           = g_eSettings[SETTING_DEFAULT_WEAPON_MODE]
                        for ( new i = 1; i <= CSW_P90; i ++ )
                            eCrate[CRATE_WEAPON_LIST][i] = false

                        iSection = SECTION_CRATE
                        g_iCrateConfig ++
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        if ( equali(szKey, "SETTING_DEFAULT_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_GIB") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_GIB], charsmax(g_eSettings[SETTING_DEFAULT_GIB]))
                        else if ( equali(szKey, "SETTING_DEFAULT_CLASS") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_CLASS], charsmax(g_eSettings[SETTING_DEFAULT_CLASS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_TEAM") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_TEAM], charsmax(g_eSettings[SETTING_DEFAULT_TEAM]))
                        else if ( equali(szKey, "SETTING_DEFAULT_MODE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODE], charsmax(g_eSettings[SETTING_DEFAULT_MODE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_REFILL") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_REFILL], charsmax(g_eSettings[SETTING_DEFAULT_REFILL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_COOLDOWN], charsmax(g_eSettings[SETTING_DEFAULT_COOLDOWN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_CAPACITY") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_CAPACITY], charsmax(g_eSettings[SETTING_DEFAULT_CAPACITY]))
                        else if ( equali(szKey, "SETTING_DEFAULT_CRATE_MODE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_CRATE_MODE], charsmax(g_eSettings[SETTING_DEFAULT_CRATE_MODE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPAWN], charsmax(g_eSettings[SETTING_DEFAULT_SPAWN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_CRATE_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_CRATE_CHANCE], charsmax(g_eSettings[SETTING_DEFAULT_CRATE_CHANCE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DELAY") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DURATION") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_HEALTH") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_HEALTH], charsmax(g_eSettings[SETTING_DEFAULT_HEALTH]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ARMOR") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ARMOR], charsmax(g_eSettings[SETTING_DEFAULT_ARMOR]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FACTOR") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FACTOR], charsmax(g_eSettings[SETTING_DEFAULT_FACTOR]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FACTOR_MAX") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FACTOR_MAX], charsmax(g_eSettings[SETTING_DEFAULT_FACTOR_MAX]))
                        else if ( equali(szKey, "SETTING_DEFAULT_EXPLODE_DAMAGE") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE], charsmax(g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_EXPLODE_RADIUS") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS], charsmax(g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_WEAPON_MODE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_WEAPON_MODE], charsmax(g_eSettings[SETTING_DEFAULT_WEAPON_MODE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_WEAPON_LIST") )
                            parseSetting(DTYPE_VECTOR_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_WEAPON_LIST], charsmax(g_eSettings[SETTING_DEFAULT_WEAPON_LIST]))
                        else if ( equali(szKey, "SETTING_MINS") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MINS], charsmax(g_eSettings[SETTING_MINS]))
                        else if ( equali(szKey, "SETTING_MAXS") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MAXS], charsmax(g_eSettings[SETTING_MAXS]))
                        else if ( equali(szKey, "SETTING_CRATE_LOAD") )
                            parseSetting(DTYPE_BOOL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_CRATE_LOAD], charsmax(g_eSettings[SETTING_CRATE_LOAD]))
                        else if ( equali(szKey, "SETTING_CRATE_RANGE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_CRATE_RANGE], charsmax(g_eSettings[SETTING_CRATE_RANGE]))
                        else if ( equali(szKey, "SETTING_CRATE_CHECK") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_CRATE_CHECK], charsmax(g_eSettings[SETTING_CRATE_CHECK]))
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_BASE], charsmax(g_eSettings[SETTING_OFFSET_BASE]))
                        else if ( equali(szKey, "SETTING_OFFSET") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET], charsmax(g_eSettings[SETTING_OFFSET]))
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_STEP], charsmax(g_eSettings[SETTING_OFFSET_STEP]))
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_ALPHA], charsmax(g_eSettings[SETTING_GHOST_ALPHA]))
                        else if ( equali(szKey, "SETTING_BREAK_VELO_Z") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_BREAK_VELO_Z], charsmax(g_eSettings[SETTING_BREAK_VELO_Z]))
                        else if ( equali(szKey, "SETTING_BREAK_VELO_RANDOM") )
                            parseSetting(DTYPE_INT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_BREAK_VELO_RANDOM], charsmax(g_eSettings[SETTING_BREAK_VELO_RANDOM]))
                        else if ( equali(szKey, "SETTING_BREAK_COUNT") )
                            parseSetting(DTYPE_INT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_BREAK_COUNT], charsmax(g_eSettings[SETTING_BREAK_COUNT]))
                        else if ( equali(szKey, "SETTING_BREAK_LIFE") )
                            parseSetting(DTYPE_INT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_BREAK_LIFE], charsmax(g_eSettings[SETTING_BREAK_LIFE]))
                        else if ( equali(szKey, "SETTING_SPRITE_ZEROGXPLODE") )
                            parseSetting(DTYPE_STRING_SPRITE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SPRITE_ZEROGXPLODE], charsmax(g_eSettings[SETTING_SPRITE_ZEROGXPLODE]))
                        else if ( equali(szKey, "SETTING_SOUND_BUTTON4") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_BUTTON4], charsmax(g_eSettings[SETTING_SOUND_BUTTON4]))
                        else if ( equali(szKey, "SETTING_SOUND_LOCKED") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_LOCKED], charsmax(g_eSettings[SETTING_SOUND_LOCKED]))
                        else if ( equali(szKey, "SETTING_SOUND_CLIP") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_CLIP], charsmax(g_eSettings[SETTING_SOUND_CLIP]))
                        else if ( equali(szKey, "SETTING_SOUND_CHCHING") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_CHCHING], charsmax(g_eSettings[SETTING_SOUND_CHCHING]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_NAV") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_NAV], charsmax(g_eSettings[SETTING_SOUND_MENU_NAV]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_REMOVE") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_REMOVE], charsmax(g_eSettings[SETTING_SOUND_MENU_REMOVE]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_ALERT") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_ALERT], charsmax(g_eSettings[SETTING_SOUND_MENU_ALERT]))
                        else if ( equali(szKey, "SETTING_SOUND_METAL") )
                            parseSetting(DTYPE_ARRAY_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_METAL], charsmax(g_eSettings[SETTING_SOUND_METAL]))
                        else if ( equali(szKey, "SETTING_COLOR_ACTIVE") )
                            parseSetting(DTYPE_VECTOR, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_COLOR_ACTIVE], charsmax(g_eSettings[SETTING_COLOR_ACTIVE]))
                        else if ( equali(szKey, "SETTING_COLOR_INACTIVE") )
                            parseSetting(DTYPE_VECTOR, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_COLOR_INACTIVE], charsmax(g_eSettings[SETTING_COLOR_INACTIVE]))
                    }
                    case SECTION_CRATE:
                    {
                        if ( equali(szKey, "CRATE_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_MODEL], charsmax(eCrate[CRATE_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
                        else if ( equali(szKey, "CRATE_CLASS") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_CLASS], charsmax(eCrate[CRATE_CLASS]), g_eSettings[SETTING_DEFAULT_CLASS])
                        else if ( equali(szKey, "CRATE_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_FLAGS], charsmax(eCrate[CRATE_FLAGS]), g_eSettings[SETTING_DEFAULT_FLAGS])
                        else if ( equali(szKey, "CRATE_TEAM") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_TEAM], charsmax(eCrate[CRATE_TEAM]), g_eSettings[SETTING_DEFAULT_TEAM])
                        else if ( equali(szKey, "CRATE_MODE") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_MODE], charsmax(eCrate[CRATE_MODE]), g_eSettings[SETTING_DEFAULT_MODE])
                        else if ( equali(szKey, "CRATE_REFILL") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_REFILL], charsmax(eCrate[CRATE_REFILL]), g_eSettings[SETTING_DEFAULT_REFILL])
                        else if ( equali(szKey, "CRATE_COOLDOWN") )
                        {
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_COOLDOWN], charsmax(eCrate[CRATE_COOLDOWN]), g_eSettings[SETTING_DEFAULT_COOLDOWN])
                            eCrate[CRATE_COOLDOWN] = floatclamp(eCrate[CRATE_COOLDOWN], 0.5, 40.0)
                            eCrate[CRATE_FRAMERATE] = (2.15 + (eCrate[CRATE_COOLDOWN] - 0.5) / (40.0 - 0.5) * (3.25 - 2.15)) / eCrate[CRATE_COOLDOWN]
                        }
                        else if ( equali(szKey, "CRATE_CAPACITY") )
                        {
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_CAPACITY], charsmax(eCrate[CRATE_CAPACITY]), g_eSettings[SETTING_DEFAULT_CAPACITY])
                            eCrate[CRATE_CAPACITY_MAX] = eCrate[CRATE_CAPACITY]
                        }
                        else if ( equali(szKey, "CRATE_CRATE_MODE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_CRATE_MODE], charsmax(eCrate[CRATE_CRATE_MODE]), g_eSettings[SETTING_DEFAULT_CRATE_MODE])
                        else if ( equali(szKey, "CRATE_SPAWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_SPAWN], charsmax(eCrate[CRATE_SPAWN]), g_eSettings[SETTING_DEFAULT_SPAWN])
                        else if ( equali(szKey, "CRATE_CRATE_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_CRATE_CHANCE], charsmax(eCrate[CRATE_CRATE_CHANCE]), g_eSettings[SETTING_DEFAULT_CRATE_CHANCE])
                        else if ( equali(szKey, "CRATE_ACTIVE_DELAY") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_ACTIVE_DELAY], charsmax(eCrate[CRATE_ACTIVE_DELAY]), g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY])
                        else if ( equali(szKey, "CRATE_ACTIVE_DURATION") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_ACTIVE_DURATION], charsmax(eCrate[CRATE_ACTIVE_DURATION]), g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION])
                        else if ( equali(szKey, "CRATE_ACTIVE_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_ACTIVE_COOLDOWN], charsmax(eCrate[CRATE_ACTIVE_COOLDOWN]), g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN])
                        else if ( equali(szKey, "CRATE_HEALTH") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_HEALTH], charsmax(eCrate[CRATE_HEALTH]), g_eSettings[SETTING_DEFAULT_HEALTH])
                        else if ( equali(szKey, "CRATE_ARMOR") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_ARMOR], charsmax(eCrate[CRATE_ARMOR]), g_eSettings[SETTING_DEFAULT_ARMOR])
                        else if ( equali(szKey, "CRATE_FACTOR") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_FACTOR], charsmax(eCrate[CRATE_FACTOR]), g_eSettings[SETTING_DEFAULT_FACTOR])
                        else if ( equali(szKey, "CRATE_FACTOR_MAX") )
                        {
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_FACTOR_MAX], charsmax(eCrate[CRATE_FACTOR_MAX]), g_eSettings[SETTING_DEFAULT_FACTOR_MAX])
                            if ( eCrate[CRATE_FACTOR_MAX] < eCrate[CRATE_FACTOR] )
                                eCrate[CRATE_FACTOR_MAX] = eCrate[CRATE_FACTOR]
                        }
                        else if ( equali(szKey, "CRATE_EXPLODE_DAMAGE") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_EXPLODE_DAMAGE], charsmax(eCrate[CRATE_EXPLODE_DAMAGE]), g_eSettings[SETTING_DEFAULT_EXPLODE_DAMAGE])
                        else if ( equali(szKey, "CRATE_EXPLODE_RADIUS") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_EXPLODE_RADIUS], charsmax(eCrate[CRATE_EXPLODE_RADIUS]), g_eSettings[SETTING_DEFAULT_EXPLODE_RADIUS])
                        else if ( equali(szKey, "CRATE_WEAPON_MODE") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_WEAPON_MODE], charsmax(eCrate[CRATE_WEAPON_MODE]), g_eSettings[SETTING_DEFAULT_WEAPON_MODE])
                        else if ( equali(szKey, "CRATE_WEAPON_LIST") )
                            parseSetting(DTYPE_VECTOR_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), eCrate[CRATE_WEAPON_LIST], charsmax(eCrate[CRATE_WEAPON_LIST]), g_eSettings[SETTING_DEFAULT_WEAPON_LIST])
                    }
                }
            }
        }
    }

    if ( g_iCrateConfig )
        ArrayPushArray(g_aCrateConfig, eCrate)
    else
        set_fail_state("No crates were found in the configuration file.")

    g_bFileWasRead = true
    fclose(iFile)
}

public client_authorized(id)
{
    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public client_disconnected(id)
{
    new iItem
    if ( g_ePlayerData[id][PDATA_CRATE_GHOST]
    && (iItem = pev(g_ePlayerData[id][PDATA_CRATE_GHOST], CRATE_ARRAY_ITEM)) != -1 )
    {
        crateKill(g_ePlayerData[id][PDATA_CRATE_GHOST])
        crateRemove(iItem)
    }

    g_ePlayerData[id][PDATA_CRATE_GHOST]  = 0
    g_ePlayerData[id][PDATA_CRATE_USE]    = 0
    g_ePlayerData[id][PDATA_CRATE_ACTION] = false
    g_ePlayerData[id][PDATA_CRATE_MENU]   = 0
}

public UpdateData(id)
{
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public crateInit()
{
    if ( g_eSettings[SETTING_CRATE_LOAD] )
        loadData()
}

public crateMenu(id, iType)
{
    new szData[64], iMenu
    formatex(szData, charsmax(szData), "%L", id, "CRATE_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   { menuRoot(id, iMenu); }
        case MENU_CREATE: { menuCreate(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CRATE_ROOT_CREATE"); }
        case MENU_STATUS: { menuStatus(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CRATE_ROOT_STATUS"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CRATE_ROOT_REMOVE"); }
        case MENU_ROTATE: { menuRotate(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "CRATE_ROOT_ROTATE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szData, charsmax(szData), "%s^n%L", szData, id, "CRATE_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szData)
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

stock menuNav(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_BACK")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)
}

public menuRoot(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_CREATE")
    menu_additem(iMenu, szItem )

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_STATUS")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_NOCLIP", id, get_user_noclip(id) ? "CRATE_ON" : "CRATE_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_GODMODE", id, get_user_godmode(id) ? "CRATE_ON" : "CRATE_OFF")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iCrate >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_LIMIT", MAX_ENT)
                crateSound(id, SOUND_MENU_REMOVE)
            }
            else
            {
                crateSound(id, SOUND_MENU_NAV)
                crateMenu(id, MENU_CREATE)
            }
        }
        case ROOT_STATUS:
        {
            if ( !g_iCrate )
            {
                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_NO_CRATE")
                crateSound(id, SOUND_MENU_REMOVE)
            }
            else
            {
                crateSound(id, SOUND_MENU_NAV)
                crateMenu(id, MENU_STATUS)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iCrate )
            {
                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_NO_CRATE")
                crateSound(id, SOUND_MENU_REMOVE)
            }
            else
            {
                crateSound(id, SOUND_MENU_REMOVE)
                crateMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
        case ROOT_NOCLIP:
        {
            crateNoClip(id)
        }
        case ROOT_GODMODE:
        {
            crateGodMode(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(id, iMenu)
{
    new eCrate[CRATE],
        szItem[64]

    for ( new i = 0; i < g_iCrateConfig; i ++ )
    {
        ArrayGetArray(g_aCrateConfig, i, eCrate)

        copy(szItem, charsmax(szItem), eCrate[CRATE_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( item == MENU_EXIT
    || !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    crateCreate(id, item)
    crateSound(id, SOUND_MENU_NAV)
    crateMenu(id, MENU_ROTATE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuStatus(id, iMenu)
{
    new szItem[64], eCrate[CRATE]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_STATUS_CURRENT",
    g_szStatusColor[eCrate[CRATE_STATUS]], eCrate[CRATE_NAME], id, g_szStatus[eCrate[CRATE_STATUS]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_STATUS_ALL_ENABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_STATUS_ALL_DISABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_STATUS_ALL_DEFAULT")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CRATE_ACTION] = true
    eCrate[CRATE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
}

public menuHandlerStatus(id, menu, item)
{
    new eCrate[CRATE]
    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
    eCrate[CRATE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

    switch( item )
    {
        case STATUS_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] >= g_iCrate - 1 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] ++

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_STATUS)
        }
        case STATUS_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = g_iCrate - 1
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] --

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_STATUS)
        }
        case STATUS_CURRENT:
        {
            if ( ++ eCrate[CRATE_STATUS] > STATUS_FORCE_DISABLE )
                eCrate[CRATE_STATUS] = STATUS_DEFAULT

            if ( eCrate[CRATE_STATUS] == STATUS_FORCE_ENABLE
            || eCrate[CRATE_STATUS] == STATUS_DEFAULT )
                eCrate[CRATE_FLAGS] |= FLAG_ACTIVE
            else
            {
                eCrate[CRATE_FLAGS] &= ~FLAG_ACTIVE
                eCrate[CRATE_NEXT_USE] = 0.0
                crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)
            }

            client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_STATUS_CURRENT",
            eCrate[CRATE_NAME], id, g_szStatusChat[eCrate[CRATE_STATUS]])
            ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_ENABLE:
        {
            for ( new i = 0; i < g_iCrate; i ++ )
            {
                ArrayGetArray(g_aCrate, i, eCrate)
                eCrate[CRATE_FLAGS] |= FLAG_ACTIVE
                eCrate[CRATE_STATUS] = STATUS_FORCE_ENABLE
                ArraySetArray(g_aCrate, i, eCrate)
            }

            client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_STATUS_ALL_ENABLED")
            crateSound(id, SOUND_MENU_ALERT)
            crateMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DISABLE:
        {
            for ( new i = 0; i < g_iCrate; i ++ )
            {
                ArrayGetArray(g_aCrate, i, eCrate)
                eCrate[CRATE_FLAGS] &= ~FLAG_ACTIVE
                eCrate[CRATE_STATUS] = STATUS_FORCE_DISABLE
                eCrate[CRATE_NEXT_USE] = 0.0
                crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)
                ArraySetArray(g_aCrate, i, eCrate)
            }

            client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_STATUS_ALL_DISABLED")
            crateSound(id, SOUND_MENU_ALERT)
            crateMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DEFAULT:
        {
            for ( new i = 0; i < g_iCrate; i ++ )
            {
                ArrayGetArray(g_aCrate, i, eCrate)
                eCrate[CRATE_FLAGS] |= FLAG_ACTIVE
                eCrate[CRATE_STATUS] = STATUS_DEFAULT
                ArraySetArray(g_aCrate, i, eCrate)
            }

            client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_STATUS_ALL_DEFAULT")
            crateSound(id, SOUND_MENU_ALERT)
            crateMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_ROOT)

            g_ePlayerData[id][PDATA_CRATE_ACTION] = false
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0
        }
        default:
        {
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eCrate[CRATE]

    menuNav(id, iMenu)
    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_REMOVE_CURRENT", eCrate[CRATE_NAME])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CRATE_ACTION] = true
    eCrate[CRATE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
}

public menuHandlerRemove(id, menu, item)
{
    new eCrate[CRATE]

    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
    eCrate[CRATE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] >= g_iCrate - 1 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] ++

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = g_iCrate - 1
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] --

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            crateKill(eCrate[CRATE_ID])
            crateRemove(g_ePlayerData[id][PDATA_CRATE_MENU])

            client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_REMOVE_CURRENT", eCrate[CRATE_NAME])
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0

            crateSound(id, g_iCrate > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            crateMenu(id, g_iCrate > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iCrate )
            {
                ArrayGetArray(g_aCrate, 0, eCrate)

                crateKill(eCrate[CRATE_ID])
                crateRemove(0)
            }

            client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0

            crateSound(id, SOUND_MENU_ALERT)
            crateMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_ROOT)

            g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false
        }
        default:
        {
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRotate(id, iMenu)
{
    new szItem[64], eCrate[CRATE]
    if ( crateGet(eCrate, g_ePlayerData[id][PDATA_CRATE_GHOST]) == -1 )
    {
        menu_destroy(iMenu)
        return
    }

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_RIGHT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_LEFT")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_GROUND",
    id, eCrate[CRATE_FLAGS] & FLAG_GROUND ? "CRATE_ON" : "CRATE_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRotate(id, menu, item)
{
    new eCrate[CRATE], iItem
    if ( (iItem = crateGet(eCrate, g_ePlayerData[id][PDATA_CRATE_GHOST])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new Float:fCurrentTime
    fCurrentTime = get_gametime()

    switch( item )
    {
        case ROTATE_RIGHT:
        {
            pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            eCrate[CRATE_ANGLES][1] -= 22.5
            if ( eCrate[CRATE_ANGLES][1] < -180.0 ) eCrate[CRATE_ANGLES][1] += 360.0

            set_pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            ArraySetArray(g_aCrate, iItem, eCrate)

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_ROTATE)
        }
        case ROTATE_LEFT:
        {
            pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            eCrate[CRATE_ANGLES][1] += 22.5
            if ( eCrate[CRATE_ANGLES][1] > 180.0 ) eCrate[CRATE_ANGLES][1] -= 360.0

            set_pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            ArraySetArray(g_aCrate, iItem, eCrate)

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_ROTATE)
        }
        case ROTATE_GROUND:
        {
            eCrate[CRATE_FLAGS] ^= FLAG_GROUND
            ArraySetArray(g_aCrate, iItem, eCrate)

            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_ROTATE)
        }
        case ROTATE_PLACE:
        {
            crateTrace(eCrate, id)
            g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false

            eCrate[CRATE_NEXT_USE] = fCurrentTime + 0.25
            eCrate[CRATE_FLAGS] |= (FLAG_SHOW | FLAG_ACTIVE)
            eCrate[CRATE_FLAGS] &= ~FLAG_GHOST
            crateSetAnim(eCrate)
            crateSetSolid(eCrate)
            ArraySetArray(g_aCrate, iItem, eCrate)

            client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_CREATE_NEW", eCrate[CRATE_NAME])
            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            crateSound(id, SOUND_MENU_NAV)
            crateMenu(id, MENU_CREATE)

            crateKill(eCrate[CRATE_ID])
            crateRemove(iItem)
            g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false
        }
        default:
        {
            crateKill(eCrate[CRATE_ID])
            crateRemove(iItem)
            g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public crateTask()
{
    new eCrate[CRATE], bool:bModified, Float:fCurrentTime
    fCurrentTime = get_gametime()

    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( !is_user_alive(id) )
            continue

        if ( !g_ePlayerData[id][PDATA_CRATE_GHOST] )
        {
            if ( g_ePlayerData[id][PDATA_CRATE_ACTION] )
                crateCheck(id)
        }
        else if ( crateGet(eCrate, g_ePlayerData[id][PDATA_CRATE_GHOST]) != -1 )
        {
            crateTrace(eCrate, id)
        }
    }

    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        bModified = false

        if ( eCrate[CRATE_FLAGS] & FLAG_SHOW )
        {
            if ( eCrate[CRATE_FLAGS] & FLAG_ACTIVE )
            {
                if ( eCrate[CRATE_NEXT_USE]
                && fCurrentTime >= eCrate[CRATE_NEXT_USE] )
                {
                    eCrate[CRATE_NEXT_USE] = 0.0
                    crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)

                    bModified = true
                }

                if ( eCrate[CRATE_NEXT_DISABLE] > 0.0
                && fCurrentTime >= eCrate[CRATE_NEXT_DISABLE] )
                {
                    eCrate[CRATE_FLAGS] &= ~FLAG_ACTIVE
                    eCrate[CRATE_NEXT_DISABLE] = 0.0
                    eCrate[CRATE_NEXT_ENABLE] = fCurrentTime + random_float(eCrate[CRATE_ACTIVE_COOLDOWN][0], eCrate[CRATE_ACTIVE_COOLDOWN][1])
                    eCrate[CRATE_NEXT_USE] = 0.0
                    crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)

                    bModified = true
                }
            }
            else
            {
                if ( eCrate[CRATE_NEXT_REFILL]
                && fCurrentTime >= eCrate[CRATE_NEXT_REFILL] )
                {
                    eCrate[CRATE_CAPACITY] = eCrate[CRATE_CAPACITY_MAX]
                    eCrate[CRATE_NEXT_REFILL] = 0.0
                    eCrate[CRATE_NEXT_USE] = fCurrentTime + 0.1

                    bModified = true
                }

                if ( eCrate[CRATE_NEXT_ENABLE] > 0.0
                && fCurrentTime >= eCrate[CRATE_NEXT_ENABLE] )
                {
                    eCrate[CRATE_FLAGS] |= FLAG_ACTIVE
                    eCrate[CRATE_NEXT_ENABLE] = 0.0

                    if ( eCrate[CRATE_FLAGS] & FLAG_ACTIVE_DURATION )
                        eCrate[CRATE_NEXT_DISABLE] = fCurrentTime + random_float(eCrate[CRATE_ACTIVE_DURATION][0], eCrate[CRATE_ACTIVE_DURATION][1])

                    bModified = true
                }
            }
        }
        else
        {
            if ( eCrate[CRATE_FLAGS] & FLAG_DEAD
            && eCrate[CRATE_SHOW] == SHOW_DEFAULT
            && eCrate[CRATE_CRATE_MODE] == CRATE_DELAY
            && eCrate[CRATE_NEXT_SPAWN]
            && fCurrentTime >= eCrate[CRATE_NEXT_SPAWN] )
            {
                if ( eCrate[CRATE_CRATE_CHANCE] >= random_float(0.0, 1.0) )
                {
                    eCrate[CRATE_FLAGS] |= FLAG_SHOW
                    eCrate[CRATE_NEXT_SPAWN] = 0.0

                    crateState(eCrate, true, true)
                    crateSound(eCrate[CRATE_ID], SOUND_BUTTON4, .bPlayer = false)
                    bModified = true
                }
                else
                {
                    eCrate[CRATE_NEXT_SPAWN] = fCurrentTime + random_float(eCrate[CRATE_SPAWN][0], eCrate[CRATE_SPAWN][1])
                }
            }
        }

        if ( bModified )
            ArraySetArray(g_aCrate, i, eCrate)
    }
}

stock crateCreate(id, iItem)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return

    new eCrate[CRATE]
    ArrayGetArray(g_aCrateConfig, iItem, eCrate)

    eCrate[CRATE_ID] = iEnt
    eCrate[CRATE_ITEM] = iItem
    if ( id )
    {
        g_ePlayerData[id][PDATA_CRATE_GHOST] = eCrate[CRATE_ID]
        g_ePlayerData[id][PDATA_CRATE_ACTION] = true
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
        eCrate[CRATE_FLAGS] |= FLAG_GHOST
    }

    set_pev(iEnt, CRATE_ARRAY_ITEM, g_iCrate)
    set_pev(iEnt, pev_impulse, CRATE_KEY)
    set_pev(iEnt, pev_classname, g_szCN[eCrate[CRATE_CLASS]])
    set_pev(iEnt, pev_angles, Float:{0.0, 180.0, 0.0})
    engfunc(EngFunc_SetModel, iEnt, eCrate[CRATE_MODEL])

    ArrayPushArray(g_aCrate, eCrate)
    g_iCrate ++

    dllfunc(DLLFunc_Spawn, iEnt)
}

stock crateRemove(iItem)
{
    new eCrate[CRATE]
    ArrayDeleteItem(g_aCrate, iItem)
    g_iCrate --

    for ( new i = iItem; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        set_pev(eCrate[CRATE_ID], CRATE_ARRAY_ITEM, i)
    }
}

public saveData(id)
{
    new eCrate[CRATE],
        szFile[128], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_SupplyCrate.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "item = %d^n", eCrate[CRATE_ITEM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        eCrate[CRATE_ORIGIN][0], eCrate[CRATE_ORIGIN][1], eCrate[CRATE_ORIGIN][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n",
        eCrate[CRATE_ANGLES][0], eCrate[CRATE_ANGLES][1], eCrate[CRATE_ANGLES][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "status = %d^n", eCrate[CRATE_SHOW])
        fputs(iFile, szData)

        eCrate[CRATE_FLAGS] &= ~(FLAG_GHOST | FLAG_SELECT)
        formatex(szData, charsmax(szData), "flags = %d^n", eCrate[CRATE_FLAGS])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_SAVE", szFile)
    fclose(iFile)

    crateSound(id, SOUND_MENU_NAV)
    crateMenu(id, MENU_ROOT)
    return PLUGIN_HANDLED
}

stock loadData()
{
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], iItem,
        iStatus, iFlags, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_SupplyCrate.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
        return PLUGIN_HANDLED

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
            {
                loadDataCrate(fOrigin, fAngles, iStatus, iFlags, iItem, iCount)
            }

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            if ( equal(szKey, "item") )
            {
                iItem = str_to_num(szValue)
            }
            else if ( equal(szKey, "origin") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[1] = str_to_float(szKey)
                fOrigin[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "angles") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[1] = str_to_float(szKey)
                fAngles[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "status") )
            {
                iStatus = str_to_num(szValue)
            }
            else if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
        }
    }

    if ( iCount != -1 )
        loadDataCrate(fOrigin, fAngles, iStatus, iFlags, iItem, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataCrate(Float:fOrigin[3], Float:fAngles[3], iStatus, iFlags, iItem, iCount)
{
    new eCrate[CRATE], Float:fCurrentTime

    fCurrentTime = get_gametime()
    crateCreate(0, iItem)
    ArrayGetArray(g_aCrate, iCount, eCrate)

    xs_vec_copy(fOrigin, eCrate[CRATE_ORIGIN])
    xs_vec_copy(fAngles, eCrate[CRATE_ANGLES])
    set_pev(eCrate[CRATE_ID], pev_origin, fOrigin)
    set_pev(eCrate[CRATE_ID], pev_angles, fAngles)

    eCrate[CRATE_NEXT_USE]      = fCurrentTime + 0.25
    eCrate[CRATE_STATUS]        = iStatus
    eCrate[CRATE_FLAGS]         = iFlags
    eCrate[CRATE_FRAMERATE]     = (2.15 + (eCrate[CRATE_COOLDOWN] - 0.5) / (40.0 - 0.5) * (3.25 - 2.15)) / eCrate[CRATE_COOLDOWN]

    if ( eCrate[CRATE_SHOW] == SHOW_DEFAULT
    && eCrate[CRATE_CRATE_MODE] == CRATE_DELAY
    && eCrate[CRATE_FLAGS] & FLAG_DEAD )
        eCrate[CRATE_NEXT_SPAWN] = fCurrentTime + random_float(eCrate[CRATE_SPAWN][0], eCrate[CRATE_SPAWN][1])

    crateSetBox(eCrate)
    crateSetAnim(eCrate, false)
    if ( eCrate[CRATE_FLAGS] & FLAG_SHOW )
        crateSetSolid(eCrate)

    ArraySetArray(g_aCrate, iCount, eCrate)
}

public crateNoClip(id)
{
    set_user_noclip(id, !get_user_noclip(id))

    crateSound(id, SOUND_MENU_NAV)
    crateMenu(id, MENU_ROOT)
}

public crateGodMode(id)
{
    set_user_godmode(id, !get_user_godmode(id))

    crateSound(id, SOUND_MENU_NAV)
    crateMenu(id, MENU_ROOT)
}

public fwdUpdateClientData(id, iSendWeapons, iHandle)
{
    if ( g_ePlayerData[id][PDATA_CRATE_GHOST] )
    {
        set_cd(iHandle, CD_WeaponAnim, 0)
        set_cd(iHandle, CD_flNextAttack, get_gametime() + 0.1)
    }

    return FMRES_IGNORED
}

public fwdAddToFullPack(es, e, iEnt, iHost, iHostFlags, iPlayer, pSet)
{
    if ( !pev_valid(iEnt)
    || !isCrate(iEnt)
    || !get_orig_retval() )
        return FMRES_IGNORED

    new eCrate[CRATE]
    if ( crateGet(eCrate, iEnt) == -1 )
        return FMRES_IGNORED

    new bool:bHidden
    bHidden = !(eCrate[CRATE_FLAGS] & FLAG_SHOW)

    if ( !g_ePlayerData[iHost][PDATA_CRATE_ACTION] )
    {
        if ( bHidden )
            set_es(es, ES_Effects, EF_NODRAW)
    }
    else if ( eCrate[CRATE_FLAGS] & FLAG_SELECT )
    {
        if ( eCrate[CRATE_FLAGS] & FLAG_ACTIVE )    set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_ACTIVE])
        else                                        set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_INACTIVE])

        set_es(es, ES_RenderAmt, 32)
        set_es(es, ES_RenderFx, kRenderFxGlowShell)

        if ( bHidden )
            set_es(es, ES_RenderMode, kRenderTransAlpha)
    }
    else if ( bHidden )
    {
        if ( eCrate[CRATE_FLAGS] & FLAG_GHOST )
            return FMRES_IGNORED

        set_es(es, ES_RenderMode, kRenderTransAlpha)
        set_es(es, ES_RenderAmt, g_eSettings[SETTING_GHOST_ALPHA])
    }

    return FMRES_IGNORED
}

public fwdSpawn(iEnt)
{
    if ( !isCrate(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)

    return HAM_IGNORED
}

public fwdTakeDamage(iEnt, iInflictor, iAttacker, Float:fDamage, iDamageBits)
{
    if ( !isCrate(iEnt) )
        return HAM_IGNORED

    new eCrate[CRATE], iItem
    if ( (iItem = crateGet(eCrate, iEnt)) == -1
    || !(eCrate[CRATE_FLAGS] & FLAG_SHOW) )
        return HAM_IGNORED

    new Float:fHealth, Float:fCurrentTime
    pev(iEnt, pev_health, fHealth)
    fCurrentTime = get_gametime()

    if ( !(eCrate[CRATE_FLAGS] & FLAG_BREAK)
    || eCrate[CRATE_SHOW] == SHOW_FORCE_SHOW )
    {
        SetHamParamFloat(4, 0.0)
    }
    else if ( fDamage >= fHealth )
    {
        eCrate[CRATE_FLAGS] &= ~FLAG_SHOW
        crateState(eCrate, false, true)

        crateGib(eCrate[CRATE_ID])
        if ( eCrate[CRATE_SHOW] == SHOW_DEFAULT
        && eCrate[CRATE_CRATE_MODE] == CRATE_DELAY )
            eCrate[CRATE_NEXT_SPAWN] = fCurrentTime + random_float(eCrate[CRATE_SPAWN][0], eCrate[CRATE_SPAWN][1])

        if ( eCrate[CRATE_FLAGS] & FLAG_EXPLODE )
            crateExplode(eCrate)

        ArraySetArray(g_aCrate, iItem, eCrate)
        SetHamParamFloat(4, 0.0)
    }

    return HAM_IGNORED
}

public fwdTraceAttack(iEnt, iAttacker, Float:fDamage, Float:fDirection[3], iTr, iDamageBits)
{
    if ( !isCrate(iEnt) )
        return HAM_IGNORED

    new eCrate[CRATE]
    if ( crateGet(eCrate, iEnt) == -1 )
        return HAM_IGNORED

    new Float:fEnd[3]
    get_tr2(iTr, TR_vecEndPos, fEnd)

    crateParticles(fEnd)
    crateSparks(fEnd)
    crateSound(iEnt, SOUND_METAL, CHAN_VOICE, false)

    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    static eCrate[CRATE], iItem,
        iEnt, iButton, Float:fCurrentTime

    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( g_ePlayerData[id][PDATA_CRATE_GHOST] )
    {
        if ( fCurrentTime > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }
    else
    {
        if ( (iEnt = crateUse(id))
        && ((iItem = crateGet(eCrate, iEnt)) != -1)
        && eCrate[CRATE_FLAGS] & FLAG_SHOW
        && ( !g_ePlayerData[id][PDATA_CRATE_USE] || g_ePlayerData[id][PDATA_CRATE_USE] == eCrate[CRATE_ID] ) )
        {
            if ( fCurrentTime >= eCrate[CRATE_NEXT_USE] )
                crateSupply(id, eCrate, iItem, fCurrentTime)

            iButton &= ~IN_USE
            set_pev(id, pev_button, iButton)
        }
        else if ( g_ePlayerData[id][PDATA_CRATE_USE]
        && (crateGet(eCrate, g_ePlayerData[id][PDATA_CRATE_USE]) != -1) )
        {
            g_ePlayerData[id][PDATA_CRATE_USE] = 0
        }
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    g_ePlayerData[id][PDATA_CRATE_ACTION] = false
    g_ePlayerData[id][PDATA_CRATE_MENU]   = 0
    g_ePlayerData[id][PDATA_CRATE_USE]    = 0

    if ( g_ePlayerData[id][PDATA_CRATE_GHOST] )
    {
        new eCrate[CRATE], iItem
        if ( (iItem = crateGet(eCrate, g_ePlayerData[id][PDATA_CRATE_GHOST])) != -1 )
        {
            crateKill(g_ePlayerData[id][PDATA_CRATE_GHOST])
            crateRemove(iItem)
        }

        g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
    }

    return HAM_IGNORED
}

stock crateTrace(eCrate[CRATE], id)
{
    new Float:fVec1[3]

    pev(id, pev_origin, eCrate[CRATE_ORIGIN])
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(eCrate[CRATE_ORIGIN], fVec1, eCrate[CRATE_ORIGIN])

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec1)
    xs_vec_add(fVec1, eCrate[CRATE_ORIGIN], fVec1)

    engfunc(EngFunc_TraceLine, eCrate[CRATE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, eCrate[CRATE_ORIGIN])

    crateSetBox(eCrate)
    crateSetOffset(eCrate)
    set_pev(eCrate[CRATE_ID], pev_origin, eCrate[CRATE_ORIGIN])
}

stock crateCheck(id)
{
    new eCrate[CRATE], Float:fVec1[3], Float:fVec2[3], Float:fVec3[3], Float:fMins[3], Float:fMaxs[3], Float:fNearest[3]
    new iBest, Float:fBestDist, Float:fDot, Float:fDist

    pev(id, pev_origin, fVec1)
    pev(id, pev_view_ofs, fVec2)
    xs_vec_add(fVec1, fVec2, fVec1)

    pev(id, pev_v_angle, fVec2)
    engfunc(EngFunc_MakeVectors, fVec2)
    global_get(glb_v_forward, fVec2)

    iBest = -1
    fBestDist = g_eSettings[SETTING_CRATE_CHECK]
    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        xs_vec_sub(eCrate[CRATE_ORIGIN], fVec1, fVec3)
        fDot = xs_vec_dot(fVec2, fVec3)

        if ( fDot < 0.0 )
            continue

        pev(eCrate[CRATE_ID], pev_absmin, fMins)
        pev(eCrate[CRATE_ID], pev_absmax, fMaxs)
        xs_vec_mul_scalar(fVec2, fDot, fVec3)
        xs_vec_add(fVec3, fVec1, fVec3)

        fNearest[0] = floatclamp(fVec3[0], fMins[0], fMaxs[0])
        fNearest[1] = floatclamp(fVec3[1], fMins[1], fMaxs[1])
        fNearest[2] = floatclamp(fVec3[2], fMins[2], fMaxs[2])
        fDist = get_distance_f(fVec3, fNearest)
        if ( fDist < fBestDist )
        {
            fBestDist = fDist
            iBest = i
        }
    }

    if ( iBest != -1
    && g_ePlayerData[id][PDATA_CRATE_MENU] != iBest )
    {
        ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
        eCrate[CRATE_FLAGS] &= ~FLAG_SELECT
        ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

        ArrayGetArray(g_aCrate, iBest, eCrate)
        eCrate[CRATE_FLAGS] |= FLAG_SELECT
        ArraySetArray(g_aCrate, iBest, eCrate)
        g_ePlayerData[id][PDATA_CRATE_MENU] = iBest
    }
}

stock crateUse(id)
{
    if ( !(pev(id, pev_button) & IN_USE) )
        return 0

    new Float:fOrigin[3], Float:fVec1[3],
        iEnt = -1

    pev(id, pev_origin, fOrigin)
    pev(id, pev_view_ofs, fVec1)
    xs_vec_add(fOrigin, fVec1, fOrigin)

    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_eSettings[SETTING_CRATE_RANGE], fVec1)
    xs_vec_add(fVec1, fOrigin, fVec1)

    engfunc(EngFunc_TraceLine, fOrigin, fVec1, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, fOrigin)

    while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, 5.0)) )
    {
        if ( !pev_valid(iEnt)
        || !isCrate(iEnt) )
            continue

        return iEnt
    }

    return 0
}

stock bool:crateAllow(id, eCrate[CRATE])
{
    new iWeaponID
    iWeaponID = cs_get_user_weapon(id)

    if ( eCrate[CRATE_CLASS] == CLASS_MARKET && (iWeaponID == CSW_KNIFE || iWeaponID == CSW_C4) )   return false
    else if ( eCrate[CRATE_WEAPON_MODE] == WEAPON_ONLY )                                            return eCrate[CRATE_WEAPON_LIST][iWeaponID]
    else if ( eCrate[CRATE_WEAPON_MODE] == WEAPON_EXCEPT )                                          return !eCrate[CRATE_WEAPON_LIST][iWeaponID]

    return true
}

stock crateSupply(id, eCrate[CRATE], iItem, Float:fCurrentTime)
{
    if ( eCrate[CRATE_FLAGS] & FLAG_ACTIVE
    && CsTeams:eCrate[CRATE_TEAM] & cs_get_user_team(id)
    && crateAllow(id, eCrate) )
    {
        if ( !g_ePlayerData[id][PDATA_CRATE_USE] )
            g_ePlayerData[id][PDATA_CRATE_USE] = eCrate[CRATE_ID]

        switch( eCrate[CRATE_CLASS] )
        {
            case CLASS_AMMO:     supplyAmmo(id, eCrate, fCurrentTime)
            case CLASS_GRENADES: supplyGrenades(id, eCrate, fCurrentTime)
            case CLASS_MARKET:   supplyMarket(id, eCrate, fCurrentTime)
        }

        if ( !eCrate[CRATE_CAPACITY] )
        {
            eCrate[CRATE_FLAGS] &= ~FLAG_ACTIVE
            eCrate[CRATE_NEXT_ENABLE] = 0.0
            eCrate[CRATE_NEXT_EMPTY] = fCurrentTime + 1.0
            eCrate[CRATE_NEXT_USE] = 0.0
            crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)
            g_ePlayerData[id][PDATA_CRATE_USE] = 0

            if ( eCrate[CRATE_FLAGS] & FLAG_REFILL )
                eCrate[CRATE_NEXT_REFILL] = fCurrentTime + random_float(eCrate[CRATE_REFILL][0], eCrate[CRATE_REFILL][1])
        }

        ArraySetArray(g_aCrate, iItem, eCrate)
    }
    else if ( fCurrentTime >= eCrate[CRATE_NEXT_EMPTY] )
    {
        crateSound(eCrate[CRATE_ID], SOUND_LOCKED, .bPlayer = false)
        eCrate[CRATE_NEXT_EMPTY] = fCurrentTime + 1.0

        ArraySetArray(g_aCrate, iItem, eCrate)
    }
}

stock supplyAmmo(id, eCrate[CRATE], Float:fCurrentTime)
{
    new iWeapon, iClip, iAmmo, iBoost
    iWeapon = cs_get_user_weapon(id, iClip, iAmmo)

    if ( (1 << iWeapon) & CSW_ALL_GUNS
    && iAmmo < floatround(eCrate[CRATE_FACTOR_MAX] * g_iWeaponMaxBP[iWeapon]) )
    {
        if ( eCrate[CRATE_MODE] & CRATE_FLAG_AMMO )
        {
            iBoost = floatround(g_iWeaponMaxBP[iWeapon] * eCrate[CRATE_FACTOR])
            iBoost = min(iBoost, floatround(eCrate[CRATE_FACTOR_MAX] * g_iWeaponMaxBP[iWeapon]) - iAmmo)

            cs_set_user_bpammo(id, iWeapon, iAmmo + iBoost)
            ammoPickup(id, iBoost)
        }

        if ( eCrate[CRATE_MODE] & CRATE_FLAG_VEST )     cs_set_user_armor(id, eCrate[CRATE_ARMOR], CS_ARMOR_KEVLAR)
        if ( eCrate[CRATE_MODE] & CRATE_FLAG_VESTHELM ) cs_set_user_armor(id, eCrate[CRATE_ARMOR], CS_ARMOR_VESTHELM)

        eCrate[CRATE_CAPACITY] -= 1.0
        eCrate[CRATE_NEXT_USE] = fCurrentTime + eCrate[CRATE_COOLDOWN]
        crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

        if ( !iClip )
            client_cmd(id, "+attack; wait; -attack;")

        crateSound(eCrate[CRATE_ID], SOUND_CLIP, .bPlayer = false)
    }
    else if ( fCurrentTime >= eCrate[CRATE_NEXT_EMPTY] )
    {
        eCrate[CRATE_NEXT_EMPTY] = fCurrentTime + 1.0
        crateSound(eCrate[CRATE_ID], SOUND_LOCKED, .bPlayer = false)
    }
}

stock supplyGrenades(id, eCrate[CRATE], Float:fCurrentTime)
{
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_HE )       grenadeAdd(id, CSW_HEGRENADE, "weapon_hegrenade", eCrate[CRATE_FACTOR])
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_FB1 )      grenadeAdd(id, CSW_FLASHBANG, "weapon_flashbang", eCrate[CRATE_FACTOR])
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_FB2 )      grenadeAdd(id, CSW_FLASHBANG, "weapon_flashbang", eCrate[CRATE_FACTOR])
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_SMOKE )    grenadeAdd(id, CSW_SMOKEGRENADE, "weapon_smokegrenade", eCrate[CRATE_FACTOR])
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_VEST )     cs_set_user_armor(id, eCrate[CRATE_ARMOR], CS_ARMOR_KEVLAR)
    if ( eCrate[CRATE_MODE] & CRATE_FLAG_VESTHELM ) cs_set_user_armor(id, eCrate[CRATE_ARMOR], CS_ARMOR_VESTHELM)

    eCrate[CRATE_CAPACITY] -= 1.0
    eCrate[CRATE_NEXT_USE] = fCurrentTime + eCrate[CRATE_COOLDOWN]
    crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])
    crateSound(eCrate[CRATE_ID], SOUND_CLIP, .bPlayer = false)
}

stock supplyMarket(id, eCrate[CRATE], Float:fCurrentTime)
{
    new iWeapon
    iWeapon = cs_get_user_weapon(id)

    if ( iWeapon != CSW_KNIFE && iWeapon != CSW_C4 )
    {
        marketSell(id, iWeapon, eCrate)

        eCrate[CRATE_CAPACITY] -= 1.0
        eCrate[CRATE_NEXT_USE] = fCurrentTime + eCrate[CRATE_COOLDOWN]
        crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])
        crateSound(eCrate[CRATE_ID], SOUND_CHCHING, .bPlayer = false)
    }
    else if ( fCurrentTime >= eCrate[CRATE_NEXT_EMPTY] )
    {
        eCrate[CRATE_NEXT_EMPTY] = fCurrentTime + 1.0
        crateSound(eCrate[CRATE_ID], SOUND_LOCKED, .bPlayer = false)
    }
}

stock crateSetBox(eCrate[CRATE])
{
    new Float:fMins[3], Float:fMaxs[3],
        Float:fForward[3], Float:fRight[3], Float:fUp[3],
        Float:fCorners[8][3]

    eCrate[CRATE_ANGLES][0] = -eCrate[CRATE_ANGLES][0]
    engfunc(EngFunc_AngleVectors, eCrate[CRATE_ANGLES], fForward, fRight, fUp)
    xs_vec_copy(g_eSettings[SETTING_MINS], fMins)
    xs_vec_copy(g_eSettings[SETTING_MAXS], fMaxs)

    for ( new i = 0; i < 8; i ++ )
    {
        fCorners[i][0] = (i & 1) ? fMaxs[0] : fMins[0]
        fCorners[i][1] = (i & 2) ? fMaxs[1] : fMins[1]
        fCorners[i][2] = (i & 4) ? fMaxs[2] : fMins[2]

        boxRotate(fCorners[i], fForward, fRight, fUp)
    }

    xs_vec_copy(fCorners[0], fMins)
    xs_vec_copy(fCorners[0], fMaxs)
    for ( new i = 1; i < 8; i ++ )
    {
        fMins[0] = floatmin(fMins[0], fCorners[i][0])
        fMins[1] = floatmin(fMins[1], fCorners[i][1])
        fMins[2] = floatmin(fMins[2], fCorners[i][2])

        fMaxs[0] = floatmax(fMaxs[0], fCorners[i][0])
        fMaxs[1] = floatmax(fMaxs[1], fCorners[i][1])
        fMaxs[2] = floatmax(fMaxs[2], fCorners[i][2])
    }

    xs_vec_copy(fMins, eCrate[CRATE_MINS])
    xs_vec_copy(fMaxs, eCrate[CRATE_MAXS])
}

stock boxRotate(Float:fLocal[3], Float:fForward[3], Float:fRight[3], Float:fUp[3])
{
    new Float:fOut[3]
    fOut[0] = fLocal[0] * fForward[0] + fLocal[1] * fRight[0] + fLocal[2] * fUp[0]
    fOut[1] = fLocal[0] * fForward[1] + fLocal[1] * fRight[1] + fLocal[2] * fUp[1]
    fOut[2] = fLocal[0] * fForward[2] + fLocal[1] * fRight[2] + fLocal[2] * fUp[2]

    xs_vec_copy(fOut, fLocal)
}

stock crateSetOffset(eCrate[CRATE])
{
    new Float:fGaps[6], Float:fVec1[3],
        Float:fCurrentGap

    fGaps[0] = -eCrate[CRATE_MINS][0]
    fGaps[1] = eCrate[CRATE_MAXS][0]
    fGaps[2] = -eCrate[CRATE_MINS][1]
    fGaps[3] = eCrate[CRATE_MAXS][1]
    fGaps[4] = -eCrate[CRATE_MINS][2]
    fGaps[5] = eCrate[CRATE_MAXS][2]

    if ( eCrate[CRATE_FLAGS] & FLAG_GROUND )
    {
        xs_vec_sub(eCrate[CRATE_ORIGIN], Float:{0.0, 0.0, 9999.9}, fVec1)
        engfunc(EngFunc_TraceLine, eCrate[CRATE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eCrate[CRATE_ID], 0)
        get_tr2(0, TR_vecEndPos, eCrate[CRATE_ORIGIN])
    }

    for ( new i = 0; i < 6; i ++ )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fVec1)
        xs_vec_add(fVec1, eCrate[CRATE_ORIGIN], fVec1)
        engfunc(EngFunc_TraceLine, eCrate[CRATE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eCrate[CRATE_ID], 0)
        get_tr2(0, TR_vecEndPos, fVec1)
        fCurrentGap = xs_vec_distance(eCrate[CRATE_ORIGIN], fVec1)

        if ( fCurrentGap < fGaps[i] )
        {
            get_tr2(0, TR_vecPlaneNormal, fVec1)
            xs_vec_mul_scalar(fVec1, fGaps[i] - fCurrentGap, fVec1)
            xs_vec_add(eCrate[CRATE_ORIGIN], fVec1, eCrate[CRATE_ORIGIN])
        }
    }
}

stock crateSetAnim(eCrate[CRATE], bool:bPlaySound = true)
{
    if ( eCrate[CRATE_FLAGS] & FLAG_ACTIVE )
    {
        if ( eCrate[CRATE_FLAGS] & FLAG_ACTIVE_DELAY )
        {
            eCrate[CRATE_FLAGS] &= ~FLAG_ACTIVE
            eCrate[CRATE_NEXT_ENABLE] = get_gametime() + random_float(eCrate[CRATE_ACTIVE_DELAY][0], eCrate[CRATE_ACTIVE_DELAY][1])

            if ( bPlaySound )
                crateSound(eCrate[CRATE_ID], SOUND_LOCKED, .bPlayer = false)
        }
        else
        {
            if ( eCrate[CRATE_FLAGS] & FLAG_ACTIVE_DURATION )
                eCrate[CRATE_NEXT_DISABLE] = get_gametime() + random_float(eCrate[CRATE_ACTIVE_DURATION][0], eCrate[CRATE_ACTIVE_DURATION][1])

            if ( bPlaySound )
                crateSound(eCrate[CRATE_ID], SOUND_BUTTON4, .bPlayer = false)
        }
    }
    else
    {
        if ( bPlaySound )
            crateSound(eCrate[CRATE_ID], SOUND_LOCKED, .bPlayer = false)
    }
}

stock crateSetSolid(eCrate[CRATE])
{
    new Float:fMins[3],
        Float:fMaxs[3]

    set_pev(eCrate[CRATE_ID], pev_solid, SOLID_BBOX)
    set_pev(eCrate[CRATE_ID], pev_movetype, MOVETYPE_NONE)
    set_pev(eCrate[CRATE_ID], pev_takedamage, DAMAGE_AIM)
    set_pev(eCrate[CRATE_ID], pev_health, random_float(eCrate[CRATE_HEALTH][0], eCrate[CRATE_HEALTH][1]))

    xs_vec_copy(eCrate[CRATE_MINS], fMins)
    xs_vec_copy(eCrate[CRATE_MAXS], fMaxs)
    engfunc(EngFunc_SetSize, eCrate[CRATE_ID], fMins, fMaxs)
    set_rendering(eCrate[CRATE_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock crateSetSeq(iEnt, iSequence, Float:fFrameRate = 1.0)
{
    set_pev(iEnt, pev_sequence, iSequence)
    set_pev(iEnt, pev_frame, 0.0)
    set_pev(iEnt, pev_framerate, fFrameRate)
    set_pev(iEnt, pev_animtime, get_gametime())
}

public crateSparks(Float:fOrigin[])
{
    message_begin_f(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_SPARKS)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    message_end()
}

stock crateParticles(Float:fOrigin[3])
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fOrigin)
    write_byte(TE_GUNSHOTDECAL)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    write_short(0)
    write_byte(random_num(41, 45))
    message_end()
}

stock crateExplode(eCrate[CRATE])
{
    new Float:fDistance, Float:fRatio, Float:fDamage, Float:fRadius,
        Float:fVec1[3], Float:fVec2[3], iEnt = -1

    fRadius = random_float(eCrate[CRATE_EXPLODE_RADIUS][0], eCrate[CRATE_EXPLODE_RADIUS][1])
    xs_vec_copy(eCrate[CRATE_ORIGIN], fVec1)
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fVec1)
    write_byte(TE_EXPLOSION)
    write_coord_f(fVec1[0])
    write_coord_f(fVec1[1])
    write_coord_f(fVec1[2])
    write_short(g_eSettings[SETTING_SPRITE_ZEROGXPLODE])
    write_byte(floatround(fRadius / 15.0))
    write_byte(15)
    write_byte(TE_EXPLFLAG_NONE)
    message_end()

    xs_vec_sub(fVec1, Float:{0.0, 0.0, 9999.9}, fVec2)
    engfunc(EngFunc_TraceLine, fVec1, fVec2, IGNORE_MONSTERS, eCrate[CRATE_ID], 0)
    get_tr2(0, TR_vecEndPos, fVec2)
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_WORLDDECAL)
    write_coord_f(fVec2[0])
    write_coord_f(fVec2[1])
    write_coord_f(fVec2[2])
    write_byte(random_num(46, 48))
    message_end()

    while ( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, eCrate[CRATE_ORIGIN], fRadius)) )
    {
        if ( !pev_valid(iEnt)
        || pev(iEnt, pev_takedamage) == DAMAGE_NO
        || iEnt == eCrate[CRATE_ID] )
            continue

        pev(iEnt, pev_absmin, fVec1)
        pev(iEnt, pev_absmax, fVec2)
        xs_vec_add(fVec1, fVec2, fVec1)
        xs_vec_mul_scalar(fVec1, 0.5, fVec1)

        fDistance = xs_vec_distance(eCrate[CRATE_ORIGIN], fVec1)
        if ( fDistance > fRadius )
            continue

        fRatio = 1.0 - fDistance / fRadius
        fDamage = random_float(eCrate[CRATE_EXPLODE_DAMAGE][0], eCrate[CRATE_EXPLODE_DAMAGE][1]) * fRatio

        fakedamage(iEnt, "weapon_hegrenade", fDamage, DMG_GRENADE)
    }
}

stock crateGib(iEnt)
{
    new Float:fOrigin[3]
    pev(iEnt, pev_origin, fOrigin)

    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fOrigin)
    write_byte(TE_BREAKMODEL)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    write_coord_f(32.0)
    write_coord_f(32.0)
    write_coord_f(32.0)
    write_coord_f(0.0)
    write_coord_f(0.0)
    write_coord_f(random_float(g_eSettings[SETTING_BREAK_VELO_Z][0], g_eSettings[SETTING_BREAK_VELO_Z][1]))
    write_byte(random_num(g_eSettings[SETTING_BREAK_VELO_RANDOM][0], g_eSettings[SETTING_BREAK_VELO_RANDOM][1]))
    write_short(g_eSettings[SETTING_DEFAULT_GIB])
    write_byte(random_num(g_eSettings[SETTING_BREAK_COUNT][0], g_eSettings[SETTING_BREAK_COUNT][1]))
    write_byte(random_num(g_eSettings[SETTING_BREAK_LIFE][0], g_eSettings[SETTING_BREAK_LIFE][1]))
    write_byte(BREAK_FLAG_METAL)
    message_end()
}

stock crateState(eCrate[CRATE], bool:bShow, bool:bFlag)
{
    if ( bShow )
    {
        set_pev(eCrate[CRATE_ID], pev_solid, SOLID_BBOX)
        set_pev(eCrate[CRATE_ID], pev_takedamage, DAMAGE_AIM)

        if ( bFlag )
        {
            set_pev(eCrate[CRATE_ID], pev_health, random_float(eCrate[CRATE_HEALTH][0], eCrate[CRATE_HEALTH][1]))
            eCrate[CRATE_CAPACITY] = eCrate[CRATE_CAPACITY_MAX]

            eCrate[CRATE_FLAGS] &= ~FLAG_DEAD
            crateSetAnim(eCrate)
        }
    }
    else
    {
        set_pev(eCrate[CRATE_ID], pev_solid, SOLID_NOT)
        set_pev(eCrate[CRATE_ID], pev_takedamage, DAMAGE_NO)

        if ( bFlag )
        {
            eCrate[CRATE_FLAGS] |= FLAG_DEAD
            eCrate[CRATE_NEXT_USE] = 0.0
            crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)
        }
    }
}

stock crateReset(eCrate[CRATE])
{
    eCrate[CRATE_NEXT_USE]      = 0.0
    eCrate[CRATE_NEXT_EMPTY]    = 0.0
    eCrate[CRATE_NEXT_REFILL]   = 0.0
    eCrate[CRATE_NEXT_ENABLE]   = 0.0
    eCrate[CRATE_NEXT_DISABLE]  = 0.0
}

stock crateSound(iEnt, iSound, iChan = CHAN_ITEM, bool:bPlayer = true, iFlags = 0)
{
    new szSample[64]

    switch( iSound )
    {
        case SOUND_MENU_NAV:        copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_NAV])
        case SOUND_MENU_REMOVE:     copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_REMOVE])
        case SOUND_MENU_ALERT:      copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_ALERT])
        case SOUND_BUTTON4:         copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_BUTTON4])
        case SOUND_LOCKED:          copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_LOCKED])
        case SOUND_CLIP:            copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_CLIP])
        case SOUND_CHCHING:         copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_CHCHING])
        case SOUND_METAL:           ArrayGetString(g_eSettings[SETTING_SOUND_METAL], random(ArraySize(g_eSettings[SETTING_SOUND_METAL])),    szSample, charsmax(szSample))
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, iChan, szSample, VOL_NORM, ATTN_NORM, iFlags, PITCH_NORM)
}

stock ammoPickup(id, iAmount)
{
    new iActiveWeapon,
        iAmmoType

    iActiveWeapon = cs_get_user_weapon_entity(id)
    iAmmoType = get_pdata_int(iActiveWeapon, MEMBER_AMMO_TYPE, XO_CBASEPLAYERWEAPON)

    message_begin(MSG_ONE_UNRELIABLE, g_iAmmoPickup, .player = id)
    write_byte(iAmmoType)
    write_byte(iAmount)
    message_end()
}


stock bombPickup(id, iGrenade)
{
    message_begin(MSG_ONE_UNRELIABLE, g_iWeapPickup, .player = id)
    write_byte(iGrenade)
    message_end()
}

stock bool:hasGrenades(id)
{
    return (cs_get_user_bpammo(id, CSW_HEGRENADE) > 0
    || cs_get_user_bpammo(id, CSW_FLASHBANG) > 0
    || cs_get_user_bpammo(id, CSW_SMOKEGRENADE) > 0)
}

stock marketSell(id, iWeapon, eCrate[CRATE])
{
    new iMoney,
        iActiveWeapon,
        iBpAmmo,
        bool:bShouldKill = true

    iMoney = cs_get_user_money(id)
    iMoney += floatround(g_iWeaponMarket[iWeapon] * eCrate[CRATE_FACTOR])
    iActiveWeapon = cs_get_user_weapon_entity(id)

    switch( isGrenade(iActiveWeapon) )
    {
        case CSW_HEGRENADE:
        {
            iBpAmmo = cs_get_user_bpammo(id, CSW_HEGRENADE)
            cs_set_user_bpammo(id, CSW_HEGRENADE, iBpAmmo - 1)

            if ( iBpAmmo > 1 )
                bShouldKill = false
        }
        case CSW_FLASHBANG:
        {
            iBpAmmo = cs_get_user_bpammo(id, CSW_FLASHBANG)
            cs_set_user_bpammo(id, CSW_FLASHBANG, iBpAmmo - 1)

            if ( iBpAmmo > 1 )
                bShouldKill = false
        }
        case CSW_SMOKEGRENADE:
        {
            iBpAmmo = cs_get_user_bpammo(id, CSW_SMOKEGRENADE)
            cs_set_user_bpammo(id, CSW_SMOKEGRENADE, iBpAmmo - 1)

            if ( iBpAmmo > 1 )
                bShouldKill = false
        }
    }

    if ( bShouldKill )
    {
        ExecuteHam(Ham_Weapon_RetireWeapon, iActiveWeapon)
        ExecuteHam(Ham_RemovePlayerItem, id, iActiveWeapon)
        user_has_weapon(id, iWeapon, 0)
        ExecuteHam(Ham_Item_Kill, iActiveWeapon)
    }

    cs_set_user_money(id, iMoney, 1)
}

stock grenadeAdd(id, iGrenade, szGrenade[], Float:fFactor)
{
    new iAmmo
    iAmmo = cs_get_user_bpammo(id, iGrenade)

    if ( !iAmmo )
    {
        give_item(id, szGrenade)
        cs_set_user_bpammo(id, iGrenade, floatround(fFactor))
    }
    else
    {
        bombPickup(id, iGrenade)
        cs_set_user_bpammo(id, iGrenade, iAmmo + floatround(fFactor))
    }
}

stock isGrenade(iEnt)
{
    new szEnt[32]
    pev(iEnt, pev_classname, szEnt, charsmax(szEnt))

    if ( equal(szEnt[7], "hegrenade") )          return CSW_HEGRENADE
    else if ( equal(szEnt[7], "flashbang") )     return CSW_FLASHBANG
    else if ( equal(szEnt[7], "smokegrenade") )  return CSW_SMOKEGRENADE

    return 0
}

stock crateGet(eCrate[CRATE], iEnt)
{
    new iItem
    iItem = pev(iEnt, CRATE_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iCrate )
        return -1

    ArrayGetArray(g_aCrate, iItem, eCrate)
    return iItem
}

stock bool:isCrate(iEnt)
{
    return pev(iEnt, pev_impulse) == CRATE_KEY
}

stock crateKill(iEnt)
{
    if ( pev_valid(iEnt) )
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}



stock parseSetting(iType, szKey[], iKeyLen, szValue[], iValueLen, any:output[], iOutputLen, const any:fallback[] = {0.0, 0.0})
{
    switch ( iType )
    {
        case DTYPE_FLOAT_RANGE:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_float(szKey)
            output[1] = str_to_float(szValue)

            if ( output[0] < 0.0 ) output[0] = fallback[0]
            if ( output[1] < 0.0 ) output[1] = fallback[1]
        }
        case DTYPE_FLOAT:
        {
            output[0] = str_to_float(szValue)
            if ( output[0] < 0.0 ) output[0] = fallback[0]
        }
        case DTYPE_INT_RANGE:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_num(szKey)
            output[1] = str_to_num(szValue)

            if ( output[0] < 0 ) output[0] = fallback[0]
            if ( output[1] < 0 ) output[1] = fallback[1]
        }
        case DTYPE_INT:
        {
            output[0] = str_to_num(szValue)
            if ( output[0] < 0 ) output[0] = fallback[0]
        }
        case DTYPE_BOOL:
        {
            output[0] = bool:str_to_num(szValue)
        }
        case DTYPE_FLAGS:
        {
            output[0] = read_flags(szValue)
        }
        case DTYPE_VECTOR:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_num(szKey)

            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[1] = str_to_num(szKey)
            output[2] = str_to_num(szValue)
        }
        case DTYPE_VECTOR_FLOAT:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_float(szKey)

            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[1] = str_to_float(szKey)
            output[2] = str_to_float(szValue)
        }
        case DTYPE_VECTOR_LIST:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH]
            copy(szTmp, charsmax(szTmp), szValue)
            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ',')
            trim(szTok)
            while ( szTok[0] )
            {
                new iNum = str_to_num(szTok)
                if ( iNum >= 1 && iNum <= 30 )
                    output[iNum] = true

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ',')
                trim(szTok)
            }
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(output[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(output, iOutputLen, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(output, iOutputLen, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_SPRITE:
        {
            if ( !g_bFileWasRead )
                output[0] = precache_model(szValue)
        }
    }
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}
