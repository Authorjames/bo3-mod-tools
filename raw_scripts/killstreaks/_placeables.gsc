#using scripts\codescripts\struct;

#using scripts\shared\_oob;
#using scripts\shared\clientfield_shared;
#using scripts\shared\killstreaks_shared;
#using scripts\shared\util_shared;

#using scripts\mp\_util;
#using scripts\mp\killstreaks\_killstreaks;
#using scripts\mp\killstreaks\_killstreak_detect;

#insert scripts\mp\_hacker_tool.gsh;
#insert scripts\shared\shared.gsh;

#namespace placeables;

#define PLACEABLE_OFFSET 40
#define PLACEABLE_MOVEABLE_TIMEOUT_EXTENSION 5000

function SpawnPlaceable( killstreakRef, killstreakId, 
	                     onPlaceCallback, onCancelCallback, onMoveCallback, onShutdownCallback, onDeathCallback, onEmpCallback,
	                     model, validModel, invalidModel, spawnsVehicle,
	                     pickupString,
	                     timeout,
	                     health,
						 empDamage,
						 placeHintString,
						 invalidLocationHintString )
{
	player = self;
	
	self killstreaks::switch_to_last_non_killstreak_weapon();
	
	placeable = spawn( "script_model", player.origin );	
	placeable.cancelable = true;
	placeable.held = false;
	placeable.validModel = validModel;
	placeable.invalidModel = invalidModel;
	placeable.killstreakId = killstreakId;
	placeable.killstreakRef = killstreakRef;
	placeable.onCancel = onCancelCallback;
	placeable.onEmp = onEmpCallback;
	placeable.onMove = onMoveCallback;
	placeable.onPlace = onPlaceCallback;
	placeable.onShutdown = onShutdownCallback;
	placeable.onDeath = onDeathCallback;
	placeable.owner = player;
	placeable.originalOwner = player;
	placeable.ownerEntNum = player.entNum;
	placeable.originalOwnerEntNum = player.entNum;
	placeable.pickupString = pickupString;
	placeable.placedModel = model;
	placeable.spawnsVehicle = spawnsVehicle;

	placeable.originalTeam = player.team;
	placeable.timedOut = false;
	placeable.timeout = timeout;
	placeable.timeoutStarted = false;
	placeable.angles = ( 0, player.angles[1], 0 );
	placeable.placeHintString = placeHintString;
	placeable.invalidLocationHintString = invalidLocationHintString;
	
	DEFAULT( placeable.placeHintString, "" );
	DEFAULT( placeable.invalidLocationHintString, "" );
	
	placeable NotSolid();
	if ( isdefined( placeable.vehicle ) )
		placeable.vehicle NotSolid();
	
	placeable.otherModel = spawn( "script_model", player.origin );
	placeable.otherModel SetModel( placeable.placedModel );
	placeable.otherModel SetInvisibleToPlayer( player );
	placeable.otherModel NotSolid();
	placeable.otherModel clientfield::set( "enemyvehicle", ENEMY_VEHICLE_ACTIVE );

	placeable killstreaks::configure_team( killstreakRef, killstreakId, player );
	
	if( isdefined( health ) && health > 0 )
	{
		placeable.health = health;
		placeable SetCanDamage( false );
		placeable thread killstreaks::MonitorDamage( killstreakRef, health, &OnDeath, 0, undefined, empDamage, &OnEMP, true );
	}
	
	player thread CarryPlaceable( placeable );
	level thread CancelOnGameEnd( placeable );
	
	player thread ShutdownOnCancelEvent( placeable );
	player thread CancelOnPlayerDisconnect( placeable );
	
	placeable thread WatchOwnerGameEvents();
	
	return placeable;
}

function UpdatePlacementModels( model, validModel, invalidModel )
{
	placeable = self;
	placeable.placedModel = model;
	placeable.validModel = validModel;
	placeable.invalidModel = invalidModel;
}

function CarryPlaceable( placeable )
{
	player = self;
	
	placeable Show();
	placeable NotSolid();
	if ( isdefined( placeable.vehicle ) )
		placeable.vehicle NotSolid();
	
	if ( isdefined( placeable.otherModel ) )
	{
		placeable thread util::ghost_wait_show_to_player( player, 0.05, "abort_ghost_wait_show" );
		placeable.otherModel thread util::ghost_wait_show_to_others( player, 0.05, "abort_ghost_wait_show" );
		placeable.otherModel NotSolid();		
	}
	
	placeable.held = true;
	player.holding_placeable = placeable;
	
	player CarryTurret( placeable, ( PLACEABLE_OFFSET, 0, 0 ), ( 0, 0, 0 ) );
	player util::_disableWeapon();
	player thread WatchPlacement( placeable );
}

function InNoPlacementTrigger()
{
	placeable = self;	
	
	if( isdefined( level.noTurretPlacementTriggers ) )
	{
		for( i = 0; i < level.noTurretPlacementTriggers.size; i++ )
		{
			if( placeable IsTouching( level.noTurretPlacementTriggers[i] ) )
			{
				return true;
			}
		}
	}
	
	if( isdefined( level.fatal_triggers ) )
	{
		for( i = 0; i < level.fatal_triggers.size; i++ )
		{
			if( placeable IsTouching( level.fatal_triggers[i] ) )
			{
				return true;
			}
		}	
	}
	
	if( placeable oob::IsTouchingAnyOOBTrigger() )
	{
		return true;
	}
	
	return false;
}

function WatchPlacement( placeable )
{
	player = self;
	
	player endon( "disconnect" );
	player endon( "death" );
	placeable endon( "placed" );
	placeable endon( "cancelled" );
	
	player thread WatchCarryCancelEvents( placeable );
	
  	lastAttempt = -1;
  	placeable.canBePlaced = false;
	waitingForAttackButtonRelease = true;
	
	while( true )
	{
		placement = player CanPlayerPlaceTurret();

		placeable.origin = placement["origin"];
		placeable.angles = placement["angles"];
		placeable.canBePlaced = placement["result"] && !( placeable InNoPlacementTrigger() );

		if ( player.laststand === true )
		{
			placeable.canBePlaced = false;
		}

		if ( isdefined( placeable.otherModel ) )
		{
			placeable.otherModel.origin = placement["origin"];
			placeable.otherModel.angles = placement["angles"];			
		}
		
		if( placeable.canBePlaced != lastAttempt )
		{
			if( placeable.canBePlaced )
			{
				placeable SetModel( placeable.validModel );
				player SetHintString( IString( placeable.placeHintString ) );
			}
			else
			{
				placeable SetModel( placeable.invalidModel );
				player SetHintString( IString( placeable.invalidLocationHintString ) );
			}
			
			lastAttempt = placeable.canBePlaced;
		}

		while( waitingForAttackButtonRelease && !player AttackButtonPressed() )
		{
			waitingForAttackButtonRelease = false;
		}
		
		if( !waitingForAttackButtonRelease && placeable.canBePlaced && player AttackButtonPressed() )
		{
			if( placement["result"] )
			{
				placeable.origin = placement["origin"];
				placeable.angles = placement["angles"];
				
				player SetHintString( "" );
				player StopCarryTurret( placeable );
				
				if( !player util::isWeaponEnabled() )
				{
					player util::_enableWeapon();	
				}
				
				placeable.held = false;
				player.holding_placeable = undefined;
				placeable.cancelable = false;
				
				if( IS_TRUE( placeable.health ) )
				{
					placeable SetCanDamage( true );
					placeable Solid();
				}
				
				if ( isdefined( placeable.vehicle ) )
				{
					placeable.vehicle SetCanDamage( true );
					placeable.vehicle Solid();
				}
				
				if( isdefined( placeable.placedModel ) && !placeable.spawnsVehicle )
				{
					placeable SetModel( placeable.placedModel );
				}
				else
				{
					placeable notify( "abort_ghost_wait_show" );
					placeable.abort_ghost_wait_show_to_player = true;
					placeable.abort_ghost_wait_show_to_others = true;
					placeable Ghost(); // need to ghost instead of hide because of resulting issue with client side animations
					
					if ( isdefined( placeable.otherModel ) )
					{
						placeable.otherModel notify( "abort_ghost_wait_show" );
						placeable.otherModel.abort_ghost_wait_show_to_player = true;
						placeable.otherModel.abort_ghost_wait_show_to_others = true;
						placeable.otherModel Ghost();  // need to ghost instead of hide because of resulting issue with client side animations
					}
				}
				
				if( isdefined( placeable.timeout ) )
				{
					if( !placeable.timeoutStarted )
					{
						placeable.timeoutStarted = true;
						placeable thread killstreaks::WaitForTimeout( placeable.killstreakRef, placeable.timeout, &OnTimeout, "death", "cancelled" );
					}
					else if( placeable.timedOut )
					{
						placeable thread killstreaks::WaitForTimeout( placeable.killstreakRef, PLACEABLE_MOVEABLE_TIMEOUT_EXTENSION, &OnTimeout, "cancelled" );
					}
				}
				
				if( isdefined( placeable.onPlace )  )
				{
					player [[ placeable.onPlace ]]( placeable );
					if( isdefined( placeable.onMove ) && !placeable.timedOut )
					{
						SpawnMoveTrigger( placeable, player );
					}
				}
								
				placeable notify( "placed" );
			}
		}

		if( placeable.cancelable && player ActionSlotFourButtonPressed() )
		{
			placeable notify( "cancelled" );
		}
		
		WAIT_SERVER_FRAME;
	}
}

function WatchCarryCancelEvents( placeable )
{
	player = self;
	assert( IsPlayer( player ) );

	placeable endon( "cancelled" );
	placeable endon( "placed" );
	
	player util::waittill_any( "death", "emp_jammed", "emp_grenaded", "disconnect", "joined_team" );
	placeable notify( "cancelled" );
}

function OnTimeout()
{
	placeable = self;
	if( IS_TRUE( placeable.held ) )
	{
		placeable.timedOut = true;
		return;
	}
	
	placeable notify( "delete_placeable_trigger" );
	placeable thread killstreaks::WaitForTimeout( placeable.killstreakRef, PLACEABLE_MOVEABLE_TIMEOUT_EXTENSION, &ForceShutdown, "cancelled" );
}

function OnDeath( attacker, weapon )
{
	placeable = self;
	
	if( isdefined( placeable.onDeath ) )
	{
		[[ placeable.onDeath ]]( attacker, weapon );
	}
	
	placeable notify( "cancelled" );
}

function OnEMP( attacker )
{
	placeable = self;
	
	if( isdefined( placeable.onEmp ) )
	{
		placeable [[ placeable.onEmp ]]( attacker );
	}
}
	
function CancelOnPlayerDisconnect( placeable )
{
	placeable endon( "hacked" );
	
	player = self;
	assert( IsPlayer( player ) );
	
	placeable endon( "cancelled" );
	placeable endon( "death" );

	player util::waittill_any( "disconnect", "joined_team" );
	placeable notify( "cancelled" );
}

function CancelOnGameEnd( placeable )
{
	placeable endon( "cancelled" );
	placeable endon( "death" );

	level waittill( "game_ended" );
	placeable notify( "cancelled" );
}

function SpawnMoveTrigger( placeable, player )
{
	pos = placeable.origin + ( 0, 0, 15 );
	placeable.pickupTrigger = spawn( "trigger_radius_use", pos );
	placeable.pickupTrigger SetCursorHint( "HINT_NOICON", placeable );
	placeable.pickupTrigger SetHintString( placeable.pickupString );
	placeable.pickupTrigger SetTeamForTrigger( player.team );
	
	player ClientClaimTrigger( placeable.pickupTrigger );
	placeable thread WatchPickup( player);
	placeable.pickupTrigger thread WatchMoveTriggerShutdown( placeable );
}

function WatchMoveTriggerShutdown( placeable )
{
	trigger = self;
	placeable util::waittill_any( "cancelled", "picked_up", "death", "delete_placeable_trigger", "hacker_delete_placeable_trigger" );
	placeable.pickupTrigger delete();
}

function WatchPickup( player )
{
	placeable = self;
	placeable endon( "death" );
	placeable endon( "cancelled" );
	
	assert( isdefined( placeable.pickupTrigger ) );
	trigger = placeable.pickupTrigger;
	
	while ( true )
	{
		trigger waittill( "trigger", player );
		
		if( !isAlive( player ) )
		{
			continue;
		}
		
		if( player isUsingOffhand() )
		{
			continue;
		}

		if( !player isOnGround() )
		{
			continue;
		}
		
		if ( isdefined( placeable.vehicle ) && ( placeable.vehicle.control_initiated === true ) )
		{
			continue;
		}

		if ( isdefined( player.carryObject ) && player.carryObject.disallowPlaceablePickup === true )
		{
			continue;
		}
		
		if( isdefined( trigger.triggerTeam ) && ( player.team != trigger.triggerTeam ) )
		{
			continue;
		}
		
		if( isdefined( trigger.claimedBy ) && ( player != trigger.claimedBy ) )
		{
			continue;
		}
		
		if( player useButtonPressed() && !player.throwingGrenade && !player meleeButtonPressed() && !player attackButtonPressed() && 
		   !IS_TRUE( player.isPlanting ) && !IS_TRUE( player.isDefusing ) && !player IsRemoteControlling() && !isdefined( player.holding_placeable ) )
		{
			placeable notify( "picked_up" );
			placeable.held = true;
			placeable SetCanDamage( false );
			assert( isdefined( placeable.onMove ) );
			player [[ placeable.onMove ]]( placeable );
			player thread CarryPlaceable( placeable );
			return;
		}
	}
}

function ForceShutdown()
{
	placeable = self;
	placeable.cancelable = false;
	placeable notify( "cancelled" );
}

function WatchOwnerGameEvents()
{
	self notify("WatchOwnerGameEvents_singleton");
	self endon ("WatchOwnerGameEvents_singleton");
	
	placeable = self;
	placeable endon( "cancelled" );
	
	placeable.owner util::waittill_any( "joined_team", "disconnect", "joined_spectators" );
	
	if ( isdefined( placeable ) )
	{
		placeable.abandoned = true;
		placeable ForceShutdown();
	}
}

function ShutdownOnCancelEvent( placeable )
{
	placeable endon( "hacked" );
	
	player = self;
	assert( IsPlayer( player ) );
	
	placeable util::waittill_any( "cancelled", "death" );
	
	if( isdefined( player ) && isdefined( placeable ) && ( placeable.held === true ) )
	{
		player SetHintString( "" );
		player StopCarryTurret( placeable );
		
		if( !player util::isWeaponEnabled() )
		{
			player util::_enableWeapon();		
		}
	}
	
	if( isdefined( placeable ) )
	{
		if( placeable.cancelable )
		{
			if( isdefined( placeable.onCancel ) )
			{
				[[ placeable.onCancel ]]( placeable );
			}	
		}
		else
		{
			if( isdefined( placeable.onShutdown ) )
			{
				[[ placeable.onShutdown ]]( placeable );
			}
		}
		
		if ( isdefined( placeable ) )
		{
			if ( isdefined( placeable.vehicle ) )
			{
				vehicle_to_kill = placeable.vehicle;
				vehicle_to_kill.selfDestruct = true;
				vehicle_to_kill Kill(); // need to kill the vehicle before placeable is deleted
				placeable.vehicle = undefined;
				placeable.otherModel delete();
				placeable delete();
			}
			else
			{
				placeable.otherModel delete();
				placeable delete();
			}
		}
	}
}
