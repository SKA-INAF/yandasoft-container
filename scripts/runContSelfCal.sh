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
	echo "--parset=[PARSET_FILE] - Input configuration file "	
	echo "--containerimg=[CONTAINER_IMG] - Singularity container image file (.simg) with ASKAPSoft installed software"

	echo ""	

	echo "*** OPTIONAL ARGS ***"
	echo "=== SELFCAL OPTIONS ==="	
	echo "--method=[SELFCAL_METHOD] - Selfcal method to be used. Valid options are {Cmodel,Components,CleanModel} (default=Cmodel)"	

	echo ""

	echo "=== RUN OPTIONS ==="	
	echo "--envfile=[ENV_FILE] - File (.sh) with list of environment variables to be loaded by each processing node"
	echo "--containeroptions=[CONTAINER_OPTIONS] - Options to be passed to container run (e.g. -B /home/user:/home/user) (default=none)"	
	echo "--nproc=[NPROC] - Number of MPI processors per node used (NB: mpi tot nproc=nproc x nnodes) (default=1)"
	echo "--nproc-sfind=[NPROC_SFIND] - Number of MPI processors per node used for source finding (NB: mpi tot nproc=nproc x nnodes) (default=nproc)"
	echo "--nproc-cmodel=[NPROC_SFIND] - Number of MPI processors per node used for cmodel (NB: mpi tot nproc=nproc x nnodes) (default=nproc)"
	echo "--nproc-cal=[NPROC_SFIND] - Number of MPI processors per node used for calibration (NB: mpi tot nproc=nproc x nnodes) (default=nproc)"
	echo "--hostfile=[HOSTFILE] - Ascii file with list of hosts used by MPI (default=no hostfile used)"
	
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
PARSET_FILE=""
SELFCAL_METHOD="Cmodel"

## RUN DEFAULT OPTIONS
ENV_FILE=""
CONTAINER_IMG=""
CONTAINER_OPTIONS=""
NPROC=1
NPROC_SFIND=$NPROC
NPROC_CMODEL=$NPROC
NPROC_CAL=$NPROC
MPI_OPTIONS=""
HOSTFILE=""
HOSTFILE_GIVEN=false

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
		--parset=*)
    	PARSET_FILE=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		
		## SELFCAL OPTIONS
		--method=*)
    	SELFCAL_METHOD=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
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
		--nproc=*)
      NPROC=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--nproc-sfind=*)
      NPROC_SFIND=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--nproc-cmodel=*)
      NPROC_CMODEL=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--nproc-cal=*)
      NPROC_CAL=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--mpioptions=*)
      MPI_OPTIONS=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
    ;;
		--hostfile=*)
    	HOSTFILE=`echo $item | sed 's/[-a-zA-Z0-9]*=//'`
			HOSTFILE_GIVEN=true
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

## Compute total number of MPI processor to be given to mpirun
NPROC_TOT=$(($NPROC * $JOB_NNODES))
NPROC_SFIND_TOT=$(($NPROC_SFIND * $JOB_NNODES))
NPROC_CMODEL_TOT=$(($NPROC_CMODEL * $JOB_NNODES))
NPROC_CAL_TOT=$(($NPROC_CAL * $JOB_NNODES))


#######################################
##         CHECK ARGS
#######################################
if [ "$PARSET_FILE" = "" ]; then
	echo "ERROR: Missing or empty parset file!"
	exit 1				
fi
if [ "$SELFCAL_METHOD" != "Cmodel" ] && [ "$SELFCAL_METHOD" != "Components" ] && [ "$SELFCAL_METHOD" != "CleanModel" ]; then
  echo "ERROR: Unknown/not supported SELFCAL_METHOD argument $SELFCAL_METHOD (hint: Cmodel/Components/CleanModel are supported)!"
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
	BATCH_JOB_DEPENDENCY_OPTION="-W depend=afterok"
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
	BATCH_JOB_DEPENDENCY_OPTION="--dependency=afterok"
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


# - Generate parsets & submit scripts 
if [ "${SELFCAL_METHOD}" != "CleanModel" ]; then

	#*************************************
	##            SFINDER
	#*************************************
	# - Run script
	EXE="selavy"
	EXE_ARGS="-c ${PARSET_FILE}"

	shfile_sfinder="run_sfinder.sh"
	echo "INFO: Creating run script file $shfile_sfinder ..."
	(
		echo "#!/bin/bash"
	
		echo ""
		echo "$EXE $EXE_ARGS"

	) > $shfile_sfinder
	chmod +x $shfile_sfinder


	# - Define submission options
	if [ "$BATCH_SYSTEM" = "PBS" ]; then
		BATCH_JOB_NNODES_DIRECTIVE="#PBS -l select=$JOB_NNODES"':'"ncpus=$JOB_NCPUS"':'"mpiprocs=$NPROC_SFIND"':'"mem=$JOB_MEMORY"'gb'
	elif [ "$BATCH_SYSTEM" = "SLURM" ]; then
		BATCH_JOB_NPROC_DIRECTIVE="#SBATCH --ntasks=$NPROC_SFIND_TOT --ntasks-per-node=$NPROC_SFIND"
	else
		echo "ERROR: Unknown/not supported BATCH_SYSTEM argument $BATCH_SYSTEM (hint: PBS/SLURM are supported)!"
  	exit 1
	fi

	CMD="mpirun -np $NPROC_SFIND_TOT $MPI_OPTIONS "
	if [ "$HOSTFILE_GIVEN" = true ] ; then
		CMD="$CMD -hostfile $HOSTFILE "
	fi


	# - Submit script
	submitfile_sfinder="submit_sfinder.sh"
	echo "INFO: Creating submit script file $submitfile_sfinder ..."
	(
		echo "#!/bin/bash"
		echo "$BATCH_JOB_NAME_DIRECTIVE contSelfCal_sfind"
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
		echo 'echo "INFO: Running source finder script '"$shfile_sfinder"' in container  ...'
		echo "$CMD singularity exec $CONTAINER_OPTIONS $CONTAINER_IMG $JOB_DIR/$shfile_sfinder"

		echo ""

		echo 'echo "INFO: End time"'
		echo 'date'

		echo 'echo "*** END RUN ***"'

	) > $submitfile_sfinder
	chmod +x $submitfile_sfinder

	# Submits the job to batch system
	if [ "$SUBMIT" = true ] ; then
		echo "INFO: Submitting script $submitfile_sfinder to QUEUE $BATCH_QUEUE using $BATCH_SYSTEM batch system ..."
		JOB_ID=`$BATCH_SUB_CMD $BATCH_QUEUE_NAME_OPTION $BATCH_QUEUE $submitfile_sfinder`
		JOBID_CHAIN="$JOBID_CHAIN:$JOBID"
		echo "INFO: Submitted script $submitfile_sfinder to queue with job id $JOB_ID ..."
	fi
	

	#*************************************
	##            CMODEL
	#*************************************
	
	if [ "${SELFCAL_METHOD}" == "Cmodel" ]; then
		# - Run script
		EXE="cmodel"
		EXE_ARGS="-c ${PARSET_FILE}"

		shfile_cmodel="run_cmodel.sh"
		echo "INFO: Creating run script file $shfile_cmodel ..."
		(
			echo "#!/bin/bash"
	
			echo ""
			echo "$EXE $EXE_ARGS"

		) > $shfile_cmodel
		chmod +x $shfile_cmodel

		# - Define submission options
		if [ "$BATCH_SYSTEM" = "PBS" ]; then
			BATCH_JOB_NNODES_DIRECTIVE="#PBS -l select=$JOB_NNODES"':'"ncpus=$JOB_NCPUS"':'"mpiprocs=$NPROC_CMODEL"':'"mem=$JOB_MEMORY"'gb'
		elif [ "$BATCH_SYSTEM" = "SLURM" ]; then
			BATCH_JOB_NPROC_DIRECTIVE="#SBATCH --ntasks=$NPROC_CMODEL_TOT --ntasks-per-node=$NPROC_CMODEL"
		else
			echo "ERROR: Unknown/not supported BATCH_SYSTEM argument $BATCH_SYSTEM (hint: PBS/SLURM are supported)!"
  		exit 1
		fi
	
		CMD="mpirun -np $NPROC_CMODEL_TOT $MPI_OPTIONS "
		if [ "$HOSTFILE_GIVEN" = true ] ; then
			CMD="$CMD -hostfile $HOSTFILE "
		fi


		# - Submission script
		submitfile_cmodel="submit_cmodel.sh"
		echo "INFO: Creating submit script file $submitfile_cmodel ..."
		(
			echo "#!/bin/bash"
			echo "$BATCH_JOB_NAME_DIRECTIVE contSelfCal_cmodel"
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
			echo 'echo "INFO: Running cmodel script '"$shfile_cmodel"' in container  ...'
			echo "$CMD singularity exec $CONTAINER_OPTIONS $CONTAINER_IMG $JOB_DIR/$shfile_cmodel"

			echo ""

			echo 'echo "INFO: End time"'
			echo 'date'

			echo 'echo "*** END RUN ***"'

		) > $submitfile_cmodel
		chmod +x $submitfile_cmodel

		# Submits the job to batch system
		if [ "$SUBMIT" = true ] ; then
			echo "INFO: Submitting script $submitfile_cmodel to QUEUE $BATCH_QUEUE using $BATCH_SYSTEM batch system ..."
			JOB_ID=`$BATCH_SUB_CMD $BATCH_JOB_DEPENDENCY_OPTION$JOBID_CHAIN $BATCH_QUEUE_NAME_OPTION $BATCH_QUEUE $submitfile_cmodel`
			echo "INFO: Submitted script $submitfile_cmodel to queue with job id $JOB_ID (dependency list=$BATCH_JOB_DEPENDENCY_OPTION$JOBID_CHAIN) ..."
			JOBID_CHAIN="$JOBID_CHAIN:$JOBID"
		fi		

	fi

fi


#*************************************
##            CALIBRATION
#*************************************
# - Run script
EXE="ccalibrator"
EXE_ARGS="-c ${PARSET_FILE}"

shfile_ccalib="run_calib.sh"
echo "INFO: Creating run script file $shfile_ccalib ..."
(
	echo "#!/bin/bash"
	
	echo ""
	echo "$EXE $EXE_ARGS"

) > $shfile_ccalib
chmod +x $shfile_ccalib

# - Define submission options
if [ "$BATCH_SYSTEM" = "PBS" ]; then
	BATCH_JOB_NNODES_DIRECTIVE="#PBS -l select=$JOB_NNODES"':'"ncpus=$JOB_NCPUS"':'"mpiprocs=$NPROC_CAL"':'"mem=$JOB_MEMORY"'gb'
elif [ "$BATCH_SYSTEM" = "SLURM" ]; then
	BATCH_JOB_NPROC_DIRECTIVE="#SBATCH --ntasks=$NPROC_CAL_TOT --ntasks-per-node=$NPROC_CAL"
else
	echo "ERROR: Unknown/not supported BATCH_SYSTEM argument $BATCH_SYSTEM (hint: PBS/SLURM are supported)!"
  exit 1
fi

CMD="mpirun -np $NPROC_CAL_TOT $MPI_OPTIONS "
if [ "$HOSTFILE_GIVEN" = true ] ; then
	CMD="$CMD -hostfile $HOSTFILE "
fi


# - Submission script
submitfile_ccalib="submit_ccalib.sh"
echo "INFO: Creating submit script file $submitfile_ccalib ..."
(
	echo "#!/bin/bash"
	echo "$BATCH_JOB_NAME_DIRECTIVE contSelfCal_cal"
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
	echo 'echo "INFO: Running calibrator script '"$shfile_ccalib"' in container  ...'
	echo "$CMD singularity exec $CONTAINER_OPTIONS $CONTAINER_IMG $JOB_DIR/$shfile_ccalib"
   
	echo ""

	echo 'echo "INFO: End time"'
	echo 'date'

	echo 'echo "*** END RUN ***"'

) > $submitfile_ccalib
chmod +x $submitfile_ccalib


# Submits the job to batch system
if [ "$SUBMIT" = true ] ; then
	echo "INFO: Submitting script $submitfile_ccalib to QUEUE $BATCH_QUEUE using $BATCH_SYSTEM batch system ..."
	
	if [ "${JOBID_CHAIN}" == "" ]; then
		JOB_ID=`$BATCH_SUB_CMD $BATCH_QUEUE_NAME_OPTION $BATCH_QUEUE $submitfile_ccalib`
		echo "INFO: Submitted script $submitfile_ccalib to queue with job id $JOB_ID (no job dependencies) ..."
	else
		JOB_ID=`$BATCH_SUB_CMD $BATCH_JOB_DEPENDENCY_OPTION$JOBID_CHAIN $BATCH_QUEUE_NAME_OPTION $BATCH_QUEUE $submitfile_ccalib`
		echo "INFO: Submitted script $submitfile_ccalib to queue with job id $JOB_ID (dependency list=$BATCH_JOB_DEPENDENCY_OPTION$JOBID_CHAIN) ..."
	fi
fi	


