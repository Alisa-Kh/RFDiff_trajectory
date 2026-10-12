#!/bin/sh

#SBATCH --gres=gpu:1
#SBATCH -t 2:20:00
#SBATCH --mem 4G
#SBATCH -p h100
##SBATCH -q gpu

source /work/lpdi/users/alisa/miniconda3/etc/profile.d/conda.sh

conda activate SE3nv

inputf=$(realpath $1)

nterm_add=$2
cterm_add=$3
chain=$4
nconf=$5

input_dir=$(echo "$inputf" | rev | cut -d '/' -f 2- | rev)
filename=$(basename "$inputf" | cut -d '.' -f 1)

first_res=$(grep 'CA' "$inputf" | head -1 | gawk '{print $6}')
last_res=$(grep 'CA' "$inputf" | tail -1 | awk '{print $6}')


prot_len=$((last_res - first_res + 1))

first_res_from_N=$((1 + nterm_add))
last_res_from_C=$((last_res - cterm_add))

echo $first_res
echo $last_res

if [[ $nterm_add -gt 0 ]] && [[ $cterm_add -gt 0 ]]
   then
    outdir=$input_dir/$filename/remodel_termini/NC_term
    filename="$filename"_NC
elif [[ $nterm_add -gt 0 ]]
   then
    outdir=$input_dir/$filename/remodel_termini/N_term
    filename="$filename"_N
elif [[ $cterm_add -gt 0 ]]
   then
    outdir=$input_dir/$filename/remodel_termini/C_term
    filename="$filename"_C
fi

mkdir -p $outdir

python scripts/run_inference.py inference.output_prefix="$outdir"/"$filename" \
                                inference.input_pdb="$inputf" inference.cautious=False \
                                'contigmap.contigs=['$nterm_add'/'$chain$first_res_from_N'-'$last_res_from_C'/'$cterm_add']'  \
                                inference.num_designs="$nconf" contigmap.length="$prot_len"-"$prot_len"
