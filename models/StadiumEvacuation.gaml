/***
* Name: StadiumEvacuation
* Author: kevinchapuis (Adapted for stadium)
* Description: A model for stadium evacuation. REUSES the species from CityEscape.
* The map is defined by WALLS (loaded as 'building') and STADIUM_PATHS (loaded as 'road').
* The 'inhabitant' (spectators) are created ON the 'road' (paths) and must
* reach the 'evacuation_point' (exits).
* Tags: evacuation, stadium, crowd, agent, gis, hazard
***/
model StadiumEvacuation

global {
	
	// Simulation start date
	date starting_date <- #now;
	
	// Time step (1 second is better for stadium movements)
	float step <- 1#sec;
	
	int nb_of_spectators;
	int nb_of_workers;
	
	// Perception distance
	float min_perception_distance <- 10.0;
	float max_perception_distance <- 30.0;
	
	// Corridor capacity: number of 'inhabitant' per meter
	float road_density;
	
	// Alert strategy parameters
	int time_after_last_stage;
	string the_alert_strategy;
	int nb_stages;
	
	// Hazard parameters
	int time_before_hazard;
	float flood_front_speed; // Speed of hazard expansion (m/min)
	
	// --- GIS FILE PATHS FOR THE STADIUM ---
	// 'road_file' now points to the PATHS
	file road_file <- file("../includes/paths.shp");
	// 'buildings' now points to the WALLS
	file buildings <- file("../includes/walls.shp");
	
	// THESE ARE KEPT so the simulation works
	// (We use the evacuation points from the original example)
	file evac_points <- file("../includes/exits.shp");
	// 'water_body' is no longer used, the hazard is created in 'init'
	// file water_body <- file("../includes/city_environment/sea_environment.shp");
	// ---------------------------------------------
	
	geometry shape <- envelope(envelope(road_file)+envelope(buildings)+envelope(evac_points));
	
	// Graph of 'road' (which are now the paths)
	graph<geometry, geometry> road_network;
	map<road,float> road_weights;
	
	// Data output (uses the original variable 'casualties')
	int casualties;
	
	init {
				
		// Creates the original species with the new files
		create road from:road_file;       // Creates "paths"
		create building from:buildings;   // Creates "walls"
		create evacuation_point from:evac_points; // Creates "exits"
		
		// MODIFIED! The hazard (fire/smoke) is no longer loaded from a file
		create hazard number: 1 {
			location <- world.shape.location; // Starts at the center of the stadium
			shape <- self.location buffer 10.0#m; // Give it a small initial shape
		}
		
		// --- ORIGINAL START LOGIC ---
		// Creates 'inhabitant' (spectators) ON the 'road' (paths).
		create spectator number:nb_of_spectators {
			location <- any_location_in(one_of(road)); // << BACK TO ORIGINAL!
			safety_point <- any(evacuation_point);
			perception_distance <- rnd(min_perception_distance, max_perception_distance);
		}
		// --- END OF CHANGE ---
		
		// The original crisis manager
		create crisis_manager;
		
		road_network <- as_edge_graph(road);
		road_weights <- road as_map (each::each.shape.perimeter);
	
	}
	
	// Original stopping reflex (uses 'inhabitant' and 'drowned')
	reflex stop_simu when:spectator all_match (each.saved or each.drowned) and worker all_match (each.saved or each.drowned){
		do pause;
	}
	
}

/*
 * Agent responsible for the communication strategy
 * (No changes)
 */
species crisis_manager {
	
	float alert_range;
	int nb_per_stage;
	geometry buffer;
	float distance_buffer;
	
	init {
		int modulo_stage <- length(spectator) mod nb_stages; 
		nb_per_stage <- int(length(spectator) / nb_stages) + (modulo_stage = 0 ? 0 : 1);
		buffer <- geometry(evacuation_point collect (each.shape buffer 1#m));
		distance_buffer <- world.shape.height / nb_stages;
		alert_range <- (time_before_hazard#mn - time_after_last_stage#mn) / nb_stages;
	}
	
	reflex send_alert when: alert_conditional() {
		ask alert_target() { self.alerted <- true; }
	}
	
	bool alert_conditional {
		if(the_alert_strategy = "STAGED" or the_alert_strategy = "SPATIAL"){
			return every(alert_range);
		} else {
			if(cycle = 0){
				return true;
			} else {
				return false;
			}
		}
	}
	
	list<spectator> alert_target {
		switch the_alert_strategy {
			match "STAGED" {
				return nb_per_stage among (spectator where (each.alerted = false));
			}
			match "SPATIAL" {
				buffer <- buffer buffer distance_buffer;
				return spectator overlapping buffer;
			}
			match "EVERYONE" {
				return list(spectator);
			}
			default {
				return [];
			}
		}
	}
}

/*
 * Represents the hazard (fire/smoke)
 * (Initialization logic changed in 'global.init')
 */
species hazard {
	
	date catastrophe_date;
	bool triggered;
	
	init {
		catastrophe_date <- current_date + time_before_hazard#mn;
	}
	
	reflex expand when:catastrophe_date < current_date {
		if(not(triggered)) {triggered <- true;}
		// Uses the original variable 'flood_front_speed'
		shape <- shape buffer (flood_front_speed#m/#mn * step) intersection world;
	}
	
	aspect default {
		// Corrected transparency syntax (0-255, not 0-1)
		draw shape color: rgb(255, 0, 0, 150); // 150 is ~60% opacity
	}
}

/*
 * Represents the spectator ('inhabitant')
 * (No logic changes, only creation)
 */
species person skills:[moving] {
	
	bool alerted;
	bool drowned; // means 'victim'
	bool saved;
	
	float perception_distance;
	evacuation_point safety_point;
	float speed; 
	
	reflex drown when:not(drowned or saved) {
		if(first(hazard) covers self){
			drowned <- true;
			casualties <- casualties + 1; 
		}
	}
	
	reflex escape when: not(saved) and location distance_to safety_point < 2#m{
		saved <- true;
		alerted <- false;
	}
}

species spectator skills: [moving] parent: person {
	bool alerted <- false;
	bool drowned <- false; // means 'victim'
	bool saved <- false;
	float perception_distance;
	evacuation_point safety_point;
	float speed <- 10#km/#h;
	
	reflex perceive when: not(alerted or drowned) and first(hazard).triggered {
		if self.location distance_to first(hazard).shape < perception_distance {
			alerted <- true;
		}
	}
	
	reflex evacuate when:alerted and not(drowned or saved) {
		do goto target:safety_point on: road_network move_weights:road_weights;
		if(current_edge != nil){
			road the_current_road <- road(current_edge);  
			the_current_road.users <- the_current_road.users + 1;
		}
	}
	
	
	
	aspect default {
		draw sphere(1#m) color:drowned ? #black : (alerted ? #red : #green);
	}
}

species worker skills: [moving] parent: person {
	bool alerted <- false;
	bool drowned <- false; // means 'victim'
	bool saved <- false;
	float perception_distance;
	evacuation_point safety_point;
	float speed <- 10#km/#h;
	
	// TODO: change this 
	reflex perceive when: not(alerted or drowned) and first(hazard).triggered {
		if self.location distance_to first(hazard).shape < perception_distance {
			alerted <- true;
		}
	}
	
	// TODO: change this
	reflex evacuate when:alerted and not(drowned or saved) {
		do goto target:safety_point on: road_network move_weights:road_weights;
		if(current_edge != nil){
			road the_current_road <- road(current_edge);  
			the_current_road.users <- the_current_road.users + 1;
		}
	}
	
	
	aspect default {
		draw sphere(1#m) color:drowned ? #black : (alerted ? #violet : #blue);
	}
}

/*
 * The evacuation point (Exit)
 * (No changes)
 */
species evacuation_point {
	
	int count_exit_spectators <- 0 update: length((spectator where each.saved) at_distance 2#m);
	int count_exit_workers <- 0 update: length((worker where each.saved) at_distance 2#m);
		
	aspect default {
		// Corrected transparency syntax (0-255, not 0-1)
		draw circle(1#m+49#m*(count_exit_spectators + count_exit_workers)/(nb_of_spectators + nb_of_workers)) color: rgb(0, 255, 0, 180); // 180 is ~70% opacity
	}
}

/*
 * The stadium paths ('road')
 * (No changes)
 */
species road {
	
	int users;
	int capacity <- int(shape.perimeter*road_density);
	float speed_coeff <- 1.0;
	
	reflex update_weights {
		speed_coeff <- max(0.05,exp(-users/capacity));
		road_weights[self] <- shape.perimeter / speed_coeff;
		users <- 0;
	}
	
	reflex flood_road {
		if(hazard first_with (each covers self) != nil){
			road_network >- self; 
			do die;
		}
	}
	
	aspect default{
		draw shape width: 4#m-(3*speed_coeff)#m color:rgb(55+200*users/capacity,0,0);
	}	
}

/*
 * The stadium walls ('building')
 * (No changes)
 */
species building {
	aspect default {
		draw shape color: #gray border: #black depth: 1;
	}
}

/*
 * NO SEATS
 */

experiment "Run_Stadium" type:gui {
	float minimum_cycle_duration <- 0.1;
		
	// --- ADJUSTED PARAMETERS ---
	
	parameter "Alert Strategy" var:the_alert_strategy init:"STAGED" among:["NONE","STAGED","SPATIAL","EVERYONE"] category:"Alert";
	parameter "Number of Stages" var:nb_stages init:6 category:"Alert";
	parameter "Buffer Time (min)" var:time_after_last_stage init:2 unit:"min" category:"Alert";
	
	parameter "Path Density" var:road_density init:4.0 min:0.1 max:10.0 category:"Congestion";
	
	parameter "Hazard Speed (m/min)" var:flood_front_speed init:10.0 min:1.0 max:30.0 unit:"m/min" category:"Hazard";
	parameter "Time Before Hazard (min)" var:time_before_hazard init:3 min:0 max:10 unit:"min" category:"Hazard";
	
	parameter "Number of Spectators" var:nb_of_spectators init:1000 min:100 max:20000 category:"Initialization";
	parameter "Number of Workers" var:nb_of_workers init:1000 min:1 max:200 category:"Initialization";
	
	output {
		display my_display type:3d axes:false{ 
			// Draws the original species (NO SEATS)
			species road;
			species evacuation_point;
			species building; // This will draw the WALLS
			species hazard ;
			species spectator;
			species worker;
		}
		monitor "Number of Victims" value:casualties;
	}	
	
}
