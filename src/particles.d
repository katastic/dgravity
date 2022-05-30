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
import planetsmod;

import std.stdio;
import std.math;
import std.random;

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
		float cx = x + v.x - v.ox;
		float cy = y + v.y - v.oy;
		float scaleX = (cast(float)lifetime/cast(float)maxLifetime) * b.w;
		float scaleY = (cast(float)lifetime/cast(float)maxLifetime) * b.h;

		if(cx > 0 && cx < SCREEN_W && cy > 0 && cy < SCREEN_H)
			al_draw_tinted_scaled_bitmap(b, c,
				0, 0, b.w, b.h,
				cx - b.w/2, cy - b.h/2, scaleX, scaleY, 
				rotation);
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
	
