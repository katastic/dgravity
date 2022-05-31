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

import std.stdio;
import std.math;
import std.random : uniform;
import std.algorithm : remove;
/+
	planet types?
		- resource (generate X money or X metal)
		- manufacturing (generate X units when recieving metal?)
		- homebase?	(autocreates new carriers when you run out?)
+/
class planet : baseObject
	{
	bool isProducer=false;
	bool isOwned=false;
	//player currentOwner;
	int currentTeamIndex;
	
	float m = PLANET_MASS;
	float r = 100; /// radius
	string name="Big Chungus";
	structure[] structures;
	dude[] dudes;
	turret[] turrets;
	satellite[] satellites; // not sure if turrets+satellites should be combined into a units array
	
	@disable this();
	this(string _name, float _x, float _y, float _r, int dudePopulation)
		{
		name = _name;
		r = _r;
		super(_x, _y, 0, 0, g.tree_bmp); // works perfect		
		structures ~= new structure(0, 0, g.fountain_bmp, this);
		structures ~= new structure( r*.8, 0, g.tree_bmp, this);
		structures ~= new structure(-r*.8, 0, g.chest_bmp, this);
		structures ~= new structure(0,  r*.8, g.dwarf_bmp, this);
		structures ~= new structure(0, -r*.8, g.goblin_bmp, this);
		
//		turrets ~= new planetTurret(-r,0.0, this);
//		turrets ~= new planetTurret( r,0.0, this);
//		turrets ~= new planetTurret( 0, -r, this);
//		turrets ~= new planetTurret( 0,  r, this);
		
		satellites ~= new satellite(this, r*1.5, 0, degToRad(.25));
		
		assert(dudePopulation >= 0);
		for(int i = 0; i < dudePopulation; i++)
			{
			// note dudes have relative coordinates
			float cx = uniform!"[]"(-r, r);
			float cy = uniform!"[]"(-r, r);
			float ca = uniform!"[]"(0, 2*PI);
			float cd = 2;
			float cvx = cos(ca)*cd;
			float cvy = sin(ca)*cd;
			dudes ~= new dude(rpair(cx, cy), cvx, cvy, this);
			}
		}
	
	void capture(int byTeamIndex, ship by) // do we need byTeamIndex if we have a ship now?
		{
		isOwned = true;
		currentTeamIndex = byTeamIndex;
		
		foreach(d; dudes)
			{
			d.isRunningForShip = true;
			d.landedShip = by;
			}
		}
		
	void drawOwnerFlag(viewport v)
		{
		al_draw_filled_circle(x + v.x - v.ox, y + v.y - v.oy, 20, g.world.teams[currentTeamIndex].color);
		}
	
	override bool draw(viewport v)
		{
		float cx = x + v.x - v.ox;
		float cy = y + v.y - v.oy;
// this pruning doesn't work for really big (bigger than screen) planets
//		if(cx < r || cx > SCREEN_W + r || cy < r || cy > SCREEN_H + r)return false;
		al_draw_filled_circle(cx, cy, r, COLOR(.2,.2,.8,1));
		al_draw_filled_circle(cx, cy, r * .80, COLOR(.6,.6,1,1));
		foreach(s; structures) 
			{
			if(s.draw(v))
				g.stats.number_of_drawn_structures++;
			else
				g.stats.number_of_drawn_structures_clipped++;			
			}

		foreach(d; dudes) 
			{
			if(d.draw(v))
				g.stats.number_of_drawn_dudes++;
			else
				g.stats.number_of_drawn_dudes_clipped++;			
			}

		foreach(t; turrets)
			{
			if(t.draw(v))
				g.stats.number_of_drawn_units++;
			else
				g.stats.number_of_drawn_units_clipped++;			
			}

		foreach(s; satellites)	
			{
			if(s.draw(v))
				g.stats.number_of_drawn_units++;
			else
				g.stats.number_of_drawn_units_clipped++;			
			}

		if(isOwned)drawOwnerFlag(v);
		return true;
		}

	void handleStructures()
		{
		foreach(s; structures) s.onTick();
		foreach(d; dudes) d.onTick();
		foreach(t; turrets) t.onTick();
		foreach(s; satellites) s.onTick();
		prune(structures);
		prune(dudes);
		prune(turrets);
		prune(satellites);
		}

	int cooldown=0;
	int SPAWN_COOLDOWN=60;
	override void onTick()
		{
		handleStructures();
		//x += vx;
		//y += vy; //do we planets moving? Also, do we want them moving on a set orbit path (ala KSP) not gravity
		if(isProducer)
			{
			if(cooldown > 0)cooldown--;
			if(cooldown == 0)
				{
				cooldown = SPAWN_COOLDOWN;
				auto s = new ship(x, y - r*2, -1, 0);
				s.isControlledByAI = true;
				g.world.units ~= s;
				}
			}
		}
	}
