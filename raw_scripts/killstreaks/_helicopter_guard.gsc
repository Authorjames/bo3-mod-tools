#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\hostmigration_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\util_shared;
#using scripts\shared\weapons\_heatseekingmissile;

#using scripts\mp\_util;
#using scripts\mp\gametypes\_hostmigration;
#using scripts\mp\gametypes\_spawning;
#using scripts\mp\killstreaks\_airsupport;
#using scripts\mp\killstreaks\_helicopter;
#using scripts\mp\killstreaks\_killstreak_detect;
#using scripts\mp\killstreaks\_killstreak_hacking;
#using scripts\mp\killstreaks\_killstreakrules;
#using scripts\mp\killstreaks\_killstreaks;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "string", "MP_CIVILIAN_AIR_TRAFFIC" );
#precache( "string", "MP_AIR_SPACE_TOO_CROWDED" );
#precache( "string", "KILLSTREAK_EARNED_HELICOPTER_GUARD" );
#precache( "string", "KILLSTREAK_HELICOPTER_GUARD_NOT_AVAILABLE" );
#precache( "string", "KILLSTREAK_HELICOPTER_GUARD_INBOUND" );
#precache( "string", "KILLSTREAK_HELICOPTER_GUARD_HACKED" );
#precache( "eventstring", "mpl_killstreak_lbguard_strt" );
#precache( "fx", "killstreaks/fx_ed_lights_green" );
#precache( "fx", "killstreaks/fx_ed_lights_red" );
#namespace helicopter_guard;

function init()
{
	killstreaks::register("helicopter_guard", "helicopter_guard", "killstreak_helicopter_guard", "helicopter_used",&tryUseheliGuardSupport, true);
	killstreaks::register_alt_weapon( "helicopter_guard", "littlebird_guard_minigun" );
	killstreaks::register_strings("helicopter_guard", &"KILLSTREAK_EARNED_HELICOPTER_GUARD", &"KILLSTREAK_HELICOPTER_GUARD_NOT_AVAILABLE", &"KILLSTREAK_HELICOPTER_GUARD_INBOUND", undefined, &"KILLSTREAK_HELICOPTER_GUARD_HACKED");
	killstreaks::register_dialog("helicopter_guard", "mpl_killstreak_lbguard_strt", "kls_littlebird_used", "","kls_littlebird_enemy", "", "kls_littlebird_ready");
	killstreaks::set_team_kill_penalty_scale( "helicopter_guard", 0.0 );
	
	level._effect["heli_guard_light"]["friendly"] = "killstreaks/fx_ed_lights_green";
	level._effect["heli_guard_light"]["enemy"] = "killstreaks/fx_ed_lights_red";
	
	level.heliGuardFlyOverNFZ = false;
	if ( level.script == "mp_hydro" )
	{
		level.heliGuardFlyOverNFZ = true;
	}
	
	thread register();
}

#define PLAYER_HEIGHT_INCREASE  (0,0,50)
#define HELI_GUARD_FIRE_TIME 	0.15
#define HELI_GUARD_MIN_SHOTS 	10
#define HELI_GUARD_MAX_SHOTS 	20
#define HELI_GUARD_MIN_PAUSE 	1.0
#define HELI_GUARD_MAX_PAUSE 	2.0
#define HELI_GUARD_GUNNER	 	0
#define HELI_GUARD_SPINUP	 	0.2
	
function register()
{
	clientfield::register( "helicopter", "vehicle_is_firing", VERSION_SHIP, 1, "int");	
	clientfield::register( "vehicle", "vehicle_is_firing", VERSION_SHIP, 1, "int");	
}
	
function tryUseheliGuardSupport( lifeId ) // self == player
{
	if ( isdefined( level.civilianJetFlyBy ) )
	{
		self iPrintLnBold( &"MP_CIVILIAN_AIR_TRAFFIC" );
		return false;
	}

	if ( self IsRemoteControlling() )
	{
		return false;
	}	

	if ( !isdefined( level.heli_paths ) || level.heli_paths.size <= 0 )
	{
		self iPrintLnBold( &"MP_UNAVAILABLE_IN_LEVEL" );
		return false;		
	}

	killstreak_id = self killstreakrules::killstreakStart( "helicopter_guard", self.team, false, true );
	if ( killstreak_id == -1 )
	{
		return false;
	}
	
	heliGuard = createHeliGuardSupport( lifeId, killstreak_id );
	if ( !isdefined( heliGuard ) )
		return false;	

	self thread startHeliGuardSupport( heliGuard, lifeId );
	
	return true;
}

function ConfigureTeamPost( owner, isHacked )
{
	heliGuard = self;
	heliGuard thread heliGuardSupport_watchForEarlyLeave();
	heliGuard thread heliGuardSupport_watchOwnerDamage();
}

function createHeliGuardSupport( lifeId, killstreak_id )
{
	owner = self;
	hardpointType = "helicopter_guard";
	closestStartNode = heliGuardSupport_getClosestStartNode( owner.origin );	
	if( isdefined( closestStartNode.angles ) )
		startAng = closestStartNode.angles;
	else
		startAng = ( 0, 0, 0);

	closestNode = heliGuardSupport_getClosestNode( owner.origin );	
	flyHeight = max( owner.origin[2] + 1600, airsupport::getNoFlyZoneHeight( owner.origin ) );
	forward = anglesToForward( owner.angles );
	targetPos = ( owner.origin*(1,1,0) ) + ( (0,0,1)*flyHeight ) + ( forward * -100 );
	
	startPos = closestStartNode.origin;
	
	heliGuard = spawnHelicopter( owner, startPos, startAng, "heli_guard_mp", "veh_t6_drone_overwatch_light" );
	if ( !isdefined( heliGuard ) )
		return;

	heliGuard.harpointType = hardpointType;
	
	heliGuard killstreaks::configure_team( hardpointType, killstreak_id, owner, "helicopter", undefined, &ConfigureTeamPost );
	heliGuard killstreak_hacking::enable_hacking( hardpointType );
	
	Target_Set( heliGuard, (0,0,-50) );
	
	heliguard setEnemyModel("veh_t6_drone_overwatch_dark");
	heliGuard.speed = 150;
	heliGuard.followSpeed = 40;
	heliGuard setCanDamage( true );
	heliGuard SetMaxPitchRoll( 45, 45 );	
	heliGuard SetSpeed( heliGuard.speed, 100, 40 );
	heliGuard SetYawSpeed( 120, 60 );
	heliGuard setneargoalnotifydist( 512 );
	heliGuard clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );
		
	heliGuard thread heliGuardSupport_attackTargets();
	
	heliGuard.killCount = 0;
	heliGuard.streakName = "littlebird_support";
	heliGuard.heliType = "littlebird";
	heliGuard.targettingRadius = 2000; // matches the maxRange on the turret gdt setting

	heliGuard.targetPos = targetPos;
	heliGuard.currentNode = closestNode;

	heliGuard.attract_strength = 10000;
	heliGuard.attract_range = 150;
	heliGuard.attractor = Missile_CreateAttractorEnt( heliGuard, heliGuard.attract_strength, heliGuard.attract_range );
	heliGuard.health = 999999; // keep it from dying anywhere in code
	heliGuard.maxHealth = level.heli_maxhealth; // this is the health we'll check
	heliGuard.rocketDamageOneShot = heliGuard.maxhealth + 1;
	heliGuard.crashType = "explode";// just explode
	heliGuard.destroyFunc =&lbExplode;
	heliGuard.targeting_delay = level.heli_targeting_delay;
	heliGuard.hasDodged = false;
	heliGuard SetDrawInfrared( true );
	
	owner thread helicopter::announceHelicopterInbound( hardpointType );

	heliGuard thread helicopter::heli_targeting( false, hardpointType );
	heliGuard thread helicopter::wait_for_killed();									// monitors player kills
	heliGuard thread helicopter::heli_health(hardpointtype, undefined );	

	killstreakTimeout = 60.0;

	heliGuard thread killstreaks::WaitForTimeout( hardpointType, killstreakTimeout, &heliGuardSupport_leave, "leaving", "death" );
	heliGuard thread heliGuardSupport_watchRoundEnd();

	heliGuard.numFlares = 1;
	heliGuard.flareOffset = (0,0,0);						
	heliGuard thread heatseekingmissile::MissileTarget_ProximityDetonateIncomingMissile("explode", "death");			// fires chaff if needed
	heliGuard thread helicopter::create_flare_ent( (0,0,-50) );

	heliGuard.killstreak_id = killstreak_id;

	level.littlebirdGuard = heliGuard;

	return heliGuard;
}

function getMeshHeight( littleBird, owner )
{
	if ( !(owner isInsideHeightLock()) )
	{
		return airsupport::getMinimumFlyHeight();
	}
	
    maxMeshHeight = littleBird GetHeliHeightLockHeight( owner.origin );
	return max( maxMeshHeight, owner.origin[2] ); 
}

function startHeliGuardSupport( littleBird, lifeId ) // self == player
{			
	level endon( "game_ended" );
	littleBird endon( "death" );
	
	// look at the player
	littleBird SetLookAtEnt( self );
	
	//	go to pos	
	maxMeshHeight = getMeshHeight( littleBird, self );
	height = airsupport::getNoFlyZoneHeight((self.origin[0], self.origin[1], maxMeshHeight ));
	playerMeshOrigin = (self.origin[0], self.origin[1], height);
	vecToStart = VectorNormalize(littleBird.origin - littleBird.targetPos);
	dist = 1500;
	target = littleBird.targetPos + vecToStart * dist;
	collide = airsupport::crossesNoFlyZone(target, playerMeshOrigin);
	while ( isdefined(collide) && dist > 0)
	{
		dist = dist - 500;	
		target = littleBird.targetPos + vecToStart * dist;
		collide = airsupport::crossesNoFlyZone(target, playerMeshOrigin);
	}
	
	littleBird setVehGoalPos( target, 1 );
	Target_SetTurretAquire( littleBird, false );

	littleBird waittill( "near_goal" );
	Target_SetTurretAquire( littleBird, true );
	littleBird SetVehGoalPos( playerMeshOrigin, 1);
	littleBird waittill( "near_goal" );
	littleBird SetSpeed( littleBird.speed, 80, 30 );	
	littleBird waittill ( "goal" );	
	
	//	begin following player	
	littleBird thread heliGuardSupport_followPlayer();

	// dodge the first sam attack
	//littleBird thread helicopter::handleIncomingSAM(&heliGuardSupport_watchSAMProximity );
}


function heliGuardSupport_followPlayer() // self == heliGuard
{
	level endon( "game_ended" );
	self endon( "death" );
	self endon( "leaving" );

	if( !isdefined( self.owner ) )
	{
		self thread heliGuardSupport_leave();
		return;
	}
	
	self SetSpeed( self.followSpeed, 20, 20 );
	while( true )
	{
		if( isdefined( self.owner ) && IsAlive( self.owner ) )
		{
			heliGuardSupport_moveToPlayer();
		}
		wait( 3 );
	}
}


function heliGuardSupport_moveToPlayer() // self == heliGuard
{
	self notify( "heliGuardSupport_moveToPlayer" );
	self endon( "heliGuardSupport_moveToPlayer" );
	
	level endon( "game_ended" );
	self endon( "death" );
	self endon( "leaving" );
	self.owner endon( "death" );
	self.owner endon( "disconnect" );
	self.owner endon( "joined_team" );
	self.owner endon( "joined_spectators" );

	maxMeshHeight = getMeshHeight( self, self.owner );

	hoverGoal = ( self.owner.origin[0], self.owner.origin[1], maxMeshHeight );

	zoneIndex = airsupport::crossesNoFlyZone( self.origin, hoverGoal );
	if ( isdefined( zoneIndex ) && level.heliGuardFlyOverNFZ )
	{
	    self.inTransit = true;
		
	    noFlyZoneHeight = airsupport::getNoFlyZoneHeightCrossed( hoverGoal, self.origin, maxMeshHeight );
	    self setVehGoalPos(( hoverGoal[0], hoverGoal[1], noFlyZoneHeight ), true );
		self waittill ( "goal" );
		return;
	}
	
	if ( isdefined( zoneIndex ) )
	{
		dist = Distance2D( self.owner.origin, level.noFlyZones[zoneIndex].origin );

		zoneOrgToPlayer2D = self.owner.origin - level.noFlyZones[zoneIndex].origin;
		zoneOrgToPlayer2D *= (1,1,0);

		zoneOrgToChopper2D = self.origin - level.noFlyZones[zoneIndex].origin;
		zoneOrgToChopper2D *= (1,1,0);

		zoneOrgAtMeshHeight = ( level.noFlyZones[zoneIndex].origin[0], level.noFlyZones[zoneIndex].origin[1], maxMeshHeight );

		// adjacent to the no fly zone closest to the player
		zoneOrgToAdjPos = VectorScale( VectorNormalize( zoneOrgToPlayer2D ), level.noFlyZones[ zoneIndex ].radius + 150.0 );

		adjacentGoalPos = zoneOrgToAdjPos + level.noFlyZones[zoneIndex].origin;
		adjacentGoalPos = ( adjacentGoalPos[0], adjacentGoalPos[1], maxMeshHeight );
		
		zoneOrgToPerpendicular = ( zoneOrgToAdjPos[1], -zoneOrgToAdjPos[0], 0 );
		zoneOrgToOppositePerpendicular = ( -zoneOrgToAdjPos[1], zoneOrgToAdjPos[0], 0 );

		perpendicularGoalPos = zoneOrgToPerpendicular + zoneOrgAtMeshHeight;
		oppositePerpendicularGoalPos = zoneOrgToOppositePerpendicular + zoneOrgAtMeshHeight;

		if ( dist < level.noFlyZones[zoneIndex].radius )
		{
			zoneIndex = undefined;
			zoneIndex = airsupport::crossesNoFlyZone( self.origin, adjacentGoalPos );

			if ( isdefined( zoneIndex ))
			{
				hoverGoal = perpendicularGoalPos;
			}
			else
			{
				hoverGoal = adjacentGoalPos;
			}			
		}
		else
		{
			// player is outside the radius, but a no fly zone is in the way
			// try to set new goal tangent to the offending no fly zone in the direction of the player
			hoverGoal = perpendicularGoalPos;
		}
	}
	
	zoneIndex = undefined;
	zoneIndex = airsupport::crossesNoFlyZone( self.origin, hoverGoal );
	if ( isdefined( zoneIndex ))
	{
		hoverGoal = oppositePerpendicularGoalPos;
	}

	self.inTransit = true;
		
	self setVehGoalPos(( hoverGoal[0], hoverGoal[1], maxMeshHeight ), true );
	self waittill ( "goal" );
}

function heliGuardSupport_moveToPlayerVertical ( maxMeshHeight ) // self == heli
{
	height = airsupport::getNoFlyZoneHeightCrossed( self.origin, self.owner.origin,  maxMeshHeight );
	upperHeight = max( self.origin[2], height );	
	
	acquireUpperHeight = ( self.origin[0], self.origin[1], upperHeight );
	hoverOverPlayer = ( self.owner.origin[0], self.owner.origin[1], upperHeight );
	hoverCorrectHeight = ( self.owner.origin[0], self.owner.origin[1], height );	
	
	self.inTransit = true; // needed?
	self setVehGoalPos( acquireUpperHeight, true ); 
	self waittill ( "goal" );
	
	self setVehGoalPos( hoverOverPlayer, true ); 
	self waittill ( "goal" );

	self setVehGoalPos( hoverCorrectHeight, true ); 
	self waittill ( "goal" );
	
	self.inTransit = false;
}

//
//	state trackers
//

function heliGuardSupport_watchForEarlyLeave()
{
	self notify( "heliGuardSupport_watchForEarlyLeave" );
	self endon( "heliGuardSupport_watchForEarlyLeave" );
	level endon ( "game_ended" );
	self endon( "death" );
	self endon( "leaving" );

	self.owner util::waittill_any( "disconnect", "joined_team", "joined_spectators" );	
		
	//	leave
	self thread heliGuardSupport_leave();
}

function heliGuardSupport_watchOwnerDamage() // self == heliGuard
{
	self notify( "heliGuardSupport_watchOwnerDamage" );
	self endon( "heliGuardSupport_watchOwnerDamage" );
	level endon ( "game_ended" );
	self endon( "death" );
	self endon( "leaving" );	
	self.owner endon( "disconnect" );
	self.owner endon( "joined_team" );
	self.owner endon( "joined_spectators" );

	while( true )
	{
		// if someone is attacking the owner, attack them
		self.owner waittill( "damage", damage, attacker, direction_vec, point, meansOfDeath, modelName, tagName, partName, weapon, iDFlags );

		if( isPlayer( attacker ) )
		{					
			if( attacker != self.owner && Distance2D( attacker.origin, self.origin ) <= self.targettingRadius && attacker airsupport::canTargetPlayerWithSpecialty() )
			{
				self SetLookAtEnt( attacker );
				self setGunnerTargetEnt( attacker, PLAYER_HEIGHT_INCREASE, HELI_GUARD_GUNNER );
				self setturrettargetent( attacker, PLAYER_HEIGHT_INCREASE );
			}
		}
	}		
}

function heliGuardSupport_watchRoundEnd()
{
	level endon ( "game_ended" );
	self endon( "death" );
	self endon( "leaving" );	
	self.owner endon( "disconnect" );
	self.owner endon( "joined_team" );
	self.owner endon( "joined_spectators" );	

	level waittill ( "round_end_finished" );

	//	leave
	self thread heliGuardSupport_leave();
}

function heliGuardSupport_leave()
{
	self endon( "death" );
	self notify( "leaving" );
	level.littlebirdGuard = undefined;

	self cleargunnertarget(HELI_GUARD_GUNNER);
	self clearturrettarget();

	//	rise
	self ClearLookAtEnt();
	flyHeight = airsupport::getNoFlyZoneHeight( self.origin );
	targetPos = self.origin + anglesToForward( self.angles ) * 1500 + (0,0,flyHeight);
	collide = airsupport::crossesNoFlyZone(self.origin, targetPos);
	tries = 5;
	while ( isdefined( collide ) && tries > 0 )
	{
		yaw = RandomInt(360);
		targetPos = self.origin + anglesToForward( (self.angles[0], yaw, self.angles[2]) ) * 1500 + (0,0,flyHeight);
		collide = airsupport::crossesNoFlyZone(self.origin, targetPos);		
		tries--;
	}
	if ( tries == 0 )
	{
		targetPos = self.origin + (0,0,flyHeight);
	}
	self SetSpeed( self.speed, 80 );
	self SetMaxPitchRoll( 45, 180 );
	self setVehGoalPos( targetPos );
	self waittill ( "goal" );	
	
	//	leave
	targetPos = targetPos + anglesToForward( (0,self.angles[1],self.angles[2]) ) * 14000;
	self setVehGoalPos( targetPos );
	self waittill ( "goal" );
	
	//	remove
	self notify( "gone" );	
	self removeLittlebird();
}

function heliDestroyed()
{
	level.littlebirdGuard = undefined;
	
	if (! isdefined(self) )
		return;
		
	self SetSpeed( 25, 5 );
	self thread lbSpin( RandomIntRange(180, 220) );
	
	wait( RandomFloatRange( .5, 1.5 ) );
	
	lbExplode();
}

function lbExplode()
{
	self notify ( "explode" );
	
	self removeLittlebird();
}

function lbSpin( speed )
{
	self endon( "explode" );
	
	// tail explosion that caused the spinning
	playfxontag( level.chopper_fx["explode"]["large"], self, "tail_rotor_jnt" );
 	self thread trail_fx( level.chopper_fx["smoke"]["trail"], "tail_rotor_jnt", "stop tail smoke" );
	
	self setyawspeed( speed, speed, speed );
	while ( isdefined( self ) )
	{
		self settargetyaw( self.angles[1]+(speed*0.9) );
		wait ( 1 );
	}
}

function trail_fx( trail_fx, trail_tag, stop_notify )
{
	// only one instance allowed
	self notify( stop_notify );
	self endon( stop_notify );
	self endon( "death" );
		
	for ( ;; )
	{
		playfxontag( trail_fx, self, trail_tag );
		WAIT_SERVER_FRAME;
	}
}

function removeLittlebird()
{	
	level.lbStrike = 0;
	killstreakrules::killstreakStop( "helicopter_guard", self.originalteam, self.killstreak_id );
	
	self spawning::remove_influencers();
	
	if( isdefined( self.marker ) )
		self.marker delete();
	
	self delete();
}

// this is different from the flares monitoring that the other helicopters do
// we want this to dodge the missiles if at all possible, making for a cool evasive manuever
function heliGuardSupport_watchSAMProximity( player, missileTeam, missileTarget, missileGroup ) // self == level
{
	level endon ( "game_ended" );
	missileTarget endon( "death" );

	for( i = 0; i < missileGroup.size; i++ )
	{
		if( isdefined( missileGroup[ i ] ) && !missileTarget.hasDodged )
		{
			missileTarget.hasDodged = true;			

			newTarget = spawn( "script_origin", missileTarget.origin );
			newTarget.angles = missileTarget.angles;
			newTarget MoveGravity( AnglesToRight( missileGroup[ i ].angles ) * -1000, 0.05 );
			//newTarget thread helicopter::deleteAfterTime( 5.0 );

			for( j = 0; j < missileGroup.size; j++ )					
			{
				if( isdefined( missileGroup[ j ] ) )
				{
					missileGroup[ j ] SetTargetEntity( newTarget );
				}
			}

			// dodge the incoming missiles
			dodgePoint = missileTarget.origin + ( AnglesToRight( missileGroup[ i ].angles ) * 200 );
			missileTarget SetSpeed( missileTarget.speed, 100, 40 );
			missileTarget SetVehGoalPos( dodgePoint, true );

			wait( 2.0 );
			missileTarget SetSpeed( missileTarget.followSpeed, 20, 20 );
			break;
		}	
	}
}

//
//	node funcs
//

function heliGuardSupport_getClosestStartNode( pos )
{
	// gets the start node that is closest to the position passed in
	closestNode = undefined;
	closestDistance = 999999;

	foreach( path in level.heli_paths )
	{
		foreach( loc in path )
		{ 	
			nodeDistance = distance( loc.origin, pos );
			if ( nodeDistance < closestDistance )
			{
				closestNode = loc;
				closestDistance = nodeDistance;
			}
		}
	}

	return closestNode;
}

function heliGuardSupport_getClosestNode( pos )
{
	// gets the closest node to the position passed in, regardless of link
	closestNode = undefined;
	closestDistance = 999999;

	foreach( loc in level.heli_loop_paths )
	{ 	
		nodeDistance = distance( loc.origin, pos );
		if ( nodeDistance < closestDistance )
		{
			closestNode = loc;
			closestDistance = nodeDistance;
		}
	}
	
	return closestNode;
}

function heliGuardSupport_getClosestLinkedNode( pos ) // self == heliGuard
{
	// gets the linked node that is closest to the current position and moving towards the position passed in
	closestNode = undefined;
	totalDistance = Distance2D( self.currentNode.origin, pos );
	closestDistance = totalDistance;

	target = self.currentNode.target;

	while( isdefined( target ) )
	{
		nextNode = GetEnt( target, "targetname" );

		if ( nextNode == self.currentNode )
		{
			break;
		}

		nodeDistance = Distance2D( nextNode.origin, pos );
		if ( nodeDistance < totalDistance && nodeDistance < closestDistance )
		{
			closestNode = nextNode;
			closestDistance = nodeDistance;
		}

		target = nextNode.target;
	}

	return closestNode;
}

function heliGuardSupport_arrayContains( array, compare )
{
	if ( array.size <= 0 )
		return false;

	foreach ( member in array )
	{
		if ( member == compare )
			return true;
	}

	return false;
}


function heliGuardSupport_getLinkedStructs()
{
	array = [];
	return array;
}

function heliGuardSupport_setAirStartNodes()
{
	level.air_start_nodes = struct::get_array( "chopper_boss_path_start", "targetname" );

	foreach( loc in level.air_start_nodes )
	{
		// Grab array of path loc refs that this loc links to
		loc.neighbors = loc heliGuardSupport_getLinkedStructs();
	}	
}

function heliGuardSupport_setAirNodeMesh()
{
	level.air_node_mesh = struct::get_array( "so_chopper_boss_path_struct", "script_noteworthy" );
	
	foreach( loc in level.air_node_mesh )
	{
		// Grab array of path loc refs that this loc links to
		loc.neighbors = loc heliGuardSupport_getLinkedStructs();
		
		// Step through each loc in the map and if it
		// links to this loc, add it
		foreach( other_loc in level.air_node_mesh )
		{
			if ( loc == other_loc )
				continue;
			
			if ( !heliGuardSupport_arrayContains( loc.neighbors, other_loc ) && heliGuardSupport_arrayContains( other_loc heliGuardSupport_getLinkedStructs(), loc ) )
				loc.neighbors[ loc.neighbors.size ] = other_loc;
		}
	}	
}

/* ============================
Turret Logic Functions
============================ */

function heliGuardSupport_attackTargets() // self == turret
{
	self endon( "death" );
	level endon( "game_ended" );
	self endon( "leaving" );

	for (;;)
	{
		self heliGuardSupport_fireStart();
	}
}

function heliGuardSupport_fireStart() // self == turret
{
	self endon( "death" );
	self endon( "leaving" );
	self endon( "stop_shooting" );
	level endon( "game_ended" );

	for ( ;; )
	{		
		numShots = RandomIntRange( HELI_GUARD_MIN_SHOTS, HELI_GUARD_MAX_SHOTS + 1 );

		if ( !isdefined( self.primaryTarget ) ) 
		{
			self waittill( "primary acquired");
		}

		if ( isdefined( self.primaryTarget ) )
		{
			targetEnt = self.primaryTarget;
			self thread heliGuardSupport_fireStop( targetEnt );
			
			self SetLookAtEnt( targetEnt );
			
			self setGunnerTargetEnt( targetEnt, PLAYER_HEIGHT_INCREASE, HELI_GUARD_GUNNER );
			self setturrettargetent( targetEnt, PLAYER_HEIGHT_INCREASE );
			self waittill( "turret_on_target" );
			
			wait( HELI_GUARD_SPINUP );

			self clientfield::set("vehicle_is_firing", 1);
			
			for ( i = 0; i < numShots; i++ )
			{
				self fireWeapon( HELI_GUARD_GUNNER + 1, undefined, undefined, self );
				self fireweapon();
				wait ( HELI_GUARD_FIRE_TIME );
			}
		}
		
		self clientfield::set("vehicle_is_firing", 0);
		//level util::clientNotify("nofir");	
		
		self clearturrettarget();
		self cleargunnertarget(HELI_GUARD_GUNNER);
		wait ( RandomFloatRange( HELI_GUARD_MIN_PAUSE, HELI_GUARD_MAX_PAUSE ) );
	}
}

function heliGuardSupport_fireStop( targetEnt ) // self == turret
{
	self endon( "death" );
	self endon( "leaving" );
	self notify( "heli_guard_target_death_watcher" );
	self endon( "heli_guard_target_death_watcher" );

	targetEnt util::waittill_any( "death", "disconnect" );

	self clientfield::set("vehicle_is_firing", 0);
			
	self notify( "stop_shooting" );
	self.primaryTarget = undefined;
	self SetLookAtEnt( self.owner );
	self cleargunnertarget(HELI_GUARD_GUNNER);
	self clearturrettarget();
}

/* ============================
END Turret Logic Functions
============================ */
