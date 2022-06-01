import allegro5.allegro;
import allegro5.allegro_primitives;
import allegro5.allegro_image;
import allegro5.allegro_font;
import allegro5.allegro_ttf;
import allegro5.allegro_color;

import g;
import viewportsmod;
import objects;
import helper;
import turretmod;
import planetsmod;
import particles;

import std.math : cos, sin;
import std.stdio;

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

// bullet check against planets
			foreach(p; g.world.planets)
				{
				foreach(s; p.satellites) // against satellite subobjects
					{
					// maybe we should set "myOwner" to be the ship, not the turret?
					// but then you can't hit individual turrets? 
					// but how do we keep from targetting ANY turret of our own ship from our own turret? 
					foreach(t; s.turrets)
						{
						if(t !is this.myOwner && checkUnitCollision(s)) // satellites do NOT use relative coordinates so no custom needed function.
							{
							writefln("-1: %s collision with %s", s, this);
							s.onHit(this);
							isDead=true;
							}
						}
					}

/+				foreach(s; p.structures)
					if(checkUnitCollision(s))
						{
						s.onHit(this);
						}+/
					
/+				if(checkPlanetCollision(p)) // collision WITH planet
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
					}+/
				}

			foreach(a; g.world.asteroids)
				{
				if(checkAsteroidCollision(a))
					{
					writefln("0 collision with %s", a);
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
						writefln("1 collision with %s", u);
//						writefln("[%s] found. I am a: [%s] owned by a [%s] -- TURRET", u, t, t.myOwner);
						continue; //we cannot hit our own unit (a ship, or a turret), or, if our spawner is a turret, we cannot hit the turrets owner (a ship/freighter)
						}
						
					auto f = cast(freighter)myOwner;
					if(f !is null && f.hasDocked)
						{
//						writefln("2 collision with %s", u);
						if(u == f.dockedShip)continue; // DONT SHOOT MY BABIES
						// ignore docked ships
						}
					
//					auto s = cast(satellite)s;
	//				if(f != null && f.myPlanet == u) // continue
						
	//				writefln("[%s] found. I am a: [%s]", u, myOwner);
						
					if(checkUnitCollision(u))
						{
						writefln("3 collision with %s", u);
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
