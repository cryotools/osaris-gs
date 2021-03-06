#!/usr/bin/env bash

#################################################################
#
# Merge multiple swath (if neccessary), then perform phase unwrappping and geocoding.
#
# Based on GMTSAR's merge_unwrap_geocode.csh by Xiaohua(Eric) Xu, 2016. 
#
################################################################

if [ ! $# -eq 3 ]; then
    echo ""
    echo "Usage: merge_unwrap_geocode_tops.csh inputfile config_file boundary_box_file"
    echo ""
    echo "Note: Inputfiles should be as following:"
    echo ""
    echo "      Swath1_Path:Swath1_master.PRM:Swath1_repeat.PRM"
    echo "      Swath2_Path:Swath2_master.PRM:Swath2_repeat.PRM"
    echo "      Swath3_Path:Swath3_master.PRM:Swath3_repeat.PRM"
    echo "      (Use the repeat PRM which contains the shift information.)"
    echo "      e.g. ../F1/intf/2015016_2015030/:S1A20151012_134357_F1.PRM"
    echo ""
    echo "      Make sure under each path, the processed phasefilt.grd, corr.grd and mask.grd exist."
    echo "      Also make sure the dem.grd is linked. "
    echo ""
    echo "      config_file is the same one used for processing."
    echo ""
    echo "Example: merge_unwrap_geocode_tops.csh filelist batch.config"
    echo ""
    exit 1
fi

if [ ! -f dem.grd  ]; then
    echo "Please link dem.grd to current folder"
    exit 1
fi

if [ ! -f $1 ]; then
    echo "ERROR: Input file $1 not found. Aborting merge-unwrap-geocode routine ..."
    exit 1
else
    input_file=$1
fi

if [ ! -f $2 ]; then
    echo "ERROR: Configuration file not found at $2. Aborting merge-unwrap-geocode routine ..."
    exit 1
else
    config_file=$2
    source $config_file
    # source $gmtsar_config_file

    work_PATH=$base_PATH/$prefix/Processing
    # Path to working directory

    # Read in parameters
    # threshold_snaphu=$( grep threshold_snaphu $2 | awk '{print $3}' )
    # threshold_geocode=$( grep threshold_geocode $2 | awk '{print $3}' )
    # #  region_cut=$( grep region_cut $2 | awk '{print $3}' )
    # switch_land=$( grep switch_land $2 | awk '{print $3}' )
    # defomax=$( grep defomax $2 | awk '{print $3}' )
    # near_interp=$( grep near_interp $2 | awk '{print $3}' )

fi

if [ ! -f $3 ]; then
    echo "ERROR: Boundary box file $3 not found. Cutting to area of interest will not be possible."
else
    bbox_file=$3
fi



# input="lists.txt"

# ## Let us read a file line-by-line using while loop ##
# while IFS= read -r line
# do
#     printf 'Working on %s file...\n' "$line"
# done < "$input"



num_swaths=$( cat $input_file | wc -l )

now_dir=$( pwd )
rm -rf ${now_dir}/merged
mkdir -p ${now_dir}/merged

# Remove old tmp files
rm -f merged/tmp_*
#for old_tmpfile in ${old_tmpfiles[@]}; do rm -f $now_dir/merged/$old_tmpfile; done


if [ $num_swaths -gt 1 ]; then
    echo; echo "$num_swaths swaths found. Merging ..."; echo
    # Creating inputfiles for merging
    while IFS= read -r line; do
	cd $now_dir
	
	pth=$( echo $line | awk -F: '{print $1}' )
	prm=$( echo $line | awk -F: '{print $2}' )
	prm2=$( echo $line | awk -F: '{print $3}' )

	cd $pth
	rshift=$( grep rshift $prm2 | tail -1 | awk '{print $3}' )
	fs1=$( grep first_sample $prm | awk '{print $3}' )
	fs2=$( grep first_sample $prm2 | awk '{print $3}' )

	cp $prm2 tmp.PRM
	if [ $fs1 > $fs2 ]; then
	    update_PRM tmp.PRM first_sample $fs1
	fi
	update_PRM tmp.PRM rshift $rshift


	cd $now_dir/merged
	swath_path=${pth::-1}
	echo "../$swath_path/tmp.PRM:../$swath_path/phasefilt.grd" >> tmp_phaselist
	echo "../$swath_path/tmp.PRM:../$swath_path/phase.grd" >> tmp_raw_phaselist
	echo "../$swath_path/tmp.PRM:../$swath_path/corr.grd" >> tmp_corrlist
	echo "../$swath_path/tmp.PRM:../$swath_path/mask.grd" >> tmp_masklist
	echo "../$swath_path/tmp.PRM:../$swath_path/display_amp.grd" >> tmp_amplist
	echo "../$swath_path/tmp.PRM:../$swath_path/amp1-db.grd" >> tmp_amp1list
	echo "../$swath_path/tmp.PRM:../$swath_path/amp2-db.grd" >> tmp_amp2list
	if [ $proc_ifg_grdnts -eq 1 ]; then
	    echo "../$swath_path/tmp.PRM:../$swath_path/xphase.grd" >> tmp_xphslist
	    echo "../$swath_path/tmp.PRM:../$swath_path/yphase.grd" >> tmp_yphslist
	fi
    done < "$input_file"


    pth=$( awk -F: 'NR==1 {print $1}' $input_file )
    stem=$( awk -F: 'NR==1 {print $2}' $input_file | awk -F"." '{print $1}' )
    # stem=$( awk -F: 'NR==1 {print $3}' $input_file | awk -F"." '{print $1}' )
    #echo $pth $stem

    cd ${now_dir}/merged

    echo; echo "Merging files"
    merge_swath tmp_phaselist phasefilt.grd $stem
    merge_swath tmp_raw_phaselist phase.grd
    merge_swath tmp_corrlist corr.grd
    merge_swath tmp_masklist mask.grd
    merge_swath tmp_amplist display_amp.grd
    merge_swath tmp_amp1list amp1-db.grd
    merge_swath tmp_amp2list amp2-db.grd
    if [ $proc_ifg_grdnts -eq 1 ]; then
	merge_swath tmp_xphslist xphase.grd
	merge_swath tmp_yphslist yphase.grd
    fi
    echo "Merging finished"; echo



    # cp ../${pth::-1}/${stem}.PRM .
    # led_file=$( awk '/led_file/{print $3}' ../${pth::-1}/${stem}.PRM )
    # if [ "$debug" -ge 1 ]; then
    # 	echo
    # 	echo "PRM: ../${pth::-1}/${stem}.PRM"
    # 	echo "LED: ../${pth::-1}/$led_file"
    # 	current_dir=$( pwd )
    # 	echo "Current directory: $current_dir"
    # 	if [ -f ../${pth::-1}/$led_file ]; then
    # 	    echo "LED file found"
    # 	else
    # 	    echo "LED file not found"
    # 	fi
    # fi
    # cp ../${pth::-1}/$led_file .





    # if [ ! -f trans.dat ]; then
    # 	led=$( grep led_file ../${pth::-1}/$stem".PRM" | awk '{print $3}' )
    # 	cp "$pth$led" .
    # fi

    
else
    # Only one swath. Prepare files directly
    pth=$( awk -F: 'NR==1{print $1}' $input_file )
    stem=$( awk -F: 'NR==1 {print $2}' $input_file | awk -F"." '{print $1}' )
    echo; echo "Only one swath found in $pth"; echo
    swath_path=${pth::-1}
    cd ${now_dir}/merged
    
    # if [ ! -f trans.dat ]; then
    # 	ln -s "${now_dir}/${swath_path::-5}/topo/trans.dat" .
    # fi

    
    ln -s "${now_dir}/$swath_path/mask.grd" .

    if [ $proc_coherences -eq 1 ]; then ln -s "${now_dir}/$swath_path/corr.grd" .; fi
    if [ $proc_amplit_ifg -eq 1 ]; then ln -s "${now_dir}/$swath_path/display_amp.grd" .; fi
    if [ $proc_amplitudes -eq 1 ]; then
	ln -s "${now_dir}/$swath_path/amp1-db.grd" .
	ln -s "${now_dir}/$swath_path/amp2-db.grd" .
    fi
    
    if [ $proc_ifg_grdnts -eq 1 ]; then
	ln -s "${now_dir}/$swath_path/xphase.grd" .
	ln -s "${now_dir}/$swath_path/yphase.grd" .
    fi

    if [ $proc_ifg_filtrd -eq 1 ]; then 
	ln -s "${now_dir}/$swath_path/phasefilt.grd" .
	ln -s "${now_dir}/$swath_path/phase.grd" .
    fi

fi

cd ${now_dir}/merged



# IMPORTANT: Create a file indicating the filter wavelength
# This will determine the output resolution generated by proj_ra2ll.csh
touch "gauss_$filter_wavelength"


# echo
# echo "Current directory: $( pwd )"
# echo "Copy path: ../${pth::-1}/${stem}.LED"
# echo

cp ../${pth::-1}/${stem}.PRM .
led_file=$( awk '/led_file/{print $3}' ../${pth::-1}/${stem}.PRM )
if [ "$debug" -ge 1 ]; then
    echo
    echo "PRM: ../${pth::-1}/${stem}.PRM"
    echo "LED: ../${pth::-1}/$led_file"
    current_dir=$( pwd )
    echo "Current directory: $current_dir"
    if [ -f ../${pth::-1}/$led_file ]; then
	echo "LED file found"
    else
	echo "LED file not found"
    fi
fi
cp ../${pth::-1}/$led_file .



# This step is essential, cut the DEM so it can run faster.
if [ ! -f trans.dat ]; then
    
    # if [ -e ${now_dir}/$pth$stem".PRM" ]; then 
    #     echo "Reading LED info from ${now_dir}/$pth$stem.PRM"
    #     led=$( grep led_file ${now_dir}/$pth$stem".PRM" | awk '{print $3}' )
    #     echo "LED file: ${now_dir}/$pth$led"
    #     cp ${now_dir}/$pth$led .
    # else
    #     echo "No PRM file found at $pth${stem}.PRM"
    # fi        

    echo; echo "Recomputing the projection LUT..."
    
    ln -s ../../topo/dem.grd .
    # Need to compute the geocoding matrix with supermaster.PRM with rshift  to 0
    rshift=$( grep rshift ${stem}.PRM | tail -1 | awk '{print $3}' )

    cp ${stem}.PRM tmp.PRM
    echo "Creating zero rshift PRM"
    update_PRM ${stem}.PRM rshift 0
    echo "Converting DEM to xyz file"
    gmt grd2xyz --FORMAT_FLOAT_OUT=%lf dem.grd -s > dem.xyz
    echo "Creating trans.dat from zero rshift PRM"
    SAT_llt2rat ${stem}.PRM 1 -bod < dem.xyz > trans.dat
    #  rshift back for other usage
    echo "Shifting PRM back for other applications"
    #update_PRM ${stem}.PRM rshift $rshift
    mv ${stem}.PRM zero_rshift.PRM
    mv tmp.PRM ${stem}.PRM
fi



# TODO: Check which range and azimuth coordinates are actually representing the boundary box
#       -> Check all 4 lon/lat combinations
#       -> Set negative values to 0
#       -> Set values > the maximum (see PRM files) to maximum
#       -> This must be applied to both p2p...csh and merge_unwrap...csh


if [ $cut_to_aoi -eq 1 ]; then

    if [ ! -f $3 ]; then
	echo "No valid boundary box file provided. Phase unwrapping will be conducted on the whole scene extent."
    else
	SAT_llt2rat $stem".PRM" 1 < $3 > boundary_box_ra.xyz
	bb_range_1=$( awk 'NR==1{ print $1 }' boundary_box_ra.xyz )
	bb_range_2=$( awk 'NR==2{ print $1 }' boundary_box_ra.xyz )
	bb_range_3=$( awk 'NR==3{ print $1 }' boundary_box_ra.xyz )
	bb_range_4=$( awk 'NR==4{ print $1 }' boundary_box_ra.xyz )
	bb_azimu_1=$( awk 'NR==1{ print $2 }' boundary_box_ra.xyz )
	bb_azimu_2=$( awk 'NR==2{ print $2 }' boundary_box_ra.xyz )
	bb_azimu_3=$( awk 'NR==3{ print $2 }' boundary_box_ra.xyz )
	bb_azimu_4=$( awk 'NR==4{ print $2 }' boundary_box_ra.xyz )

	# Find min/max values for radar boundary box coordinates
	range_max=$bb_range_1
	range_min=$bb_range_1
	azimu_max=$bb_azimu_1
	azimu_min=$bb_azimu_1

	if [ $debug -ge 1 ]; then
	    echo "bb_range_1: $bb_range_1"
	    echo "bb_range_2: $bb_range_2"
	    echo "bb_range_3: $bb_range_3"
	    echo "bb_range_4: $bb_range_4"
	    echo "bb_azimu_1: $bb_azimu_1"
	    echo "bb_azimu_2: $bb_azimu_2"
	    echo "bb_azimu_3: $bb_azimu_3"
	    echo "bb_azimu_4: $bb_azimu_4"

	    echo "Intial range min/max: $range_min / $range_max"
	    echo "Intial azimu min/max: $azimu_min / $azimu_max"
	fi

	for corner_nr in {2..4}; do
	    rng_name="bb_range_$corner_nr"
	    azi_name="bb_azimu_$corner_nr"
	    if [ ! -z ${!rng_name} ]; then
		if [ $( echo "${!rng_name} > $range_max" | bc -l ) -eq 1 ]; then range_max=${!rng_name}; fi
		if [ $( echo "${!rng_name} < $range_min" | bc -l ) -eq 1 ]; then range_min=${!rng_name}; fi
	    fi
	    if [ ! -z ${!azi_name} ]; then
		if [ $( echo "${!azi_name} > $azimu_max" | bc -l ) -eq 1 ]; then azimu_max=${!azi_name}; fi
		if [ $( echo "${!azi_name} < $azimu_min" | bc -l ) -eq 1 ]; then azimu_min=${!azi_name}; fi
	    fi
	    
	    if [ $debug -ge 1 ]; then	
		echo "New range min/max: $range_min / $range_max"
		echo "New azimu min/max: $azimu_min / $azimu_max"
	    fi
	done


	# if [ $( echo "$bb_range_2 > $range_max" | bc -l ) == 1 ]; then range_max=$bb_range_2; fi
	# if [ $( echo "$bb_range_3 > $range_max" | bc -l ) == 1 ]; then range_max=$bb_range_3; fi
	# if [ $( echo "$bb_range_4 > $range_max" | bc -l ) == 1 ]; then range_max=$bb_range_4; fi

	# range_min=$bb_range_1
	# if [ $( echo "$bb_range_2 < $range_min" | bc -l ) == 1 ]; then range_min=$bb_range_2; fi
	# fi
	# if [ $( echo "$bb_range_3 < $range_min" | bc -l ) == 1 ]; then
	# 	range_min=$bb_range_3
	# fi
	# if [ $( echo "$bb_range_4 < $range_min" | bc -l ) == 1 ]; then
	# 	range_min=$bb_range_4
	# fi

	# azimu_max=$bb_azimu_1
	# if [ $( echo "$bb_azimu_2 > $azimu_max" | bc -l ) == 1 ]; then
	# 	azimu_max=$bb_azimu_2
	# fi
	# if [ $( echo "$bb_azimu_3 > $azimu_max" | bc -l ) == 1 ]; then
	# 	azimu_max=$bb_azimu_3
	# fi
	# if [ $( echo "$bb_azimu_4 > $azimu_max" | bc -l ) == 1 ]; then
	# 	azimu_max=$bb_azimu_4
	# fi

	# azimu_min=$bb_azimu_1
	# if [ $( echo "$bb_azimu_2 < $azimu_min" | bc -l ) == 1 ]; then
	# 	azimu_min=$bb_azimu_2
	# fi
	# if [ $( echo "$bb_azimu_3 < $azimu_min" | bc -l ) == 1 ]; then
	# 	azimu_min=$bb_azimu_3
	# fi
	# if [ $( echo "$bb_azimu_4 < $azimu_min" | bc -l ) == 1 ]; then
	# 	azimu_min=$bb_azimu_4
	# fi

	region_cut=$range_min"/"$range_max"/"$azimu_min"/"$azimu_max
	echo "Var region_cut set to "$region_cut
    fi
else 
    echo "No cutting to area of interest"
    region_cut=0
fi



# Unwrap interferometric phase

if [ -z $region_cut  ]; then
    region_cut=$( gmt grdinfo ${pth::-1}/amp1.grd -I- | cut -c3-20 )
fi

#if [ $( echo "$threshold_snaphu > 0" | bc -l ) -eq 1  ]; then
if [ $proc_ifg_unwrpd -eq 1 ]; then

    echo; echo "Unwrapping interferometric phase with Snaphu"; echo

    if [ $switch_land -eq 1 ]; then
	if [ ! -f landmask_ra.grd ]; then
            landmask.csh $region_cut
	fi
    fi    

    #
    # prepare the files adding the correlation mask
    #
    if [ $cut_to_aoi -eq 1 ]; then
	gmt grdcut mask.grd -R$region_cut -Gmask_patch.grd
	gmt grdcut corr.grd -R$region_cut -Gcorr_patch.grd
	gmt grdcut phasefilt.grd -R$region_cut -Gphase_patch.grd
    else
	ln -s mask.grd mask_patch.grd
	ln -s corr.grd corr_patch.grd
	ln -s phasefilt.grd phase_patch.grd
    fi
    #
    # create landmask
    #
    if [ -e landmask_ra.grd ]; then
	if [ $cut_to_aoi -eq 1 ]; then
	    gmt grdsample landmask_ra.grd -R$region_cut `gmt grdinfo -I phase_patch.grd` -Glandmask_ra_patch.grd
	else 
	    gmt grdsample landmask_ra.grd `gmt grdinfo -I phase_patch.grd` -Glandmask_ra_patch.grd
	fi
	gmt grdmath phase_patch.grd landmask_ra_patch.grd MUL = phase_patch.grd -V
    fi
    #
    # user defined mask 
    #
    if [ -e mask_def.grd ]; then
	if [ $cut_to_aoi -eq 1 ]; then
	    gmt grdcut mask_def.grd -R$region_cut -Gmask_def_patch.grd
	else
	    cp mask_def.grd mask_def_patch.grd
	fi
	gmt grdmath corr_patch.grd mask_def_patch.grd MUL = corr_patch.grd -V
    fi

    gmt grdmath corr_patch.grd $threshold_snaphu GE 0 NAN mask_patch.grd MUL = mask2_patch.grd
    gmt grdmath corr_patch.grd 0. XOR 1. MIN  = corr_patch.grd
    gmt grdmath mask2_patch.grd corr_patch.grd MUL = corr_tmp.grd 
    gmt grd2xyz phase_patch.grd -ZTLf -N0 > phase.in
    gmt grd2xyz corr_tmp.grd -ZTLf  -N0 > corr.in
    #
    # run snaphu
    #
    sharedir=`gmtsar_sharedir.csh`    

    if [ $defomax -eq 0 ]; then
	snaphu phase.in `gmt grdinfo -C phase_patch.grd | cut -f 10` -f $sharedir/snaphu/config/snaphu.conf.brief -g con_comp.out -c corr.in -o unwrap.out -v -s 
    else
	sed "s/.*DEFOMAX_CYCLE.*/DEFOMAX_CYCLE  $defomax/g" $sharedir/snaphu/config/snaphu.conf.brief > snaphu.conf.brief
	snaphu phase.in `gmt grdinfo -C phase_patch.grd | cut -f 10` -f snaphu.conf.brief -c corr.in -g con_comp.out -o unwrap.out -v -d
    fi
    #
    # convert to grd
    #
    gmt xyz2grd con_comp.out -ZTLu -r `gmt grdinfo -I- phase_patch.grd` `gmt grdinfo -I phase_patch.grd` -Gcon_comp.grd
    gmt xyz2grd unwrap.out -ZTLf -r `gmt grdinfo -I- phase_patch.grd` `gmt grdinfo -I phase_patch.grd` -Gtmp.grd
    gmt grdmath tmp.grd mask2_patch.grd MUL = tmp.grd
    #
    # detrend the unwrapped if DEFOMAX = 0 for interseismic
    #
    if [ $defomax -eq 0 ]; then
	gmt grdtrend tmp.grd -N3r -Dunwrap.grd
    else
	mv tmp.grd unwrap.grd
    fi
    #
    # landmask
    if [ -e landmask_ra.grd ]; then
	gmt grdmath unwrap.grd landmask_ra_patch.grd MUL = tmp.grd -V
	mv tmp.grd unwrap.grd
    fi
    #
    # user defined mask
    #
    if [ -e mask_def.grd ]; then
	gmt grdmath unwrap.grd mask_def_patch.grd MUL = tmp.grd -V
	mv tmp.grd unwrap.grd
    fi
    #
    #  plot the unwrapped phase
    #
    # gmt grdgradient unwrap.grd -Nt.9 -A0. -Gunwrap_grad.grd
    # tmp=`gmt grdinfo -C -L2 unwrap.grd`
    # limitU=`echo $tmp | awk '{printf("%5.1f", $12+$13*2)}'`
    # limitL=`echo $tmp | awk '{printf("%5.1f", $12-$13*2)}'`
    # std=`echo $tmp | awk '{printf("%5.1f", $13)}'`
    # gmt makecpt -Cseis -I -Z -T"$limitL"/"$limitU"/1 -D > unwrap.cpt
    # boundR=`gmt grdinfo unwrap.grd -C | awk '{print ($3-$2)/4}'`
    # boundA=`gmt grdinfo unwrap.grd -C | awk '{print ($5-$4)/4}'`
    # gmt grdimage unwrap.grd -Iunwrap_grad.grd -Cunwrap.cpt -JX6.5i -B"$boundR":Range:/"$boundA":Azimuth:WSen -X1.3i -Y3i -P -K > unwrap.ps
    # gmt psscale -D3.3/-1.5/5/0.2h -Cunwrap.cpt -B"$std":"unwrapped phase, rad": -O -E >> unwrap.ps

    
    # Clean up
    if [ $clean_up -ge 1 ]; then
	rm -f tmp.grd corr_tmp.grd unwrap.out tmp2.grd unwrap_grad.grd 
	rm -f phase.in corr.in 
	rm -f wrap.grd corr_patch.grd phase_patch.grd mask_patch.grd mask3.grd mask3.out
    fi

    # if [ $near_interp -eq 1 ]; then
    #   snaphu_interp.csh $threshold_snaphu $defomax $region_cut
    # else
    #   snaphu.csh $threshold_snaphu $defomax $region_cut
    # fi

    
else
    echo; echo "Skipping phase unwrapping ..."; echo
fi




# GEOCODING


#if [ -f raln.grd) rm raln.grd
#if [ -f ralt.grd) rm ralt.grd

# if [ $threshold_geocode != 0 ]; then



# gmt grdmath phasefilt.grd mask.grd MUL = phasefilt_mask.grd -V


# If activated, mask phase and phase gradient using correlation

if [ $( echo "$threshold_geocode > 0" | bc -l ) -eq 1 ]; then
    echo; echo "Preparing coherence masks for phase datasets (threshold $threshold_geocode)"
    gmt grdmath corr.grd $threshold_geocode GE 0 NAN mask.grd MUL = mask2.grd -V
    if [ -e phase.grd ]; then
	gmt grdmath phase.grd mask2.grd MUL = phase_mask.grd
    fi
    if [ -e xphase.grd ]; then
	gmt grdmath xphase.grd mask2.grd MUL = xphase_mask.grd
	gmt grdmath yphase.grd mask2.grd MUL = yphase_mask.grd
    fi
    if [ -e unwrap.grd ]; then 
	gmt grdcut mask2.grd `gmt grdinfo unwrap.grd -I-` -Gmask3.grd
	gmt grdmath unwrap.grd mask3.grd MUL = unwrap_mask.grd
    fi
    if [ -e phasefilt.grd ]; then 
	gmt grdmath phasefilt.grd mask2.grd MUL = phasefilt_mask.grd
    fi
else
    echo; echo "Skipping coherence masking for phase datasets (threshold $threshold_geocode)"
    if [ -e xphase.grd ]; then
	mv xphase.grd xphase_mask.grd
	mv yphase.grd yphase_mask.grd
    fi
    if [ -e unwrap.grd ]; then 
	mv unwrap.grd unwrap_mask.grd
    fi
    if [ -e phasefilt.grd ]; then 
	mv phasefilt.grd phasefilt_mask.grd
    fi
fi


# TODO: use vars from config file
# if [ -e $bbox_file ]; then
# lon_1=$( awk 'NR==1{ print $1 }' $bbox_file )
# lon_2=$( awk 'NR==2{ print $1 }' $bbox_file )
# lat_1=$( awk 'NR==1{ print $2 }' $bbox_file )
# lat_2=$( awk 'NR==2{ print $2 }' $bbox_file )
if [ $( echo "$lon_1 > $lon_2" | bc -l ) -eq 1 ]; then
    lon_max=$lon_1
    lon_min=$lon_2
else
    lon_max=$lon_2
    lon_min=$lon_1
fi
if [ $( echo "$lat_1 > $lat_2" | bc -l ) -eq 1 ]; then
    lat_max=$lat_1
    lat_min=$lat_2
else
    lat_max=$lat_2
    lat_min=$lat_1
fi

cut_coords=$lon_min"/"$lon_max"/"$lat_min"/"$lat_max
#fi 


#  Reproject the phase to lon/lat space

echo; echo "Geocoding result datasets to WGS84 ..."; echo

maker=$0:t
today=$( date )
remarked=$( echo by $USER on $today with $maker )

# echo remarked is $remarked



if [ $proc_coherences -eq 1 ]; then
    echo; echo "Projecting coherence to geographic coordinates"; echo
    proj_ra2ll.csh trans.dat corr.grd corr_ll.grd           
    if [ $cut_to_aoi -eq 1 ]; then
	gmt grdcut corr_ll.grd -Gcorr_ll.grd -R$cut_coords -V
    fi
    gmt grdedit -D//"dimensionless"/1///"$PWD:t geocoded correlation"/"$remarked"      corr_ll.grd
else 
    echo; echo "Skipping reprojection of coherence (proc_coherences set to ${proc_coherences})"
fi

# proj_ra2ll.csh trans.dat phase.grd       phase_ll.grd 
# gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase"/"$remarked"                   phase_ll.grd

# if [ $proc_ifg_filtrd -eq 1 ]; then
#     echo; echo "Projecting filtered phase to geographic coordinates"; echo
#     proj_ra2ll.csh trans.dat phasefilt.grd   phasefilt_ll.grd
#     if [ $cut_to_aoi -eq 1 ]; then
# 	gmt grdcut phasefilt_ll.grd -Gphasefilt_ll.grd -R$cut_coords -V
#     fi
#     gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase after filtering"/"$remarked"   phasefilt_ll.grd
# else 
#     echo; echo "Skipping reprojection of filtered phase (proc_ifg_filtrd set to $proc_ifg_filtrd)"
# fi


# if [ $proc_ifg_filtrd -eq 1 ]; then
# echo; echo "Projecting masked phase to geographic coordinates"; echo
# proj_ra2ll.csh trans.dat phase_mask.grd  phase_mask_ll.grd
# if [ $cut_to_aoi -eq 1 ]; then
#     gmt grdcut phase_mask_ll.grd -Gphase_mask_ll.grd -R$cut_coords -V
# fi
# gmt grdedit -D//"radians"/1///"$PWD:t wrapped phase after masking"/"$remarked"     phase_mask_ll.grd


if [ $proc_amplit_ifg -eq 1 ]; then
    echo; echo "Projecting interferogram amplitude to geographic coordinates"; echo
    proj_ra2ll.csh trans.dat display_amp.grd display_amp_ll.grd
    if [ $cut_to_aoi -eq 1 ]; then
	gmt grdcut display_amp_ll.grd -Gdisplay_amp_ll.grd -R$cut_coords -V
    fi
    gmt grdedit -D//"dimensionless"/1///"$PWD:t amplitude"/"$remarked"                  display_amp_ll.grd
else 
    echo; echo "Skipping reprojection of interf. amplitude (proc_amplit_ifg set to ${proc_amplit_ifg})"
fi


if [ $proc_amplitudes -eq 1 ]; then
    echo; echo "Projecting master raw amplitude (dB) to geographic coordinates"; echo
    proj_ra2ll.csh trans.dat amp1-db.grd amp1_db_ll.grd
    if [ $cut_to_aoi -eq 1 ]; then
	gmt grdcut amp1_db_ll.grd -Gamp1_db_ll.grd -R$cut_coords -V
    fi
    gmt grdedit -D//"dimensionless"/1///"$PWD:t amplitude (dB)"/"$remarked"                 amp1_db_ll.grd

    echo; echo "Projecting slave raw amplitudes (dB) to geographic coordinates"; echo
    proj_ra2ll.csh trans.dat amp2-db.grd amp2_db_ll.grd
    if [ $cut_to_aoi -eq 1 ]; then
	gmt grdcut amp2_db_ll.grd -Gamp2_db_ll.grd -R$cut_coords -V
    fi
    gmt grdedit -D//"dimensionless"/1///"$PWD:t amplitude (dB)"/"$remarked"                  amp2_db_ll.grd
else 
    echo; echo "Skipping reprojection of amplitudes [dB] (proc_amplitudes set to ${proc_amplitudes})"
fi



if [ $proc_ifg_grdnts -eq 1 ]; then    
    echo; echo "Projecting masked xphase to geographic coordinates"; echo
    proj_ra2ll.csh trans.dat xphase_mask.grd xphase_ll.grd
    if [ $cut_to_aoi -eq 1 ]; then
	gmt grdcut xphase_ll.grd -Gxphase_ll.grd -R$cut_coords -V
    fi
    gmt grdedit -D//"radians"/1///"$PWD:t xphase"/"$remarked"                          xphase_ll.grd
    echo; echo "Projecting masked yphase to geographic coordinates"; echo
    proj_ra2ll.csh trans.dat yphase_mask.grd yphase_ll.grd
    if [ $cut_to_aoi -eq 1 ]; then
	gmt grdcut yphase_ll.grd -Gyphase_ll.grd -R$cut_coords -V
    fi
    gmt grdedit -D//"radians"/1///"$PWD:t yphase"/"$remarked"                          yphase_ll.grd
else 
    echo; echo "Skipping reprojection of phase gradients (proc_ifg_grdnts set to ${proc_ifg_grdnts})"
fi



if [ $proc_ifg_unwrpd -eq 1 ]; then
    if [ -e unwrap_mask.grd ]; then
	echo; echo "Projecting masked unwrapped phase to geographic coordinates"; echo
	proj_ra2ll.csh trans.dat unwrap_mask.grd unwrap_mask_ll.grd 
	if [ $cut_to_aoi -eq 1 ]; then
	    gmt grdcut unwrap_mask_ll.grd -Gunwrap_mask_ll.grd -R$cut_coords -V
	fi
	gmt grdedit -D//"radians"/1///"PWD:t unwrapped, masked phase"/"$remarked"        unwrap_mask_ll.grd
    fi
else 
    echo; echo "Skipping reprojection of unwrapped interferogram (proc_ifg_unwrpd set to ${proc_ifg_unwrpd})"
fi


# if [ -e unwrap.grd ]; then
#     echo; echo "Projecting unwrapped phase to geographic coordinates"; echo
#     proj_ra2ll.csh trans.dat unwrap.grd unwrap_ll.grd
#     if [ $cut_to_aoi -eq 1 ]; then
# 	gmt grdcut unwrap_ll.grd -Gunwrap_ll.grd -R$cut_coords -V
#     fi
#     gmt grdedit -D//"radians"/1///"PWD:t unwrapped phase"/"$remarked"               unwrap_ll.grd
# fi

if [ $proc_ifg_filtrd -eq 1 ]; then
    if [ -e phasefilt_mask.grd ]; then
	echo; echo "Projecting filtered masked phase to geographic coordinates"; echo
	proj_ra2ll.csh trans.dat phasefilt_mask.grd phasefilt_mask_ll.grd
	if [ $cut_to_aoi -eq 1 ]; then
	    gmt grdcut phasefilt_mask_ll.grd -Gphasefilt_mask_ll.grd -R$cut_coords -V
	fi
	gmt grdedit -D//"phase in radians"/1///"PWD:t wrapped phase masked filtered"/"$remarked"   phasefilt_mask_ll.grd
    fi
else 
    echo; echo "Skipping reprojection of filtered interferogram (proc_ifg_filtrd set to ${proc_ifg_filtrd})"
fi


if [ $proc_ifg_concmp -eq 1 ]; then
    if [ -e con_comp.grd ]; then
	echo; echo "Projecting Snaphu connected components to geographic coordinates"; echo
	proj_ra2ll.csh trans.dat con_comp.grd con_comp_ll.grd
	if [ $cut_to_aoi -eq 1 ]; then
	    gmt grdcut con_comp_ll.grd -Gcon_comp_ll.grd -R$cut_coords -V
	fi
	gmt grdedit -D//"dimensionless"/1///"PWD:t connected components"/"$remarked" con_comp_ll.grd
    fi
else 
    echo; echo "Skipping reprojection of Snaphu's connected components (proc_ifg_concmp set to ${proc_ifg_concmp})"
fi



echo; echo "Geocoding finished"; echo

# 
# proj_ra2ll.csh trans.dat phasefilt.grd phasefilt_ll.grd
# proj_ra2ll.csh trans.dat phasefilt_mask.grd phasefilt_mask_ll.grd
# proj_ra2ll.csh trans.dat corr.grd corr_ll.grd
# proj_ra2ll.csh trans.dat con_comp.grd con_comp_ll.grd
# # gmt makecpt -Crainbow -T-3.15/3.15/0.05 -Z > phase.cpt
# #  BT=$( gmt grdinfo -C corr.grd | awk '{print $7}' )
# # gmt makecpt -Cgray -T0/$BT/0.05 -Z > corr.cpt
# # grd2kml.csh phasefilt_ll phase.cpt
# # grd2kml.csh corr_ll corr.cpt

# if [ -f unwrap.grd ]; then
#   gmt grdmath unwrap.grd mask.grd MUL=unwrap_mask.grd -V
#   proj_ra2ll.csh trans.dat unwrap.grd unwrap_ll.grd
#   proj_ra2ll.csh trans.dat unwrap_mask.grd unwrap_mask_ll.grd
#   #  BT=$( gmt grdinfo -C unwrap.grd | awk '{print $7}' )
#   #  BL=$( gmt grdinfo -C unwrap.grd | awk '{print $6}' )
#   # gmt makecpt -T$BL/$BT/0.5 -Z > unwrap.cpt
#   # grd2kml.csh unwrap_mask_ll unwrap.cpt
#   # grd2kml.csh unwrap_ll unwrap.cpt
# fi




# rm -f tmp_phaselist tmp_corrlist tmp_masklist *.eps *.bb
