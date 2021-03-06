#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\damagefeedback_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\tweakables_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_weaponobjects;
#using scripts\shared\weapons\_heatseekingmissile;

#using scripts\mp\_challenges;
#using scripts\mp\_util;
#using scripts\mp\gametypes\_globallogic_audio;
#using scripts\mp\gametypes\_globallogic_player;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_dogs;
#using scripts\mp\killstreaks\_flak_drone;
#using scripts\mp\killstreaks\_killstreak_bundles;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\mp\killstreaks\_killstreaks.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using_animtree ( "mp_vehicles" );

#namespace helicopter;

#precache( "locationselector", "compass_objpoint_helicopter" );
#precache( "string", "MP_DESTROYED_HELICOPTER");
#precache( "string", "KILLSTREAK_DESTROYED_HELICOPTER_GUNNER");
#precache( "string", "KILLSTREAK_EARNED_HELICOPTER_COMLINK" );
#precache( "string", "KILLSTREAK_HELICOPTER_COMLINK_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_HELICOPTER_COMLINK_INBOUND" );
#precache( "string", "KILLSTREAK_HELICOPTER_COMLINK_HACKED" );
#precache( "string", "KILLSTREAK_DESTROYED_SUPPLY_DROP_DEPLOY_SHIP" );
#precache( "string", "mpl_killstreak_heli" );
#precache( "fx", "killstreaks/fx_heli_exp_lg" );
#precache( "fx", "killstreaks/fx_heli_exp_md" );
#precache( "fx", "killstreaks/fx_vtol_exp" );
#precache( "fx", "killstreaks/fx_heli_exp_sm" );
#precache( "fx", "killstreaks/fx_heli_smk_trail_engine_33" );
#precache( "fx", "killstreaks/fx_heli_smk_trail_engine_66" );
#precache( "fx", "killstreaks/fx_heli_smk_trail_tail" );
#precache( "fx", "killstreaks/fx_heli_smk_trail_engine" );
#precache( "fx", "killstreaks/fx_sc_lights_grn" );
#precache( "fx", "killstreaks/fx_sc_lights_red" );

#define HELI_ENTRANCE_Z_HELP 1000
#define HELICOPTER_COMLINK "helicopter_comlink"
#define INVENTORY_HELICOPTER_COMLINK "inventory_helicopter_comlink"
	
function precachehelicopter(model,type)
{	
	if(!isdefined(type))
		type = "blackhawk";

	level.vehicle_deathmodel[model] = model;
	
	/******************************************************/
	/*					SETUP WEAPON TAGS				  */
	/******************************************************/
	
	// helicopter sounds:
	level.heli_sound["hit"] = "evt_helicopter_hit";
	level.heli_sound["hitsecondary"] = "evt_helicopter_hit";
	level.heli_sound["damaged"] = "null";
	level.heli_sound["spinloop"] = "evt_helicopter_spin_loop";
	level.heli_sound["spinstart"] = "evt_helicopter_spin_start";
	level.heli_sound["crash"] = "evt_helicopter_midair_exp";
	level.heli_sound["missilefire"] = "wpn_hellfire_fire_npc";
}

function useKillstreakHelicopter( hardpointType )
{
	if ( self killstreakrules::isKillstreakAllowed( hardpointType, self.team ) == false)
		return false;

	if ( (!isdefined( level.heli_paths ) || !level.heli_paths.size) )
	{
		/#iprintlnbold("Need to add helicopter paths to the level");#/
		return false;
	}
	
	if ( ( hardpointType == "helicopter_comlink" ) || ( hardpointType == "inventory_helicopter_comlink" ) )
	{
		result = self selectHelicopterLocation( hardpointType );
		if ( !isdefined(result) || result == false )
			return false;
	}
	
	destination = 0;
	missilesEnabled = false;
	if ( hardpointType == "helicopter_x2" )
	{
		missilesEnabled = true;
	}
	
	assert( level.heli_paths.size > 0, "No non-primary helicopter paths found in map" );
			
	random_path = randomint( level.heli_paths[destination].size );
	
	startnode = level.heli_paths[destination][random_path];
	
	protectLocation = undefined;
	armored = false;
	if ( ( hardpointType == "helicopter_comlink" ) || ( hardpointType == "inventory_helicopter_comlink" ) )
	{
		protectLocation = (level.helilocation[0],  level.helilocation[1], int(airsupport::getMinimumFlyHeight()) -200 );
		armored = false;
		
		startnode = getValidProtectLocationStart(random_path, protectLocation, destination );
	}
	
	killstreak_id = self killstreakrules::killstreakStart( hardpointType, self.team );
	if ( killstreak_id == -1 )
		return false;
	
	if ( ( hardpointType == "helicopter_comlink" ) || ( hardpointType == "inventory_helicopter_comlink" ) )
	{
		self challenges::calledInComlinkChopper();
	}

	self killstreaks::play_killstreak_start_dialog( hardpointType, self.team, killstreak_id );
	self thread announceHelicopterInbound( hardpointType );	
	
	thread heli_think( self, startnode, self.team, missilesEnabled, protectLocation, hardpointType, armored, killstreak_id );

	return true;
}

function announceHelicopterInbound(hardpointType)
{
	team = self.team;
	
	self AddWeaponStat( killstreaks::get_killstreak_weapon( hardpointtype ), "used", 1 );
}

// generate path graph from script_origins
function heli_path_graph()
{	
	// collecting all start nodes in the map to generate path arrays
	path_start = getentarray( "heli_start", "targetname" ); 					// start pointers, point to the actual start node on path
	path_dest = getentarray( "heli_dest", "targetname" ); 						// dest pointers, point to the actual dest node on path
	loop_start = getentarray( "heli_loop_start", "targetname" ); 				// start pointers for loop path in the map
	gunner_loop_start = getentarray( "heli_gunner_loop_start", "targetname" );  // start pointers for gunner loop path in the map
	leave_nodes = getentarray( "heli_leave", "targetname" ); 					// points where the helicopter leaves to
	crash_start = getentarray( "heli_crash_start", "targetname" );				// start pointers, point to the actual start node on crash path
	
	assert( ( isdefined( path_start ) && isdefined( path_dest ) ), "Missing path_start or path_dest" );
		
	// for each destination, loop through all start nodes in level to populate array of start nodes that leads to this destination
	for (i=0; i<path_dest.size; i++)
	{
		startnode_array = [];
		isPrimaryDest = false;
		
		// destnode is the final destination from multiple start nodes
		destnode_pointer = path_dest[i];
		destnode = getent( destnode_pointer.target, "targetname" );
		
		// for each start node, traverse to its dest., if same dest. then append to startnode_array
		for ( j=0; j<path_start.size; j++ )
		{
			toDest = false;
			currentnode = path_start[j];
			// traverse through path to dest.
			while( isdefined( currentnode.target ) )
			{
				nextnode = getent( currentnode.target, "targetname" );
				if ( nextnode.origin == destnode.origin )
				{
					toDest = true;
					break;
				}
				
				currentnode = nextnode;
			}
			if ( toDest )
			{
				startnode_array[startnode_array.size] = getent( path_start[j].target, "targetname" ); // the actual start node on path, not start pointer
				if ( isdefined( path_start[j].script_noteworthy ) && ( path_start[j].script_noteworthy == "primary" ) )
					isPrimaryDest = true;
			}
		}
		assert( ( isdefined( startnode_array ) && startnode_array.size > 0 ), "No path(s) to destination" );
		
		// load the array of start nodes that lead to this destination node into level.heli_paths array as an element
		if ( isPrimaryDest )
			level.heli_primary_path = startnode_array;
		else
			level.heli_paths[level.heli_paths.size] = startnode_array;
	}
	
	// loop paths array
	for (i=0; i<loop_start.size; i++)
	{
		startnode = getent( loop_start[i].target, "targetname" );
		level.heli_loop_paths[level.heli_loop_paths.size] = startnode;
	}
	assert( isdefined( level.heli_loop_paths[0] ), "No helicopter loop paths found in map" );
	
	// chopper gunner paths
	for ( i = 0 ; i < gunner_loop_start.size ; i++ )
	{
		startnode = getent( gunner_loop_start[i].target, "targetname" );
		startnode.isGunnerPath = true;
		level.heli_loop_paths[level.heli_loop_paths.size] = startnode;
	}
	
	// start nodes
	for (i=0; i<path_start.size; i++)
	{
		// do not consider "primary" starts as a path_start for supply drops
		if ( isdefined( path_start[ i ].script_noteworthy ) && ( path_start[ i ].script_noteworthy == "primary" ) )
			continue;

		level.heli_startnodes[level.heli_startnodes.size] = path_start[i];
	}
	assert( isdefined( level.heli_startnodes[0] ), "No helicopter start nodes found in map" );
	
	// leave nodes
	for (i=0; i<leave_nodes.size; i++)
		level.heli_leavenodes[level.heli_leavenodes.size] = leave_nodes[i];
	assert( isdefined( level.heli_leavenodes[0] ), "No helicopter leave nodes found in map" );
	
	// crash paths
	for (i=0; i<crash_start.size; i++)
	{
		crash_start_node = getent( crash_start[i].target, "targetname" );
		level.heli_crash_paths[level.heli_crash_paths.size] = crash_start_node;
	}
	assert( isdefined( level.heli_crash_paths[0] ), "No helicopter crash paths found in map" );
}

function init()
{
	path_start = getentarray( "heli_start", "targetname" ); 		// start pointers, point to the actual start node on path
	loop_start = getentarray( "heli_loop_start", "targetname" ); 	// start pointers for loop path in the map


	level.chaff_offset["attack"] = ( -130, 0, -140 );
	
	level.chopperComlinkFriendly = "veh_t7_drone_hunter";
	level.chopperComlinkEnemy = "veh_t7_drone_hunter";
	level.chopperRegular = "veh_t7_drone_hunter";

	precachehelicopter( level.chopperRegular );
	precachehelicopter( level.chopperComlinkFriendly );
	precachehelicopter( level.chopperComlinkEnemy );
		
	clientfield::register( "helicopter", "heli_comlink_bootup_anim", VERSION_SHIP, 1, "int");
	clientfield::register( "helicopter", "heli_warn_targeted", VERSION_SHIP, 1, "int" );
	clientfield::register( "helicopter", "heli_warn_locked", VERSION_SHIP, 1, "int" );
	clientfield::register( "helicopter", "heli_warn_fired", VERSION_SHIP, 1, "int" );	
	
	clientfield::register( "helicopter", "active_camo", VERSION_SHIP, 3, "int" );


	clientfield::register( "vehicle", "heli_comlink_bootup_anim", VERSION_SHIP, 1, "int");
	clientfield::register( "vehicle", "heli_warn_targeted", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "heli_warn_locked", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "heli_warn_fired", VERSION_SHIP, 1, "int" );	
	
	clientfield::register( "vehicle", "active_camo", VERSION_SHIP, 3, "int" );
	
	
	// array of paths, each element is an array of start nodes that all leads to a single destination node
	level.heli_paths = [];
	level.heli_loop_paths = [];
	level.heli_startnodes = [];
	level.heli_leavenodes = [];
	level.heli_crash_paths = [];
	
	level.last_start_node_index = 0;

	// helicopter fx
	level.chopper_fx["explode"]["death"] = "killstreaks/fx_heli_exp_lg";
	level.chopper_fx["explode"]["guard"] = "killstreaks/fx_heli_exp_md";
	level.chopper_fx["explode"]["gunner"] = "killstreaks/fx_vtol_exp";
	level.chopper_fx["explode"]["large"] = "killstreaks/fx_heli_exp_sm";
	level.chopper_fx["damage"]["light_smoke"] = "killstreaks/fx_heli_smk_trail_engine_33";
	level.chopper_fx["damage"]["heavy_smoke"] = "killstreaks/fx_heli_smk_trail_engine_66";
	level.chopper_fx["smoke"]["trail"] = "killstreaks/fx_heli_smk_trail_tail";
	level.chopper_fx["fire"]["trail"]["large"] = "killstreaks/fx_heli_smk_trail_engine";
	
	level._effect["heli_comlink_light"]["friendly"] = "_debug/fx_debug_deleted_fx";
	level._effect["heli_comlink_light"]["enemy"] = "_debug/fx_debug_deleted_fx";
	
	level.heliComlinkBootupAnim = %veh_anim_future_heli_gearup_bay_open;
	
	killstreaks::register("helicopter_comlink", "helicopter_comlink", "killstreak_helicopter_comlink", "helicopter_used",&useKillstreakHelicopter, true );
	killstreaks::register_strings("helicopter_comlink", &"KILLSTREAK_EARNED_HELICOPTER_COMLINK", &"KILLSTREAK_HELICOPTER_COMLINK_NOT_AVAILABLE", &"KILLSTREAK_HELICOPTER_COMLINK_INBOUND", undefined, &"KILLSTREAK_HELICOPTER_COMLINK_HACKED" );
	killstreaks::register_dialog("helicopter_comlink", "mpl_killstreak_heli", "helicopterDialogBundle", "helicopterPilotDialogBundle", "friendlyHelicopter", "enemyHelicopter", "enemyHelicopterMultiple", "friendlyHelicopterHacked", "enemyHelicopterHacked", "requestHelicopter", "threatHelicopter" );
	killstreaks::register_alt_weapon("helicopter_comlink", "cobra_20mm_comlink" );
	killstreaks::set_team_kill_penalty_scale( "helicopter_comlink", 0.0 );
	
	// TODO: Move to killstreak data
	level.killstreaks["helicopter_comlink"].threatOnKill = true;
	level.killstreaks["inventory_helicopter_comlink"].threatOnKill = true;	

	if ( !path_start.size && !loop_start.size)
		return;

	heli_path_graph();
}

function heli_get_dvar_int( dvar, def )
{
	return int( heli_get_dvar( dvar, def ) );
}

// dvar set/fetch/check
function heli_get_dvar( dvar, def )
{
	if ( GetDvarString( dvar ) != "" )
		return getdvarfloat( dvar );
	else
	{
		SetDvar( dvar, def );
		return Float( def );
	}
}

function set_goal_pos( goalPos, stop )
{
	self.heliGoalPos = goalpos;
	self setvehgoalpos( goalPos, stop );
}

function spawn_helicopter( owner, origin, angles, model, targetname, target_offset, hardpointType, killstreak_id )
{
	chopper = spawnHelicopter( owner, origin, angles, model, targetname );
	chopper.owner = owner;
	chopper clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	chopper.attackers = [];
	chopper.attackerData = [];
	chopper.attackerDamage = [];
	chopper.flareAttackerDamage = [];
	chopper.destroyFunc =&destroyHelicopter;
	chopper.hardpointType = hardpointType;
	chopper.killstreak_id = killstreak_id;
	chopper.pilotIsTalking = false;
	chopper SetDrawInfrared( true );
	chopper.allowContinuedLockonAfterInvis = true;
	chopper.soundmod = "heli";
	
	if ( !isdefined( target_offset ) )
		target_offset = (0,0,0);
		
	chopper.target_offset = target_offset;
	
	Target_Set(chopper, target_offset);

	if( ( hardpointtype == "helicopter_comlink" ) || ( hardpointtype == "inventory_helicopter_comlink" ) )
	{
		chopper.allowHackingAfterCloak = true;
		chopper.flak_drone = flak_drone::spawn( chopper, &OnFlakDroneDestroyed );
		chopper.treat_owner_damage_as_friendly_fire = true;
		chopper.ignore_team_kills = true;
		chopper init_active_camo();
	}
	
	return chopper;
}

function OnFlakDroneDestroyed()
{
	chopper = self;
	
	if ( !isdefined( chopper ) )
	{
		return;
	}
	chopper.numFlares = 0;
	chopper killstreaks::play_pilot_dialog_on_owner( "weaponDestroyed", "helicopter_comlink", chopper.killstreak_id );
	
	chopper thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile("crashing", "death");
}

function explodeOnContact( hardpointtype )
{
	self endon ( "death" );
	wait (10);
	for (;;)
	{
		self waittill("touch");
		self thread heli_explode();
	}
}

function getValidProtectLocationStart(random_path, protectLocation, destination )
{
	startnode = level.heli_paths[destination][random_path];
	path_index = ( random_path + 1 ) % level.heli_paths[destination].size;
	
	inNoFly = airsupport::crossesNoFlyZone( protectLocation + (0,0,1), protectLocation );
	if( isdefined(inNoFly))
	{
		protectLocation = (protectLocation[0], protectLocation[1], level.noFlyZones[inNoFly].origin[2] + level.noFlyZones[inNoFly].height);
	}
	
	noFlyZone = airsupport::crossesNoFlyZone( startnode.origin, protectLocation );
	while ( isdefined(noFlyZone) && path_index != random_path )
	{
		startnode = level.heli_paths[destination][path_index];

		if( isDefined(noFlyZone) )
		{
			path_index = ( path_index + 1 ) % level.heli_paths[destination].size;
		}
	}
	
	// if we dont have a valid position at this point just return
	return level.heli_paths[destination][path_index];
}

function getValidRandomLeaveNode( start )
{
	if( self === level.vtol )
	{
		foreach( node in level.heli_leavenodes )
		{
			if ( isdefined( node.script_noteworthy ) && ( node.script_noteworthy == "primary" ) )
				return node;
		}
	}
	
	random_leave_node = randomInt( level.heli_leavenodes.size );
	leavenode = level.heli_leavenodes[random_leave_node];
	path_index = ( random_leave_node + 1 ) % level.heli_leavenodes.size;
	noFlyZone = airsupport::crossesNoFlyZone( leavenode.origin, start );
	isPrimary = ( leavenode.script_noteworthy === "primary" );
	
	while( ( isdefined( noFlyZone ) || isPrimary ) && ( path_index != random_leave_node ) )
	{
		leavenode = level.heli_leavenodes[path_index];
		noFlyZone = airsupport::crossesNoFlyZone( leavenode.origin, start );
		isPrimary = ( leavenode.script_noteworthy === "primary" );
		path_index = ( path_index + 1 ) % level.heli_leavenodes.size;
	}
	
	// if we dont have a valid position at this point just return
	return level.heli_leavenodes[path_index];
}

function getValidRandomStartNode( dest )
{	
	path_index = randomInt( level.heli_startnodes.size );
	best_index = path_index;
	
	count = 0;
	for( i = 0; i < level.heli_startnodes.size; i++ )
	{
		startnode = level.heli_startnodes[path_index];
		noFlyZone = airsupport::crossesNoFlyZone( startnode.origin, dest );
		
		if( !isdefined( noFlyZone ) ) // we didnt hit any noflyzones
		{
			best_index = path_index;
			if( path_index != level.last_start_node_index ) // if possible, we dont want to pickup the previous index
				break;
		}
		path_index = ( path_index + 1 ) % level.heli_startnodes.size;
	}
	
	level.last_start_node_index = best_index;
	return level.heli_startnodes[best_index];
}

function getValidRandomCrashNode( start )
{
	random_leave_node = randomInt( level.heli_crash_paths.size );
	leavenode = level.heli_crash_paths[random_leave_node];
	path_index = ( random_leave_node + 1 ) % level.heli_crash_paths.size;
	
	noFlyZone = airsupport::crossesNoFlyZone( leavenode.origin, start );
	while ( isdefined(noFlyZone) && path_index != random_leave_node )
	{
		leavenode = level.heli_crash_paths[path_index];
		noFlyZone = airsupport::crossesNoFlyZone( leavenode.origin, start );
		path_index = ( path_index + 1 ) % level.heli_crash_paths.size;
	}
	
	// if we dont have a valid position at this point just return
	return level.heli_crash_paths[path_index];
}

function ConfigureTeamPost( owner, isHacked )
{
	chopper = self;
	owner thread watchForEarlyLeave( chopper );
}

function HackedCallbackPost( hacker ) 
{
	heli = self;
	if ( isdefined ( heli.flak_drone ) )
	{
		heli.flak_drone flak_drone::configureteam( heli, true );
	}
	heli.endTime = getTime() + killstreak_bundles::get_hack_timeout() * 1000;
	heli.killstreakEndTime = int( heli.endTime );
}


// spawn helicopter at a start node and monitors it
function heli_think( owner, startnode, heli_team, missilesEnabled, protectLocation, hardpointType, armored, killstreak_id )
{
	heliOrigin = startnode.origin;
	heliAngles = startnode.angles;

	if ( ( hardpointType == "helicopter_comlink" ) || ( hardpointType == "inventory_helicopter_comlink" ) )
	{
		chopperModelFriendly = level.chopperComlinkFriendly;
		chopperModelEnemy = level.chopperComlinkEnemy;
	}
	else
	{
		chopperModelFriendly = level.chopperRegular;
		chopperModelEnemy = level.chopperRegular;
	}

	chopper = spawn_helicopter( owner, heliOrigin, heliAngles, "heli_ai_mp", chopperModelFriendly, (0,0,100), hardpointType, killstreak_id );
	chopper.harpointType = hardpointType;

	chopper killstreaks::configure_team( hardpointType, killstreak_id, owner, "helicopter", undefined, &ConfigureTeamPost );
		
	if ( hardpointType == HELICOPTER_COMLINK || hardpointType == INVENTORY_HELICOPTER_COMLINK )
	{
		chopper killstreak_hacking::enable_hacking( HELICOPTER_COMLINK, undefined, &HackedCallbackPost );
	}

	chopper setEnemyModel(chopperModelEnemy);
	
	chopper thread watchForEMP();
	
	//Delay the SAM turret targeting the chopper until it has had a chance to enter the play space.
	Target_SetTurretAquire( chopper, false );
	chopper thread SAMTurretWatcher();

	if ( ( hardpointType == "helicopter_comlink" ) || ( hardpointType == "inventory_helicopter_comlink" ) )
		chopper.defaultWeapon = GetWeapon( "cobra_20mm_comlink" );
	else
		chopper.defaultWeapon = GetWeapon( "cobra_20mm" );

	chopper.requiredDeathCount = owner.deathCount;
	chopper.chaff_offset = level.chaff_offset["attack"];
	
	minigun_snd_ent = spawn( "script_origin", chopper GetTagOrigin( "tag_flash" ) );
	minigun_snd_ent LinkTo( chopper, "tag_flash", (0,0,0), (0,0,0) );
	chopper.minigun_snd_ent = minigun_snd_ent;
	minigun_snd_ent thread AutoStopSound();
	
	chopper thread heli_existance();
	
	level.chopper = chopper;
	
	//chopper.crashType = "explode";                    //want attack helicopters and chopper gunners to spin out
	
	chopper.reached_dest = false;						// has helicopter reached destination
	if ( armored )
		chopper.maxhealth = level.heli_amored_maxhealth;// max armored health
	else
		chopper.maxhealth = level.heli_maxhealth;		// max health

	chopper.rocketDamageOneShot = level.heli_maxhealth + 1;			// Make it so the heatseeker blows it up in one hit
	chopper.rocketDamageTwoShot = (level.heli_maxhealth / 2) + 1;	// Make it so the heatseeker blows it up in two hit
	
	if ( ( hardpointType == "helicopter_comlink" ) || ( hardpointType == "inventory_helicopter_comlink" ) )
	{
		chopper.numFlares = 0; // no flares, let the flak drone do the work of intercepting the missile
	}
	else if( hardpointType == "helicopter_guard")
	{
		chopper.numFlares = 1;
	}
	else
	{
		chopper.numFlares = 2;										// 2 flares for chopper gunner, 1 for attack/guard
	}
	
	chopper.flareOffset = (0,0,-256);								// offset from vehicle to start the flares
	chopper.waittime = level.heli_dest_wait;						// the time helicopter will stay stationary at destination
	chopper.loopcount = 0; 											// how many times helicopter circled the map
	chopper.evasive = false;										// evasive manuvering
	chopper.health_bulletdamageble = level.heli_armor;				// when damage taken is above this value, helicopter can be damage by bullets to its full amount
	chopper.health_evasive = level.heli_armor;						// when damage taken is above this value, helicopter performs evasive manuvering
	chopper.targeting_delay = level.heli_targeting_delay;			// delay between per targeting scan - in seconds
	chopper.primaryTarget = undefined;								// primary target ( player )
	chopper.secondaryTarget = undefined;							// secondary target ( player )
	chopper.attacker = undefined;									// last player that shot the helicopter
	chopper.missile_ammo = level.heli_missile_max;					// initial missile ammo
	chopper.currentstate = "ok";									// health state
	chopper.lastRocketFireTime = -1;
	
	// helicopter loop threads
	if ( isdefined(protectLocation) ) 
	{
		chopper thread heli_protect( startNode, protectLocation, hardpointType, heli_team );
		chopper clientfield::set( "heli_comlink_bootup_anim", 1 );
	}
	else
	{
		chopper thread heli_fly( startnode, 2.0, hardpointType );		// fly heli to given node and continue on its path
	}
	
	chopper thread heli_damage_monitor( hardpointtype );				// monitors damage
	chopper thread wait_for_killed();									// monitors player kills
	chopper thread heli_health( hardpointType );						// display helicopter's health through smoke/fire
	chopper thread attack_targets( missilesEnabled,  hardpointType  );	// enable attack
	chopper thread heli_targeting( missilesEnabled,  hardpointType  );	// targeting logic
	chopper thread heli_missile_regen();								// regenerates missile ammo
	
	if( hardpointtype != "helicopter_comlink" )
	{
		chopper thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile("crashing", "death");			// fires chaff if needed
		chopper thread create_flare_ent( (0,0,-100) );
	}
}

function AutoStopSound()
{
	self endon( "death" );
	level waittill( "game_ended" );

	self StopLoopSound();
}

function heli_existance()
{
	self waittill( "leaving" );
	
	self spawning::remove_influencers();
}

function create_flare_ent( offset )
{
	self.flare_ent = spawn( "script_model", self GetTagOrigin("tag_origin") );
	self.flare_ent SetModel( "tag_origin" );
	self.flare_ent LinkTo( self, "tag_origin", offset );
}

function heli_missile_regen()
{
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );
	
	for( ;; )
	{
		if( self.missile_ammo >= level.heli_missile_max )
			self waittill( "missile fired" );
		else
		{
			// regenerates faster when damaged
			if ( self.currentstate == "heavy smoke" )
				wait( level.heli_missile_regen_time/4 );
			else if ( self.currentstate == "light smoke" )
				wait( level.heli_missile_regen_time/2 );
			else
				wait( level.heli_missile_regen_time );
		}
		if( self.missile_ammo < level.heli_missile_max )
			self.missile_ammo++;
	}
}

// helicopter targeting logic
function heli_targeting( missilesEnabled,  hardpointType  )
{
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );
	
	// targeting sweep cycle
	for ( ;; )
	{		
		// array of helicopter's targets
		targets = [];
		targetsMissile = [];
		// scan for all players in game
		players = level.players;
		for (i = 0; i < players.size; i++)
		{
			player = players[i];

			if ( self canTargetPlayer_turret( player, hardpointType ) )
			{
				if( isdefined( player ) )
					targets[targets.size] = player;
			}
			if ( missilesEnabled && ( self canTargetPlayer_missile( player,  hardpointType  ) ) )
			{
				if( isdefined( player ) )
					targetsMissile[targetsMissile.size] = player;
			}	
			else
				continue;
		}

		dogs = dogs::dog_manager_get_dogs();
		
		foreach( dog in dogs )
		{
			if ( self canTargetDog_turret( dog ) )
			{
				targets[targets.size] = dog;
			}
			if ( missilesEnabled && (self canTargetDog_missile( dog ) ) )
			{
				targetsMissile[targetsMissile.size] = dog;
			}	
		}
		
		tanks = GetEntArray( "talon", "targetname" );
		
		foreach( tank in tanks )
		{
			if ( self canTargetTank_turret( tank ) )
			{
				targets[targets.size] = tank;
			}
		}
		
		actors = GetActorArray();
		foreach( actor in actors )
		{
			if( isdefined( actor ) && isdefined( actor.isAiClone ) && IsAlive( actor ) )
			{
				if ( self canTargetActor_turret( actor, hardpointType ) )
				{
					targets[targets.size] = actor;
				}
			}
		}		
	
		// no targets found
		if ( targets.size == 0 && targetsMissile.size == 0 )
		{
			self.primaryTarget = undefined;
			self.secondaryTarget = undefined;
			self SetGoalYaw(RandomInt(360));
			wait ( self.targeting_delay );
			continue;
		}
		
		if( targets.size == 1 )
		{
			if( isdefined( targets[0].isAiClone ) )
			{
				killstreaks::update_actor_threat( targets[0] );
			} 
			else if( isdefined( targets[0].type ) && (targets[0].type == "dog" || targets[0].type == "tank_drone"))
			{
				killstreaks::update_dog_threat( targets[0] );
			}
			else
			{
				killstreaks::update_player_threat( targets[0] );
			}
	
			self.primaryTarget = targets[0];	// primary only
			self notify( "primary acquired" );
			self.secondaryTarget = undefined;
		}
		else if ( targets.size > 1 )
			assignPrimaryTargets( targets );
		
		if( targetsMissile.size == 1 )
		{
			if( !isdefined( targetsMissile[0].type ) || targetsMissile[0].type != "dog" || targets[0].type == "tank_drone")
			{
				self killstreaks::update_missile_player_threat( targetsMissile[0] );
			}
			else if( targetsMissile[0].type == "dog" )
			{
				self killstreaks::update_missile_dog_threat( targetsMissile[0] );
			}
	
			self.secondaryTarget = targetsMissile[0];	// primary only
			self notify( "secondary acquired" );
		}
		else if( targetsMissile.size > 1 )
			assignSecondaryTargets( targetsMissile );
					
		wait ( self.targeting_delay );
	
	}	
}

// targetability
function canTargetPlayer_turret( player,  hardpointType  )
{
	canTarget = true;
	
	if ( !isalive( player ) || player.sessionstate != "playing" )
		return false;

	if ( player.ignoreme === true )
		return false;

	if ( player == self.owner )
	{
		self check_owner( hardpointType );
		return false;
	}

	if ( player airsupport::canTargetPlayerWithSpecialty() == false ) 
		return false;

	if ( distance( player.origin, self.origin ) > level.heli_visual_range )
		return false;
	
	if ( !isdefined( player.team ) )
		return false;
	
	if ( level.teamBased && player.team == self.team )
		return false;
	
	if ( player.team == "spectator" )
		return false;
	
	if ( isdefined( player.spawntime ) && ( gettime() - player.spawntime )/1000 <= level.heli_target_spawnprotection )
		return false;
		
	heli_centroid = self.origin + ( 0, 0, -160 );
	heli_forward_norm = anglestoforward( self.angles );
	heli_turret_point = heli_centroid + 144*heli_forward_norm;
	
	visible_amount = player sightConeTrace( heli_turret_point, self);
	
	if ( visible_amount < level.heli_target_recognition )
		return false;	
	
	return canTarget;
}

function canTargetActor_turret( actor, hardpointType )
{
	helicopter = self;
	
	canTarget = true;
	
	if( !isalive( actor ) )
		return actor;

	if( !isdefined( actor.team ) )
		return false;

	if( level.teamBased && actor.team == helicopter.team )
		return false;

	if( DistanceSquared( actor.origin, helicopter.origin ) > ( level.heli_visual_range * level.heli_visual_range ) )
		return false;
	
	heli_centroid = helicopter.origin + ( 0, 0, -160 );
	heli_forward_norm = anglestoforward( helicopter.angles );
	heli_turret_point = heli_centroid + 144 * heli_forward_norm;
	
	visible_amount = actor sightConeTrace( heli_turret_point, helicopter );
	if( visible_amount < level.heli_target_recognition )
		return false;	
	
	return canTarget;
}

function getVerticalTan( startOrigin, endOrigin )
{
	vector = endOrigin - startOrigin;
	
	opposite = startOrigin[2] - endOrigin[2];
	if ( opposite < 0 )
		opposite *= 1;
		
	adjacent = distance2d( startOrigin, endOrigin );
	
	if ( adjacent < 0 )
		adjacent *= 1;
		
	if ( adjacent < 0.01 )
		adjacent = 0.01;
		
	tangent = opposite / adjacent;

	return tangent;
}



// targetability
function canTargetPlayer_missile( player,  hardpointType  )
{
	canTarget = true;
	
	if ( !isalive( player ) || player.sessionstate != "playing" )
		return false;

	if ( player.ignoreme === true )
		return false;

	if ( player == self.owner )
	{
		self check_owner( hardpointType );
		return false;
	}

	if ( player airsupport::canTargetPlayerWithSpecialty() == false ) 
		return false;
		
	if ( distance( player.origin, self.origin ) > level.heli_missile_range )
		return false;
	
	if ( !isdefined( player.team ) )
		return false;
	
	if ( level.teamBased && player.team == self.team )
		return false;
	
	if ( player.team == "spectator" )
		return false;
	
	if ( isdefined( player.spawntime ) && ( gettime() - player.spawntime )/1000 <= level.heli_target_spawnprotection )
		return false;
		
	if ( self target_cone_check( player, level.heli_missile_target_cone ) == false )
		return false;

	heli_centroid = self.origin + ( 0, 0, -160 );
	heli_forward_norm = anglestoforward( self.angles );
	heli_turret_point = heli_centroid + 144*heli_forward_norm;
	
	if (!isdefined(player.lastHit))
		player.lastHit = 0;
		
	player.lastHit = self HeliTurretSightTrace( heli_turret_point, player, player.lastHit );
	if (player.lastHit != 0)
		return false;	
	
	return canTarget;
}

// targetability
function canTargetDog_turret( dog )
{
	canTarget = true;
		
	if ( !isdefined( dog ) )
		return false;
		
	if ( distance( dog.origin, self.origin ) > level.heli_visual_range )
		return false;
	
	if ( !isdefined( dog.team ) )
		return false;
		
	if ( level.teamBased && (dog.team == self.team) )
		return false;
	
	if ( isdefined(dog.script_owner) && self.owner == dog.script_owner )
		return false;
	
	heli_centroid = self.origin + ( 0, 0, -160 );
	heli_forward_norm = anglestoforward( self.angles );
	heli_turret_point = heli_centroid + 144*heli_forward_norm;
	
	if (!isdefined(dog.lastHit))
		dog.lastHit = 0;

	dog.lastHit = self HeliTurretDogTrace( heli_turret_point, dog, dog.lastHit );
	if ( dog.lastHit != 0 )
		return false;

	return canTarget;
}

// targetability
function canTargetDog_missile( dog )
{
	canTarget = true;
		
	if ( !isdefined( dog ) )
		return false;
		
	if ( distance( dog.origin, self.origin ) > level.heli_missile_range )
		return false;
	
	if ( !isdefined( dog.team ) )
		return false;
	
	if ( level.teamBased && (dog.team == self.team) )
		return false;
		
	if ( isdefined(dog.script_owner) && self.owner == dog.script_owner )
		return false;
		
	// TODO	
	//should do a view cone to cut down on processing
		
	heli_centroid = self.origin + ( 0, 0, -160 );
	heli_forward_norm = anglestoforward( self.angles );
	heli_turret_point = heli_centroid + 144*heli_forward_norm;
	
	if (!isdefined(dog.lastHit))
		dog.lastHit = 0;

	dog.lastHit = self HeliTurretDogTrace( heli_turret_point, dog, dog.lastHit );
	if (dog.lastHit != 0)
		return false;

	return canTarget;
}


// targetability
function canTargetTank_turret( tank )
{
	canTarget = true;
		
	if ( !isdefined( tank ) )
		return false;
		
	if ( distance( tank.origin, self.origin ) > level.heli_visual_range )
		return false;
	
	if ( !isdefined( tank.team ) )
		return false;
		
	if ( level.teamBased && (tank.team == self.team) )
		return false;
	
	if ( isdefined(tank.owner) && self.owner == tank.owner )
		return false;

	return canTarget;
}

// assign targets to primary and secondary
function assignPrimaryTargets( targets )
{
	for( idx=0; idx<targets.size; idx++ )
	{
		if( isdefined( targets[idx].isAiClone ) )
		{
			killstreaks::update_actor_threat( targets[idx] );
		}
		else if ( isdefined( targets[idx].type ) && targets[idx].type == "dog" ) 
		{ 
			killstreaks::update_dog_threat( targets[idx] );
		}
		else if ( IsPlayer( targets[idx] ) )
		{
			killstreaks::update_player_threat( targets[idx] );
		}
		else
		{
			killstreaks::update_non_player_threat( targets[idx] );
		}
	}

	assert( targets.size >= 2, "Not enough targets to assign primary and secondary" );
	
	// find primary target, highest threat level
	highest = 0;	
	second_highest = 0;
	primaryTarget = undefined;
	
	// find max and second max, 2n
	for( idx=0; idx<targets.size; idx++ )
	{
		assert( isdefined( targets[idx].threatlevel ), "Target player does not have threat level" );
		if( targets[idx].threatlevel >= highest )
		{
			highest = targets[idx].threatlevel;
			primaryTarget = targets[idx];
		}
	}

	assert( isdefined( primaryTarget ), "Targets exist, but none was assigned as primary" );
	self.primaryTarget = primaryTarget;
	self notify( "primary acquired" );
}

// assign targets to primary and secondary
function assignSecondaryTargets( targets )
{
	for( idx = 0; idx < targets.size; idx++ )
	{
		if( !isdefined( targets[idx].type ) || targets[idx].type != "dog" ) 
		{
			self killstreaks::update_missile_player_threat ( targets[idx] );
		}
		else if( targets[idx].type == "dog" || targets[0].type == "tank_drone") 
		{
			killstreaks::update_missile_dog_threat( targets[idx] );
		}
	}

	assert( targets.size >= 2, "Not enough targets to assign primary and secondary" );
	
	// find primary target, highest threat level
	highest = 0;	
	second_highest = 0;
	primaryTarget = undefined;
	secondaryTarget = undefined;
	
	// find max and second max, 2n
	for( idx=0; idx<targets.size; idx++ )
	{
		assert( isdefined( targets[idx].missilethreatlevel ), "Target player does not have threat level" );
		if( targets[idx].missilethreatlevel >= highest )
		{
			highest = targets[idx].missilethreatlevel;
			secondaryTarget = targets[idx];
		}
	}
		
	assert( isdefined( secondaryTarget ), "1+ targets exist, but none was assigned as secondary" );
	self.secondaryTarget = secondaryTarget;
	self notify( "secondary acquired" );
	
	
	//TODO Maybe missiles do not target the ones on the primary list?	
	//assert( self.secondaryTarget != self.primaryTarget, "Primary and secondary targets are the same" );
}

// resets helicopter's motion values
function heli_reset()
{
	self clearTargetYaw();
	self clearGoalYaw();
	self setspeed( 60, 25 );	
	self setyawspeed( 75, 45, 45 );
	//self setjitterparams( (30, 30, 30), 4, 6 );
	self setmaxpitchroll( 30, 30 );
	self setneargoalnotifydist( 256 );
	self setturningability(0.9);
}

function heli_wait( waittime )
{
	self endon ( "death" );
	self endon ( "crashing" );
	self endon ( "evasive" );

	self thread heli_hover();
	wait( waittime );
	heli_reset();
	
	self notify( "stop hover" );
}

// hover movements
function heli_hover()
{
	// stop hover when anything at all happens
	self endon( "death" );
	self endon( "stop hover" );
	self endon( "evasive" );
	self endon( "leaving" );
	self endon( "crashing" );
	randInt = randomint(360);
	self setgoalyaw( self.angles[1]+randInt );

}

function wait_for_killed()
{
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );
	
	self.bda = 0;
	
	while(1)
	{
		self waittill( "killed", victim );
		
		if ( !isdefined( self.owner ) || !isdefined( victim ) )
			continue;
			
		if ( self.owner == victim ) // killed himself
			continue;
		
		// no kill confirm on team kill.  May want another VO.
		if ( level.teamBased && self.owner.team == victim.team )
			continue;
		
		self thread wait_for_bda_timeout();
	}
}

function wait_for_bda_timeout()
{
	self endon( "killed" );
	
	wait( 2.5 );
	
	if ( !isdefined( self ) )
		return;

	self play_bda_dialog();
}

function play_bda_dialog( )
{
	if (self.bda == 1)
	{
		bdaDialog = "kill1";
	}
	else if (self.bda == 2)
	{
		bdaDialog = "kill2";
	}
	else if (self.bda == 3)
	{
		bdaDialog = "kill3";
	}
	else if (self.bda > 3)
	{
		bdaDialog = "killMultiple";
	}
		
	self killstreaks::play_pilot_dialog_on_owner( bdaDialog, self.killstreakType, self.killstreak_id );
	
	self notify( "bda_dialog", bdaDialog );
	
	self.bda = 0;
}

function heli_hacked_health_update( hacker )
{
	helicopter = self;
	hackedDamageTaken = helicopter.maxhealth - helicopter.hackedHealth;
	assert ( hackedDamageTaken > 0 );
	if ( hackedDamageTaken > helicopter.damageTaken )
	{
		helicopter.damageTaken = hackedDamageTaken;
	}
}

function heli_damage_monitor( hardpointtype )
{
	helicopter = self;
	self endon( "death" );
	self endon( "crashing" );

	self.damageTaken = 0;
	
	last_hit_vo = 0;
	hit_vo_spacing = 6000;
	
	tableHealth = killstreak_bundles::get_max_health( hardpointtype );
	if ( isdefined( tableHealth ) )
	{
		self.maxhealth = tableHealth;
	}

	helicopter.hackedHealthUpdateCallback = &heli_hacked_health_update;
	helicopter.hackedHealth = killstreak_bundles::get_hacked_health( hardpointtype );

	if ( !isdefined( self.attackerData ) )
	{
		self.attackers = [];
		self.attackerData = [];
		self.attackerDamage = [];
		self.flareAttackerDamage = [];
	}
	
	for( ;; )
	{
		// this damage is done to self.health which isnt used to determine the helicopter's health, damageTaken is.
		self waittill( "damage", damage, attacker, direction, point, type, modelName, tagName, partname, weapon, flags, inflictor, chargeLevel );		

		if( !isdefined( attacker ) || !isplayer( attacker ) )
			continue;
		
		heli_friendlyfire = weaponobjects::friendlyFireCheck( self.owner, attacker );
		// skip damage if friendlyfire is disabled
		if( !heli_friendlyfire )
			continue;
			
		if ( !level.hardcoreMode )
		{
			if(	isdefined( self.owner ) && attacker == self.owner )
				continue;
			
			if ( level.teamBased )
				isValidAttacker = (isdefined( attacker.team ) && attacker.team != self.team);
			else
				isValidAttacker = true;
	
			if ( !isValidAttacker )
				continue;
		}		

		self.attacker = attacker;
		
		weapon_damage = killstreak_bundles::get_weapon_damage( hardpointType, self.maxhealth, attacker, weapon, type, damage, flags, chargeLevel );
		
		if ( !isdefined( weapon_damage ) )
		{
			if ( type == "MOD_RIFLE_BULLET" || type == "MOD_PISTOL_BULLET" )
			{
				hasFMJ = attacker HasPerk( "specialty_armorpiercing" );
				
				if ( hasFMJ )
				{
					damage += int( damage * level.cac_armorpiercing_data );
				}
	
				damage *= level.heli_armor_bulletdamage;
			}
			else if( type == "MOD_PROJECTILE" || type == "MOD_PROJECTILE_SPLASH" || type == "MOD_EXPLOSIVE" )
			{
				shouldUpdateDamage = ( weapon.statIndex != level.weaponPistolEnergy.statIndex ) && ( weapon.statIndex != level.weaponSpecialCrossbow.statIndex );
				
				if ( shouldUpdateDamage )
				{
					switch ( weapon.name )
					{
					case "tow_turret":
						if( isdefined( self.rocketDamageTwoShot ) )
						{
							// 2 shot kill
							damage = self.rocketDamageTwoShot;						
						}
						else if( isdefined( self.rocketDamageOneShot ) )
						{
							// 1 shot kill
							damage = self.rocketDamageOneShot;
						}
						break;				
					default:
						if( isdefined( self.rocketDamageOneShot ) )
						{
							// 1 shot kill
							damage = self.rocketDamageOneShot;
						}					
						break;
					}
				}
			}
			
			weapon_damage = damage;
		}
		
		if ( weapon_damage > 0 )
			self challenges::trackAssists( attacker, weapon_damage, false );
		
		self.damageTaken += weapon_damage;
		
		playerControlled = false;

		if( self.damageTaken > self.maxhealth && !isdefined(self.xpGiven) )
		{
			self.xpGiven = true;

			switch( hardpointtype )
			{
				case "helicopter_gunner":
					playerControlled = true;
					event = "destroyed_vtol_mothership";
					break;
				case "helicopter_comlink":
				case "inventory_helicopter_comlink":
					event = "destroyed_helicopter_comlink";
					if ( self.leaving !== true )
					{
						self killstreaks::play_destroyed_dialog_on_owner( self.killstreakType, self.killstreak_id );
					}
					break;
				case "supply_drop":
				case "supply_drop_combat_robot":
					if( isdefined( helicopter.killstreakWeaponName ) )
					{
						switch( helicopter.killstreakWeaponName )
						{
						case "inventory_ai_tank_drop":
						case "ai_tank_drop":
						case "inventory_ai_tank_marker":
						case "ai_tank_drop_marker":
						case "ai_tank_marker":
							{
								event = "destroyed_helicopter_agr_drop";
							}
							break;
						case "combat_robot_drop":
						case "inventory_combat_robot_drop":
						case "combat_robot_marker":
						case "inventory_combat_robot_marker":
							{
								event = "destroyed_helicopter_giunit_drop";	
							}
							break;
						default:
							{
								event = "destroyed_helicopter_supply_drop";
							}
							break;
						}
					}
					else
					{
						event = "destroyed_helicopter_supply_drop";
					}
					break;
			}
			
			if ( isdefined( event ) ) 
			{
				if( isdefined( self.owner ) && self.owner util::IsEnemyPlayer( attacker ) )
				{
					challenges::destroyedHelicopter( attacker, weapon, type, false );
					challenges::destroyedAircraft( attacker, weapon, playerControlled );
					scoreevents::processScoreEvent( event, attacker, self.owner, weapon );
					attacker challenges::addFlySwatterStat( weapon, self );
					if ( playerControlled == true )
					{
						attacker challenges::destroyedPlayerControlledAircraft();
					}
					if ( hardpointtype == "helicopter_player_gunner" )
					{
						attacker AddWeaponStat( weapon, "destroyed_controlled_killstreak", 1 );
					}
				}
				else
				{
					//Destroyed Friendly Killstreak 
				}
			}
			
			// do give stats to killstreak weapons
			// we need the kill stat so that we know how many kills the weapon has gotten (even on helicopters) for challenges
			// we need the destroyed stat for the same reason as the kill stat and these have different challenges associated
			//attacker _properks::destroyedKillstreak();
			
			weaponStatName = "destroyed";
			switch( weapon.name )
			{
			// SAM Turrets keep the kills stat for shooting things down because we used destroyed for when you destroy a SAM Turret
			case "auto_tow":
			case "tow_turret":
			case "tow_turret_drop":
				weaponStatName = "kills";
				break;
			}
			attacker AddWeaponStat( weapon, weaponStatName, 1 );
			
			notifyString = undefined;
			killstreakReference = undefined;
			switch( hardpointtype )
			{
			case "helicopter_gunner":
				killstreakReference = "killstreak_helicopter_gunner";
				break;
			case "helicopter_player_gunner":
				killstreakReference = "killstreak_helicopter_player_gunner";
				break;
			case "helicopter_player_firstperson":
				killstreakReference = "killstreak_helicopter_player_firstperson";
				break;
			case "helicopter_comlink":
			case "inventory_helicopter_comlink":
			case "helicopter":
			case "helicopter_x2":
				notifyString = &"KILLSTREAK_DESTROYED_HELICOPTER";
				killstreakReference = "killstreak_helicopter_comlink";
				break;
			case "supply_drop":
				notifyString = &"KILLSTREAK_DESTROYED_SUPPLY_DROP_DEPLOY_SHIP";
				killstreakReference = "killstreak_supply_drop";
				break;
			case "helicopter_guard":
				killstreakReference = "killstreak_helicopter_guard";
			}
			
			// increment the destroyed stat for this, we aren't using the weaponStatName variable from above because it could be "kills" and we don't want that
			if( isdefined( killstreakReference ) )
			{
				level.globalKillstreaksDestroyed++;
				attacker AddWeaponStat( GetWeapon( hardpointtype ), "destroyed", 1 );
			}

			if( hardpointtype == "helicopter_player_gunner" )
			{
				self.owner SendKillstreakDamageEvent( 600 );
			}
			
			if ( isdefined( notifyString ) )
			{
				LUINotifyEvent( &"player_callout", 2, notifyString, attacker.entnum );
			}
			
			if ( isdefined( self.attackers ) )
			{
				for ( j = 0; j < self.attackers.size; j++ )
				{
					player = self.attackers[j];
					
					if ( !isdefined( player ) )
						continue;
					
					if ( player == attacker )
						continue;
					
					flare_done = self.flareAttackerDamage[player.clientId];
					if ( isdefined ( flare_done ) && flare_done == true ) 
					{
						scoreevents::processScoreEvent( "aircraft_flare_assist", player );
					}
					else
					{
						damage_done = self.attackerDamage[player.clientId];
						player thread processCopterAssist( self, damage_done);
					}
				}
				self.attackers = [];
			}
			attacker notify( "destroyed_helicopter" );
			
			if( Target_IsTarget( self ) )
			{
				Target_remove( self ); 
			}
		}
		else if ( isdefined( self.owner ) && IsPlayer( self.owner ) )
		{
			if ( last_hit_vo + hit_vo_spacing < GetTime() )
			{
				if ( type == "MOD_PROJECTILE" || RandomIntRange(0,3) == 0 )
				{
					// TODO CDC - change to new pilot dialog
					//self.owner PlayLocalSound(level.heli_vo[self.team]["hit"]);
					last_hit_vo = GetTime();
				}
			}
		}
		
		if( ( hardpointtype == "helicopter_comlink" ) || ( hardpointtype == "inventory_helicopter_comlink" ) )
		{
			self thread heli_active_camo_damage_update( damage );
		}
	}
}

function init_active_camo()
{
	heli = self;
	heli.active_camo_supported = true;
	heli.active_camo_damage = 0;
	heli.active_camo_disabled = false;
	heli.camo_state = HELICOPTER_CAMO_STATE_OFF;
	heli_set_active_camo_state( HELICOPTER_CAMO_STATE_ON );
	
	if( isdefined( heli.flak_drone ) )
	{
		heli.flak_drone flak_drone::SetCamoState( HELICOPTER_CAMO_STATE_ON );
	}
}

function heli_set_active_camo_state( state )
{
	heli = self;
	
	if( !isdefined( heli.active_camo_supported ) )
	{
		return;
	}
	
	if( state == HELICOPTER_CAMO_STATE_OFF )
	{
		//Target_Set( heli, heli.target_offset );
		heli clientfield::set( "toggle_lights", CF_TOGGLE_LIGHTS_OFF );
		if( heli.camo_state == HELICOPTER_CAMO_STATE_ON )
			heli playsound ("veh_hind_cloak_off");
		heli.camo_state = HELICOPTER_CAMO_STATE_OFF;
		heli.camo_state_switch_time = gettime();
	}
	else if( state == HELICOPTER_CAMO_STATE_ON )
	{
		if( heli.active_camo_disabled )
		{
			return;
		}
		
		//if( Target_IsTarget( heli ) )
		//{
			//Target_Remove( heli );	
		//}
		
		heli clientfield::set( "toggle_lights", CF_TOGGLE_LIGHTS_ON );
		
		if( heli.camo_state == HELICOPTER_CAMO_STATE_OFF )
			heli playsound ("veh_hind_cloak_on");
		heli.camo_state = HELICOPTER_CAMO_STATE_ON;
		heli.camo_state_switch_time = gettime();
		
		if ( isdefined( heli.owner ) )
		{
			if ( isdefined( heli.play_camo_dialog ) && heli.play_camo_dialog )
			{
				heli killstreaks::play_pilot_dialog_on_owner( "activateCounter", "helicopter_comlink", self.killstreak_id );
				// Only play the cloak line once
				heli.play_camo_dialog = false;	
			}
			else if ( !isdefined( heli.play_camo_dialog ) )
			{
				// Don't play camo dialog when initializing the copter
				heli.play_camo_dialog = true;
			}
		}
	}
	else if( state == HELICOPTER_CAMO_STATE_FLICKER )
	{
		heli clientfield::set( "toggle_lights", CF_TOGGLE_LIGHTS_OFF );
	}
	
	if( isdefined( heli.flak_drone ) )
	{
		heli.flak_drone flak_drone::SetCamoState( state );
	}
	
	heli clientfield::set( "active_camo", state );
}

function heli_active_camo_damage_update( damage )
{
	self endon( "death" );
	self endon( "crashing" );
	
	heli = self;
	
	heli.active_camo_damage += damage;
	
	if( heli.active_camo_damage > HELICOPTER_CAMO_DAMAGE_LIMIT )
	{
		heli.active_camo_disabled = true;
		heli thread heli_active_camo_damage_disable();
	}
	else
	{
		heli heli_set_active_camo_state( HELICOPTER_CAMO_STATE_FLICKER );
		wait( HELICOPTER_CAMO_FLICKER_DURATION );
		heli heli_set_active_camo_state( HELICOPTER_CAMO_STATE_ON );
	}
}

function heli_active_camo_damage_disable()
{
	self endon( "death" );
	self endon( "crashing" );
	
	heli = self;
	heli notify( "heli_active_camo_damage_disable" );
	heli endon( "heli_active_camo_damage_disable" );
	
	heli heli_set_active_camo_state( HELICOPTER_CAMO_STATE_OFF );
	
	wait( HELICOPTER_CAMO_DAMAGE_DURATION );
	
	heli.active_camo_damage = 0;
	heli.active_camo_disabled = false;
	heli heli_set_active_camo_state( HELICOPTER_CAMO_STATE_ON );
}

function heli_health( hardpointType, playerNotify )
{
	self endon( "death" );
	self endon( "crashing" );
	
	self.currentstate = "ok";
	self.laststate = "ok";
	self setdamagestage( 3 );
	damageState = 3;
	
	tableHealth = killstreak_bundles::get_max_health( hardpointType );
	
	if ( isdefined( tableHealth ) )
	{
		self.maxhealth = tableHealth;
	}

	for ( ;; )
	{
		self waittill( "damage", damage, attacker, direction, point, type, modelName, tagName, partname, weapon );		
		WAIT_SERVER_FRAME;
		
		if( self.damageTaken > self.maxhealth )
		{
			damageState = 0;
			self setDamageStage( damageState );

			self heli_set_active_camo_state( HELICOPTER_CAMO_STATE_OFF );
			
			self thread heli_crash( hardpointType, self.owner, playerNotify );
		}		
		else if ( self.damageTaken >= (self.maxhealth * 0.66) && damageState >= 2 )
		{
			self killstreaks::play_pilot_dialog_on_owner( "damaged", "helicopter_comlink", self.killstreak_id );
			
			//self setdamagestage( 1 );
			if ( isdefined( self.vehicletype ) && self.vehicletype == "heli_player_gunner_mp" )
			{
				PlayFXOnTag( level.chopper_fx["damage"]["heavy_smoke"], self, "tag_origin");
			}
			else
			{
				PlayFXOnTag( level.chopper_fx["damage"]["heavy_smoke"], self, "tag_main_rotor");				
			}
			damageState = 1;
			self.currentstate = "heavy smoke";
			self.evasive = true;
			self notify("damage state");
		}
		else if ( self.damageTaken >= (self.maxhealth * 0.33) && damageState == 3 )
		{
			//self setdamagestage( 2 );
			if ( isdefined( self.vehicletype ) && self.vehicletype == "heli_player_gunner_mp" )
			{
				PlayFXOnTag( level.chopper_fx["damage"]["light_smoke"], self, "tag_origin");
			}
			else
			{
				PlayFXOnTag( level.chopper_fx["damage"]["light_smoke"], self, "tag_main_rotor");			
			}
			damageState = 2;
			self.currentstate = "light smoke";
			self notify("damage state");
		}
	}
}

// evasive manuvering - helicopter circles the map for awhile then returns to path
function heli_evasive( hardpointType )
{
	// only one instance allowed
	self notify( "evasive" );
	
	self.evasive = true;
	
	// set helicopter path to circle the map level.heli_loopmax number of times
	loop_startnode = level.heli_loop_paths[0];
	
	gunnerPathFound = true;
	if ( hardpointType == "helicopter_gunner" )
	{
		gunnerPathFound = false;
		for ( i = 0 ; i < level.heli_loop_paths.size ; i++ )
		{
			if ( isdefined( level.heli_loop_paths[i].isGunnerPath ) && level.heli_loop_paths[i].isGunnerPath )
			{
				loop_startnode = level.heli_loop_paths[i];
				gunnerPathFound = true;
				break;
			}
		}
	}
	assert( gunnerPathFound, "No chopper gunner loop paths found in map" );
	
	startwait = 2;
	if ( isdefined( self.doNotStop ) && self.doNotStop )
		startwait = 0;
	
	self thread heli_fly( loop_startnode, startwait, hardpointType );
}

function notify_player( player, playerNotify, delay )
{
	if ( !isdefined(player) )
		return;
	
	if ( !isdefined(playerNotify) )
		return;

	player endon( "disconnect" );
	player endon( playerNotify );
	
	wait (delay);
	
	player notify( playerNotify );
}

function play_going_down_vo( delay )
{
	self.owner endon( "disconnect" );
	self endon( "death" );
	
	wait (delay);
}

// attach helicopter on crash path
function heli_crash( hardpointType, player, playerNotify )
{
	self endon( "death" );
	self notify( "crashing" );

	self spawning::remove_influencers();
	
	self stoploopsound(0);
	if( isdefined( self.minigun_snd_ent ) )
	{
		self.minigun_snd_ent StopLoopSound();
	}
	if( isdefined( self.alarm_snd_ent ) )
	{
	    self.alarm_snd_ent StopLoopSound();
	}

	//TODO : Play crash alert vo CDC
	
	// these types are for the chopper and player controlled heli
	crashTypes = [];
	crashTypes[0] = "crashOnPath";
	crashTypes[1] = "spinOut";
	
	crashType = crashTypes[randomInt(2)];

	// ai chopper should just explode
	if ( isdefined( self.crashType ) ) 
		crashType = self.crashType;

	switch (crashType)
	{
		case "explode":
		{
			thread notify_player( player, playerNotify, 0 );
			self thread heli_explode();
		}
		break;
		case "crashOnPath":
		{
			if ( isdefined( player ) )
				self thread play_going_down_vo( 0.5 );

			thread notify_player( player, playerNotify, 4 );
			self clear_client_flags();
			self thread crashOnNearestCrashPath( hardpointType );
		}
		break;
		case "spinOut":
		{
			if ( isdefined( player ) )
				self thread play_going_down_vo( 0.5 );
			thread notify_player( player, playerNotify, 4 );
			self clear_client_flags();

			heli_reset();

			heli_speed = 30+randomInt(50);
			heli_accel = 10+randomInt(25);
			
			// helicopter leaves randomly towards one of the leave origins
			leavenode = getValidRandomCrashNode( self.origin );
			// movement change due to damage
			self setspeed( heli_speed, heli_accel );	
			self set_goal_pos( (leavenode.origin), 0 );
			
			rateOfSpin = 45 + randomint(90);
			
			thread heli_secondary_explosions();
			
			// helicopter losing control and spins
			self thread heli_spin( rateOfSpin );
			//TODO : pilot call in VO

	
			self util::waittill_any_timeout( RandomIntRange(4, 6), "near_goal" ); //self waittillmatch( "goal" );
			
			if ( isdefined( player ) && isdefined( playerNotify ) )
				player notify( playerNotify ); // make sure
			self thread heli_explode();
		}
		break;
	}	

	self thread explodeOnContact( hardpointtype );
	
	time = randomIntRange(4, 6);
	self thread waitThenExplode( time );
}

function damagedRotorFX()
{
	self endon ( "death" );
	self SetRotorSpeed( 0.6 );
}

function waitThenExplode( time )
{
	self endon( "death" );
	
	wait( time );	
	
	self thread heli_explode();
}

function crashOnNearestCrashPath( hardpointType )
{	
	crashPathDistance = -1;
	crashPath = level.heli_crash_paths[0];
	for ( i = 0; i < level.heli_crash_paths.size; i++ )
	{
		currentDistance = distance(self.origin, level.heli_crash_paths[i].origin);
		if ( crashPathDistance == -1 || crashPathDistance > currentDistance )
		{
			crashPathDistance = currentDistance;
			crashPath = level.heli_crash_paths[i];
		}
	}
	
	heli_speed = 30+randomInt(50);
	heli_accel = 10+randomInt(25);
	
	// movement change due to damage
	self setspeed( heli_speed, heli_accel );	
			
	thread heli_secondary_explosions();

	// fly to crash path
	self thread heli_fly( crashPath, 0, hardpointType );
	
	rateOfSpin = 45 + randomint(90);
	
	// helicopter losing control and spins
	self thread heli_spin( rateOfSpin );
	
	// wait until helicopter is on the crash path
	self waittill ( "path start" );

	
	self waittill( "destination reached" );
	self thread heli_explode();
}

//This is a temporary solution for playing fx while we are switching to new models with new tag naming conventions.
function CheckHelicopterTag( tagName )
{
	if( isdefined( self.model ) )
	{
		if( self.model == "veh_t7_drone_hunter" )
		{
			switch( tagName )
			{
				case "tag_engine_left":
					return "tag_fx_exhaust2";
				case "tag_engine_right":
					return "tag_fx_exhaust1";
				case "tail_rotor_jnt":
					return "tag_fx_tail";
				default:
					break;
			}
		}
	}
	
	return tagName;
}

function heli_secondary_explosions()
{
	self endon( "death" );
	
	playFxOnTag( level.chopper_fx["explode"]["large"], self, self CheckHelicopterTag( "tag_engine_left" ) );
//	self playSound ( level.heli_sound["hitsecondary"] );
	self playSound ( level.heli_sound["hit"] );

	// form smoke trails on tail after explosion
	if ( isdefined( self.vehicletype ) && self.vehicletype == "heli_player_gunner_mp" )
	{
		self thread trail_fx( level.chopper_fx["smoke"]["trail"],  self CheckHelicopterTag( "tag_engine_right" ), "stop tail smoke" );
	}
	else
	{
		self thread trail_fx( level.chopper_fx["smoke"]["trail"],  self CheckHelicopterTag( "tail_rotor_jnt" ), "stop tail smoke" );		
	}
		
	self setdamagestage( 0 );
	// form fire smoke trails on body after explosion
	self thread trail_fx( level.chopper_fx["fire"]["trail"]["large"],  self CheckHelicopterTag( "tag_engine_left" ), "stop body fire" );
	
	wait ( 3.0 );

	if ( !isdefined( self ) )
		return;
         
	playFxOnTag( level.chopper_fx["explode"]["large"], self, self CheckHelicopterTag( "tag_engine_left" ) );
	self playSound ( level.heli_sound["hitsecondary"] );
}

// self spin at one rev per 2 sec
function heli_spin( speed )
{
	self endon( "death" );
	
	// tail explosion that caused the spinning
//	playfxontag( level.chopper_fx["explode"]["medium"], self, "tail_rotor_jnt" );
	// play hit sound immediately so players know they got it
	
	// play heli crashing spinning sound
	self thread spinSoundShortly();
	
	// spins until death
	self setyawspeed( speed, speed / 3 , speed / 3 );
	while ( isdefined( self ) )
	{
		self settargetyaw( self.angles[1]+(speed*0.9) );
		wait ( 1 );
	}
}

function spinSoundShortly()
{
	self endon( "death" );
	
	wait .25;
	
	self stopLoopSound();
	wait .05;
	self playLoopSound( level.heli_sound["spinloop"] );
	wait .05;
	self playSound( level.heli_sound["spinstart"] );
}

function trail_fx( trail_fx, trail_tag, stop_notify )
{
	playfxontag( trail_fx, self, trail_tag );
}

function destroyHelicopter()
{
	team = self.originalteam;

	if ( Target_IsTarget(self) )
		Target_remove( self ); 
		
	self spawning::remove_influencers();

	if( isdefined( self.interior_model ) )
	{
		self.interior_model Delete();
		self.interior_model = undefined;
	}
	if( isdefined( self.minigun_snd_ent ) )
	{
		self.minigun_snd_ent StopLoopSound();
		self.minigun_snd_ent Delete();
		self.minigun_snd_ent = undefined;
	}
	if( isdefined( self.alarm_snd_ent ) )
	{
	    self.alarm_snd_ent Delete();
	    self.alarm_snd_ent = undefined;
	}
	if ( isdefined( self.flare_ent ) )
	{
		self.flare_ent Delete();
		self.flare_ent = undefined;
	}
	
	killstreakrules::killstreakStop( self.hardpointType, team, self.killstreak_id );
	
	self delete();
}

// crash explosion
function heli_explode()
{	
	self endon( "death" );
	
	forward = ( self.origin + ( 0, 0, 100 ) ) - self.origin;
	if( isdefined(self.helitype) && self.helitype == "littlebird" )
	{		
		playfx( level.chopper_fx["explode"]["guard"], self.origin, forward );
	}
	else if ( isdefined( self.vehicletype ) && self.vehicletype == "heli_player_gunner_mp" )
	{
		playfx( level.chopper_fx["explode"]["gunner"], self.origin, forward );
	}
	else
	{
		playfx( level.chopper_fx["explode"]["death"], self.origin, forward );
	}
	
	// play heli explosion sound
	self PlaySound ( level.heli_sound["crash"] );
	
	wait( 0.1 );
	
	assert( isdefined( self.destroyFunc ) );
	self [[self.destroyFunc]]();
}

function clear_client_flags()
{
	self clientfield::set( "heli_warn_fired", 0 );
	self clientfield::set( "heli_warn_targeted", 0 );
	self clientfield::set( "heli_warn_locked", 0 );
}

// helicopter leaving parameter, can not be damaged while leaving
function heli_leave()
{
	self notify( "destintation reached" );
	self notify( "leaving" );
	
	hardpointType = self.hardpointType;
	
	self.leaving = true;
	
	if( !IS_TRUE( self.detroyScoreEventGiven ) )
	{
		self killstreaks::play_pilot_dialog_on_owner( "timeout", hardpointType );
		self killstreaks::play_taacom_dialog_response_on_owner( "timeoutConfirmed", hardpointType );
	}

	// helicopter leaves randomly towards one of the leave origins
	leavenode = getValidRandomLeaveNode( self.origin );

	heli_reset();
	self ClearLookAtEnt();
	exitAngles = VectorToAngles(leavenode.origin - self.origin);
	self SetGoalYaw( exitAngles[1] );
	wait ( 1.5 );

	if ( !isdefined( self ) )
	{
		return;
	}

	self setspeed( 180, 65 );
	

	self set_goal_pos( self.origin + ( leavenode.origin - self.origin ) / 2 + ( 0, 0, HELI_ENTRANCE_Z_HELP ), false );
	self waittill( "near_goal" );
	if( isdefined( self ) )
	{
		self set_goal_pos( leavenode.origin, true );
		self waittillmatch( "goal" );
		if( isdefined( self ) )
		{
			self stoploopsound(1);
			self util::death_notify_wrapper();
			if( isdefined( self.alarm_snd_ent ) )
			{
			    self.alarm_snd_ent StopLoopSound();
			    self.alarm_snd_ent Delete();
			    self.alarm_snd_ent = undefined;
			}
		
			assert( isdefined( self.destroyFunc ) );
			self [[self.destroyFunc]]();
		}
	}
}
	
// flys helicopter from given start node to a destination on its path
function heli_fly( currentnode, startwait, hardpointType )
{
	self endon( "death" );
	self endon( "leaving" );
	
	// only one thread instance allowed
	self notify( "flying" );
	self endon( "flying" );
	
	// if owner switches teams, helicopter should leave
	self endon( "abandoned" );
	
	self.reached_dest = false;
	heli_reset();
	
	pos = self.origin;
	wait( startwait );

	while ( isdefined( currentnode.target ) )
	{	
		nextnode = getent( currentnode.target, "targetname" );
		assert( isdefined( nextnode ), "Next node in path is undefined, but has targetname" );
		
		// offsetted 
		pos = nextnode.origin+(0,0,30); 
		
		// motion change via node
		if( isdefined( currentnode.script_airspeed ) && isdefined( currentnode.script_accel ) )
		{
			heli_speed = currentnode.script_airspeed;
			heli_accel = currentnode.script_accel;
		}
		else
		{
			heli_speed = 30+randomInt(20);
			heli_accel = 10+randomInt(5);
		}
		
		if ( isdefined( self.pathSpeedScale ) )
		{
			heli_speed *= self.pathSpeedScale;
			heli_accel *= self.pathSpeedScale;
		}
		
		// fly nonstop until final destination
		if ( !isdefined( nextnode.target ) )
			stop = 1;
		else
			stop = 0;
			
		// if in damaged state, do not stop at any node other than destination
		if( self.currentstate == "heavy smoke" || self.currentstate == "light smoke" )	
		{
			// movement change due to damage
			self setspeed( heli_speed, heli_accel );	
			self set_goal_pos( (pos), stop );
			
			self waittill( "near_goal" ); //self waittillmatch( "goal" );
			self notify( "path start" );
		}
		else
		{
			// if the node has helicopter stop time value, we stop
			if( isdefined( nextnode.script_delay ) && !isdefined( self.doNotStop ) ) 
				stop = 1;
	
			self setspeed( heli_speed, heli_accel );	
			self set_goal_pos( (pos), stop );
			
			if ( !isdefined( nextnode.script_delay ) || isdefined( self.doNotStop ) )
			{
				self waittill( "near_goal" ); //self waittillmatch( "goal" );
				self notify( "path start" );
			}
			else
			{
				// post beta addition --- (
				self setgoalyaw( nextnode.angles[1] );
				// post beta addition --- )
				
				self waittillmatch( "goal" );				
				heli_wait( nextnode.script_delay );
			}
		}
		
		// increment loop count when helicopter is circling the map
		for( index = 0; index < level.heli_loop_paths.size; index++ )
		{
			if ( level.heli_loop_paths[index].origin == nextnode.origin )
				self.loopcount++;
		}
		if( self.loopcount >= level.heli_loopmax )
		{
			self thread heli_leave();
			return;
		}
		currentnode = nextnode;
	}
	
	self setgoalyaw( currentnode.angles[1] );
	self.reached_dest = true;	// sets flag true for helicopter circling the map
	self notify ( "destination reached" );
	// wait at destination
	if ( isdefined( self.waittime ) && self.waittime > 0 )
		heli_wait( self.waittime );
	
	// if still alive, switch to evasive manuvering
	if( isdefined( self ) )
		self thread heli_evasive( hardpointType );
}

function heli_random_point_in_radius( protectDest, nodeHeight )
{
	min_distance = Int(level.heli_protect_radius * .2);
	direction = randomintrange(0,360);
	distance = randomintrange(min_distance, level.heli_protect_radius);

	x = cos(direction);
	y = sin(direction);
	x = x * distance;
	y = y * distance;

	return (protectDest[0] + x, protectDest[1] + y, nodeHeight);
}

function heli_get_protect_spot(protectDest, nodeHeight)
{
	protect_spot = heli_random_point_in_radius( protectDest, nodeHeight );
	
	tries = 10;
	noFlyZone = airsupport::crossesNoFlyZone( protectDest, protect_spot );
	while( tries != 0 && isdefined( noFlyZone ) )
	{
		protect_spot = heli_random_point_in_radius( protectDest, nodeHeight );
		tries--;
		noFlyZone = airsupport::crossesNoFlyZone( protectDest, protect_spot );
	}
	
	noFlyZoneHeight = airsupport::getNoFlyZoneHeightCrossed( protectDest, protect_spot, nodeHeight );
	return ( protect_spot[0], protect_spot[1], noFlyZoneHeight );
}

function wait_or_waittill( time, msg1, msg2, msg3 )
{
	self endon( msg1 ); 
	self endon( msg2 );
	self endon( msg3 );
	wait( time ); 
	return true;
}

function set_heli_speed_normal()
{
	self setmaxpitchroll( 30, 30 );
	heli_speed = 30+randomInt(20);
	heli_accel = 10+randomInt(5);
	self setspeed( heli_speed, heli_accel );	
	self setyawspeed( 75, 45, 45 );
}

function set_heli_speed_evasive()
{
	self setmaxpitchroll( 30, 90 );
	heli_speed = 50+randomInt(20);
	heli_accel = 30+randomInt(5);
	self setspeed( heli_speed, heli_accel );	
	self setyawspeed( 100, 75, 75 );
}

function set_heli_speed_hover()
{
	self setmaxpitchroll( 0, 90 );
	self setspeed( 20, 10 );	
	self setyawspeed( 55, 25, 25 );
}


function is_targeted()
{
	if ( isdefined(self.locking_on) && self.locking_on )
		return true;

	if ( isdefined(self.locked_on) && self.locked_on )
		return true;

	if ( isdefined(self.locking_on_hacking) && self.locking_on_hacking )
		return true;

	return false;
}

function heli_mobilespawn( protectDest )
{
	self endon( "death" );
	
	self notify( "flying" );
	self endon( "flying" );
	
	self endon( "abandoned" );
	
	IPrintLnBold( "PROTECT ORIGIN: ("+protectDest[0]+","+protectDest[1]+","+protectDest[2]+")\n" );
	
	heli_reset();
	
	self SetHoverParams( 50, 100, 50 );
	
	wait( 2 );
	
	set_heli_speed_normal();
	
	self set_goal_pos( protectDest, 1 );
	
	self waittill( "near_goal" );
	
	set_heli_speed_hover();
}

// flys helicopter from given start node to a destination on its path
function heli_protect( startNode, protectDest, hardpointType, heli_team )
{
	self endon( "death" );
		
	// only one thread instance allowed
	self notify( "flying" );
	self endon( "flying" );
	
	// if owner switches teams, helicopter should leave
	self endon( "abandoned" );
	
	self.reached_dest = false;
	heli_reset();

	self SetHoverParams( 50, 100, 50);
	
	wait( 2 );
	
	currentDest = protectDest;
	
	nodeHeight = protectDest[2];
	
	nextnode = startNode;
	
	heightOffset = 0;
	if ( heli_team == "axis" )
	{
		heightOffset = 400;
	}
	
	protectDest = ( protectDest[0], protectDest[1], nodeHeight );
	noFlyZoneHeight = airsupport::getNoFlyZoneHeight( protectDest );
	protectDest = ( protectDest[0], protectDest[1], noFlyZoneHeight + heightOffset );
	currentDest = protectDest;
	startTime = gettime();
	self.endTime = startTime + ( level.heli_protect_time * 1000 );
	self.killstreakEndTime = int( self.endTime );
	
	self SetSpeed( 150, 80 );
	
	self set_goal_pos( self.origin + ( currentDest - self.origin ) / 3 + ( 0, 0, HELI_ENTRANCE_Z_HELP ), false );
	self waittill( "near_goal" );
	
	heli_speed = 30+randomInt(20);
	heli_accel = 10+randomInt(5);

	self thread updateTargetYaw();

	mapEnter = true;
	
	while ( getTime() < self.endTime )
	{	
		stop = 1;
		
		if( !mapEnter )
		{
			self updateSpeed();			
		}
		else
		{
			mapEnter = false;	
		}
		
		// movement change due to damage
		self set_goal_pos( (currentDest), stop );
		
		self thread updateSpeedOnLock();
		self util::waittill_any( "near_goal", "locking on", "locking on hacking" );
		hostmigration::waitTillHostMigrationDone();
		self notify( "path start" );
			
		if ( !self is_targeted() )
		{
			
			waittillframeend;
			
			time = level.heli_protect_pos_time;
			
			if ( self.evasive == true )
			{
				time = 2.0;
			}
			
			set_heli_speed_hover();
			
			wait_or_waittill ( time, "locking on", "locking on hacking", "damage state" );
		}
		else
		{
			 wait 2;
		}
		
		prevDest = currentDest;
		currentDest = heli_get_protect_spot(protectDest, nodeHeight);
		noFlyZoneHeight = airsupport::getNoFlyZoneHeight( currentDest );
		currentDest = ( currentDest[0], currentDest[1], noFlyZoneHeight + heightOffset );
		noFlyZones = airsupport::crossesNoFlyZones( prevDest, currentDest );
		if ( isdefined( noFlyZones ) && ( noFlyZones.size > 0 ) )
		{
			currentDest = prevDest;
		}
	}
	
	self heli_set_active_camo_state( HELICOPTER_CAMO_STATE_ON );
	self thread heli_leave();
}

function updateSpeedOnLock()
{
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );

	self util::waittill_any( "near_goal", "locking on", "locking on hacking" );

	self updateSpeed();
}

function updateSpeed()
{
	if ( self is_targeted() || ( isdefined(self.evasive) && self.evasive ) )
	{
		set_heli_speed_evasive();		
	}
	else
	{
		set_heli_speed_normal();		
	}
}

function updateTargetYaw()
{
	self notify( "endTargetYawUpdate" );
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );
	
	self endon( "endTargetYawUpdate" );
	
	for(;;)
	{
		if ( isdefined( self.primaryTarget ) )
		{
			yaw = math::get_2d_yaw( self.origin, self.primaryTarget.origin );
			self setTargetYaw( yaw );
		}
	
		wait( 1 );
	}
}
		
function fire_missile( sMissileType, iShots, eTarget )
{
	if ( !isdefined( iShots ) )
		iShots = 1;
	assert( self.health > 0 );
	
	weapon = undefined;
	weaponShootTime = undefined;	
	tags = [];
	switch( sMissileType )
	{
		case "ffar":
			weapon = GetWeapon( "hind_FFAR" );
			tags[ 0 ] = "tag_store_r_2";
			break;
		default:
			assertMsg( "Invalid missile type specified. Must be ffar" );
			break;
	}
	assert( isdefined( weapon ) );
	assert( tags.size > 0 );
	
	weaponShootTime = weapon.fireTime;
	assert( isdefined( weaponShootTime ) );
	
	self setVehWeapon( weapon );
	nextMissileTag = -1;
	for( i = 0 ; i < iShots ; i++ ) // I don't believe iShots > 1 is properly supported; we don't set the weapon each time
	{
		nextMissileTag++;
		if ( nextMissileTag >= tags.size )
			nextMissileTag = 0;
		
		eMissile = self fireWeapon( 0, eTarget );
		eMissile.killcament = self;
		self.lastRocketFireTime = gettime();
		
		if ( i < iShots - 1 )
			wait weaponShootTime;
	}
	// avoid calling setVehWeapon again this frame or the client doesn't hear about the original weapon change
}

function check_owner( hardpointType )
{
	if ( !isdefined( self.owner ) || !isdefined( self.owner.team ) || self.owner.team != self.team )
	{
		self notify ( "abandoned" );
		self thread heli_leave();	
	}
}

function attack_targets( missilesEnabled, hardpointType  )
{
	//self thread turret_kill_players();
	self thread attack_primary( hardpointType );
	if ( missilesEnabled ) 
		self thread attack_secondary( hardpointType );
}

// missile only
function attack_secondary( hardpointType )
{
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );	
	
	for( ;; )
	{
		if ( isdefined( self.secondaryTarget ) )
		{
			self.secondaryTarget.antithreat = undefined;
			self.missileTarget = self.secondaryTarget;
			
			antithreat = 0;

			while( isdefined( self.missileTarget ) && isalive( self.missileTarget ) )
			{
				// if selected target is not in missile hit range, skip
				if( self target_cone_check( self.missileTarget, level.heli_missile_target_cone ) )
					self thread missile_support( self.missileTarget, level.heli_missile_rof, true, undefined );
				else
					break;
				
				// lower targets threat after shooting
				antithreat += 100;
				self.missileTarget.antithreat = antithreat;
				
				wait level.heli_missile_rof;

				// target might disconnect or change during last assault cycle
				if ( !isdefined( self.secondaryTarget ) || ( isdefined( self.secondaryTarget ) && self.missileTarget != self.secondaryTarget ) )
					break;
			}
			// reset the antithreat factor
			if ( isdefined( self.missileTarget ) )
				self.missileTarget.antithreat = undefined;
		}
		self waittill( "secondary acquired" );

		// check if owner has left, if so, leave
		self check_owner( hardpointType );
	}	
}

function turret_target_check( turretTarget, attackAngle )
{
	
	targetYaw = math::get_2d_yaw( self.origin, turretTarget.origin );
	chopperYaw = self.angles[1];
	
	if ( targetYaw < 0 ) 
		targetYaw = targetYaw * -1;
	
	targetYaw = int( targetYaw ) % 360;
		
	if ( chopperYaw < 0 ) 
		chopperYaw = chopperYaw * -1;
	
	chopperYaw = int( chopperYaw ) % 360;
	
	if ( chopperYaw > targetYaw )
		difference = chopperYaw - targetYaw;
	else
		difference = targetYaw - chopperYaw;
		
	return ( difference <= attackAngle );
}
					
// check if missile is in hittable sight zone
function target_cone_check( target, coneCosine )
{
	heli2target_normal = vectornormalize( target.origin - self.origin );
	heli2forward = anglestoforward( self.angles );
	heli2forward_normal = vectornormalize( heli2forward );

	heli_dot_target = vectordot( heli2target_normal, heli2forward_normal );
	
	if ( heli_dot_target >= coneCosine )
	{
		return true;
	}
	return false;
}



// if wait for turret turning is too slow, enable missile assault support
function missile_support( target_player, rof, instantfire, endon_notify )
{
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );	
	 
	if ( isdefined ( endon_notify ) )
		self endon( endon_notify );
			
	self.turret_giveup = false;
	
	if ( !instantfire )
	{
		wait( rof );
		self.turret_giveup = true;
		self notify( "give up" );
	}
	
	if ( isdefined( target_player ) )
	{
		if ( level.teambased )
		{
			// if target near friendly, do not shoot missile, target already has lower threat level at this stage
			for (i = 0; i < level.players.size; i++)
			{
				player = level.players[i];
				if ( isdefined( player.team ) && player.team == self.team && distance( player.origin, target_player.origin ) <= level.heli_missile_friendlycare )
				{
					self notify ( "missile ready" );
					return;		
				}
			}
		}
		else
		{
			player = self.owner;
			if ( isdefined( player ) && isdefined( player.team ) && player.team == self.team && distance( player.origin, target_player.origin ) <= level.heli_missile_friendlycare )
			{
				self notify ( "missile ready" );
				return;
			}
		}
	}
	
	if ( self.missile_ammo > 0 && isdefined( target_player ) )
	{
		self fire_missile( "ffar", 1, target_player );
		self.missile_ammo--;
		self notify( "missile fired" );
	}
	else
	{
		return;
	}
	
	if ( instantfire )
	{
		wait ( rof );
		self notify ( "missile ready" );
	}
}

// mini-gun with missile support
function attack_primary( hardpointType )
{
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );
	level endon( "game_ended" );
 
	for( ;; )
	{
		if ( isdefined( self.primaryTarget ) )
		{
			self.primaryTarget.antithreat = undefined;
			self.turretTarget = self.primaryTarget;
			antithreat = 0;
			last_pos = undefined;
			
			while( isdefined( self.turretTarget ) && isalive( self.turretTarget ) )
			{
				
				//Look at target			
				if ( (hardpointType == "helicopter_comlink") || (hardpointType == "inventory_helicopter_comlink") )
					self SetLookAtEnt( self.turretTarget );
				
				helicopterTurretMaxAngle = heli_get_dvar_int( "scr_helicopterTurretMaxAngle", level.helicopterTurretMaxAngle );
				while ( isdefined( self.turretTarget ) && isalive( self.turretTarget ) && self turret_target_check( self.turretTarget, helicopterTurretMaxAngle ) == false ) 
					wait( 0.1 );
					
				if ( !isdefined( self.turretTarget ) || !isalive( self.turretTarget ) )
					break;

				// shoots one clip of mini-gun non stop
				self setTurretTargetEnt( self.turretTarget, ( 0, 0, 50 ) );		

				self waittill( "turret_on_target" );
				hostmigration::waitTillHostMigrationDone();
				
				/* 
				self util::waittill_any( "turret_on_target", "give up" );
				if( isdefined( self.turret_giveup ) && self.turret_giveup )
					break;
				*/
					
				self notify( "turret_on_target" );
				//play some targeting Dialog CDC
				if (!self.pilotIsTalking)
				{
					//self thread PlayPilotDialog ("attackheli_target");
				}
				
				self thread turret_target_flag( self.turretTarget );
				
				wait 1;
					
				self heli_set_active_camo_state( HELICOPTER_CAMO_STATE_OFF );
				
				// wait for turret to spinup and fire
				wait( level.heli_turret_spinup_delay );
				
				// fire gun =================================
				weaponShootTime = self.defaultWeapon.fireTime;
				self setVehWeapon( self.defaultWeapon );
				
				// shoot full clip at target, if target lost, shoot at the last position recorded, if target changed, sweep onto next target
				for( i = 0 ; i < level.heli_turretClipSize ; i++ )
				{
					// if turret on primary target, keep last position of the target in case target lost
					if ( isdefined( self.turretTarget ) && isdefined( self.primaryTarget ) )
					{
						if ( self.primaryTarget != self.turretTarget )
							self setTurretTargetEnt( self.primaryTarget, ( 0, 0, 40 ) );
					}
					else
					{
						if ( isdefined( self.targetlost ) && self.targetlost && isdefined( self.turret_last_pos ) )
						{
							self setturrettargetvec( self.turret_last_pos );
						}
						else
						{
							self clearturrettarget();
						}	
					}
					if ( gettime() != self.lastRocketFireTime )
					{
						// fire one bullet
						self setVehWeapon( self.defaultWeapon );
						miniGun = self fireWeapon();
						//self.minigun_snd_ent PlayLoopSound( "wpn_attack_chopper_minigun_fire_loop_npc" );//now in gdt
					}
					
					// wait for RoF
					if ( i < level.heli_turretClipSize - 1 )
						wait weaponShootTime;
				}
				//self.minigun_snd_ent StopLoopSound();
				//self.minigun_snd_ent PlaySound("wpn_attack_chopper_minigun_fire_loop_ring_npc");//now in gdt
				self notify( "turret reloading" );
				// end fire gun ==============================
				
				// wait for turret reload
				wait( level.heli_turretReloadTime );
				
				wait( 3 ); // cooldown before recloaking
				
				self heli_set_active_camo_state( HELICOPTER_CAMO_STATE_ON );
							
				// lower the target's threat since already assaulted on
				if ( isdefined( self.turretTarget ) && isalive( self.turretTarget ) )
				{
					antithreat += 100;
					self.turretTarget.antithreat = antithreat;
				}
				
				// primary target might disconnect or change during last assault cycle, if so, find new target
				if ( !isdefined( self.primaryTarget ) || ( isdefined( self.turretTarget ) && isdefined( self.primaryTarget ) && self.primaryTarget != self.turretTarget ) )
					break;
			}
			// reset the antithreat factor
			if ( isdefined( self.turretTarget ) )
				self.turretTarget.antithreat = undefined;
		}
		self waittill( "primary acquired" );
		
		// check if owner has left, if so, leave
		self check_owner( hardpointType );
	}
}

// target lost flaging
function turret_target_flag( turrettarget )
{
	// forcing single thread instance
	self notify( "flag check is running" );
	self endon( "flag check is running" );
	
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );
	self endon( "turret reloading" );
	
	// ends on target player death or undefined
	turrettarget endon( "death" );
	turrettarget endon( "disconnect" );
	
	self.targetlost = false;
	self.turret_last_pos = undefined;
	
	while( isdefined( turrettarget ) )
	{
		heli_centroid = self.origin + ( 0, 0, -160 );
		heli_forward_norm = anglestoforward( self.angles );
		heli_turret_point = heli_centroid + 144*heli_forward_norm;
	
		sight_rec = turrettarget sightconetrace( heli_turret_point, self );
		if ( sight_rec < level.heli_target_recognition )
			break;
		
		WAIT_SERVER_FRAME;
	}
	
	if( isdefined( turrettarget ) && isdefined( turrettarget.origin ) )
	{
		assert( isdefined( turrettarget.origin ), "turrettarget.origin is undefined after isdefined check" );
		self.turret_last_pos = turrettarget.origin + ( 0, 0, 40 );
		assert( isdefined( self.turret_last_pos ), "self.turret_last_pos is undefined after setting it #1" );
		self setturrettargetvec( self.turret_last_pos );
		assert( isdefined( self.turret_last_pos ), "self.turret_last_pos is undefined after setting it #2" );
		self.targetlost = true;
	}
	else
	{
		self.targetlost = undefined;
		self.turret_last_pos = undefined;
	}
}

function waittill_confirm_location()
{
	self endon( "emp_jammed" );
	self endon( "emp_grenaded" );
	
	self waittill( "confirm_location", location );
	
	return location;
}

function selectHelicopterLocation(hardpointtype)
{
	self beginLocationComlinkSelection( "compass_objpoint_helicopter", 1500 );
	self.selectingLocation = true;

	self thread airsupport::endSelectionThink();

	location = self waittill_confirm_location();

	if ( !isdefined( location ) )
	{
		// selection was cancelled
		return false;
	}

	if ( self killstreakrules::isKillstreakAllowed( hardpointType, self.team ) == false )
	{
		return false;
	}
	
	level.helilocation = location;

	return airsupport::finishHardpointLocationUsage( location, undefined );
}

function processCopterAssist( destroyedCopter, damagedone )
{
	self endon( "disconnect" );
	destroyedCopter endon( "disconnect" );
	
	wait .05; 
	
	if ( !isdefined( level.teams[self.team] ) )
		return;
	
	if ( self.team == destroyedCopter.team )
		return;
	
	assist_level = "aircraft_destruction_assist";
	
	assist_level_value = int( ceil( ( damagedone.damage / destroyedCopter.maxhealth ) * 4 ) );
	
	if ( assist_level_value > 0 )
	{
		if ( assist_level_value > 3 )
		{
			assist_level_value = 3;
		}
		assist_level = assist_level + "_" + ( assist_level_value * 25 );
	}

	scoreevents::processScoreEvent( assist_level, self );
}

//Allow the SAM turret to attack choppers
function SAMTurretWatcher()
{
	self endon( "death" );
	self endon( "crashing" );
	self endon( "leaving" );
	level endon( "game_ended" );

	self util::waittill_any( "turret_on_target", "path start", "near_goal" );

	Target_SetTurretAquire( self, true );
}

function PlayPilotDialog( dialog, time, voice, shouldWait )
{
	self endon( "death" );
	level endon( "remote_end" );

	if (isdefined(time))
	{
		wait time;
	}
	if (!isdefined(self.pilotVoiceNumber))
	{
		self.pilotVoiceNumber = 0;        
	}
	if (isdefined(voice))
	{
		voicenumber = voice;
	}
	else
	{
		voicenumber = self.pilotVoiceNumber;
	}
	soundAlias = level.teamPrefix[self.team] + voicenumber + "_" + dialog;

	if ( isdefined ( self.owner ) )
	{
		self.owner playPilotTalking( shouldWait, soundAlias );
	}
}

function playPilotTalking( shouldWait, soundAlias )
{
	self endon( "disconnect" );
	self endon( "joined_team" );
	self endon( "joined_spectators" );

	tryCounter = 0;
	while( isdefined(self.pilotTalking) && self.pilotTalking && tryCounter < 10 )
	{
		if ( isdefined( shouldWait ) && !shouldWait )
			return;
		wait 1;   
		tryCounter++;
	}
	self.pilotTalking = true;
	self playLocalSound(soundAlias);
	wait 3;
	self.pilotTalking = false;
}

function watchForEarlyLeave( chopper )
{
	chopper notify( "watchForEarlyLeave_helicopter" );
	chopper endon( "watchForEarlyLeave_helicopter" );
	chopper endon( "death" );
	self endon( "heli_timeup" );

	self util::waittill_any( "joined_team", "disconnect" );
	
	if ( isdefined( chopper ) )
		chopper thread heli_leave();
	
	if ( isdefined( self ) )
		self notify( "heli_timeup" );
}

function watchForEMP()
{
	heli = self;
	
	heli endon( "death" );
	heli endon( "heli_timeup" );
	
	heli.owner waittill( "emp_jammed" );	
	heli thread heli_explode();
}
