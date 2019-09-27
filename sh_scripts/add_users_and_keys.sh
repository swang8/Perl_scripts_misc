## run this with root

# add a group: porecampusa, all will be in this group
groupadd porecampusa

wget download.txgen.tamu.edu/shichen/uploads/all.keys.txt

users=(shichenwang nickloman mickwatson joshquick mattloose)
for i in ${users[@]}; do
  echo "Creat user:" $i
  dir="/home/${i}"
  useradd -d $dir -g porecampusa -G users,admin -m -p porecampusa $i
  passwd ${i}
  mkdir /home/${i}/.ssh
  chown ${i}:porecampusa /home/${i}/.ssh
  chmod 750 /home/${i}/.ssh
  cp all.keys.txt /home/${i}/.ssh/authorized_keys
  chown -R ${i}:porecampusa /home/${i}/.ssh
  chmod 700 /home/${i}/.ssh/authorized_keys
done

## for students
useradd -d $dir -g porecampusa -G users,admin -m -p porecampusa  porecampusa
mkdir /home/porecampusa/.ssh
cp all.keys.txt /home/porecampusa/.ssh/authorized_keys
chown -R porecmapusa:porecampusa  /home/porecampusa/.ssh
chmod 700 /home/porecampusa/.ssh/authoorized_keys

