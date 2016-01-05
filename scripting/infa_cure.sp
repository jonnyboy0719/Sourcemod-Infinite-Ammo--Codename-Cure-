#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define sInfo "\x01[\x07FF0000Info\x01]"

new Handle:flGroup;
new Handle:is_sourcebans;

new bool:access[MAXPLAYERS + 1] = false;
new bool:DontRepeat[MAXPLAYERS + 1] = false;

new AdminID[MAXPLAYERS + 1];
new GroupID;

Handle db = null;

//=========================
// Plugin:myinfo = {}
//========================

public Plugin:myinfo = {
	name 						= "Infinite Ammo",
	author 						= "JonnyBoy0719",
	description 				= "GO NUTS!",
	version 					= "1.0",
	url 						= ""
}

//=========================
// OnPluginStart()
//========================

public OnPluginStart()
{
	// Events
	HookEvent("player_spawn", EVENT_PlayerSpawned);
	flGroup = CreateConVar("sm_infa_group", "vip", "Set which group should have access. If empty, anyone have infinite ammo.");
	is_sourcebans = CreateConVar("sm_infa_sourcebans", "0", "If the server is using Sourcebans, then you need to enable this", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	// Lets create a config file
	AutoExecConfig(true, "infinite_ammo");
	
	DBConnect();
}

//=========================
// DBConnect()
//========================

void DBConnect()
{
	char errors[255];
	if (GetConVarBool(is_sourcebans))
		db = SQL_Connect("sourcebans", true, errors, sizeof(errors));
	else
	{
		if (SQL_CheckConfig("prometheus"))
		{
			db = SQL_Connect("prometheus", true, errors, sizeof(errors));
		} else {
			db = SQL_Connect("default", true, errors, sizeof(errors));
		}
	}
	if (db == null) LogError("[Prometheus] Unable to connect to MySQL database: %s", errors);
}

//=========================
// OnClientPostAdminCheck()
//========================

public OnClientPostAdminCheck(iClient)
{
	if (1 <= iClient <= MaxClients)
	{
		CheckDataBase(iClient);
	}
}

//=========================
// EVENT_PlayerSpawned()
//========================

public Action:EVENT_PlayerSpawned(Handle:hEvent,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (!IsValidClient(client)) return;
	CreateTimer(0.5, InfiniteAmmoPls, client, TIMER_REPEAT);
}

//=========================
// InfiniteAmmoPls()
//========================

public Action:InfiniteAmmoPls(Handle:timer, any:client)
{
	if (IsClientInGame(client))
	{
		// If the player is not alive, don't do anything.
		if (!IsPlayerAlive(client))
			return Plugin_Stop;
		
		if(!DontRepeat[client])
			CheckDataBase(client);
		
		if(access[client])
		{
			if(!DontRepeat[client])
				DontRepeat[client] = true;
			SetInfiniteAmmo(client);
		}
		else
			return Plugin_Stop;
	}
	return Plugin_Handled;
}

//=========================
// CheckDataBase()
//========================

public CheckDataBase(client)
{
	if(!IsClientInGame(client))
		return;
	
	if(!IsPlayerAlive(client))
		return;
	
	decl String:getgroup[255];
	GetConVarString(flGroup, getgroup, sizeof(getgroup));
	
	if(StrEqual(getgroup, ""))
	{
		access[client] = true;
		return;
	}
	
	if(!GetGroupID(getgroup))
		return;
	
	new String:SteamID[32];
	GetClientAuthString(client, SteamID, sizeof(SteamID));
	
	if(IsValidAdmin(client, SteamID))
		if(IsValidGroup(AdminID[client], GroupID))
			access[client] = true;
	
	return;
}

//=========================
// bool:IsValidClient()
//========================

stock bool:IsValidClient(client, bool:bCheckAlive=true)
{
	if(client < 1 || client > MaxClients) return false;
	if(!IsClientInGame(client)) return false;
	if(IsClientSourceTV(client) || IsClientReplay(client)) return false;
	if(IsFakeClient(client)) return false;
	if(bCheckAlive) return IsPlayerAlive(client);
	return true;
}

//=========================
// SetInfiniteAmmo()
//========================

stock SetInfiniteAmmo(client){
	new activeWeapon = GetEntDataEnt2(client, FindSendPropInfo("CBasePlayer", "m_hActiveWeapon"));
	if(activeWeapon != INVALID_ENT_REFERENCE)
		SetEntData(activeWeapon, FindSendPropInfo("CBaseCombatWeapon", "m_iClip1"), 60);
}

//=========================
// Prometheus
//========================

bool IsValidGroup(authid, group)
{
	if (GetConVarBool(is_sourcebans))
	{
		Handle hQry = null;
		char query[100];
		Format(query, sizeof(query), "SELECT EXISTS (SELECT * FROM sb_admins_servers_groups WHERE group_id = %d AND admin_id = %d)", group, authid);
		hQry = SQL_Query(db, query);
		if (hQry == null)
		{
			char Error[1024];
			SQL_GetError(db, Error, sizeof(Error));
			LogError("[SourceBans] An error occurred while checking if valid group in the Database: %s", Error);
			CloseHandle(hQry);
			return false;
		}// \x07f39c12
		if (SQL_FetchRow(hQry)) 
		{
			CloseHandle(hQry);
			return true;
		}
		CloseHandle(hQry);

	}
	else
	{
		Handle hQry = null;
		char query[100];
		Format(query, sizeof(query), "SELECT EXISTS (SELECT * FROM sm_admins_groups WHERE group_id = %d AND admin_id = %d)", group, authid);
		hQry = SQL_Query(db, query);
		if (hQry == null)
		{
			char Error[1024];
			SQL_GetError(db, Error, sizeof(Error));
			LogError("[Prometheus] An error occurred while checking if valid group in the Database: %s", Error);
			CloseHandle(hQry);
			return false;
		}// \x07f39c12
		if (SQL_FetchRow(hQry)) 
		{
			CloseHandle(hQry);
			return true;
		}
		CloseHandle(hQry);
	}
	return false;
}

bool IsValidAdmin(client, char[] authid)
{
	if (GetConVarBool(is_sourcebans))
	{
		Handle hQry = null;
		char query[100];
		Format(query, sizeof(query), "SELECT EXISTS (SELECT * FROM sb_admins WHERE authid = '%s')", authid);
		hQry = SQL_Query(db, query);
		if (hQry == null)
		{
			char Error[1024];
			SQL_GetError(db, Error, sizeof(Error));
			LogError("[SourceBans] An error occurred while checking if valid admin in the Database: %s", Error);
			CloseHandle(hQry);
			return false;
		}
		if (SQL_FetchRow(hQry)) 
		{
			if (SQL_FetchInt(hQry, 0) == 1) 
			{
				AdminID[client] = SQL_FetchInt(hQry, 0);
				CloseHandle(hQry);
				return true;
			}
		}
		CloseHandle(hQry);

	}
	else
	{
		Handle hQry = null;
		char query[100];
		Format(query, sizeof(query), "SELECT EXISTS (SELECT * FROM sm_admins WHERE identity = '%s')", authid);
		hQry = SQL_Query(db, query);
		if (hQry == null)
		{
			char Error[1024];
			SQL_GetError(db, Error, sizeof(Error));
			LogError("[Prometheus] An error occurred while checking if valid admin in the Database: %s", Error);
			CloseHandle(hQry);
			return false;
		}
		if (SQL_FetchRow(hQry)) 
		{
			if (SQL_FetchInt(hQry, 0) == 1) 
			{
				AdminID[client] = SQL_FetchInt(hQry, 0);
				CloseHandle(hQry);
				return true;
			}
		}
		CloseHandle(hQry);
	}
	return false;
}

bool GetGroupID(char[] group)
{
	if (GetConVarBool(is_sourcebans))
	{
		Handle hQry = null;
		char query[100];
		Format(query, sizeof(query), "SELECT gid FROM sb_groups WHERE name = '%s'", group);
		hQry = SQL_Query(db, query);
		if (hQry == null)
		{
			char Error[1024];
			SQL_GetError(db, Error, sizeof(Error));
			LogError("[SourceBans] An error occurred while selecting group ID from the Database: %s", Error);
			CloseHandle(hQry);
			return false;
		}
		if (SQL_FetchRow(hQry))
		{
			GroupID = SQL_FetchInt(hQry, 0);
			CloseHandle(hQry);
			return true;
		}
		CloseHandle(hQry);
	}
	else
	{
		Handle hQry = null;
		char query[100];
		Format(query, sizeof(query), "SELECT id FROM sm_groups WHERE name = '%s'", group);
		hQry = SQL_Query(db, query);
		if (hQry == null)
		{
			char Error[1024];
			SQL_GetError(db, Error, sizeof(Error));
			LogError("[Prometheus] An error occurred while selecting group ID from the Database: %s", Error);
			CloseHandle(hQry);
			return false;
		}
		if (SQL_FetchRow(hQry))
		{
			GroupID = SQL_FetchInt(hQry, 0);
			CloseHandle(hQry);
			return true;
		}
		CloseHandle(hQry);
	}
	return false;
}