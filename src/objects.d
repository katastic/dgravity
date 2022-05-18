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

struct particle
	{
	float x=0, y=0;
	float vx=0, vy=0;
	int type=0;
	int lifetime=0;
	int maxLifetime=0;
	int rotation=0;
	bool isDead=false;

	//particle(x, y, vx, vy, 0, 5);
	/// spawn smoke without additional unit u
	this(float _x, float _y, float _vx, float _vy, int _type, int  _lifetime)
		{
		import std.math : cos, sin;
		x = _x;
		y = _y;
		vx = _vx + uniform!"[]"(-.1, .1);
		vy = _vy + uniform!"[]"(-.1, .1);
		type = _type;
		lifetime = _lifetime;
		maxLifetime = _lifetime;
		rotation = uniform!"[]"(0, 3);
		}
	
	/// spawn smoke with acceleration from unit u
	this(float _x, float _y, float _vx, float _vy, int _type, int  _lifetime, unit u)
		{
		import std.math : cos, sin;
		float thrustAngle = u.angle;
		float thrustDistance = -30;
		float thrustVelocity = -3;
		
		x = _x + cos(thrustAngle)*thrustDistance;
		y = _y + sin(thrustAngle)*thrustDistance;
		vx = _vx + uniform!"[]"(-.1, .1) + cos(thrustAngle)*thrustVelocity;
		vy = _vy + uniform!"[]"(-.1, .1) + sin(thrustAngle)*thrustVelocity;
		type = _type;
		lifetime = _lifetime;
		maxLifetime = _lifetime;
		rotation = uniform!"[]"(0, 3);
		}
		
	void draw(viewport v)
		{
		BITMAP *b = g.smoke_bmp;
		ALLEGRO_COLOR c = ALLEGRO_COLOR(1,1,1,cast(float)lifetime/cast(float)maxLifetime);
		float cx = x + v.x - v.ox - b.w/2;
		float cy = y + v.y - v.oy - b.h/2;
		float scaleX = (cast(float)lifetime/cast(float)maxLifetime) * b.w;
		float scaleY = (cast(float)lifetime/cast(float)maxLifetime) * b.h;
		al_draw_tinted_scaled_bitmap(b, c,
			0, 0, b.w, b.h,
			cx, cy, scaleX, scaleY, rotation);
		}
	
	// NOTE. duplicate of ship.checkPlanetCollision
	bool checkPlanetCollision(planet p)
		{
		if(distanceTo(this, p) < p.r)
			{
			return true;
			}else{
			return false;
			}
		}
	
	void onTick() // should we check for planets collision?
		{
		lifetime--;
		if(lifetime == 0)
			{
			isDead=true;
			}else{
				
			foreach(p; g.world.planets) // NOTE. similar to ship.checkPlanetCollision
				{
				if(checkPlanetCollision(p))
					{
					vx = 0;
					vy = 0;
					}
				}
			
			x += vx;
			y += vy;
			}
		}	
	}

class asteroid : unit
	{
	int size=2; // 2 = large, 1 = medium, 0 = small
	float va=0; // velocity of rotation (angular velocity)
	int r=0; // radius, quick collision checking value. 
	
	this(float _x, float _y, float _vx, float _vy, float _va, int _size)
		{
		va = _va;
		angle = uniform!"[]"(0, 2*PI);
		size = _size;
		BITMAP* b;
		if(size == 0){b = g.small_asteroid_bmp; r = b.w/2;}
		if(size == 1){b = g.medium_asteroid_bmp; r = b.w/2;} 
		if(size == 2){b = g.large_asteroid_bmp; r = b.w/2;}
		assert(b !is null);
		super(0, _x, _y, _vx, _vy, b);
		}
		
	/// WARN: we do SIZE REDUCTION HERE. Careful not to somehow use this
	/// to clone an asteroid.
	/// TODO: make sure they don't collide and they split off in random 
	/// direction from each other.
	this(asteroid a)
		{
		// We would call a function called shrink() to make this obvious
		// but other functions cannot call super().
		va = a.va;
		angle = a.angle;
		size = a.size - 1;
		BITMAP* b;
		assert(size >= 0);
		if(size == 0){b = g.small_asteroid_bmp; r = b.w/2;}
		if(size == 1){b = g.medium_asteroid_bmp; r = b.w/2;} 
		if(size == 2){b = g.large_asteroid_bmp; r = b.w/2;}
		assert(b !is null);
		super(0, a.x, a.y, a.vx, a.vy, b);
		}		
	
	override void onTick()
		{
		angle += va;
		wrapRadRef(angle);
		super.onTick(); //apply unit physics
		}
		
	/// become smaller and create 3 new identical smaller size asteroids
	void split()
		{
		g.world.particles ~= particle(x, y, vx, vy, 0, uniform!"[]"(30, 60));
		if(size <= 0)
			{
			import std.random : uniform;
			g.world.particles ~= particle(x, y, vx, vy, 0, uniform!"[]"(30, 60));
			isDead = true;
			return;
			}
		g.world.asteroids ~= new asteroid(this);
		g.world.asteroids ~= new asteroid(this);
		g.world.asteroids ~= new asteroid(this);
		size--;
		if(size == 0){bmp = g.small_asteroid_bmp; r = bmp.w/2;}
		if(size == 1){bmp = g.medium_asteroid_bmp; r = bmp.w/2;} 
		if(size == 2){bmp = g.large_asteroid_bmp; r = bmp.w/2;}
		}
		
	override void onCollision(baseObject who)
		{
		split();
		}
		
	override void onHit(baseObject who)
		{
		split();
		}
	}
	
class bullet : baseObject
	{
	float x=0, y=0;
	float vx=0, vy=0;
	float angle=0;
	int type; // 0 = normal bullet whatever
	int lifetime; // frames passed since firing
	bool isDead=false; // to trim
	
	this(float _x, float _y, float _vx, float _vy, float _angle, int _type, int _lifetime)
		{
		x = _x;
		y = _y;
		vx = _vx;
		vy = _vy;
		type = _type;
		lifetime = _lifetime;
		angle = _angle;
		super(_x, _y, _vx, _vy, g.bullet_bmp);
		}
	
	void applyGravity(planet p) //MODIFIED FROM ORIGINAL
		{		
		// gravity acceleration formula: g = -G*M/r^2
		float G = 1; // gravitational constant
		float M = PLANET_MASS_FOR_BULLETS; // mass of planet
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
	
	bool checkAsteroidCollision(asteroid a) // TODO fix. currently radial collision setup
		{
		if(distanceTo(this, a) < a.r)
			{
			return true;
			}else{
			return false;
			}		
		}
	
	// NOTE. duplicate of ship.checkPlanetCollision
	bool checkPlanetCollision(planet p)
		{
		if(distanceTo(this, p) < p.r)
			{
			return true;
			}else{
			return false;
			}
		}
	
	override void onTick() // should we check for planets collision?
		{
		lifetime--;
		if(lifetime == 0)
			{
			isDead=true;
			}else{
			applyGravity(g.world.planets[0]);
			foreach(p; g.world.planets) // NOTE. similar to ship.checkPlanetCollision
				{
				if(checkPlanetCollision(p))
					{
					isDead=true;
					vx = 0;
					vy = 0;
					import std.random : uniform;
					g.world.particles ~= particle(x, y, vx, vy, 0, uniform!"[]"(3, 6));
					}
				}
			
			foreach(a; g.world.asteroids)
				{
				if(checkAsteroidCollision(a))
					{
					isDead=true;
					a.onHit(this);
					}
				}
						
			x += vx;
			y += vy;
			}
		}
	
	override void draw(viewport v)
		{		
		float dx = x + v.x - v.ox;
		float dy = y + v.y - v.oy;
//		al_draw_bitmap(bmp, dx, dy, 0);
		al_draw_center_rotated_bitmap(bmp, dx, dy, angle + degToRad(90), 0);
		}
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

	void applyGravity(planet p)
		{		
		// gravity acceleration formula: g = -G*M/r^2
		float G = 1; // gravitational constant
		float M = PLANET_MASS; // mass of planet
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

	bool checkPlanetCollision(planet p)
		{
		if(distanceTo(this, p) < p.r)
			{
			return true;
			}else{
			return false;
			}
		}

	override void onTick()
		{
		applyGravity(g.world.planets[0]);
		foreach(p; g.world.planets)
			{
			if(checkPlanetCollision(p))
				{
				x += -vx; // NOTE we apply reverse full velocity once 
				y += -vy; // to 'undo' the last tick and unstick us, then set the new heading
				vx *= -.80;
				vy *= -.80;
				}
			}
		x += vx;
		y += vy;
		}
		
	void onCollision(baseObject who)
		{
		}
		
	void onHit(baseObject who)
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
		
		// Velocity Helper
		float mag = distance(vx, vy)*10.0;
		float angle2 = atan2(vy, vx);
		drawAngleHelper(this, v, angle2, mag, COLOR(1,0,0,1)); 
		
		// Planet Helper(s)
		drawAngleHelper(this, v, angle, 25, COLOR(0,1,0,1)); 
		drawPlanetHelper(this, g.world.planets[0], v);
		drawPlanetHelper(this, g.world.planets[1], v);

		// draw angle text
		al_draw_text(g.font1, white, x + v.x - v.ox + 30, y + v.y - v.oy - 30, 0, format("%3.2f", radToDeg(angle)).toStringz); 
	
		draw_hp_bar(x, y - bmp.w/2, v, hp, 100);		
		}
	}

class ship : unit
	{
	bool isLanded=false;
	immutable float MAX_LATCHING_SPEED = 3;
	immutable float MAX_SAFE_LANDING_ANGLE = 45;
	immutable float ROTATION_SPEED = 5;
	immutable float BULLET_SPEED = 10;
	
	this(float _x, float _y, float _xv, float _yv)
		{
		super(1, _x, _y, _xv, _yv, ship_bmp);
		}

	override void draw(viewport v)
		{
		super.draw(v);
		}
		
	void crash()
		{
		x += -vx; // NOTE we apply reverse full velocity once 
		y += -vy; // to 'undo' the last tick and unstick us, then set the new heading
		vx *= -.80;
		vy *= -.80;
		}

	override void onTick()
		{
		if(!isLanded)
			{
			applyGravity(g.world.planets[0]);
			foreach(p; g.world.planets)
				{
				if(checkPlanetCollision(p))
					{
					if(distance(vx, vy) > MAX_LATCHING_SPEED)
						{ 
						crash();
						}else{
						float a = angle;
						float b = angleTo(this, p).wrapRad;
						float result = angleDiff(a, b);
						writefln("A%3.2f B%3.2f result was: %3.2f < %3.2f?", radToDeg(a), radToDeg(b), radToDeg(result), MAX_SAFE_LANDING_ANGLE);
						if(result < degToRad(MAX_SAFE_LANDING_ANGLE))
							{					
							writeln(" SUCCESS");
							angle = angleTo(this, p);
							isLanded = true;
							vx = 0;
							vy = 0;
							}else{
							writeln(" FAIL");
							crash();
							}
						}
					}
				}
			x += vx;
			y += vy;
			}
		}

	void spawnSmoke()
		{
		g.world.particles ~= particle(x, y, vx*.99, vy*.99, 0, 100, this);
		}

	override void up()
		{ 
		if(isLanded)
			{				
			isLanded = false;
			x += cos(angle)*5f; 
			y += sin(angle)*5f; 
			applyV(angle, .1);
			applyV(angle, .1);
			applyV(angle, .1);
			}
		applyV(angle, .1);
		spawnSmoke();
		}
		
	override void down() 
		{ 	
		if(!isLanded)applyV(angle, -.1); 
		}
		
	override void left() { if(!isLanded){angle -= degToRad(ROTATION_SPEED); angle = wrapRad(angle);}}
	override void right() { if(!isLanded){angle += degToRad(ROTATION_SPEED); angle = wrapRad(angle);}}
	override void attack()
		{
		float _vx = vx + cos(angle)*BULLET_SPEED;
		float _vy = vy + sin(angle)*BULLET_SPEED;
		g.world.bullets ~= new bullet(x, y, _vx, _vy, angle, 0, 100);
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
		import std.format : format;
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
