# frozen_string_literal: true

class UtilityBills
  def self.get_rates_from_eia_data(runner, state_code, fuel_type, fixed_charge, marginal_rate = nil)
    msn_codes = Constants.StateCodesMap.map {|x| x[0]}.uniq
    msn_codes << 'US'
    return unless msn_codes.include? state_code # Check if the state_code is valid

    average_rate = nil
    if [HPXML::FuelTypeElectricity, HPXML::FuelTypeNaturalGas].include? fuel_type
      household_consumption = get_household_consumption(state_code, fuel_type)
      if not marginal_rate.nil?
        # Calculate average rate from user-specified fixed charge, user-specified marginal rate, and EIA data
        average_rate = marginal_rate_to_average_rate(marginal_rate, fixed_charge, household_consumption)
      else
        average_rate = get_eia_seds_rate(state_code, fuel_type)
        marginal_rate = average_rate_to_marginal_rate(average_rate, fixed_charge, household_consumption)
      end
    elsif [HPXML::FuelTypeOil, HPXML::FuelTypePropane, HPXML::FuelTypeCoal, HPXML::FuelTypeWoodCord, HPXML::FuelTypeWoodPellets].include? fuel_type
      marginal_rate = get_eia_seds_rate(state_code, fuel_type)
    end

    return marginal_rate, average_rate
  end

  def self.get_household_consumption(state_code, fuel_type)
    rows = CSV.read(File.join(File.dirname(__FILE__), '../../ReportUtilityBills/resources/simple_rates/HouseholdConsumption.csv'))
    rows.each do |row|
      next if row[0] != state_code

      if fuel_type == HPXML::FuelTypeElectricity
        return Float(row[1])
      elsif fuel_type == HPXML::FuelTypeNaturalGas
        return Float(row[2])
      end
    end
  end

  def self.average_rate_to_marginal_rate(average_rate, fixed_charge, household_consumption)
    return average_rate - 12.0 * fixed_charge / household_consumption
  end

  def self.marginal_rate_to_average_rate(marginal_rate, fixed_charge, household_consumption)
    return marginal_rate + 12.0 * fixed_charge / household_consumption
  end

  def self.get_eia_seds_rate(state_code, fuel_type)
    msn_code_map = {
      HPXML::FuelTypeElectricity => 'ESRCD',
      HPXML::FuelTypeNaturalGas => 'NGRCD',
      HPXML::FuelTypeOil => 'DFRCD',
      HPXML::FuelTypePropane => 'PQRCD',
      HPXML::FuelTypeCoal => 'CLRCD',
      HPXML::FuelTypeWoodCord => 'WDRCD',
      HPXML::FuelTypeWoodPellets => 'WDRCD'
    }
    unit_conv = {
      HPXML::FuelTypeElectricity => 0.003412, # convert $/MMBtu to $/kWh
      HPXML::FuelTypeNaturalGas => 0.1, # convert $/MMBtu to $/therms
      HPXML::FuelTypeOil => 0.139, # convert $/MMBtu to $/gallons of oil
      HPXML::FuelTypePropane => 0.0916, # convert $/MMBtu to $/gallons of propane
      HPXML::FuelTypeCoal => 1, # $/MMBtu
      HPXML::FuelTypeWoodCord => 1, # $/MMBtu
      HPXML::FuelTypeWoodPellets => 1 # $/MMBtu
    }

    rows = CSV.read(File.join(File.dirname(__FILE__), '../../ReportUtilityBills/resources/simple_rates/pr_all_update.csv'))
    rows.each do |row|
      next if row[1].upcase != state_code.upcase # State
      next if row[2].upcase != msn_code_map[fuel_type] # EIA SEDS MSN code
      
      if fuel_type == HPXML::FuelTypeCoal
        seds_rate = row[40] # Use 2007 prices for coal. For 2008 forward, EIA assumes there is zero residential sector coal consumption in the United States, and SEDS does not estimate a price.
      else
        seds_rate = row[-1]
        seds_rate = row[-2] if seds_rate.nil? # If the rate for the latest year is unavailable, use the rate from the previous year.
      end

      return Float(seds_rate) * unit_conv[fuel_type]
    end
  end
end
