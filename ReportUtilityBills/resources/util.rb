# frozen_string_literal: true

class UtilityBill
  def self.calculate_simple(fuels, fuel_type, utility_bill, fixed_charge, marginal_rate, total_elec_produced_timeseries, pv_feed_in_tariff_rate)
    energy = fuels[fuel_type].timeseries_output

    utility_bill.fixed = 12.0 * fixed_charge if (!energy.all? { |x| x == 0.0 } && !fixed_charge.nil?)
    utility_bill.marginal = energy.collect { |x| x * marginal_rate }.sum

    if !pv_feed_in_tariff_rate.nil? # has pv
      utility_bill.marginal -= total_elec_produced_timeseries.collect { |x| x * pv_feed_in_tariff_rate }.sum
    end

    utility_bill.total = utility_bill.fixed + utility_bill.marginal
  end
end
