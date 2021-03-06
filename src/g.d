import allegro5.allegro;
import allegro5.allegro_primitives;
import allegro5.allegro_image;
import allegro5.allegro_font;
import allegro5.allegro_ttf;
import allegro5.allegro_color;

import std.stdio;
import std.math;
import std.conv;
import std.string;
import std.random;
import std.algorithm : remove;
import std.datetime;
import std.datetime.stopwatch : benchmark, StopWatch, AutoStart;

import helper;
import objects;
import viewportsmod;
import graph;
import particles;
import planetsmod;
import bulletsmod;

immutable float PLANET_MASS = 4000;
immutable float PLANET_MASS_FOR_BULLETS = 20_000;

//ALLEGRO_CONFIG* 		cfg;  //whats this used for?
ALLEGRO_DISPLAY* 		al_display;
ALLEGRO_EVENT_QUEUE* 	queue;
ALLEGRO_TIMER* 			fps_timer;
ALLEGRO_TIMER* 			screencap_timer;

FONT* 	font1;

BITMAP* ship_bmp;
BITMAP* freighter_bmp;
BITMAP* smoke_bmp;
BITMAP* small_asteroid_bmp;
BITMAP* medium_asteroid_bmp;
BITMAP* large_asteroid_bmp;
BITMAP* space_bmp;
BITMAP* bullet_bmp;
BITMAP* dude_bmp;
BITMAP* trailer_bmp;
BITMAP* turret_bmp;
BITMAP* turret_base_bmp;
BITMAP* satellite_bmp;

BITMAP* chest_bmp;
BITMAP* chest_open_bmp;
BITMAP* dwarf_bmp;
BITMAP* goblin_bmp;
BITMAP* boss_bmp;
BITMAP* fountain_bmp;
BITMAP* tree_bmp;
BITMAP* wall_bmp;
BITMAP* grass_bmp;
BITMAP* lava_bmp;
BITMAP* water_bmp;
BITMAP* wood_bmp;
BITMAP* stone_bmp;
BITMAP* reinforced_wall_bmp;
BITMAP* sword_bmp;
BITMAP* carrot_bmp;
BITMAP* potion_bmp;
BITMAP* blood_bmp;

int SCREEN_W = 1360;
int SCREEN_H = 720;

intrinsicGraph!float testGraph;
intrinsicGraph!float testGraph2;

void loadResources()	
	{
	font1 = getFont("./data/DejaVuSans.ttf", 18);

	bullet_bmp  			= getBitmap("./data/bullet.png");
	ship_bmp			  	= getBitmap("./data/ship.png");
	freighter_bmp		  	= getBitmap("./data/freighter.png");
	small_asteroid_bmp  	= getBitmap("./data/small_asteroid.png");
	medium_asteroid_bmp  	= getBitmap("./data/medium_asteroid.png");
	large_asteroid_bmp  	= getBitmap("./data/large_asteroid.png");
	smoke_bmp  				= getBitmap("./data/smoke.png");
	space_bmp  				= getBitmap("./data/seamless_space.png");
	bullet_bmp  			= getBitmap("./data/bullet.png");
	dude_bmp	  			= getBitmap("./data/dude.png");
	trailer_bmp	  			= getBitmap("./data/trailer.png");
	turret_bmp	  			= getBitmap("./data/turret.png");
	turret_base_bmp			= getBitmap("./data/turret_base.png");
	satellite_bmp			= getBitmap("./data/satellite.png");
	
	sword_bmp  			= getBitmap("./data/sword.png");
	carrot_bmp  		= getBitmap("./data/carrot.png");
	potion_bmp  		= getBitmap("./data/potion.png");
	chest_bmp  			= getBitmap("./data/chest.png");
	chest_open_bmp  	= getBitmap("./data/chest_open.png");

	dwarf_bmp  		= getBitmap("./data/dwarf.png");
	goblin_bmp  	= getBitmap("./data/goblin.png");
	boss_bmp 	 	= getBitmap("./data/boss.png");

	wall_bmp  		= getBitmap("./data/wall.png");
	grass_bmp  		= getBitmap("./data/grass.png");
	lava_bmp  		= getBitmap("./data/lava.png");
	water_bmp  		= getBitmap("./data/water.png");
	fountain_bmp  	= getBitmap("./data/fountain.png");
	wood_bmp  		= getBitmap("./data/wood.png");
	stone_bmp  		= getBitmap("./data/brick.png");
	tree_bmp  		= getBitmap("./data/tree.png");
	blood_bmp  		= getBitmap("./data/blood.png");
	reinforced_wall_bmp  	= getBitmap("./data/reinforced_wall.png");	
	}

alias KEY_UP = ALLEGRO_KEY_UP; // should we do these? By time we write them out we've already done more work than just writing them.
alias KEY_DOWN = ALLEGRO_KEY_DOWN; // i'll leave them coded as an open question for later
alias KEY_LEFT = ALLEGRO_KEY_LEFT; 
alias KEY_RIGHT = ALLEGRO_KEY_RIGHT; 

alias COLOR = ALLEGRO_COLOR;
alias BITMAP = ALLEGRO_BITMAP;
alias FONT = ALLEGRO_FONT;
	
struct ipair
	{
	int x;
	int y;
	this(int _x, int _y) //needed?
		{
		x = _x;
		y = _y;
		}
	}

struct apair
	{
	float a; /// angle
	float m; /// magnitude
	} // idea: some sort of automatic convertion between angle/magnitude, and xy velocities?

struct rpair // relative pair. not sure best way to implement conversions
	{
	float x;
	float y;
	}

struct pair
	{
	float x;
	float y;
	
	this(T)(T t) //give it an object that has fields x and y
		{
		x = t.x;
		y = t.y;
		}
	
	this(int _x, int _y)
		{
		x = to!float(_x);
		y = to!float(_y);
		}

	this(float _x, float _y)
		{
		x = _x;
		y = _y;
		}
		
	this(double _x, double _y)
		{
		x = _x;
		y = _y;
		}
	}

world_t world;
viewport[2] viewports;

class player
	{
	int myTeamIndex;
	ship currentShip; //current. Also how do we handle with units die / switch active ship (if that's an option)
//	int money=1000; //we might have team based money accounts. doesn't matter yet.
	int kills=0;
	int aikills=0;
	int deaths=0;
	
	this(ship who)
		{
		currentShip = who;
		}
		
	void onTick()
		{
		if(cooldown > 0)cooldown--;
		}
		
	int cooldown = 0; // to prevent rapid spamming
	void findNextShip()
		{
		if(cooldown > 0){return;}
		cooldown = 20;
		bool hasFoundMe=false;
		int idx = 0;
		foreach(u; g.world.units)
			{
			if(g.world.units[$-1] is currentShip){hasFoundMe=true;} // degenerate case of we're last item in array, so we start "viable" candidate at start. This would be super easy if everything was in terms of indexes instead of pointers
			idx++;
			ship s = cast(ship)u;
//			writefln("looking at [%s] index %d of %d name=%s",u, idx, g.world.units.length, s.name);
			if(s !is null)
				if(s !is currentShip)
					{
					if(hasFoundMe)
//					if(s.myTeamIndex == myTeamIndex)
						{
	//					writeln("found");
						currentShip.isPlayerControlled = false;
						currentShip = s;
						currentShip.isPlayerControlled = true;
						g.viewports[0].attach(s);
						break;
						}
					}else{
//					writeln("same ship");
					hasFoundMe = true;
					}
			}
		}
		
	}
	
class team
	{
	int money=0;
	int aikills=0;
	int kills=0;
	int deaths=0;
	COLOR color;
	
	this(player p, COLOR teamColor)
		{
		color = teamColor;
		}
	}
	
class world_t
	{	
	player[] players;
	team[] teams;
				
	baseObject[] objects; // other stuff
	unit[] units;
 	//structure_t[] structures; // should all structures be owned by a planet? are there 'free floating' structures we'd have? an asteroid structure that's just a structure?
	planet[] planets;
	asteroid[] asteroids;
	particle[] particles;
	bullet[] bullets;

	this()
		{		
		auto s = new ship(315, 1850, 0, 0);	
		s.name = "Interdicter";
		s.myTeamIndex = 1;
		units ~= s; //which comes first, player or the egg
		players ~= new player(s);
		teams ~= new team(players[0], blue);
		players[0].myTeamIndex = 0; // teams[0];
		
		auto s2 = new ship(20, 20, 0, 0); // was freighter
	
		s.isOwned = true;
		s.currentOwner = players[0];
		s2.myTeamIndex = 1;
		s2.isOwned = true;
		s2.currentOwner = players[0];
		units ~= s2;
		
		assert(viewports[0] !is null);
		viewports[0].attach(s);

		{
		auto s3 = new ship(600, 200, 0, 0);
		s3.name = "Tacobus";
		s3.myTeamIndex = 2;
		units ~= s3;
		}
		{
		auto s4 = new ship(600, 200, 0, 0);
		s4.name = "Timid";
		s4.myTeamIndex = 2;
		units ~= s4;
		}
		
		// note structures currently pre-req a player instantiated
		float r = 1000;
		auto pl = new planet("first", 400, 3000, r, 25);
		planets ~= pl;
		planets ~= new planet("second", 1210, 410, 100, 0);
		planets[1].m = PLANET_MASS*.25; // we get CLOSER to SMALLER planets making gravity much larger if its the same mass!
		planets ~= new planet("third", 1720, 520, 50, 0);
		planets[2].m = PLANET_MASS*.05;
		//planets[2].isProducer = true;
		
		for(int i = 0; i < 25; i++)
			{
			float angle = uniform!"[]"(0, 2*PI);
			float distance = uniform!"[]"(2*r, 3*r);
			float cx = pl.x + cos(angle)*distance;
			float cy = pl.y + sin(angle)*distance;
			asteroids ~= new asteroid(cx, cy, 0.1, 0, .02, uniform!"[]"(0,2));
			}

		testGraph = new intrinsicGraph!float("Draw (ms)", g.stats.nsDraw, 100, 200, COLOR(1,0,0,1), 1_000_000);
		testGraph2 = new intrinsicGraph!float("Logic (ms)", g.stats.msLogic, 100, 320, COLOR(1,0,0,1), 1_000_000);
	
		stats.swLogic = StopWatch(AutoStart.no);
		stats.swDraw = StopWatch(AutoStart.no);
		}
		
	void drawSpace(viewport v) //FIXME
		{
//		auto p = al_get_pixel(al_get_backbuffer(al_display), 0, 0);
//		writefln("[temp1] R%f G%f B%f A%f", p.r, p.g, p.b, p.a);	
	//	pair[] data;
		
		for(float i = -g.space_bmp.w; i < SCREEN_W; i += g.space_bmp.w)
			for(float j = -g.space_bmp.h; j < SCREEN_H; j += g.space_bmp.h)
				{					
	//			data ~= pair(i, j);
				al_draw_tinted_bitmap(g.space_bmp, COLOR(1,1,1,1), i, j, 0);
				}
		
//		writefln("points drawn at: %s", data);
		}
/+
//		auto p2 = al_get_pixel(al_get_backbuffer(al_display), 0, 0);
//		writefln("[temp2] R%f G%f B%f A%f", p2.r, p2.g, p2.b, p2.a);	
		for(int i = -2; i < 2; i++)
			for(int j = -2; j < 2; j++)
				{
				COLOR c = COLOR(1,1,1,.5); 
				al_draw_tinted_bitmap(g.space_bmp, c, 0 + v.x - v.ox/2 + g.space_bmp.w*i, 0 + v.y - v.oy/2 + g.space_bmp.h*j, 1);
				}
//		auto p3 = al_get_pixel(al_get_backbuffer(al_display), 0, 0);
//		writefln("[temp3] R%f G%f B%f A%f", p3.r, p3.g, p3.b, p2.a);	
		for(int i = -4; i < 4; i++)
			for(int j = -4; j < 4; j++)
				{
				COLOR c = COLOR(1,1,1,.25); 
				al_draw_tinted_bitmap(g.space_bmp, c, 0 + v.x - v.ox/4 + g.space_bmp.w*i, 0 + v.y - v.oy/4 + g.space_bmp.h*j, 3);
				}
		}
	+/	
	void draw(viewport v)
		{
		drawSpace(v);
		stats.swDraw.start();

		void draw(T)(ref T obj)
			{
			foreach(ref o; obj)
				{
				o.draw(v);
				}
			}
		
		void drawStat(T, U)(ref T obj, ref U stat)
			{
			foreach(ref o; obj)
				{
				stat++;
				o.draw(v);
				}
			}

		void drawStat2(T, U)(ref T obj, ref U stat, ref U clippedStat)
			{
			foreach(ref o; obj)
				{
				if(o.draw(v))
					{
					stat++;
					}else{
					clippedStat++;
					}
				}
			}
		
		drawStat2(planets, 	stats.number_of_drawn_units, 	stats.number_of_drawn_units_clipped);
		drawStat2(asteroids, stats.number_of_drawn_asteroids, stats.number_of_drawn_asteroids_clipped);
		drawStat2(bullets, 	stats.number_of_drawn_bullets, 	stats.number_of_drawn_bullets_clipped);
		drawStat2(particles, stats.number_of_drawn_particles, stats.number_of_drawn_particles_clipped);
		drawStat2(units, 	stats.number_of_drawn_units, stats.number_of_drawn_units_clipped);
//		drawStat(structures, stats.number_of_drawn_structures);		

		testGraph.draw(v);
		testGraph2.draw(v);
		stats.swDraw.stop();
		stats.nsDraw = stats.swDraw.peek.total!"nsecs";
		stats.swDraw.reset();
		}
		
	int timer=0;
	void logic()
		{
		stats.swLogic.start();
		assert(testGraph !is null);
		testGraph.onTick();
		testGraph2.onTick();
		
		ship p = cast(ship)units[1]; // player
		p.isPlayerControlled = true;
		ship p2 = cast(ship)units[0]; // player
		p2.isPlayerControlled = true;
		
		viewports[0].onTick();
		players[0].onTick();
//		viewports[0].ox = p.x - viewports[0].w/2;
	//	viewports[0].oy = p.y - viewports[0].h/2;
		
		timer++;
		if(timer > 200)
			{
			timer = 0;
			float cx = planets[0].x + uniform!"[]"(-500, 500);
			float cy = planets[0].y + uniform!"[]"(-500, 500);
			g.world.asteroids ~= new asteroid(cx, cy, 0, 0, uniform!"[]"(-10,10)/1000.0, uniform!"[]"(0,2));
			}//float _x, float _y, float _vx, float _vy, float _va, int _size

		if(key_w_down)players[0].currentShip.up();
		if(key_s_down)players[0].currentShip.down();
		if(key_a_down)players[0].currentShip.left();
		if(key_d_down)players[0].currentShip.right();
		if(key_space_down)players[0].currentShip.actionFire();
		if(key_q_down)players[0].findNextShip();
		
		if(key_i_down)p2.up();
		if(key_k_down)p2.down();
		if(key_j_down)p2.left();
		if(key_l_down)p2.right();
		if(key_m_down)p2.actionFire();

		tick(planets);
		tick(particles);
		tick(asteroids);
		tick(units);
		tick(bullets);
			
		prune(units);
		prune(planets);
		prune(particles);
		prune(bullets);
		prune(asteroids);
		
		stats.swLogic.stop();
		stats.msLogic = stats.swLogic.peek.total!"msecs";
		stats.swLogic.reset();
		}
	}

struct statistics_t
	{
	// per frame statistics
	ulong number_of_drawn_units=0;
	ulong number_of_drawn_particles=0;
	ulong number_of_drawn_structures=0;
	ulong number_of_drawn_asteroids=0;
	ulong number_of_drawn_bullets=0;
	ulong number_of_drawn_dudes=0;

	ulong number_of_drawn_units_clipped=0;
	ulong number_of_drawn_particles_clipped=0;
	ulong number_of_drawn_structures_clipped=0;
	ulong number_of_drawn_asteroids_clipped=0;
	ulong number_of_drawn_bullets_clipped=0;
	ulong number_of_drawn_dudes_clipped=0;
	
	ulong fps=0;
	ulong frames_passed=0;
	
	StopWatch swLogic;
	StopWatch swDraw;
	float msLogic;
	float nsDraw;
	
	void reset()
		{ // note we do NOT reset fps and frames_passed here as they are cumulative or handled elsewhere.
		number_of_drawn_units = 0;
		number_of_drawn_particles = 0;
		number_of_drawn_structures = 0;
		number_of_drawn_asteroids = 0;
		number_of_drawn_bullets = 0;
		number_of_drawn_dudes = 0;

		number_of_drawn_units_clipped = 0;
		number_of_drawn_particles_clipped = 0;
		number_of_drawn_structures_clipped = 0;
		number_of_drawn_asteroids_clipped = 0;
		number_of_drawn_bullets_clipped = 0;
		number_of_drawn_dudes_clipped = 0;
		}
	}

statistics_t stats;

int mouse_x = 0; //cached, obviously. for helper routines.
int mouse_y = 0;
int mouse_lmb = 0;
int mouse_in_window = 0;
bool key_w_down = false;
bool key_s_down = false;
bool key_a_down = false;
bool key_d_down = false;
bool key_q_down = false;
bool key_e_down = false;
bool key_f_down = false;
bool key_space_down = false;

bool key_i_down = false;
bool key_j_down = false;
bool key_k_down = false;
bool key_l_down = false;
bool key_m_down = false;

