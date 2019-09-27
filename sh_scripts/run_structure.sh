base="/home/shichen.wang/Tools/fastStructure"

 for k in `seq 1 5`
 do
 output='K'
 echo "python $base/structure.py -K $k --input=for_structure --output=$output"
 python $base/structure.py -K $k --input=for_structure --output=$output
 done

for k in `seq 3 5`
do
out="K$k"
python $base/distruct.py -K $k --input=K --output=$out --popfile=pop --title=$out
python $base/distruct.py -K $k --input=K --output=$out --popfile=acc --title=$out
done
