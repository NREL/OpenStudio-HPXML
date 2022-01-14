# frozen_string_literal: true

class UtilityBill
  def self.calculate_simple(fuels, fuel_type, utility_bill, fixed_charge, marginal_rate)
    energy = fuels[fuel_type].timeseries_output

    if [FT::Elec, FT::Gas].include? fuel_type
      utility_bill.fixed = 12.0 * fixed_charge if !energy.all? { |x| x == 0.0 }
    end
    utility_bill.marginal = energy.collect { |x| x * marginal_rate }.sum
    utility_bill.total = utility_bill.marginal
    utility_bill.total += utility_bill.fixed if !utility_bill.fixed.nil?
  end
end
