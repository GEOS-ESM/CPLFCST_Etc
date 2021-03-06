#!/bin/csh
#
##########################################################################################
#
# This script runs one seasonal hindcast 
# It performs the following tasks for a given date, ensemble number and queue:
#    runs setup utility
#    places IC to run directory
#
##########################################################################################
# INPUT:
#  icdate	initial date of the forecast (YYYYMMDD)
#  ENSM		ensemble number (1:99), number 1 is reserved for 9-month duration forecast
#  doS2S        choice of queue (0-gmaofcst; 1-s2s preops; 2-gmaodev; 3-high)
#
# PREREQUISITES:
# 1) The environmental variable GEOSS2S is set to:
# /discover/nobackup/projects/gmao/m2oasf/aogcm/g5fcst/forecast/production/geos-s2s
# 2) Directories $GEOSS2S/util and $GEOSS2S/util/submitted are required
# 3) Files required to be in $GEOSS2S/util are:
#    SEASONAL                         SUBSEASONAL
#    submit_hindcastSEASONAL.sh       subXsubmit_hindcast.sh
#    do_one_hindcast.sh               do_one_hindcast.sh
#    submit_cleanSEASONAL.sh
#    clean_one_hindcast.sh
#    monitor_hindcastSEASONAL.sh      monitor_subXensX.sh
#    proc_diag_fcst.csh
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
set EMISQFEDCL = FALSE

###########################################
#   SET BUILD, RUN AND ARCHIVE LOCATIONS 
###########################################

set BUILD = '/discover/nobackup/projects/gmao/m2oasf/build'
set FCSTSRC = "${BUILD}/geos-s2s/GEOSodas/src"
set FCSTBASE = "$GEOSS2S"

set QUEUENAME = 'gmaofcst'
if ( ${doS2S} == 1 ) set QUEUENAME = 's2s'
if ( ${doS2S} == 2 ) set QUEUENAME = 'gmaodev'
if ( ${doS2S} == 3 ) set QUEUENAME = 'high'

set DOSUBX = TRUE
if ( $ENSM == 1 ) set DOSUBX = FALSE
if ( $ENSM > 5 ) set DOSUBX = FALSE

set ARCHDIRN = `grep 'setenv MASDIR /archive/u' $FCSTSRC/GMAO_Shared/GEOS_Util/post/gcmpost_CPLFCSTfull.script | cut -d'/' -f5`

set ARCHDIR = "/archive/u/${USER}/${ARCHDIRN}/seasonal"
if ( $DOSUBX == TRUE ) set ARCHDIR = "/archive/u/${USER}/${ARCHDIRN}/subseasonal"

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

set EXPNMO = `echo ${EXPID} | cut -c1-3`

#Dates of initial conditions at 21z
@ icdatem1 = $icdate - 1
@ iym1 = $EXPYR - 1
if ($EXPID == 'jan01') set icdatem1 = ${iym1}1231
if ($EXPID == 'apr01') set icdatem1 = ${EXPYR}0331
if ($EXPID == 'may01') set icdatem1 = ${EXPYR}0430

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

if ( -e tmp ) /bin/rm -rf tmp
mkdir tmp
cd tmp
#July:   set loka = ANNA   -fix -4 salt 1999-2006,2008-2009,2011,2013-2014
#July:   set loka = ANDREA -fix 2007,2010,2012,2015
#August: set loka = ANDREA -fix 2009-2015
#August: set loka = ERIC   -fix 1999-2007, 2008 +fix, 19990809 & 20010809 +fix
#September: set loka = ERIC   +fix 1999-2010, 2015 minus 20040912 & 20060927
#September: set loka = ANDREA +fix 2011-2014 plus  20040912 & 20060927
#October  : set loka = ERIC   +fix
#sep if ( ${EXPYR} > 2010 ) set loka = ANDREA
#oct if ( ${EXPYR} < 1990 ) set loka = ANDREA
#nov if ( ${EXPYR} > 1987 ) set loka = ANNA
#nov if ( ${EXPYR} < 1988 ) set loka = ANDREA
#20170907: 1981-2016 oct-dec moved to loca REINIT
#oct
set loka = ERIC
if ( ( ${EXPMO} == 10 ) & ( ${EXPYR} < 1990) ) set loka = ANDREA
if ( ( ${EXPMO} == 11 ) & ( ${EXPYR} < 1988) ) set loka = ANDREA
if ( ( ${EXPMO} == 11 ) & ( ${EXPYR} > 1987) ) set loka = ANNA
if ( ( ${EXPMO} == 12 ) & ( ${EXPYR} < 1987) ) set loka = ERIC
if ( ( ${EXPMO} == 12 ) & ( ${EXPYR} > 2002) ) set loka = ERIC
if ( ( ${EXPMO} == 10 ) & ( ${EXPYR} > 2002) ) set loka = ERIC
if ( ${icdatem1} == 20040912 ) set loka = ANDREA
if ( ${icdatem1} == 20060927 ) set loka = ANDREA
if ( ${icdatem1} == 19851007 ) set loka = ANNA

set loka = REINIT

echo "GET ${EXPYR} OCEAN RESTARTS FROM:"
if ( $loka == ANNA ) then
#echo "  /home/aborovik/exp/S2S-2_1_REINIT_002/Y${EXPYR}/${EXPID}/ocean_das/restarts/restarts.e${icdatem1}_21z.tar"
#tar xvf /home/aborovik/exp/S2S-2_1_REINIT_002/Y${EXPYR}/${EXPID}/ocean_das/restarts/restarts.e${icdatem1}_21z.tar
echo "/gpfsm/dnb42/projects/p17/aborovik/geos5/exp/S2S-2_1_REINIT_002/hindcast_restarts/restarts.e${icdatem1}_21z.tar"
tar xvf /gpfsm/dnb42/projects/p17/aborovik/geos5/exp/S2S-2_1_REINIT_002/hindcast_restarts/restarts.e${icdatem1}_21z.tar
endif
if ( $loka == ANDREA ) then
echo "  /discover/nobackup/amolod/S2S-2_1_REINIT_005/hindcast_restarts/restarts.e${icdatem1}_21z.tar"
#tar xvf /discover/nobackup/amolod/S2S-2_1_REINIT_005/hindcast_restarts-dontuse/restarts.e${icdatem1}_21z.tar
tar xvf /discover/nobackup/amolod/S2S-2_1_REINIT_005/hindcast_restarts/restarts.e${icdatem1}_21z.tar
endif
if ( $loka == ERIC ) then
echo "  /gpfsm/dnb42/projects/p17/ehackert/geos5/exp/S2S_REINIT_004/hindcast_restarts/restarts.e${icdatem1}_21z.tar"
tar xvf /gpfsm/dnb42/projects/p17/ehackert/geos5/exp/S2S_REINIT_004/hindcast_restarts/restarts.e${icdatem1}_21z.tar
endif
if ( $loka == REINIT ) then
echo "/discover/nobackup/projects/gmao/m2oasf/aogcm/g5odas/restart/REINIT/${EXPNMO}/restarts.e${icdatem1}_21z.tar"
tar xvf /discover/nobackup/projects/gmao/m2oasf/aogcm/g5odas/restart/REINIT/${EXPNMO}/restarts.e${icdatem1}_21z.tar
endif

set rsocn = $status
if ( $rsocn > 0 ) exit

cd $runxdir
/bin/rm -rf RESTART
/bin/mv tmp/RESTART ./
/bin/mv tmp/seaice_import_rst ./
/bin/mv tmp/seaice_internal_rst ./
/bin/mv tmp/saltwater_import_rst ./
/bin/mv tmp/saltwater_internal_rst ./
echo "GET MERRA2 RESTARTS FROM jmarshak m2oasf/restart/OutData/${icdate}/restarts.e${icdatem1}_21z.tar"
tar xvf /discover/nobackup/projects/gmao/m2oasf/restart/OutData/${icdate}/restarts.e${icdatem1}_21z.tar
/bin/rm -rf tmp

if ( ( $DOSUBX == TRUE ) & ( $ENSM < 5 ) )  then
   echo "SUBSEASONAL: GET PERTURBED fvcore_internal_rst moist_internal_rst for ensemble $ENSM"
   set rstsdir = "/discover/nobackup/projects/gmao/m2oasf/restart"
   @ pertnumber = ${ENSM} / 2
   @ oddens = $ENSM - $pertnumber * 2

   if ( $oddens == 1 ) set pertname = 'Plus'${pertnumber}
   if ( $oddens == 0 ) set pertname = 'Minu'${pertnumber}
 
   echo "GET PERTURBED ${pertnumber} MERRA2 RESTARTS $pertname FROM OutData/${icdate} FOR ENSEMBLE NUMBER $ENSM"
   /bin/cp -p ${rstsdir}/OutData/${icdate}/fvcore_internal_rst${pertname} fvcore_internal_rst
   /bin/cp -p ${rstsdir}/OutData/${icdate}/moist_internal_rst${pertname} moist_internal_rst
endif

wait

###########################################
#   SUBMIT THE RUN
###########################################
cd $runhdir
if ( -e $runxdir/saltwater_internal_rst) then
   echo qsub gcm_run.j
   qsub gcm_run.j
endif

echo 'DONE'
date
exit
