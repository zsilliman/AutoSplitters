state("NullTransit") {}

startup {
	vars.single_level_setting = "Single Level Run";
	vars.outer_bloom_setting = "Measure Outer Bloom";
	vars.conductors_path_setting = "Measure Conductor's Path";
	vars.habitation_grounds_setting = "Measure Habitation Grounds";

	settings.Add(vars.single_level_setting, default_value: false, description: "Single Level Run", parent: null);
	settings.Add(vars.outer_bloom_setting, default_value: true, description: "Outer Bloom", parent: vars.single_level_setting);
	settings.Add(vars.conductors_path_setting, default_value: false, description: "Conductor's Path", parent: vars.single_level_setting);
	settings.Add(vars.habitation_grounds_setting, default_value: false, description: "Habitation Grounds", parent: vars.single_level_setting);

	settings.SetToolTip(vars.single_level_setting, "If false, this will measure a full game run. Otherwise, only a single level is measured. If multiple are set to true, the first will be picked.");
	print("Startup Completed."); 
}

init {
	print("Init Started.");

	refreshRate = 30;

	string logPath = "%USERPROFILE%\\AppData\\LocalLow\\HalfwayGames\\NullTransit\\Player.log";
	logPath = Environment.ExpandEnvironmentVariables(logPath);

	try { // Wipe the log file to clear out messages from last time
		FileStream fs = new FileStream(logPath, FileMode.Open, FileAccess.Write, FileShare.ReadWrite);
		fs.SetLength(0);
		fs.Close();
	} catch {
		print("Logpath not found: " + logPath);
	} // May fail if file doesn't exist.
	vars.reader = new StreamReader(new FileStream(logPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite));

	// Constants for possible event names
	vars.outer_bloom = "Outer Bloom";
	vars.conductors_path = "Conductors Path";
	vars.habitation_grounds = "Habitation Grounds";
	vars.final_boss = "Beat Final Boss";
	vars.end_cutscene = "End Cutscene";
	vars.ship = "Ship";

	// The sequence we expect to see for a complete run
	vars.target_seq = new List<string>();
	// Build target sequence from settings
	if (settings[vars.single_level_setting])
	{
		if (settings[vars.outer_bloom_setting])
		{
			// Outer Bloom sequence
			vars.target_seq = new List<string> { vars.outer_bloom, vars.conductors_path };
			print("Using single-level setting for Outer Bloom");
		}
		else if (settings[vars.conductors_path_setting])
		{
			// Conductor's Path sequence
			vars.target_seq = new List<string> { vars.conductors_path, vars.habitation_grounds };
			print("Using single-level setting for Conductor's Path");
		}
		else if (settings[vars.habitation_grounds_setting])
		{
			// Habitation Grounds sequence
			vars.target_seq = new List<string> { vars.habitation_grounds, vars.final_boss, vars.ship };
			print("Using single-level setting for Habitation Grounds");
		}
	}
	else
	{
		// Set full run sequence
		vars.target_seq = new List<string> { vars.outer_bloom, vars.conductors_path, vars.habitation_grounds, vars.final_boss, vars.ship, vars.end_cutscene };
			print("Using full-game setting");
	}

	// The sequence we are currently at in the active run
	current.active_seq = new List<string>();
	current.reset = false;

	// Counter for triggering Start and Split
	current.seq_counter = 0;

	vars.lst_to_string = (Func<List<string>, string>)(lst =>
	{
		string result = "[";
		string separator = " ==> ";
		foreach (var val in lst)
		{
			result += val + separator;
		}
		return result.Substring(0, result.Length - separator.Length) + "]";
	});

	// Function to try to add an event to the sequence
	vars.add_event = (Func<string, bool>)(event_name =>
	{
		print("Trying to add event: " + event_name);
		int next_index = current.active_seq.Count;
		if (next_index < vars.target_seq.Count && vars.target_seq[next_index] == event_name)
		{
			current.active_seq.Add(event_name);
			print("Added event: " + event_name + "  Active Sequence = " + vars.lst_to_string(current.active_seq));
			return true;
		}
		return false;
	});

	print("Init Completed.");
} 

update {
	// Outer Bloom Entered
	string OuterBloomIndicator = "Steam achievement [REACH_OUTPOST] was set.";

	// Conductor's Path Entered
	string ConductorsPathIndicator = "Steam achievement [REACH_RAILS] was set.";

	// Habitation Grounds Entered
	string HabitationGroundsIndicator = "Steam achievement [REACH_BLOCKS] was set.";

	// Ship Entered
	string ShipIndicator = "Pointer Home: IsInCurrentScene=true  SectionRef=null  SceneToOpen=MainGameMap.unity";

	// Defeated Final Boss (does not result in a split event)
	string DefeatFinalBossIndicator = "Steam achievement [DEFEAT_FINAL_BOSS] was set.";

	// Cutscene Started
	string CutsceneStarted = "Steam achievement [BEAT_GAME] was set.";

	// Whether we should reset the timer
	string ResetIndicatorA = "ProgressionIndex = 0";
	string ResetIndicatorB = "Loading WorldRecipeStore save data.";

	var line = "";
	var lines = "";
	while (line != null)
	{
		line = vars.reader.ReadLine();
		if (line != null)
			lines += line + "\n";
	}

	// If no line was read, don't run any other blocks.
	if (lines == null || lines.Length == 0) {
		return false;
	}

	bool new_event = false; 
	string new_event_name = "";
	current.reset = false;

	if (lines.Contains(OuterBloomIndicator)) 
	{
		new_event = vars.add_event(vars.outer_bloom);
		new_event_name = vars.outer_bloom;
	}
	else if (lines.Contains(ConductorsPathIndicator))
	{
		new_event = vars.add_event(vars.conductors_path);
		new_event_name = vars.conductors_path;
	}
	else if (lines.Contains(HabitationGroundsIndicator))
	{
		new_event = vars.add_event(vars.habitation_grounds);
		new_event_name = vars.habitation_grounds;
	}
	else if (lines.Contains(ShipIndicator))
	{
		new_event = vars.add_event(vars.ship);
		new_event_name = vars.ship;
	}
	else if (lines.Contains(DefeatFinalBossIndicator))
	{
		new_event = vars.add_event(vars.final_boss);
		new_event_name = vars.final_boss;
	}
	else if (lines.Contains(CutsceneStarted))
	{
		new_event = vars.add_event(vars.end_cutscene);
		new_event_name = vars.end_cutscene;
	}
	if (lines.Contains(ResetIndicatorA) || lines.Contains(ResetIndicatorB))
	{
		current.reset = true;
		print("Reseting...");
	}

	// Increment seq counter (we don't increment for final boss, since that doesn't actually correspond to a split, but we still want to track it). This allows it to be stored in the 'old' state, since the list is stored by ref not value
	if (new_event && new_event_name != vars.final_boss)
	{
		current.seq_counter++;
	};

	return true;
}

//isLoading {
	//print("Current Seq Counter = " + current.seq_counter + "    target_seq.Count = " + vars.target_seq.Count);
	//return current.seq_counter >= vars.target_seq.Count;
//}

start
{
	return old.seq_counter == 0 && current.seq_counter == 1;
}

split
{
	return old.seq_counter != current.seq_counter && current.seq_counter > 1;
}

reset
{
	return !old.reset && current.reset;
}

onReset
{
	current.seq_counter = 0;
	current.active_seq.Clear();
	print("Reset counters.");
}