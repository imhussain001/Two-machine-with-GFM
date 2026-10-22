# Two-Machine Power System with a Grid-Forming Converter

MATLAB/Simulink load-frequency study of a two-area power system with a grid-forming
converter (GFM). Using the same disturbance in every case, it compares primary control
(governor droop), secondary control (AGC) and the frequency support from a GFM.

The test system, operating point and parameters follow Rodríguez-Amenedo & Arnaltes Gómez,
*IEEE Access* 9 (2021), Fig. 14 and Tables 2 and 5–7 (see [References](#references)).

## System

```
 Area 1                                             Area 2
 SG1 (1500 MVA) --T1-- bus 2 ==== 2 x 0.2 pu ==== bus 3 --T2-- SG2 (4000 MVA, slack)
  bus 1                 |       tie-lines                |       bus 4
               GFM --T5-+                              Load 4000 MW
             (1500 MVA) |
              bus 5    Load 1250 MW
```

- **Model type:** phasor (RMS) model on a 100 MVA base at 50 Hz. The network is solved
  algebraically at every time step.
- **Network:** constant-impedance loads. Every source (SG1, SG2, GFM) is connected as a
  Norton injection behind its reactance.
- **Initial state:** a Newton load flow inside each model sets it, using SG1 = 1350 MW and
  GFM = 0 MW, with SG2 as the slack. Each model starts in steady state, with
  max |dx/dt(0)| ≈ 1e-15.
- **Disturbance:** a −100 MW load step (load rejection) at bus 2 at t = 1 s.
- **Primary control:** IEEEG1 governor with 5 % droop (K = 20) and a reheat steam turbine
  (T4 = 0.3 s, T5 = 7 s, T6 = 0.6 s).
- **AGC:** tie-line bias integral control on the area control error (ACE).
  ACE1 = ΔPtie + B1·Δf1 and ACE2 = −ΔPtie + B2·Δf2, with dPref_i/dt = −(Ki/kS_i)·ACE_i.
- **GFM:** fixed |Eg| behind xg = 0.15 pu (own base), P-f droop Rg = 0.05, an optional
  POD-P washout loop (Kw = 3, Tw = 1 s, switched by `pod_on`), and bus-5 frequency
  measured through a Tf = 0.02 s filter.

The full equations are in `twomachine_gfm_equations.pdf` (LaTeX source in `.tex`) in
each model folder.

## Repository layout

| Folder | Synchronous generator model |
|---|---|
| `Two machine with GFM_0_0_model/` | Model 0.0, classical: constant E′ behind x′d = 0.34 pu, H = 6.3 s, D = 0, no exciter |
| `Two machine with GFM_1_0_model/` | Model 1.0: field winding (x′d, T′d0 = 6.47 s), IEEE ST1 exciter (KA = 200), H = 6.3 s, D = 2 |

Both folders have the same four study folders. Each study folder holds its own copies of
the case models and runs on its own, without needing any other folder:

| Study folder | Script | Compares |
|---|---|---|
| `StudyA_supplementary_control/` | `run_studyA.m` | Case 1 (primary only) vs Case 2 (primary + AGC) |
| `StudyB_GFM_with_AGC/` | `run_studyB.m` | Case 2 vs Case 3 (primary + AGC + GFM) |
| `StudyC_GFM_primary_only/` | `run_studyC.m` | Case 1 vs Case 4 (Case 3 model run with Ki = 0, i.e. GFM without AGC) |
| `Comparison_all_three_cases/` | `run_comparison.m` | Cases 1, 2 and 3 |

Case models:

- `case1_primary_control.slx`: governor droop only (4-bus network, no GFM)
- `case2_primary_AGC.slx`: droop + AGC (4-bus network, no GFM)
- `case3_primary_AGC_GFM.slx`: droop + AGC + GFM at bus 5 (5-bus network)

Other files:

- Reference PDFs and notes are in the model folders.
- The `backup_2026-10-21_*` folders hold earlier versions of the models.

## Settings that differ between the two folders

| Parameter | 0.0 folder | 1.0 folder |
|---|---|---|
| AGC integral gain `Ki` | 0.02 (low gain, AGC ≈ 6–7× slower than primary control) | 0.1 |
| GFM control (`pod_on`) | 0: P-f droop only | 1: droop + POD-P |
| Simulation time `t_stop` | 150 s | 100 s |

## How to run

Requires MATLAB and Simulink. The models were saved in R2024b.

```matlab
cd 'Two machine with GFM_0_0_model/Comparison_all_three_cases'
run_comparison
```

Each script does the following:

1. Simulates its cases.
2. Prints a table to the Command Window: peak frequency deviation, RoCoF, final
   frequency, ΔPm, tie-line flow and GFM power.
3. Saves the figures (`*_SG_frequencies.png`, `*_power.png`, `*_tie_line.png` and, for
   Studies A–C, `*_comparison.png`) in the study folder.

All model data lives in each model's Model Workspace (Model Explorer → Model Workspace,
"MATLAB Code"), including the load flow and the initialisation. To change a value, edit
it there and click **Reinitialize from Source**.

## Example results (0.0 folder, t_stop = 150 s)

| | Case 1 (no AGC) | Case 2 (AGC) | Case 3 (AGC + GFM) | Case 4 (GFM, no AGC) |
|---|---|---|---|---|
| SG1 peak frequency deviation | 112.0 mHz | 111.3 mHz | 78.2 mHz | 78.6 mHz |
| Final frequency | 50.037 Hz | 50.001 Hz | 50.001 Hz | 50.031 Hz |
| Final tie-line change | 76.7 MW | 0.8 MW | 1.0 MW | 63.0 MW |
| Peak GFM active power | — | — | 54.7 MW | 54.7 MW |

What the cases show:

- **The GFM** cuts the peak frequency deviation by about 30 % and the peak tie-line
  swing by about 20 %.
- **The AGC** brings the frequency back to 50 Hz and the tie-line flow back to its
  scheduled value. At Ki = 0.02 this takes about 125 s.

## Assumptions and limitations

- **Phasor (RMS) model:** a balanced, positive-sequence, fundamental-frequency model. It
  does not represent EMT effects or the GFM's inner current and voltage loops.
- **Loads:** constant impedance at unity power factor.
- **GFM:** an ideal voltage source with fixed |Eg|. There is no current limit and no
  DC-side dynamics.
- **SG model 0.0:** has no damper or excitation dynamics. Model 1.0 represents the
  missing dampers with D = 2.

## References

1. J. L. Rodríguez-Amenedo and S. Arnaltes Gómez, "Damping low-frequency oscillations in
   power systems using grid-forming converters," *IEEE Access*, vol. 9, pp. 158984–158997,
   2021, doi: 10.1109/ACCESS.2021.3130333.
2. J. L. Rodríguez Amenedo and S. Arnaltes, "Damping power system oscillations using
   grid-forming converters," in *Grid-Forming Power Inverters: Control and Applications*,
   N. Mohammed, H. Haes Alhelou and B. Bahrani, Eds. CRC Press, 2023, ch. 8, pp. 157–177,
   doi: 10.1201/9781003302520-8.
