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
import std.algorithm : remove;

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
	int size=200; // 2 = large, 1 = medium, 0 = small
	float va=0; // velocity of rotation (angular velocity)
	int r=0; // radius, quick collision checking value. 
	
	this(float _x, float _y, float _vx, float _vy, float _va, int _size)
		{
//		writeln("asteroid.this, size: ", _size);
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
		
	this(asteroid a)
		{
//		writeln("asteroid.this(a), size: ", a.size);
		va = a.va;
		angle = a.angle;
		size = a.size;
		BITMAP* b;
		assert(size >= 0);
		if(size == 0){b = g.small_asteroid_bmp; r = b.w/2;}
		if(size == 1){b = g.medium_asteroid_bmp; r = b.w/2;} 
		if(size == 2){b = g.large_asteroid_bmp; r = b.w/2;}
		assert(b !is null);
		super(0, a.x + uniform!"[]"(-250, 250), a.y + uniform!"[]"(-250, 250), a.vx, a.vy, b);
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
//		writeln("asteroid.split, size: ", size);
		g.world.particles ~= particle(x, y, vx, vy, 0, uniform!"[]"(30, 60));
		size--;
		if(size < 0)
			{
			import std.random : uniform;
			g.world.particles ~= particle(x, y, vx, vy, 0, uniform!"[]"(30, 60));
			isDead = true;
			return;
			}else{				
			// clone ourselves then reduce size
			g.world.asteroids ~= new asteroid(this); 
			g.world.asteroids ~= new asteroid(this);
			g.world.asteroids ~= new asteroid(this);
			if(size == 0){bmp = g.small_asteroid_bmp; r = bmp.w/2;}
			if(size == 1){bmp = g.medium_asteroid_bmp; r = bmp.w/2;} 
			if(size == 2){bmp = g.large_asteroid_bmp; r = bmp.w/2;}
			}
		}
		
	override void onCollision(baseObject who)
		{
		split();
		}
		
	override void onHit(bullet b)
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
	unit myOwner;
	
	this(float _x, float _y, float _vx, float _vy, float _angle, int _type, int _lifetime, unit _myOwner)
		{
		myOwner = _myOwner;
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
		float angle2 = angleTo(this, p);
		float g = -G*M/r^^2;
		applyV(angle2, g);
		}

	void applyV(float applyAngle, float vel)
		{
		vx += cos(applyAngle)*vel;
		vy += sin(applyAngle)*vel;
		}

	bool checkUnitCollision(unit u)
		{
		writeln("[bullet] Death by unit contact.");

//		writefln("[%f,%f] vs u.[%f,%f]", x, y, u.x, u.y);
		if(x - 10 < u.x)
		if(x + 10 > u.x)
		if(y - 10 < u.y)
		if(y + 10 > u.y)
			{
			writeln("FOUND A UNIT");
			return true;
			}		
		return false;
		}
			
	bool checkAsteroidCollision(asteroid a) // TODO fix. currently radial collision setup
		{
		if(distanceTo(this, a) < a.r)
			{
			writeln("[bullet] Death by asteroid.");
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
			writeln("[bullet] Death by planet.");
			return true;
			}else{
			return false;
			}
		}
		
	void die()
		{
		isDead=true;
		vx = 0;
		vy = 0;
		import std.random : uniform;
		g.world.particles ~= particle(x, y, vx, vy, 0, uniform!"[]"(3, 6));
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
					// if we're inside a planet, lets check it for people.
					foreach(d; p.dudes)
						{
						if(x >= d.x + d.myPlanet.x - 10)
						if(x <= d.x + d.myPlanet.x + 10)
						if(y >= d.y + d.myPlanet.y - 10)
						if(y <= d.y + d.myPlanet.y + 10)
							{
							d.isDead = true;
							die();
							}
						}
//					die(); // if we hit a planet
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
			
			foreach(u; g.world.units)
				{
				if(u != myOwner)
					{
					if(checkUnitCollision(u))
						{
						isDead=true;
						u.onHit(this);
						}
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
	float maxHP=100.0; /// Maximum health points
	float hp=100.0; /// Current health points
	float ap=0; /// armor points (reduced on hits then armor breaks)
	float armor=0; /// flat reduction (or percentage) on damages, haven't decided.
	uint team=0;
	bool isPlayerControlled=false;
	float weapon_damage = 5;

	void applyGravity(planet p)
		{		
		// gravity acceleration formula: g = -G*M/r^2
		float G = 1; // gravitational constant
		float M = p.m; // mass of planet
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
		
	void onHit(bullet b) //projectile based damage
		{
		// b.myOwner
		}

	void onCrash(unit byWho) //for crashing into each other/objects
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
//		drawPlanetHelper(this, g.world.planets[1], v);

		// draw angle text
		al_draw_text(g.font1, white, x + v.x - v.ox + 30, y + v.y - v.oy - 30, 0, format("%3.2f", radToDeg(angle)).toStringz); 
	
		draw_hp_bar(x, y - bmp.w/2, v, hp, 100);		
		}
	}
	
class laser : gun
	{
	this(ship newOwner)
		{
		super(newOwner);
		gunCooldownTime = 0; //instant fire
		damage = 1;
		} // not sure how we spawn laser beams. Could be as simple as projecting a line.
		
	override void fireProjectile()
		{
		// spawn laser projectile. (still on g.world.bullets?)
		// but it's a line.
		// maybe a 'laser bullet' structure that requires source position (player) and destination pos?
		}
	}

class minigun : gun
	{
	this(ship newOwner)
		{
		super(newOwner);
		gunCooldownTime = 0;
		spreadArc=5;
		roundsFired=1;
		speed=20;
		}
	}

class shotgun : gun
	{
	this(ship newOwner)
		{
		super(newOwner);
		gunCooldownTime = 30;
		spreadArc=10;
		roundsFired=20;
		}
	}

class gun
	{
	float ammoLeft=100; // float in case we need to do some sort of "eats 1.5 units fluid per frame" logic
	float damage=5;
	int cooldown=0;
	int gunCooldownTime=5;
	int roundsFired=1;
	float speed=10;
	float spreadArc=0; // fixed spread arc degrees (degrees left and right. think 2x for total spread)
	float recoil; // increases with more shots more often
	float recoilCooldown; // nyi
	bool isShotgun=false; //spread. needed?
	unit myOwner;
	
	this(ship newOwner)
		{
		myOwner = newOwner;
		}
	
	void fireProjectile()
		{
		with(myOwner) //CAREFUL not to shadow variables here!
			{
			import std.random;
			float _vx = vx + cos(angle + uniform!"[]"(-spreadArc, spreadArc).degToRad)*speed;
			float _vy = vy + sin(angle + uniform!"[]"(-spreadArc, spreadArc).degToRad)*speed;
			g.world.bullets ~= new bullet(x, y, _vx, _vy, angle, 0, 100, myOwner);
			}
		}
	
	void onTick()
		{
		if(cooldown > 0)
			{
			cooldown--;
			}
		}
	
	void actionFire()
		{
		if(cooldown == 0)
			{
			for(int i = 0; i < roundsFired; i++)fireProjectile();
			cooldown = gunCooldownTime;
			}
		}
	}

class hardpoint : unit
	{
	ship owner;
	
	this(ship _owner)
		{
		hp = 50;
		owner = _owner;
		super(0, owner.x, owner.y, 0, 0, g.trailer_bmp);
		}
	
	override void draw(viewport v)
		{
		COLOR c = COLOR(1,1,1,hp/maxHP);
		al_draw_tinted_rotated_bitmap(bmp, c,
			bmp.w/2, bmp.h/2, 
			owner.x + v.x - v.ox + cos(angle + PI/2f)*10f, 
			owner.y + v.y - v.oy + sin(angle + PI/2f)*10f, angle, 0);
		al_draw_tinted_rotated_bitmap(bmp, c,
			bmp.w/2, bmp.h/2, 
			owner.x + v.x - v.ox + cos(angle + PI/2f)*-10f, 
			owner.y + v.y - v.oy + sin(angle + PI/2f)*-10f, angle, 0);
		}
		
	override void onTick()
		{
		// need some vector rotations;
		angle = owner.angle;
		x = owner.x;
		y = owner.y;
		}
	}

class freighter : ship
	{
	hardpoint[] hardpoints;
		
	this(float _x, float _y, float _xv, float _yv)
		{
		name = "USS Caramelee";
		super(_x, _y, _xv, _yv); // THIS sets up gun. careful to be first.
		myGun = new shotgun(this); // NOTE we're replacing an existing one from super(). That's a memory usage.
		bmp = freighter_bmp;
		SPEED = 0.2;
		auto h = new hardpoint(this);
		hardpoints ~= h;
		}
		
	override void draw(viewport v)
		{
		foreach(h; hardpoints)
			{
			h.draw(v);
			}
		super.draw(v);
		}

	override void onTick()
		{
		foreach(h; hardpoints)
			{
			h.onTick();
			}

		myGun.onTick();
		
		super.onTick();
		}
	}

class ship : unit
	{
	string name="";
	bool isOwned=false;
	player currentOwner;
	bool isLanded=false;
	gun myGun;
	
	/// "constants" 
	/// They are UPPER_CASE but they're not immutable so inherited classes can override them.
	/// unless there's some other way to do that.
	float MAX_LATCHING_SPEED = 3;
	float MAX_SAFE_LANDING_ANGLE = 45;
	float ROTATION_SPEED = 5;
	uint  SHIELD_COOLDOWN = 60; /// frames till it can start recharging
	float SHIELD_RECHARGE_RATE = 0.5; /// once recharging starts rate of fill
	int   SHIELD_MAX = 100; /// total shield health
	float SPEED = 0.1f;
	
//	int gunCooldown = 0;
	float shieldHP = 0;
	int shieldCooldown = 60;
	//we could also have a shield break animation of the bubble popping
	
	this(float _x, float _y, float _xv, float _yv)
		{
		myGun = new minigun(this);
		super(1, _x, _y, _xv, _yv, ship_bmp);
		}

	override void draw(viewport v)
		{
		drawShield(pair(x + v.x - v.ox, y + v.y - v.oy), v, bmp.w, 5, COLOR(0,0,1,1), shieldHP/SHIELD_MAX);
		super.draw(v);
		
		if(name != "")
			{
			drawTextCenter(x + v.x - v.ox, y + v.y - v.oy - bmp.w, white, "%s", name);
			// using bmp.w because it's larger in non-rotated sprites
			}
		}
		
	void crash()
		{
		x += -vx; // NOTE we apply reverse full velocity once 
		y += -vy; // to 'undo' the last tick and unstick us, then set the new heading
		vx *= -.80;
		vy *= -.80;
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
	
	void doLand(planet p)
		{
		if(isOwned)p.currentTeam = currentOwner.myTeam;
		angle = angleTo(this, p);
		isLanded = true;
		vx = 0;
		vy = 0;
		p.capture(currentOwner.myTeam);
		}

	planet findNearestPlanet()
		{
		planet nearestP;
		float nearestD = float.max;
		foreach(p; g.world.planets)
			{
			float d = distanceTo(p, this);
			if(d < nearestD)
				{
				nearestD = d;
				nearestP = p;
				}
			}
		assert(nearestP !is null);
		assert(nearestD != float.max);
		return nearestP;
		}
		
		
	void doShield()
		{
		if(shieldCooldown > 0)
			{
			shieldCooldown--; 
			return;
			}else{
			if(shieldHP < SHIELD_MAX)shieldHP += SHIELD_RECHARGE_RATE;
			if(shieldHP > SHIELD_MAX)shieldHP = SHIELD_MAX;
			}
		}

	override void onTick()
		{
		doShield();
		if(!isLanded)
			{
			applyGravity(findNearestPlanet());
			
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
			//			writefln("A%3.2f B%3.2f result was: %3.2f < %3.2f?", radToDeg(a), radToDeg(b), radToDeg(result), MAX_SAFE_LANDING_ANGLE);
						if(result < degToRad(MAX_SAFE_LANDING_ANGLE))
							{					
		//					writeln(" SUCCESS");
							doLand(p);
							}else{
	//						writeln(" FAIL");
							crash();
							}
						}
					}
				}
				
			foreach(a; g.world.asteroids)
				{
				if(checkAsteroidCollision(a))
					{
				//	isDead=true;
					a.onCrash(this);
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
			applyV(angle, SPEED);
			applyV(angle, SPEED);
			applyV(angle, SPEED);
			}
		applyV(angle, SPEED);
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
		if(!isLanded)myGun.actionFire();
		}
	}
	
class dude : baseObject
	{
	// do dudes walk around the surface or bounce around the inside?
	 
	planet myPlanet;
	
	this(float relx, float rely, float _vx, float _vy, planet _myPlanet)
		{
		myPlanet = _myPlanet;
		super(relx, rely, _vx, _vy, g.dude_bmp);
		}

	// originally a copy of structure.draw
	override void draw(viewport v)
		{		
		// we draw RELATIVE to planet.xy, so no using baseObject.draw
		// TODO how do we rotate angle from center of planet properly? Or do we even need that?
		float cx=myPlanet.x + x + v.x - v.ox;
		float cy=myPlanet.y + y + v.y - v.oy;
		al_draw_center_rotated_bitmap(bmp, cx, cy, 0, 0);
		al_draw_filled_circle(cx, cy, 20, COLOR(1,0,0,.5));
		}
	
	override void onTick()
		{
		import std.random : uniform;
		x += vx;
		y += vy;
		float dist = sqrt(x^^2 + y^^2); //we're using relative-to-planet coordinates!
		if(dist > myPlanet.r)
			{
//			writefln("bounce at [%3.2f,%3.2f] d=%3.2f r=%3.2f", x, y, dist, myPlanet.r);

			// position (shrink radius position of person inward toward planet)
	//		writefln("initial xy = %3.2f, %3.2f", x, y);
			float bangle = atan2(y, x);
			float bd = sqrt(x^^2 + y^^2);
			x = cos(bangle)*bd*.95;
			y = sin(bangle)*bd*.95;
		//	writefln("warping to [%3.2f,%3.2f] of bangle,bd [%3.2f,%3.2f]", x, y, radToDeg(bangle), bd);
			
			// velocity towards planet center
			float cangle = atan2(y, x) + uniform!"[]"(-30.0, 30.0).degToRad; // note not vy, vx! Also this is currently an angle AWAY from planet center.
			float cd = sqrt(vx^^2 + vy^^2);
		//	writefln("cangle: %3.2f d: %3.2f", radToDeg(cangle), cd);
			vx = -cos(cangle)*cd;
			vy = -sin(cangle)*cd;
			}
		}
	}
	
class planet : baseObject
	{
	bool isOwned=false;
	//player currentOwner;
	team currentTeam;
	
	float m = PLANET_MASS;
	float r = 100; /// radius
	string name="Big Chungus";
	structure_t[] structures;
	dude[] dudes;
	
	@disable this();
	this(string _name, float _x, float _y, float _r)
		{
		name = _name;
		r = _r;
		super(_x, _y, 0, 0, g.tree_bmp); // works perfect		
		structures ~= new structure_t(0, 0, g.fountain_bmp, this);
		structures ~= new structure_t( r*.8, 0, g.tree_bmp, this);
		structures ~= new structure_t(-r*.8, 0, g.chest_bmp, this);
		structures ~= new structure_t(0,  r*.8, g.dwarf_bmp, this);
		structures ~= new structure_t(0, -r*.8, g.goblin_bmp, this);
		
		for(int i = 0; i < 100; i++)
			{
			// note dudes have relative coordinates
			float cx = uniform!"[]"(-r, r);
			float cy = uniform!"[]"(-r, r);
			float ca = uniform!"[]"(0, 2*PI);
			float cd = 2;
			float cvx = cos(ca)*cd;
			float cvy = sin(ca)*cd;
			dudes ~= new dude(cx, cy, cvx, cvy, this);
			}
		}
	
	void capture(team by)
		{
		isOwned = true;
		currentTeam = by;
		}
		
	void drawOwnerFlag(viewport v)
		{
		al_draw_filled_circle(x + v.x - v.ox, y + v.y - v.oy, 20, currentTeam.color);
		}
	
	override void draw(viewport v)
		{
		al_draw_filled_circle(x + v.x - v.ox, y + v.y - v.oy, r, COLOR(.8,.8,.8,1));
		al_draw_filled_circle(x + v.x - v.ox, y + v.y - v.oy, r * .80, COLOR(1,1,1,1));
		foreach(s; structures) 
			{
			g.stats.number_of_drawn_structures++;
			s.draw(v);
			}

		foreach(d; dudes) 
			{
//			g.stats.number_of_drawn_structures++;
			d.draw(v);
			}
		
		if(isOwned)drawOwnerFlag(v);
		}

	override void onTick()
		{
		import std.algorithm : remove;
		// do structures  get handled by us or by root logic() call?
		foreach(s; structures) s.onTick();
		foreach(d; dudes) d.onTick();
		prune(structures);
		prune(dudes);
		}

	//prune ready-to-delete entries (copied from g)
	void prune(T)(ref T obj)
		{
		for(size_t i = obj.length ; i-- > 0 ; )
			{
			if(obj[i].isDead)obj = obj.remove(i); continue;
			}
		//see https://forum.dlang.org/post/sagacsjdtwzankyvclxn@forum.dlang.org
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
	// this CRASHES. I'm not sure why, players should exist by now but doesn't. Almost like it's not allocated yet.
	//	assert(g.world.players[0] !is null);
	//	g.world.players[0].money -= 250;
//		assert(p !is null); // this works fine. wtf.
//		p.money -= 250;
		myPlanet = _myPlanet;
		if(myPlanet.isOwned)myPlanet.currentTeam.money -= 250; 
		}

	override void draw(viewport v)
		{
		// we draw RELATIVE to planet.xy, so no using baseObject.draw
		// TODO how do we rotate angle from center of planet properly? Or do we even need that?
		float cx=myPlanet.x + x + v.x - v.ox;
		float cy=myPlanet.y + y + v.y - v.oy;
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
