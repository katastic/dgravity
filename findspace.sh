# find three newlines (or more) in code files indicating wasted space
# 	pcregrep - perl enhanced grep
# 		-M multiline
# 		-n write line number
echo "Searching for multiple consecutive newlines in source files."
pcregrep -nM '\n\n\n' ./src/*.d
