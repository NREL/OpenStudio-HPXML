# frozen_string_literal: true

class Material
  # thick_in - Thickness [in]
  # mat_base - Material object that defines k, rho, and cp. Can be overridden with values for those arguments.
  # k_in - Conductivity [Btu-in/h-ft^2-F]
  # rho - Density [lb/ft^3]
  # cp - Specific heat [Btu/lb*F]
  # rvalue - R-value [h-ft^2-F/Btu]
  def initialize(name = nil, thick_in = nil, mat_base = nil, k_in = nil, rho = nil, cp = nil, tAbs = nil, sAbs = nil, vAbs = nil, rvalue = nil)
    @name = name

    if not thick_in.nil?
      @thick_in = thick_in # in
      @thick = UnitConversions.convert(thick_in, 'in', 'ft') # ft
    end

    if not mat_base.nil?
      @k_in = mat_base.k_in # Btu-in/h-ft^2-F
      if not mat_base.k_in.nil?
        @k = UnitConversions.convert(mat_base.k_in, 'in', 'ft') # Btu/h-ft-F
      else
        @k = nil
      end
      @rho = mat_base.rho
      @cp = mat_base.cp
    else
      @k_in = nil
      @k = nil
      @rho = nil
      @cp = nil
    end

    # Override the base material if both are included
    if not k_in.nil?
      @k_in = k_in # Btu-in/h-ft^2-F
      @k = UnitConversions.convert(k_in, 'in', 'ft') # Btu/h-ft-F
    end
    if not rho.nil?
      @rho = rho # lb/ft^3
    end
    if not cp.nil?
      @cp = cp # Btu/lb*F
    end

    @tAbs = tAbs
    @sAbs = sAbs
    @vAbs = vAbs

    # Calculate R-value
    if not rvalue.nil?
      @rvalue = rvalue # h-ft^2-F/Btu
    elsif (not @thick_in.nil?) && (not @k_in.nil?)
      if @k_in > 0
        @rvalue = @thick_in / @k_in # h-ft^2-F/Btu
      else
        @rvalue = @thick_in / 10000000.0 # h-ft^2-F/Btu
      end
    end
  end

  attr_accessor :name, :thick, :thick_in, :k, :k_in, :rho, :cp, :rvalue, :tAbs, :sAbs, :vAbs

  def self.AirCavityClosed(thick_in)
    rvalue = Gas.AirGapRvalue
    return new(nil, thick_in, nil, thick_in / rvalue, Gas.Air.rho, Gas.Air.cp)
  end

  def self.AirCavityOpen(thick_in)
    return new(nil, thick_in, nil, 10000000.0, Gas.Air.rho, Gas.Air.cp)
  end

  def self.AirFilm(rvalue)
    return new(Constants.AirFilm, 1.0, nil, 1.0 / rvalue)
  end

  def self.AirFilmOutside
    rvalue = 0.197 # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmOutsideASHRAE140
    return self.AirFilm(0.174)
  end

  def self.AirFilmVertical
    rvalue = 0.68 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmVerticalASHRAE140
    return self.AirFilm(0.685)
  end

  def self.AirFilmFlatEnhanced
    rvalue = 0.61 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmFlatReduced
    rvalue = 0.92 # hr-ft-F/Btu (ASHRAE 2005, F25.2, Table 1)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmFloorAverage
    # For floors between conditioned spaces where heat does not flow across
    # the floor; heat transfer is only important with regards to the thermal
    rvalue = (self.AirFilmFlatReduced.rvalue + self.AirFilmFlatEnhanced.rvalue) / 2.0 # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmFloorReduced
    # For floors above unconditioned basement spaces, where heat will
    # always flow down through the floor.
    rvalue = self.AirFilmFlatReduced.rvalue # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmFloorASHRAE140
    return self.AirFilm(0.765)
  end

  def self.AirFilmFloorZeroWindASHRAE140
    return self.AirFilm(0.455)
  end

  def self.AirFilmSlopeEnhanced(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for non-reflective materials of
    # emissivity = 0.90.
    rvalue = 0.002 * Math::exp(0.0398 * roof_pitch) + 0.608 # hr-ft-F/Btu (evaluates to film_flat_enhanced at 0 degrees, 0.62 at 45 degrees, and film_vertical at 90 degrees)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmSlopeReduced(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for non-reflective materials of
    # emissivity = 0.90.
    rvalue = 0.32 * Math::exp(-0.0154 * roof_pitch) + 0.6 # hr-ft-F/Btu (evaluates to film_flat_reduced at 0 degrees, 0.76 at 45 degrees, and film_vertical at 90 degrees)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmSlopeEnhancedReflective(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for reflective materials of
    # emissivity = 0.05.
    rvalue = 0.00893 * Math::exp(0.0419 * roof_pitch) + 1.311 # hr-ft-F/Btu (evaluates to 1.32 at 0 degrees, 1.37 at 45 degrees, and 1.70 at 90 degrees)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmSlopeReducedReflective(roof_pitch)
    # Correlation functions used to interpolate between values provided
    # in ASHRAE 2005, F25.2, Table 1 - which only provides values for
    # 0, 45, and 90 degrees. Values are for reflective materials of
    # emissivity = 0.05.
    rvalue = 2.999 * Math::exp(-0.0333 * roof_pitch) + 1.551 # hr-ft-F/Btu (evaluates to 4.55 at 0 degrees, 2.22 at 45 degrees, and 1.70 at 90 degrees)
    return self.AirFilm(rvalue)
  end

  def self.AirFilmRoof(roof_pitch)
    # Use weighted average between enhanced and reduced convection based on degree days.
    # hdd_frac = hdd65f / (hdd65f + cdd65f)
    # cdd_frac = cdd65f / (hdd65f + cdd65f)
    # return self.AirFilmSlopeEnhanced(roof_pitch).rvalue * hdd_frac + self.AirFilmSlopeReduced(roof_pitch).rvalue * cdd_frac # hr-ft-F/Btu
    # Simplification to not depend on weather
    rvalue = (self.AirFilmSlopeEnhanced(roof_pitch).rvalue + self.AirFilmSlopeReduced(roof_pitch).rvalue) / 2.0 # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmRoofRadiantBarrier(roof_pitch)
    # Use weighted average between enhanced and reduced convection based on degree days.
    # hdd_frac = hdd65f / (hdd65f + cdd65f)
    # cdd_frac = cdd65f / (hdd65f + cdd65f)
    # return self.AirFilmSlopeEnhancedReflective(roof_pitch).rvalue * hdd_frac + self.AirFilmSlopeReducedReflective(roof_pitch).rvalue * cdd_frac # hr-ft-F/Btu
    # Simplification to not depend on weather
    rvalue = (self.AirFilmSlopeEnhancedReflective(roof_pitch).rvalue + self.AirFilmSlopeReducedReflective(roof_pitch).rvalue) / 2.0 # hr-ft-F/Btu
    return self.AirFilm(rvalue)
  end

  def self.AirFilmRoofASHRAE140
    return self.AirFilm(0.752)
  end

  def self.CoveringBare(floorFraction = 0.8, rvalue = 2.08)
    # Combined layer of, e.g., carpet and bare floor
    thick_in = 0.5 # in
    return new('Floor Covering', thick_in, nil, thick_in / (rvalue * floorFraction), 3.4, 0.32, 0.9, 0.9, 0.9)
  end

  def self.Concrete(thick_in)
    return new("Concrete #{thick_in} in.", thick_in, BaseMaterial.Concrete, nil, nil, nil, 0.9)
  end

  def self.ExteriorFinishMaterial(siding, emittance, solar_absorptance, thick_in = nil)
    if siding == HPXML::SidingTypeAluminum
      thick_in = 0.375 if thick_in.nil?
      return new(siding, thick_in, BaseMaterial.Aluminum, nil, nil, nil, emittance, solar_absorptance, solar_absorptance)
    elsif siding == HPXML::SidingTypeAsbestos # Asbestos cement
      thick_in = 0.25 if thick_in.nil?
      return new(siding, thick_in, nil, 4.20, 118.6, 0.24, emittance, solar_absorptance, solar_absorptance)
    elsif siding == HPXML::SidingTypeBrick
      thick_in = 4.0 if thick_in.nil?
      return new(siding, thick_in, BaseMaterial.Brick, nil, nil, nil, emittance, solar_absorptance, solar_absorptance)
    elsif siding == HPXML::SidingTypeCompositeShingle
      thick_in = 0.1 if thick_in.nil?
      return new(siding, thick_in, nil, 1.128, 70, 0.35, emittance, solar_absorptance, solar_absorptance)
    elsif siding == HPXML::SidingTypeFiberCement
      thick_in = 0.375 if thick_in.nil?
      return new(siding, thick_in, nil, 1.79, 21.7, 0.24, emittance, solar_absorptance, solar_absorptance)
    elsif siding == HPXML::SidingTypeMasonite # Masonite hardboard
      thick_in = 0.5 if thick_in.nil?
      return new(siding, thick_in, nil, 0.69, 46.8, 0.39, emittance, solar_absorptance, solar_absorptance)
    elsif siding == HPXML::SidingTypeStucco
      thick_in = 1.0 if thick_in.nil?
      return new(siding, thick_in, BaseMaterial.Stucco, nil, nil, nil, emittance, solar_absorptance, solar_absorptance)
    elsif siding == HPXML::SidingTypeSyntheticStucco # EIFS
      thick_in = 1.0 if thick_in.nil?
      return new(siding, thick_in, BaseMaterial.InsulationRigid, nil, nil, nil, emittance, solar_absorptance, solar_absorptance)
    elsif siding == HPXML::SidingTypeVinyl
      thick_in = 0.375 if thick_in.nil?
      return new(siding, thick_in, BaseMaterial.Vinyl, nil, nil, nil, emittance, solar_absorptance, solar_absorptance)
    elsif siding == HPXML::SidingTypeWood
      thick_in = 1.0 if thick_in.nil?
      return new(siding, thick_in, nil, 0.71, 34.0, 0.28, emittance, solar_absorptance, solar_absorptance)
    end
  end

  def self.FloorWood
    return Material.new('Wood Floor', 0.625, BaseMaterial.Wood)
  end

  def self.GypsumWall(thick_in)
    return new("Drywall #{thick_in} in.", thick_in, BaseMaterial.Gypsum, nil, nil, nil, 0.9, 0.5, 0.1)
  end

  def self.GypsumCeiling(thick_in)
    return new("Drywall #{thick_in} in.", thick_in, BaseMaterial.Gypsum, nil, nil, nil, 0.9, 0.3, 0.1)
  end

  def self.Soil(thick_in)
    return new("Soil #{thick_in} in.", thick_in, BaseMaterial.Soil)
  end

  def self.Stud2x(thick_in)
    return new("Stud 2x #{thick_in} in.", thick_in, BaseMaterial.Wood)
  end

  def self.Stud2x4
    return new('Stud 2x4', 3.5, BaseMaterial.Wood)
  end

  def self.Stud2x6
    return new('Stud 2x6', 5.5, BaseMaterial.Wood)
  end

  def self.Stud2x8
    return new('Stud 2x8', 7.25, BaseMaterial.Wood)
  end

  def self.Plywood(thick_in)
    return new("Plywood #{thick_in} in.", thick_in, BaseMaterial.Wood)
  end

  def self.RadiantBarrier(grade)
    # Merge w/ Constructions.get_gap_factor
    if grade == 1
      gap_frac = 0.0
    elsif grade == 2
      gap_frac = 0.02
    elsif grade == 3
      gap_frac = 0.05
    end
    rb_emittance = 0.05
    non_rb_emittance = 0.90
    emittance = rb_emittance * (1.0 - gap_frac) + non_rb_emittance * gap_frac
    return new('Radiant Barrier', 0.0084, nil, 1629.6, 168.6, 0.22, emittance, 0.05, 0.05)
  end

  def self.RoofMaterial(roof_type, emissivity, absorptivity)
    return new(roof_type, 0.375, nil, 1.128, 70, 0.35, emissivity, absorptivity, absorptivity)
  end
end

class BaseMaterial
  def initialize(rho, cp, k_in)
    @rho = rho
    @cp = cp
    @k_in = k_in
  end

  attr_accessor :rho, :cp, :k_in

  def self.Gypsum
    return new(50.0, 0.2, 1.1112)
  end

  def self.Wood
    return new(32.0, 0.29, 0.8004)
  end

  def self.Concrete
    return new(140.0, 0.2, 12.5)
  end

  def self.Gypcrete
    # http://www.maxxon.com/gyp-crete/data
    return new(100.0, 0.223, 4.7424)
  end

  def self.InsulationRigid
    return new(2.0, 0.29, 0.204)
  end

  def self.InsulationCelluloseDensepack
    return new(3.5, 0.25, nil)
  end

  def self.InsulationCelluloseLoosefill
    return new(1.5, 0.25, nil)
  end

  def self.InsulationFiberglassDensepack
    return new(2.2, 0.25, nil)
  end

  def self.InsulationFiberglassLoosefill
    return new(0.5, 0.25, nil)
  end

  def self.InsulationGenericDensepack
    return new((self.InsulationFiberglassDensepack.rho + self.InsulationCelluloseDensepack.rho) / 2.0, 0.25, nil)
  end

  def self.InsulationGenericLoosefill
    return new((self.InsulationFiberglassLoosefill.rho + self.InsulationCelluloseLoosefill.rho) / 2.0, 0.25, nil)
  end

  def self.Soil
    return new(115.0, 0.1, 12.0)
  end

  def self.Brick
    return new(110.0, 0.19, 5.5)
  end

  def self.Vinyl
    return new(11.1, 0.25, 0.62)
  end

  def self.Aluminum
    return new(10.9, 0.29, 0.61)
  end

  def self.Stucco
    return new(80.0, 0.21, 4.5)
  end

  def self.Stone
    return new(140.0, 0.2, 12.5)
  end

  def self.StrawBale
    return new(11.1652, 0.2991, 0.4164)
  end
end

class SimpleMaterial
  def initialize(name = nil, rvalue = nil)
    @name = name
    @rvalue = rvalue
  end

  attr_accessor :name, :rvalue

  def self.Adiabatic
    return new('Adiabatic', rvalue = 1000)
  end
end

class GlazingMaterial
  def initialize(name = nil, ufactor = nil, shgc = nil)
    @name = name
    @ufactor = ufactor
    @shgc = shgc
  end

  attr_accessor :name, :ufactor, :shgc
end

class Liquid
  def initialize(rho, cp, k, mu, h_fg, t_frz, t_boil, t_crit)
    @rho = rho # Density (lb/ft3)
    @cp = cp # Specific Heat (Btu/lbm-R)
    @k = k # Thermal Conductivity (Btu/h-ft-R)
    @mu = mu # Dynamic Viscosity (lbm/ft-h)
    @h_fg = h_fg # Latent Heat of Vaporization (Btu/lbm)
    @t_frz = t_frz # Freezing Temperature (degF)
    @t_boil = t_boil    # Boiling Temperature (degF)
    @t_crit = t_crit    # Critical Temperature (degF)
  end

  attr_accessor :rho, :cp, :k, :mu, :h_fg, :t_frz, :t_boil, :t_crit

  def self.H2O_l
    # From EES at STP
    return new(62.32, 0.9991, 0.3386, 2.424, 1055, 32.0, 212.0, nil)
  end

  def self.R22_l
    # Converted from EnthDR22 f77 in ResAC (Brandemuehl)
    return new(nil, 0.2732, nil, nil, 100.5, nil, -41.35, 204.9)
  end
end

class Gas
  def initialize(rho, cp, k, mu, m)
    @rho = rho # Density (lb/ft3)
    @cp = cp # Specific Heat (Btu/lbm-R)
    @k = k # Thermal Conductivity (Btu/h-ft-R)
    @mu = mu # Dynamic Viscosity (lbm/ft-h)
    @m = m # Molecular Weight (lbm/lbmol)
    if @m
      gas_constant = 1.9858 # Gas Constant (Btu/lbmol-R)
      @r = gas_constant / m # Gas Constant (Btu/lbm-R)
    else
      @r = nil
    end
  end

  attr_accessor :rho, :cp, :k, :mu, :m, :r

  def self.Air
    # From EES at STP
    return new(0.07518, 0.2399, 0.01452, 0.04415, 28.97)
  end

  def self.AirGapRvalue
    return 1.0 # hr*ft*F/Btu (Assume for all air gap configurations since there is no correction for direction of heat flow in the simulation tools)
  end

  def self.H2O_v
    # From EES at STP
    return new(nil, 0.4495, nil, nil, 18.02)
  end

  def self.R22_v
    # Converted from EnthDR22 f77 in ResAC (Brandemuehl)
    return new(nil, 0.1697, nil, nil, nil)
  end

  def self.PsychMassRat
    return self.H2O_v.m / self.Air.m
  end
end
