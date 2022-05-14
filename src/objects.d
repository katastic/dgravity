import allegro5.allegro;
import allegro5.allegro_primitives;
import allegro5.allegro_image;
import allegro5.allegro_font;
import allegro5.allegro_ttf;
import allegro5.allegro_color;

import std.conv;
import std.random;
import std.stdio;
import std.math;
import std.string;

import g;
import helper;
import viewportsmod;
/*
	Teams
		0 - Neutral		(asteroids. unclaimed planets?)
		1 - Player 1? (if we support real teams, then its whatever team it is)

name clashes
	- we cannot use "object" since that's a D keyword. 
	- we also can't use "with" for onCollision(baseObject with)
*/

/// baseObject and handler for asteroids, 1st-order physics baseObjects that float and split on collision/firing
/// 
class asteroid : unit
	{
	float va=0; // velocity of rotation (angular velocity)
	this(float _x, float _y, float _vx, float _vy, float _va)
		{
		va = _va;
		angle = uniform!"[]"(0, 2*PI);
		super(0, _x, _y, _vx, _vy, g.large_asteroid_bmp);
		}
	
	override void onTick()
		{
		angle += va;
		wrapRadRef(angle);
		super.onTick(); //apply unit physics
		}
		
	override void onCollision(baseObject who)
		{
		}
	}
	
struct bullet
	{
	float x=0, y=0;
	float vx=0, vy=0;
	int type; // 0 = normal bullet whatever
	int lifetime; // frames passed since firing
	bool isDead=false; // to trim
	}
	
class bulletHandler
	{
	bullet[] bullets;
	
	void add(float _x, float _y, float _vx, float _vy)
		{
		bullet b;
		b.x = _x;
		b.y = _y;
		b.vx = _vx;
		b.vy = _vy;
		bullets ~= b;
		}
	
	void draw(viewport v)
		{
		foreach(ref b; bullets)
			{
			// draw
			al_draw_bitmap(g.stone_bmp, b.x + v.x - v.ox, b.y + v.y - v.oy, 0);
			}
		}
		
	void onTick()
		{
		foreach(ref b; bullets)
			{
			b.x += b.vx;
			b.y += b.vy;
			b.lifetime--;
			if(b.lifetime <= 0)b.isDead = true;
			}
		}
	}

class item : baseObject
	{
	bool isInside = false; //or isHidden? Not always the same though...
	int team;
	
	this(uint _team, float _x, float _y, float _vx, float _vy, ALLEGRO_BITMAP* b)
		{	
		writeln("ITEM EXISTS BTW at ", x, " ", y);
		super(_x, _y, _vx, _vy, b);
		}
		
	override void draw(viewport v)
		{
		if(!isInside)
			{
			super.draw(v);
			}
		}
		
	override void onTick()
		{
		if(!isInside)
			{
			x += vx;
			y += vy;
			vx *= .99; 
			vy *= .99; 
			}
		}
	}

class unit : baseObject // WARNING: This applies PHYSICS. If you inherit from it, make sure to override if you don't want those physics.
	{
	immutable float maxHP=100.0; /// Maximum health points
	float hp=maxHP; /// Current health points
	float ap=0; /// armor points (reduced on hits then armor breaks)
	float armor=0; /// flat reduction (or percentage) on damages, haven't decided.
	uint team=0;
	bool isPlayerControlled=false;
	float weapon_damage = 5;

	void applyGravity()
		{		
		// gravity acceleration formula: g = -G*M/r^2
		float G = 1; // gravitational constant
		float M = 1000; // mass of planet
		auto p = pair(400,400); // planet position
		float r = distanceTo(this, p);
		float angle = angleTo(this, p);
		float g = -G*M/r^^2;
		applyV(angle, g);
		}

	void applyV(float applyAngle, float vel)
		{
		vx += cos(applyAngle)*vel;
		vy += sin(applyAngle)*vel;
		}

	override void onTick()
		{
		applyGravity();
		auto p = pair(400,400);
		if(distanceTo(this, p) < 100)
			{
			vx *= -.80;
			vy *= -.80;
			}
		x += vx;
		y += vy;
		}
		
		
	void onCollision()
		{
		}
		
	void onHit()
		{
		}


	void doAttackStructure(structure_t s)
		{
		s.onHit(this, weapon_damage);
		}

	void doAttack(unit u)
		{
		u.onAttack(this, weapon_damage);
		}
		
	void onAttack(unit from, float amount) /// I've been attacked!
		{
		hp -= amount;
		}
	
	this(uint _team, float _x, float _y, float _vx, float _vy, ALLEGRO_BITMAP* b)
		{
		team = _team; 
		super(_x, _y, _vx, _vy, b);
		}

	override void draw(viewport v)
		{
		super.draw(v);
		
		float mag = distance(vx, vy)*10.0;
		float angle2 = atan2(vy, vx);
		drawAngleHelper(this, v, angle2, mag, COLOR(1,0,0,1)); 
		
		drawAngleHelper(this, v, angle, 25, COLOR(0,1,0,1)); 
		drawPlanetHelper(this, g.world.planets[0], v);
		drawPlanetHelper(this, g.world.planets[1], v);

		draw_hp_bar(
			x, 
			y - bmp.w/2, 
			v, hp, 100);		
		}
	}

class ship_t : unit
	{
	this(float _x, float _y, float _xv, float _yv, ALLEGRO_BITMAP* b)
		{
		super(1, _x, _y, _xv, _yv, b);
		}

	override void draw(viewport v)
		{
		super.draw(v);
		}

	override void up(){ applyV(angle, .1);}
	override void down() { applyV(angle, -.1); }
	override void left() { angle -= degToRad(10.0);}
	override void right() { angle += degToRad(10.0);}
	override void attack()
		{
		}
	}
	
class planet : baseObject
	{
	float r = 100; /// radius
	string name="";
	@disable this();
	structure_t[] structures;
	
	this(string _name, float _x, float _y, float _r)
		{
		name = _name;
		r = _r;
		super(_x, _y, 0, 0, g.tree_bmp); // works perfect
		
		structures ~= new structure_t(0, 0, g.fountain_bmp, this);
		}
	
	override void draw(viewport v)
		{
		al_draw_filled_circle(x + v.x - v.ox, y + v.y - v.oy, r, COLOR(.8,.8,.8,1));
		al_draw_filled_circle(x + v.x - v.ox, y + v.y - v.oy, r * .80, COLOR(1,1,1,1));
		foreach(s; structures) s.draw(v);
		}
		
	override void onTick()
		{
		// do structures  get handled by us or by root logic() call?
		foreach(s; structures) s.onTick();
		}
	}

class structure_t : baseObject
	{
	immutable float maxHP=500.0;
	float hp=maxHP;
	int level=1; //ala upgrade level
	int team=0;
	int direction=0;
	immutable int countdown_rate = 200; // 60 fps, 60 ticks = 1 second
	int countdown = countdown_rate; // I don't like putting variables in the middle of classes but I ALSO don't like throwing 1-function-only variables at the top like the entire class uses them.
	planet myPlanet;
	
	this(float x, float y, ALLEGRO_BITMAP* b, planet _myPlanet)
		{
		super(x, y, 0, 0,b);
		writeln("we MADE a structure. @ ", x, " ", y);
		g.players[0].money -= 250;
		myPlanet = _myPlanet;
		}

	override void draw(viewport v)
		{
		// we draw RELATIVE to planet.xy, so no using baseObject.draw
		// TODO how do we rotate angle from center of planet properly?
		float cx=myPlanet.x + v.x - v.ox;
		float cy=myPlanet.y + v.y - v.oy;
		al_draw_center_rotated_bitmap(bmp, cx, cy, 0, 0);
		draw_hp_bar(x, y, v, hp, maxHP);
		}

	void onHit(unit u, float damage)
		{
		hp -= damage;
		}
	}

class baseObject
	{
	ALLEGRO_BITMAP* bmp;
	@disable this(); 
	bool isDead = false;	
	float x=0, y=0; 	/// baseObjects are centered at X/Y (not top-left) so we can easily follow other baseObjects.
	float vx=0, vy=0; /// Velocities.
	float w=0, h=0;   /// width, height 
	float angle=0;	/// pointing angle 

	this(float _x, float _y, float _vx, float _vy, ALLEGRO_BITMAP* _bmp)
		{
		x = _x;
		y = _y;
		vx = _vx;
		vy = _vy;
		bmp = _bmp;
		}
		
	void draw(viewport v)
		{
		al_draw_center_rotated_bitmap(bmp, 
			x - v.ox + v.x, 
			y - v.oy + v.y, 
			angle, 0);
		}
	
	// INPUTS (do we support mouse input?)
	// ------------------------------------------
	void up(){ y-= 10;}
	void down(){y+= 10;}
	void left(){x-= 10;}
	void right(){x+= 10;}
	void attack()
		{
		}
	
	void onTick()
		{
		// THOU. SHALT. NOT. PUT. PHYSICS. IN BASE. baseObject.
		}
	}	
