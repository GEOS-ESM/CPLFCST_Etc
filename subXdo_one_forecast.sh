#!/bin/csh
#
##########################################################################################
#
# This script runs one subseasonal forecast 
# It performs the following tasks for a given date, ensemble number and queue:
#    runs setup utility
#    checks for IC to be available
#    places IC to run directory
#    For ensemble members 2,3,4 it generates perturbations
#
##########################################################################################
# INPUT:
#  icdate	initial date of the forecast (YYYYMMDD)
#  ENSM		ensemble number (2:5), number 1 is reserved for 9-month duration forecast
#  doS2S        choice of queue (0-use gmaofcst queue ; 1-use s2s preops queue; 2-use gmaodev queue)
#
# PREREQUISITES:
# 1) The environmental variable GEOSS2S is set to:
# /discover/nobackup/projects/gmao/m2oasf/aogcm/g5fcst/forecast/production/geos-s2s
# 2) Directories $GEOSS2S/util and $GEOSS2S/util/submitted are required
# 3) Files required to be in $GEOSS2S/util are:
#    subXsubmit_forecast.sh 
#    subXdo_one_forecast.sh
#    monitor_subXensX.sh
#    fvcore_pert.sh 
#    moist_pert.sh
#    perturb_atm.sh
# 
# $GEOSS2S/util is the location of the run to be submitted 
# $GEOSS2S/runh is the home directory of the run (will be generated by setup)
# $GEOSS2S/runx is the work directory of the run (will be generated by setup)
# $ARCHIVE/GEOS_S2S is the archive directory of the run
#########################################################################################


###########################################
#   ENTER THE IC DATE AND ENSEMBLE NUMBER
###########################################

set icdate = $1
set ENSM = $2
set doS2S = $3
set EMISQFEDCL = TRUE

###########################################
#   SET BUILD, RUN AND ARCHIVE LOCATIONS 
###########################################
set RESTARTS = '/gpfsm/dnb42/projects/p17/production/geos5/exp/S2S-2_1_ANA_001/hindcast_restarts/'
set BUILD = '/discover/nobackup/projects/gmao/m2oasf/build'
set FCSTSRC = "${BUILD}/geos-s2s/GEOSodas/src"
set FCSTBASE = "$GEOSS2S"

##########################################
#   CHECK RESTARTS AVAILABILITY 
##########################################
set EXPYR = `echo $icdate | cut -c1-4`
set EXPMO = `echo $icdate | cut -c5-6`
set EXPDD = `echo $icdate | cut -c7-8`
if ($EXPMO == '01') set EXPID='jan'$EXPDD
if ($EXPMO == '02') set EXPID='feb'$EXPDD
if ($EXPMO == '03') set EXPID='mar'$EXPDD
if ($EXPMO == '04') set EXPID='apr'$EXPDD
if ($EXPMO == '05') set EXPID='may'$EXPDD
if ($EXPMO == '06') set EXPID='jun'$EXPDD
if ($EXPMO == '07') set EXPID='jul'$EXPDD
if ($EXPMO == '08') set EXPID='aug'$EXPDD
if ($EXPMO == '09') set EXPID='sep'$EXPDD
if ($EXPMO == '10') set EXPID='oct'$EXPDD
if ($EXPMO == '11') set EXPID='nov'$EXPDD
if ($EXPMO == '12') set EXPID='dec'$EXPDD

#Dates of initial conditions at 21z
@ icdatem1 = $icdate - 1
@ iym1 = $EXPYR - 1
if ($EXPID == 'jan01') set icdatem1 = ${iym1}1231
if ($EXPID == 'apr01') set icdatem1 = ${EXPYR}0331
if ($EXPID == 'may01') set icdatem1 = ${EXPYR}0430
if ( ! -e $RESTARTS/RESTART/${icdatem1}_2100z.ocean_temp_salt.res.nc ) then
     echo "RESTARTS $icdatem1 NOT AVAILABLE, EXIT"
     exit
endif

set QUEUENAME = 'gmaofcst'
if ( ${doS2S} == 1 ) set QUEUENAME = 's2s'
if ( ${doS2S} == 2 ) set QUEUENAME = 'gmaodev'

set DOSUBX = TRUE
if ( $ENSM == 1 ) set DOSUBX = FALSE

set ARCHDIRN = `grep 'setenv MASDIR /archive/u' $FCSTSRC/GMAO_Shared/GEOS_Util/post/gcmpost_CPLFCSTfull.script | cut -d'/' -f5`

set ARCHDIR = "/archive/u/gmaofcst/${ARCHDIRN}/seasonal"
if ( $DOSUBX == TRUE ) set ARCHDIR = "/archive/u/gmaofcst/${ARCHDIRN}/subseasonal"

set descr = `ls -l ${BUILD}/geos-s2s | cut -d'>' -f2 | cut -d'/' -f1`
echo "ENTERED $icdate for ensemble $ENSM; SUBSEASONAL=$DOSUBX"
echo "RUN QUEUE: $QUEUENAME"
echo "DESCRIPTION: ${BUILD} $descr"

###########################################
#   RUN THE SETUP UTILITY               
###########################################

#source $FCSTSRC/g5_modules
module purge
module load comp/intel-15.0.2.164
module load mpi/impi-5.0.3.048
module load lib/mkl-15.0.2.164
module load other/comp/gcc-4.6.3-sp1
module load other/SIVO-PyD/spd_1.20.0_gcc-4.6.3-sp1_mkl-15.0.0.090
module load other/git-2.3.1
module load other/cdo

set filesetup = 'gcm_CPLFCST360S2Sallsetup'
cd $FCSTBASE/util
if (! -e submitted/ens${ENSM}gcm_setup$icdate) then
   echo " SET UP THE EXPERIMENT FOR $icdate"
   cd $FCSTSRC/Applications/GEOSgcm_App
   /bin/rm -f $FCSTBASE/util/sedfile
cat > $FCSTBASE/util/sedfile << EOF
s/@FCSTIC/$icdate/g
s/@FCSTXX/$descr/g
s/@FCSTMEMBER/$ENSM/g
s/@FCSTSUBX/$DOSUBX/g
s/@FCSTQUEUENAME/$QUEUENAME/g
s/@FCSTARCHIVE/$ARCHDIRN/g
s/@FCSTEMISQFED/$EMISQFEDCL/g
EOF
   sed -f $FCSTBASE/util/sedfile $filesetup > $FCSTBASE/util/gcm_setup$icdate
else
   echo 'SETTING EXIST, EXITING'
   exit
endif
cd $FCSTBASE/util
chmod 750 $FCSTBASE/util/gcm_setup$icdate
$FCSTBASE/util/gcm_setup$icdate

###########################################
#   SET THE cap_restart AND LOCATION
###########################################

#set EXPYR = `echo $icdate | cut -c1-4`
#set EXPMO = `echo $icdate | cut -c5-6`
#set EXPDD = `echo $icdate | cut -c7-8`
#if ($EXPMO == '01') set EXPID='jan'$EXPDD
#if ($EXPMO == '02') set EXPID='feb'$EXPDD
#if ($EXPMO == '03') set EXPID='mar'$EXPDD
#if ($EXPMO == '04') set EXPID='apr'$EXPDD
#if ($EXPMO == '05') set EXPID='may'$EXPDD
#if ($EXPMO == '06') set EXPID='jun'$EXPDD
#if ($EXPMO == '07') set EXPID='jul'$EXPDD
#if ($EXPMO == '08') set EXPID='aug'$EXPDD
#if ($EXPMO == '09') set EXPID='sep'$EXPDD
#if ($EXPMO == '10') set EXPID='oct'$EXPDD
#if ($EXPMO == '11') set EXPID='nov'$EXPDD
#if ($EXPMO == '12') set EXPID='dec'$EXPDD

#Dates of initial conditions at 21z
#@ icdatem1 = $icdate - 1
#@ iym1 = $EXPYR - 1
#if ($EXPID == 'jan01') set icdatem1 = ${iym1}1231
#if ($EXPID == 'apr01') set icdatem1 = ${EXPYR}0331
#if ($EXPID == 'may01') set icdatem1 = ${EXPYR}0430

set caprestart=${icdatem1}' 210000'
set runhdir="$FCSTBASE/runh/$EXPYR/$EXPID/ens$ENSM"
set runxdir="$FCSTBASE/runx/$EXPYR/$EXPID/ens$ENSM"

echo $caprestart > $runhdir/cap_restartIC
/bin/cp -p  $runhdir/cap_restartIC $runxdir/cap_restart

/bin/mv gcm_setup$icdate submitted/ens${ENSM}gcm_setup$icdate

###########################################
#   PLACE THE RESTARTS TO EXP DIRECTORY
###########################################
echo "GET THE INITIAL CONDITIONS (restarts) IN PLACE"
cd $runxdir
/bin/rm -rf RESTART
@ nerr = 0

set loka = GMAOFCST
echo "GET ${EXPYR} OCEAN RESTARTS FOR ${icdatem1}_21z"

if ( $loka == GMAOFCST ) then
 echo "$RESTARTS"
 if ( ! -e tmp ) mkdir tmp
 cd tmp
 cp -p $RESTARTS/*.${icdatem1}_2100z.bin ./
 set fnames = `ls -1 *${icdatem1}_2100z.bin | cut -d "_" -f-2`
 foreach fname ( $fnames )
  /bin/mv ${fname}_checkpoint.${icdatem1}_2100z.bin ${runxdir}/${fname}_rst
 end
 set nfiles = `ls -1 ${runxdir}/*_rst | wc -l`
 if ( $nfiles != 21 ) then
    echo "NUMBER ATM RESTARTS WRONG"
    @ nerr = $nerr + 1
 endif
 cp -p $RESTARTS/RESTART/${icdatem1}_2100z.ocean*.nc ./
 set fnames = `ls -1 ${icdatem1}_2100z.ocean_*.nc | cut -c16-`
 mkdir -p ${runxdir}/RESTART
 foreach fname ( $fnames )
  /bin/mv ${icdatem1}_2100z.${fname} ${runxdir}/RESTART/${fname}
 end
 set nfiles = `ls -1 ${runxdir}/RESTART/*.nc | wc -l`
 if ( $nfiles != 13 ) then
    echo "NUMBER OCN RESTARTS WRONG"
    @ nerr = $nerr + 1
 endif
 if ( $nerr > 0 ) exit
 cd ${runxdir}
 /bin/rmdir tmp
 set rss = $status
 if ( $rss > 0 ) exit
endif

if ( ( $DOSUBX == TRUE ) & ( $ENSM < 5 ) )  then
   echo "SUBSEASONAL: GET PERTURBED fvcore_internal_rst moist_internal_rst for ensemble $ENSM"
   @ pertnumber = ${ENSM} / 2
   @ oddens = $ENSM - $pertnumber * 2

   if ( $oddens == 1 ) set pertname = 'Plus'${pertnumber}
   if ( $oddens == 0 ) set pertname = 'Minu'${pertnumber}
 
   echo "GET PERTURBED ${pertname} ${icdatem1}_2100z RESTARTS FOR ENSEMBLE NUMBER $ENSM FROM S2S-2_1_ANA_001"
   #/gpfsm/dnb42/projects/p17/production/geos5/exp/S2S-2_1_ANA_001/hindcast_restarts/*.${icdatem1}_2100z.bin
   /bin/mv $runxdir/fvcore_internal_rst $runxdir/central_fvcore_internal_rst
   /bin/mv $runxdir/moist_internal_rst $runxdir/central_moist_internal_rst
   cd $FCSTBASE/runx/$EXPYR/$EXPID
   if ( ! -e OutData ) mkdir -p OutData
   if ( ! -e OutData/moist_internal_rst${pertname} ) $GEOSS2S/util/perturb_atm.sh $icdate $ENSM
   set stmv = `ls -1 OutData/*${pertname} | wc -l`
   if ( $stmv == 2 ) then
    /bin/mv OutData/fvcore_internal_rst${pertname} $runxdir/fvcore_internal_rst
    /bin/mv OutData/moist_internal_rst${pertname} $runxdir/moist_internal_rst
    /bin/rm -f $runhdir/NO_PERT
   else
    echo "PERTURBATION NOT GENERATED FOR ${pertname}"
    touch $runhdir/NO_PERT
   endif
endif

wait

###########################################
#   SUBMIT THE RUN
###########################################
cd $runhdir
if ( ! -e $runhdir/NO_PERT) then
   echo qsub gcm_run.j
   qsub gcm_run.j
endif

echo 'DONE'
exit
