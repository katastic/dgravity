// GLOBAL CONSTANTS
// =============================================================================
immutable bool DEBUG_NO_BACKGROUND = false; /// No graphical background so we draw a solid clear color. Does this do anything anymore?

// =============================================================================

import std.stdio;
import std.conv;
import std.string;
import std.format;
import std.random;
import std.algorithm;
import std.traits; // EnumMembers
import std.datetime;
import std.datetime.stopwatch : benchmark, StopWatch, AutoStart;
//thread yielding?
//-------------------------------------------
//import core.thread; //for yield... maybe?
//extern (C) int pthread_yield(); //does this ... work? No errors yet I can't tell if it changes anything...
//------------------------------

pragma(lib, "dallegro5ldc");

version(ALLEGRO_NO_PRAGMA_LIB){}else{
	pragma(lib, "allegro");
	pragma(lib, "allegro_primitives");
	pragma(lib, "allegro_image");
	pragma(lib, "allegro_font");
	pragma(lib, "allegro_ttf");
	pragma(lib, "allegro_color");
}

import allegro5.allegro;
import allegro5.allegro_primitives;
import allegro5.allegro_image;
import allegro5.allegro_font;
import allegro5.allegro_ttf;
import allegro5.allegro_color;

import helper;
import objects;
import viewportsmod;
static import g;
import g : queue, al_display, fps_timer, screencap_timer;

display_t display;

//=============================================================================

//https://www.allegro.cc/manual/5/keyboard.html
//	(instead of individual KEYS touching ANY OBJECT METHOD. Because what if we 
// 		change objects? We have to FIND all keys associated with that object and 
// 		change them.)
alias ALLEGRO_KEY = ubyte;
struct keyset_t
		{
		baseObject obj;
		ALLEGRO_KEY [ __traits(allMembers, keys_label).length] key;
		// If we support MOUSE clicks, we could simply attach a MOUSE in here 
		// and have it forward to the object's click_on() method.
		// But again, that kills the idea of multiplayer.
		}
		
enum keys_label
	{
	ERROR = 0,
	UP_KEY,
	DOWN_KEY,
	LEFT_KEY,
	RIGHT_KEY,
	FIRE_UP_KEY,
	FIRE_DOWN_KEY,
	FIRE_LEFT_KEY,
	FIRE_RIGHT_KEY,
	ACTION_KEY
	}

bool initialize()
	{
	al_set_config_value(al_get_system_config(), "trace", "level", "info"); // enable logging. see https://github.com/liballeg/allegro5/issues/1339
	// "debug"
	if (!al_init())
		{
		auto ver 		= al_get_allegro_version();
		auto major 		= ver >> 24;
		auto minor 		= (ver >> 16) & 255;
		auto revision 	= (ver >> 8) & 255;
		auto release 	= ver & 255;

		writefln("The system Allegro version (%s.%s.%s.%s) does not match the version of this binding (%s.%s.%s.%s)",
			major, minor, revision, release,
			ALLEGRO_VERSION, ALLEGRO_SUB_VERSION, ALLEGRO_WIP_VERSION, ALLEGRO_RELEASE_NUMBER);

		assert(0, "The system Allegro version does not match the version of this binding!");
		}else{
				writefln("The Allegro version (%s.%s.%s.%s)",
			ALLEGRO_VERSION, ALLEGRO_SUB_VERSION, ALLEGRO_WIP_VERSION, ALLEGRO_RELEASE_NUMBER);
		}
	
static if (false) // MULTISAMPLING. Not sure if helpful.
	{
	with (ALLEGRO_DISPLAY_OPTIONS)
		{
		al_set_new_display_option(ALLEGRO_SAMPLE_BUFFERS, 1, ALLEGRO_REQUIRE);
		al_set_new_display_option(ALLEGRO_SAMPLES, 8, ALLEGRO_REQUIRE);
		}
	}

	al_display 	= al_create_display(g.SCREEN_W, g.SCREEN_H);
	queue		= al_create_event_queue();

	if (!al_install_keyboard())      assert(0, "al_install_keyboard failed!");
	if (!al_install_mouse())         assert(0, "al_install_mouse failed!");
	if (!al_init_image_addon())      assert(0, "al_init_image_addon failed!");
	if (!al_init_font_addon())       assert(0, "al_init_font_addon failed!");
	if (!al_init_ttf_addon())        assert(0, "al_init_ttf_addon failed!");
	if (!al_init_primitives_addon()) assert(0, "al_init_primitives_addon failed!");

	al_register_event_source(queue, al_get_display_event_source(al_display));
	al_register_event_source(queue, al_get_keyboard_event_source());
	al_register_event_source(queue, al_get_mouse_event_source());
	
	with(ALLEGRO_BLEND_MODE)
		{
		al_set_blender(ALLEGRO_BLEND_OPERATIONS.ALLEGRO_ADD, ALLEGRO_ALPHA, ALLEGRO_INVERSE_ALPHA);
		}
				
	// load animations/etc
	// --------------------------------------------------------
	g.loadResources();

	// SETUP viewports
	// --------------------------------------------------------
	g.viewports[0] = new viewport(0, 0, g.SCREEN_W, g.SCREEN_H, 0, 0);

	// SETUP world
	// --------------------------------------------------------
	g.world = new g.world_t;
	
	// FPS Handling
	// --------------------------------------------------------
	fps_timer 		= al_create_timer(1.0f);
	screencap_timer = al_create_timer(5.0f);
	al_register_event_source(queue, al_get_timer_event_source(fps_timer));
	al_register_event_source(queue, al_get_timer_event_source(screencap_timer));
	al_start_timer(fps_timer);
	al_start_timer(screencap_timer);
	
	return 0;
	}
	
struct display_t
	{
	void start_frame()	
		{
		g.stats.reset();
		reset_clipping(); //why would we need this? One possible is below! To clear to color the whole screen!
//		al_clear_to_color(ALLEGRO_COLOR(.2,.2,.2,1)); //only needed if we aren't drawing a background
		}
		
	void end_frame()
		{	
		al_flip_display();
		}

	void draw_frame()
		{
		start_frame();
		//------------------
		draw2();
		//------------------
		end_frame();
		}

	void reset_clipping()
		{
		al_set_clipping_rectangle(0, 0, g.SCREEN_W-1, g.SCREEN_H-1);
		}
		
	void draw2()
		{
		
	static if(true) //draw left viewport
		{
		al_set_clipping_rectangle(
			g.viewports[0].x, 
			g.viewports[0].y, 
			g.viewports[0].x + g.viewports[0].w ,  //-1
			g.viewports[0].y + g.viewports[0].h); //-1
		
		static if(DEBUG_NO_BACKGROUND)
			al_clear_to_color(ALLEGRO_COLOR(0, 0, 0, 1));
		
		g.world.draw(g.viewports[0]);
		}

	static if(false) //draw right viewport
		{
		al_set_clipping_rectangle(
			g.viewports[1].x, 
			g.viewports[1].y, 
			g.viewports[1].x + g.viewports[1].w  - 1, 
			g.viewports[1].y + g.viewports[1].h - 1);

		static if(DEBUG_NO_BACKGROUND)
			al_clear_to_color(ALLEGRO_COLOR(.8,.7,.7, 1));

		g.world.draw(g.viewports[1]);
		}
		
		//Viewport separator
	static if(false)
		{
		al_draw_line(
			g.SCREEN_W/2 + 0.5, 
			0 + 0.5, 
			g.SCREEN_W/2 + 0.5, 
			g.SCREEN_H + 0.5,
			al_map_rgb(0,0,0), 
			10);
		}
		
		// Draw FPS and other text
		display.reset_clipping();
		al_draw_filled_rounded_rectangle(16, 32, 64+650, 105+32, 8, 8, ALLEGRO_COLOR(.7, .7, .7, .7));

		unit u = g.world.units[0];
		drawText2(20, "obj[%.2f,%.2f][%.2f %f.2] %.2f deg", u.x, u.y, u.vx, u.vy, u.angle.radToDeg);
		drawText2(20, "fps[%d] objrate[%d]", g.stats.fps, 
					(g.stats.number_of_drawn_particles +
					g.stats.number_of_drawn_units + 
					g.stats.number_of_drawn_particles + 
					g.stats.number_of_drawn_structures) * g.stats.fps ); 
		
//		drawText2(20, "money [%d] deaths [%d]", g.world.players[0].myTeamIndex.money, g.world.players[0].deaths);
		drawText2(20, "drawn: structs [%d] bg_tiles [%d] particles [%d] units [%d]", 
			g.stats.number_of_drawn_structures, 
			g.stats.number_of_drawn_background_tiles, 
			g.stats.number_of_drawn_particles,
			g.stats.number_of_drawn_units);
			
		textHelper(true);  //reset
		
		draw_target_dot(g.mouse_x, g.mouse_y);		// DRAW MOUSE PIXEL HELPER/FINDER

/*
		int val = -1;
		int mouse_xi = (g.mouse_x + cast(int)g.viewports[0].ox + cast(int)g.viewports[0].x)/TILE_W;
		int mouse_yi = (g.mouse_y + cast(int)g.viewports[0].oy + cast(int)g.viewports[0].x)/TILE_H;
		if(mouse_xi >= 0 && mouse_yi >= 0
			&& mouse_xi < 50 && mouse_yi < 50)
			{
			}
*/			
		al_draw_textf(
			g.font1, 
			ALLEGRO_COLOR(0, 0, 0, 1), 
			g.mouse_x, 
			g.mouse_y - 30, 
			ALLEGRO_ALIGN_CENTER, "mouse [%d, %d]", g.mouse_x, g.mouse_y);
		}
	}

void logic()
	{
	g.world.logic();
	}

/// This function corrects a bug/error/oversight in al_save_bitmap that dumps ALPHA channel from the screen into the picture
///
void al_save_screen(string path)
	{
	auto sw = StopWatch(AutoStart.yes);
	auto disp = al_get_backbuffer(al_display);
	auto w = disp.w;
	auto h = disp.h;
	ALLEGRO_BITMAP* temp = al_create_bitmap(w, h);
	al_lock_bitmap(temp, al_get_bitmap_format(temp), ALLEGRO_LOCK_WRITEONLY);
	al_lock_bitmap(disp, al_get_bitmap_format(temp), ALLEGRO_LOCK_READONLY); // makes HUGE difference (6.4 seconds vs 270 milliseconds)
	al_set_target_bitmap(temp);
//	al_clear_to_color(ALLEGRO_COLOR(0,0,0,1));
//	al_draw_bitmap(disp, 0, 0, 0);
	for(int j = 0; j < h; j++)
		for(int i = 0; i < w; i++)
			{
			auto pixel = al_get_pixel(disp, i, j);
			pixel.a = 1.0; // remove alpha
			al_put_pixel(i, j, pixel);
			}
	al_unlock_bitmap(disp);
	al_unlock_bitmap(temp);
	al_save_bitmap(path.toStringz, temp);
	al_reset_target();
	al_destroy_bitmap(temp);
	
	sw.stop();
	int secs, msecs;
	sw.peek.split!("seconds", "msecs")(secs, msecs);
	writefln("Saving screenshot took %d.%ds", secs, msecs);
	}

void execute()
	{
	ALLEGRO_EVENT event;
		
	bool isKey(ALLEGRO_KEY key)
		{
		// captures: event.keyboard.keycode
		return (event.keyboard.keycode == key);
		}

	void isKeySet(ALLEGRO_KEY key, ref bool setKey)
		{
		// captures: event.keyboard.keycode
		if(event.keyboard.keycode == key)
			{
			setKey = true;
			}
		}
	void isKeyRel(ALLEGRO_KEY key, ref bool setKey)
		{
		// captures: event.keyboard.keycode
		if(event.keyboard.keycode == key)
			{
			setKey = false;
			}
		}
		
	bool exit = false;
	while(!exit)
		{
		while(al_get_next_event(queue, &event))
			{
			switch(event.type)
				{
				case ALLEGRO_EVENT_DISPLAY_CLOSE:
					{
					exit = true;
					break;
					}
				case ALLEGRO_EVENT_KEY_DOWN:
					{
					isKeySet(ALLEGRO_KEY_ESCAPE, exit);

					isKeySet(ALLEGRO_KEY_SPACE, g.key_space_down);
					isKeySet(ALLEGRO_KEY_W, g.key_w_down);
					isKeySet(ALLEGRO_KEY_S, g.key_s_down);
					isKeySet(ALLEGRO_KEY_A, g.key_a_down);
					isKeySet(ALLEGRO_KEY_D, g.key_d_down);		

					isKeySet(ALLEGRO_KEY_M, g.key_m_down);
					isKeySet(ALLEGRO_KEY_I, g.key_i_down);
					isKeySet(ALLEGRO_KEY_J, g.key_j_down);
					isKeySet(ALLEGRO_KEY_K, g.key_k_down);
					isKeySet(ALLEGRO_KEY_L, g.key_l_down);
					isKeySet(ALLEGRO_KEY_Q, g.key_q_down);
					break;
					}
					
				case ALLEGRO_EVENT_KEY_UP:				
					{
					isKeyRel(ALLEGRO_KEY_SPACE, g.key_space_down);
					isKeyRel(ALLEGRO_KEY_W, g.key_w_down);
					isKeyRel(ALLEGRO_KEY_S, g.key_s_down);
					isKeyRel(ALLEGRO_KEY_A, g.key_a_down);
					isKeyRel(ALLEGRO_KEY_D, g.key_d_down);

					isKeyRel(ALLEGRO_KEY_M, g.key_m_down);
					isKeyRel(ALLEGRO_KEY_I, g.key_i_down);
					isKeyRel(ALLEGRO_KEY_J, g.key_j_down);
					isKeyRel(ALLEGRO_KEY_K, g.key_k_down);
					isKeyRel(ALLEGRO_KEY_L, g.key_l_down);
					isKeyRel(ALLEGRO_KEY_Q, g.key_q_down);
					break;
					}

				case ALLEGRO_EVENT_MOUSE_AXES:
					{
					g.mouse_x = event.mouse.x;
					g.mouse_y = event.mouse.y;
					g.mouse_in_window = true;
					break;
					}

				case ALLEGRO_EVENT_MOUSE_ENTER_DISPLAY:
					{
					writeln("mouse enters window");
					g.mouse_in_window = true;
					break;
					}
				
				case ALLEGRO_EVENT_MOUSE_LEAVE_DISPLAY:
					{
					writeln("mouse left window");
					g.mouse_in_window = false;
					break;
					}

				case ALLEGRO_EVENT_MOUSE_BUTTON_DOWN:
					{
					if(!g.mouse_in_window)break;
					
					if(event.mouse.button == 1)
						{
						}
					if(event.mouse.button == 2)
						{
						}
					break;
					}
				
				case ALLEGRO_EVENT_MOUSE_BUTTON_UP:
					{
					g.mouse_lmb = false;
					break;
					}
				
				case ALLEGRO_EVENT_TIMER:
					{
					if(event.timer.source == screencap_timer)
						{
						al_stop_timer(screencap_timer); // Do this FIRST so inner code cannot take so long as to re-trigger timers.
						writeln("saving screenshot [screen.png]");
						al_save_screen("screen.png");	
//	auto sw = StopWatch(AutoStart.yes);
//						al_save_bitmap("screen.png", al_get_backbuffer(al_display));
//				sw.stop();
//	int secs, msecs;
//	sw.peek.split!("seconds", "msecs")(secs, msecs);
//	writefln("Saving screenshot took %d.%ds", secs, msecs);
			}						
					if(event.timer.source == fps_timer) //ONCE per second
						{
						g.stats.fps = g.stats.frames_passed;
						g.stats.frames_passed = 0;
						}
					break;
					}
				default:
				}
			}

		logic();
		display.draw_frame();
		g.stats.frames_passed++;
//		Fiber.yield();  // THIS SEGFAULTS. I don't think this does what I thought.
//		pthread_yield(); //doesn't seem to change anything useful here. Are we already VSYNC limited to 60 FPS?
		}
	}

void shutdown() 
	{
		
	}
	
void runAllegroTest()
	{
	unit[] units;
	units ~= new ship(0, 0, 1, 1);
	units ~= new freighter(0, 0, 1, 1);
	
	ship s0 = cast(ship)units[0];
	ship s1 = cast(ship)units[1];
	
	writeln(s0 is null);
	writeln(s1 is null);
	writeln(s0.classinfo);
	writeln(s1.classinfo);
	writeln(s0 == s1);
	writeln(s0 is s1);
	
	ship refs1 = s0;
	writeln(s0 is refs1);
	}

void setupFloatingPoint()
	{
	import std.math.hardware;
	FloatingPointControl fpctrl;
    fpctrl.enableExceptions(FloatingPointControl.severeExceptions);
	// enables hardware trap exceptions on uninitialized floats (NaN), (I would imagine) division by zero, etc.
	// see 
	// 		https://dlang.org/library/std/math/hardware/floating_point_control.html
	// we could disable this on [release] mode if necessary for performance
	}

//=============================================================================
int main(string [] args)
	{
	setupFloatingPoint();	
	writeln("args length = ", args.length);
	foreach(size_t i, string arg; args)
		{
		writeln("[",i, "] ", arg);
		}
		
	if(args.length > 2)
		{
		g.SCREEN_W = to!int(args[1]);
		g.SCREEN_H = to!int(args[2]);
		writeln("New resolution is ", g.SCREEN_W, "x", g.SCREEN_H);
		}

	return al_run_allegro(
		{
		initialize();
		execute();
		runAllegroTest();
		shutdown();
		return 0;
		});


	return 0;
	}
