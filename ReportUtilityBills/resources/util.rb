# frozen_string_literal: true

class Fuel
  def initialize(meters: [])
    @meters = meters
    @timeseries = []
  end
  attr_accessor(:meters, :timeseries, :units)
end

class UtilityRate
  def initialize()
    @fixedmonthlycharge = false
    @flatratebuy = 0.0
    @realtimeprice = []

    @net_metering_excess_sellback_type = false
    @net_metering_user_excess_sellback_rate = false

    @feed_in_tariff_rate = false

    @energyratestructure = []
    @energyweekdayschedule = []
    @energyweekendschedule = []

    @demandratestructure = []
    @demandweekdayschedule = []
    @demandweekendschedule = []

    @flatdemandstructure = []
  end
  attr_accessor(:fixedmonthlycharge, :flatratebuy, :realtimeprice,
                :net_metering_excess_sellback_type, :net_metering_user_excess_sellback_rate,
                :feed_in_tariff_rate,
                :energyratestructure, :energyweekdayschedule, :energyweekendschedule,
                :demandratestructure, :demandweekdayschedule, :demandweekendschedule,
                :flatdemandstructure)
end

class UtilityBill
  def initialize()
    @annual_energy_charge = 0.0
    @annual_fixed_charge = 0.0
    @annual_total = 0.0

    @monthly_energy_charge = []
    @monthly_fixed_charge = [0] * 12

    @monthly_production_credit = []
    @annual_production_credit = 0.0
  end
  attr_accessor(:annual_energy_charge, :annual_fixed_charge, :annual_total,
                :monthly_energy_charge, :monthly_fixed_charge,
                :monthly_production_credit, :annual_production_credit)
end

class CalculateUtilityBill
  def self.simple(fuel_type, header, fuel_time_series, is_production, rate, bill, net_elec)
    sum_fuel_time_series = fuel_time_series.sum
    monthly_fuel_cost = [0] * 12
    net_elec_cost = 0
    (0...fuel_time_series.size).to_a.each do |month|
      if is_production && fuel_type == FT::Elec && rate.feed_in_tariff_rate
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.feed_in_tariff_rate
      else
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.flatratebuy
      end

      if fuel_type == FT::Elec && sum_fuel_time_series != 0 # has PV
        if is_production
          net_elec -= fuel_time_series[month]
        else
          net_elec += fuel_time_series[month]
        end
      end

      if is_production
        bill.monthly_production_credit[month] = monthly_fuel_cost[month]
        bill.annual_production_credit += bill.monthly_production_credit[month]
      else
        bill.monthly_energy_charge[month] = monthly_fuel_cost[month]
        bill.monthly_fixed_charge[month] = rate.fixedmonthlycharge if rate.fixedmonthlycharge

        bill.annual_energy_charge += bill.monthly_energy_charge[month]
        bill.annual_fixed_charge += bill.monthly_fixed_charge[month]
      end

      net_elec_cost = 0
    end
    return net_elec
  end

  def self.detailed_electric(fuels, rate, bill, net_elec)
    # TODO
    return net_elec
  end
end
