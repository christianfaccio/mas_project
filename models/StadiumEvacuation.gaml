/***
* Name: StadiumEvacuation
* Authors: Christian Faccio, Javier Arribas González, Luis Bernabeu Agüeria, Imanol Jurado Martínez, Bruno Sancho Deltell
* Description: Our project focuses on the simulation and analysis of crowd evacuation behavior and dynamics during sporting 
* events using agent-based modelling. Each agent represents an individual spectator with autonomous decision-making 
* capabilities, potentially including more sophisticated dynamics like stadium geometry or police agents. 
* The objectives include spotting bottlenecks in stadium emergency exits, analyzing crowd behavior to better improve 
* stadiums' geometry and evaluate how factors like staff guidance and crowd management protocols impact evacuation 
* efficiency and safety.
* Tags: evacuation, stadium, crowd, agent, gis, hazard
***/
model StadiumEvacuation

// OK
global {
	
	// People parameters
	float workers_over_spectators <- 0.1; // ex. 2 workers per 8 spectators
	int tot_people <- 500;
	int nb_of_spectators <- int((1 / (1 + workers_over_spectators)) * tot_people);
	int nb_of_workers <- tot_people - nb_of_spectators;
	
	float min_perception_distance <- 1.0;
	float max_perception_distance <- 5.0;
	
	float speed_ratio <- 2.0; // hazard_speed / people_speed
	
	float abs_speed <- 5.0;
	float speed <- abs_speed #m/#mn;
	float exp_weight <- 0.01;
	float perc_increase <- 0.2;
	
	float leader_frac <- 0.1;
	float follower_frac <- 0.75;
	
	// Hazard parameters
	int time_before_hazard <- 1; // (min)
	float flood_front_speed <- abs_speed * speed_ratio; // Speed of hazard expansion (m/min)
	
	// --- GIS FILE PATHS FOR THE STADIUM ---
	file road_file <- file("../includes/paths.shp");
	file buildings <- file("../includes/buildings.shp");
	file evac_points <- file("../includes/exits.shp");
	// ---------------------------------------------
	
	geometry shape <- envelope(envelope(road_file)+envelope(buildings)+envelope(evac_points));
	
	graph<geometry, geometry> road_network;
	
	// Data output
	int tot_victims;
	int tot_saved_people;
	int tot_spectators_victims;
	int tot_spectators_saved;
	int tot_workers_victims;
	int tot_workers_saved;
	int tot_leaders_victims;
	int tot_leaders_saved;
	int tot_followers_victims;
	int tot_followers_saved;
	int tot_panic_victims;
	int tot_panic_saved;
	
	
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
		    if (r < leader_frac) {
		        role <- "leader";
		    } else if (r < (leader_frac + follower_frac)) {
		        role <- "follower";
		    } else {
		        role <- "panic";
		        perception_distance <- 1.0;
		    }
   	}
   	
   	// Reflexes ---------------------------------------------------------------------------------------
    
    reflex drown when:not(drowned or saved) {
	    if(first(hazard) covers self){
	        drowned <- true;
	        tot_victims <- tot_victims + 1;
	        tot_spectators_victims <- tot_spectators_victims + 1;
	        
	        // Count by role
	        if (role = "leader") {
	            tot_leaders_victims <- tot_leaders_victims + 1;
	        } else if (role = "follower") {
	            tot_followers_victims <- tot_followers_victims + 1;
	        } else if (role = "panic") {
	            tot_panic_victims <- tot_panic_victims + 1;
	        }
	        
	        do die;
	    }
	}

	reflex escaped when: not(saved) and location distance_to safety_point < 2#m{
	    saved <- true;
	    tot_saved_people <- tot_saved_people + 1;
	    tot_spectators_saved <- tot_spectators_saved + 1;
	    
	    // Count by role
	    if (role = "leader") {
	        tot_leaders_saved <- tot_leaders_saved + 1;
	    } else if (role = "follower") {
	        tot_followers_saved <- tot_followers_saved + 1;
	    } else if (role = "panic") {
	        tot_panic_saved <- tot_panic_saved + 1;
	    }
	    
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
   		speed <- speed * (0.5 + 0.5 * exp(-exp_weight * n_people));
   	}
   	
   	reflex role_influence {
	    list<spectator> nearby_spectators <- (spectator at_distance perception_distance) where (each != self);
	    list<worker> nearby_workers <- (worker at_distance perception_distance) where (each != self);
	
	    // Leaders increasing speed
	    if (role = "leader") {
	        loop s over: nearby_spectators {
	            s.speed <- s.speed * (1.0 + perc_increase);
	        }
	        loop s over: nearby_workers {
	            s.speed <- s.speed * (1.0 + perc_increase);
	        }
	    }
	
	    // Panic slowing speed
	    if (role = "panic") {
	        loop s over: nearby_spectators {
	            s.speed <- s.speed * (1.0 - perc_increase);
	        }
	        loop s over: nearby_workers {
	            s.speed <- s.speed * (1.0 - perc_increase);
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
    	// Movement handled by reflex above
    }
    
    aspect default {
		    rgb c <- being_alerted ? #red : (role = "leader" ? #green :(role = "panic" ? #violet : #black));

		
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
	        tot_victims <- tot_victims + 1;
	        tot_workers_victims <- tot_workers_victims + 1;
	        do die;
	    }
	}

	reflex escaped when: not(saved) and location distance_to safety_point < 2#m{
	    saved <- true;
	    tot_saved_people <- tot_saved_people + 1;
	    tot_workers_saved <- tot_workers_saved + 1;
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
   		speed <- speed * (0.5 + 0.5 * exp(-exp_weight * n_people));
   	}
   	
   	reflex role_influence {
	    list<spectator> nearby_spectators <- (spectator at_distance perception_distance) where (each != self);
	    list<worker> nearby_workers <- (worker at_distance perception_distance) where (each != self);
	
	    // Leaders increasing speed
        loop s over: nearby_spectators {
            s.speed <- s.speed * (1.0 + perc_increase);
        }
        loop s over: nearby_workers {
            s.speed <- s.speed * (1.0 + perc_increase);
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
    output {
        display my_display type:3d axes:false{ 
            species road;
            species evacuation_point;
            species building; 
            species hazard ;
            species spectator;
            species worker;
        }
        
        // Overall statistics
        monitor "Number of Saved people: " value: tot_saved_people; 
        monitor "Number of Victims: " value: tot_victims;
        
        // Spectators vs Workers
        monitor "Spectators Saved: " value: tot_spectators_saved;
        monitor "Spectators Victims: " value: tot_spectators_victims;
        monitor "Workers Saved: " value: tot_workers_saved;
        monitor "Workers Victims: " value: tot_workers_victims;
        
        // Role breakdown
        monitor "Leaders Saved: " value: tot_leaders_saved;
        monitor "Leaders Victims: " value: tot_leaders_victims;
        monitor "Followers Saved: " value: tot_followers_saved;
        monitor "Followers Victims: " value: tot_followers_victims;
        monitor "Panic Saved: " value: tot_panic_saved;
        monitor "Panic Victims: " value: tot_panic_victims;
    }    
}

experiment "nb_workers vs nb_spectators" type: batch until: spectator all_match (each.saved or each.drowned) and worker all_match (each.saved or each.drowned) repeat: 20 {
	parameter "Tot people" var: tot_people min: 500 max: 2000 step: 100;
	parameter "Workers/Spectators" var: workers_over_spectators min: 0.1 max 0.9 step: 0.1;
	
	reflex save_results {
		ask simulations {
			save [	tot_people,
					workers_over_spectators,
					nb_of_spectators,
					nb_of_workers,
					min_perception_distance,
					max_perception_distance,
					speed,
					speed_ratio,
					time_before_hazard,
					leader_frac,
					follower_frac,
					tot_victims, 
					tot_saved_people,
					tot_spectators_victims,
					tot_spectators_saved,	
					tot_workers_victims,
					tot_workers_saved,
					tot_leaders_victims,
					tot_leaders_saved,
					tot_followers_victims,
					tot_followers_saved,
					tot_panic_victims,
					tot_panic_saved
				]
			to: "../analysis/results/1.csv" format: "csv" rewrite: false;
		}
	}
}

experiment "Perception Distance" type: batch until: spectator all_match (each.saved or each.drowned) and worker all_match (each.saved or each.drowned) repeat: 20 {
	parameter "Min perception distance" var: min_perception_distance min: 1.0 max: 5.0 step: 1.0;
	parameter "Max perception distance" var: max_perception_distance min: 10.0 max: 15.0 step: 1.0;
	
	reflex save_results {
		ask simulations {
			save [	tot_people,
					workers_over_spectators,
					nb_of_spectators,
					nb_of_workers,
					min_perception_distance,
					max_perception_distance,
					speed,
					speed_ratio,
					time_before_hazard,
					leader_frac,
					follower_frac,
					tot_victims, 
					tot_saved_people,
					tot_spectators_victims,
					tot_spectators_saved,	
					tot_workers_victims,
					tot_workers_saved,
					tot_leaders_victims,
					tot_leaders_saved,
					tot_followers_victims,
					tot_followers_saved,
					tot_panic_victims,
					tot_panic_saved
				]
			to: "../analysis/results/2.csv" format: "csv" rewrite: false;
		}
	}
}

experiment "Speed people vs Speed hazard ratio" type: batch until: spectator all_match (each.saved or each.drowned) and worker all_match (each.saved or each.drowned) repeat: 20 {
	parameter "Speed people" var: abs_speed min: 1.0 max: 10.0 step: 1.0;
	parameter "Speed ratio" var: speed_ratio min: 2.0 max: 5.0 step: 0.5;
	
	reflex save_results {
		ask simulations {
			save [	tot_people,
					workers_over_spectators,
					nb_of_spectators,
					nb_of_workers,
					min_perception_distance,
					max_perception_distance,
					speed,
					speed_ratio,
					time_before_hazard,
					leader_frac,
					follower_frac,
					tot_victims, 
					tot_saved_people,
					tot_spectators_victims,
					tot_spectators_saved,	
					tot_workers_victims,
					tot_workers_saved,
					tot_leaders_victims,
					tot_leaders_saved,
					tot_followers_victims,
					tot_followers_saved,
					tot_panic_victims,
					tot_panic_saved
				]
			to: "../analysis/results/3.csv" format: "csv" rewrite: false;
		}
	}
}

experiment "Spectator type %" type: batch until: spectator all_match (each.saved or each.drowned) and worker all_match (each.saved or each.drowned) repeat: 20 {
	parameter "Leader %" var: leader_frac min: 0.1 max: 0.5 step: 0.1;
	parameter "Follower %" var: follower_frac min: 0.1 max: 0.5 step: 0.1;
	
	reflex save_results {
		ask simulations {
			save [	tot_people,
					workers_over_spectators,
					nb_of_spectators,
					nb_of_workers,
					min_perception_distance,
					max_perception_distance,
					speed,
					speed_ratio,
					time_before_hazard,
					leader_frac,
					follower_frac,
					tot_victims, 
					tot_saved_people,
					tot_spectators_victims,
					tot_spectators_saved,	
					tot_workers_victims,
					tot_workers_saved,
					tot_leaders_victims,
					tot_leaders_saved,
					tot_followers_victims,
					tot_followers_saved,
					tot_panic_victims,
					tot_panic_saved
				]
			to: "../analysis/results/4.csv" format: "csv" rewrite: false;
		}
	}
}

experiment "Hazard params" type: batch until: spectator all_match (each.saved or each.drowned) and worker all_match (each.saved or each.drowned) repeat: 20 {
	parameter "Time before hazard" var: time_before_hazard min: 1 max: 10 step: 1;
	parameter "Speed ratio" var: speed_ratio min: 0.5 max: 3.0 step: 0.5;
	
	reflex save_results {
		ask simulations {
			save [	tot_people,
					workers_over_spectators,
					nb_of_spectators,
					nb_of_workers,
					min_perception_distance,
					max_perception_distance,
					speed,
					speed_ratio,
					time_before_hazard,
					leader_frac,
					follower_frac,
					tot_victims, 
					tot_saved_people,
					tot_spectators_victims,
					tot_spectators_saved,	
					tot_workers_victims,
					tot_workers_saved,
					tot_leaders_victims,
					tot_leaders_saved,
					tot_followers_victims,
					tot_followers_saved,
					tot_panic_victims,
					tot_panic_saved
				]
			to: "../analysis/results/5.csv" format: "csv" rewrite: false;
		}
	}
}
