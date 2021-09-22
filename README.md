# vep

## Prerequisites
The script will check for the following prerequisites.

### Linux tools
- wget 
- tar 
- docker 
- pgrep 
- gzip 
- bgzip (tabix on debian based linux distributions)

### Disk space
At least 30GB of disk space are required.

## Instructions (initial setup)
The script can be used without root rights. I would highly recommend this!

### Add your vep user to the docker group
`sudo usermod -a -G docker $(whoami)`

### Clone the git repository
`git clone https://github.com/overathm/vep`

### Make the script executable
`chmod +x Run_VEP_batch.sh`

### Execute the script
`./Run_VEP_batch.sh`


## Cron Job
After the initial setup the script will be executed hourly through the cron facilities.


mo
