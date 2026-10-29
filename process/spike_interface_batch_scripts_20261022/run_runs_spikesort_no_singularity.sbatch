#!/bin/bash
#SBATCH --job-name=si-sort
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --chdir=/users/jmurph14/docs/spikeInterfaceBatch
#SBATCH --output=/users/jmurph14/docs/spikeInterfaceBatch/logs/%x-%A.out
#SBATCH --error=/users/jmurph14/docs/spikeInterfaceBatch/logs/%x-%A.err

set -euo pipefail

MANIFEST="/users/jmurph14/docs/spikeInterfaceBatch/recordings.tsv"
OUTPUT_ROOT="$HOME/scratch/spikeinterface-results"
PYTHON_SCRIPT="/users/jmurph14/docs/spikeInterfaceBatch/run_sorter_jm.py"

source /users/jmurph14/python_virtual_environments/spikeInterface/bin/activate

if [[ ! -f "$MANIFEST" ]]; then
    echo "Manifest not found: $MANIFEST" >&2
    exit 1
fi
if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    echo "Python script not found: $PYTHON_SCRIPT" >&2
    exit 1
fi

mkdir -p "$OUTPUT_ROOT"
python -u "$PYTHON_SCRIPT" --manifest "$MANIFEST" --output-root "$OUTPUT_ROOT"
