# dGravity

![screenshot](/screen.png?raw=true "Screenshot")

--- Building Instructions ---

 - use ./godmd (for DMD) or ./goldc for LDC2 and then run ./main
 - use ./godmd2 (will dump to a temporary directory) and run. Makes it harder to run gdb after though.

	"go"	don't use this, it's a WIP, not working.
	"goprofdmd"		godmd with garbage collection profiling turned on then run ./view
	"run_with_core_dump" self-explainatory
			
Other stuff:
	findspace.sh	- find extra white space in code files
	scan			- runs dscanner static analyzer
	deb				- run gdb on main
	
