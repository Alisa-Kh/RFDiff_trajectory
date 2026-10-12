#!/bin/sh
#SBATCH --gres=gpu:1
#SBATCH -t 2:15:00
#SBATCH --mem 4G
#SBATCH -p l40s
##SBATCH -q gpu

inputf=$(realpath $1) # initial conformation
input_dir=$(echo "$inputf" | rev | cut -d '/' -f 2- | rev)
infilename=`basename "$inputf" | cut -d '.' -f 1`
ref=$2 # final conformation
nterm_add=$3
cterm_add=$4
output_dir=$5

chain=$(echo $inputf | rev | cut -c 1 | rev)

RMS_LOSS_INIT_WEIGHT=10
UNFOLDING_WEIGHT=0.05
#UNFOLD_WEIGHT_FOR_REFOLDING=0.01
T_INIT=20

first_res=$(grep 'CA' "$inputf" | head -1 | gawk '{print $6}')
last_res=$(grep 'CA' "$inputf" | tail -1 | gawk '{print $6}')

first_res_from_N=$((1 + nterm_add))
last_res_from_C=$((last_res - cterm_add))
prot_len=$((last_res - first_res + 1))
output_prefix=$output_dir/"$infilename"_refolded

T=$T_INIT
RMS_LOSS_WEIGHT=$RMS_LOSS_INIT_WEIGHT
rmsd_report=$output_dir/design_rmsds_from_target_w"$RMS_LOSS_INIT_WEIGHT"_T"$T_INIT"
#bb_val_report=$output_dir/bb_quality_w"$RMS_LOSS_INIT_WEIGHT"_T"$T_INIT"

cur_rmsd=100
i=1

#rm -f $rmsd_report

# first let's unfold it

source /work/lpdi/users/alisa/miniconda3/etc/profile.d/conda.sh

i=1
while [ "$cur_rmsd" -ge 1 ] && [ "$i" -le 20 ]

 do
  conda activate SE3nv
  which python
  scripts/run_inference.py inference.input_pdb="$inputf" \
                           'contigmap.contigs=['$nterm_add'/A'$first_res_from_N'-'$last_res_from_C'/'$cterm_add']' \
                           diffuser.partial_T="$T" \
                           inference.cautious=False inference.num_designs=10  \
                           inference.output_prefix="$output_prefix"_"$i" inference.deterministic=False \
                           'potentials.guiding_potentials=["type:ca_constraints,weight:'$RMS_LOSS_WEIGHT'","type:unfolding,weight:'$UNFOLDING_WEIGHT'"]' \
                           inference.reference_struct="$ref" >> "$output_dir"/rfdiff_log


  conda deactivate
  which python
  for design in "$output_prefix"_"$i"_?.pdb
   do
    # TMalign $ref $design -I $output_dir/align.txt
     rmsd=$(TMalign $ref $design -I $output_dir/align.txt | grep 'TM/Lali/rmsd' | awk '{print $NF}')
     echo $design $rmsd >> $rmsd_report
   done

  next_input=$(sort -nk2 $rmsd_report | head -1 | awk '{print $1}')
  cur_rmsd=$(sort -nk2 $rmsd_report | head -1 | awk '{print $2}')
  echo Step "$i": Current min RMSD: "$cur_rmsd". Continuing with "$next_input" >> "$output_dir"/log_tran_path
  inputf=$next_input

  i=$((i+1))

  # round the rmsd for if statements:
  cur_rmsd=$(echo "$cur_rmsd" | awk '{print int($1)}')

  if [ "$i" -eq 2 ]; then UNFOLDING_WEIGHT=0.04;
  elif [ "$i" -eq 3 ]; then UNFOLDING_WEIGHT=0.03;
  elif [ "$i" -eq 4 ]; then UNFOLDING_WEIGHT=0.02;
  elif [ "$i" -eq 5 ]; then UNFOLDING_WEIGHT=0.01;
  elif [ "$i" -eq 6 ]; then UNFOLDING_WEIGHT=0;
  fi

#  if [ "$cur_rmsd" -lt 4 ] && [ "$cur_rmsd" -ge 1 ] && [ "$i" -lt 20 ]
#    then
#      T=15
  if [ "$cur_rmsd" -lt 1 ] || [ "$i" -ge 20 ] # at last iteration or if rmsd less than 1 refine with 10 timesteps and no potential
    then
      T=10
      RMS_LOSS_WEIGHT=0
  fi

  echo $i

done
