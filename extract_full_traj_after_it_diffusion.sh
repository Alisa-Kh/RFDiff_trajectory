PROTOCOL_ROOT=$(dirname "$(realpath $BASH_SOURCE)")
outdir=$1
for a in \
 $(cat log_tran_path | awk '{print $NF}' | rev | cut -d '/' -f 1 | rev | cut -d '.' -f 1)
  do
    python $PROTOCOL_ROOT/split_models.py traj/"$a"_pX0_traj.pdb "$outdir"
  done