# find three newlines (or more) in code files indicating wasted space
# 	pcregrep - perl enhanced grep
# 		-M multiline
# 		-n write line number
echo "Searching for multiple consecutive newlines in source files."
echo "--------------------------------------------------------------------------"
pcregrep -nM '\n\n\n' ./src/*.d
echo
echo "Searching for closing curley brackets with extra space after them"
echo "--------------------------------------------------------------------------"
pcregrep -nM '}\n\n.*}' ./src/*.d
