import allegro5.allegro;
import allegro5.allegro_primitives;
import allegro5.allegro_image;
import allegro5.allegro_font;
import allegro5.allegro_ttf;
import allegro5.allegro_color;

import std.json;
import std.conv;
import std.random;
import std.file;
import std.stdio;

import helper;
import g;
import viewport;

class map_t
	{
	immutable uint w = 50;
	immutable uint h = 50;

	tile[w][h] data;
	tile[w][h] data2;
	
	this()
		{
		load("world.map");
		}
	
	void draw(viewport_t v, bool drawTopLayer)
		{
		import std.math;
		import g : TILE_W, TILE_H;
		long signed_start_i = cast(long) ((v.ox)/TILE_W)-1; //need signed to allow for negative
		long signed_start_j = cast(long) ((v.oy)/TILE_H)-1;
		uint start_i=0;
		uint start_j=0;
		uint end_i = cast(uint) ((v.w + v.ox + v.x)/TILE_W)+1; // v.ox should be negative shouldn't it??sd
		uint end_j = cast(uint) ((v.h + v.oy + v.y)/TILE_H)+1;

		if(signed_start_i < 0){start_i = 0;}else{start_i = to!uint(signed_start_i);}
		if(signed_start_j < 0){start_j = 0;}else{start_j = to!uint(signed_start_j);}
		end_i.clampHigh(w-1);
		end_j.clampHigh(h-1);
		
//		writeln("start:", start_i, "/", start_j, " offset", v.ox, "/" , v.oy, " = end: ", end_i, "/",end_j);				
		if(!drawTopLayer)
			{
			for(uint i = cast(uint) start_i; i < end_i; i++)
			for(uint j = cast(uint) start_j; j < end_j; j++)
				{
				ushort index = data[i][j];
				assert(index >= 0);
				assert(index < 400);
				auto p = pair(i*TILE_W, j*TILE_H);
				float d = distanceTo(p, g.lights[0]); // holy crap. We just compared a pair, to a light object
				
				d /= 500; // Lower means darker quicker (lower radius/sharper transition)
//				writeln(d, " ", i, " ", j);
				d.clampBoth(0, 1.0);
				auto c = COLOR(1.0 - d,1.0 - d,1.0 - d,1.0);
				al_draw_tinted_bitmap(g.atlas1[index], c, v.x + i*TILE_W - v.ox, v.y + j*TILE_H - v.oy, 0);
				stats.number_of_drawn_background_tiles++;
				}
			}
		
		if(drawTopLayer)
			{
			for(uint i = cast(uint) start_i; i < end_i; i++)
			for(uint j = cast(uint) start_j; j < end_j; j++)
				{
				ushort index = data2[i][j];
				if(index == 0)continue; // skip blank first tile
				assert(index >= 0);
				assert(index < 400);
				al_draw_bitmap(g.atlas2[index], v.x + i*TILE_W - v.ox, v.y + j*TILE_H - v.oy, 0);
				stats.number_of_drawn_background_tiles++;
				}
			}
		}

	int frames_passed=0;
	
	void logic()
		{
		return;
//		if(frames_passed > 60){fluid_logic(); frames_passed=0;}
//		frames_passed++;
		}
		
	void fluid_logic() /// Called at different tick rate
		{
		auto old = data.dup;
		
		// NOTE, due to the order of precedence, lava "wins" against water if there's an available tile.
			
		// ideally we need to double-buffer/page flip the MAP
		// so we can make DECISIONS based on last frames map, and its EFFECTS apply 
		// the NEW frames map. Otherwise, we risk mutating WHILE we iterating and 
		// having changes cascade / explode.
		
		// note we're currently DUPLICATING the map every frame as opposed to flipping
		// so this is allocating every frame instead of swapping between two buffers (read: SLOW)

		/// spread fluid of [TYPE] out one tile into grass		
		void spread(ubyte TYPE)
			{
			for(int i = 0; i < w; i++)
				for(int j = 0; j < h; j++)
					{
					if(old[i][j] == TYPE)
						{
						if(i > 0 && old[i-1][j] == 0)
							{
							data[i-1][j] = TYPE;
							}
						if(j > 0 && old[i][j-1] == 0)
							{
							data[i][j-1] = TYPE;
							}
						if(i < w-1 && old[i+1][j] == 0)
							{
							data[i+1][j] = TYPE;
							}
						if(j < h-1 && old[i][j+1] == 0)
							{
							data[i][j+1] = TYPE;
							}
						}
					}
			}

		/// spread fluid of [TYPE] out one tile into grass, and occasionally "burn" wood bridges
		void spread_and_burn(ubyte TYPE) 
			{
			for(int i = 0; i < w; i++)
				for(int j = 0; j < h; j++)
					{
					if(old[i][j] == TYPE)
						{
						// Spread into grass:
						if(i > 0 && old[i-1][j] == 0)
							{
							data[i-1][j] = TYPE;
							}
						if(j > 0 && old[i][j-1] == 0)
							{
							data[i][j-1] = TYPE;
							}
						if(i < w-1 && old[i+1][j] == 0)
							{
							data[i+1][j] = TYPE;
							}
						if(j < h-1 && old[i][j+1] == 0)
							{
							data[i][j+1] = TYPE;
							}

						// Spread into wood (4):
						immutable float chance = 5.0; 
						//NOTE. THIS only fires off ONCE A SECOND. So it's 1/60th of the normal tick rate for percentages for the objects!
						if(i > 0 && old[i-1][j] == 4 && percent(chance))
							{
							data[i-1][j] = TYPE;
							}
						if(j > 0 && old[i][j-1] == 4 && percent(chance))
							{
							data[i][j-1] = TYPE;
							}
						if(i < w-1 && old[i+1][j] == 4 && percent(chance))
							{
							data[i+1][j] = TYPE;
							}
						if(j < h-1 && old[i][j+1] == 4 && percent(chance))
							{
							data[i][j+1] = TYPE;
							}
						}
					}
			}
			
		spread(2);
		spread_and_burn(3);	
		}
		
	//https://forum.dlang.org/post/t3ljgm$16du$1@digitalmars.com
	//big 'ol wtf case.
	void rawWriteValue(T)(File file, T value)
		{
		file.rawWrite((&value)[0..1]); // should this be 0..3?
		}

	JSONValue map_in_json_format;

	void save(string path="world.map")
		{
		writeln("save map");
		import std.json;
		import std.file;
		File f = File("./data/maps/map.map", "w");
		
		map_in_json_format.object["width"] = 50;
		map_in_json_format.object["height"] = 50;
		map_in_json_format.object["layer0"] = JSONValue( data ); 
		map_in_json_format.object["layer1"] = JSONValue( data2 ); 

		f.write(map_in_json_format.toJSON(false));
		f.close();

//		auto f = File(path, "w");
//		rawWriteValue(f, data);
//		writeln("SAVING MAP");
		//https://forum.dlang.org/post/mailman.113.1330209587.24984.digitalmars-d-learn@puremagic.com
		}

	void load(string path="world.map")
		{
		writeln("load map");
		string str = std.file.readText("./data/maps/map.map");
		//writeln(str);
		map_in_json_format = parseJSON(str);
//		writeln(map_in_json_format);

		auto t = map_in_json_format;

		int width = to!int(t.object["width"].integer);
		int height = to!int(t.object["height"].integer);
		writeln(width, " by ", height);
	
		foreach(size_t j, ref r; t.object["layer0"].array)
			{
			foreach(size_t i, ref val; r.array)
				{
				data[j][i] = to!ushort(val.integer); //"integer" outs long. lulbbq.
				}
			}
		foreach(size_t j, ref r; t.object["layer1"].array)
			{
			foreach(size_t i, ref val; r.array)
				{
				data2[j][i] = to!ushort(val.integer); //"integer" outs long. lulbbq.
				}
			}
			
//		writeln("LOADING MAP");
//		auto read = File(path).rawRead(data[]);
		}

	}	
