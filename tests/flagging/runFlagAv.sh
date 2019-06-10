#!/bin/bash

NARGS="$#"
echo "INFO: NARGS= $NARGS"

if [ "$NARGS" -lt 2 ]; then
	echo "ERROR: Invalid number of arguments...see script usage!"
  echo ""
	echo "**************************"
  echo "***     USAGE          ***"
	echo "**************************"
 	echo "$0 [ARGS]"
	echo ""
	echo "=========================="
	echo "==    ARGUMENT LIST     =="
	echo "=========================="
	echo "*** MANDATORY ARGS ***"
	echo "--inputms=[INPUT_MS] - Input measurement set file (.ms)"
	echo "--containerimg=[CONTAINER_IMG] - Singularity container image file (.simg) with ASKAPSoft installed software"
	echo ""	

	echo "*** OPTIONAL ARGS ***"
	echo "=== FLAG OPTIONS ==="	
	echo "--parset=[PARSET_FILE] - Input configuration file with flagging options"	
	echo "--use-aoflagger - Use AOFLAGGER instead of default cflag"
	
	echo "=== RUN OPTIONS ==="	
	echo "--envfile=[ENV_FILE] - File (.sh) with list of environment variables to be loaded by each processing node"
	echo "--containeroptions=[CONTAINER_OPTIONS] - Options to be passed to container run (e.g. -B /home/user:/home/user) (default=none)"	
	echo ""
	
	echo "=== SUBMISSION OPTIONS ==="
	echo "--submit - Submit the script to the batch system using queue specified"
	echo "--queue=[BATCH_QUEUE] - Name of queue in batch system"
	echo "--jobwalltime=[JOB_WALLTIME] - Job wall time in batch system (default=96:00:00)"
	echo "--jobmemory=[JOB_MEMORY] - Memory in GB required for the job (default=4)"
	echo "--jobusergroup=[JOB_USER_GROUP] - Name of job user group batch system (default=empty)"
	echo "=========================="

	exit 1
fi


#######################################
##         PARSE ARGS
#######################################
## MANDATORY OPTIONS
INPUT_MS=""
PARSET_FILE=""

## FLAG OPTIONS
USE_AOFLAGGER=false

## RUN DEFAULT OPTIONS
ENV_FILE=""
CONTAINER_IMG=""
CONTAINER_OPTIONS=""

## SUBMIT DEFAULT OPTIONS
SUBMIT=false
BATCH_QUEUE=""
JOB_WALLTIME="96:00:00"
JOB_MEMORY="4"
JOB_USER_GROUP=""
JOB_USER_GROUP_OPTION=""

for item in "$@"
do
	case $item in 
		## MANDATORY ##	
		--inputms=*)
			INPUT_MS=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`	
		;;

		
		## FLAG OPTIONS ##		
		--parset=*)
    	PARSET_FILE=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		
		--use-aoflagger*)
    	USE_AOFLAGGER=true
    ;;
			
		## RUN OPTIONS	
		--envfile=*)
    	ENV_FILE=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
			
		--containerimg=*)
    	CONTAINER_IMG=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--containeroptions=*)
    	CONTAINER_OPTIONS=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		
		
		## SUBMISSION OPTIONS	
		--submit*)
    	SUBMIT=true
    ;;
		--queue=*)
    	BATCH_QUEUE=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`		
    ;;
		--jobwalltime=*)
			JOB_WALLTIME=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`	
		;;
		--jobmemory=*)
			JOB_MEMORY=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`	
		;;
		--jobusergroup=*)
			JOB_USER_GROUP=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`	
			JOB_USER_GROUP_OPTION="#PBS -A $JOB_USER_GROUP"
		;;
		
		
    *)
    # Unknown option
    echo "ERROR: Unknown option ($item)...exit!"
    exit 1
    ;;
	esac
done



#######################################
##         CHECK ARGS
#######################################
if [ "$INPUT_MS" = "" ]; then
	echo "ERROR: Missing or empty input measurement set filename!"
	exit 1				
fi

#######################################
##     DEFINE & LOAD ENV VARS
#######################################
export JOB_DIR="$PWD"


#######################################
##     RUN
#######################################
if [ "$PARSET_FILE" = "" ] ; then

	PARSET_FILE="$JOB_DIR/parset.cfg"

	cfgfile=$PARSET_FILE
	echo "INFO: Creating parset file $cfgfile ..."
	(

		echo "# The path/filename for the measurement set"
		echo "Cflag.dataset = $INPUT_MS"

		echo ""

		echo "# Amplitude based flagging with dynamic thresholds"
		echo "#  This finds a statistical threshold in the spectrum of each"
		echo "#  time-step, then applies the same threshold level to the integrated"
		echo "#  spectrum at the end."
		echo "Cflag.amplitude_flagger.enable           = true"
		echo "Cflag.amplitude_flagger.dynamicBounds    = true"
		echo "Cflag.amplitude_flagger.threshold        = 4.0"
		echo "Cflag.amplitude_flagger.integrateSpectra = true"
		echo "Cflag.amplitude_flagger.integrateSpectra.threshold = 4.0"
		echo "Cflag.amplitude_flagger.integrateTimes = false"
		echo "Cflag.amplitude_flagger.integrateTimes.threshold = 4.0"
		echo "Cflag.amplitude_flagger.low             = 0.000001"

		echo ""

		echo "# Stokes-V flagging"
		echo "Cflag.stokesv_flagger.enable           = true"
		echo "Cflag.stokesv_flagger.useRobustStatistics = true"
		echo "Cflag.stokesv_flagger.threshold        = 4.0"
		echo "Cflag.stokesv_flagger.integrateSpectra = true"
		echo "Cflag.stokesv_flagger.integrateSpectra.threshold = 4.0"
		echo "Cflag.stokesv_flagger.integrateTimes = false"
		echo "Cflag.stokesv_flagger.integrateTimes.threshold = 4.0"

	) > $cfgfile
	chmod +x $cfgfile
fi

# - Generate run script
if [ "$USE_AOFLAGGER" = true ] ; then
	EXE="aoflagger"
	EXE_ARGS="-v -auto-read-mode $INPUT_MS"
else
	EXE="cflag"
	EXE_ARGS="-c ${PARSET_FILE}"
fi
	

shfile="run.sh"
echo "INFO: Creating run script file $shfile ..."
(
	echo "#!/bin/bash"
	
	echo ""
	echo 'echo "INFO: Running command "'"$EXE $EXE_ARGS"'" ...'
	echo "$EXE $EXE_ARGS"

) > $shfile
chmod +x $shfile

submitfile="submit.sh"
echo "INFO: Creating submit script file $submitfile ..."
(
	echo "#!/bin/bash"
	echo "#PBS -N flagAvg"
	echo "#PBS -j oe"
	echo "#PBS -o $BASEDIR"
  echo "#PBS -l select=1:ncpus=1:mem=$JOB_MEMORY"'GB'
	echo "#PBS -l walltime=$JOB_WALLTIME"
  echo '#PBS -r n'
  echo '#PBS -S /bin/bash'    
  echo '#PBS -p 1'
	echo "$JOB_USER_GROUP_OPTION"

	echo " "
	echo 'echo "INFO: Running on host $HOSTNAME ..."'
	echo " "

	echo 'echo "*************************************************"'
  echo 'echo "****         PREPARE JOB                     ****"'
  echo 'echo "*************************************************"'
	echo "JOBDIR=$JOB_DIR" 
	if [ "$ENV_FILE" != "" ]; then
		echo 'echo "INFO: Source the software environment ..."'
		echo "source $ENV_FILE"		
	fi

	echo ""

	echo 'echo "*************************************************"'
  echo 'echo "****         RUN JOB                     ****"'
  echo 'echo "*************************************************"'
	echo 'echo "INFO: Running script "'"$shfile"' in container  ...'
	echo "singularity exec $CONTAINER_OPTIONS $CONTAINER_IMG $JOB_DIR/$shfile"
	
	echo ""

	echo 'echo "*** END RUN ***"'

) > $submitfile
chmod +x $submitfile


