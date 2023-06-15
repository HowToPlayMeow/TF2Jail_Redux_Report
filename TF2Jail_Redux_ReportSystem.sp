#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Battlefield Duck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <morecolors>
#include <adminmenu>

#pragma newdecls required

//define
#define TEAM_RED 2
#define TEAM_BLU 3


public Plugin myinfo = 
{
	name = "[TF2] Jailbreak - Report System",
	author = PLUGIN_AUTHOR,
	description = "A Report System for tf2jail, to vote freekiller and camper ",
	version = PLUGIN_VERSION,
	url = ""
};

//Variable
Handle hConVars;
Handle hChatTrigger;
Handle hVoteDelay;
Handle hVoteholdtime;
Handle hVoteBurn;
Handle hVoteSlay;
Handle hVoteKick;

bool g_bVoting;
int g_iClientSelection[MAXPLAYERS + 1]; 	//Client selected which client
int g_iClientReason[MAXPLAYERS + 1];		//Client selected which Report Reason
int g_iClientPunlishment[MAXPLAYERS + 1];	//Client selected which Punlishment Reason

int g_iClientVoteSelect[MAXPLAYERS + 1]; //Client select 'no vote' or 'yes'or 'no'
int g_ilockClientSelection;
int g_ilockClientReason;
int g_ilockClientPunlishment;

//Start
public void OnPluginStart()
{
	//ConVar
	CreateConVar("sm_tf2jail_reportsystem_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_NOTIFY);
	hConVars = CreateConVar("sm_tf2jail_reportsystem_enable", "1", "[TF2] Jailbreak - Report System", _, true, 0.0, true, 1.0);
	hChatTrigger = CreateConVar("sm_tf2jail_reportsystem_chattrigger", "9kill", "Chat Trigger for sm_jailr");
	hVoteDelay = CreateConVar("sm_tf2jail_reportsystem_votedelay", "1.0", "Vote Delay in sec", _, true, 0.1, true, 10.0);
	hVoteholdtime = CreateConVar("sm_tf2jail_reportsystem_voteholdtime", "20.0", "Vote Hold Time", _, true, 10.0, true, 120.0);
	hVoteBurn = CreateConVar("sm_tf2jail_reportsystem_voteburn", "40.0", "Vote Burn pass percentage", _, true, 10.0, true, 99.0);
	hVoteSlay = CreateConVar("sm_tf2jail_reportsystem_voteslay", "50.0", "Vote Slay pass percentage", _, true, 10.0, true, 99.0);
	hVoteKick = CreateConVar("sm_tf2jail_reportsystem_votekick", "60.0", "Vote Kick pass percentage", _, true, 10.0, true, 99.0);
	
	//Commands
	RegConsoleCmd("sm_freekill", Command_ReportMenu, "Open the report menu");
	RegConsoleCmd("sm_fk", Command_ReportMenu, "Open the report menu");
	RegConsoleCmd("sm_camping", Command_ReportMenu, "Open the report menu");
	RegConsoleCmd("sm_jailr", Command_ReportMenu, "Open the report menu");
	RegConsoleCmd("sm_jailreport", Command_ReportMenu, "Open the report menu");
	
	AddCommandListener(OnClientSayCmd, "say"); //chat trigger
	AddCommandListener(OnClientSayCmd, "say_team"); //chat trigger
	
	AutoExecConfig();
}

//Chat trigger
public Action OnClientSayCmd(int iClient, const char[]strCmd, int arg)
{
	if(!IsValidClient(iClient))
		return Plugin_Continue;
		
	char cCommand[32];
	GetConVarString(hChatTrigger, cCommand, sizeof(cCommand));
	char strText[256];
	GetCmdArgString(strText, sizeof(strText));
	StripQuotes(strText);

	ReplaceString(strText, sizeof(strText), "!", "");
	ReplaceString(strText, sizeof(strText), "/", "");
	
	if((strcmp(cCommand, strText)) == 0)		Command_ReportMenu(iClient, 0);

	return Plugin_Continue;
}

//Reset Variables
public void OnClientPutInServer(int iClient)
{
	g_iClientSelection[iClient] = 0; 	
	g_iClientReason[iClient] = 0;	
	g_iClientPunlishment[iClient] = 0;	
	g_iClientVoteSelect[iClient] = 0;
}
public void OnClientDisconnect(int iClient)
{
	g_iClientSelection[iClient] = 0; 	
	g_iClientReason[iClient] = 0;	
	g_iClientPunlishment[iClient] = 0;
}
public void OnMapStart()
{
	g_bVoting = false;
}


/*******************************************************************************************

	Main Report Menu

*******************************************************************************************/
public Action Command_ReportMenu(int client, int args)
{
	if (GetConVarBool(hConVars) && IsValidClient(client))
	{
		/*
		if (GetClientTeam(client) == TEAM_BLU)	
		{
			CPrintToChat(client, "{hotpink}[Jail Report] {common}Hey! You are a {azure}Guard{common}!");
			return Plugin_Handled;
		}
		if (GetClientTeam(client) == 1)	//Spectator
		{
			CPrintToChat(client, "{hotpink}[Jail Report] {common}Hey! You are not in-game!");
			return Plugin_Handled;
		}
		if (TF2Jail_IsRebel(client))
		{
			CPrintToChat(client, "{hotpink}[Jail Report] {common}Hey! You are a {red}Rebeller{common}! You can't use the command when you are rebelled'");
			return Plugin_Handled;
		}
		*/
		if (IsVoteInProgress() || g_bVoting)					
		{
			CPrintToChat(client, "{hotpink}[Jail Report] {common}Vote is in progress! Try again later.");
			return Plugin_Handled;
		}
		//Show menu 
		if (IsValidClient(client))				// GetClientTeam(client) == TEAM_RED) // && !IsPlayerAlive(client))
		{
			char menuinfo[255];
			Menu menu = new Menu(Handler_ReportMenu);
				
			Format(menuinfo, sizeof(menuinfo), "TF2Jail Report Meow \n \n Select a Player: ");
			menu.SetTitle(menuinfo);
				
			for (int iClient = 1; iClient <= MaxClients; iClient++)
			{
				if(IsValidClient(iClient) && GetClientTeam(iClient) == TEAM_BLU)
				{
					char cSelectedClient[32];
					IntToString(iClient, cSelectedClient, sizeof(cSelectedClient));
					Format(menuinfo, sizeof(menuinfo), "%N", iClient);
					menu.AddItem(cSelectedClient, menuinfo);
				}
			}

			menu.ExitBackButton = false;
			menu.ExitButton = true;
			menu.Display(client, 60);
		}
	}
	return Plugin_Handled;
}

//Handler Report
public int Handler_ReportMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));
		
		int iSelectedClient = StringToInt(info);
		Command_GuardSelectedMenu(client, iSelectedClient);
		
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) 
		{
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}



/*******************************************************************************************

	Main Selected Client Menu

*******************************************************************************************/
public Action Command_GuardSelectedMenu(int client, int iSelectedClient)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_GuardSelectedMenu);
				
	Format(menuinfo, sizeof(menuinfo), "TF2Jail Report System V1.0 \n \n Selected Player: \n [ %N ]\n ", iSelectedClient);
	menu.SetTitle(menuinfo);
	
	g_iClientSelection[client] = iSelectedClient;
	
	Format(menuinfo, sizeof(menuinfo), "He is Freekilling");
	menu.AddItem("freekill", menuinfo); 
	
	Format(menuinfo, sizeof(menuinfo), "He is Camping");
	menu.AddItem("camping", menuinfo); 
	
	Format(menuinfo, sizeof(menuinfo), "He is playing cells");
	menu.AddItem("playcells", menuinfo); 
			

	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, 240);

	return Plugin_Handled;
}

//Handler GuardSelected
public int Handler_GuardSelectedMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));

		if (strcmp(info, "freekill") == 0)
		{
			Command_PunlishMenu(client, 1);
		}
		else if (strcmp(info, "camping") == 0)
		{
			Command_PunlishMenu(client, 2);
		}
		else if (strcmp(info, "playcells") == 0)
		{
			Command_PunlishMenu(client, 3);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) 
		{
			Command_ReportMenu(client, -1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}



/*******************************************************************************************

	Main Punlishment Menu

*******************************************************************************************/
public Action Command_PunlishMenu(int client, int iSelectedReason)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_PunlishMenu);
				
	g_iClientReason[client] = iSelectedReason;
	char creason[32];
	if (g_iClientReason[client] == 1)	creason = "Freekilling";
	if (g_iClientReason[client] == 2)	creason = "Camping";
	if (g_iClientReason[client] == 3)	creason = "Playing Cells";
	Format(menuinfo, sizeof(menuinfo), "TF2Jail Report System V1.0 \n \n Selected Player: \n [ %N ]\n \n Report Reason : [ %s ] \n ", g_iClientSelection[client], creason);
	menu.SetTitle(menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "VoteBurn him");
	menu.AddItem("voteburn", menuinfo); 
	
	Format(menuinfo, sizeof(menuinfo), "VoteSlay him");
	menu.AddItem("voteslay", menuinfo); 
	
	Format(menuinfo, sizeof(menuinfo), "VoteKick him");
	menu.AddItem("votekick", menuinfo); 
			

	menu.ExitBackButton = true;
	menu.ExitButton = false;
	menu.Display(client, 240);

	return Plugin_Handled;
}

//Handler Punlishment
public int Handler_PunlishMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char creason[32];
		if (g_iClientReason[client] == 1)	creason = "Freekilling";
		if (g_iClientReason[client] == 2)	creason = "Camping";
		if (g_iClientReason[client] == 3)	creason = "Playing Cells";
	
		char info[32];
		menu.GetItem(selection, info, sizeof(info));

		if (strcmp(info, "voteburn") == 0)
		{
			g_iClientPunlishment[client] = 1;
			CPrintToChatAll("{hotpink}[Jail Report] {common}%N. Initiated a burn vote to %N. Reason: %s", client, g_iClientSelection[client], creason);
		}
		else if (strcmp(info, "voteslay") == 0)
		{
			g_iClientPunlishment[client] = 2;
			CPrintToChatAll("{hotpink}[Jail Report] {common}%N. Initiated a slay vote to %N. Reason: %s", client, g_iClientSelection[client], creason);
		}
		else if (strcmp(info, "votekick") == 0)
		{
			g_iClientPunlishment[client] = 3;
			CPrintToChatAll("{hotpink}[Jail Report] {common}%N. Initiated a kick vote to %N. Reason: %s", client, g_iClientSelection[client], creason);
		}
		
		if(!g_bVoting) 	
		{
			g_ilockClientSelection = g_iClientSelection[client];
			g_ilockClientReason = g_iClientReason[client];
			g_ilockClientPunlishment = g_iClientPunlishment[client];
			CreateTimer(GetConVarFloat(hVoteDelay), Timer_Vote, client);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (selection == MenuCancel_ExitBack) 
		{
			Command_GuardSelectedMenu(client, g_iClientSelection[client]);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}



/*******************************************************************************************

	Main Vote Menu

*******************************************************************************************/
public Action Command_VoteMenu(int client, int iCommandTriggerClient)
{
	char menuinfo[255];
	Menu menu = new Menu(Handler_VoteMenu);
				
	char creason[32];
	if (g_ilockClientReason == 1)	creason = "Freekilling";
	if (g_ilockClientReason == 2)	creason = "Camping";
	if (g_ilockClientReason == 3)	creason = "Playing Cells";
	char cpunlish[32];
	if (g_ilockClientPunlishment == 1)	cpunlish = "Burn";
	if (g_ilockClientPunlishment == 2)	cpunlish = "Slay";
	if (g_ilockClientPunlishment == 3)	cpunlish = "Kick";
	Format(menuinfo, sizeof(menuinfo), "TF2Jail Report System V1.0 \n \n '%N' is %s, \n '%s' him, Do you agree?\n ", g_ilockClientSelection, creason, cpunlish);
	menu.SetTitle(menuinfo);
	
	Format(menuinfo, sizeof(menuinfo), "No Vote");
	menu.AddItem("novote", menuinfo); 
	
	Format(menuinfo, sizeof(menuinfo), " ");
	menu.AddItem(" ", menuinfo, ITEMDRAW_SPACER); 
	
	Format(menuinfo, sizeof(menuinfo), "Yes");
	menu.AddItem("yes", menuinfo); 
	
	Format(menuinfo, sizeof(menuinfo), "No");
	menu.AddItem("no", menuinfo); 
			

	menu.ExitBackButton = false;
	menu.ExitButton = false;
	menu.Display(client, GetConVarInt(hVoteholdtime));

	return Plugin_Handled;
}

//Handler vote
public int Handler_VoteMenu(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(selection, info, sizeof(info));

		if (strcmp(info, "novote") == 0)
		{
			g_iClientVoteSelect[client] = 0;
		}
		else if (strcmp(info, "yes") == 0)
		{
			g_iClientVoteSelect[client] = 1;
		}
		else if (strcmp(info, "no") == 0)
		{
			g_iClientVoteSelect[client] = 2;
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}



/*******************************************************************************************

	Vote Timer

*******************************************************************************************/
public Action Timer_Vote(Handle timer, int iCommandTriggerClient)
{
	CPrintToChatAll("{hotpink}[Jail Report] {common}Voting is in progress now");

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsValidClient(iClient))
		{
			Command_VoteMenu(iClient, iCommandTriggerClient);
		}
	}
	g_bVoting = true;
	CreateTimer(GetConVarFloat(hVoteholdtime), Timer_VoteFinish, iCommandTriggerClient);
}

public Action Timer_VoteFinish(Handle timer, int iCommandTriggerClient)
{
	int iVaildClient = 0;
	int inovote = 0;
	int ivoteyes = 0;
	int ivoteno = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)	
	{
		if(IsValidClient(iClient))
		{
			iVaildClient++;
			if(g_iClientVoteSelect[iClient] == 0)	inovote++;
			if(g_iClientVoteSelect[iClient] == 1)	ivoteyes++;
			if(g_iClientVoteSelect[iClient] == 2)	ivoteno++;
			g_iClientVoteSelect[iClient] = 0; //Reset value for next time
		}
	}
	
	float novoteper = float(inovote) / float(iVaildClient)* 100;
	float yesper = float(ivoteyes) / float(iVaildClient)* 100;
	float noper = float(ivoteno) / float(iVaildClient) * 100;
	
	CPrintToChatAll("{hotpink}[Jail Report] {common}Voting Result:  NoVote[%i](%i)  Yes[%i](%i)  No[%i](%i)", inovote, RoundFloat(novoteper) , ivoteyes, RoundFloat(yesper), ivoteno, RoundFloat(noper));
	
	char cpunlish[32];
	bool success = false;
	if (g_ilockClientPunlishment == 1)	
	{
		cpunlish = "Burn";
		if(yesper >= GetConVarFloat(hVoteBurn))	
		{	
			success = true;
			TF2_IgnitePlayer(g_ilockClientSelection, iCommandTriggerClient);
			if(TF2_GetPlayerClass(g_ilockClientSelection) == TFClass_Pyro)	SDKHooks_TakeDamage(g_ilockClientSelection, iCommandTriggerClient, iCommandTriggerClient, 60.0);
		}
		
	}
	if (g_ilockClientPunlishment == 2)	
	{
		cpunlish = "Slay";
		if(yesper >= GetConVarFloat(hVoteSlay))		
		{
			success = true;
			SDKHooks_TakeDamage(g_ilockClientSelection, iCommandTriggerClient, iCommandTriggerClient, 450.0);
		}
	}
	if (g_ilockClientPunlishment == 3)	
	{
		cpunlish = "Kick";
		if(yesper >= GetConVarFloat(hVoteKick))		
		{
			success = true;
			KickClient(g_ilockClientSelection);
		}
	}
	if(success)
	{
		CPrintToChatAll("{hotpink}[Jail Report] {common}Voting Sucess: %s %N", cpunlish, g_ilockClientSelection);
	}
	else
	{
		CPrintToChatAll("{hotpink}[Jail Report] {common}Voting Fail");
	}
	g_bVoting = false;
}



/*******************************************************************************************

Stock

*******************************************************************************************/
stock bool IsValidClient(int client) 
{ 
    if(client <= 0 ) return false; 
    if(client > MaxClients) return false; 
    if(!IsClientConnected(client)) return false; 
    return IsClientInGame(client); 
}

