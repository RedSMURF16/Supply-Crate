/*
*
*	Supply Crate by RedSMURF
*
*
*	Description:
*   This plugin adds a menu offering multiple crate types, each with unqiue functionality,
*   it only uses it's own crate models as custom crate animations are not supported.
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
*       crate_reload                "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*       v2.0: Major rework with performance improvements and new mechanics,
*             Improved crate placement logic for natural alignment with ground and walls,
*             Crates might refill after a certain duration,
*             Added activation delay after round start,
*             Crates can break or explode from damage,
*             CRATE_FACTOR is used with AMMO CRATES to scale the supplied ammo.
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

#if !defined MAX_AUTHID_LENGTH
    #define MAX_AUTHID_LENGTH 64
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

#define MAX_ENT                 32
#define MENU_BLINK              0.1
#define MEMBER_ACTIVE_WEAPON    373
#define MEMBER_AMMO_TYPE        49
#define MATERIAL_METAL          "2"

/**
 *  Crate animation sequences.
 */
#define CRATE_SEQ_IDLE          0
#define CRATE_SEQ_OPENCLOSE     1

/**
 *  Crate Bitflag sounds.
 */
#define CRATE_SOUND_PLACE       (1 << 0)
#define CRATE_SOUND_EMPTY       (1 << 1)
#define CRATE_SOUND_REMOVE      (1 << 2)
#define CRATE_SOUND_SUPPLY      (1 << 3)
#define CRATE_SOUND_SELL        (1 << 4)
#define CRATE_SOUND_REFILL      (1 << 5)

new const PLUGIN_VERSION[]          = "2.0"
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
    STATE_ACTIVE,
    STATE_INACTIVE,
    STATE_VALID,
    STATE_INVALID
}

enum
{
    FLAG_BREAK   = (1 << 0),
    FLAG_EXPLODE = (1 << 1),
    FLAG_SELECT  = (1 << 2)
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],

    Float:SETTING_MINS[3],
    Float:SETTING_MAXS[3],
    SETTING_SOUND_PLACE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_EMPTY[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_SUPPLY[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_SELL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_REFILL[MAX_RESOURCE_PATH_LENGTH],

    bool:SETTING_CRATE_LOAD,
    bool:SETTING_REQUIRE_NEED,
    Float:SETTING_CRATE_RANGE,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET_MIN,
    Float:SETTING_OFFSET_MAX,
    Float:SETTING_OFFSET_STEP,
    Float:SETTING_OFFSET_FREQ,
    Float:SETTING_GHOST_FREQ,
    SETTING_GHOST_ALPHA
}

enum _:CRATE
{
    CRATE_ID,
    CRATE_ITEM,
    CRATE_STATE,
    CRATE_NAME[MAX_VALUE_LENGTH],
    CRATE_MODEL[MAX_RESOURCE_PATH_LENGTH],
    CRATE_CLASS,
    CRATE_MODE,
    CRATE_FLAGS,
    CRATE_SOUND_FLAGS,
    CRATE_OCCUPIED,
    Float:CRATE_ORIGIN[3],
    Float:CRATE_ANGLES[3],
    Float:CRATE_DECAL[3],
    Float:CRATE_MINS[3],
    Float:CRATE_MAXS[3],
    Float:CRATE_COOLDOWN,
    Float:CRATE_CAPACITY,
    Float:CRATE_CAPACITY_MAX,
    Float:CRATE_FRAMERATE,
    Float:CRATE_REFILL,
    Float:CRATE_DELAY,
    Float:CRATE_HEALTH,
    Float:CRATE_FACTOR,
    Float:CRATE_EXPLODE_DAMAGE,
    Float:CRATE_EXPLODE_RADIUS,
    Float:CRATE_NEXT_USE,
    Float:CRATE_NEXT_EMPTY,
    Float:CRATE_NEXT_REFILL
}

enum _:PLAYER_DATA
{
    PDATA_NAME[MAX_VALUE_LENGTH],
    PDATA_AUTHID[MAX_AUTHID_LENGTH],
    PDATA_ADMIN_FLAGS,
    PDATA_CRATE_GHOST,
    PDATA_CRATE_MENU,
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
    SOUND_PLACE,
    SOUND_EMPTY,
    SOUND_REMOVE,
    SOUND_SUPPLY,
    SOUND_SELL,
    SOUND_REFILL
}

enum
{
    AMMO_ONLY,
    AMMO_VEST,
    AMMO_VESTHELM,
    VEST_ONLY,
    VESTHELM_ONLY
}

enum
{
    GRENADES_FB,
    GRENADES_HE,
    GRENADES_SG,
    GRENADES_HE_FB,
    GRENADES_HE_SG,
    GRENADES_FB_SG,
    GRENADES_ALL
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_REMOVE,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_REMOVE,
    ROOT_SAVE
}

enum
{
    NAV_NEXT,
    NAV_BACK,
    NAV_SELECT,
    NAV_SELECT_ALL
}

enum
{
    ROTATE_RIGHT,
    ROTATE_LEFT,
    ROTATE_PLACE
}

enum _:TASK_MENU
{
    TASK_ID,
    TASK_TYPE
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

new g_szMenuHandler[][MAX_VALUE_LENGTH] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerRemove",
    "menuHandlerRotate"
}

new g_szCN[][MAX_VALUE_LENGTH] =
{
    "SC_Ammo",
    "SC_Grenades",
    "SC_Market"
}

new Array:g_aCrate,
    Array:g_aCrateConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    g_szFileName[MAX_RESOURCE_PATH_LENGTH],
    bool:g_bFileWasRead = false,
    g_iCrate,
    g_iCrateConfig,
    g_iAmmoPickup

public plugin_init()
{
    register_plugin("Ammo Crate", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("say /sc",               "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /sc",          "cmdMenu", ADMIN_RCON)
    register_clcmd("say /supplycrate",      "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /supplycrate", "cmdMenu", ADMIN_RCON)
    register_concmd("crate_reload", "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")

    register_dictionary("SupplyCrate.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    register_forward(FM_AddToFullPack, "fwdAddToFullPack", 1)
    RegisterHam(Ham_Spawn, "func_breakable", "fwdSpawn", 1)
    RegisterHam(Ham_TakeDamage, "func_breakable", "fwdTakeDamage", 0)
    RegisterHam(Ham_TraceAttack, "func_breakable", "fwdTraceAttack", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink", 0)
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_logevent("eventRoundStart", 2, "1=Round_Start")
    register_event("HLTV", "eventHLTV", "a", "1=0", "2=0")
    set_task(g_eSettings[SETTING_GHOST_FREQ], "crateTask", .flags = "b")

    g_iAmmoPickup = get_user_msgid("AmmoPickup")

    if ( g_eSettings[SETTING_CRATE_LOAD] )
        loadData()
}

public plugin_precache()
{
    g_aCrate       = ArrayCreate(CRATE)
    g_aCrateConfig = ArrayCreate(CRATE)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aCrate)
    ArrayDestroy(g_aCrateConfig)
}

public plugin_cfg()
{
    if ( !g_iCrate )
        return PLUGIN_CONTINUE

    new eCrate[CRATE]
    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        crateKill(eCrate[CRATE_ID])
    }

    return PLUGIN_CONTINUE
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    new iArg[TASK_MENU]
    iArg[TASK_ID]   = id
    iArg[TASK_TYPE] = MENU_ROOT

    set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))

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

    new eCrateOld[CRATE], eCrateNew[CRATE],
        iCrate

    iCrate = g_iCrate
    for ( new i = 0; i < iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrateOld)

        crateCreate(0, eCrateOld[CRATE_ITEM])
        ArrayGetArray(g_aCrate, g_iCrate - 1, eCrateNew)

        xs_vec_copy(eCrateOld[CRATE_ORIGIN], eCrateNew[CRATE_ORIGIN])
        xs_vec_copy(eCrateOld[CRATE_ANGLES], eCrateNew[CRATE_ANGLES])
        xs_vec_copy(eCrateOld[CRATE_DECAL], eCrateNew[CRATE_DECAL])
        set_pev(eCrateNew[CRATE_ID], pev_origin, eCrateNew[CRATE_ORIGIN])
        set_pev(eCrateNew[CRATE_ID], pev_angles, eCrateNew[CRATE_ANGLES])
        eCrateNew[CRATE_STATE] = STATE_ACTIVE

        crateSetBox(eCrateNew)
        crateSetAnim(eCrateNew)
        crateSetActive(eCrateNew)
        ArraySetArray(g_aCrate, g_iCrate - 1, eCrateNew)
    }

    for ( new i = 0; i < iCrate; i ++ )
        crateRemove(0)

    return PLUGIN_HANDLED
}

public eventHLTV()
{
    if ( !g_iCrate )
        return PLUGIN_CONTINUE

    new eCrate[CRATE]
    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        crateKill(eCrate[CRATE_ID])
    }

    return PLUGIN_CONTINUE
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        new iPlayers[MAX_PLAYERS], iNum
        get_players(iPlayers, iNum, "ch")

        for ( new i = 0; i < iNum; i ++ )
            UpdateData(iPlayers[i])

        ArrayClear(g_aCrateConfig)
        g_iCrateConfig = 0
    }

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
        eCrate[CRATE], iSection = SECTION_NONE, iLine

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
                        eCrate[CRATE_CLASS]          = CLASS_AMMO
                        eCrate[CRATE_MODE]           = AMMO_VEST
                        eCrate[CRATE_FLAGS]          = 0
                        eCrate[CRATE_SOUND_FLAGS]    = CRATE_SOUND_PLACE | CRATE_SOUND_EMPTY | CRATE_SOUND_REMOVE | CRATE_SOUND_SUPPLY | CRATE_SOUND_SELL | CRATE_SOUND_REFILL
                        eCrate[CRATE_COOLDOWN]       = 2.5
                        eCrate[CRATE_CAPACITY]       = 10.0
                        eCrate[CRATE_FRAMERATE]      = 1.0
                        eCrate[CRATE_REFILL]         = -1.0
                        eCrate[CRATE_DELAY]          = 0.0
                        eCrate[CRATE_HEALTH]         = 250.0
                        eCrate[CRATE_FACTOR]         = 1.0
                        eCrate[CRATE_EXPLODE_DAMAGE] = 100.0
                        eCrate[CRATE_EXPLODE_RADIUS] = 150.0

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
                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        trim(szKey)
                        trim(szValue)

                        if ( equali(szKey, "SETTING_DEFAULT_MODEL") )
                        {
                            copy(g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]), szValue)
                            if ( !g_bFileWasRead ) precache_model(g_eSettings[SETTING_DEFAULT_MODEL])
                        }
                        else if ( equali(szKey, "SETTING_MINS") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MINS][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MINS][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_MAXS") )
                        {
                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS][0] = str_to_float(szKey)

                            strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                            g_eSettings[SETTING_MAXS][1] = str_to_float(szKey)
                            g_eSettings[SETTING_MAXS][2] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_SOUND_PLACE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_PLACE], charsmax(g_eSettings[SETTING_SOUND_PLACE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_PLACE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_EMPTY") )
                        {
                            copy(g_eSettings[SETTING_SOUND_EMPTY], charsmax(g_eSettings[SETTING_SOUND_EMPTY]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_EMPTY])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_REMOVE") )
                        {
                            copy(g_eSettings[SETTING_SOUND_REMOVE], charsmax(g_eSettings[SETTING_SOUND_REMOVE]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_REMOVE])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_SUPPLY") )
                        {
                            copy(g_eSettings[SETTING_SOUND_SUPPLY], charsmax(g_eSettings[SETTING_SOUND_SUPPLY]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_SUPPLY])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_SELL") )
                        {
                            copy(g_eSettings[SETTING_SOUND_SELL], charsmax(g_eSettings[SETTING_SOUND_SELL]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_SELL])
                        }
                        else if ( equali(szKey, "SETTING_SOUND_REFILL") )
                        {
                            copy(g_eSettings[SETTING_SOUND_REFILL], charsmax(g_eSettings[SETTING_SOUND_REFILL]), szValue)
                            if ( !g_bFileWasRead ) precache_sound(g_eSettings[SETTING_SOUND_REFILL])
                        }
                        else if ( equali(szKey, "SETTING_CRATE_LOAD") )
                        {
                            g_eSettings[SETTING_CRATE_LOAD] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_REQUIRE_NEED") )
                        {
                            g_eSettings[SETTING_REQUIRE_NEED] = bool:str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_CRATE_RANGE") )
                        {
                            g_eSettings[SETTING_CRATE_RANGE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                        {
                            g_eSettings[SETTING_OFFSET_BASE] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MIN") )
                        {
                            g_eSettings[SETTING_OFFSET_MIN] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_MAX") )
                        {
                            g_eSettings[SETTING_OFFSET_MAX] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                        {
                            g_eSettings[SETTING_OFFSET_STEP] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_OFFSET_FREQ") )
                        {
                            g_eSettings[SETTING_OFFSET_FREQ] = str_to_float(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                        {
                            g_eSettings[SETTING_GHOST_ALPHA] = str_to_num(szValue)
                        }
                        else if ( equali(szKey, "SETTING_GHOST_FREQ") )
                        {
                            g_eSettings[SETTING_GHOST_FREQ] = str_to_float(szValue)
                        }
                    }
                    case SECTION_CRATE:
                    {
                        strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                        trim(szKey)
                        trim(szValue)

                        if ( equali(szKey, "CRATE_MODEL") )
                        {
                            copy( eCrate[CRATE_MODEL], charsmax(eCrate[CRATE_MODEL]), szValue)
                            if ( !equali(g_eSettings[SETTING_DEFAULT_MODEL], szValue) && !g_bFileWasRead )
                                precache_model(szValue)
                        }
                        else if ( equali(szKey, "CRATE_CLASS") )
                        {
                            eCrate[CRATE_CLASS] = str_to_num(szValue)
                            eCrate[CRATE_CLASS] = clamp(eCrate[CRATE_CLASS], CLASS_AMMO, CLASS_MARKET)
                        }
                        else if ( equali(szKey, "CRATE_MODE") )
                        {
                            eCrate[CRATE_MODE] = str_to_num(szValue)
                            switch( eCrate[CRATE_CLASS] )
                            {
                                case CLASS_AMMO:     { eCrate[CRATE_MODE] = clamp(eCrate[CRATE_MODE], AMMO_ONLY, VESTHELM_ONLY); }
                                case CLASS_GRENADES: { eCrate[CRATE_MODE] = clamp(eCrate[CRATE_MODE], GRENADES_HE, GRENADES_ALL); }
                            }
                        }
                        else if ( equali(szKey, "CRATE_FLAGS") )
                        {
                            eCrate[CRATE_FLAGS] = read_flags(szValue)
                            eCrate[CRATE_FLAGS] &= 3
                        }
                        else if ( equali(szKey, "CRATE_SOUND_FLAGS") )
                        {
                            eCrate[CRATE_SOUND_FLAGS] = read_flags(szValue)
                            eCrate[CRATE_SOUND_FLAGS] &= 127
                        }
                        else if ( equali(szKey, "CRATE_COOLDOWN") )
                        {
                            eCrate[CRATE_COOLDOWN] = str_to_float(szValue)
                            eCrate[CRATE_COOLDOWN] = floatclamp(eCrate[CRATE_COOLDOWN], 0.5, 40.0)
                            eCrate[CRATE_FRAMERATE] = (2.15 + (eCrate[CRATE_COOLDOWN] - 0.5) / (40.0 - 0.5) * (3.25 - 2.15)) / eCrate[CRATE_COOLDOWN]
                        }
                        else if ( equali(szKey, "CRATE_CAPACITY") )
                        {
                            eCrate[CRATE_CAPACITY] = str_to_float(szValue)
                            if ( eCrate[CRATE_CAPACITY] < 0.0 ) eCrate[CRATE_CAPACITY] = 10.0

                            eCrate[CRATE_CAPACITY_MAX] = eCrate[CRATE_CAPACITY]
                        }
                        else if ( equali(szKey, "CRATE_REFILL") )
                        {
                            eCrate[CRATE_REFILL] = str_to_float(szValue)
                            if ( eCrate[CRATE_REFILL] < 0.0 && eCrate[CRATE_REFILL] != -1.0 ) eCrate[CRATE_REFILL] = -1.0
                        }
                        else if ( equali(szKey, "CRATE_DELAY") )
                        {
                            eCrate[CRATE_DELAY] = str_to_float(szValue)
                            if ( eCrate[CRATE_DELAY] < 0.0 ) eCrate[CRATE_DELAY] = 0.0
                        }
                        else if ( equali(szKey, "CRATE_HEALTH") )
                        {
                            eCrate[CRATE_HEALTH] = str_to_float(szValue)
                            if ( eCrate[CRATE_HEALTH] < 0.0 ) eCrate[CRATE_HEALTH] = 250.0
                        }
                        else if ( equali(szKey, "CRATE_FACTOR") )
                        {
                            eCrate[CRATE_FACTOR] = str_to_float(szValue)
                            if ( eCrate[CRATE_FACTOR] < 0.0 ) eCrate[CRATE_FACTOR] = 0.0
                        }
                        else if ( equali(szKey, "CRATE_EXPLODE_DAMAGE") )
                        {
                            eCrate[CRATE_EXPLODE_DAMAGE] = str_to_float(szValue)
                            if ( eCrate[CRATE_EXPLODE_DAMAGE] < 0.0 ) eCrate[CRATE_EXPLODE_DAMAGE] = 100.0
                        }
                        else if ( equali(szKey, "CRATE_EXPLODE_RADIUS") )
                        {
                            eCrate[CRATE_EXPLODE_RADIUS] = str_to_float(szValue)
                            if ( eCrate[CRATE_EXPLODE_RADIUS] < 0.0 ) eCrate[CRATE_EXPLODE_RADIUS] = 150.0
                        }
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
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    get_user_authid(id, g_ePlayerData[id][PDATA_AUTHID], charsmax(g_ePlayerData[][PDATA_AUTHID]))

    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public UpdateData(id)
{
    get_user_name(id, g_ePlayerData[id][PDATA_NAME], charsmax(g_ePlayerData[][PDATA_NAME]))
    g_ePlayerData[id][PDATA_ADMIN_FLAGS] = get_user_flags(id)
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public crateMenu(iArg[TASK_MENU])
{
    new szTitle[64],
        id, iType, iMenu

    id    = iArg[TASK_ID]
    iType = iArg[TASK_TYPE]
    formatex( szTitle, charsmax(szTitle), "%L", id, "CRATE_MENU_TITLE")
    iMenu = menu_create(szTitle, g_szMenuHandler[iType])

    switch( iType )
    {
        case MENU_ROOT:   menuRoot(id, iMenu)
        case MENU_CREATE: menuCreate(iMenu)
        case MENU_REMOVE: menuRemove(id, iMenu)
        case MENU_ROTATE: menuRotate(id, iMenu)
    }

    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

public menuRoot(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROOT_SAVE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    new iArg[TASK_MENU]
    iArg[TASK_ID] = id

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iCrate >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_LIMIT")
            }
            else
            {
                iArg[TASK_TYPE] = MENU_CREATE
                set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iCrate )
            {
                client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_NO_CRATE")
            }
            else
            {
                iArg[TASK_TYPE] = MENU_REMOVE
                set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(iMenu)
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
    new iArg[TASK_MENU]

    iArg[TASK_ID] = id
    iArg[TASK_TYPE] = MENU_ROTATE
    set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))

    crateCreate(id, item)
    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64],
        eCrate[CRATE]

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_BACK")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_NAV_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    g_ePlayerData[id][PDATA_CRATE_ACTION] = true

    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
    eCrate[CRATE_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
}

public menuHandlerRemove(id, menu, item)
{
    new iArg[TASK_MENU],
        eCrate[CRATE]

    iArg[TASK_ID] = id

    ArrayGetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)
    eCrate[CRATE_FLAGS] &= ~FLAG_SELECT
    ArraySetArray(g_aCrate, g_ePlayerData[id][PDATA_CRATE_MENU], eCrate)

    switch( item )
    {
        case NAV_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] >= g_iCrate - 1 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] ++

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case NAV_BACK:
        {
            if ( g_ePlayerData[id][PDATA_CRATE_MENU] <= 0 )
                g_ePlayerData[id][PDATA_CRATE_MENU] = g_iCrate - 1
            else
                g_ePlayerData[id][PDATA_CRATE_MENU] --

            iArg[TASK_TYPE] = MENU_REMOVE
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case NAV_SELECT:
        {
            crateKill(eCrate[CRATE_ID])
            crateRemove(g_ePlayerData[id][PDATA_CRATE_MENU])
            g_ePlayerData[id][PDATA_CRATE_MENU] = 0
            g_ePlayerData[id][PDATA_CRATE_ACTION] = false

            if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_REMOVE )
                crateSetSound(eCrate[CRATE_ID], SOUND_REMOVE, false)

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case NAV_SELECT_ALL:
        {
            while ( g_iCrate )
            {
                ArrayGetArray(g_aCrate, 0, eCrate)

                crateKill(eCrate[CRATE_ID])
                crateRemove(0)

                if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_REMOVE )
                    crateSetSound(eCrate[CRATE_ID], SOUND_REMOVE, false)
            }

            iArg[TASK_TYPE] = MENU_ROOT
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
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
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_RIGHT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_LEFT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "CRATE_ROTATE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRotate(id, menu, item)
{
    new eCrate[CRATE], iItem,
        iArg[TASK_MENU]

    iItem = crateFind(g_ePlayerData[id][PDATA_CRATE_GHOST], eCrate)
    iArg[TASK_ID] = id

    switch( item )
    {
        case ROTATE_RIGHT:
        {
            pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            eCrate[CRATE_ANGLES][1] -= 22.5
            if ( eCrate[CRATE_ANGLES][1] < -180.0 ) eCrate[CRATE_ANGLES][1] += 360.0

            set_pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            ArraySetArray(g_aCrate, iItem, eCrate)

            iArg[TASK_TYPE] = MENU_ROTATE
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case ROTATE_LEFT:
        {
            pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            eCrate[CRATE_ANGLES][1] += 22.5
            if ( eCrate[CRATE_ANGLES][1] > 180.0 ) eCrate[CRATE_ANGLES][1] -= 360.0

            set_pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
            ArraySetArray(g_aCrate, iItem, eCrate)

            iArg[TASK_TYPE] = MENU_ROTATE
            set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
        }
        case ROTATE_PLACE:
        {
            if ( crateTrace(eCrate, id) && iItem != -1 )
            {
                g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
                g_ePlayerData[id][PDATA_CRATE_ACTION] = false

                pev(eCrate[CRATE_ID], pev_origin, eCrate[CRATE_ORIGIN])
                pev(eCrate[CRATE_ID], pev_angles, eCrate[CRATE_ANGLES])
                eCrate[CRATE_NEXT_USE] = get_gametime() + 0.25
                eCrate[CRATE_STATE] = STATE_ACTIVE

                crateSetAnim(eCrate)
                crateSetActive(eCrate)
                ArraySetArray(g_aCrate, iItem, eCrate)

                iArg[TASK_TYPE] = MENU_ROOT
                set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
            }
            else
            {
                iArg[TASK_TYPE] = MENU_ROTATE
                set_task(MENU_BLINK, "crateMenu", .parameter = iArg, .len = sizeof(iArg))
            }
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
    new iPlayers[MAX_PLAYERS], iNum, id,
        eCrate[CRATE], iItem, iEnt

    get_players(iPlayers, iNum, "ach")
    for ( new i = 0; i < iNum; i ++ )
    {
        id = iPlayers[i]
        iEnt = g_ePlayerData[id][PDATA_CRATE_GHOST]
        if ( !iEnt || (iItem = crateFind(iEnt, eCrate)) == -1 )
            continue

        if ( crateTrace(eCrate, id) ) eCrate[CRATE_STATE] = STATE_VALID
        else                          eCrate[CRATE_STATE] = STATE_INVALID

        ArraySetArray(g_aCrate, iItem, eCrate)
    }

    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)

        if ( eCrate[CRATE_STATE] != STATE_ACTIVE )
            continue

        if ( eCrate[CRATE_NEXT_REFILL]
        && get_gametime() >= eCrate[CRATE_NEXT_REFILL] )
        {
            eCrate[CRATE_CAPACITY] = eCrate[CRATE_CAPACITY_MAX]
            eCrate[CRATE_NEXT_REFILL] = 0.0
            eCrate[CRATE_NEXT_USE] = get_gametime() + 0.1

            if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_REFILL )
                crateSetSound(eCrate[CRATE_ID], SOUND_REFILL, false)
        }
        else if ( eCrate[CRATE_OCCUPIED]
        && get_gametime() >= eCrate[CRATE_NEXT_USE] )
        {
            eCrate[CRATE_OCCUPIED] = 0
            eCrate[CRATE_NEXT_USE] = 0.0
            crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_IDLE, 1.0)
        }

        ArraySetArray(g_aCrate, i, eCrate)
    }
}

stock crateDummy(eCrate[CRATE], iItem)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))

    if ( !pev_valid(iEnt) )
        return

    set_pev(iEnt, pev_classname, g_szCN[eCrate[CRATE_CLASS]])
    set_pev(iEnt, pev_origin, eCrate[CRATE_ORIGIN])
    set_pev(iEnt, pev_angles, eCrate[CRATE_ANGLES])

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_NONE)
    set_pev(iEnt, pev_takedamage, DAMAGE_NO)
    engfunc(EngFunc_SetModel, iEnt, eCrate[CRATE_MODEL])

    eCrate[CRATE_ID] = iEnt
    ArraySetArray(g_aCrate, iItem, eCrate)

    dllfunc(DLLFunc_Spawn, iEnt)
}

public crateCreate(id, iItem)
{
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_breakable"))

    if ( !pev_valid(iEnt) )
        return

    new eCrate[CRATE]
    ArrayGetArray(g_aCrateConfig, iItem, eCrate)

    DispatchKeyValue(iEnt, "material", MATERIAL_METAL)
    eCrate[CRATE_ID] = iEnt
    eCrate[CRATE_ITEM] = iItem
    if ( id )
    {
        g_ePlayerData[id][PDATA_CRATE_GHOST] = eCrate[CRATE_ID]
        g_ePlayerData[id][PDATA_CRATE_ACTION] = true
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
    }

    set_pev(iEnt, pev_classname, g_szCN[eCrate[CRATE_CLASS]])
    engfunc(EngFunc_SetModel, iEnt, eCrate[CRATE_MODEL])

    ArrayPushArray(g_aCrate, eCrate)
    g_iCrate ++

    dllfunc(DLLFunc_Spawn, iEnt)
}

public crateRemove(iItem)
{
    ArrayDeleteItem(g_aCrate, iItem)
    g_iCrate --
}

public saveData(id)
{
    new eCrate[CRATE],
        szFile[64], iFile,
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

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n^n",
        eCrate[CRATE_ANGLES][0], eCrate[CRATE_ANGLES][1], eCrate[CRATE_ANGLES][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "decal = %.2f %.2f %.2f^n^n",
        eCrate[CRATE_DECAL][0], eCrate[CRATE_DECAL][1], eCrate[CRATE_DECAL][2])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "CRATE_CHAT_TAG", id, "CRATE_CHAT_SAVED")
    fclose(iFile)

    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[64], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], Float:fDecal[3], iItem,
        eCrate[CRATE], iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_SupplyCrate.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
    {
        console_print(0, "%L %L", 0, "CRATE_CHAT_TAG", 0, "CRATE_CHAT_NO_DATA")
        return PLUGIN_HANDLED
    }

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
            {
                crateCreate(0, iItem)
                ArrayGetArray(g_aCrate, iCount, eCrate)

                xs_vec_copy(fOrigin, eCrate[CRATE_ORIGIN])
                xs_vec_copy(fAngles, eCrate[CRATE_ANGLES])
                xs_vec_copy(fDecal, eCrate[CRATE_DECAL])
                set_pev(eCrate[CRATE_ID], pev_origin, fOrigin)
                set_pev(eCrate[CRATE_ID], pev_angles, fAngles)
                eCrate[CRATE_STATE] = STATE_ACTIVE
                eCrate[CRATE_FRAMERATE] = (2.0 + (eCrate[CRATE_COOLDOWN] - 0.5) / (40.0 - 0.5) * (3.2 - 2.0)) / eCrate[CRATE_COOLDOWN]

                crateSetBox(eCrate)
                crateSetAnim(eCrate, false)
                crateSetActive(eCrate)
                ArraySetArray(g_aCrate, iCount, eCrate)
            }

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
            trim(szKey)
            trim(szValue)

            switch( szKey[0] )
            {
                case 'i':
                {
                    iItem = str_to_num(szValue)
                }
                case 'o':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fOrigin[1] = str_to_float(szKey)
                    fOrigin[2] = str_to_float(szValue)
                }
                case 'a':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fAngles[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fAngles[1] = str_to_float(szKey)
                    fAngles[2] = str_to_float(szValue)
                }
                case 'd':
                {
                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fDecal[0] = str_to_float(szKey)

                    strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                    fDecal[1] = str_to_float(szKey)
                    fDecal[2] = str_to_float(szValue)
                }
            }
        }
    }

    if ( iCount != -1 )
    {
        crateCreate(0, iItem)
        ArrayGetArray(g_aCrate, iCount, eCrate)

        xs_vec_copy(fOrigin, eCrate[CRATE_ORIGIN])
        xs_vec_copy(fAngles, eCrate[CRATE_ANGLES])
        xs_vec_copy(fDecal, eCrate[CRATE_DECAL])
        set_pev(eCrate[CRATE_ID], pev_origin, fOrigin)
        set_pev(eCrate[CRATE_ID], pev_angles, fAngles)
        eCrate[CRATE_STATE] = STATE_ACTIVE
        eCrate[CRATE_FRAMERATE] = (2.0 + (eCrate[CRATE_COOLDOWN] - 0.5) / (40.0 - 0.5) * (3.2 - 2.0)) / eCrate[CRATE_COOLDOWN]

        crateSetBox(eCrate)
        crateSetAnim(eCrate, false)
        crateSetActive(eCrate)
        ArraySetArray(g_aCrate, iCount, eCrate)
    }

    fclose(iFile)
    return PLUGIN_HANDLED
}

public fwdSpawn(iEnt)
{
    if ( !isCrate(iEnt) )
        return HAM_IGNORED

    set_pev(iEnt, pev_solid, SOLID_NOT)
    set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
    set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)

    return HAM_IGNORED
}

public fwdTakeDamage(iEnt, iInflictor, iAttacker, Float:fDamage, iDamageBits)
{
    if ( !isCrate(iEnt) )
        return HAM_IGNORED

    new eCrate[CRATE], iItem,
        Float:fHealth

    iItem = crateFind(iEnt, eCrate)
    pev(iEnt, pev_health, fHealth)

    if ( !(eCrate[CRATE_FLAGS] & FLAG_BREAK) )
    {
        SetHamParamFloat(4, 0.0)
    }
    else if ( fDamage >= fHealth
    && iItem != -1
    && eCrate[CRATE_STATE] == STATE_ACTIVE )
    {
        eCrate[CRATE_STATE] = STATE_INACTIVE
        crateKill(eCrate[CRATE_ID])
        crateDummy(eCrate, iItem)

        if ( eCrate[CRATE_FLAGS] & FLAG_EXPLODE )
            crateExplode(eCrate)
    }

    return HAM_IGNORED
}

public fwdTraceAttack(iEnt, iAttacker, Float:fDamage, Float:fDirection[3], iTr, iDamageBits)
{
    if ( !isCrate(iEnt) )
        return HAM_IGNORED

    new Float:fEnd[3]
    get_tr2(iTr, TR_vecEndPos, fEnd)

    crateEmitParticles(fEnd)
    crateEmitSparks(fEnd)

    return HAM_IGNORED
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
    crateFind(iEnt, eCrate)

    if ( eCrate[CRATE_STATE] == STATE_ACTIVE )
    {
        if ( g_ePlayerData[iHost][PDATA_CRATE_ACTION]
        && eCrate[CRATE_FLAGS] & FLAG_SELECT )
        {
            set_es(es, ES_RenderMode, kRenderTransAlpha)
            set_es(es, ES_RenderAmt, 32)
            set_es(es, ES_RenderColor, {255, 0, 0})
            set_es(es, ES_RenderFx, kRenderFxGlowShell)
        }
    }
    else
    {
        if ( !g_ePlayerData[iHost][PDATA_CRATE_ACTION] )
        {
            set_es(es, ES_Effects, EF_NODRAW)
        }
        else
        {
            if ( eCrate[CRATE_FLAGS] & FLAG_SELECT )
            {
                set_es(es, ES_RenderMode, kRenderTransAlpha)
                set_es(es, ES_RenderAmt, 32)
                set_es(es, ES_RenderColor, {255, 0, 0})
                set_es(es, ES_RenderFx, kRenderFxGlowShell)
            }
            else if ( eCrate[CRATE_STATE] != STATE_VALID )
            {
                set_es(es, ES_RenderMode, kRenderTransAlpha)
                set_es(es, ES_RenderAmt, g_eSettings[SETTING_GHOST_ALPHA])
            }
        }
    }

    return FMRES_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    if ( g_ePlayerData[id][PDATA_CRATE_GHOST] )
    {
        new eCrate[CRATE], iItem

        if ( (iItem = crateFind(g_ePlayerData[id][PDATA_CRATE_GHOST], eCrate)) != -1 )
        {
            crateKill(g_ePlayerData[id][PDATA_CRATE_GHOST])
            crateRemove(iItem)
            g_ePlayerData[id][PDATA_CRATE_GHOST] = 0
        }
    }

    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    static eCrate[CRATE], iItem,
    iEnt, iButton

    iButton = pev(id, pev_button)

    if ( g_ePlayerData[id][PDATA_CRATE_GHOST] )
    {
        if ( get_gametime() > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET_MIN], g_eSettings[SETTING_OFFSET_MAX])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = get_gametime() + g_eSettings[SETTING_OFFSET_FREQ]
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)
    }
    else
    {
        if ( (iEnt = crateUse(id))
        && (iItem = crateFind(iEnt, eCrate)) != -1
        && eCrate[CRATE_STATE] == STATE_ACTIVE )
        {
            if ( get_gametime() >= eCrate[CRATE_NEXT_USE]
            && (!eCrate[CRATE_OCCUPIED] || eCrate[CRATE_OCCUPIED] == id) )
                crateSupply(id, eCrate, iItem)

            iButton &= ~IN_USE
            set_pev(id, pev_button, iButton)
        }
    }

    return HAM_IGNORED
}

public bool:crateTrace(eCrate[CRATE], id)
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

    return crateRadius(eCrate)
}

public crateUse(id)
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

public crateSupply(id, eCrate[CRATE], iItem)
{
    if ( eCrate[CRATE_CAPACITY] > 0 )
    {
        switch( eCrate[CRATE_CLASS] )
        {
            case CLASS_AMMO:     supplyAmmo(id, eCrate)
            case CLASS_GRENADES: supplyGrenades(id, eCrate)
            case CLASS_MARKET:   supplyMarket(id, eCrate)
        }

        if ( !eCrate[CRATE_CAPACITY] )
        {
            eCrate[CRATE_NEXT_EMPTY] = get_gametime() + 1.0

            if ( eCrate[CRATE_REFILL] != -1 )
                eCrate[CRATE_NEXT_REFILL] = get_gametime() + eCrate[CRATE_REFILL]
        }
    }
    else if ( get_gametime() >= eCrate[CRATE_NEXT_EMPTY]
    && eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY )
    {
        eCrate[CRATE_NEXT_EMPTY] = get_gametime() + 1.0
        crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
    }

    ArraySetArray(g_aCrate, iItem, eCrate)
}

supplyAmmo(id, eCrate[CRATE])
{
    new iWeapon, iClip, iAmmo, iBoost
    iWeapon = cs_get_user_weapon(id, iClip, iAmmo)

    if ( (1 << iWeapon) & CSW_ALL_GUNS
    && (!g_eSettings[SETTING_REQUIRE_NEED] || g_iWeaponMaxBP[iWeapon] > iAmmo) )
    {
        iBoost = clamp(iAmmo + floatround(g_iWeaponMaxBP[iWeapon] * eCrate[CRATE_FACTOR]), 0, g_iWeaponMaxBP[iWeapon])

        switch( eCrate[CRATE_MODE] )
        {
            case AMMO_ONLY:     { cs_set_user_bpammo(id, iWeapon, iBoost); ammoPickup(id, iBoost - iAmmo); }
            case AMMO_VEST:     { cs_set_user_bpammo(id, iWeapon, iBoost); cs_set_user_armor(id, 100, CS_ARMOR_KEVLAR); ammoPickup(id, iBoost - iAmmo); }
            case AMMO_VESTHELM: { cs_set_user_bpammo(id, iWeapon, iBoost); cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM); ammoPickup(id, iBoost - iAmmo); }
            case VEST_ONLY:     { cs_set_user_armor(id, 100, CS_ARMOR_KEVLAR); }
            case VESTHELM_ONLY: { cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM); }
        }

        eCrate[CRATE_CAPACITY] -= 1.0
        eCrate[CRATE_OCCUPIED] = id
        eCrate[CRATE_NEXT_USE] = get_gametime() + eCrate[CRATE_COOLDOWN]
        crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

        if (!iClip)
            client_cmd(id, "+attack; wait; -attack;")

        if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_SUPPLY )
            crateSetSound(id, SOUND_SUPPLY, true)
    }
    else if ( get_gametime() >= eCrate[CRATE_NEXT_EMPTY]
    && eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY )
    {
        eCrate[CRATE_NEXT_EMPTY] = get_gametime() + 1.0
        crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
    }
}

supplyGrenades(id, eCrate[CRATE])
{
    if ( !g_eSettings[SETTING_REQUIRE_NEED] || !hasGrenades(id) )
    {
        switch( eCrate[CRATE_MODE] )
        {
            case GRENADES_HE:    { give_item(id, "weapon_hegrenade"); }
            case GRENADES_FB:    { give_item(id, "weapon_flashbang"); give_item(id, "weapon_flashbang"); }
            case GRENADES_SG:    { give_item(id, "weapon_smokegrenade"); }
            case GRENADES_HE_FB: { give_item(id, "weapon_hegrenade"); give_item(id, "weapon_flashbang"); give_item(id, "weapon_flashbang"); }
            case GRENADES_HE_SG: { give_item(id, "weapon_hegrenade"); give_item(id, "weapon_smokegrenade"); }
            case GRENADES_FB_SG: { give_item(id, "weapon_flashbang"); give_item(id, "weapon_flashbang"); give_item(id, "weapon_smokegrenade"); }
            case GRENADES_ALL:   { give_item(id, "weapon_hegrenade"); give_item(id, "weapon_flashbang"); give_item(id, "weapon_flashbang"); give_item(id, "weapon_smokegrenade"); }
        }

        eCrate[CRATE_CAPACITY] -= 1.0
        eCrate[CRATE_OCCUPIED] = id
        eCrate[CRATE_NEXT_USE] = get_gametime() + eCrate[CRATE_COOLDOWN]
        crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

        if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_SUPPLY )
            crateSetSound(id, SOUND_SUPPLY, true)
    }
    else if ( get_gametime() >= eCrate[CRATE_NEXT_EMPTY]
    && eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY )
    {
        eCrate[CRATE_NEXT_EMPTY] = get_gametime() + 1.0
        crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
    }
}

supplyMarket(id, eCrate[CRATE])
{
    new iWeapon
    iWeapon = cs_get_user_weapon(id)

    if ( iWeapon != CSW_KNIFE && iWeapon != CSW_C4 )
    {
        marketSell(id, iWeapon, eCrate)

        eCrate[CRATE_CAPACITY] -= 1.0
        eCrate[CRATE_OCCUPIED] = id
        eCrate[CRATE_NEXT_USE] = get_gametime() + eCrate[CRATE_COOLDOWN]
        crateSetSeq(eCrate[CRATE_ID], CRATE_SEQ_OPENCLOSE, eCrate[CRATE_FRAMERATE])

        if ( eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_SELL )
            crateSetSound(id, SOUND_SELL, true)
    }
    else if ( get_gametime() >= eCrate[CRATE_NEXT_EMPTY]
    && eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY )
    {
        eCrate[CRATE_NEXT_EMPTY] = get_gametime() + 1.0
        crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
    }
}

stock crateSetBox(eCrate[CRATE])
{
    new Float:fMins[3], Float:fMaxs[3],
        Float:fForward[3], Float:fRight[3], Float:fUp[3],
        Float:fCorners[8][3]

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

    xs_vec_sub(eCrate[CRATE_ORIGIN], Float:{0.0, 0.0, 9999.9}, fVec1)
    engfunc(EngFunc_TraceLine, eCrate[CRATE_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, eCrate[CRATE_ID], 0)
    get_tr2(0, TR_vecEndPos, eCrate[CRATE_ORIGIN])
    xs_vec_copy(eCrate[CRATE_ORIGIN], eCrate[CRATE_DECAL])

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
    if ( eCrate[CRATE_CAPACITY] > 0.0 )
    {
        if ( eCrate[CRATE_DELAY] > 0.0 )
        {
            eCrate[CRATE_CAPACITY] = 0.0
            eCrate[CRATE_NEXT_REFILL] = get_gametime() + eCrate[CRATE_DELAY]

            if ( bPlaySound && (eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY) )
                crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
        }
        else
        {
            if ( bPlaySound && (eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_PLACE) )
                crateSetSound(eCrate[CRATE_ID], SOUND_PLACE, false)
        }
    }
    else
    {
        if ( bPlaySound && (eCrate[CRATE_SOUND_FLAGS] & CRATE_SOUND_EMPTY) )
            crateSetSound(eCrate[CRATE_ID], SOUND_EMPTY, false)
    }
}

stock crateSetActive(eCrate[CRATE])
{
    new Float:fMins[3],
        Float:fMaxs[3]

    set_pev(eCrate[CRATE_ID], pev_solid, SOLID_BBOX)
    set_pev(eCrate[CRATE_ID], pev_movetype, MOVETYPE_NONE)
    set_pev(eCrate[CRATE_ID], pev_takedamage, DAMAGE_AIM)
    set_pev(eCrate[CRATE_ID], pev_health, eCrate[CRATE_HEALTH])

    xs_vec_copy(eCrate[CRATE_MINS], fMins)
    xs_vec_copy(eCrate[CRATE_MAXS], fMaxs)
    engfunc(EngFunc_SetSize, eCrate[CRATE_ID], fMins, fMaxs)
    set_rendering(eCrate[CRATE_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock crateSetSeq(iEnt, iSequence, Float:fFrameRate)
{
    set_pev(iEnt, pev_sequence, iSequence)
    set_pev(iEnt, pev_frame, 0.0)
    set_pev(iEnt, pev_framerate, fFrameRate)
    set_pev(iEnt, pev_animtime, get_gametime())
}

stock crateSetSound(iEnt, iSound, bool:bPlayer)
{
    new szSample[64]

    switch( iSound )
    {
        case SOUND_PLACE:   copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_PLACE])
        case SOUND_EMPTY:   copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_EMPTY])
        case SOUND_REMOVE:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_REMOVE])
        case SOUND_SUPPLY:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_SUPPLY])
        case SOUND_SELL:    copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_SELL])
        case SOUND_REFILL:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_REFILL])
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, CHAN_ITEM, szSample, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

stock bool:crateRadius(eCrate[CRATE])
{
    new iEnt = -1

    while ( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, eCrate[CRATE_ORIGIN], 15.0)) )
    {
        if ( pev_valid(iEnt)
        && iEnt != eCrate[CRATE_ID]
        && (isCrate(iEnt) || pev(iEnt, pev_solid) >= SOLID_BBOX) )
            return false
    }

    return true
}

stock crateEmitParticles(Float:fOrigin[3])
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

stock crateEmitSparks(Float:fOrigin[3])
{
    message_begin_f(MSG_PVS, SVC_TEMPENTITY, fOrigin)
    write_byte(TE_SPARKS)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    message_end()
}

stock marketSell(id, iWeapon, eCrate[CRATE])
{
    new iMoney,
        iActiveWeapon

    iMoney = cs_get_user_money(id)
    iMoney += floatround(g_iWeaponMarket[iWeapon] * eCrate[CRATE_FACTOR])
    iActiveWeapon = get_pdata_cbase(id, MEMBER_ACTIVE_WEAPON)

    ExecuteHam(Ham_Weapon_RetireWeapon, iActiveWeapon)
    ExecuteHam(Ham_RemovePlayerItem, id, iActiveWeapon)
    user_has_weapon(id, iWeapon, 0)
    ExecuteHam(Ham_Item_Kill, iActiveWeapon)

    cs_set_user_money(id, iMoney, 1)
}

stock ammoPickup(id, iAmount)
{
    new iActiveWeapon,
        iAmmoType

    iActiveWeapon = get_pdata_cbase(id, MEMBER_ACTIVE_WEAPON)
    iAmmoType = get_pdata_int(iActiveWeapon, MEMBER_AMMO_TYPE)

    message_begin(MSG_ONE_UNRELIABLE, g_iAmmoPickup, .player = id)
    write_byte(iAmmoType)
    write_byte(iAmount)
    message_end()
}

stock crateExplode(eCrate[CRATE])
{
    new Float:fOrigin[3]
    xs_vec_copy(eCrate[CRATE_ORIGIN], fOrigin)

    explodeFireBall(eCrate, fOrigin)
    explodeDamage(eCrate, fOrigin)
}

stock explodeFireBall(eCrate[CRATE], Float:fOrigin[3])
{
    new iExplosion
    iExplosion = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_explosion"))

    if ( !pev_valid(iExplosion) )
        return;

    new iSpawnFlags,
        szRadius[16], Float:fRadius

    iSpawnFlags = SF_ENVEXPLOSION_NODAMAGE | SF_ENVEXPLOSION_NODECAL
    fRadius = eCrate[CRATE_EXPLODE_RADIUS] / 2.5
    fRadius = floatclamp(fRadius, 10.0, 150.0)
    formatex(szRadius, charsmax(szRadius), "%.2f", fRadius)
    DispatchKeyValue(iExplosion, "iMagnitude", szRadius)

    set_pev(iExplosion, pev_origin, fOrigin)
    set_pev(iExplosion, pev_spawnflags, iSpawnFlags)
    xs_vec_copy(eCrate[CRATE_DECAL], fOrigin)

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
    write_byte(TE_WORLDDECAL)
    write_coord_f(fOrigin[0])
    write_coord_f(fOrigin[1])
    write_coord_f(fOrigin[2])
    write_byte(random_num(46, 48))
    message_end()

    dllfunc(DLLFunc_Spawn, iExplosion)
    dllfunc(DLLFunc_Use, iExplosion, iExplosion)
}

stock explodeDamage(eCrate[CRATE], Float:fOrigin[3])
{
    new Float:fDistance, Float:fRatio, Float:fDamage,
        Float:fVec1[3], Float:fVec2[3], iEnt = -1

    while ( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fOrigin, eCrate[CRATE_EXPLODE_RADIUS])) )
    {
        if ( !pev_valid(iEnt)
        || pev(iEnt, pev_takedamage) == DAMAGE_NO
        || iEnt == eCrate[CRATE_ID] )
            continue

        pev(iEnt, pev_absmin, fVec1)
        pev(iEnt, pev_absmax, fVec2)
        xs_vec_add(fVec1, fVec2, fVec1)
        xs_vec_mul_scalar(fVec1, 0.5, fVec1)

        fDistance = xs_vec_distance(fOrigin, fVec1)
        if ( fDistance > eCrate[CRATE_EXPLODE_RADIUS] )
            continue

        fRatio = 1.0 - fDistance / eCrate[CRATE_EXPLODE_RADIUS]
        fDamage = eCrate[CRATE_EXPLODE_DAMAGE] * fRatio

        ExecuteHam(Ham_TakeDamage, iEnt, eCrate[CRATE_ID], eCrate[CRATE_ID], fDamage, DMG_GRENADE)
    }
}

stock bool:isCrate(iEnt)
{
    new szEnt[32]
    pev(iEnt, pev_classname, szEnt, charsmax(szEnt))

    for ( new i = 0; i < sizeof(g_szCN); i ++ )
    {
        if ( equali(szEnt, g_szCN[i]) )
            return true
    }

    return false
}

stock bool:hasGrenades(id)
{
    new iWeapons[32],
        iNum

    get_user_weapons(id, iWeapons, iNum)

    for ( new i = 0; i < iNum; i ++ )
    {
        if ( (1 << iWeapons[i]) & CSW_ALL_GRENADES )
            return true
    }
    return false
}

stock crateKill(iEnt)
{
    if ( pev_valid(iEnt) )
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock crateFind(iEnt, eCrate[CRATE])
{
    for ( new i = 0; i < g_iCrate; i ++ )
    {
        ArrayGetArray(g_aCrate, i, eCrate)
        if ( eCrate[CRATE_ID] == iEnt )
            return i
    }

    return -1
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}



