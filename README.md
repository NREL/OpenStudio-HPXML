OpenStudio-HEScore
===============

An OpenStudio/EnergyPlus simulation workflow that operates on a HPXML file produced by DOE's Home Energy Score (HEScore).

**Unit Test Status:** [![CircleCI](https://circleci.com/gh/NREL/OpenStudio-WAP.svg?style=svg&circle-token=18b77833ba86b38bb222bb5075d3796a5c9698f1)](https://circleci.com/gh/NREL/OpenStudio-WAP/tree/master)

## Setup

1. Either download [OpenStudio 2.7.1](https://github.com/NREL/OpenStudio/releases/tag/v2.7.1) (at a minimum, install the Command Line Interface and EnergyPlus components) or use the [nrel/openstudio docker image](https://hub.docker.com/r/nrel/openstudio).
2. Clone or download this repository's source code. 
3. To obtain all available weather files, run:  
```openstudio workflow/run_simulation.rb --download-weather``` 

## Running

Run the WAP simulation on a provided sample HPXML file:  
```openstudio --no-ssl workflow/run_simulation.rb -x workflow/sample_files/sample_buildings_house_with_crawl_space.xml```  

Run `openstudio workflow/run_simulation.rb -h` to see all available commands/arguments.
