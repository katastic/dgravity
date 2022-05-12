
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
import map;

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

class treasure_chest : drawable_object_t
	{
	int team;
	bool isOpen = false;
	bool isOpening = false; // so you can't open it while opening it.
	int state_delay = 0;
	item[] itemsInside;

	//fixme
	this(uint _team, float _x, float _y, float _xv, float _yv)
		{
		writeln("i'm existing.");
		super(g.chest_bmp);
		team = _team; 
		x = _x; 
		y = _y;
		vx = _xv;
		vy = _yv;
		}
		
	void onHit(unit_t by)
		{
		isOpening = true;
		writeln("[Treasure Chest] OPENING");
		state_delay = 60;		
		}
	
	override void onTick()
		{		
		if(isOpening)
			{
			state_delay--;
			if(state_delay == 0)
				{
				isOpen = true;
				isOpening = false;
				
				writeln("OPENED");
				bmp = g.chest_open_bmp;
				foreach(ref i; itemsInside)
					{
					writeln("item pop");
					i.isInside = false;
					i.x = x;
					i.y = y;
					
					float vel = 1.0f;
					float angle = uniform!"[]"(0, 2*PI);
					
					i.vx = cos(angle)*vel;
					i.vy = sin(angle)*vel;
					}
				itemsInside = [];
				}
			}
		}

	void onUse(unit_t user)
		{
		if(isOpen == false)
			{
			state_delay = 60;
			isOpening = true;
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
				g.world.blood2.add(x, y);

		if(hp <= 0)
				{
				writeln("monster died!"); 
				delete_me = true; 
				g.world.blood2.add(x + uniform(-5, 5), y + uniform(-5, 5));
				g.world.blood2.add(x + uniform(-5, 5), y + uniform(-5, 5));
				g.world.blood2.add(x + uniform(-5, 5), y + uniform(-5, 5));
				g.world.blood2.add(x + uniform(-5, 5), y + uniform(-5, 5));
				g.world.blood2.add(x + uniform(-5, 5), y + uniform(-5, 5));
				}
		}

	override void onTick()
		{
		import g : TILE_W, TILE_H;
		g.world.blood2.add(x, y);
		if(!isBeingHit && percent(4) )
			{			
			float angle = atan2(g.world.units[0].y - y, g.world.units[0].x - x);
			float vel = 1.0f;
						
			vx = cos(angle)*vel;
			vy = sin(angle)*vel;
			}
	
		super.onTick();
		attemptMoveRel(vx, vy);

		if(isBeingHit)
			{
			vx *= .99;
			vy *= .99;
			if(abs(vx) < .3 && abs(vy) < .3)
				{
				vx = 0; 
				vy = 0; 
				isBeingHit = false;
				}  
			}

		if(x < 0 || y < 0)delete_me = true;
		if(x > (world.map.w-1)*TILE_W)delete_me = true;
		if(y > (world.map.h-1)*TILE_H)delete_me = true;
		
		int i = cast(int) x/TILE_W;
		int j = cast(int) y/TILE_H;

		if(world.map.data[i][j] == 3) //if water, take damage
			{
			hp -= 5;
			}
		}
	}

class tree : drawable_object_t 
	{
	float waterPercent=50;
	float growthPercent=0;
	immutable float waterMinimum = 20;
	
	this(float _x, float _y, float _xv, float _yv, ALLEGRO_BITMAP* b)
		{
		super(g.tree_bmp);
		x = _x;
		y = _y;
		vx = _xv;
		vy = _yv;
		}

	override void onTick()
		{
		if(waterPercent > waterMinimum && growthPercent < 100)
			{
			growthPercent+=.5;
			}
		}

	override void draw(viewport_t v)
		{
//		super.draw(v);
		float x2 = x - v.ox + v.x - bmp.w/2;
		float y2 = y - v.oy + v.y - bmp.h/2;
		draw_hp_bar(x2, y2, v, growthPercent, 100); 
		al_draw_scaled_bitmap(bmp,
		   0, 0, g.sword_bmp.w, bmp.h,
		   x2, y2, 
		   bmp.w*growthPercent/100.0, bmp.h*growthPercent/100.0, 
		   0);
		}
	}

class unit_t : drawable_object_t 
	{
	immutable float maxHP=100.0; /// Maximum health points
	float hp=maxHP; /// Current health points
	float ap=0; /// armor points (reduced on hits then armor breaks)
	float armor=0; /// flat reduction (or percentage) on damages, haven't decided.
	float weapon_damage=50;
	bool has_weapon=false;
	bool isAttacking=false;
	bool isRunning=false;
	uint team=0;
	bool isPlayerControlled=false;
	
	void attemptMoveRel(float dx, float dy)
		{
		import g : TILE_W, TILE_H;
		float cx = x + dx;
		float cy = y + dy;
		if(cx > 0 && cy > 0 && cx < g.world.map.w*(TILE_W-1) && cy < g.world.map.h*(TILE_H-1))
			{
			tile type = g.world.map.data[cast(int)cx/TILE_W][cast(int)cy/TILE_H];
			if(g.atlas1.isPassable[type])
				{
				x = cx;
				y = cy;
				}
			}
		}

	void searchAndAttackNearbyEnemy() /// first one we find. ALSO STRUCTURES!
		{
		import g : TILE_W, TILE_H;
		isAttacking = false;
		foreach(u; world.units)  // le oof algorithm complexity
			{
			assert(u.team != 0);
			if(u.team != team)
				{
				if( to!int(u.x/TILE_W) == to!int(x/TILE_W) && (to!int(u.y/TILE_H) == to!int(y/TILE_H)) )
					{
					attack(u);
					isAttacking=true;
					break;
					}
				}
			}
			
		// <-- At this point, if we've failed to find any valid units, we search structures
			
		// Optimization-wise, it'd be nice of we only scanned structures first so we can bail out
		// early. (does that make sense? it's late) but we need to gameplay wise, attack PEOPLE on 
		// a tile before we bother with structures otherwise a structure cannot defend itself! 
		// (at least not on the tile its on)
		
		foreach(s; world.structures)
			{
			assert(s.team != 0);
			if(team != s.team)
			if(to!int(s.x/TILE_W) == to!int(x/TILE_W) && (to!int(s.y/TILE_H) == to!int(y/TILE_H)))
				{
				attackStructure(s);
				isAttacking=true;
				break;
				}
			}
		}
	
	void attackStructure(structure_t s)
		{
		s.onHit(this, weapon_damage);
		}

	void attack(unit_t u)
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

	void drawShadow(viewport_t v)
		{		
		import std.math : atan2;

		foreach(l; g.lights)
			{
			// re: fading alpha with distance
			// "I don't think this is how light works"
			float alpha = 0.75 - capHigh(distanceTo(this, l)/200, 0.75f);
			float angle = angleTo(this, l); //g.world.units[0]
			float distance = (bmp.w + bmp.h) / 2;
			float relx = cos(angle)*distance;
			float rely = sin(angle)*distance;

			al_draw_tinted_scaled_bitmap(bmp,
			   COLOR(0,0,0,alpha),
			   0,0,bmp.w, bmp.h,
			   relx + x - v.ox + v.x - bmp.w/2, 
			   rely + y - v.oy + v.y - bmp.h/2, 
			   bmp.w, 
			   bmp.h, 
			   0);
			}
		}

	override void draw(viewport_t v)
		{
		al_draw_tinted_bitmap(bmp,
			ALLEGRO_COLOR(1.0, 1.0, 1.0, 1.0),
			x - v.ox + v.x - bmp.w/2, 
			y - v.oy + v.y - bmp.h/2, 
			0);			
		
		drawShadow(v);
		
		draw_hp_bar(
			x - v.ox + v.x, 
			y - v.oy + v.y - bmp.w/2, 
			v, hp, 100);		
		}

	override void onTick()
		{
		}
	
	void actionSprint(){}
	void actionUse(){}
	}

class dwarf_t : unit_t
	{
	STATE state = STATE.WALKING;
	int state_delay = 0;
	item[] myInventory;
	bool hasSword = true;
	int direction = 0;
	int use_cooldown = 0;
	float stamina = 100f;
	immutable float SPRINT_SPEED = 4;

	this(float _x, float _y, float _xv, float _yv, ALLEGRO_BITMAP* b)
		{
		super(1, _x, _y, _xv, _yv, b);
		direction = 0;
		bmp = g.dude_up_bmp;
		}

	override void draw(viewport_t v)
		{
		super.draw(v);

		string text;
		text = to!string(state);
		
		al_draw_text(g.font, 
			ALLEGRO_COLOR(0, 0, 0, 1), 
			x - v.ox, 
			y - v.oy, 
			ALLEGRO_ALIGN_CENTER, 
			text.toStringz());
		}
	
	override void actionSprint() // FIX: How does spamming sprint quickly deplete our stamina if we can only start it with a full bar??  
		{
		sprintWasHeld = true;
		if(state == STATE.WALKING && stamina == 100)
			{
			state = STATE.SPRINTING;
			
			// up down left right
			if(direction == 0){vx = 0; vy = -SPRINT_SPEED;}
			if(direction == 1){vx = 0; vy = SPRINT_SPEED;}
			if(direction == 2){vx = -SPRINT_SPEED; vy = 0;}
			if(direction == 3){vx = SPRINT_SPEED; vy = 0;}
			}
		}

	override void actionUse() //does this need some sort of delay / anim delay / cooldown
		{
		if(use_cooldown == 0)
			{
			use_cooldown = 20;
			}else{
			writeln("use [cooldown] not ready!");
			return;
			}
		
		foreach(i; g.world.chests)
			{
			if(i.x < x + 16 && i.x > x - 16)
			if(i.x < x + 16 && i.x > x - 16)
			if(i.y < y + 16 && i.y > y - 16)
				{
				writeln("I'm opening a chest");
				i.onHit(this);
				return; 
				}
			}

		foreach(i; g.world.items)
			{
			if(i.isInside == false)
				if(i.x < x + 16 && i.x > x - 16)
				if(i.x < x + 16 && i.x > x - 16)
				if(i.y < y + 16 && i.y > y - 16)
					{
					writeln("I'm picking up an item");
					pickUp(i);
					return;
					//break; // lets only pick up one item at a time if it's for a USE key. [if it's "walk over" we'll pick up all of them--assuming we have room)
					// eventually: Clause for 'inventory too full'
					}
			}			
		}

	bool sprintWasHeld = false;

	override void onTick()
		{		
		if(use_cooldown > 0)use_cooldown--;
		if(stamina < 100)stamina++; // we penalize you for holding stamina even when it runs out by not giving you stamina, also so it doesn't keep repeating.
		if(stamina > 100)stamina = 100;
//		super.onTick();

		bool sprint2 = sprintWasHeld;
		sprintWasHeld = false;	// we need this wierdness to ensure it gets reset even if not during STATE.SPRINTING, but STATE.SPRINTING also needs to reset it.
		// we might be able to move the sprintwasheld = false to the bottom
		// BUT here's a problem! OTHER STATES can TERMINATE EARLY.
		// so AFTER_SWITCH_BLOCK() code never gets called.

		switch(state)
			{
			case STATE.WALKING:
//			x += vx;
//			y += vy;
			break;
			
			case STATE.SPRINTING:
			if(sprint2 == true && stamina >= 2.5)
				{
				stamina -= 2.5;
				attemptMoveRel(vx, vy);
				sprintWasHeld = false;
				}else{
				stamina = 0;
				state = STATE.WALKING;
				}
			break;
			
			case STATE.JUMPING:
			x += vx;
			y += vy;
			state_delay++;
			if(state_delay == 35) 
				{
				state_delay = 0;
				state = STATE.LANDING;
				writeln("switching to STATE.LANDING");
				}
			break;
			
			case STATE.LANDING: 	// Note: Our current jump is VELOCITY not DISTANCE based. Faster = further. Not faster to get same distance.
			state_delay++;
			if(state_delay == 20) 
				{
				state_delay = 0;
				state = STATE.WALKING;
				writeln("switching to STATE.WALKING");
				}
			break;
			case STATE.ATTACKING:
			state_delay++;
			if(state_delay == 20)
				{
				state_delay = 0;
				// DO ATTACK ON SPOT
				
				state = STATE.WALKING;
				writeln("switching to STATE.WALKING");
				
				if(hasSword)
					{
					writeln("ATTACKING with sword.");
					}else{
					writeln("NO sword.");
					return;
					}
				
				foreach(i; g.world.monsters)
					{
					if(i.x < x + 16 && i.x > x - 16)
					if(i.x < x + 16 && i.x > x - 16)
					if(i.y < y + 16 && i.y > y - 16)
						{
						writeln("I hit someone");
						i.onHit(this, 190);
//						return;  comment to allow hitting multiple here
						}
					}

				foreach(i; g.world.structures)
					{
					if(i.x < x + 16 && i.x > x - 16)
					if(i.x < x + 16 && i.x > x - 16)
					if(i.y < y + 16 && i.y > y - 16)
						{
						writeln("I hit a structure");
						i.onHit(this, 90);
//						return;  comment to allow hitting multiple here
						}
					}
				}
			break;		
			
			default:
			assert(0, "invalid state!"); 
			break;
			}
		}
		
	immutable float RUN_SPEED = 2.0f; 
	immutable float JUMP_SPEED = 4.0f; 

	override void up(){ if(state == STATE.WALKING){ direction=0; attemptMoveRel(0, -RUN_SPEED); bmp = g.dude_up_bmp;}}
	override void down() { if(state == STATE.WALKING){ direction=1; attemptMoveRel(0, RUN_SPEED); bmp = g.dude_down_bmp;}}
	override void left() { if(state == STATE.WALKING){ direction=2; attemptMoveRel(-RUN_SPEED,0); bmp = g.dude_left_bmp;}}
	override void right() { if(state == STATE.WALKING){ direction=3; attemptMoveRel(RUN_SPEED,0); bmp = g.dude_right_bmp;}}

	void pickUp(ref item i)
		{
		i.isInside = true;
		writeln("I picked ", i ," up. ", i);
		myInventory ~= i;
		if(i.bmp == g.sword_bmp)
			{
			hasSword = true;
			}
		}

	override void actionAttack()
		{
		if(state == STATE.WALKING)
			{
			if(hasSword && stamina > 50)
				{
				stamina -= 50;
				state = STATE.ATTACKING;
				writeln("switching to STATE.ATTACKING");
				}else{
				g.guis[0].setFlicker();
				}
			}
		}
	override void actionJump()
		{
		if(state == STATE.WALKING && stamina >= 50)
			{
			stamina -= 50;
			state = STATE.JUMPING;
			if(direction == 0){vx = 0; vy = -JUMP_SPEED;}
			if(direction == 1){vx = 0; vy =  JUMP_SPEED;}
			if(direction == 2){vx = -JUMP_SPEED; vy = 0;}
			if(direction == 3){vx =  JUMP_SPEED; vy = 0;}
			writeln("switching to STATE.JUMPING");
			}
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
		import g : TILE_W, TILE_H;
		if(hp <= 0)delete_me = true;
			
		if(
			world.map.data[cast(int)x/TILE_W][cast(int)y/TILE_H] == 0 || 
			world.map.data[cast(int)x/TILE_W][cast(int)y/TILE_H] == 4 ||
			world.map.data[cast(int)x/TILE_W][cast(int)y/TILE_H] == 5 
			) 
			{
			//
			}else{
			hp -= 5; // this goes at like 60 FPS!
			}
		}
	}

	
class dwarf_structure_t : structure_t
	{
	this(float x, float y)
		{
		super(x, y, g.fountain_bmp);
		team = 1;
		}
		
	override void onTick()
		{
		super.onTick(); // check if we're alive

		// Spawn dudes at rate
		countdown--;
		if(countdown == 0)
			{
			auto d = new dwarf_t(x, y, uniform!"[]"(-.5, .5), uniform!"[]"(-.5, .5), g.dwarf_bmp);
			world.units ~= d;
			countdown = countdown_rate;
			}			
		}
	}

class monster_structure_t : structure_t
	{
	this(float x, float y)
		{
		super(x, y, g.fountain_bmp);
		team = 2;
		}
		
	override void onTick()
		{
		super.onTick(); // check if we're alive

		// Spawn dudes at rate
		countdown--;
		if(countdown == 0)
			{
			auto d = new monster_t(x, y, uniform!"[]"(-.5, .5), uniform!"[]"(-.5, .5));
			world.monsters ~= d;
			countdown = countdown_rate;
			}			
		}
	}

class object_t
	{
	public:
	bool		delete_me = false;
	
	float 		x, y; 	/// Objects are centered at X/Y (not top-left) so we can easily follow other objects.
	float		vx, vy; /// Velocities.
	float		w, h;   /// width, height (does this make sense in here instead of drawable_object_t)

//	int direction; // see enum
//	float		angle; // instead of x_vel, y_vel?
//	float		vel;
//	int			w2, h2; //cached half width/height

// why would the NON drawable object have a draw call???
//	void draw(viewport_t v)
	//	{
		//}

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
	void actionAttack()
		{
		}
	void actionJump()
		{
		}
	void actionDodge()
		{
		}
	void click_at(float relative_x, float relative_y){} //maybe? relative to object coordinate.
	
	// EVENTS
	// ------------------------------------------
	void onTick()
		{
		}

	void on_collision(object_t other_obj)
		{
		}	
	}	
