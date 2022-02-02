# frozen_string_literal: true

class CalculateUtilityBill
  def self.simple(fuel_type, fuel_time_series, is_production, rate, bill, realtimeprice = false)
    monthly_fuel_cost = []

    (0..11).to_a.each do |month|
      if is_production && fuel_type == FT::Elec && rate.feed_in_tariff
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.feed_in_tariff
      elsif !is_production && fuel_type == FT::Elec && realtimeprice
        monthly_fuel_cost[month] = fuel_time_series[month] * realtimeprice[month] # hour?
      else
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.flatratebuy
      end

      if fuel_type == FT::Elec && is_production && !fuel_time_series.all? { |x| x == 0.0 }

      end

      if is_production
        if rate.feed_in_tariff

        elsif realtimeprice

        else

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
    end # end monthly
  end
end
