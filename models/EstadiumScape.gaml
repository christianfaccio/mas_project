/***
* Nombre: StadiumEvacuation
* Autor: kevinchapuis (Adaptado para estadio)
* Descripción: Un modelo de evacuación de un estadio. REUTILIZA las especies de CityEscape.
* El mapa se define por MUROS (cargados como 'building') y CAMINOS_ESTADIO (cargados como 'road').
* Los 'inhabitant' (espectadores) se crean SOBRE los 'road' (caminos) y deben
* llegar a los 'evacuation_point' (salidas).
* Tags: evacuacion, estadio, multitud, agente, gis, peligro
***/
model StadiumEvacuation

global {
	
	// Fecha de inicio de la simulación
	date starting_date <- #now;
	
	// Paso de tiempo (1 segundo es mejor para movimientos en estadios)
	float step <- 1#sec;
	
	int nb_of_people;
	
	// Distancia de percepción
	float min_perception_distance <- 10.0;
	float max_perception_distance <- 30.0;
	
	// Capacidad de los pasillos: número de 'inhabitant' por metro
	float road_density;
	
	// Parámetros de la estrategia de alerta
	int time_after_last_stage;
	string the_alert_strategy;
	int nb_stages;
	
	// Parámetros del peligro
	int time_before_hazard;
	float flood_front_speed; // Velocidad de expansión del peligro (m/mn)
	
	// --- RUTAS DE ARCHIVOS GIS DEL ESTADIO ---
	// 'road_file' ahora apunta a los CAMINOS
	file road_file <- file("../includes/CAMINOS_ESTADIO.shp");
	// 'buildings' ahora apunta a los MUROS
	file buildings <- file("../includes/MUROS.shp");
	
	// ESTOS SE MANTIENEN para que la simulación funcione
	file evac_points <- file("../includes/evacuation_environment.shp");
	file water_body <- file("../includes/sea_environment.shp");
	// ---------------------------------------------
	
	geometry shape <- envelope(envelope(road_file)+envelope(buildings)+envelope(evac_points));
	
	// Grafo de 'road' (que ahora son los caminos)
	graph<geometry, geometry> road_network;
	map<road,float> road_weights;
	
	// Salida de datos (usa la variable original 'casualties')
	int casualties;
	
	init {
				
		// Crea las especies originales con los archivos nuevos
		create road from:road_file;       // Crea "caminos"
		create building from:buildings;   // Crea "muros"
		create evacuation_point from:evac_points; // Crea "salidas"
		create hazard from: water_body;   // Crea "fuego/humo"
		
		// --- CAMBIO DE LÓGICA DE INICIO ---
		// Crea 'inhabitant' (espectadores) SOBRE los 'road' (caminos),
		// ya que los 'building' ahora son solo muros.
		create inhabitant number:nb_of_people {
			location <- any_location_in(one_of(road));
			safety_point <- any(evacuation_point);
			perception_distance <- rnd(min_perception_distance, max_perception_distance);
		}
		// --- FIN DEL CAMBIO ---
		
		// El gestor de crisis original
		create crisis_manager;
		
		road_network <- as_edge_graph(road);
		road_weights <- road as_map (each::each.shape.perimeter);
	
	}
	
	// Reflex de parada original (usa 'inhabitant' y 'drowned')
	reflex stop_simu when:inhabitant all_match (each.saved or each.drowned) {
		do pause;
	}
	
}

/*
 * Agent responsible of the communication strategy
 * (Sin cambios)
 */
species crisis_manager {
	
	float alert_range;
	int nb_per_stage;
	geometry buffer;
	float distance_buffer;
	
	init {
		int modulo_stage <- length(inhabitant) mod nb_stages; 
		nb_per_stage <- int(length(inhabitant) / nb_stages) + (modulo_stage = 0 ? 0 : 1);
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
	
	list<inhabitant> alert_target {
		switch the_alert_strategy {
			match "STAGED" {
				return nb_per_stage among (inhabitant where (each.alerted = false));
			}
			match "SPATIAL" {
				buffer <- buffer buffer distance_buffer;
				return inhabitant overlapping buffer;
			}
			match "EVERYONE" {
				return list(inhabitant);
			}
			default {
				return [];
			}
		}
	}
}

/*
 * Representa el peligro (fuego/humo)
 * (Sin cambios)
 */
species hazard {
	
	date catastrophe_date;
	bool triggered;
	
	init {
		catastrophe_date <- current_date + time_before_hazard#mn;
	}
	
	reflex expand when:catastrophe_date < current_date {
		if(not(triggered)) {triggered <- true;}
		// Usa la variable original 'flood_front_speed'
		shape <- shape buffer (flood_front_speed#m/#mn * step) intersection world;
	}
	
	aspect default {
		// Sintaxis de transparencia corregida
		draw shape color: rgb(255, 0, 0, 0.6);
	}
}

/*
 * Representa al espectador ('inhabitant')
 * (Sin cambios)
 */
species inhabitant skills:[moving] {
	
	bool alerted <- false;
	bool drowned <- false; // 'drowned' ahora significa 'víctima'
	bool saved <- false;
	
	float perception_distance;
	evacuation_point safety_point;
	float speed <- 10#km/#h; // Puedes bajar esta velocidad si quieres
	
	reflex drown when:not(drowned or saved) {
		if(first(hazard) covers self){
			drowned <- true;
			casualties <- casualties + 1; 
		}
	}
	
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
	
	reflex escape when: not(saved) and location distance_to safety_point < 2#m{
		saved <- true;
		alerted <- false;
	}
	
	aspect default {
		draw sphere(1#m) color:drowned ? #black : (alerted ? #red : #green);
	}
}

/*
 * El punto de evacuación (Salida)
 * (Sin cambios)
 */
species evacuation_point {
	
	int count_exit <- 0 update: length((inhabitant where each.saved) at_distance 2#m);
		
	aspect default {
		// Sintaxis de transparencia corregida
		draw circle(1#m+49#m*count_exit/nb_of_people) color: rgb(0, 255, 0, 0.7);
	}
}

/*
 * Los caminos del estadio ('road')
 * (Sin cambios)
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
 * Los muros del estadio ('building')
 * (Sin cambios)
 */
species building {
	aspect default {
		draw shape color: #gray border: #black depth: 1;
	}
}

experiment "Run_Stadium" type:gui {
	float minimum_cycle_duration <- 0.1;
		
	// --- PARÁMETROS AJUSTADOS ---
	
	parameter "Estrategia de Alerta" var:the_alert_strategy init:"STAGED" among:["NONE","STAGED","SPATIAL","EVERYONE"] category:"Alert";
	parameter "Número de etapas" var:nb_stages init:6 category:"Alert";
	parameter "Tiempo de búfer (mn)" var:time_after_last_stage init:2 unit:"mn" category:"Alert";
	
	parameter "Densidad de Caminos" var:road_density init:4.0 min:0.1 max:10.0 category:"Congestion";
	
	parameter "Velocidad Peligro (m/mn)" var:flood_front_speed init:10.0 min:1.0 max:30.0 unit:"m/mn" category:"Hazard";
	parameter "Tiempo antes del peligro (mn)" var:time_before_hazard init:3 min:0 max:10 unit:"mn" category:"Hazard";
	
	parameter "Número de Espectadores" var:nb_of_people init:1000 min:100 max:20000 category:"Initialization";
	
	output {
		display my_display type:3d axes:false{ 
			// Dibuja las especies originales
			species road;
			species evacuation_point;
			species building; // Esto dibujará los MUROS
			species hazard ;
			species inhabitant;
		}
		monitor "Número de víctimas" value:casualties;
	}	
	
}
