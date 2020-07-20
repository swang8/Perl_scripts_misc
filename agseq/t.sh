vcfs=($@);

unset vcfs[0]

echo ${vcfs[*]}

echo $(dirname $0)
