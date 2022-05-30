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
import particles;
import guns;
import planetsmod;

/*
	Teams
		0 - Neutral		(asteroids. unclaimed planets?)
		1 - Player 1? (if we support real teams, then its whatever team it is)

name clashes
	- we cannot use "object" since that's a D keyword. 
	- we also can't use "with" for onCollision(baseObject with)
*/
class satellite : ship
	{
	BITMAP* gun_bmp;
	planet myPlanet;
	float radius;
	float orbitAngle;
	float orbitVelocity;

	@disable this();

	this(planet _myPlanet, float _radius, float _orbitAngle, float _orbitVelocity)
		{
		myPlanet = _myPlanet;
		radius = _radius;
		orbitAngle = _orbitAngle;
		orbitVelocity = _orbitVelocity;
		assert(myPlanet !is null);
		super(0, 0, 0, 0);
		bmp = g.satellite_bmp;
		gun_bmp = g.ship_bmp;
		}
		
	override void onTick()
		{
		orbitAngle += orbitVelocity;
		orbitAngle.wrapRadRef;
		
		x = myPlanet.x + cos(orbitAngle)*radius;
		y = myPlanet.y + sin(orbitAngle)*radius;
		// doing it this way should let us keep base-class draw routine
		}
		
	override bool draw(viewport v)
		{
		super.draw(v);
		al_draw_center_rotated_bitmap(gun_bmp, x + v.x - v.ox, y + v.y - v.oy, angle, 0);
		return true;
		}
	
	}

class asteroid : unit
	{
	int size=200; // 2 = large, 1 = medium, 0 = small
	float va=0; // velocity of rotation (angular velocity)
	int r=0; // radius, quick collision checking value. 
	bool isAffectedByGravity=false;
	bool doesCollideWithPlanets=false; // WARNING we haven't implemented the case where it's affected by gravity but no collision
	
	override void onCrash(unit byWho)
		{
		isDead = true;
		split();
		}

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
		assert(size >= 0 && size <= 2);
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
		
		if(doesCollideWithPlanets && isAffectedByGravity)
			{
			super.onTick(); //apply unit physics
			}else{
			x += vx;
			y += vy;
			}
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
	bool isDebugging=false;
	float x=0, y=0;
	float vx=0, vy=0;
	float angle=0;
	int type; // 0 = normal bullet whatever
	int lifetime; // frames passed since firing
	bool isDead=false; // to trim
	unit myOwner;
	bool isAffectedByGravity=true;
	COLOR c;
	
	this(float _x, float _y, float _vx, float _vy, float _angle, COLOR _c, int _type, int _lifetime, bool _isAffectedByGravity, unit _myOwner, bool _isDebugging)
		{
		isDebugging = _isDebugging;
		c = _c;
		myOwner = _myOwner;
		x = _x;
		y = _y;
		vx = _vx;
		vy = _vy;
		type = _type;
		lifetime = _lifetime;
		angle = _angle;
		isAffectedByGravity = _isAffectedByGravity;
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
//		writefln("[%f,%f] vs u.[%f,%f]", x, y, u.x, u.y);
		if(x - 10 < u.x)
		if(x + 10 > u.x)
		if(y - 10 < u.y)
		if(y + 10 > u.y)
			{
//		writeln("[bullet] Death by unit contact.");
			return true;
			}		
		return false;
		}
			
	bool checkAsteroidCollision(asteroid a) // TODO fix. currently radial collision setup
		{
		if(distanceTo(this, a) < a.r)
			{
//			writeln("[bullet] Death by asteroid.");
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
	//		writeln("[bullet] Death by planet.");
			return true;
			}else{
			return false;
			}
		}
		
	void die(unit from)
		{
		isDead=true;
		vx = 0;
		vy = 0;
		import std.random : uniform;
		g.world.particles ~= particle(x, y, vx, vy, 0, uniform!"[]"(3, 6));
		if(isDebugging) writefln("[debug] bullet at [%3.2f, %3.2f] died from [%s]", x, y, from);
		}
	
	override void onTick() // should we check for planets collision?
		{
		lifetime--;
		if(lifetime == 0)
			{
			isDead=true;
			}else{
			if(isAffectedByGravity) applyGravity(g.world.planets[0]);

/+			
// bullet check against planets
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
						
//					die(); // if we hit a planet itself
					}
				}
+/			
			foreach(a; g.world.asteroids)
				{
				if(checkAsteroidCollision(a))
					{
					a.onHit(this);
					die(a);
					}
				}
			
		//	writeln("---FRAME---");
			foreach(u; g.world.units) // NOTE: this is only scanning units not SUBARRAYS containing turrets
				{

				if(u != myOwner)
					{
					auto t = cast(attachedTurret)myOwner; //if we're from a turret, check against our turrets owner
					if(t !is null && u == t.myOwner)
						{
//						writefln("[%s] found. I am a: [%s] owned by a [%s] -- TURRET", u, t, t.myOwner);
						continue; //we cannot hit our own unit (a ship, or a turret), or, if our spawner is a turret, we cannot hit the turrets owner (a ship/freighter)
						}
	//				writefln("[%s] found. I am a: [%s]", u, myOwner);
						
					if(checkUnitCollision(u))
						{
						u.onHit(this);
						die(u);
						}
					}					
				}
						
			x += vx;
			y += vy;
			}
		}
	
	override bool draw(viewport v)
		{		
		float cx = x + v.x - v.ox;
		float cy = y + v.y - v.oy;
		if(cx > 0 && cx < SCREEN_W && cy > 0 && cy < SCREEN_H)
			{
			al_draw_center_rotated_tinted_bitmap(bmp, c, cx, cy, angle + degToRad(90), 0);
			return true;
			}
		return false;
		}
	}
/+
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
	}+/

class item : baseObject
	{
	bool isInside = false; //or isHidden? Not always the same though...
	int team;
	
	this(uint _team, float _x, float _y, float _vx, float _vy, ALLEGRO_BITMAP* b)
		{	
		writeln("ITEM EXISTS BTW at ", x, " ", y);
		super(_x, _y, _vx, _vy, b);
		}
		
	override bool draw(viewport v)
		{
		if(!isInside)
			{
			super.draw(v);
			return true;
			}
		return false;
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
	int myTeamIndex=0;
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

	void doAttackStructure(structure s)
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
	
	this(uint _teamIndex, float _x, float _y, float _vx, float _vy, ALLEGRO_BITMAP* b)
		{
		myTeamIndex = _teamIndex; 
		super(_x, _y, _vx, _vy, b);
		}

	override bool draw(viewport v)
		{
		super.draw(v);
		
		// Velocity Helper
		float mag = distance(vx, vy)*10.0;
		float angle2 = atan2(vy, vx);
		drawAngleHelper(this, v, angle2, mag, COLOR(1,0,0,1)); 
		
//		drawAngleHelper(this, v, angle, 25, COLOR(0,1,0,1)); // my pointing direction

		// Planet Helper(s)
		if(isPlayerControlled) 
			{
			drawPlanetHelper(this, g.world.planets[0], v);

			pair p1 = pair(x + v.x - v.ox - bmp.w, y + v.y - v.oy - bmp.h);
			pair p2 = pair(x + v.x - v.ox + bmp.w, y + v.y - v.oy + bmp.h);
			drawSplitRectangle(p1, p2, 20, 1, white);

			// draw angle text
			al_draw_text(g.font1, white, 
				x + v.x - v.ox + bmp.w + 30, 
				y + v.y - v.oy - bmp.w, 0, format("%3.2f", radToDeg(angle)).toStringz); 
			}
		
		// Point to other player (could for nearby enemy units) once seen (but not before)
		//float angle3 = angleTo(g.world.units[0], this);
		//drawAngleHelper(this, v, angle3, 25, COLOR(1,1,0,1)); 
	
		draw_hp_bar(x, y - bmp.w/2, v, hp, 100);		
		return true;
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
	
	override bool draw(viewport v)
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
		return true;
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
		super(_x, _y, _xv, _yv); // THIS sets up a gun. careful to call first.
		myGun = new shotgun(this); // NOTE we're replacing an existing one from super(). That's a memory usage.
		
//		myGun.isDebugging = true; //DEBUG
		
		bmp = freighter_bmp;
		SPEED = 0.2;
		auto h = new hardpoint(this);
		hardpoints ~= h;
		
		turrets ~= new attachedTurret(0, 0, this);
		turrets[0].isDebugging = true; //DEBUG
		}
		
	override bool draw(viewport v)
		{
		foreach(h; hardpoints)
			{
			h.draw(v);
			}
		super.draw(v);
		return true;
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

class planetTurret : turret
	{
	// >>USING RELATIVE COORDINATES<<
	this(float _x, float _y, baseObject _myOwner)
		{
		super(_x, _y, _myOwner, true); // special constructor
		myGun = new planetGun(this);
		}
	}

class attachedTurret : turret
	{
	float attachmentX;
	float attachmentY; // offset from 0,0 attachment point so we can rotate around it

	this(float _x, float _y, baseObject _myOwner)
		{
		super(_x, _y, _myOwner);
		isDebugging = true;
		}

	override bool draw(viewport v)
		{
		float dist = 50;
		float cangle = myOwner.angle;
		float cx = myOwner.x + v.x - v.ox + cos(cangle)*dist; // NOTE. we're currently NOT USING x,y
		float cy = myOwner.y + v.y - v.oy + sin(cangle)*dist; // because vector addition hard. apparently.
//			al_draw_centered_bitmap(bmp, cx, cy, 0);
		al_draw_center_rotated_bitmap(turretGun_bmp, cx, cy, angle, 0);
		return true;
		}
	
	override void onTick()
		{
//		writeln("I am a attachedTurret.ontick()");
		alignTurretandFire(); //TODO FIX ME. Change the coordinates
		}
	}

class turret : ship
	{
	// >>USING RELATIVE COORDINATES<<
	BITMAP* turretGun_bmp;
	baseObject myOwner;
	float TURRET_TRAVERSE_SPEED=degToRad(2);
	float TURRET_FIRE_DISTANCE=400f;
	
	this(float _x, float _y, baseObject _myOwner, bool dontSetupGun=true) // special case for planetTurret that will setup the gun
		{
		super(_x, _y, 0, 0);
		turretGun_bmp = g.turret_bmp;
		bmp = g.turret_base_bmp;
		myOwner = _myOwner;
		}
	
	this(float _x, float _y, baseObject _myOwner)
		{
		super(_x, _y, 0, 0);

		myGun = new turretGun(this, yellow);
		turretGun_bmp = g.turret_bmp;
		bmp = g.turret_base_bmp;
		myOwner = _myOwner;
		}

	override bool draw(viewport v)
		{
		al_draw_centered_bitmap(bmp, myOwner.x + x + v.x - v.ox, myOwner.y + y + v.y - v.oy, 0);
		al_draw_center_rotated_bitmap(turretGun_bmp, myOwner.x + x + v.x - v.ox, myOwner.y + y + v.y - v.oy, angle, 0);
		return true;
		}

	void alignTurretandFire()
		{
		pair absoluteP = pair(myOwner.x + x, myOwner.y + y); 
	
		// this simple section has turned into a nightmare of angles and tests not working
		
		// whenever we have "shoot the nearest enemy" we need to not shoot at our owner (or I guess our team, which counts as our owner)
		// but also not HITTING our owner.
	
		float destinationAngle = angleTo(g.world.units[0], absoluteP);
		float distance = distanceTo(g.world.units[0], absoluteP);
		//writeln(angle, " ", destinationAngle);
//		writeln(angle.radToDeg, " ", destinationAngle.radToDeg);

// --------------> read this thoroughly
// https://math.stackexchange.com/questions/110080/shortest-way-to-achieve-target-angle

// TODO: FIX THESE		
//		assert(angle == wrapRad(angle)); these are floats so we'd need to at least check a float /w range test
//		assert(destinationAngle == wrapRad(destinationAngle));
		angle = wrapRad(angle);
		destinationAngle = wrapRad(destinationAngle);
		
	//	auto t = angleDiff2(angle, destinationAngle + PI/2); //FIXME: Why is this off by 90 degrees?!?!? but not for all turrets!? what the hell is going on.
//		writeln(angle.radToDeg, " ", destinationAngle.radToDeg, " = ", t.radToDeg);
	//	if(t < 0)
		if(angle > destinationAngle)
			{
//			writeln("down");
			angle -= TURRET_TRAVERSE_SPEED;
		}else{
	//		writeln("up");
			angle += TURRET_TRAVERSE_SPEED;
			}
		 //grab target()
		myGun.onTick();
		vx = myOwner.vx; // note, these aren't "used" for our position, but are needed for spawning bullets
		vy = myOwner.vy; // that add with our velocity.
		
//		if(distance < TURRET_FIRE_DISTANCE)
		myGun.actionFireRelative(myOwner);
		}

	override void onTick()
		{
		alignTurretandFire();
		}
	}

class ship : unit
	{
	string name="";
	bool isControlledByAI=false;
	bool isDebugging=false;
	bool isOwned=false;
	player currentOwner;
	bool isLanded=false; /// on planet
	bool isDocked=false; /// attached to object
	unit dockingUnit;
	gun myGun;
	turret[] turrets;
	int numDudesInside; // NYI, we don't need (at least at this point) to keep actual unique dude classes inside. Just delete them and keep track of how many we had. (ala all level-1 blue pikmin are the same)
	int numDudesInsideMax = 20;
	
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
		
	bool requestBoarding(dude d)
		{
		// we send dude type just in case there's multiple classes or something.
		if(numDudesInside < numDudesInsideMax)
			{
			numDudesInside++;
			return true;
			}else{
			return false; // we full
			}
		}
	
	this(float _x, float _y, float _xv, float _yv)
		{
		myGun = new minigun(this);
		super(1, _x, _y, _xv, _yv, ship_bmp);
		}

	override bool draw(viewport v)
		{
		float cx = x + v.x - v.ox;
		float cy = y + v.y - v.oy;
		if(cx < 0 || cx > SCREEN_W || cy < 0 || cy > SCREEN_H)return false;
		//drawShield(pair(x, y), v, bmp.w, 5, COLOR(0,0,1,1), shieldHP/SHIELD_MAX);
		super.draw(v);
		
		foreach(t; turrets){t.draw(v); g.stats.number_of_drawn_units++; }
		
		if(name != "")
			{
			if(numDudesInside == 0)
				drawTextCenter(cx, cy - bmp.w, white, "%s", name);
			else
				drawTextCenter(cx, cy - bmp.w, white, "%s [+%d]", name, numDudesInside);
					
			// using bmp.w because it's larger in non-rotated sprites
			}
		
		return true;
		}
		
	void crash()
		{
		x += -vx; // NOTE we apply reverse full velocity once 
		y += -vy; // to 'undo' the last tick and unstick us, then set the new heading
		vx *= -.80;
		vy *= -.80;
		}
		
	bool checkUnitCollision(unit u)
		{
//		writefln("[%f,%f] vs u.[%f,%f]", x, y, u.x, u.y);
		if(x - 10 < u.x)
		if(x + 10 > u.x)
		if(y - 10 < u.y)
		if(y + 10 > u.y)
			{
//		writeln("[bullet] Death by unit contact.");
			return true;
			}		
		return false;
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
	
	void dumpDudes(planet p)
		{
		for(int i = 0; i < numDudesInside; i++)
			p.dudes ~= new dude(0, 0, uniform!"[]"(-1.0,1.0), uniform!"[]"(-1.0,1.0), p); 
		numDudesInside = 0;
		// todo: 
		// - Check for max planet capacity.
		// - make dudes spawn properly from ship and have normal angle/pos
		// - make a better dude constructor
		}
	
	void doLand(planet p)
		{
		if(isOwned)
			{
			p.currentTeamIndex = currentOwner.myTeamIndex;
			angle = angleTo(this, p);
			isLanded = true;
			vx = 0;
			vy = 0;
			p.capture(currentOwner.myTeamIndex, this);
			dumpDudes(p);
			}else{
			// ships that aren't being used by a player cannot capture. IF that needs to change, we currently cannot follow a null reference to a player class.
			}
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
		
	void runAI()
		{
		// Mode: attack
		// we can add randomness (on spawn) to certain parameters to make it more 'human' / imperfect
		// Overshooting (detect turn left, but then we keep turning left until we get a stop turning
		// or turn right command, then we reduce the tickrate of the AI)
		// - could implement some sort of PID controller
		//		desired_pos(player)		-- set point (SP)
		//		this:
		//			current_pos			-- 
		//			current_vel
		//			current_angle
		// 
		// at the very least, a PID of "distance to target" plus our velocity equation
		//	https://en.wikipedia.org/wiki/PID_controller
		//
		//	P proportional error vs desired
		//	D derivative, for dampening overshoot
		//  I integral (not needed?) for removing residuals
		// 
		// ALSO, ships currently have LINEAR velocity. Do we want SQUARED so they can't speed up as fast?
		//	K.E. = 1/2mv^^2
		/+
			ALSO (not necessarily needed) but look up PID velocity and position control
				because if we're taking an integral or derivative of position (or velocity)...
				we're already using those terms and may plug them in. (del pos/time = velocity right?)
			
			we might use a more advanced version for getting AI ships to land on planets carefully (desired end velocity=0)
		+/
	
		immutable float MAX_AI_SPEED = 2;		// jet till we hit max speed
		immutable float BOOST_DISTANCE = 100; 	// jet until we close distance (what about manuevering for close combat vs closing the distance?)
		immutable float ENGAGE_DISTANCE = 400;
		immutable float SHOT_PERCENT = 25;		// 1/60th frame rate, 25% = ~15 shots / second max (not including cooldown) 
		immutable float SHOT_ANGLE_RANGE = 30;  // NYI, don't shoot unless we're SOMEWHAT close to being able to hit (don't shoot backwards). Unless we want to look stupid sometimes. Add a percentage chance for that based on AI_STUPIDITY.
		
		unit target = g.world.units[0];
		float a = angleTo(target, this);
		// FIXME: WARNING. This will cap max speed... even if we're going max speed opposite direction!
		if(distanceTo(target, this) > BOOST_DISTANCE /*&& distance(vx, vy) < MAX_AI_SPEED*/){up();}
		if(distanceTo(target, this) < ENGAGE_DISTANCE && percent(SHOT_PERCENT)){actionFire();}		
		if(isLanded)up();
		if(angle > a)left();
		if(angle < a)right();
		}

	override void onTick()
		{
		/// Subunit logic
		myGun.onTick();
		doShield();
		foreach(t; turrets)t.onTick();
		if(isControlledByAI)runAI();
		
		/// Self logic
		if(isDocked)
			{
			assert(dockingUnit !is null);
			vx = 0;
			vy = 0;
			x = dockingUnit.x;
			y = dockingUnit.y;
			angle = dockingUnit.angle;
			return; // <------- EARLY TERMINATION
			}
			
		if(!isLanded)
			{
			applyGravity(findNearestPlanet());
			
			/// check for docking
			if(!isDocked)
				{
				foreach(u; g.world.units)
					{
					if(checkUnitCollision(u))
						{
						if((u !is this) && cast(freighter)u !is null)
							{
							isDocked = true;
							dockingUnit = u;
							}
						}
					}
				}
			
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
		float cvx = cos(angle)*0;
		float cvy = sin(angle)*0;
		g.world.particles ~= particle(x, y, vx + cvx, vy + cvy, 0, 100, this);
		}

	override void up()
		{		
		if(isLanded || isDocked)
			{				
			isDocked = false;
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

	override void actionFire()
		{
		if(!isLanded)myGun.actionFire();
		}
	}
	
class dude : baseObject
	{
	// do dudes walk around the surface or bounce around the inside?
	bool isRunningForShip=false;
	ship landedShip;
	planet myPlanet;
	
	this(float relx, float rely, float _vx, float _vy, planet _myPlanet)
		{
		myPlanet = _myPlanet;
		super(relx, rely, _vx, _vy, g.dude_bmp);
		}

	// originally a copy of structure.draw
	override bool draw(viewport v)
		{		
		// we draw RELATIVE to planet.xy, so no using baseObject.draw
		// TODO how do we rotate angle from center of planet properly? Or do we even need that?
		float cx=myPlanet.x + x + v.x - v.ox;
		float cy=myPlanet.y + y + v.y - v.oy;
		if(cx < 0 || cx > SCREEN_W || cy < 0 || cy > SCREEN_H)return false;

		al_draw_center_rotated_bitmap(bmp, cx, cy, 0, 0);
		if(isRunningForShip)
			al_draw_filled_circle(cx, cy, 20, COLOR(0,1,0,.5));
			else
			al_draw_filled_circle(cx, cy, 20, COLOR(0,0,1,.5));
		return true;
		}

	void checkPlanetBoundaries()
		{	
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
			
			isRunningForShip = false;
			}
		}
	
	void checkForShipPickup(ship s)
		{
		pair p = pair(myPlanet.x + x, myPlanet.y + y);
		
		if(p.x - 10 < s.x)
		if(p.x + 10 > s.x)
		if(p.y - 10 < s.y)
		if(p.y + 10 > s.y)
			{
			//if (ship isn't full)
			if(s.requestBoarding(this))
				{
				isDead = true;
				}else{
				isRunningForShip = false;
				}
			}
		}
	
	override void onTick()
		{
		import std.random : uniform;
		
		if(isRunningForShip)
			{
			pair p = pair(myPlanet.x + x, myPlanet.y + y);
			float angle=angleTo(landedShip, p);
			vx = cos(angle)*1;
			vy = sin(angle)*1;
			checkForShipPickup(landedShip);
			}
		
		x += vx;
		y += vy;

		checkPlanetBoundaries();
		}
	}
	
class structure : baseObject
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
		if(myPlanet.isOwned)g.world.teams[myPlanet.currentTeamIndex].money -= 250; 
		}

	override bool draw(viewport v)
		{
		// we draw RELATIVE to planet.xy, so no using baseObject.draw
		// TODO how do we rotate angle from center of planet properly? Or do we even need that?
		float cx=myPlanet.x + x + v.x - v.ox;
		float cy=myPlanet.y + y + v.y - v.oy;
		al_draw_center_rotated_bitmap(bmp, cx, cy, 0, 0);
		draw_hp_bar(x, y, v, hp, maxHP);
		return true;
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
		
	bool draw(viewport v)
		{
		al_draw_center_rotated_bitmap(bmp, 
			x - v.ox + v.x, 
			y - v.oy + v.y, 
			angle, 0);

		return true;
		}
	
	// INPUTS (do we support mouse input?)
	// ------------------------------------------
	void up(){ y-= 10;}
	void down(){y+= 10;}
	void left(){x-= 10;}
	void right(){x+= 10;}
	void actionFire()
		{
		}
	
	void onTick()
		{
		// THOU. SHALT. NOT. PUT. PHYSICS. IN BASE. baseObject.
		}
	}	
