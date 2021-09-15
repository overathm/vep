#!/bin/bash

#The idea would be to go through the input folder and fetch the .vcf files to be annotated by VEP, as disscused, important would be
#that the files who were already analyzed are renamed or moved to a different location to avoid reanalysis

#here be dragons! Don't change anything!
#variable that specifies the time how long files have to remain in the input folder
waitperiod=5
#name of the directories which we will need
dir=(input output reference archive archive/logs)
needed_commands=(wget tar docker pgrep gzip bgzip )
#name of reference file
refseq="homo_sapiens_refseq_vep_104_GRCh37"
#name of the fasta file
fasta="Homo_sapiens.GRCh37.dna.primary_assembly"
#name of docker container
docker_name="vep_nngm"
#dir of mounting
mount_dir="/opt/vep/.vep"
#name of the script
scriptname=$(basename "$0")

#check if the user have the correct permissions
if [ $(groups $(whoami) | grep  'docker'|wc -l)  -eq 0 ];then
  if [ $(id -u) -ne 0 ];then
   printf "ERROR: You are not in the docker group, nor are you running this program with root privileges!!!!\nto add yourself to the docker group you can execute the following command:\nusermod -a -G docker $(whoami).\nEXIT\n"
  exit
  fi
fi

#check if all programs are installed
for i in "${needed_commands[@]}";do
  if ! command -v $i &> /dev/null
    then
      printf "command $i could not be found, please install\nEXIT!\n"
      exit
  fi
done

#check if docker is running
if [ $(systemctl is-active docker) == "active" ];then
    printf "docker is installed and running\n"
else
    printf  "ERROR: docker is not running, please check!\n EXIT!!!\n"
    exit
fi

#check if all directories exist otherwise they will be created
for i in "${dir[@]}";do
    if [ ! -d "$i" ]; then
        mkdir -p $i
            if [ $? -eq 0 ];then
	        printf "Folder $i created\n"
                chmod a+rwx $i
            else
                printf "ERROR: there is a problem with creating folder $i\nEXIT\n"
                exit
            fi
    fi
done

#check if refseq exists otherwise download it
if [ ! -f "reference/${refseq}.tar.gz" ]; then
  if [ $(df -P . | tail -1 | xargs | cut -d" " -f4) -lt 15000000 ];then
    printf "ERROR: There is not enough diskspace for downloading the refseq file\nEXIT\n"
    exit
  else
    wget -P  reference http://ftp.ensembl.org/pub/release-104/variation/indexed_vep_cache/${refseq}.tar.gz
    tar xzf reference/${refseq}.tar.gz --directory reference
  fi
fi

#check if fasta exists otherwise download it
if [ ! -f "reference/${fasta}.fa.gz" ]; then
  if [ $(df -P . | tail -1 | xargs | cut -d" " -f4) -lt 1000000 ];then
    printf "ERROR: There is not enough diskspace for downloading the FASTA file\nEXIT\n"
    exit
  else
    wget -P reference http://ftp.ensembl.org/pub/grch37/current/fasta/homo_sapiens/dna/${fasta}.fa.gz
    gzip -d reference/${fasta}.fa.gz > reference/${fasta}.fa
    bgzip -c reference/${fasta}.fa > reference/${fasta}.fa.gz
  fi
fi

#make cronjob if not existing
if [ $(crontab -l | grep $scriptname | wc -l) -eq 0 ];then
  crontab -l > vepcron
  #echo new cron into cron file
  echo "22 * * * * cd $(pwd) && ./$scriptname >> $(pwd)/archive/logs/$(date +"%Y%m%d")cron.log 2>&1" >> vepcron
  cat vepcron
  #install new cron file
  crontab vepcron
  rm vepcron
fi

#pull the right docker image
docker pull ensemblorg/ensembl-vep:release_104.3

#run docker image
docker_con=$( docker run -d -i -t -v $(pwd):${mount_dir} ensemblorg/ensembl-vep )
printf "docker image with the ID $docker_con is started\n"

#check if enough space is left
if [ $(df -P . | tail -1 | xargs | cut -d" " -f4) -lt 5000000 ];then
  printf "INFO: There is less then 5GB space left on your disk, please check\n"
fi

#check for whitespaces and repaces them with underscore
SAVEIFS=$IFS
IFS=$'\n'
for f in $(find input/ -name '*\ *.vcf')
do
  mv "$f" "${f// /_}"
  printf "I don't like whitespaces: $f is renamed to ${f// /_}"
done
IFS=$SAVEIFS

#for every file that ends with .vfc that stayed ther for longer than timeout (that value is stored in the config)
for i in $(find input/ -name '*.vcf' -mmin +$waitperiod)
  do
    #BASENAME=$( echo $i | cut -d'/' -f2)
    basename=${i##*/}
    basename_we=$( echo $basename | cut -d'.' -f1)
    outname=${basename_we}_VEP_RefSeq.vcf

    cp $i archive
    if [ $? -eq 0 ];then
      printf "file $i is copied to archive\n"
    else
      printf "ERROR: the file $i cannot be copied into the archive\nEXIT\n"
      exit
    fi

    #The options of the vep script below can still be modified based on what we decide as final output, these changes however
    #will not change at all the rest of the script, I will check the different outputfiles available by VEP to check for problems
    #during the run or a .log file

    echo $(date +%T) >> archive/logs/$(date +"%Y%m%d")docker.log

    (docker exec -i ${docker_con} /bin/bash -c "./vep\
  -input_file ${mount_dir}/$i \
  --offline \
  --cache \
  --dir_cache ${mount_dir}/reference \
  --refseq \
  --hgvs \
  --hgvsg \
  --fasta ${mount_dir}/reference/${fasta}.fa.gz \
  --format vcf \
  --vcf \
  --force_overwrite \
  --no_stats \
  -o stdout | \
./filter_vep \
--force_overwrite  \
--filter 'Feature matches NM_002529 or Feature matches NM_006180 or Feature matches NM_001012338 or Feature matches NM_020975 or Feature matches NM_005343 or Feature matches NM_000455 or Feature matches NM_203500 or Feature matches NM_004304 or Feature matches NM_004333 or Feature matches NM_001904 or Feature matches NM_005228 or Feature matches NM_023110 or (Feature matches NM_000141 and EXON is 8/18)or Feature matches NM_022970 or Feature matches NM_000142 or Feature matches NM_213647 or Feature matches NM_004448 or Feature matches NM_033360 or Feature matches NM_002755 or Feature matches NM_001127500 or Feature matches NM_002524 or Feature matches NM_006218 or Feature matches NM_000314 or Feature matches NM_000546 or Feature matches NM_002944 or Feature matches NM_005896 or Feature matches NM_002168' \
 --only_matched \
  -output_file ${mount_dir}/output/$outname ; chmod 666 ${mount_dir}/output/* "  ) >> archive/logs/$(date +"%Y%m%d")docker.log

    if [ -f archive/$basename ] && [ -f output/$outname ];then
      rm $i
    else
      printf "$basename doesn't exist in archive or output, so it could not be deleted\n"
    fi
  done

printf "docker stop "
docker stop $docker_con
printf "docker rm "
docker rm $docker_con
