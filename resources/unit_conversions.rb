class UnitConversions
  # As there is a performance penalty to using OpenStudio's built-in unit convert()
  # method, we use our own approach here.

  # Hash value is [scalar, delta]
  @Conversions = {
    # Energy
    ['btu', 'j'] => [1055.05585262, 0],
    ['j', 'btu'] => [3412.141633127942 / 1000.0 / 3600.0, 0],
    ['j', 'kbtu'] => [3412.141633127942 / 1000.0 / 3600.0 / 1000.0, 0],
    ['j', 'therm'] => [3412.141633127942 / 1000.0 / 3600.0 / 1000.0 / 100.0, 0],
    ['kj', 'btu'] => [0.9478171203133172, 0],
    ['gj', 'mbtu'] => [0.9478171203133172, 0],
    ['gj', 'kwh'] => [277.778, 0],
    ['gj', 'therm'] => [9.48043, 0],
    ['kwh', 'btu'] => [3412.141633127942, 0],
    ['kwh', 'j'] => [3600000.0, 0],
    ['wh', 'gj'] => [0.0000036, 0],
    ['kwh', 'wh'] => [1000.0, 0],
    ['mbtu', 'wh'] => [293071.0701722222, 0],
    ['therm', 'btu'] => [100000.0, 0],
    ['therm', 'kbtu'] => [100.0, 0],
    ['therm', 'kwh'] => [29.307107017222222, 0],
    ['therm', 'wh'] => [29307.10701722222, 0],
    ['wh', 'btu'] => [3.412141633127942, 0],
    ['wh', 'kbtu'] => [0.003412141633127942, 0],
    ['kbtu', 'btu'] => [1000.0, 0],
    ['gal', 'btu', Constants.FuelTypePropane] => [91600.0, 0],
    ['gal', 'btu', Constants.FuelTypeOil] => [139000.0, 0],
    ['j', 'gal', Constants.FuelTypePropane] => [3412.141633127942 / 1000.0 / 3600.0 / 91600.0, 0],
    ['j', 'gal', Constants.FuelTypeOil] => [3412.141633127942 / 1000.0 / 3600.0 / 139000.0, 0],

    # Power
    ['btu/hr', 'w'] => [0.2930710701722222, 0],
    ['kbtu/hr', 'btu/hr'] => [1000.0, 0],
    ['kbtu/hr', 'w'] => [293.0710701722222, 0],
    ['kw', 'w'] => [1000.0, 0],
    ['ton', 'btu/hr'] => [12000.0, 0],
    ['ton', 'kbtu/hr'] => [12.0, 0],
    ['ton', 'w'] => [3516.85284207, 0],
    ['w', 'btu/hr'] => [3.412141633127942, 0],
    ['kbtu/hr', 'kw'] => [0.2930710701722222, 0],

    # Power Flux
    ['w/m^2', 'btu/(hr*ft^2)'] => [0.3169983306281505, 0],

    # Temperature
    ['k', 'r'] => [1.8, 0],
    ['c', 'f'] => [1.8, 32.0],
    ['c', 'k'] => [1.0, 273.15],
    ['f', 'r'] => [1.0, 459.67],

    # Specific Heat
    ['btu/(lbm*r)', 'j/(kg*k)'] => [4187.0, 0], # by mass
    ['btu/(ft^3*f)', 'j/(m^3*k)'] => [67100.0, 0], # by volume
    ['btu/(lbm*r)', 'wh/(kg*k)'] => [1.1632, 0],

    # Length
    ['ft', 'in'] => [12.0, 0],
    ['ft', 'm'] => [0.3048, 0],
    ['in', 'm'] => [0.0254, 0],
    ['m', 'mm'] => [1000.0, 0],

    # Area
    ['cm^2', 'ft^2'] => [1.0 / 929.0304, 0],
    ['ft^2', 'cm^2'] => [929.0304, 0],
    ['ft^2', 'in^2'] => [144.0, 0],
    ['ft^2', 'm^2'] => [0.09290304, 0],
    ['m^2', 'ft^2'] => [1.0 / 0.09290304, 0],

    # Volume
    ['ft^3', 'gal'] => [7.480519480579059, 0],
    ['ft^3', 'l'] => [28.316846591999997, 0],
    ['ft^3', 'm^3'] => [0.028316846592000004, 0],
    ['gal', 'in^3'] => [231.0, 0],
    ['gal', 'm^3'] => [0.0037854117839698515, 0],
    ['l', 'pint'] => [2.1133764, 0],
    ['pint', 'l'] => [0.47317647, 0],

    # Mass
    ['lbm', 'kg'] => [0.45359237, 0],

    # Volume Flow Rate
    ['m^3/s', 'gal/min'] => [15850.323141615143, 0],
    ['m^3/s', 'cfm'] => [2118.880003289315, 0],
    ['m^3/s', 'ft^3/min'] => [2118.880003289315, 0],

    # Mass Flow Rate
    ['lbm/min', 'kg/hr'] => [27.2155422, 0],
    ['lbm/min', 'kg/s'] => [27.2155422 / 3600.0, 0],

    # Time
    ['day', 'hr'] => [24.0, 0],
    ['hr', 'min'] => [60.0, 0],
    ['hr', 's'] => [3600.0, 0],
    ['min', 's'] => [60.0, 0],
    ['yr', 'day'] => [365.0, 0],
    ['yr', 'hr'] => [8760.0, 0],

    # Velocity
    ['knots', 'm/s'] => [0.51444444, 0],
    ['mph', 'm/s'] => [0.44704, 0],
    ['m/s', 'knots'] => [1.9438445, 0],
    ['m/s', 'mph'] => [2.2369363, 0],

    # Pressure & Density
    ['atm', 'btu/ft^3'] => [2.719, 0],
    ['atm', 'kpa'] => [101.325, 0],
    ['atm', 'psi'] => [14.692, 0],
    ['inh2o', 'pa'] => [249.1, 0],
    ['lbm/(ft*s^2)', 'inh2o'] => [0.005974, 0],
    ['lbm/ft^3', 'inh2o/mph^2'] => [0.01285, 0],
    ['lbm/ft^3', 'kg/m^3'] => [16.02, 0],
    ['psi', 'btu/ft^3'] => [0.185, 0],
    ['psi', 'kpa'] => [6.89475729, 0],
    ['psi', 'pa'] => [6.89475729 * 1000.0, 0],

    # Angles
    ['rad', 'deg'] => [57.29578, 0],

    # R-Value
    ['hr*ft^2*f/btu', 'm^2*k/w'] => [0.1761, 0],

    # U-Factor
    ['btu/(hr*ft^2*f)', 'w/(m^2*k)'] => [5.678, 0],

    # UA
    ['btu/(hr*f)', 'w/k'] => [0.5275, 0],

    # Thermal Conductivity
    ['btu/(hr*ft*r)', 'w/(m*k)'] => [1.731, 0],
    ['btu*in/(hr*ft^2*r)', 'w/(m*k)'] => [0.14425, 0],

    # Infiltration
    ['ft^2/(s^2*r)', 'l^2/(s^2*cm^4*k)'] => [0.001672, 0],
    ['inh2o/mph^2', 'pa*s^2/m^2'] => [1246.0, 0],
    ['inh2o/r', 'pa/k'] => [448.4, 0],

    # Humidity
    ['lbm/lbm', 'grains'] => [7000.0, 0]
  }

  def self.convert(x, from, to, fuel_type = nil)
    from.downcase!
    to.downcase!

    return x if from == to

    # Try forward
    if fuel_type.nil?
      key = [from, to]
    else
      key = [from, to, fuel_type]
    end
    conversion = @Conversions[key]
    if not conversion.nil?
      return x * conversion[0] + conversion[1]
    end

    # Try reverse
    if fuel_type.nil?
      key = [to, from]
    else
      key = [to, from, fuel_type]
    end
    conversion = @Conversions[key]
    if not conversion.nil?
      return x / conversion[0] - conversion[1]
    end

    if fuel_type.nil?
      fail "Unhandled unit conversion from #{from} to #{to}."
    else
      fail "Unhandled unit conversion from #{from} to #{to} for fuel type #{fuel_type}."
    end
  end
end
