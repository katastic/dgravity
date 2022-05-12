class viewport_t
	{
	/// Screen coordinates
	int x;
	int y;
	int w; /// viewport width
	int h; /// viewport height
	
	/// Camera position
	float ox; /// offset_x, how much scrolling. subtracted from drawing calls.
	float oy; /// offset_y
	float zoom = 1.0;
	
	int* screen_w; // mirror of g.screen_w 
	int* screen_h; // used anywhere?? are these even set or just left null right now?

	@disable this();

	this(int _x, int _y, int _w, int _h, float _ox, float _oy)
		{
		x = _x;
		y = _y;
		w = _w;
		h = _h;
		ox = _ox;
		oy = _oy;
		}
	}
