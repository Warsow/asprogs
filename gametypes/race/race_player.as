/*
Copyright (C) 2009-2019 Chasseur de bots

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/

class Position
{
	bool saved;
	Vec3 location;
	Vec3 angles;
	bool skipWeapons;
	int weapon;
	bool[] weapons;
	int[] ammos;
	float speed;

	Position()
	{
		this.weapons.resize( WEAP_TOTAL );
		this.ammos.resize( WEAP_TOTAL );
		this.clear();
	}

	~Position() {}

	void clear()
	{
		this.saved = false;
		this.speed = 0;
	}

	void set( Vec3 location, Vec3 angles )
	{
		this.saved = true;
		this.location = location;
		this.angles = angles;
	}
}

class Table
{
	uint columns;
	bool[] lefts;
	String[] seps;
	uint[] maxs;
	String[] items;

	Table( String format )
	{
		columns = 0;
		seps.insertLast( "" );
		for ( uint i = 0; i < format.length(); i++ )
		{
			String c = format.substr( i, 1 );
			if ( c == "l" || c == "r" )
			{
				this.columns++;
				this.lefts.insertLast( c == "l" );
				this.seps.insertLast( "" );
				this.maxs.insertLast( 0 );
			}
			else
			{
				this.seps[this.seps.length() - 1] += c;
			}
		}
	}

	~Table() {}

	void clear()
	{
		this.items.resize( 0 );
	}

	void reset()
	{
		this.clear();
		for ( uint i = 0; i < this.columns; i++ )
			this.maxs[i] = 0;
	}

	void addCell( String cell )
	{
		int column = this.items.length() % this.columns;
		uint len = cell.removeColorTokens().length();
		if ( len > this.maxs[column] )
			this.maxs[column] = len;
		this.items.insertLast( cell );
	}

	uint numRows()
	{
		int rows = this.items.length() / this.columns;
		if ( this.items.length() % this.columns != 0 )
			rows++;
		return rows;
	}

	String getRow( uint n )
	{
		String row = "";
		for ( uint i = 0; i < this.columns; i++ )
		{
			uint j = n * this.columns + i;
			if ( j < this.items.length() )
			{
				row += this.seps[i];

				int d = this.maxs[i] - this.items[j].removeColorTokens().length();
				String pad = "";
				for ( int k = 0; k < d; k++ )
					pad += " ";

				if ( !this.lefts[i] )
					row += pad;

				row += this.items[j];

				if ( this.lefts[i] )
					row += pad;
			}
		}
		row += this.seps[this.columns];
		return row;
	}
}

class ContestedRecord
{
	RunStatusQuery @query;
	uint finalTime;

	ContestedRecord( RunStatusQuery @query, uint finalTime )
	{
		@this.query = query;
		this.finalTime = finalTime;
	}

	~ContestedRecord()
	{
		// Release the native object
		query.deleteSelf();
	}

	bool isReady { get const { return query.isReady; } }

	bool hasFailed { get const { return query.hasFailed; } }

	int worldRank { get const { return query.worldRank; } }

	int personalRank { get const { return query.personalRank; } }
}

class Player
{
	Client @client;
	uint[] sectorTimes;
	uint[] bestSectorTimes;
	int64 startTime;
	uint finishTime;
	bool hasTime;
	uint bestFinishTime;
	Table report( S_COLOR_ORANGE + "l " + S_COLOR_WHITE + "r " + S_COLOR_ORANGE + "/ l r " + S_COLOR_ORANGE + "/ l r" );
	int currentSector;
	bool inRace;
	bool postRace;
	bool practicing;
	bool arraysSetUp;

	bool heardReady;
	bool heardGo;

	ContestedRecord @contestedRecord;

	// hettoo : practicemode
	int noclipWeapon;
	Position practicePosition;
	Position preRacePosition;

	void clear()
	{
		@this.client = null;
		this.currentSector = 0;
		this.inRace = false;
		this.postRace = false;
		this.practicing = false;
		this.startTime = 0;
		this.finishTime = 0;
		this.hasTime = false;
		this.bestFinishTime = 0;

		this.heardReady = false;
		this.heardGo = false;

		if( this.sectorTimes.size() != numCheckpoints )
		{
			this.sectorTimes.resize( numCheckpoints );
		}
		if( this.bestSectorTimes.size() != numCheckpoints )
		{
			this.bestSectorTimes.resize( numCheckpoints );
		}
		for ( int i = 0; i < numCheckpoints; i++ )
		{
			this.sectorTimes[i] = 0;
			this.bestSectorTimes[i] = 0;
		}
	}

	Player()
	{
		this.clear();
	}

	~Player() {}

	void takeTimesFromRecord( const RecordTime &record )
	{
		if ( this.hasTime && record.finishTime >= this.bestFinishTime )
		{
			return;
		}

		this.hasTime = true;
		this.bestFinishTime = record.finishTime;

		if( this.bestSectorTimes.size() != numCheckpoints )
		{
			this.bestSectorTimes.resize( numCheckpoints );
		}

		for ( int j = 0; j < numCheckpoints; j++ )
		{
			this.bestSectorTimes[j] = record.sectorTimes[j];
		}
	}

	bool preRace()
	{
		return !this.inRace && !this.practicing && !this.postRace && this.client.team != TEAM_SPECTATOR;
	}

	void setQuickMenu()
	{
		String s = '';
		Position @position = this.savedPosition();

		s += menuItems[MI_RESTART_RACE];
		if ( this.practicing )
		{
			s += menuItems[MI_LEAVE_PRACTICE];
			if ( this.client.team != TEAM_SPECTATOR )
			{
				if ( this.client.getEnt().moveType == MOVETYPE_NOCLIP )
					s += menuItems[MI_NOCLIP_OFF];
				else
					s += menuItems[MI_NOCLIP_ON];
			}
			else
			{
				s += menuItems[MI_EMPTY];
			}
			s += menuItems[MI_SAVE_POSITION];
			if ( position.saved )
				s += menuItems[MI_LOAD_POSITION] +
					 menuItems[MI_CLEAR_POSITION];
		}
		else
		{
			s += menuItems[MI_ENTER_PRACTICE] +
				 menuItems[MI_EMPTY] +
				 menuItems[MI_SAVE_POSITION];
			if ( position.saved && ( this.preRace() || this.client.team == TEAM_SPECTATOR ) )
				s += menuItems[MI_LOAD_POSITION] +
					 menuItems[MI_CLEAR_POSITION];
		}

		GENERIC_SetQuickMenu( this.client, s );
	}

	bool toggleNoclip()
	{
		Entity @ent = this.client.getEnt();
		if ( !this.practicing )
		{
			G_PrintMsg( ent, "Noclip mode is only available in practice mode.\n" );
			return false;
		}
		if ( this.client.team == TEAM_SPECTATOR )
		{
			G_PrintMsg( ent, "Noclip mode is not available for spectators.\n" );
			return false;
		}

		String msg;
		if ( ent.moveType == MOVETYPE_PLAYER )
		{
			ent.moveType = MOVETYPE_NOCLIP;
			this.noclipWeapon = ent.weapon;
			msg = "Noclip mode enabled.";
		}
		else
		{
			ent.moveType = MOVETYPE_PLAYER;
			this.client.selectWeapon( this.noclipWeapon );
			msg = "Noclip mode disabled.";
		}

		G_PrintMsg( ent, msg + "\n" );

		this.setQuickMenu();

		return true;
	}

	Position @savedPosition()
	{
		if ( this.preRace() )
			return preRacePosition;
		else
			return practicePosition;
	}

	bool loadPosition( bool verbose )
	{
		Entity @ent = this.client.getEnt();
		if ( !this.practicing && this.client.team != TEAM_SPECTATOR && !this.preRace() )
		{
			if ( verbose )
				G_PrintMsg( ent, "Position loading is not available during a race.\n" );
			return false;
		}

		Position @position = this.savedPosition();

		if ( !position.saved )
		{
			if ( verbose )
				G_PrintMsg( ent, "No position has been saved yet.\n" );
			return false;
		}

		ent.origin = position.location;
		ent.angles = position.angles;

		if ( !position.skipWeapons )
		{
			for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
			{
				if ( position.weapons[i] )
					this.client.inventoryGiveItem( i );
				Item @item = G_GetItem( i );
				this.client.inventorySetCount( item.ammoTag, position.ammos[i] );
			}
			this.client.selectWeapon( position.weapon );
		}

		if ( this.practicing )
		{
			if ( ent.moveType != MOVETYPE_NOCLIP )
			{
				Vec3 a, b, c;
				position.angles.angleVectors( a, b, c );
				a.z = 0;
				a.normalize();
				a *= position.speed;
				ent.set_velocity( a );
			}
		}
		else if ( this.preRace() )
		{
			ent.set_velocity( Vec3() );
		}

		return true;
	}

	bool savePosition()
	{
		Client @ref = this.client;
		if ( this.client.team == TEAM_SPECTATOR && this.client.chaseActive )
			@ref = G_GetEntity( this.client.chaseTarget ).client;
		Entity @ent = ref.getEnt();

		if ( this.preRace() )
		{
			Vec3 mins, maxs;
			ent.getSize( mins, maxs );
			Vec3 down = ent.origin;
			down.z -= 1;
			Trace tr;
			if ( !tr.doTrace( ent.origin, mins, maxs, down, ent.entNum, MASK_PLAYERSOLID ) )
			{
				G_PrintMsg( this.client.getEnt(), "You can only save your prerace position on solid ground.\n" );
				return false;
			}
		}

		Position @position = this.savedPosition();
		position.set( ent.origin, ent.angles );

		if ( ref.team == TEAM_SPECTATOR )
		{
			position.skipWeapons = true;
		}
		else
		{
			position.skipWeapons = false;
			for ( int i = WEAP_NONE + 1; i < WEAP_TOTAL; i++ )
			{
				position.weapons[i] = ref.canSelectWeapon( i );
				Item @item = G_GetItem( i );
				position.ammos[i] = ref.inventoryCount( item.ammoTag );
			}
			position.weapon = ent.moveType == MOVETYPE_NOCLIP ? this.noclipWeapon : ref.weapon;
		}
		this.setQuickMenu();

		return true;
	}

	bool clearPosition()
	{
		if ( !this.practicing && this.client.team != TEAM_SPECTATOR && !this.preRace() )
		{
			G_PrintMsg( this.client.getEnt(), "Position clearing is not available during a race.\n" );
			return false;
		}

		this.savedPosition().clear();
		this.setQuickMenu();

		return true;
	}

	int64 timeStamp()
	{
		return levelTime;
	}

	bool startRace()
	{
		if ( !this.preRace() )
			return false;

		this.currentSector = 0;
		this.inRace = true;
		this.startTime = this.timeStamp();

		for ( int i = 0; i < numCheckpoints; i++ )
			this.sectorTimes[i] = 0;

		this.report.reset();

		this.client.newRaceRun( numCheckpoints );

		this.setQuickMenu();

		return true;
	}

	bool validTime()
	{
		return this.timeStamp() >= this.startTime;
	}

	uint raceTime()
	{
		return this.timeStamp() - this.startTime;
	}

	void cancelRace()
	{
		if ( this.inRace && this.currentSector > 0 )
		{
			Entity @ent = this.client.getEnt();
			uint rows = this.report.numRows();
			for ( uint i = 0; i < rows; i++ )
				G_PrintMsg( ent, this.report.getRow( i ) + "\n" );
			G_PrintMsg( ent, S_COLOR_ORANGE + "Race canceled\n" );
		}

		this.inRace = false;
		this.postRace = false;
		this.finishTime = 0;
	}

	void completeRace()
	{
		uint delta;
		String str;

		if ( !this.validTime() ) // something is very wrong here
			return;

		this.client.addAward( S_COLOR_CYAN + "Race Finished!" );

		this.finishTime = this.raceTime();
		this.inRace = false;
		this.postRace = true;

		str = "Current: " + RACE_TimeToString( this.finishTime );

		const String @rankAsString = localRecordsStorage.getFinalRankAsString( this.finishTime );
		if( @rankAsString != null )
		{
			str += " (" + S_COLOR_GREEN + "#" + rankAsString + S_COLOR_WHITE + ")";
		}

		Entity @ent = this.client.getEnt();
		G_CenterPrintMsg( ent, str + "\n" + RACE_TimeDiffString( this.finishTime, this.bestFinishTime, true ) );
		this.report.addCell( "Race finished:" );
		this.report.addCell( RACE_TimeToString( this.finishTime ) );
		this.report.addCell( "Personal:" );
		this.report.addCell( RACE_TimeDiffString( this.finishTime, this.bestFinishTime, false ) );
		this.report.addCell( "Server:" );
		this.report.addCell( RACE_TimeDiffString( this.finishTime, localRecordsStorage.getBestTime(), false ) );
		uint rows = this.report.numRows();
		for ( uint i = 0; i < rows; i++ )
			G_PrintMsg( ent, this.report.getRow( i ) + "\n" );

		if ( !this.hasTime || this.finishTime < this.bestFinishTime )
		{
			this.client.addAward( S_COLOR_YELLOW + "Personal record!" );
			// copy all the sectors into the new personal record backup
			this.hasTime = true;
			this.bestFinishTime = this.finishTime;
			for ( int i = 0; i < numCheckpoints; i++ )
				this.bestSectorTimes[i] = this.sectorTimes[i];
		}

		// if the run was not rejected by the local storage
		if( localRecordsStorage.registerCompletedRun( this ) )
		{
			// Send the final time to MM.
			// This also starts contesting the status of a completed run
			// against global world and personal records if possible.
			this.sendRaceRun( this.finishTime );
		}

		// set up for respawning the player with a delay
		this.schedulePostRaceRespawn();

		G_AnnouncerSound( this.client, G_SoundIndex( "sounds/misc/timer_ploink" ), GS_MAX_TEAMS, false, null );
	}

	private void sendRaceRun( int64 time )
	{
		RunStatusQuery @query = this.client.completeRaceRun( time );
		if ( @query == null )
		{
			return;
		}

		if ( @contestedRecord != null )
		{
			// Allow the old object to be garbage-collected
			@contestedRecord = null;
			// TODO: Put an assertion that we start contesting a better record
		}

		@contestedRecord = @ContestedRecord( query, time );
	}

	void checkContestedRecordStatus()
	{
		if ( @contestedRecord == null )
		{
			return;
		}

		if ( !contestedRecord.isReady )
		{
			return;
		}

		// Create a local object reference so we can still use the object in this scope
		ContestedRecord @record = @contestedRecord;
		// Allow the object to be garbage-collected at leaving of this method scope
		@contestedRecord = null;

		if ( record.hasFailed )
		{
			G_PrintMsg( client.getEnt(), S_COLOR_YELLOW + "Failed to fetch the global record status\n" );
			// Allow the object to be garbage-collected
			@contestedRecord = null;
			return;
		}

		// Retrieved ranks start from 1
		if ( record.worldRank == 1 )
		{
			String message = this.client.name;
			String login = this.client.getUserInfoKey( "cl_mm_login" );
			if ( login != "" )
			{
				message += S_COLOR_WHITE + "(" + S_COLOR_YELLOW + login + S_COLOR_WHITE + ")";
			}

			message += S_COLOR_CYAN + " made a new " + S_COLOR_RED;
			message += "*** WORLD RECORD ***" + S_COLOR_CYAN + " with ";
			message += S_COLOR_WHITE + RACE_TimeToString( record.finalTime );
			message += S_COLOR_CYAN + "!\n";
			G_PrintMsg( null, message );
			return;
		}

		String message;
		// Retrieved ranks start from 1
		if ( record.personalRank == 1 )
		{
			message += S_COLOR_MAGENTA + "The time " + S_COLOR_WHITE;
			message += RACE_TimeToString( record.finalTime );
			message += S_COLOR_MAGENTA + " was your global personal record and ";
			message += S_COLOR_WHITE + "#" + record.worldRank;
			message += S_COLOR_MAGENTA + " in the world!\n";
		}
		else
		{
			message += "The time " + RACE_TimeToString( record.finalTime );
			message += S_COLOR_WHITE + " was your global personal result ";
			message += "#" + record.personalRank + " and #" + record.worldRank + " in the world!\n";
		}

		G_PrintMsg( client.getEnt(), message );
	}

	bool touchCheckPoint( int id )
	{
		uint delta;
		String str;

		if ( id < 0 || id >= numCheckpoints )
			return false;

		if ( !this.inRace )
			return false;

		if ( this.sectorTimes[id] != 0 ) // already past this checkPoint
			return false;

		if ( !this.validTime() ) // something is very wrong here
			return false;

		this.sectorTimes[id] = this.raceTime();

		// send this checkpoint to MM
		this.client.setSectorTime( id, this.sectorTimes[id] );

		// print some output and give awards if earned

		str = "Current: " + RACE_TimeToString( this.sectorTimes[id] );

		const String @sectorRank = localRecordsStorage.getSectorRankAsString( this.sectorTimes[id], id );
		if ( @sectorRank != null )
		{
			// extra id when on server record beating time
			str += " (" + S_COLOR_GREEN + "#" + sectorRank + S_COLOR_WHITE + ")";
		}

		uint topRecordTime = 0;
		RecordTime @topRecord = localRecordsStorage.findRecordByRank( 0 );
		if( @topRecord != null )
		{
			topRecordTime = topRecord.sectorTimes[id];
		}

		Entity @ent = this.client.getEnt();
		G_CenterPrintMsg( ent, str + "\n" + RACE_TimeDiffString( this.sectorTimes[id], this.bestSectorTimes[id], true ) );
		this.report.addCell( "Sector " + this.currentSector + ":" );
		this.report.addCell( RACE_TimeToString( this.sectorTimes[id] ) );
		this.report.addCell( "Personal:" );
		this.report.addCell( RACE_TimeDiffString( this.sectorTimes[id], this.bestSectorTimes[id], false ) );
		this.report.addCell( "Server:" );
		this.report.addCell( RACE_TimeDiffString( this.sectorTimes[id], topRecordTime, false ) );

		// if beating the level record on this sector give an award
		if ( ( @topRecord == null ) || this.sectorTimes[id] < topRecord.sectorTimes[id] )
		{
			this.client.addAward( "Sector record on sector " + this.currentSector + "!" );
		}
		// if beating his own record on this sector give an award
		else if ( this.sectorTimes[id] < this.bestSectorTimes[id] )
		{
			// ch : does racesow apply sector records only if race is completed?
			this.client.addAward( "Personal record on sector " + this.currentSector + "!" );
			this.bestSectorTimes[id] = this.sectorTimes[id];
		}

		this.currentSector++;

		G_AnnouncerSound( this.client, G_SoundIndex( "sounds/misc/timer_bip_bip" ), GS_MAX_TEAMS, false, null );

		return true;
	}

	void enterPracticeMode()
	{
		if ( this.practicing )
			return;

		this.practicing = true;
		G_CenterPrintMsg( this.client.getEnt(), S_COLOR_CYAN + "Entered practice mode" );
		this.cancelRace();
		this.setQuickMenu();
	}

	void leavePracticeMode()
	{
		if ( !this.practicing )
			return;

		this.practicing = false;
		G_CenterPrintMsg( this.client.getEnt(), S_COLOR_CYAN + "Left practice mode" );
		if ( this.client.team != TEAM_SPECTATOR )
			this.client.respawn( false );
		this.setQuickMenu();
	}

	void togglePracticeMode()
	{
		if ( this.practicing )
			this.leavePracticeMode();
		else
			this.enterPracticeMode();
	}

	private void schedulePostRaceRespawn()
	{
		Entity @respawner = G_SpawnEntity( "race_respawner" );
		respawner.nextThink = levelTime + 5000;
		@respawner.think = race_respawner_think;
		respawner.count = this.client.playerNum;
	}

	private void scheduleForcedRespawn()
	{
		Entity @respawner = G_SpawnEntity( "race_respawner" );
		// Put some delay so catching early possible anomalies
		// tied to this deferred execution is more likely.
		respawner.nextThink = levelTime + 500;
		@respawner.think = race_respawner_think2;
		respawner.count = this.client.playerNum;
	}

	void handleUserInfoChangedEvent()
	{
		String login = client.getUserInfoKey( "cl_mm_login" );
		RecordTime @record;
		if ( login != "" )
		{
			@record = localRecordsStorage.findRecordByLogin( login );
		}
		else
		{
			@record = localRecordsStorage.findRecordByName( client.name );

			const bool wasPreRace = this.preRace();
			// Prevent an infinite looping at respawning at start position
			if( !wasPreRace )
			{
				this.cancelRace();
				// We should respawn the client immediately.
				// Unfortunately this leads to an infinite recursion
				// as the "user info changed" event is fired on respawn.
				this.scheduleForcedRespawn();
			}

			// MM login value is the same while a client keeps connected.
			// Identifying players by names is more troublesome.
			// Changing a user name is like switching an account.
			// We have to clear the player state.
			// Hopefully it gets refilled by the found record.
			// This could fail if the local records capacity is exceeded.
			// Should not really be worse than it used to be
			// (local records were not even retrieved for a connecting not loggged in clients).
			// TODO: Check whether a name was really modified
			// (it is not for most invocations of this events handler).
			this.clear();
			// Hack: Let the respawner think we're in a post race state
			this.postRace = !wasPreRace;
		}

		if ( @record != null )
		{
			this.takeTimesFromRecord( record );
		}
	}
}

Player[] players( maxClients );

Player @RACE_GetPlayer( Client @client )
{
	if ( @client == null || client.playerNum < 0 )
		return null;

	Player @player = players[client.playerNum];
	@player.client = client;

	return player;
}

// TODO: Should be an anonymous function
void race_respawner_think( Entity @respawner )
{
	Client @client = G_GetClient( respawner.count );

	// An invocation of this callback has a substantial delay after touching the final trigger.
	// A client might have respawned on its own and started a new run or did something else.
	// Respawn the client only if it still in game and is in "post-race" state.
	if ( RACE_GetPlayer( client ).postRace && client.team != TEAM_SPECTATOR )
	{
		client.respawn( false );
	}

	respawner.freeEntity();
}

// TODO: Should be an anonymous function
void race_respawner_think2( Entity @respawner )
{
	Client @client = G_GetClient( respawner.count );

	// An invocation of this callback has a small delay.
	// However this still leaves a room for performing actions on client's own.
	// Respawn the client only if it is still in game and is not at the start position.
	if ( !RACE_GetPlayer( client ).preRace() && client.team != TEAM_SPECTATOR )
	{
		G_PrintMsg( client.getEnt(), S_COLOR_RED + "Your user info was changed. Forcing respawn...\n" );
		client.respawn( false );
	}

	respawner.freeEntity();
}
