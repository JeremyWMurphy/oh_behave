import argparse
import csv
from pathlib import Path

import spikeinterface.extractors as se
import spikeinterface.preprocessing as spre
import spikeinterface.sorters as ss
import spikeinterface.core as sc
from spikeinterface.sortingcomponents.motion import interpolate_motion


def process_recording(raw, output_path: Path) -> None:
    output_path.mkdir(parents=True, exist_ok=True)

    preprocessing_list = [
    {'name':'phase_shift'},
    {'name':'scale_to_physical_units'},
    {'name': 'highpass_filter', 'params': {'freq_min': 500.}},
    {'name': 'gaussian_filter', 'params': {'freq_max': 5000.}},
    {'name':'resample','params': {'resample_rate':15e3}},
    ]

    concatenated_rec = spre.apply_preprocessing_pipeline(raw, preprocessing_list)

    bad_channels, labels = spre.detect_bad_channels(
         concatenated_rec, method="coherence+psd"
    )

    interpolated = spre.interpolate_bad_channels(
        recording=concatenated_rec, bad_channel_ids=bad_channels
    )

    all_chan_ids = interpolated.get_channel_ids()
    # this is a pretty conservative guess
    out_of_brain = all_chan_ids[all_chan_ids.size-133:] 

    cleaned = spre.detect_and_remove_bad_channels(
        recording=interpolated, bad_channel_ids=out_of_brain)

    motion_preset = 'dredge'
    motion, motion_info = spre.compute_motion(
        cleaned,
        preset=motion_preset,
        output_motion_info=True,
        # Pass the DREDge parameters directly into the motion estimator block
        estimate_motion_kwargs={"batching_mode": "full"} 
    )

    motion_corrected = interpolate_motion(recording=cleaned, motion=motion)

    whitened = spre.whiten(motion_corrected)
    referenced = spre.common_reference(whitened,operator='median', reference='global')
    ref_no_white = spre.common_reference(motion_corrected,operator='median', reference='global')

    sorters = ['kilosort4','spykingcircus2','tridesclous2']

    for sorter in sorters:
        
        sorted = ss.run_sorter(
            sorter_name=sorter,
            recording=referenced,
            output_folder=output_path / sorter,
            verbose=True,
        )

        sort_analyzer = sc.create_sorting_analyzer(sorted,ref_no_white,sparse=True,format='memory')
        compute_dict = {
            'random_spikes': {},
            'noise_levels':{},
            'waveforms':{},
            'principal_components': {'n_components': 3, 'mode': 'by_channel_local'},
            'templates': {},
            'template_similarity':{},
            'spike_locations':{},
            'spike_amplitudes':{},
            'correlograms':{},
            'isi_histograms':{},
            'quality_metrics':{},
            'template_metrics':{},
        }

        sort_analyzer.compute(compute_dict)
        sort_analyzer.save_as(folder=output_path / sorter / 'sorting_analyzer/',format='binary_folder')


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()

    recordings = []
    with args.manifest.open(newline="") as manifest:
        for line_number, row in enumerate(csv.reader(manifest, delimiter="\t"), start=1):
            if not row or all(not field.strip() for field in row):
                continue
            if len(row) != 2 or not all(field.strip() for field in row):
                raise ValueError(
                    f"{args.manifest}:{line_number}: expected recording_id and input_path "
                    "separated by a tab"
                )
            recordings.append((row[0].strip(), Path(row[1].strip())))

    if not recordings:
        raise ValueError(f"No recordings found in manifest: {args.manifest}")

    recording_ids = [recording_id for recording_id, _ in recordings]
    if len(recording_ids) != len(set(recording_ids)):
        raise ValueError(f"Duplicate recording_id in manifest: {args.manifest}")

    raw_recordings = [
        se.read_openephys(
            input_path,
            stream_name="Record Node 101#Neuropix-PXI-112.ProbeA",
        )
        for _, input_path in recordings
    ]
    concatenated = sc.concatenate_recordings(raw_recordings)

    output_path = args.output_root / "concatenated"
    print(f"Sorting {len(raw_recordings)} concatenated recordings", flush=True)
    print(f"Output: {output_path}", flush=True)
    process_recording(concatenated, output_path)


if __name__ == "__main__":
    main()