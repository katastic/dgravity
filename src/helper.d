import allegro5.allegro;
import allegro5.allegro_primitives;
import allegro5.allegro_image;
import allegro5.allegro_font;
import allegro5.allegro_ttf;
import allegro5.allegro_color;

import std.format;
import std.math;
import std.random;
import std.conv;
import viewportsmod;
import g;
import objects;

COLOR white = COLOR(1,1,1,1);
COLOR black = COLOR(0,0,0,1);
COLOR red   = COLOR(1,0,0,1);
COLOR green = COLOR(0,1,0,1);
COLOR blue  = COLOR(0,0,1,1);

//mixin template grey(T)(T w)
	//{
	//COLOR(w, w, w, 1);
	//}

/// TODO: NYI
/// give me the necessary velocity (vx,vy) for a object to orbit a planet at distance D
///
///		startAngle - the (radian) clock angle to start it at (0 = noon, +velocity = facing clockwise)
///
/// ALSO: Gravity Well orbits were likely hardcoded 'attachments' so they had no chance of falling.

pair giveStableOrbit(planet p, float velocity, float startAngle)  
	{
	return pair(0,0);
	}

// TODO: does this track viewport offset or not?!
void drawAngleHelper(baseObject o, viewport v, float angle, float distance, ALLEGRO_COLOR color)
	{
	float cx = cos(angle)*distance;
	float cy = sin(angle)*distance;
	al_draw_line(
		o.x + v.x - v.ox, 
		o.y + v.y - v.oy, 
		o.x + cx + v.x - v.ox, 
		o.y + cy + v.y - v.oy, 
		color, 1);
	}

/// indicator that DOESNT show distance, only direction
/// has a gap before the line starts
void drawPlanetHelper(baseObject o, planet p, viewport v) 
	{
	float angle = angleTo(p,o); //to P from O
	float gapLength = 40;
	float totalLength = 80;
	float cx = cos(angle)*(totalLength-gapLength);
	float cy = sin(angle)*(totalLength-gapLength);
	float cx2 = cos(angle)*(totalLength);
	float cy2 = sin(angle)*(totalLength);
	
	al_draw_line(
		o.x + cx + v.x - v.ox, 
		o.y + cy + v.y - v.oy, 
		o.x + cx2 + v.x - v.ox, 
		o.y + cy2 + v.y - v.oy, 
		COLOR(0,0,1,1), 
		1);
	}

float radToDeg(T)(T angle)
	{
	return angle/(2.0*PI)*360.0;
	}

float degToRad(T)(T angle)
	{
	return angle*(2.0*PI)/360.0;
	}
	
void testRad()
	{
	for(int i = 0; i < 10; i++)
		{
		double x = -2*PI -.5 + .1*i;
		writeln(x, " ", wrapRad(x));
		}
	}
	
T wrapRad(T)(T angle)
	{
	if(angle >= 0)
		angle = fmod(angle, 2.0*PI);
	else
		angle += 2.0*PI; // everyone does this. What if angle is more than 360 negative though?
			// it'll be wrong. though a few more "hits" though this function and it'll be fixed.
			// otherwise, we could do a while loop but is that slower even when we don't need it?
			// either find the answer or stop caring.
	
	////	writeln(fmod(angle, 2.0*PI).radToDeg);
	//while(angle > 2*PI)angle -= 2*PI;
	//while(angle < 0)angle += 2*PI;
	return angle;
	}

void wrapRadRef(T)(ref T angle)
	{
	angle = fmod(angle, 2.0*PI);
	}

/// angleTo:		angleTo (This FROM That)
///
/// Get angle to anything that has an x and y coordinate fields
/// 	Cleaner:	float angle = angleTo(this, g.world.units[0]);
///  	Verses :	float angle = atan2(y - g.world.units[0].y, x - g.world.units[0].x);
float angleTo(T, U)(T _this, U fromThat) 
	{
	return atan2(_this.y - fromThat.y, _this.x - fromThat.x);
	}

float angleDiff(T)(T _thisAngle, T toThatAngle)
	{
	return abs(_thisAngle - toThatAngle);
	}

float distanceTo(T, U)(T t, U u)
	{
	return sqrt((u.x - t.x)^^2 + (u.y - t.y)^^2);
	}
	
float distance(float x, float y)
	{
	return sqrt(x*x + y*y);
	}

/// 2D array width/height helpers
size_t w(T)(T[][] array2d)
	{
	array2d[0].length;
	}

/// Ditto
size_t h(T)(T[][] array2d)
	{
	array2d.length;
	}

//	writeln(array.length); // 10, h
//	writeln(array[0].length); // 5, w

// Graphical helper functions
//=============================================================================
/// For bitmap culling. Is this point inside the screen?
bool isInsideScreen(float x, float y, viewport v) 
	{
	if(x > 0 && x < v.w && y > 0 && y < v.h)
		{return true;} else{ return false;}
	}

/// Same as above but includes a bitmaps width/height instead of a single point
bool isWideInsideScreen(float x, float y, ALLEGRO_BITMAP* b, viewport v) 
	{
	if(x >= -b.w/2 && x - b.w/2 < v.w && y - b.h/2 >= -b.w/2 && y < v.h)
		{return true;} else{ return false;} //fixme
	}

/*
//inline this? or template...
void draw_target_dot(pair xy)
	{
	draw_target_dot(xy.x, xy.y);
	}
*/
void draw_target_dot(float x, float y)
	{
	draw_target_dot(to!(int)(x), to!(int)(y));
	}

void draw_target_dot(int x, int y)
	{
	al_draw_pixel(x + 0.5, y + 0.5, al_map_rgb(0,1,0));

	immutable r = 2; //radius
	al_draw_rectangle(x - r + 0.5f, y - r + 0.5f, x + r + 0.5f, y + r + 0.5f, al_map_rgb(0,1,0), 1);
	}

/// For each call, this increments and returns a new Y coordinate for lower text.
int textHelper(bool doReset=false)
	{
	static int number_of_entries = -1;
	
	number_of_entries++;
	immutable int text_height = 20;
	immutable int starting_height = 20;
	
	if(doReset)number_of_entries = 0;
	
	return starting_height + text_height*number_of_entries;
	}

void draw_hp_bar(float x, float y, viewport v, float hp, float max)
	{
	float _x = x;
	float _y = y - 10;
	float _hp = hp/max*20.0;

	if(hp != max)
		al_draw_filled_rectangle(
			_x - 20/2 + v.x - v.ox, 
			_y + v.y - v.oy, 
			_x + _hp/2  + v.x - v.ox, 
			_y + 5 + v.y - v.oy, 
			ALLEGRO_COLOR(1, 0, 0, 0.70));
	}

// Helper functions
//=============================================================================

bool percent(float chance)
	{
	return uniform!"[]"(0.0, 100.0) < chance;
	}

// TODO Fix naming conflict here. This series returns the value. The other works by 
// reference
/+
	capLow		(non-reference versions)
	
		capRefLow?	(reference versions)
		rCapLow	
		refCapLow
	
	
	also is cap ambiguous? I like that it's smaller than 'clamp'
		cap:
			verb
				2.provide a fitting climax or conclusion to.
+/

T capHigh(T)(T val, T max)
	{
	if(val > max)
		{
		return max;
		}else{
		return val;
		}
	}	
// Ditto.
T capLow(T)(T val, T max)
	{
	if(val < max)
		{
		return max;
		}else{
		return val;
		}
	}	
// Ditto.
T capBoth(T)(T val, T min, T max)
	{
	assert(min < max);
	if(val < max)
		{
		val = max;
		}
	if(val > min)
		{
		val = min;
		}
	return val;
	}	

// can't remember the best name for this. How about clampToMax? <-----
void clampHigh(T)(ref T val, T max)
	{
	if(val > max)
		{
		val = max;
		}
	}	

void clampLow(T)(ref T val, T min)
	{
	if(val < min)
		{
		val = min;
		}
	}	

void clampBoth(T)(ref T val, T min, T max)
	{
	assert(min < max);
	if(val < min)
		{
		val = min;
		}
	if(val > max)
		{
		val = max;
		}
	}	

// <------------ Duplicates??
void cap(T)(ref T val, T low, T high)
	{
	if(val < low){val = low; return;}
	if(val > high){val = high; return;}
	}

// Cap and return value.
// better name for this? 
pure T cap_ret(T)(T val, T low, T high)
	{
	if(val < low){val = low; return val;}
	if(val > high){val = high; return val;}
	return val;
	}

/// Font Height = Ascent + Descent
int h(const ALLEGRO_FONT *f)
	{
	return al_get_font_line_height(f);
	}

/// Font Ascent
int a(const ALLEGRO_FONT *f)
	{
	return al_get_font_ascent(f);
	}

/// Font Descent
int d(const ALLEGRO_FONT *f)
	{
	return al_get_font_descent(f);
	}

//helper functions using universal function call syntax.
/// Return BITMAP width
int w(ALLEGRO_BITMAP *b)
	{
	return al_get_bitmap_width(b);
	}
	
/// Return BITMAP height
int h(ALLEGRO_BITMAP *b)
	{
	return al_get_bitmap_height(b);
	}

/// Same as al_draw_bitmap but center the sprite
/// we can also chop off the last item.
/// we could also throw an assert!null in here but maybe not for performance reasons.
void al_draw_centered_bitmap(ALLEGRO_BITMAP* b, float x, float y, int flags=0)
	{
	al_draw_bitmap(b, x - b.w/2, y - b.h/2, flags);
	}
	
/// Set texture target back to normal (the screen)
void al_reset_target() 
	{
	al_set_target_backbuffer(al_get_current_display());
	}

/// draw scaled bitmap but with a scale factor (simpler than the allegro API version)
void al_draw_scaled_bitmap2(ALLEGRO_BITMAP *bitmap, float x, float y, float scaleX, float scaleY, int flags=0)
	{
	al_draw_scaled_bitmap(bitmap, 0, 0, bitmap.w, bitmap.h, x, y, bitmap.w * scaleX, bitmap.h * scaleY, flags);
	}

void al_draw_center_rotated_bitmap(BITMAP* bmp, float x, float y, float angle, int flags)
	{
	al_draw_rotated_bitmap(bmp, bmp.w/2, bmp.h/2, x, y, angle, flags);
	}

// you know, we could do some sort of scoped lambda like thing that auto resets the target
/*
	DAllegro might already have that somewhere...
	
	foo();
	al_target(my_bitmap)
		{
		al_clear_to_color(...);
		al_draw_filled_rectangle(...);
		} // calls al_reset_target at end
	bar();

	al_target would be a class
		this

*/
//ALLEGRO_BITMAP* target, 

void al_target2(ALLEGRO_BITMAP* target, scope void delegate() func)
	{
	al_set_target_bitmap(target);
	func();
	al_reset_target();
	}
	
import std.stdio;
void test2()
	{
	ALLEGRO_BITMAP* bmp;
	al_target2(bmp, { al_draw_pixel(5, 5, ALLEGRO_COLOR(1,1,1,1)); });
	}

struct al_target()
	{
	this(ALLEGRO_BITMAP* target)
		{
		al_set_target(target);
		}
		
		//wheres the middle???
		
	~this()
		{
		al_reset_target();
		}
	}

/// Print variablename = value
/// usage because of D oddness:    
/// writeval(var.stringof, var);
void writeval(T)(string x, T y) 
	{
	writeln(x, " = ", y);
	}

/// Load a font and verify we succeeded or cause an out-of-band error to occur.
FONT* getFont(string path, int size)
	{
	import std.string : toStringz;
	ALLEGRO_FONT* f = al_load_font(toStringz(path), size, 0);
	assert(f != null, format("ERROR: Failed to load font [%s]!", path));
	return f;
	}

/// Load a bitmap and verify we succeeded or cause an out-of-band error to occur.
ALLEGRO_BITMAP* getBitmap(string path)
	{
	import std.string : toStringz;
	ALLEGRO_BITMAP* bmp = al_load_bitmap(toStringz(path));
	assert(bmp != null, format("ERROR: Failed to load bitmap [%s]!", path));
	return bmp;
	}

/// ported Gourand shading Allegro 5 functions from my old forum post
/// 	https://www.allegro.cc/forums/thread/615262
/// Four point shading:
void al_draw_gouraud_bitmap(ALLEGRO_BITMAP* bmp, float x, float y, COLOR tl, COLOR tr, COLOR bl, COLOR br)
	{
	ALLEGRO_VERTEX[4] vtx;
	float w = bmp.w;
	float h = bmp.h;

	vtx[0].x = x;
	vtx[0].y = y;
	vtx[0].z = 0;
	vtx[0].color = tl;
	vtx[0].u = 0;
	vtx[0].v = 0;

	vtx[1].x = x + w;
	vtx[1].y = y;
	vtx[1].z = 0;
	vtx[1].color = tr;
	vtx[1].u = w;
	vtx[1].v = 0;

	vtx[2].x = x + w;
	vtx[2].y = y + h;
	vtx[2].z = 0;
	vtx[2].color = br;
	vtx[2].u = w;
	vtx[2].v = h;

	vtx[3].x = x;
	vtx[3].y = y + h;
	vtx[3].z = 0;
	vtx[3].color = bl;
	vtx[3].u = 0;
	vtx[3].v = h;

	al_draw_prim(cast(void*)vtx, null, bmp, 0, vtx.length, ALLEGRO_PRIM_TYPE.ALLEGRO_PRIM_TRIANGLE_FAN);
	}

/// Five points (includes center)
void al_draw_gouraud_bitmap_5pt(ALLEGRO_BITMAP* bmp, float x, float y, COLOR tl, COLOR tr, COLOR bl, COLOR br, COLOR mid)
	{
	ALLEGRO_VERTEX[6] vtx;
	float w = bmp.w;
	float h = bmp.h;

	//center
	vtx[0].x = x + w/2;
	vtx[0].y = y + h/2;
	vtx[0].z = 0;
	vtx[0].color = mid;
	vtx[0].u = w/2;
	vtx[0].v = h/2;

	vtx[1].x = x;
	vtx[1].y = y;
	vtx[1].z = 0;
	vtx[1].color = tl;
	vtx[1].u = 0;
	vtx[1].v = 0;

	vtx[2].x = x + w;
	vtx[2].y = y;
	vtx[2].z = 0;
	vtx[2].color = tr;
	vtx[2].u = w;
	vtx[2].v = 0;

	vtx[3].x = x + w;
	vtx[3].y = y + h;
	vtx[3].z = 0;
	vtx[3].color = br;
	vtx[3].u = w;
	vtx[3].v = h;

	vtx[4].x = x;
	vtx[4].y = y + h;
	vtx[4].z = 0;
	vtx[4].color = bl;
	vtx[4].u = 0;
	vtx[4].v = h;

	vtx[5].x = vtx[1].x; //end where we started.
	vtx[5].y = vtx[1].y;
	vtx[5].z = vtx[1].z;
	vtx[5].color = vtx[1].color;
	vtx[5].u = vtx[1].u;
	vtx[5].v = vtx[1].v;

	al_draw_prim(cast(void*)vtx, null, bmp, 0, vtx.length, ALLEGRO_PRIM_TYPE.ALLEGRO_PRIM_TRIANGLE_FAN);
	}
	
	
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

/// al_draw_line_segment 1D
void al_draw_scaled_indexed_line_segment(T)(pair xycoord, T[] y, float yScale, COLOR color, float thickness, int index, COLOR indexColor)
	{
	assert(y.length > 1);

	for(int i = 1; i < y.length; i++) // note i = 1
		{
		if(i == index)
			{
			al_draw_line(
				xycoord.x + i, 
				xycoord.y + y[i]*yScale, 
				xycoord.x + i-1, 
				xycoord.y + y[i-1]*yScale, 
				indexColor, thickness*2);
			}else{
			al_draw_line(
				xycoord.x + i, 
				xycoord.y + y[i]*yScale, 
				xycoord.x + i-1, 
				xycoord.y + y[i-1]*yScale, 
				color, thickness);
			}
		}
	}
