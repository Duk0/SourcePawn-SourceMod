//*****************************************************************
//	------------------------------------------------------------- *
//						*** Menu Handling ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
public void OnAdminMenuReady(Handle topmenu)
{
	/*************************************************************/
	/* Add a Play Admin Sound option to the SourceMod Admin Menu */
	/*************************************************************/

	/* Block us from being called twice */
	if (topmenu != hAdminMenu)
	{
		/* Save the Handle */
		hAdminMenu = topmenu;
		TopMenuObject server_commands = FindTopMenuCategory(hAdminMenu, ADMINMENU_SERVERCOMMANDS);
		AddToTopMenu(hAdminMenu, "sm_admin_sounds", TopMenuObject_Item, Play_Admin_Sound,
					 server_commands, "sm_admin_sounds", ADMFLAG_GENERIC);
		AddToTopMenu(hAdminMenu, "sm_karaoke", TopMenuObject_Item, Play_Karaoke_Sound, server_commands, "sm_karaoke", ADMFLAG_CHANGEMAP);

		/* ####FernFerret#### */
		// Added two new items to the admin menu, the soundmenu hide (toggle) and the all sounds menu
		AddToTopMenu(hAdminMenu, "sm_all_sounds", TopMenuObject_Item, Play_All_Sound, server_commands, "sm_all_sounds", ADMFLAG_GENERIC);
		AddToTopMenu(hAdminMenu, "sm_sound_showmenu", TopMenuObject_Item, Set_Sound_Menu, server_commands, "sm_sound_showmenu", ADMFLAG_CHANGEMAP);
		/* ################## */
	}
}

public void Play_Admin_Sound(Handle topmenu, TopMenuAction action, TopMenuObject object_id,
						int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Play Admin Sound");
	else if (action == TopMenuAction_SelectOption)
		Sound_Menu(param, admin_sounds);
}

public void Play_Karaoke_Sound(Handle topmenu, TopMenuAction action, TopMenuObject object_id,
						 int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Karaoke");
	else if (action == TopMenuAction_SelectOption)
		Sound_Menu(param, karaoke_sounds);
}

/* ####FernFerret#### */
// Start FernFerret's Action Sounds Code
// This function sets parameters for showing the All Sounds item in the menu
public void Play_All_Sound(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "Play a Sound");
	else if (action == TopMenuAction_SelectOption)
		Sound_Menu(param, all_sounds);
}

// Creates the SoundMenu show/hide item in the admin menu, it is a toggle
public void Set_Sound_Menu(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (cvarshowsoundmenu.IntValue == 1)
	{
		if (action == TopMenuAction_DisplayOption)
			Format(buffer, maxlength, "Hide Sound Menu");
		else if (action == TopMenuAction_SelectOption)
			cvarshowsoundmenu.IntValue = 0;
	}
	else
	{
		if (action == TopMenuAction_DisplayOption)
			Format(buffer, maxlength, "Show Sound Menu");
		else if (action == TopMenuAction_SelectOption)
			cvarshowsoundmenu.IntValue = 1;
	}
}

public void Sound_Menu(int client, sound_types types)
{
	if (types >= admin_sounds)
	{
		AdminId aid = GetUserAdmin(client);
		bool isadmin = (aid != INVALID_ADMIN_ID) && GetAdminFlag(aid, Admin_Generic, Access_Effective);
		if (!isadmin)
		{
			//PrintToChat(client,"[Say Sounds] You must be an admin view this menu!");
			PrintToChat(client,"\x04[Say Sounds] \x01%t", "AdminMenu");
			return;
		}
	}

	Menu soundmenu = new Menu(Menu_Select);
	soundmenu.ExitButton = true;
	soundmenu.SetTitle("Choose a sound to play.");

	char title[PLATFORM_MAX_PATH+1];
	char buffer[PLATFORM_MAX_PATH+1];
	char karaokefile[PLATFORM_MAX_PATH+1];

	listfile.Rewind();
	if (listfile.GotoFirstSubKey())
	{
		do
		{
			listfile.GetSectionName(buffer, sizeof(buffer));
			if (!StrEqual(buffer, "JoinSound") &&
				!StrEqual(buffer, "ExitSound") &&
				strncmp(buffer, "STEAM_", 6, false))
			{
				if (!listfile.GetNum("actiononly", 0) &&
					listfile.GetNum("enable", 1))
				{
					bool admin = view_as<bool>(listfile.GetNum("admin", 0));
					bool adult = view_as<bool>(listfile.GetNum("adult", 0));
					if (!admin || types >= admin_sounds)
					{
						title[0] = '\0';
						listfile.GetString("title", title, sizeof(title));
						if (!title[0])
							strcopy(title, sizeof(title), buffer);

						karaokefile[0] = '\0';
						listfile.GetString("karaoke", karaokefile, sizeof(karaokefile));
						bool karaoke = (karaokefile[0] != '\0');
						if (!karaoke || types >= karaoke_sounds)
						{
							switch (types)
							{
								case karaoke_sounds:
								{
									if (!karaoke)
										continue;
								}
								case admin_sounds:
								{
									if (!admin)
										continue;
								}
								case all_sounds:
								{
									if (karaoke)
										StrCat(title, sizeof(title), " [Karaoke]");

									if (admin)
										StrCat(title, sizeof(title), " [Admin]");
								}
							}
							if (!adult)
							{
								soundmenu.AddItem(buffer, title);
							}
						}
					}
				}
			}
		} while (listfile.GotoNextKey());
	}
	else
	{
		SetFailState("No subkeys found in the config file!");
	}

	soundmenu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_Select(Menu menu, MenuAction action, int client, int selection)
{
	if (action == MenuAction_Select)
	{
		char SelectionInfo[PLATFORM_MAX_PATH+1];
		if (menu.GetItem(selection, SelectionInfo, sizeof(SelectionInfo)))
		{
			listfile.Rewind();
			listfile.GotoFirstSubKey();
			char buffer[PLATFORM_MAX_PATH];
			do
			{
				listfile.GetSectionName(buffer, sizeof(buffer));
				if (strcmp(SelectionInfo, buffer, false) == 0)
				{
					Submit_Sound(client, buffer);
					break;
				}
			} while (listfile.GotoNextKey());

			menu.DisplayAt(client, menu.Selection, MENU_TIME_FOREVER);
		}
	}
	else if (action == MenuAction_End)
	{	
		if (client != 0)
			delete menu;
	}
	
	return 0;
}

//*****************************************************************
//	------------------------------------------------------------- *
//				*** Client Preferences Menu ***					  *
//	------------------------------------------------------------- *
//*****************************************************************
public void SaysoundClientPref(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if (action == CookieMenuAction_SelectOption)
	{
		char confMenuFlags[26];
		confMenuFlags[0] = '\0';
		cvarMenuSettingsFlags.GetString(confMenuFlags, sizeof(confMenuFlags));
		
		if (confMenuFlags[0] == '\0' || HasClientFlags(confMenuFlags, client))
			ShowClientPrefMenu(client);
	}
}

public int MenuHandlerClientPref(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)	
	{
		if (param2 == 0)
		{
			// Saysounds
			if(!checkClientCookies(param1, CHK_SAYSOUNDS))
				SetClientCookie(param1, g_sssaysound_cookie, "1");
			else
				SetClientCookie(param1, g_sssaysound_cookie, "0");
		}
		else if (param2 == 1)
		{
			// Action Sounds
			if(!checkClientCookies(param1, CHK_EVENTS))
			{
				SetClientCookie(param1, g_ssevents_cookie, "1");
			}
			else
			{
				SetClientCookie(param1, g_ssevents_cookie, "0");
			}	
		}
		else if (param2 == 2)
		{
			// Karaoke
			if(!checkClientCookies(param1, CHK_KARAOKE))
				SetClientCookie(param1, g_sskaraoke_cookie, "1");
			else
				SetClientCookie(param1, g_sskaraoke_cookie, "0");
		}
		else if (param2 == 3)
		{
			// Chat Message
			if(!checkClientCookies(param1, CHK_CHATMSG))
				SetClientCookie(param1, g_sschatmsg_cookie, "1");
			else
				SetClientCookie(param1, g_sschatmsg_cookie, "0");
		}
		ShowClientPrefMenu(param1);
	} 
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

void ShowClientPrefMenu(int client)
{
	Menu menu = new Menu(MenuHandlerClientPref);
	char buffer[100];

	Format(buffer, sizeof(buffer), "%T", "SaysoundsMenu", client);
	menu.SetTitle(buffer);

	// Saysounds
	if(!checkClientCookies(client, CHK_SAYSOUNDS))
		Format(buffer, sizeof(buffer), "%T", "EnableSaysound", client);
	else
		Format(buffer, sizeof(buffer), "%T", "DisableSaysound", client);

	menu.AddItem("SaysoundPref", buffer);

	// Action Sounds
	if(!checkClientCookies(client, CHK_EVENTS))
		Format(buffer, sizeof(buffer), "%T", "EnableEvents", client);
	else
		Format(buffer, sizeof(buffer), "%T", "DisableEvents", client);

	menu.AddItem("EventPref", buffer);

	// Karaoke
	if(!checkClientCookies(client, CHK_KARAOKE))
		Format(buffer, sizeof(buffer), "%T", "EnableKaraoke", client);
	else
		Format(buffer, sizeof(buffer), "%T", "DisableKaraoke", client);

	menu.AddItem("KaraokePref", buffer);

	// Chat Messages
	if(!checkClientCookies(client, CHK_CHATMSG))
		Format(buffer, sizeof(buffer), "%T", "EnableChat", client);
	else
		Format(buffer, sizeof(buffer), "%T", "DisableChat", client);

	menu.AddItem("ChatPref", buffer);

	menu.ExitButton = true;

	menu.Display(client, MENU_TIME_FOREVER);
}