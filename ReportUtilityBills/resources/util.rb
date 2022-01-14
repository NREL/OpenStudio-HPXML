# frozen_string_literal: true

class UtilityBill
  def self.calculate_simple(fuels, fuel_type, utility_bill, fixed_charge, marginal_rate)
    energy = fuels[fuel_type].timeseries_output

    utility_bill.fixed = 12.0 * fixed_charge if (!energy.all? { |x| x == 0.0 } && !fixed_charge.nil?)
    utility_bill.marginal = energy.collect { |x| x * marginal_rate }.sum
    utility_bill.total = utility_bill.fixed + utility_bill.marginal
  end
end
