# use dockerimage
species=(cognatus cuneatus tasmanicus tristis usitatus)
base="/home/shichen.wang/Tools/fastStructure"
for spe in ${species[@]}; do
	for k in `seq 1 10`
	do
	  output=${spe}_K$k
	  docker run -t -v /data4/.shichen/Hojun/17127Son/Quality_Filtered/KOS_separate_species:/home faststruc "cd /home && python /fastStructure/structure.py -K $k --input=$spe --output=$output"
	done
	
       for k in `seq 1 10`
       do
         out="${spe}_K$k"
         python $base/distruct.py -K $k --input=${spe}_K$k --output=$out --title=$out --popfile=${spe}.location.pop
       done
done
