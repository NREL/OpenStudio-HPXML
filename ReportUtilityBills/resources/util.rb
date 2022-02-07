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
  def self.simple(fuel_type, year, fuel_time_series, is_production, rate, bill, net_elec)
    sim_end_day_of_year = Schedule.get_day_num_from_month_day(year, 12, 31)
    num_hrs = sim_end_day_of_year * 24
    day_end_months = Schedule.day_end_months(year)

    if !rate.realtimeprice.empty? && rate.realtimeprice.size != num_hrs
      feb_28_hr = Schedule.get_day_num_from_month_day(year, 2, 28) * 24 - 1
      feb_29_hr = feb_28_hr + 24
      feb_28_prices = rate.realtimeprice[feb_28_hr...feb_29_hr]
      rate.realtimeprice.insert(feb_29_hr, feb_28_prices).flatten!
    end

    hourly_fuel_cost = []
    monthly_fuel_cost = [0] * 12
    month = 0
    net_elec_cost = 0
    (0...num_hrs).to_a.each do |hour|
      if is_production && fuel_type == FT::Elec && rate.feed_in_tariff_rate
        hourly_fuel_cost[hour] = fuel_time_series[hour] * rate.feed_in_tariff_rate
      elsif !is_production && fuel_type == FT::Elec && !rate.realtimeprice.empty?
        hourly_fuel_cost[hour] = fuel_time_series[hour] * rate.realtimeprice[hour]
      else
        hourly_fuel_cost[hour] = fuel_time_series[hour] * rate.flatratebuy
      end
      monthly_fuel_cost[month] += hourly_fuel_cost[hour]

      if fuel_type == FT::Elec && fuel_time_series.sum != 0 # has PV
        if is_production
          net_elec -= fuel_time_series[hour]
          if !rate.realtimeprice.empty?
            net_elec_cost += fuel_time_series[hour] * rate.realtimeprice[hour]
          end
        else
          net_elec += fuel_time_series[hour]
        end
      end

      next unless hour == day_end_months[month] * 24 - 1

      if is_production
        if !rate.realtimeprice.empty?
          bill.monthly_production_credit[month] = net_elec_cost
        else
          bill.monthly_production_credit[month] = monthly_fuel_cost[month]
        end
        bill.annual_production_credit += bill.monthly_production_credit[month]
      else
        bill.monthly_energy_charge[month] = monthly_fuel_cost[month]
        bill.monthly_fixed_charge[month] = rate.fixedmonthlycharge if rate.fixedmonthlycharge

        bill.annual_energy_charge += bill.monthly_energy_charge[month]
        bill.annual_fixed_charge += bill.monthly_fixed_charge[month]
      end

      net_elec_cost = 0
      month += 1
    end
    return net_elec
  end

  def self.detailed_electric(fuels, rate, bill, net_elec)
    # TODO
    return net_elec
  end
end
