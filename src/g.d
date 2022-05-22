import allegro5.allegro;
import allegro5.allegro_primitives;
import allegro5.allegro_image;
import allegro5.allegro_font;
import allegro5.allegro_ttf;
import allegro5.allegro_color;

import std.stdio;
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

immutable PLANET_MASS = 4000;
immutable PLANET_MASS_FOR_BULLETS = 20000;

ALLEGRO_FONT* 	font1;

ALLEGRO_BITMAP* ship_bmp;
ALLEGRO_BITMAP* smoke_bmp;
ALLEGRO_BITMAP* small_asteroid_bmp;
ALLEGRO_BITMAP* medium_asteroid_bmp;
ALLEGRO_BITMAP* large_asteroid_bmp;
ALLEGRO_BITMAP* space_bmp;
ALLEGRO_BITMAP* bullet_bmp;
ALLEGRO_BITMAP* dude_bmp;

ALLEGRO_BITMAP* dude_up_bmp;
ALLEGRO_BITMAP* dude_down_bmp;
ALLEGRO_BITMAP* dude_left_bmp;
ALLEGRO_BITMAP* dude_right_bmp;
ALLEGRO_BITMAP* chest_bmp;
ALLEGRO_BITMAP* chest_open_bmp;
ALLEGRO_BITMAP* dwarf_bmp;
ALLEGRO_BITMAP* goblin_bmp;
ALLEGRO_BITMAP* boss_bmp;
ALLEGRO_BITMAP* fountain_bmp;
ALLEGRO_BITMAP* tree_bmp;
ALLEGRO_BITMAP* wall_bmp;
ALLEGRO_BITMAP* grass_bmp;
ALLEGRO_BITMAP* lava_bmp;
ALLEGRO_BITMAP* water_bmp;
ALLEGRO_BITMAP* wood_bmp;
ALLEGRO_BITMAP* stone_bmp;
ALLEGRO_BITMAP* reinforced_wall_bmp;
ALLEGRO_BITMAP* sword_bmp;
ALLEGRO_BITMAP* carrot_bmp;
ALLEGRO_BITMAP* potion_bmp;
ALLEGRO_BITMAP* blood_bmp;

int SCREEN_W = 1360;
int SCREEN_H = 720;

intrinsicGraph!float testGraph;
intrinsicGraph!float testGraph2;

void loadResources()	
	{
	font1 = getFont("./data/DejaVuSans.ttf", 18);

	bullet_bmp  			= getBitmap("./data/bullet.png");
	ship_bmp			  	= getBitmap("./data/ship.png");
	small_asteroid_bmp  	= getBitmap("./data/small_asteroid.png");
	medium_asteroid_bmp  	= getBitmap("./data/medium_asteroid.png");
	large_asteroid_bmp  	= getBitmap("./data/large_asteroid.png");
	smoke_bmp  				= getBitmap("./data/smoke.png");
	space_bmp  				= getBitmap("./data/seamless_space.png");
	bullet_bmp  			= getBitmap("./data/bullet.png");
	dude_bmp	  			= getBitmap("./data/dude.png");
	
	dude_up_bmp  		= getBitmap("./data/dude_up.png");
	dude_down_bmp	  	= getBitmap("./data/dude_down.png");
	dude_left_bmp  		= getBitmap("./data/dude_left.png");
	dude_right_bmp  	= getBitmap("./data/dude_right.png");
	
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
	team myTeam;
	ship currentShip; //current. Also how do we handle with units die / switch active ship (if that's an option)
//	int money=1000; //we might have team based money accounts. doesn't matter yet.
	int kills=0;
	int aikills=0;
	int deaths=0;
	
	this(ship who)
		{
		currentShip = who;
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
		auto s = new ship(680, 360, 0, 0);	
		units ~= s; //which comes first, player or the egg
		players ~= new player(s);
		teams ~= new team(players[0], blue);
		players[0].myTeam = teams[0];
		
		s.isOwned = true;
		s.currentOwner = players[0];
		
		// note structures currently pre-req a player instantiated
		planets ~= new planet("first", 400, 300, 200);
	//	planets ~= new planet("second", 1210, 410, 100);
	//	planets[1].m = PLANET_MASS*.25; // we get CLOSER to SMALLER planets making gravity much larger if its the same mass!
	//	planets ~= new planet("third", 1720, 520, 50);
	//	planets[2].m = PLANET_MASS*.05;
		asteroids ~= new asteroid(400+150, 550, 0.1, 0, .02, 2);
		asteroids ~= new asteroid(400-150, 550, 0.1, 0, .02, 1);
		asteroids ~= new asteroid(400-150 + uniform!"[]"(-300,300), 550 + uniform!"[]"(-300,300), 0.1, 0, .02, 0);
		asteroids ~= new asteroid(400-150 + uniform!"[]"(-300,300), 550 + uniform!"[]"(-300,300), 0.1, 0, .02, 0);
		asteroids ~= new asteroid(400-150 + uniform!"[]"(-300,300), 550 + uniform!"[]"(-300,300), 0.1, 0, .02, 0);
		asteroids ~= new asteroid(400-150 + uniform!"[]"(-300,300), 550 + uniform!"[]"(-300,300), 0.1, 0, .02, 0);
		testGraph = new intrinsicGraph!float("Draw (ms)", g.stats.nsDraw, 100, 200 - 50, COLOR(1,0,0,1), 1_000_000);
		testGraph2 = new intrinsicGraph!float("Logic (ms)", g.stats.msLogic, 100, 320 - 50, COLOR(1,0,0,1), 1_000_000);
	
		stats.swLogic = StopWatch(AutoStart.no);
		stats.swDraw = StopWatch(AutoStart.no);
		}
		
	void drawSpace(viewport v)
		{
		for(int i = -2; i < 2; i++)
			for(int j = -2; j < 2; j++)
				{
				COLOR c = COLOR(1,1,1,1); 
				al_draw_tinted_bitmap(g.space_bmp, c, 0 + v.x - v.ox/1.25 + g.space_bmp.w*i, 0 + v.y - v.oy/1.25 + g.space_bmp.h*j, 0);
				}
		for(int i = -2; i < 2; i++)
			for(int j = -2; j < 2; j++)
				{
				COLOR c = COLOR(1,1,1,.5); 
				al_draw_tinted_bitmap(g.space_bmp, c, 0 + v.x - v.ox/2 + g.space_bmp.w*i, 0 + v.y - v.oy/2 + g.space_bmp.h*j, 1);
				}
		for(int i = -4; i < 4; i++)
			for(int j = -4; j < 4; j++)
				{
				COLOR c = COLOR(1,1,1,.25); 
				al_draw_tinted_bitmap(g.space_bmp, c, 0 + v.x - v.ox/4 + g.space_bmp.w*i, 0 + v.y - v.oy/4 + g.space_bmp.h*j, 3);
				}
		}
		
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
		
		drawStat(planets, 	stats.number_of_drawn_units);
		drawStat(asteroids, stats.number_of_drawn_units);
		drawStat(bullets, 	stats.number_of_drawn_particles);
		drawStat(particles, stats.number_of_drawn_particles);
		drawStat(units, 	stats.number_of_drawn_units);
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
		
		ship p = cast(ship)units[0]; // player
		p.isPlayerControlled = true;
		viewports[0].ox = p.x - viewports[0].w/2;
		viewports[0].oy = p.y - viewports[0].h/2;
		timer++;
		if(timer > 200)
			{
			timer = 0;
			float cx = planets[0].x + uniform!"[]"(-500, 500);
			float cy = planets[0].y + uniform!"[]"(-500, 500);
			g.world.asteroids ~= new asteroid(cx, cy, 0, 0, uniform!"[]"(-10,10)/1000.0, uniform!"[]"(0,2));
			}//float _x, float _y, float _vx, float _vy, float _va, int _size
		if(key_w_down)p.up();
		if(key_s_down)p.down();
		if(key_a_down)p.left();
		if(key_d_down)p.right();
		if(key_space_down)p.attack();
		
		void tick(T)(ref T obj)
			{
			foreach(ref o; obj)
				{
				o.onTick();
				}
			}
			
//		tick(structures);
		tick(planets);
		tick(particles);
		tick(asteroids);
		tick(units);
		tick(bullets);

		//prune ready-to-delete entries
		void prune(T)(ref T obj)
			{
			for (size_t i = obj.length ; i-- > 0 ; )
				{
				if(obj[i].isDead)obj = obj.remove(i); continue;
				}
			//see https://forum.dlang.org/post/sagacsjdtwzankyvclxn@forum.dlang.org
			}
			
		prune(units);
//		prune(structures);
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
	ulong number_of_drawn_background_tiles=0;
	
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
		number_of_drawn_background_tiles = 0;
		number_of_drawn_structures=0;
		number_of_drawn_units=0;
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

