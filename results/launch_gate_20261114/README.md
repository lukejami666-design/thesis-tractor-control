# Candidate J fixed-parameter archive — 2026-11-14

Status: **engineering checks failed; not deployed; original performance targets failed**. Traction-margin conclusion: **insufficient evidence**. Read [feasibility_report.md](feasibility_report.md) first, then [launch_gate_control_20261114.md](launch_gate_control_20261114.md).

- `models/launch_gate_exp.slx`: unmodified saved experimental controller; `launch_gate_diag.slx`: same controller with read-only logs. Do not overwrite the formal model with either file.
- `data/diag_gate_L2_U08.mat` and `diag_baseline_L2_U08.mat`: 5001 samples, 1 ms, 0–5 s, direct solver Fx/Fy/Fz and raw wheel speed plus command diagnostics.
- `data/candidate_J_full_parameters.mat`: authoritative complete P. The historical overrides MAT has only five fields and is not a complete initialization.
- `src/`: actual archived launch code, chart state labels/transitions, shared allocation interfaces and controlled copy of public parameter source.
- `event_timeline.*`, `metrics.*`, `torque_decomposition_1ms.csv`, `engineering_checks.json`, `figures/`: recomputed diagnostics.
- `validation_version_index.csv`: historical first-correction nine-case matrix versus five saved J cases; no claim of a complete nine-case J rerun.
- `archive_manifest.json`: relative-path file sizes and SHA-256. User formal model backups stay local under `D:/毕设/launch_gate_20261114/feasibility_local` and are not uploaded.

## Reproduction

Offline analysis (Python with numpy, scipy and matplotlib):

```text
python analyze_feasibility.py
```

The historical-ingest scripts `prepare_archive.py` and `inspect_sources.py` document this machine's original paths and are **not** needed for ordinary offline analysis. For offline analysis, the archive includes the necessary historical comparison data; version-index ingestion uses the documented optional historical source directory if it still exists.

Simulation requires MATLAB R2022b/Simulink and a separately installed, working TruckSim 2019.0 solver with the matching local vehicle configuration. Commercial vehicle/tire data and license files are intentionally not redistributed. Validate `vehicle_configuration.json` run/deck hashes and EXPORT ordering before reproduction. Merely opening the SLX does not establish matching plant configuration.

In an existing prepared MATLAB session with P and gate_throttle present, add this folder to the MATLAB path and run:

```matlab
archiveDir = fileparts(which('run_feasibility'));
run_feasibility(archiveDir, '<your matching local vehicle data directory>');
check_protection(archiveDir);
```

The simulation script derives the archive path from its own location by default and reads full P from the saved candidate, rather than relying on a machine-specific public parameter file. It restores existing P, gate_throttle, current directory and MATLAB path on exit, and does not touch the formal model. Review all warnings. Protection replay is a function-level test, not an integrated vehicle fault-injection test.

No new tuning or control repair is included. The ineffective 1e12 single-wheel bounds and gate_diag repeated-target defect are preserved as the diagnosed implementation, not silently corrected.
