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
	
	echo ""

	echo "=== RUN OPTIONS ==="	
	echo "--envfile=[ENV_FILE] - File (.sh) with list of environment variables to be loaded by each processing node"
	echo "--containeroptions=[CONTAINER_OPTIONS] - Options to be passed to container run (e.g. -B /home/user:/home/user) (default=none)"	
	echo ""
	
	echo "=== SUBMISSION OPTIONS ==="
	echo "--submit - Submit the script to the batch system using queue specified"
	echo "--batchsystem - Name of batch system. Valid choices are {PBS,SLURM} (default=PBS)"
	echo "--queue=[BATCH_QUEUE] - Name of queue in batch system"
	echo "--jobwalltime=[JOB_WALLTIME] - Job wall time in batch system (default=96:00:00)"
	echo "--jobcpus=[JOB_NCPUS] - Number of cpu per node requested for the job (default=1)"
	echo "--jobnodes=[JOB_NNODES] - Number of nodes requested for the job (default=1)"
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
BATCH_SYSTEM="PBS"
JOB_WALLTIME="96:00:00"
JOB_MEMORY="4"
JOB_USER_GROUP=""
JOB_USER_GROUP_OPTION=""
JOB_NNODES="1"
JOB_NCPUS="1"

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
		--batchsystem=*)
    	BATCH_SYSTEM=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--queue=*)
    	BATCH_QUEUE=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--jobwalltime=*)
			JOB_WALLTIME=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`	
		;;	
		--jobcpus=*)
      JOB_NCPUS=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--jobnodes=*)
      JOB_NNODES=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
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
if [ "$INPUT_MS" = "" ] && [ "$PARSET_FILE" = "" ]; then
	echo "ERROR: Missing or empty input measurement set filename or parset file (at least one required)!"
	exit 1				
fi
if [ "$INPUT_MS" = "" ] && [ "$USE_AOFLAGGER" = true ]; then
	echo "ERROR: Missing or empty input measurement set filename (required when aoflagger is selected)!"
	exit 1				
fi
if [ "$BATCH_QUEUE" = "" ] && [ "$SUBMIT" = true ]; then
  echo "ERROR: Empty BATCH_QUEUE argument (hint: you must specify a queue if submit option is activated)!"
  exit 1
fi

if [ "$BATCH_SYSTEM" = "" ] && [ "$SUBMIT" = true ]; then
  echo "ERROR: Empty BATCH_SYSTEM argument (hint: you must specify a batch systen if submit option is activated)!"
  exit 1
fi

if [ "$BATCH_SYSTEM" != "PBS" ] && [ "$BATCH_SYSTEM" != "SLURM" ]; then
  echo "ERROR: Unknown/not supported BATCH_SYSTEM argument $BATCH_SYSTEM (hint: PBS/SLURM/NONE are supported)!"
  exit 1
fi

#######################################
##     DEFINE & LOAD ENV VARS
#######################################
export JOB_DIR="$PWD"
export BASEDIR="$PWD"

## Define batch run options
if [ "$BATCH_SYSTEM" = "PBS" ]; then
  BATCH_SUB_CMD="qsub"
	BATCH_QUEUE_NAME_OPTION="-q"
	BATCH_JOB_NAME_DIRECTIVE="#PBS -N"
	BATCH_JOB_OUTFILE_DIRECTIVE="#PBS -o $BASEDIR"
	BATCH_JOB_ERRFILE_DIRECTIVE="#PBS -e $BASEDIR"
	BATCH_JOB_JOINOUTERR_DIRECTIVE="#PBS -j oe"
	BATCH_JOB_WALLTIME_DIRECTIVE="#PBS -l walltime=$JOB_WALLTIME"
	BATCH_JOB_SHELL_DIRECTIVE="#PBS -S /bin/bash"
	BATCH_JOB_USERGRP_DIRECTIVE="#PBS -A $JOB_USER_GROUP"
	BATCH_JOB_PRIORITY="#PBS -p 1"
	BATCH_JOB_NOREQUEUE_DIRECTIVE="#PBS -r n"
	BATCH_JOB_SCATTER_DIRECTIVE="#PBS -l place=scatter"
	BATCH_JOB_NNODES_DIRECTIVE="#PBS -l select=$JOB_NNODES"':'"ncpus=$JOB_NCPUS"':'"mpiprocs=$NPROC"':'"mem=$JOB_MEMORY"'gb'
	#BATCH_JOB_NPROC_DIRECTIVE="#PBS -l mpiprocs="
	#BATCH_JOB_MEM_DIRECTIVE="#PBS -l mem="
	#BATCH_JOB_NCORE_DIRECTIVE="#PBS -l ncpus="
	BATCH_JOB_NPROC_DIRECTIVE=""
	BATCH_JOB_MEM_DIRECTIVE=""
	BATCH_JOB_NCORE_DIRECTIVE=""

elif [ "$BATCH_SYSTEM" = "SLURM" ]; then
  BATCH_SUB_CMD="sbatch"
	BATCH_QUEUE_NAME_OPTION="-p"
	BATCH_JOB_NAME_DIRECTIVE="#SBATCH -J"
	BATCH_JOB_OUTFILE_DIRECTIVE="#SBATCH -o $BASEDIR"
	BATCH_JOB_ERRFILE_DIRECTIVE="#SBATCH -e $BASEDIR"
	BATCH_JOB_JOINOUTERR_DIRECTIVE="" # There is no such option in SLURM
	BATCH_JOB_WALLTIME_DIRECTIVE="#SBATCH --time=$JOB_WALLTIME"
	BATCH_JOB_SHELL_DIRECTIVE="" # Equivalent SLURM directive not found
	BATCH_JOB_USERGRP_DIRECTIVE="#SBATCH -A $JOB_USER_GROUP"
	BATCH_JOB_PRIORITY="" # Equivalent SLURM directive not found
	BATCH_JOB_NOREQUEUE_DIRECTIVE="#SBATCH --no-requeue"
	BATCH_JOB_SCATTER_DIRECTIVE="#SBATCH --spread-job"
	BATCH_JOB_NNODES_DIRECTIVE="#SBATCH --nodes=$JOB_NNODES"
	#BATCH_JOB_NPROC_DIRECTIVE="#SBATCH --ntasks-per-node=$NPROC"
	BATCH_JOB_NPROC_DIRECTIVE="#SBATCH --ntasks=$NPROC_TOT --ntasks-per-node=$NPROC"
	BATCH_JOB_MEM_DIRECTIVE="#SBATCH --mem=$JOB_MEMORY"'gb'
	BATCH_JOB_NCORE_DIRECTIVE="#SBATCH --ntasks-per-node=$JOB_NCPUS"
else 
	echo "ERROR: Unknown/not supported BATCH_SYSTEM argument $BATCH_SYSTEM (hint: PBS/SLURM are supported)!"
  exit 1
fi

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
	echo "$EXE $EXE_ARGS"

) > $shfile
chmod +x $shfile

submitfile="submit.sh"
echo "INFO: Creating submit script file $submitfile ..."
(
	echo "#!/bin/bash"
	echo "$BATCH_JOB_NAME_DIRECTIVE flagAvg"
	echo "$BATCH_JOB_OUTFILE_DIRECTIVE"
	echo "$BATCH_JOB_ERRFILE_DIRECTIVE"
	echo "$BATCH_JOB_JOINOUTERR_DIRECTIVE"
	echo "$BATCH_JOB_WALLTIME_DIRECTIVE"
	echo "$BATCH_JOB_SHELL_DIRECTIVE"
	echo "$BATCH_JOB_USERGRP_DIRECTIVE"
	echo "$BATCH_JOB_PRIORITY"
	echo "$BATCH_JOB_NOREQUEUE_DIRECTIVE"
	echo "$BATCH_JOB_SCATTER_DIRECTIVE"
	echo "$BATCH_JOB_NNODES_DIRECTIVE"
	echo "$BATCH_JOB_NPROC_DIRECTIVE"
	echo "$BATCH_JOB_MEM_DIRECTIVE"
	echo "$BATCH_JOB_NCORE_DIRECTIVE"

	echo 'echo "INFO: Start time"'
	echo 'date'

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
	
	echo 'echo "INFO: End time"'
	echo 'date'

	echo 'echo "*** END RUN ***"'

) > $submitfile
chmod +x $submitfile



# Submits the job to batch system
if [ "$SUBMIT" = true ] ; then
	echo "INFO: Submitting script $submitfile to QUEUE $BATCH_QUEUE using $BATCH_SYSTEM batch system ..."
	$BATCH_SUB_CMD $BATCH_QUEUE_NAME_OPTION $BATCH_QUEUE $submitfile
fi

