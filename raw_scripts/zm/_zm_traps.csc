#using scripts\codescripts\struct;

#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_traps.gsh;

#namespace zm_traps;

REGISTER_SYSTEM( "zm_traps", &__init__, undefined )
//TODO T7 - break out trap types into their own files to support p&p
	
function __init__()
{
	//This requires a struct to be placed in the map with the following data:
	//targetname = "zm_traps"
	//script_noteworthy = this string should match that of the server side, ie. "electric"
	s_traps_array = struct::get_array( "zm_traps", "targetname" );
	a_registered_traps = [];
	
	//Check to see if a trap type has been registered yet and if not, add it to the array to get registered
	//We want to make sure each type is only registered once
	foreach( trap in s_traps_array )
	{
		if( isdefined( trap.script_noteworthy ) )
		{
			if( !trap is_trap_registered( a_registered_traps ) )
			{
				a_registered_traps[ trap.script_noteworthy ] = 1;
			}
		}
	}
}

function is_trap_registered( a_registered_traps )//self = struct
{
	return isdefined( a_registered_traps[ self.script_noteworthy ] );
}
