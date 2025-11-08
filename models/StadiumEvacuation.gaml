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

// OK
global {
	
	int nb_of_spectators;
	int nb_of_workers;
	
	// Perception distance
	float min_perception_distance <- 1.0;
	float max_perception_distance <- 5.0;
	
	// Hazard parameters
	int time_before_hazard;
	float flood_front_speed; // Speed of hazard expansion (m/min)
	
	// --- GIS FILE PATHS FOR THE STADIUM ---
	file road_file <- file("../includes/paths.shp");
	file buildings <- file("../includes/walls.shp");
	file evac_points <- file("../includes/exits.shp");
	// ---------------------------------------------
	
	geometry shape <- envelope(envelope(road_file)+envelope(buildings)+envelope(evac_points));
	
	graph<geometry, geometry> road_network;
	
	// Data output
	int victims;
	int safe_people;
	
	
	init {
		create road from:road_file;       // Creates "paths"
		create building from:buildings;   // Creates "walls"
		create evacuation_point from:evac_points; // Creates "exits" (2)
		
		create hazard number: 1 {
			location <- any_location_in(world);
			shape <- self.location buffer 0.1#m; 
		}
		create spectator number:nb_of_spectators {
			location <- any_location_in(one_of(road)); 
			safety_point <- evacuation_point closest_to(self);
			perception_distance <- rnd(min_perception_distance, max_perception_distance); 
		}
		create worker number: nb_of_workers {
			location <- any_location_in(one_of(road)); 
			safety_point <- evacuation_point closest_to(self);
			perception_distance <- rnd(min_perception_distance, max_perception_distance);
		}
		
		road_network <- as_edge_graph(road);
	
	}
	
	// Original stopping reflex (uses 'inhabitant' and 'drowned')
	reflex stop_simu when:spectator all_match (each.saved or each.drowned) and worker all_match (each.saved or each.drowned){
		do pause;
	}
	
}

// OK
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

// OK
species person skills:[moving] {
    bool alerted;
    bool drowned;
    bool saved;
    float perception_distance;
    evacuation_point safety_point;
    
    reflex drown when:not(drowned or saved) {
        if(first(hazard) covers self){
            drowned <- true;
            victims <- victims + 1; 
        }
    }
    reflex escape when: not(saved) and location distance_to safety_point < 2#m{
        saved <- true;
        alerted <- false;
        safe_people <- safe_people + 1;
    }
}

// TODO: BDI agent
species spectator parent: person control: simple_bdi {
    
    // Perceive alerted people nearby (workers or other spectators)
    reflex perceive when: not(alerted or drowned) {
        if not empty((worker + spectator) at_distance perception_distance where each.alerted) {
            alerted <- true;
        }
    }
    
    reflex evacuate when: alerted and not(drowned or saved) {
        do goto target:safety_point on: road_network;
    }
    
    aspect default {
        draw sphere(1#m) color: drowned ? #black : (alerted ? #red : #green);
    }
}

// TODO: BDI agent
species worker parent: person {
    
    init {
        alerted <- true;  // Workers start alerted
    }
    
    reflex evacuate when: alerted and not(drowned or saved) {
        do goto target:safety_point on: road_network;
    }
    
    aspect default {
        draw sphere(1#m) color: drowned ? #black : (alerted ? #violet : #blue);
    }
}

// OK
species evacuation_point {
	
	int count_exit_spectators <- 0 update: length((spectator where each.saved) at_distance 2#m);
	int count_exit_workers <- 0 update: length((worker where each.saved) at_distance 2#m);
		
	aspect default {
		// Corrected transparency syntax (0-255, not 0-1)
		draw circle(1#m+49#m*(count_exit_spectators + count_exit_workers)/(nb_of_spectators + nb_of_workers)) color: rgb(0, 255, 0, 180); // 180 is ~70% opacity
	}
}

// OK
species road {
	aspect default{
		draw shape width: 4#m color:rgb(55,0,0);
	}	
}

// OK
species building {
	aspect default {
		draw shape color: #gray border: #black depth: 1;
	}
}


experiment "Run_Stadium" type:gui {
	float minimum_cycle_duration <- 0.1;
		
	// --- ADJUSTED PARAMETERS ---
			
	parameter "Hazard Speed (m/min)" var:flood_front_speed init:10.0 min:1.0 max:30.0 unit:"m/min" category:"Hazard";
	parameter "Time Before Hazard (min)" var:time_before_hazard init:1 min:0 max:10 unit:"min" category:"Hazard";
	
	parameter "Number of Spectators" var:nb_of_spectators init:1000 min:0 max:20000 category:"Initialization";
	parameter "Number of Workers" var:nb_of_workers init:5 min:0 max:200 category:"Initialization";
	
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
		monitor "Number of Saved people: " value: safe_people; 
		monitor "Number of Victims: " value:victims;
	}	
	
}
