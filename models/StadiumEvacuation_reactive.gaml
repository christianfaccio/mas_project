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
	file buildings <- file("../includes/buildings.shp");
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

species spectator skills:[moving] control: simple_bdi {
	
	bool drowned;
    bool saved;
    float perception_distance;
    float speed <- 5.0 #km / #h;
    evacuation_point safety_point;
    bool being_alerted <- false;
    string role; // leader, follower, panic
    
    
    // BELIEFS
    predicate not_alerted <- new_predicate("not_alerted");
    predicate alerted <- new_predicate("alerted");
    predicate dead <- new_predicate("dead");
    
    // DESIRES
    predicate watch <- new_predicate("watch");
    predicate escape <- new_predicate("escape");

   	init {
   		do add_belief(not_alerted);
   		do add_desire(watch);
	   	float r <- rnd(1.0);
		    if (r < 0.10) {
		        role <- "leader";
		    } else if (r < 0.85) {
		        role <- "follower";
		    } else {
		        role <- "panic";
		    }
   	}
   	
   	// Reflexes ---------------------------------------------------------------------------------------
    
    reflex drown when:not(drowned or saved) {
        if(first(hazard) covers self){
            drowned <- true;
            victims <- victims + 1; 
            do die;
        }
    }
    
    reflex escaped when: not(saved) and location distance_to safety_point < 2#m{
        saved <- true;
        safe_people <- safe_people + 1;
        do die;
    }
    
    reflex move_to_safety when: being_alerted and not (saved or drowned) {
        do goto target: safety_point on: road_network speed: speed;
    }
    
   	reflex perceive_alert when: not being_alerted {
   		// Check for nearby workers
   		list<worker> nearby_workers <- worker at_distance perception_distance;
   		if not empty(nearby_workers) {
   			being_alerted <- true;
   			do remove_belief(not_alerted);
   			do add_belief(alerted);
   			do remove_desire(watch);
   			do add_desire(predicate: escape, strength: 5.0);
   		}
   		
   		// Check for nearby alerted spectators
   		list<spectator> nearby_alerted <- (spectator at_distance perception_distance) where (each.being_alerted);
   		if not empty(nearby_alerted) {
   			being_alerted <- true;
   			do remove_belief(not_alerted);
   			do add_belief(alerted);
   			do remove_desire(watch);
   			do add_desire(predicate: escape, strength: 5.0);
   		}
   	}
   	
   	reflex modify_speed {
   		// Check for nearby workers
   		list<worker> nearby_workers <- worker at_distance perception_distance;
   		
   		// Check for nearby spectators
   		list<spectator> nearby_spectators <- spectator at_distance perception_distance;
   		
   		int n_people <- length(nearby_workers) + length(nearby_spectators);
   		speed <- speed * (0.5 + 0.5 * exp(-0.01 * n_people));
   	}
   	
   	reflex role_influence {
	    list<spectator> nearby_spectators <- (spectator at_distance perception_distance) where (each != self);
	    list<worker> nearby_workers <- (worker at_distance perception_distance) where (each != self);
	
	    // Leaders increasing speed
	    if (role = "leader") {
	        loop s over: nearby_spectators {
	            s.speed <- s.speed * 1.2;
	        }
	        loop s over: nearby_workers {
	            s.speed <- s.speed * 1.2;
	        }
	    }
	
	    // Panic slowing speed
	    if (role = "panic") {
	        loop s over: nearby_spectators {
	            s.speed <- s.speed * 0.8;
	        }
	        loop s over: nearby_workers {
	            s.speed <- s.speed * 0.8;
	        }
    	}
	}
   	
	// Rules
    rule belief: not_alerted new_desire: watch strength: 1.0;
    rule belief: alerted new_desire: escape strength: 2.0;
    
    // Plans ------------------------------------------------------------------------------------------
    plan watching intention: watch {
		// Just watching
    }
    
    plan escape_danger intention: escape {
    	// Movement now handled by reflex above
    }
    
    aspect default {
		    rgb c <- 	being_alerted ? #red : (role = "leader" ? #green :(role = "panic" ? #violet : #black));

		
		    if (role = "leader") {
		    	draw square(12#m) color: c;
		    } else if (role = "panic") {
		    	draw triangle(12#m) color: c;
		    } else {
		    	draw circle(4#m) color: c;
		    }
	}
    
}

species worker skills: [moving] control: simple_bdi{
	
	bool drowned;
    bool saved;
    float perception_distance;
    float speed <- 5.0 #km / #h;
    evacuation_point safety_point;
    bool being_alerted <- true;
    string role <- "leader"; // always leader
    
    // BELIEFS
    predicate not_alerted <- new_predicate("not_alerted");
    predicate alerted <- new_predicate("alerted");
    predicate dead <- new_predicate("dead");
    
    // DESIRES
    predicate watch <- new_predicate("watch");
    predicate escape <- new_predicate("escape");

   	init {
   		do add_belief(alerted);
   		do add_desire(escape);
   		being_alerted <- true;
   	}
   	
   	// Reflexes ---------------------------------------------------------------------------------------
    
    reflex drown when:not(drowned or saved) {
        if(first(hazard) covers self){
            drowned <- true;
            victims <- victims + 1; 
            do die;
        }
    }
    
    reflex escaped when: not(saved) and location distance_to safety_point < 2#m{
        saved <- true;
        safe_people <- safe_people + 1;
        do die;
    }
    
    // DIRECT MOVEMENT - same as spectators
    reflex move_to_safety when: being_alerted and not (saved or drowned) {
        do goto target: safety_point on: road_network speed: speed;
    }
    
    reflex modify_speed {
   		// Check for nearby workers
   		list<worker> nearby_workers <- worker at_distance perception_distance;
   		
   		// Check for nearby spectators
   		list<spectator> nearby_spectators <- spectator at_distance perception_distance;
   		
   		int n_people <- length(nearby_workers) + length(nearby_spectators);
   		speed <- speed * (0.5 + 0.5 * exp(-0.01 * n_people));
   	}
   	
   	reflex role_influence {
	    list<spectator> nearby_spectators <- (spectator at_distance perception_distance) where (each != self);
	    list<worker> nearby_workers <- (worker at_distance perception_distance) where (each != self);
	
	    // Leaders increasing speed
        loop s over: nearby_spectators {
            s.speed <- s.speed * 1.2;
        }
        loop s over: nearby_workers {
            s.speed <- s.speed * 1.2;
        }
	}
    
	// Rules
    rule belief: not_alerted new_desire: watch strength: 1.0;
    rule belief: alerted new_desire: escape strength: 2.0;
    
    // Plans ------------------------------------------------------------------------------------------
    plan watching intention: watch {
		// do nothing
    }
    
    plan escape_danger intention: escape {
    	// Movement now handled by reflex above
    }
    
    aspect default {
        draw sphere(8#m) color: #blue;
    }
}

// OK
species evacuation_point {
	
	int count_exit_spectators <- 0 update: length((spectator where each.saved) at_distance 2#m);
	int count_exit_workers <- 0 update: length((worker where each.saved) at_distance 2#m);
		
	aspect default {
		// Corrected transparency syntax (0-255, not 0-1)
		draw circle(20#m+49#m*(count_exit_spectators + count_exit_workers)/(nb_of_spectators + nb_of_workers)) color: rgb(0, 255, 0, 180); // 180 is ~70% opacity
	}
}

// OK
species road {
	aspect default{
		draw shape width: 1#m color:rgb(55,0,0);
	}	
}

// OK
species building {
	aspect default {
		draw shape color: #gray border: #black depth: 1;
	}
}


experiment "Run_Stadium" type:gui {
	
	// --- ADJUSTED PARAMETERS ---
	
	parameter "Hazard Speed (m/min)" var:flood_front_speed init:10.0 min:1.0 max:30.0 unit:"m/min" category:"Hazard";
	parameter "Time Before Hazard (min)" var:time_before_hazard init:1 min:0 max:10 unit:"min" category:"Hazard";
	
	parameter "Number of Spectators" var:nb_of_spectators init:500 min:0 max:20000 category:"Initialization";
	parameter "Number of Workers" var:nb_of_workers init:50 min:0 max:200 category:"Initialization";
	
	output {
		display my_display type:3d axes:false{ 
			species road;
			species evacuation_point;
			species building; 
			species hazard ;
			species spectator;
			species worker;
		}
		monitor "Number of Saved people: " value: safe_people; 
		monitor "Number of Victims: " value:victims;
	}	
	
}