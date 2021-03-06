#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;

#namespace zm_game_module;

/*------------------------------------
Handles registration of any game modules
------------------------------------*/
function register_game_module(index,module_name,pre_init_func,post_init_func,pre_init_zombie_spawn_func,post_init_zombie_spawn_func,hub_start_func)
{
	if(!isdefined(level._game_modules))
	{
		level._game_modules = [];
		level._num_registered_game_modules = 0;
	}	
	
	for(i=0;i<level._num_registered_game_modules;i++)
	{
		if(!isdefined(level._game_modules[i]))
		{
			continue;
		}
		if(isdefined(level._game_modules[i].index) && level._game_modules[i].index == index)
		{
			assert(level._game_modules[i].index != index,"A Game module is already registered for index (" + index + ")" );
		}
	}
	
	level._game_modules[level._num_registered_game_modules] = spawnstruct();
	level._game_modules[level._num_registered_game_modules].index = index;
	level._game_modules[level._num_registered_game_modules].module_name = module_name;
	level._game_modules[level._num_registered_game_modules].pre_init_func = pre_init_func;
	level._game_modules[level._num_registered_game_modules].post_init_func = post_init_func;
	level._game_modules[level._num_registered_game_modules].pre_init_zombie_spawn_func = pre_init_zombie_spawn_func;
	level._game_modules[level._num_registered_game_modules].post_init_zombie_spawn_func = post_init_zombie_spawn_func;
	level._game_modules[level._num_registered_game_modules].hub_start_func = hub_start_func;
	level._num_registered_game_modules++;	
}

function set_current_game_module(game_module_index)
{
	if(!isdefined(game_module_index))
	{
		level.current_game_module = level.GAME_MODULE_CLASSIC_INDEX;
		level.scr_zm_game_module = level.GAME_MODULE_CLASSIC_INDEX;
		return;
	}
	game_module = get_game_module(game_module_index);
	
	if(!isdefined(game_module))
	{
		assert(isdefined(game_module),"unknown game module (" + game_module_index + ")" );
		return;
	}	
	
	level.current_game_module = game_module_index;	
}

function get_current_game_module()
{
	return get_game_module(level.current_game_module);
}

function get_game_module(game_module_index)
{
	
	if(!isdefined(game_module_index))
	{
		return undefined;
	}
		
	for(i=0;i<level._game_modules.size;i++)
	{
		if(level._game_modules[i].index == game_module_index)
		{
			return level._game_modules[i];
		}
	}	
	return undefined;
}

/*------------------------------------
function function that should run at the beginning of "zombie_spawn_init() " in _zm_spawner
------------------------------------*/
function game_module_pre_zombie_spawn_init()
{
	current_module = get_current_game_module();
	if(!isdefined(current_module) || !isdefined(current_module.pre_init_zombie_spawn_func))
	{
		return;
	}
	
	self [[current_module.pre_init_zombie_spawn_func]]();
}

/*------------------------------------
function function that should run at the end of "zombie_spawn_init() " in _zm_spawner
------------------------------------*/
function game_module_post_zombie_spawn_init()
{
	current_module = get_current_game_module();
	if(!isdefined(current_module) || !isdefined(current_module.post_init_zombie_spawn_func))
	{
		return;
	}
		
	self [[current_module.post_init_zombie_spawn_func]]();
}

function freeze_players(freeze)
{			
	players = GetPlayers();
	for(i=0;i<players.size;i++)
	{
		players[i] util::freeze_player_controls( freeze );
	}
}  	

function respawn_spectators_and_freeze_players()
{
	players = GetPlayers();
	foreach(player in players)
	{
		if(player.sessionstate == "spectator")
		{
			if(isdefined(player.spectate_hud))
			{
				player.spectate_hud destroy();
			}	
			player [[level.spawnPlayer]]();
		}
		player util::freeze_player_controls( true );
	}
}

function damage_callback_no_pvp_damage(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, eapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	if(isdefined(eAttacker) && isplayer( eAttacker) && eAttacker == self) //player can damage self
	{
		return iDamage;
	}
	if(isdefined(eAttacker) && !isPlayer(eAttacker))
	{
		return iDamage;
	}
	if(!isdefined(eAttacker))
	{
		return iDamage;
	}
	return 0;
}


function respawn_players()
{
	players = GetPlayers();
	foreach(player in players)
	{		
		player [[level.spawnPlayer]]();
		player util::freeze_player_controls( true );
	}
}

function zombie_goto_round( target_round )
{
	level notify( "restart_round" );
		
	if ( target_round < 1 )
	{
		target_round = 1;
	}

	level.zombie_total = 0;
	zombie_utility::ai_calculate_health( target_round );
	// kill all active zombies
	zombies = zombie_utility::get_round_enemy_array();
	if ( isdefined( zombies ) )
	{
		for (i = 0; i < zombies.size; i++)
		{
			zombies[i] dodamage(zombies[i].health + 666, zombies[i].origin);
		}
	}
	respawn_players();
	wait(1);
}

function make_supersprinter()
{
	self zombie_utility::set_zombie_run_cycle( "super_sprint" );
}

function game_module_custom_intermission(intermission_struct)
{
	self closeInGameMenu();

	level endon( "stop_intermission" );
	self endon("disconnect");
	self endon("death");
	self notify( "_zombie_game_over" ); // ww: notify so hud elements know when to leave

	//Show total gained point for end scoreboard and lobby
	self.score = self.score_total;

	self.sessionstate = "intermission";
	self.spectatorclient = -1; 
	self.killcamentity = -1; 
	self.archivetime = 0; 
	self.psoffsettime = 0; 
	self.friendlydamage = undefined;

	s_point = struct::get(intermission_struct,"targetname");
	
	if(!isdefined(level.intermission_cam_model))
	{
		level.intermission_cam_model = spawn("script_model",s_point.origin);//(1566, 498, 47.5));
		level.intermission_cam_model.angles = s_point.angles;
		level.intermission_cam_model setmodel("tag_origin");
	}
	self.game_over_bg = NewClientHudelem( self );
	self.game_over_bg.horzAlign = "fullscreen";
	self.game_over_bg.vertAlign = "fullscreen";
	self.game_over_bg SetShader( "black", 640, 480 );
	self.game_over_bg.alpha = 1;

	self spawn( level.intermission_cam_model.origin, level.intermission_cam_model.angles );
	self CameraSetPosition( level.intermission_cam_model );
	self CameraSetLookAt();
	self CameraActivate( true );	
	self linkto(level.intermission_cam_model);	
	level.intermission_cam_model moveto(struct::get(s_point.target,"targetname").origin,12);	
	if(isdefined(level.intermission_cam_model.angles))
	{	
		level.intermission_cam_model rotateto(struct::get(s_point.target,"targetname").angles,12);	
	}
	self.game_over_bg FadeOverTime( 2 );
	self.game_over_bg.alpha = 0;
	wait(2);				
	self.game_over_bg thread zm::fade_up_over_time(1);
}

function create_fireworks(launch_spots,min_wait,max_wait,randomize)
{
	level endon("stop_fireworks");
	while(1)
	{
		if(IS_TRUE(randomize))
		{
			launch_spots =array::randomize(launch_spots);
		}
		foreach(spot in launch_spots)
		{
			level thread fireworks_launch(spot);
			wait(randomfloatrange(min_wait,max_wait));
		}
		wait(randomfloatrange(min_wait,max_wait));	
	}
}

function fireworks_launch(launch_spot)
{
	firework = spawn("script_model",launch_spot.origin + (randomintrange(-60,60),randomintrange(-60,60),0));
	firework setmodel("tag_origin");
	util::wait_network_frame();	
	PlayFXOnTag( level._effect[ "fw_trail_cheap" ], firework, "tag_origin" );
	firework playloopsound( "zmb_souls_loop", .75 );
	
	dest = launch_spot;	

	while(isdefined(dest) && isdefined(dest.target))
	{
		random_offset = (randomintrange(-60,60),randomintrange(-60,60),0);
		new_dests = struct::get_array(dest.target,"targetname");	
		new_dest = array::random(new_dests);
		dest = new_dest;
		dist = distance(new_dest.origin + random_offset,firework.origin);
		time = dist/700;							
		firework MoveTo(new_dest.origin + random_offset, time);
		firework waittill("movedone");
	}
 	firework playsound( "zmb_souls_end");

	playfx(level._effect["fw_pre_burst"],firework.origin);
	firework delete();
}
