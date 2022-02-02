# frozen_string_literal: true

class CalculateUtilityBill
  def self.simple(fuel_type, fuel_time_series, is_production, rate, bill, net_elec, realtimeprice = false)
    monthly_fuel_cost = []

    (0..11).to_a.each do |month|
      if is_production && fuel_type == FT::Elec && rate.feed_in_tariff_rate
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.feed_in_tariff_rate
      elsif !is_production && fuel_type == FT::Elec && realtimeprice
        monthly_fuel_cost[month] = fuel_time_series[month] * realtimeprice[month] # hour?
      else
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.flatratebuy
      end

      if fuel_type == FT::Elec && fuel_time_series.sum != 0 # has PV
        if is_production
          net_elec -= fuel_time_series[month]
          if realtimeprice

          end
        else
          net_elec += fuel_time_series[month]
        end
      end

      if is_production
        if realtimeprice

        else
          bill.monthly_production_credit[month] = monthly_fuel_cost[month]
          bill.annual_production_credit += bill.monthly_production_credit[month]
        end
      else
        bill.monthly_energy_charge[month] = monthly_fuel_cost[month]
        if rate.fixedmonthlycharge
          bill.monthly_fixed_charge[month] = rate.fixedmonthlycharge
        else
          bill.monthly_fixed_charge[month] = 0
        end
        bill.annual_energy_charge += bill.monthly_energy_charge[month]
        bill.annual_fixed_charge += bill.monthly_fixed_charge[month]
      end
    end
    return net_elec
  end
end
