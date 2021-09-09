# vep

Instructions:
the script can be used without root rights. I would also highly recommend this. the user just has to be added to the docker group first with:
sudo usermod -a -G docker $(whoami)

make a new folder:
mkdir foldername

copy the script into that folder:
https://github.com/overathm/vep

make the script executable:
chmod +x Run_VEP_batch_v0_5.sh

and execute it with:
./Run_VEP_batch_v0_5.sh

After that the script will be executed hourly.

The following programmes are required:
wget tar docker pgrep gzip bgzip
and at least 30GB of memory is required.
However, the progam indicates that there is not enough memory and that programs are not installed.