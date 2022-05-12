
enum STATE{	WALKING, SPRINTING, JUMPING, LANDING, ATTACKING}

interface animState
	{
	void enter();
	void trigger();
	void exit();
	}

class attackingState : animState
	{
	void enter(){}
	void trigger(){}
	void exit(){}
	}

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
import viewport;

class item : drawable_object_t
	{
	bool isInside = false; //or isHidden? Not always the same though...
	int team;
	
	this(uint _team, float _x, float _y, float _vx, float _vy, ALLEGRO_BITMAP* b)
		{
		x = _x;
		y = _y;
		vx = _vx;
		vy = _vy;
		
		writeln("ITEM EXISTS BTW at ", x, " ", y);
		super(b);
		}
		
	override void draw(viewport_t v)
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

class boss_t : monster_t
	{
	this(float _x, float _y, float  _vx, float _vy)
		{
		super(_x, _y, _vx, _vy);
		bmp = g.boss_bmp;
		hp = 300;
		}
	}

class monster_t : unit_t
	{
	bool isBeingHit=false;

	this(float _x, float _y, float  _vx, float _vy)
		{
		super(2, _x, _y, _vx, _vy, g.goblin_bmp);
		}

	void onHit(unit_t by, float damage)
		{
		isBeingHit=true;

		float angle = atan2(by.y - y, by.x - x);
		float vel = 2.0f;
		
		vx = -cos(angle)*vel;
		vy = -sin(angle)*vel;
		writeln(angle, ",", vel, ",", vx, ",", vy);
		hp -= damage;
		writeln("monster hit. health is now:", hp);

		if(hp <= 0)
				{
				writeln("monster died!"); 
				delete_me = true; 
				}
		}

	override void onTick()
		{
		}
	}


class unit_t : drawable_object_t 
	{
	immutable float maxHP=100.0; /// Maximum health points
	float hp=maxHP; /// Current health points
	float ap=0; /// armor points (reduced on hits then armor breaks)
	float armor=0; /// flat reduction (or percentage) on damages, haven't decided.
	uint team=0;
	bool isPlayerControlled=false;
	float weapon_damage = 5;

	void doAttackStructure(structure_t s)
		{
		s.onHit(this, weapon_damage);
		}

	void doAttack(unit_t u)
		{
		u.onAttack(this, weapon_damage);
		}
		
	void onAttack(unit_t from, float amount) /// I've been attacked!
		{
		hp -= amount;
		}
	
	this(uint _team, float _x, float _y, float _xv, float _yv, ALLEGRO_BITMAP* b)
		{
		super(b);
		team = _team; 
		x = _x; 
		y = _y;
		vx = _xv;
		vy = _yv;
		}

	override void draw(viewport_t v)
		{
		al_draw_tinted_bitmap(bmp,
			ALLEGRO_COLOR(1.0, 1.0, 1.0, 1.0),
			x - v.ox + v.x - bmp.w/2, 
			y - v.oy + v.y - bmp.h/2, 
			0);			
		
		draw_hp_bar(
			x - v.ox + v.x, 
			y - v.oy + v.y - bmp.w/2, 
			v, hp, 100);		
		}

	override void onTick()
		{
		}
	}

class dwarf_t : unit_t
	{
	this(float _x, float _y, float _xv, float _yv, ALLEGRO_BITMAP* b)
		{
		super(1, _x, _y, _xv, _yv, b);
		bmp = g.dude_up_bmp;
		}

	override void draw(viewport_t v)
		{
		super.draw(v);
		}

	override void onTick()
		{		
		}
		
	immutable float RUN_SPEED = 2.0f; 
	immutable float JUMP_SPEED = 4.0f; 

	override void up(){ }
	override void down() { }
	override void left() { }
	override void right() { }
	override void attack()
		{
		}
	}
	
class drawable_object_t : object_t
	{
	ALLEGRO_BITMAP* bmp;
	
	@disable this(); // SWEET. <-THIS (no relation) means the compiler checks to make
	// sure we call super() from child classes!!!!!
	
	this(ALLEGRO_BITMAP* _bmp) 
		{
		bmp = _bmp;
		}
	
	void draw(viewport_t v)
		{
		al_draw_bitmap(bmp, 
			x - v.ox + v.x - bmp.w/2, 
			y - v.oy + v.y - bmp.h/2, 
			0);
		}
	}	

class structure_t : drawable_object_t
	{
	immutable float maxHP=500.0;
	float hp=maxHP;
	int level=1; //ala upgrade level
	int team=0;
	int direction=0;
	immutable int countdown_rate = 200; // 60 fps, 60 ticks = 1 second
	int countdown = countdown_rate; // I don't like putting variables in the middle of classes but I ALSO don't like throwing 1-function-only variables at the top like the entire class uses them.
	
	this(float x, float y, ALLEGRO_BITMAP* b)
		{
		super(b);
		writeln("we MADE a structure. @ ", x, " ", y);
		g.players[0].money -= 250;
		this.x = x;
		this.y = y;	
		}

	override void draw(viewport_t v)
		{
		super.draw(v);
		draw_hp_bar(x, y, v, hp, maxHP);
		}

	void onHit(unit_t u, float weapon_damage)
		{
		hp -= weapon_damage;
		}

	override void onTick()
		{
		}
	}

	

class object_t
	{
	public:
	bool		delete_me = false;
	
	float 		x, y; 	/// Objects are centered at X/Y (not top-left) so we can easily follow other objects.
	float		vx, vy; /// Velocities.
	float		w, h;   /// width, height (does this make sense in here instead of drawable_object_t)
	float 		angle;	/// pointing angle (not necessarily the direction of movement)


	// if this gets called implicity through SUPER, AFTER later code changes it, we reset back to defaults!
	// we have to be CAREFUL to make sure the call order for super is DEFINED and respected.
	this()
		{
		x = 0;
		y = 0;
		vx = 0;
		vy = 0;
		}

	this(float _x, float _y, float _vx, float _vy)
		{
		x = _x;
		y = _y;
		vx = _vx;
		vy = _vy;
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

	// EVENTS
	// ------------------------------------------
	void onTick()
		{
		}

	void on_collision(object_t other_obj)
		{
		}	
	}	
