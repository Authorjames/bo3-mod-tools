#using scripts\codescripts\struct;

#using scripts\shared\challenges_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\hud_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\math_shared;
#using scripts\shared\popups_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_heatseekingmissile;
#using scripts\shared\weapons\_weaponobjects;

#using scripts\mp\_challenges;
#using scripts\mp\_util;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_shellshock;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_ai_tank;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_remote_weapons;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define UAV_REMOTE_FLY_TIME 60
#define UAV_REMOTE_AIM_ASSIST_RANGE 200
#define UAV_REMOTE_MAX_PAST_RANGE 200
#define UAV_REMOTE_MIN_HELI_PROXIMITY 150
#define UAV_REMOTE_MAX_HELI_PROXIMITY 300
#define UAV_REMOTE_PAST_RANGE_COUNTDOWN 6.1
#define UAV_REMOTE_HELI_RANGE_COUNTDOWN 6.1
#define UAV_REMOTE_COLLISION_RADIUS 18
#define UAV_REMOTE_Z_OFFSET -9
#define UAV_REMOTE_MODEL "veh_t6_drone_quad_rotor_mp"
#define UAV_REMOTE_MODEL_ENEMY "veh_t6_drone_quad_rotor_mp_alt"
#define UAV_DEATH_MODEL "veh_t6_drone_quad_rotor_mp"
#define QRDRONE_MAX_HEALTH 225
	
#precache( "string", "MP_REMOTE_UAV_PLACE" );
#precache( "string", "MP_REMOTE_UAV_CANNOT_PLACE" );
#precache( "string", "SPLASHES_DESTROYED_REMOTE_UAV" );
#precache( "string", "SPLASHES_MARKED_BY_REMOTE_UAV" );
#precache( "string", "SPLASHES_REMOTE_UAV_MARKED" );
#precache( "string", "SPLASHES_TURRET_MARKED_BY_REMOTE_UAV" );
#precache( "string", "SPLASHES_REMOTE_UAV_ASSIST" );
#precache( "string", "KILLSTREAK_EARNED_QRDRONE" );
#precache( "string", "KILLSTREAK_QRDRONE_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_QRDRONE_INBOUND" );
#precache( "string", "KILLSTREAK_QRDRONE_HACKED" );
#precache( "eventstring", "mpl_killstreak_qrdrone" );
#precache( "fx", "killstreaks/fx_drgnfire_light_green_3p" );
#precache( "fx", "killstreaks/fx_drgnfire_light_red_3p" );
#precache( "fx", "killstreaks/fx_drgnfire_light_green_1p" );
#precache( "fx", "weapon/fx_muz_md_rifle_3p" );
#precache( "fx", "killstreaks/fx_drgnfire_explosion" );
#precache( "fx", "killstreaks/fx_drgnfire_impact_sparks" );
#precache( "fx", "killstreaks/fx_drgnfire_damage_state" );
#precache( "fx", "killstreaks/fx_drgnfire_rotor_wash_runner" );

#namespace qrdrone;

function init()
{	
	level.qrdrone_vehicle = "qrdrone_mp";
	
	level.ai_tank_stun_fx = "killstreaks/fx_agr_emp_stun";

	level.QRDrone_minigun_flash = "weapon/fx_muz_md_rifle_3p";
	level.QRDrone_fx["explode"] = "killstreaks/fx_drgnfire_explosion";	
	
	level._effect[ "quadrotor_nudge" ]	= "killstreaks/fx_drgnfire_impact_sparks";
	level._effect[ "quadrotor_damage" ]	= "killstreaks/fx_drgnfire_damage_state";

	level.QRDrone_dialog["launch"][0] = "ac130_plt_yeahcleared";
	level.QRDrone_dialog["launch"][1] = "ac130_plt_rollinin";
	level.QRDrone_dialog["launch"][2] = "ac130_plt_scanrange";
	
	level.QRDrone_dialog["out_of_range"][0] = "ac130_plt_cleanup";
	level.QRDrone_dialog["out_of_range"][1] = "ac130_plt_targetreset";	
	
	level.QRDrone_dialog["track"][0] = "ac130_fco_moreenemy";
	level.QRDrone_dialog["track"][1] = "ac130_fco_getthatguy";
	level.QRDrone_dialog["track"][2] = "ac130_fco_guymovin";
	level.QRDrone_dialog["track"][3] = "ac130_fco_getperson";
	level.QRDrone_dialog["track"][4] = "ac130_fco_guyrunnin";
	level.QRDrone_dialog["track"][5] = "ac130_fco_gotarunner";
	level.QRDrone_dialog["track"][6] = "ac130_fco_backonthose";
	level.QRDrone_dialog["track"][7] = "ac130_fco_gonnagethim";
	level.QRDrone_dialog["track"][8] = "ac130_fco_personnelthere";
	level.QRDrone_dialog["track"][9] = "ac130_fco_rightthere";
	level.QRDrone_dialog["track"][10] = "ac130_fco_tracking";

	level.QRDrone_dialog["tag"][0] = "ac130_fco_nice";
	level.QRDrone_dialog["tag"][1] = "ac130_fco_yougothim";
	level.QRDrone_dialog["tag"][2] = "ac130_fco_yougothim2";
	level.QRDrone_dialog["tag"][3] = "ac130_fco_okyougothim";	
	
	level.QRDrone_dialog["assist"][0] = "ac130_fco_goodkill";
	level.QRDrone_dialog["assist"][1] = "ac130_fco_thatsahit";
	level.QRDrone_dialog["assist"][2] = "ac130_fco_directhit";
	level.QRDrone_dialog["assist"][3] = "ac130_fco_rightontarget";
	
	level.QRDrone_lastDialogTime = 0;
	
	level.QRDrone_noDeployZones = GetEntArray( "no_vehicles", "targetname" );

	level._effect["qrdrone_prop"] = "_t6/weapon/qr_drone/fx_qr_wash_3p";

	clientfield::register( "helicopter", "qrdrone_state", VERSION_SHIP, 3, "int" );
	clientfield::register( "helicopter", "qrdrone_timeout", VERSION_SHIP, 1, "int" );
	clientfield::register( "helicopter", "qrdrone_countdown", VERSION_SHIP, 1, "int" );

	clientfield::register( "vehicle", "qrdrone_state", VERSION_SHIP, 3, "int" );
	clientfield::register( "vehicle", "qrdrone_timeout", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "qrdrone_countdown", VERSION_SHIP, 1, "int" );
	clientfield::register( "vehicle", "qrdrone_out_of_range", VERSION_SHIP, 1, "int" );	

	
	level.qrdroneOnBlowUp = &qrdrone::QRDrone_blowup;
	level.qrdroneOnDamage = &qrdrone::QRDrone_damageWatcher;
}	

function tryUseQRDrone( lifeId )
{ 
	if ( self util::isUsingRemote() || isdefined( level.nukeIncoming ) )
	{
		return false;
	}	
	
	if (!self IsOnGround())
	{
		self iPrintLnBold( &"KILLSTREAK_QRDRONE_NOT_PLACEABLE" );
		return false;
	}
			
	streakName = "TODO";
	result = self giveCarryQRDrone( lifeId, streakName );
		
	self.isCarrying = false;
	return ( result );
}


function giveCarryQRDrone( lifeId, streakName )
{
	//	create carry object
	carryQRDrone = createCarryQRDrone( streakName, self );	
	
	//	give carry object and wait for placement (blocking loop)
	self setCarryingQRDrone( carryQRDrone );
	
	//	we're back, what happened?
	if ( isAlive( self ) && isdefined( carryQRDrone ) )
	{		
		//	if it placed, start the killstreak at that location
		origin = carryQRDrone.origin;
		angles = self.angles;
		carryQRDrone.soundEnt delete();
		carryQRDrone delete();		
		
		result = self startQRDrone( lifeId, streakName, origin, angles );		
	}	
	else
	{
		//	cancelled placement or died
		result = false;
	}
	
	return result;
}


//	Carry Remote UAV


function createCarryQRDrone( streakName, owner )
{
	pos = owner.origin + ( anglesToForward( owner.angles ) * 4 ) + ( anglesToUp( owner.angles ) * 50 );	

	carryQRDrone = spawnTurret( "misc_turret", pos, GetWeapon( "auto_gun_turret" ) );
	carryQRDrone.turretType = "sentry";
	carryQRDrone SetTurretType(carryQRDrone.turretType);
	carryQRDrone.origin = pos;
	carryQRDrone.angles = owner.angles;	
	
	carryQRDrone.canBePlaced = true;
	carryQRDrone makeUnusable();	
	carryQRDrone.owner = owner;
	carryQRDrone SetOwner( carryQRDrone.owner );
	carryQRDrone.scale = 3;
	carryQRDrone.inHeliProximity = false;

	carryQRDrone thread carryQRDrone_handleExistence();
	
	carryQRDrone.rangeTrigger = GetEnt( "qrdrone_range", "targetname" );
	if ( !isdefined( carryQRDrone.rangeTrigger ) )
	{
		carryQRDrone.maxHeight = int(airsupport::getMinimumFlyHeight());
		carryQRDrone.maxDistance = 3600;		
	}	
	carryQRDrone.minHeight = level.mapCenter[2] - 800;		
	
	//	apparently can't call playLoopSound on a turret?
	carryQRDrone.soundEnt = spawn( "script_origin", carryQRDrone.origin );
	carryQRDrone.soundEnt.angles = carryQRDrone.angles;
	carryQRDrone.soundEnt.origin = carryQRDrone.origin;
	carryQRDrone.soundEnt linkTo( carryQRDrone );
	carryQRDrone.soundEnt playLoopSound( "recondrone_idle_high" );		

	return carryQRDrone;	
}

function watchForAttack( )
{
	self endon ( "death" );
	self endon ( "disconnect" );
	self endon ( "place_carryQRDrone" );
	self endon ( "cancel_carryQRDrone" );
	
	for ( ;; )
	{
		WAIT_SERVER_FRAME;
	
		if ( self attackButtonPressed() )
		{
				self notify( "place_carryQRDrone" );		
		}		
	}
}

function setCarryingQRDrone( carryQRDrone )
{
	self endon ( "death" );
	self endon ( "disconnect" );
	
	carryQRDrone thread carryQRDrone_setCarried( self );		

	if ( !carryQRDrone.canBePlaced )
	{
			if ( self.team != "spectator" )
				self iPrintLnBold( &"KILLSTREAK_QRDRONE_NOT_PLACEABLE" );
			if ( isdefined( carryQRDrone.soundEnt ) )
				carryQRDrone.soundEnt delete();	
			carryQRDrone delete();		
			return;
	}					
	
	self.isCarrying = false;
	carryQRDrone.carriedBy = undefined;		

	carryQRDrone playSound( "sentry_gun_plant" );	
	carryQRDrone notify ( "placed" );		
}

function carryQRDrone_setCarried( carrier )
{
	self setCanDamage( false );
	self setContents( 0 );

	self.carriedBy = carrier;
	carrier.isCarrying = true;

	carrier thread updateCarryQRDronePlacement( self );
	self notify ( "carried" );	
}


function isInRemoteNoDeploy()
{
	if ( isdefined( level.QRDrone_noDeployZones ) && level.QRDrone_noDeployZones.size )
	{
		foreach( zone in level.QRDrone_noDeployZones )
		{
			if ( self isTouching( zone ) )
				return true;
		}
	}
	return false;
}


function updateCarryQRDronePlacement( carryQRDrone )
{
	self endon ( "death" );
	self endon ( "disconnect" );
	level endon ( "game_ended" );
	
	carryQRDrone endon ( "placed" );
	carryQRDrone endon ( "death" );
	
	carryQRDrone.canBePlaced = true;
	lastCanPlaceCarryQRDrone = -1; // force initial update

	for( ;; )
	{		
		heightOffset = UAV_REMOTE_COLLISION_RADIUS;
		switch( self getStance() )
		{
			case "stand":
				heightOffset = 40;
				break;
			case "crouch":
				heightOffset = 25;
				break;
			case "prone":
				heightOffset = 10;
				break;
		}
		
		placement = self CanPlayerPlaceVehicle( 22, 22, 50, heightOffset, 0, 0 );
		carryQRDrone.origin = placement[ "origin" ] + ( anglesToUp(self.angles) * ( UAV_REMOTE_COLLISION_RADIUS - UAV_REMOTE_Z_OFFSET ) );
		carryQRDrone.angles = placement[ "angles" ];		
		carryQRDrone.canBePlaced = self isOnGround() && placement[ "result" ] && carryQRDrone QRDrone_in_range() && !carryQRDrone isInRemoteNoDeploy();			
	
		if ( carryQRDrone.canBePlaced != lastCanPlaceCarryQRDrone )
		{
			if ( carryQRDrone.canBePlaced )
			{
				//	if they're holding it in launch position just launch now
				if ( self attackButtonPressed() )
					self notify( "place_carryQRDrone" );				
			}
			else
			{
			}
		}
		
		lastCanPlaceCarryQRDrone = carryQRDrone.canBePlaced;		
		WAIT_SERVER_FRAME;
	}
}


function carryQRDrone_handleExistence()
{
	level endon ( "game_ended" );
	self endon("death");
	self.owner endon ( "place_carryQRDrone" );
	self.owner endon ( "cancel_carryQRDrone" );

	self.owner util::waittill_any( "death", "disconnect", "joined_team", "joined_spectators" );

	if ( isdefined( self ) )
	{
		self delete();
	}
}

function removeRemoteWeapon()
{
	level endon( "game_ended" );
	self endon ( "disconnect" );
	
	wait(0.7);
	
}


function startQRDrone( lifeId, streakName, origin, angles )
{		
	self lockPlayerForQRDroneLaunch();
	self util::setUsingRemote( streakName );
	self util::freeze_player_controls( true );
			
	// blocking function waiting for the tablet to be switched to
	result = self killstreaks::init_ride_killstreak( "qrdrone" );		
	
	if ( result != "success" || level.gameEnded )
	{
		if ( result != "disconnect" )
		{
			self util::freeze_player_controls( false );
			self killstreakrules::isKillstreakAllowed( "qrdrone", self.team );
			self notify( "qrdrone_unlock" );
			self killstreaks::clear_using_remote();
		}
		return false;
	}	

	team = self.team;
	killstreak_id = self killstreakrules::killstreakStart( "qrdrone", team, false, true );
	if ( killstreak_id == -1 )
	{
		self notify( "qrdrone_unlock" );
		self util::freeze_player_controls( false );
		self killstreaks::clear_using_remote();
		return false;
	}

	self notify( "qrdrone_unlock" );
	QRDrone = createQRDrone( lifeId, self, streakName, origin, angles, killstreak_id );
	self util::freeze_player_controls( false );
	if ( isdefined( QRDrone ) )
	{
		self thread QRDrone_Ride( lifeId, QRDrone, streakName );
		QRDrone waittill( "end_remote" );

		killstreakrules::killstreakStop( "qrdrone", team, killstreak_id );
		return true;
	}
	else
	{
		self iPrintLnBold( &"MP_TOO_MANY_VEHICLES" );
		self killstreaks::clear_using_remote();
		killstreakrules::killstreakStop( "qrdrone", team, killstreak_id );
		return false;	
	}		
}

function lockPlayerForQRDroneLaunch()
{
	//	lock
	lockSpot = spawn( "script_origin", self.origin );
	lockSpot hide();	
	self playerLinkTo( lockSpot );	
	
	//	wait for unlock
	self thread clearPlayerLockFromQRDroneLaunch( lockSpot );
}


function clearPlayerLockFromQRDroneLaunch( lockSpot )
{
	level endon( "game_ended" );
	
	msg = self util::waittill_any_return( "disconnect", "death", "qrdrone_unlock" );
	
	lockSpot delete();
}


function createQRDrone( lifeId, owner, streakName, origin, angles, killstreak_id )
{
	QRDrone = spawnHelicopter( owner, origin, angles, level.qrdrone_vehicle, UAV_REMOTE_MODEL );	
	if ( !isdefined( QRDrone ) )
		return undefined;
			
	QRDrone.lifeId = lifeId;
	QRDrone.team = owner.team;
	QRDrone.pers["team"] = owner.team;	
	QRDrone.owner = owner;
	QRDrone clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
	QRDrone.health = 999999; // keep it from dying anywhere in code
	QRDrone.maxHealth = 250; // this is the health we'll check
	QRDrone.damageTaken = 0;	
	QRDrone.destroyed = false;
	QRDrone setCanDamage( true );
	QRDrone EnableAimAssist();
	
	QRDrone.smoking = false;
	QRDrone.inHeliProximity = false;		
	QRDrone.heliType = "qrdrone";	
	QRDrone.markedPlayers = [];
	QRDrone.isStunned = false;
	QRDrone SetEnemyModel( UAV_REMOTE_MODEL_ENEMY );
	QRDrone SetDrawInfrared( true );
	
	QRDrone.killCamEnt = QRDrone.owner;
		
	owner weaponobjects::addWeaponObjectToWatcher( "qrdrone", QRDrone );
	QRDrone thread QRDrone_explode_on_notify(killstreak_id);
	QRDrone thread QRDrone_explode_on_game_end();

	QRDrone thread QRDrone_leave_on_timeout( streakName );
	QRDrone thread QRDrone_watch_distance();
	QRDrone thread QRDrone_watch_for_exit();
	
	QRDrone thread deleteOnKillbrush( owner );

	// make the qrdrone targetable
	Target_Set( QRDrone, (0,0,0) );
	Target_SetTurretAquire( QRDrone, false );
	
	QRDrone.numFlares = 0;
	QRDrone.flareOffset = (0,0,-100);						
	QRDrone thread heatseekingmissile::MissileTarget_LockOnMonitor( self, "end_remote" );				// monitors missle lock-ons
	QRDrone thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile( "crashing" );

	QRDrone.emp_fx = spawn( "script_model", self.origin );
	QRDrone.emp_fx SetModel( "tag_origin" );
	QRDrone.emp_fx LinkTo( self, "tag_origin", (0,0,-20) + AnglesToForward(self.angles) * 6 );

	// create the influencers
	QRDrone spawning::create_entity_enemy_influencer( "small_vehicle", QRDrone.team );
	QRDrone spawning::create_entity_enemy_influencer( "qrdrone_cylinder", QRDrone.team );

	return QRDrone;
}


function QRDrone_ride( lifeId, QRDrone, streakName )
{
	QRDrone.playerLinked = true;
	self.restoreAngles = self.angles;
		
	QRDrone usevehicle( self, 0 );
	self util::clientNotify( "qrfutz" );	
	self killstreaks::play_killstreak_start_dialog( "qrdrone", self.pers["team"] );

	self AddWeaponStat( GetWeapon( "killstreak_qrdrone" ), "used", 1 );

	self.qrdrone_rideLifeId = lifeId;
	self.QRDrone = QRDrone;
	
	self thread QRDrone_delayLaunchDialog( QRDrone );
	self thread QRDrone_fireGuns( QRDrone );
	QRDrone thread play_lockon_sounds( self );
		
	if ( isdefined( level.qrdrone_vision ) )
		self setVisionsetWaiter();
}

function QRDrone_delayLaunchDialog( QRDrone )
{
	level endon( "game_ended" );
	self endon ( "disconnect" );
	QRDrone endon ( "death" );
	QRDrone endon ( "end_remote" );
	QRDrone endon ( "end_launch_dialog" );	
	
	wait( 3 );
	self QRDrone_dialog( "launch" );
}

function QRDrone_Unlink( QRDrone )
{
	if ( isdefined( QRDrone ) )
	{		
		QRDrone.playerLinked = false;
		self destroyHud();
		
		if ( isdefined( self.viewlockedentity ) )
		{
			self Unlink();
			if ( isdefined(level.gameEnded) && level.gameEnded )
			{
				self util::freeze_player_controls( true );
			}	
		}
	}
}


function QRDrone_endride( QRDrone )
{
	if ( isdefined( QRDrone ) )
	{		
		QRDrone notify( "end_remote" );
		
		self killstreaks::clear_using_remote();

		self setPlayerAngles( self.restoreAngles );	
		
		if ( isalive(self) )
		{
			self killstreaks::switch_to_last_non_killstreak_weapon();
		}
			
		self thread QRDrone_freezeBuffer();
	}
	self.QRDrone = undefined;
}

function play_lockon_sounds( player )
{
	player endon("disconnect");
	self endon( "death" );
	self endon ( "blowup" );
	self endon ( "crashing" );
	level endon ( "game_ended" );
	self endon ( "end_remote" );	
		
	self.lockSounds = spawn( "script_model", self.origin);
	wait ( 0.1 );
	self.lockSounds LinkTo( self, "tag_player" );
	
	while ( true )
	{
		self waittill( "locking on" );
		
		while ( true )
		{
			if ( enemy_locking() )
			{
				//self.lockSounds PlaySoundToPlayer( "uin_alert_lockon_start", player );				
				//wait ( 0.3 );
				
				self.lockSounds PlaySoundToPlayer( "uin_alert_lockon", player );
				wait ( 0.125 );
			}
			
			if ( enemy_locked() )
			{
				self.lockSounds PlaySoundToPlayer( "uin_alert_lockon", player );
				wait ( 0.125 );
			}
			
			if ( !enemy_locking() && !enemy_locked() )
			{
				self.lockSounds StopSounds();
				break;
			}			
		}
	}
}

function enemy_locking()
{
	if ( isdefined(self.locking_on) && self.locking_on )
		return true;
	
	return false;
}

function enemy_locked()
{
	if ( isdefined(self.locked_on) && self.locked_on )
		return true;
			
	return false;
}


function QRDrone_freezeBuffer()
{
	self endon( "disconnect" );
	self endon( "death" );
	level endon( "game_ended" );
	
	self util::freeze_player_controls( true );
	wait( 0.5 );
	self util::freeze_player_controls( false );
}


function QRDrone_playerExit( QRDrone )
{
	level endon( "game_ended" );
	self endon ( "disconnect" );
	QRDrone endon ( "death" );
	QRDrone endon ( "end_remote" );
	
	//	delay exit for transition into remote
	wait( 2 );
	
	while( true )
	{
		timeUsed = 0;
		while(	self UseButtonPressed() )
		{	
			timeUsed += 0.05;
			if( timeUsed > 0.75 )
			{	
				QRDrone thread QRDrone_leave();
				return;
			}
			WAIT_SERVER_FRAME;
		}
		WAIT_SERVER_FRAME;
	}
}

function touchedKillbrush()
{
	if ( isdefined(self) )
	{
		self clientfield::set( "qrdrone_state", QRDRONE_FX_DEATH );
		watcher =  self.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
		watcher thread weaponobjects::waitAndDetonate( self, 0.0);	
	}
}

function deleteOnKillbrush(player)
{
	player endon("disconnect");
	self endon("death");
		
	killbrushes = [];
	hurt = GetEntArray( "trigger_hurt","classname" );

	foreach( trig in hurt )
	{
		if ( trig.origin[2] <= player.origin[2] && ( !isDefined( trig.script_parameters ) || trig.script_parameters != "qrdrone_safe" ) )
		{
			killbrushes[ killbrushes.size ] = trig;
		}
	}
	
	crate_triggers = GetEntArray( "crate_kill_trigger", "targetname" );

	while(1)
	{
		for (i = 0; i < killbrushes.size; i++)
		{
			if (self istouching(killbrushes[i]) )
			{
				self touchedKillbrush();
				return;
			}
		}

		foreach( trigger in crate_triggers )
		{
			if ( trigger.active && self istouching(trigger) )
			{
				self touchedKillbrush();
				return;
			}
		}
		
		if ( isdefined( level.levelKillbrushes ) )
		{
			foreach( trigger in level.levelKillbrushes  )
			{
				if (self istouching(trigger) )
				{
					self touchedKillbrush();
					return;
				}
			}
		}

		if ( level.script == "mp_castaway" )
		{
			origin = self.origin - ( 0, 0, 12 );
			water = GetWaterHeight( origin );

			if ( water - origin[2] > 0 )
			{
				self touchedKillbrush();
				return;
			}
		}
		
		wait( 0.1 );
	}
}

function QRDrone_force_destroy()
{
	self clientfield::set( "qrdrone_state", QRDRONE_FX_DEATH );
	watcher =  self.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
	watcher thread weaponobjects::waitAndDetonate( self, 0.0);	
}

function QRDrone_get_damage_effect( health_pct )
{
	if( health_pct > .5 )
	{
		return level._effect[ "quadrotor_damage" ];
	}
	
	return undefined;
}

function QRDrone_play_single_fx_on_tag( effect, tag )
{	
	if( isdefined( self.damage_fx_ent ) )
	{
		if( self.damage_fx_ent.effect == effect )
		{
			// already playing
			return;
		}
		self.damage_fx_ent delete();
	}
	
	playfxontag( effect, self, "tag_origin" );

}

function QRDrone_update_damage_fx( health_percent )
{	
	effect = QRDrone_get_damage_effect( health_percent );
	if( isdefined( effect ) )
	{
		QRDrone_play_single_fx_on_tag( effect, "tag_origin" );	
	}
	else
	{
		if( isdefined( self.damage_fx_ent ) )
		{
			self.damage_fx_ent delete();
		}
	}
}

function QRDrone_damageWatcher()
{
	self endon( "death" );

	self.maxhealth = 999999;
	self.health = self.maxhealth;
	self.maxhealth = QRDRONE_MAX_HEALTH;
	
	low_health = false;
	damage_taken = 0;

	for ( ;; )
	{
		self waittill( "damage", damage, attacker, dir, point, mod, model, tag, part, weapon, flags );
		
		if( !isdefined( attacker ) || !isplayer( attacker ) )
			continue;
		
		self.owner playrumbleonentity("damage_heavy");

		if ( mod == "MOD_RIFLE_BULLET" || mod == "MOD_PISTOL_BULLET")
		{
			if ( isPlayer( attacker ) )
			{
			    if ( attacker HasPerk( "specialty_armorpiercing" ) )
			    {
					damage += int( damage * level.cac_armorpiercing_data );
			    }
			}
			
			if (weapon.weapClass == "spread")
					damage = damage * 2;
		}	
			
		if ( weapon.isEmp && (mod == "MOD_GRENADE_SPLASH"))
		{
			damage_taken += ( QRDRONE_MAX_HEALTH );
			damage = 0;
		}
		
		if (!self.isStunned)
		{
			if ( weapon.isStun && (mod == "MOD_GRENADE_SPLASH" || mod == "MOD_GAS") )
			{
				self.isStunned = true;
				self QRDrone_stun( 2 );
			}
		}
		
		self.attacker = attacker;
		
		self.owner SendKillstreakDamageEvent( int(damage) );

		damage_taken += damage;

			
		if ( damage_taken >= QRDRONE_MAX_HEALTH )
		{
			//this is for HUD screen scramble
			self.owner SendKillstreakDamageEvent( 200 );
			
			self QRDrone_death( attacker, weapon, dir, mod );
			return;
		}
		else 
		{
			QRDrone_update_damage_fx( float(damage_taken) / QRDRONE_MAX_HEALTH );
		}
	}
}

function QRDrone_stun( duration )
{	
	self endon( "death" );
	self notify( "stunned" );
	
	self.owner util::freeze_player_controls( true );
	
	if (isdefined(self.owner.fullscreen_static))
	{
		self.owner thread remote_weapons::stunStaticFX( duration );
	}
	wait ( duration );
	
	self.owner util::freeze_player_controls( false );

	self.isStunned = false;
}

function QRDrone_death( attacker, weapon, dir, damageType )
{
	if( isdefined( self.damage_fx_ent ) )
	{
		self.damage_fx_ent delete();
	}
	
	if ( isdefined(attacker) && IsPlayer(attacker) && attacker != self.owner)
	{
		level thread popups::DisplayTeamMessageToAll( &"SCORE_DESTROYED_QRDRONE", attacker ); 
		if ( self.owner util::IsEnemyPlayer( attacker ) )
		{
			attacker challenges::destroyedQRDrone( damageType, weapon );
			attacker AddWeaponStat( weapon, "destroyed_qrdrone", 1 );
			attacker challenges::addFlySwatterStat( weapon, self );	
			attacker AddWeaponStat( weapon, "destroyed_controlled_killstreak", 1 );		
		}
		else
		{
			//Destroyed Friendly Killstreak 
		}
	}
		
	self thread QRDrone_crash_movement( attacker, dir );
	if ( weapon.isEmp )
	{
		PlayFXOnTag( level.ai_tank_stun_fx, self.emp_fx, "tag_origin" );
	}
	
	self waittill( "crash_done" );
	
	if ( isdefined(self.emp_fx) )
	{
		self.emp_fx delete();
	}
	// A dynEnt will be spawned in the collision thread when it hits the ground and "crash_done" notify will be sent
	self clientfield::set( "qrdrone_state", QRDRONE_FX_DEATH );
	watcher =  self.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
	watcher thread weaponobjects::waitAndDetonate( self, 0.0, attacker, weapon );
}

function death_fx()
{
	playfxontag( self.deathfx, self, self.deathfxtag );
	self playsound("veh_qrdrone_sparks");
}

function QRDrone_crash_movement( attacker, hitdir )
{
	self endon( "crash_done" );
	self endon( "death" );
	self notify( "crashing" );
	
	// take away driver control
	self takeplayercontrol();
	
	self SetMaxPitchRoll( 90, 180 );
	self SetPhysAcceleration( ( 0, 0, -800 ) );

	side_dir = VectorCross( hitdir, (0,0,1) );
	side_dir_mag = RandomFloatRange( -100, 100 );
	side_dir_mag += math::sign( side_dir_mag ) * 80;
	side_dir *= side_dir_mag;
	
	velocity = self GetVelocity();
	self SetVehVelocity( velocity + (0,0,100) + VectorNormalize( side_dir ) );

	ang_vel = self GetAngularVelocity();
	ang_vel = ( ang_vel[0] * 0.3, ang_vel[1], ang_vel[2] * 0.3 );
	
	yaw_vel = RandomFloatRange( 0, 210 ) * math::sign( ang_vel[1] );
	yaw_vel += math::sign( yaw_vel ) * 180;
	
	ang_vel += ( RandomFloatRange( -100, 100 ), yaw_vel, RandomFloatRange( -200, 200 ) );
	
	self SetAngularVelocity( ang_vel );
	
	self.crash_accel = RandomFloatRange( 75, 110 );
	
	self thread QRDrone_crash_accel();
	self thread QRDrone_collision();
	
	//drone death sounds JM - play 1 shot hit, turn off main loop, thread dmg loop
	self playsound("veh_qrdrone_dmg_hit");
	self thread QRDrone_dmg_snd();

	wait 0.1;
	
	if( RandomInt( 100 ) < 40 )
	{
		self thread QRDrone_fire_for_time( RandomFloatRange( 0.7, 2.0 ) );
	}
	
	wait 2;
	
	// failsafe notify
	self notify( "crash_done" );
}


function QRDrone_dmg_snd()
{
	dmg_ent = spawn("script_origin", self.origin);
	dmg_ent linkto (self);
	dmg_ent PlayLoopSound ("veh_qrdrone_dmg_loop");
	self util::waittill_any("crash_done", "death");
	dmg_ent stoploopsound(.2);
	wait (2);
	dmg_ent delete();
}

function QRDrone_fire_for_time( totalFireTime )
{
	self endon( "crash_done" );
	self endon( "change_state" );
	self endon( "death" );
	
	weapon = self SeatGetWeapon( 0 );
	fireTime = weapon.fireTime;
	time = 0;
	
	fireCount = 1;
	
	while( time < totalFireTime )
	{
		self FireWeapon();
		fireCount++;
		wait fireTime;
		time += fireTime;
	}
}

function QRDrone_crash_accel()
{
	self endon( "crash_done" );
	self endon( "death" );
	
	count = 0;
	
	while( 1 )
	{
		velocity = self GetVelocity();
		self SetVehVelocity( velocity + AnglesToUp( self.angles ) * self.crash_accel );
		self.crash_accel *= 0.98;
		
		wait 0.1;
		
		count++;
		if( count % 8 == 0 )
		{
			if( RandomInt( 100 ) > 40 )
			{
				if( velocity[2] > 150.0 )
				{
					self.crash_accel *= 0.75;
				}
				else if( velocity[2] < 40.0 && count < 60 )
				{
					if( Abs( self.angles[0] ) > 30 || Abs( self.angles[2] ) > 30 )
					{
						self.crash_accel = RandomFloatRange( 160, 200 );
					}
					else
					{
						self.crash_accel = RandomFloatRange( 85, 120 );
					}
				}
			}
		}
	}
}

function QRDrone_collision()
{
	self endon( "crash_done" );
	self endon( "death" );
	
	while( 1 )
	{
		self waittill( "veh_collision", velocity, normal );
		ang_vel = self GetAngularVelocity() * 0.5;
		self SetAngularVelocity( ang_vel );
		
		velocity = self GetVelocity();
		
		// bounce off walls
		if( normal[2] < 0.7 )	
		{
			self SetVehVelocity( velocity + normal * 70 );
			self playsound ("veh_qrdrone_wall");
			PlayFX( level._effect[ "quadrotor_nudge" ], self.origin );
		}
		else
		{
			self playsound ("veh_qrdrone_explo");
			self notify( "crash_done" );
		}
	}
}

function QRDrone_watch_distance( zoffset, minHeightOverride )
{
	self endon ("death" );
	
	self.owner inithud();
	
	// Reset the ui model. Setting it dircetly to 0 doest seem to do it
	self clientfield::set( "qrdrone_out_of_range", 1 );
	WAIT_SERVER_FRAME;
	self clientfield::set( "qrdrone_out_of_range", 0 );

	qrdrone_height = struct::get( "qrdrone_height", "targetname");
	if ( isdefined(qrdrone_height) )
	{
		self.maxHeight = qrdrone_height.origin[2];
	}
	else
	{
		self.maxHeight = int(airsupport::getMinimumFlyHeight());
	}
	
	if( isdefined( zoffset ) )
		self.maxHeight += zoffset; 
	
	self.maxDistance = 12800;		

	self.minHeight = level.mapCenter[2] - 800;		
	if( isdefined( minHeightOverride ) )
		self.minHeight = minHeightOverride;

	//	ent to put headicon on for pointing to inside of map when they go out of range
	self.centerRef = spawn( "script_model", level.mapCenter );
	
	//	shouldn't be possible to start out of range, but just in case
	inRangePos = self.origin;		
	
	self.rangeCountdownActive = false;
	
	//	loop
	while ( true )
	{
		if ( !self QRDrone_in_range() )
		{
			//	increase static with distance from exit point or distance to heli in proximity
			staticAlpha = 0;		
			while ( !self QRDrone_in_range() )
			{
				if ( !self.rangeCountdownActive )
				{
					self.rangeCountdownActive = true;
					self thread QRDrone_rangeCountdown();
				}
				if ( isdefined( self.heliInProximity ) )
				{
					dist = distance( self.origin, self.heliInProximity.origin );
					staticAlpha = 1 - ( (dist-UAV_REMOTE_MIN_HELI_PROXIMITY) / (UAV_REMOTE_MAX_HELI_PROXIMITY-UAV_REMOTE_MIN_HELI_PROXIMITY) );
				}
				else
				{
					dist = distance( self.origin, inRangePos );
					staticAlpha = min( .7, dist/UAV_REMOTE_MAX_PAST_RANGE );					
				}
				
				self.owner set_static_alpha( staticAlpha, self );
				
				WAIT_SERVER_FRAME;
			}
			
			//	end countdown
			self notify( "in_range" );
			self.rangeCountdownActive = false;
			
			//	fade out static
			self thread QRDrone_staticFade( staticAlpha );
		}		
		inRangePos = self.origin;
		WAIT_SERVER_FRAME;
	}
}


function QRDrone_in_range()
{
	if ( self.origin[2] < self.maxHeight && self.origin[2] > self.minHeight &&  !self.inHeliProximity )
	{
		if ( self isMissileInsideHeightLock() )
		{
				return true;
		}
	}
	return false;
}


function QRDrone_staticFade( staticAlpha )
{
	self endon ( "death" );
	while( self QRDrone_in_range() )
	{
		staticAlpha -= 0.05;
		if ( staticAlpha < 0 )
		{
			self.owner set_static_alpha( staticAlpha, self );
			break;
		}
		self.owner set_static_alpha( staticAlpha, self );
		
		WAIT_SERVER_FRAME;
	}
}


function QRDrone_rangeCountdown()
{
	self endon( "death" );
	self endon( "in_range" );
	
	if ( isdefined( self.heliInProximity ) )
		countdown = UAV_REMOTE_HELI_RANGE_COUNTDOWN;
	else
		countdown = UAV_REMOTE_PAST_RANGE_COUNTDOWN;
	
	hostmigration::waitLongDurationWithHostMigrationPause( countdown );
	
	self.owner notify( "stop_signal_failure" );
	
	if( isdefined( self.distance_shutdown_override ) )
	{
		return [[ self.distance_shutdown_override ]]();
	}
	
	self clientfield::set( "qrdrone_state", QRDRONE_FX_DEATH );
	watcher =  self.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
	watcher thread weaponobjects::waitAndDetonate(self,0);
}


function QRDrone_explode_on_notify( killstreak_id )
{
	self endon ( "death" );
	self endon( "end_ride" );

	self.owner util::waittill_any( "disconnect", "joined_team", "joined_spectators" );
	
	if( isdefined( self.owner ) )
	{
		self.owner killstreaks::clear_using_remote();
		self.owner destroyHud();
		self.owner QRDrone_endride( self );
	}
	else
	{
		killstreakrules::killstreakStop( "qrdrone", self.team, killstreak_id );
	}
	
	self clientfield::set( "qrdrone_state", QRDRONE_FX_DEATH );
	watcher =  self.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
	watcher thread weaponobjects::waitAndDetonate(self,0);
}


function QRDrone_explode_on_game_end()
{
	self endon ( "death" );	

	level waittill( "game_ended" );
	
	self clientfield::set( "qrdrone_state", QRDRONE_FX_DEATH );
	watcher =  self.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
	watcher weaponobjects::waitAndDetonate(self,0);
	self.owner QRDrone_endride( self );
}


function QRDrone_leave_on_timeout( killstreakName )
{
	qrdrone = self;
	qrdrone endon ( "death" );	
	
	if ( !level.vehiclesTimed ) 
		return;

	qrdrone.flyTime = 60.0;
	waittime = self.flyTime - 10;
	
	qrdrone thread killstreaks::WaitForTimeout( killstreakName, waittime, &QRDrone_leave_on_timeout_callback, "death" );
}

function QRDrone_leave_on_timeout_callback()
{
	qrdrone = self;

	qrdrone clientfield::set( "qrdrone_state", QRDRONE_FX_BLINK );
	qrdrone clientfield::set( "qrdrone_countdown", 1 );
	hostmigration::waitLongDurationWithHostMigrationPause( 6 );

	qrdrone clientfield::set( "qrdrone_state", QRDRONE_FX_FINAL_BLINK );
	qrdrone clientfield::set( "qrdrone_timeout", 1 );
	hostmigration::waitLongDurationWithHostMigrationPause( 4 );

	qrdrone clientfield::set( "qrdrone_state", QRDRONE_FX_DEATH );
	watcher =  self.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
	watcher thread weaponobjects::waitAndDetonate(self,0);
}


function QRDrone_leave()
{
	level endon( "game_ended" );
	self endon( "death" );
	
	//	disengage player
	self notify( "leaving" );
	self.owner QRDrone_Unlink( self );
	self.owner QRDrone_endride( self );

	//	remove	
	self notify( "death" );
}

function QRDrone_exit_button_pressed()
{
	return self UseButtonPressed();
}

function QRDrone_watch_for_exit()
{
	level endon( "game_ended" );
	self endon( "death" );
	self.owner endon( "disconnect" );
		
	wait( 1 );
	
	while( true )
	{
		timeUsed = 0;
		while( self.owner QRDrone_exit_button_pressed() )
		{
			timeUsed += 0.05;
			if ( timeUsed > 0.25 )
			{
				self clientfield::set( "qrdrone_state", QRDRONE_FX_DEATH );
				watcher =  self.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
				watcher thread weaponobjects::waitAndDetonate( self, 0.0, self.owner );
				return;
			}
			WAIT_SERVER_FRAME;
		}
		WAIT_SERVER_FRAME;
	}	
}

function QRDrone_cleanup()
{
	if ( level.gameEnded )
	{
		return;
	}

	if( isdefined( self.owner ) )
	{
		if ( self.playerLinked == true )
			self.owner QRDrone_Unlink( self );

		self.owner QRDrone_endride( self );	
	}
		
	if ( isdefined( self.scrambler ) )
		self.scrambler delete();
		
	if ( isdefined(self) && isdefined( self.centerRef ) )
		self.centerRef delete();
	
	Target_SetTurretAquire( self, false );
		
	if( isdefined( self.damage_fx_ent ) )
	{
		self.damage_fx_ent delete();
	}

	if ( isdefined( self.emp_fx ) )
	{
		self.emp_fx delete();
	}
	
	self delete();
}


function QRDrone_light_fx()
{
	playFXOnTag( level.chopper_fx["light"]["belly"], self, "tag_light_nose" );
	WAIT_SERVER_FRAME;
	playFXOnTag( level.chopper_fx["light"]["tail"], self, "tag_light_tail1" );	
}


function QRDrone_dialog( dialogGroup )
{
	if ( dialogGroup == "tag" )
		waitTime = 1000;
	else
		waitTime = 5000;
	
	if ( getTime() - level.QRDrone_lastDialogTime < waitTime )
		return;
	
	level.QRDrone_lastDialogTime = getTime();
	
	randomIndex = randomInt( level.QRDrone_dialog[ dialogGroup ].size );
	soundAlias = level.QRDrone_dialog[ dialogGroup ][ randomIndex ];

	self playLocalSound( soundAlias );
}

function QRDrone_watchHeliProximity()
{
	level endon( "game_ended" );
	self  endon( "death" );
	self  endon( "end_remote" );
	
	while( true )
	{
		inHeliProximity = false;
		
		if ( !self.inHeliProximity && inHeliProximity )
			self.inHeliProximity = true;
		else if ( self.inHeliProximity && !inHeliProximity )
		{
			self.inHeliProximity = false;
			self.heliInProximity = undefined;
		}
		
		WAIT_SERVER_FRAME;
	}
}


function QRDrone_detonateWaiter()
{
	self.owner endon("disconnect"); 
	self endon("death"); 
	
	while( self.owner attackbuttonpressed() ) 
		WAIT_SERVER_FRAME;

	watcher = self.owner weaponobjects::getWeaponObjectWatcher( "qrdrone" );
		
	while( !self.owner attackbuttonpressed() ) 
		WAIT_SERVER_FRAME;
		
	self clientfield::set( "qrdrone_state", QRDRONE_FX_DEATH );
	watcher thread weaponobjects::waitAndDetonate(self,0);
	
	self.owner thread hud::fade_to_black_for_x_sec( GetDvarfloat( "scr_rcbomb_fadeOut_delay" ), GetDvarfloat( "scr_rcbomb_fadeOut_timeIn" ), GetDvarfloat( "scr_rcbomb_fadeOut_timeBlack" ), GetDvarfloat( "scr_rcbomb_fadeOut_timeOut" ) );
}

function QRDrone_fireGuns( QRDrone )
{
	self endon ( "disconnect" );
	QRDrone endon ( "death" );
	QRDrone endon ( "blowup" );
	QRDrone endon ( "crashing" );
	level endon ( "game_ended" );
	QRDrone endon ( "end_remote" );	
	
	//	transition into remote
	wait( 1 );
	
	while ( true )
	{	
		if ( self AttackButtonPressed() )
		{
			QRDrone FireWeapon();
			weapon = GetWeapon( "qrdrone_turret" );
			fireTime = weapon.fireTime;
			
			wait( fireTime );			
		}
		else
		{
			WAIT_SERVER_FRAME; 				
		}
	}
}

function QRDrone_blowup(attacker, weapon)
{
	self.owner endon("disconnect");
	self endon ("death");

	self notify("blowup");
	
	explosionOrigin = self.origin;
	explosionAngles = self.angles;
	
	if ( !isdefined( attacker ) )
	{
		attacker = self.owner;
	}

	origin = self.origin + (0,0,10);
	radius = 256;
	min_damage = 10;
	max_damage = 35;

	if ( isdefined(attacker) )
	{
		self radiusDamage( origin, radius, max_damage, min_damage, attacker, "MOD_EXPLOSIVE", self.weapon );
	}
	PhysicsExplosionSphere( origin, radius, radius, 1, max_damage, min_damage );
	shellshock::rcbomb_earthquake( origin );

	// CDC - play rc car exlposion sound TO DO replace with final explo sound after effects are in 
	playsoundatposition("veh_qrdrone_explo", self.origin);

	PlayFX( level.QRDrone_fx["explode"] , explosionOrigin, (0, 0, 1 ));
	
	self Hide();
	if( isdefined(self.owner))
	{
		self.owner util::clientNotify("qrdrone_blowup");

		if ( attacker != self.owner )
		{	
			level.globalKillstreaksDestroyed++;
			attacker AddWeaponStat( self.weapon, "destroyed", 1 );
		}	
		self.owner remote_weapons::destroyRemoteHUD();
		
		self.owner util::freeze_player_controls( true );
		self.owner SendKillstreakDamageEvent( 600 );
		wait(0.75);
		self.owner thread hud::fade_to_black_for_x_sec( 0, 0.25, 0.1, 0.25 );
		wait(0.25);
		self.owner QRDrone_Unlink( self );
		self.owner util::freeze_player_controls( false );

		if ( isdefined( self.neverDelete ) && self.neverDelete )
		{
			return;
		}	
	}
	
	QRDrone_cleanup();
}

// self == player
function setVisionsetWaiter()
{
	self endon("disconnect"); 
	
	self UseServerVisionset( true );
	self SetVisionSetForPlayer( level.qrdrone_vision, 1 );

	self.QRDrone waittill("end_remote"); 
	
	self UseServerVisionset( false );
}

function inithud()
{	
}

function destroyHud()
{
	if( isdefined(self) )
	{
		self notify ( "stop_signal_failure" );
		self.flashingSignalFailure = false;
		self clientfield::set_to_player( "static_postfx", 0 );
		
		if ( isdefined( self.fullscreen_static ) )
			self.fullscreen_static destroy();
		
		self remote_weapons::destroyRemoteHUD();
		self util::clientNotify( "nofutz" );
	}
}

function set_static_alpha( alpha, drone )
{
	if ( isdefined( self.fullscreen_static ) )
	{
		self.fullscreen_static.alpha = alpha;
	}
	
	if ( alpha > 0 )
	{
		if( !isdefined( self.flashingSignalFailure ) || !self.flashingSignalFailure )
		{
			self thread flash_signal_failure( drone );
			self.flashingSignalFailure = true;
			if ( self IsRemoteControlling() )
				self clientfield::set_to_player( "static_postfx", 1 );
		}
	}
	else
	{
		self notify ( "stop_signal_failure" );
		drone clientfield::set( "qrdrone_out_of_range", 0 );
		self.flashingSignalFailure = false;
		self clientfield::set_to_player( "static_postfx", 0 );
	}
}

function flash_signal_failure( drone )
{
	self endon( "stop_signal_failure" );
	drone endon( "death" );
	drone clientfield::set( "qrdrone_out_of_range", 1 );
	i = 0;
	for ( ;; )
	{
		drone PlaySoundToPlayer( "uin_alert_lockon", self );
		if ( i < 5 )
			wait ( .6 );
		else if ( i < 6 )
			wait ( 0.5 );
		else
			wait ( .3 );
		i++;
	}
}