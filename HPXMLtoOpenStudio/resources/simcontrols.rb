# frozen_string_literal: true

class SimControls
  def self.apply(model, header, apply_ashrae140_assumptions)
    sim = model.getSimulationControl
    sim.setRunSimulationforSizingPeriods(false)

    tstep = model.getTimestep
    tstep.setNumberOfTimestepsPerHour(60 / header.timestep)

    shad = model.getShadowCalculation
    shad.setShadingCalculationUpdateFrequency(20)
    shad.setMaximumFiguresInShadowOverlapCalculations(200)

    outsurf = model.getOutsideSurfaceConvectionAlgorithm
    outsurf.setAlgorithm('DOE-2')

    insurf = model.getInsideSurfaceConvectionAlgorithm
    insurf.setAlgorithm('TARP')

    zonecap = model.getZoneCapacitanceMultiplierResearchSpecial
    zonecap.setHumidityCapacityMultiplier(15)
    # temperature capacitance multiplier = 3.6 according to a recent paper:
    # Kristen S Cetin, Mohammad Hassan Fathollahzadeh, Niraj Kunwar, Huyen Do, Paulo Cesar Tabares-Velasco, Development
    # and validation of an HVAC on/off controller in EnergyPlus for energy simulation of residential and small commercial
    # buildings, Energy and Buildings, Volume 183, 2019, Pages 467-483, ISSN 0378-7788,
    # https://doi.org/10.1016/j.enbuild.2018.11.005.
    zonecap.setTemperatureCapacityMultiplier(3.6)
    if apply_ashrae140_assumptions
      zonecap.setTemperatureCapacityMultiplier(1.0)
    end

    convlim = model.getConvergenceLimits
    convlim.setMinimumSystemTimestep(0)

    run_period = model.getRunPeriod
    run_period.setBeginMonth(header.sim_begin_month)
    run_period.setBeginDayOfMonth(header.sim_begin_day_of_month)
    run_period.setEndMonth(header.sim_end_month)
    run_period.setEndDayOfMonth(header.sim_end_day_of_month)
  end
end
