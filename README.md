OpenStudio-HEScore
===============

An OpenStudio/EnergyPlus simulation workflow that operates on a HPXML file produced by DOE's Home Energy Score (HEScore).

[![ci](https://github.com/NREL/OpenStudio-HEScore/workflows/ci/badge.svg)](https://github.com/NREL/OpenStudio-HEScore/actions)

## Setup

1. Either download [OpenStudio 3.3.0](https://github.com/NREL/OpenStudio/releases/tag/v3.3.0) (at a minimum, install the Command Line Interface and EnergyPlus components) or use the [nrel/openstudio docker image](https://hub.docker.com/r/nrel/openstudio).
2. Clone or download this repository's source code. 
3. To obtain all available weather files, run:  
```openstudio workflow/run_simulation.rb --download-weather``` 

## Running

Run the HEScore simulation on a provided HPXML file:  
```openstudio workflow/run_simulation.rb -j workflow/regression_files/Base.json```  

Run `openstudio workflow/run_simulation.rb -h` to see all available commands/arguments.

## Outputs

Upon completion, simulation results disaggregated by end use and month are available in the `workflow/results/results.json` file. 

There is also a `workflow/results/HEScoreDesign.xml`, which is the result of applying the HEScore ruleset (e.g., geometry assumptions, etc.) and is the input to the EnergyPlus simulation.

Finally, there is a `workflow/HEScoreDesign` directory that contains the EnergyPlus input and output files.
