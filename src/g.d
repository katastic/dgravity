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

void loadResources()	
	{
	font1 = getFont("./data/DejaVuSans.ttf", 18);

	bullet_bmp  			= getBitmap("./data/bullet.png");
	ship_bmp			  	= getBitmap("./data/ship.png");
	small_asteroid_bmp  	= getBitmap("./data/small_asteroid.png");
	medium_asteroid_bmp  	= getBitmap("./data/medium_asteroid.png");
	large_asteroid_bmp  	= getBitmap("./data/large_asteroid.png");
	smoke_bmp  	= getBitmap("./data/smoke.png");
	space_bmp  	= getBitmap("./data/seamless_space.png");
	bullet_bmp  	= getBitmap("./data/bullet.png");
	
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
alias dir=direction;

/// thought bubble handler
class bubble_handler
	{
	bubble[] bubbles;
	
	void spawn(string text, float _x, float _y, int lifetime)
		{
		bubble b;
		b.text = text;
		b.x = _x;
		b.y = _y;
		b.lifetime = lifetime;
		
		bubbles ~= b;
		}
	
	void drawBubble(bubble b, viewport v)
		{
		float cx = b.x - v.ox + v.x; // topleft x,y
		float cy = b.y - v.oy + v.y;
		float w = 100;
		float h = 64;
		float r = 5;
		
		al_draw_filled_rounded_rectangle(
			cx, cy,
			cx + w, cy + h,
			r, r, COLOR(1,1,1,0.7));
			
		al_draw_text(g.font1, COLOR(0,0,0,1.0), cx + r, cx + r, 0, b.text.toStringz);
		
		// todo: smooth fade out 
		// if(lifetime < 10) ...
		}
	
	void draw(viewport v)
		{
		foreach(ref b; bubbles)
			{
			drawBubble(b, v);
			}
		}
	
	void onTick()
		{
		foreach(ref b; bubbles)
			{
			b.lifetime--;
			if(b.lifetime >= 0)b.isDead = true;
			}
		for(size_t i = bubbles.length ; i-- > 0 ; )
			{
			if(bubbles[i].isDead)bubbles = bubbles.remove(i); continue;
			}
		}
	}

struct light
	{
	float x=684;
	float y=245;
	COLOR color;
	}
	
light[2] lights;

struct bubble
	{
	string text;
	float x=0, y=0;
	float vx=0, vy=0;
	int lifetime=0;
	bool isDead=false;
	}


class particle_handler
	{
	particle[] data;
	
	void draw(viewport v)
		{
		// what about accumulation buffer particle systems like static blood decal
		foreach(ref p; data)
			{
			al_draw_bitmap(g.stone_bmp, p.x + v.x - v.ox, p.y + v.y - v.oy, 0);
			}
		}
	
	void onTick()
		{
		foreach(ref p; data)
			{
			p.x += p.vx;
			p.y += p.vy;
			}
		}
	}
	
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
viewport [2] viewports;

enum direction { down, up, left, right, upleft, upright, downright, downleft} // do we support diagonals. 
// everyone supports at least down. [for signs]
// then UDLR
// then UDLR + diags

struct player_t
	{
	int money=1000; //we might have team based money accounts. doesn't matter yet.
	int deaths=0;
	}
	
class world_t
	{			
	baseObject[] objects; // other stuff
	unit[] units;
	structure_t[] structures;
	planet[] planets;
	asteroid[] asteroids;
	particle[] particles;
	bullet[] bullets;

	this()
		{
		units ~= new ship(680, 360, 0, 0);
		planets ~= new planet("first", 400, 300, 200);
		planets ~= new planet("second", 1210, 410, 100);
		planets ~= new planet("third", 1720, 520, 50);
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
		al_draw_bitmap(g.space_bmp, 0 + v.x - v.ox, 0 + v.y - v.oy, 0);
		for(int i = -2; i < 2; i++)
			for(int j = -2; j < 2; j++)
				{
				COLOR c = COLOR(1,1,1,.5); 
				al_draw_tinted_bitmap(g.space_bmp, c, 0 + v.x - v.ox + g.space_bmp.w*i, 0 + v.y - v.oy + g.space_bmp.h*j, 0);
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
		
		draw(planets);
		draw(asteroids);
		draw(bullets);
		draw(particles);
		drawStat(units, stats.number_of_drawn_dwarves);
		drawStat(structures, stats.number_of_drawn_structures);		

		testGraph.draw(v);
		testGraph2.draw(v);
		stats.swDraw.stop();
		stats.nsDraw = stats.swDraw.peek.total!"nsecs";
		stats.swDraw.reset();
		}
		
	void logic()
		{
		stats.swLogic.start();
		assert(testGraph !is null);
		testGraph.onTick();
		testGraph2.onTick();
		ship p = cast(ship)units[0]; // player
		viewports[0].ox = p.x - viewports[0].w/2;
		viewports[0].oy = p.y - viewports[0].h/2;

		p.isPlayerControlled = true;

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
			
		tick(structures);
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
		prune(structures);
		prune(planets);
		prune(particles);
		prune(bullets);
		prune(asteroids);
		stats.swLogic.stop();
		stats.msLogic = stats.swLogic.peek.total!"msecs";
		stats.swLogic.reset();
		}
		
	}

// CONSTANTS
//=============================================================================
player_t[2] players;
	
/// al_draw_line_segment for pairs
void al_draw_line_segment(pair[] pairs, COLOR color, float thickness)
	{
	assert(pairs.length > 1);
	pair lp = pairs[0]; // initial p, also previous p ("last p")
	foreach(ref p; pairs)
		{
		al_draw_line(p.x, p.y, lp.x, lp.y, color, thickness);
		lp = p;
		}
	}
	
/// al_draw_line_segment for raw integers floats POD arrays
void al_draw_line_segment(T)(T[] x, T[] y, COLOR color, float thickness)
	{
	assert(x.length > 1);
	assert(y.length > 1);
	assert(x.length == y.length);

	for(int i = 1; i < x.length; i++) // note i = 1
		{
		al_draw_line(x[i], y[i], x[i-1], y[i-1], color, thickness);
		}
	}

/// al_draw_line_segment 1D
void al_draw_line_segment(T)(T[] y, COLOR color, float thickness)
	{
	assert(y.length > 1);

	for(int i = 1; i < y.length; i++) // note i = 1
		{
		al_draw_line(i, y[i], i-1, y[i-1], color, thickness);
		}
	}

/// al_draw_line_segment 1D
void al_draw_scaled_line_segment(T)(pair xycoord, T[] y, float yScale, COLOR color, float thickness)
	{
	assert(y.length > 1);

	for(int i = 1; i < y.length; i++) // note i = 1
		{
		al_draw_line(
			xycoord.x + i, 
			xycoord.y + y[i]*yScale, 
			xycoord.x + i-1, 
			xycoord.y + y[i-1]*yScale, 
			color, thickness);
		}
	}

// what if we want timestamps? Have two identical buffers, one with X
// and one with (T)ime? (not to be confused with T below)
class circularBuffer(T, size_t size)
	{
	T[size] data; 
 	int index=0;
	bool isFull=false;
	int maxSize=size;
	
	/* note:
	if 'data' is a static array it causes all kinds of extra problems
	 because static arrays aren't ranges so magic things like maxElement
	 fail.
	 
	but it's its dynamic, now its on the heap. We're only allocating once
	but it's still kinda bullshit.
	
	but then we have to "manage" an expanding array even though its not
	going to expand so the appender has to deal with the case of growing
	until it hits max size. which is also bullshit.
	*/
    T maxElement()
		{
		import std.traits : mostNegative;
		T maxSoFar = to!T(mostNegative!T);
		for(int i = 0; i < size; i++)
			{
			if(data[i] > maxSoFar)maxSoFar = data[i]; 
			}
		return maxSoFar;
		}
		
    T minElement()
		{
		T minSoFar = to!T(T.max);
		for(int i = 0; i < size; i++)
			{
			if(data[i] < minSoFar)minSoFar = data[i]; 
			}
		return minSoFar;
		}

    T opApply(scope T delegate(ref T) dg)
		{ //https://dlang.org/spec/statement.html#foreach-statement
			//http://ddili.org/ders/d.en/foreach_opapply.html
        foreach (e; data)
			{
            T result = dg(e);
            if (result)
                return result;
			}
        return 0;
		}
		
	void addNext(T t)
		{
		index++;
		if(index == data.length)
			{
			index = 0; isFull = true;
			}
		data[index] = t;
		}
	}

intrinsicGraph!float testGraph;
intrinsicGraph!float testGraph2;

/// Graph that attempts to automatically poll a value every frame
/// is instrinsic the right name?
/// We also want a variant that gets manually fed values
/// This one also will (if maxTimeRemembered != 0) not reset the "zoom" or y-scaling
/// for a certain amount of time after the 
///
/// Not sure if time remembered should be in terms of individual frames, or, 
/// in terms of "buffers" full. Because a longer buffer, with same frames, will
/// last a shorter length and so what's right for one buffer, could be not enough
/// for a larger one.
///
/// Also warning: Make sure any timing considerations don't expect DRAWING to be
/// lined up 1-to-1 with LOGIC. Draw calls may be duplicated with no new data, or 
/// skipped during slowdowns.

/*
	how do we support multiple datasources of different types? Have we gone about this
	the wrong way? How about simply accepting all datasources and simply converting them
	to float? In addition to simplicity, we can also now accept multiple datasources.
		EXCEPT. while it's easy to support a manual "pushBackData(T)(T value)" function
		is there a way to mark datasources and still have it convert them? Doesn't that
		require some method of storing multiple different data types? I mean all datatypes
		in D inherit from [Object], right? Is that a starting point?

	also what about new features in inherited modified versions of graph?
		multigraph   - figuring this out templates wise.
		coloredgraph - color a line differently above or below a datum ("redlining")
		?			 - filled solid drawing
		?			 - multicolored solid filled graph (showing how much percentage each is)
		?			 - peak detection?
*/
class intrinsicGraph(T)
	{
	string name;
	bool isScaling=true;  // NYI, probably want no for FPS
	bool isTransparent=false; // NYI, no background. For overlaying multiple graphs (but how do we handle multiple drawing multiple min/max scales in UI?)
	bool doFlipVertical=false; // NYI, flip vertical axis. Do we want ZERO to be bottom or top. Could be as easy as sending a negative scaling value.
	float x=0,y=300;
	int w=400, h=100;
	COLOR color;
	BITMAP* buffer;
	T* dataSource; // where we auto grab the data every frame
	circularBuffer!(T, 400) dataBuffer; //how do we invoke the constructor?
	float scaling = 1.0; /// scale VALUES by this for peeking numbers with higher granulaity (nsecs to view milliseconds = 1_000_000)

	// private data
 	private T max=-9999; //READONLY cache of max value.
 	private T min=-9999; //READONLY cache of max value.
 	private float scaleFactor=1.00; //READONLY set by draw() every frame.
 	private int maxTimeRemembered=600; // how many frames do we remember a previous maximum. 0 for always update.
 	private T previousMaximum=0;
 	private T previousMinimum=0;
	private int howLongAgoWasMaxSet=0;
 	
	this(string _name, ref T _dataSource, float _x, float _y, COLOR _color, float _scaling=1)
		{
		scaling = _scaling;
		name = _name;
		dataBuffer = new circularBuffer!(T, 400);
		dataSource = &_dataSource;
		color = _color;
		x = _x;
		y = _y;
		}

	void draw(viewport v)
		{
		// TODO. Are we keeping/using viewport? 
		// We'd have to know which grapsh are used in which viewport
		al_draw_filled_rectangle(x + v.x, y + v.y, x + w + v.x, y + h + v.y, COLOR(1,1,1,.75));

		// this looks confusing but i'm not entirely sure how to clean it up
		// We need a 'max', that is cached between onTicks. But we also have a tempMax
		// where we choose which 'max' we use
		
		T tempMax = max;
		T tempMin = min;
		howLongAgoWasMaxSet++;
//		if(howLongAgoWasMaxSet <= maxTimeRemembered) DISABLED
		if(tempMax < previousMaximum)
			{
			tempMax = previousMaximum;
			}else{
			previousMaximum = tempMax;
			howLongAgoWasMaxSet = 0;
			}
		if(tempMin > previousMinimum)
			{
			tempMin = previousMinimum;
			}else{
			previousMinimum = tempMin;
			}
		import std.math : abs;
		if(tempMax == tempMin)tempMax++;
		scaleFactor = h/(tempMax + abs(tempMin)); //fixme for negatives. i think the width is right but it's still "offset" above the datum then.
		al_draw_scaled_line_segment(pair(this), dataBuffer.data, scaleFactor, color, 1.0f);

		al_draw_text(g.font1, COLOR(0,0,0,1), x, y, 0, name.toStringz);
		al_draw_text(g.font1, COLOR(0,0,0,1), x + w - 32, y, 0, format("%s",min/scaling).toStringz);
		al_draw_text(g.font1, COLOR(0,0,0,1), x + w - 32, y+h-g.font1.h, 0, format("%s",max/scaling).toStringz);
		al_draw_text(g.font1, COLOR(0,0,0,1), x     + 32, y+h-g.font1.h, 0, format("%s",dataBuffer.data[dataBuffer.index]/scaling).toStringz);
		}
		
	void onTick()
		{
		max = dataBuffer.maxElement; // note: we only really need to scan if [howLongAgoWasMaxSet] indicates a time we'd scan
		min = dataBuffer.minElement; // note: we only really need to scan if [howLongAgoWasMaxSet] indicates a time we'd scan
		dataBuffer.addNext(*dataSource);
		}
	}
	
struct statistics_t
	{
	// per frame statistics
	ulong number_of_drawn_particles=0;
	ulong number_of_drawn_objects=0;
	ulong number_of_drawn_structures=0;
	ulong number_of_drawn_dwarves=0;
	ulong number_of_drawn_background_tiles=0;
	
	ulong fps=0;
	ulong frames_passed=0;
	
	StopWatch swLogic;
	StopWatch swDraw;
	float msLogic;
	float nsDraw;
	
	void reset()
		{ // note we do NOT reset fps and frames_passed here as they are cumulative or handled elsewhere.
		number_of_drawn_particles = 0;
		number_of_drawn_objects = 0;
		number_of_drawn_structures = 0;
		number_of_drawn_dwarves = 0;
		number_of_drawn_background_tiles = 0;
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

