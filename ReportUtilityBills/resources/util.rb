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
    @fixedmonthlycharge = nil
    @flatratebuy = 0.0
    @realtimeprice = []

    @minmonthlycharge = 0.0
    @minannualcharge = nil

    @net_metering_excess_sellback_type = nil
    @net_metering_user_excess_sellback_rate = nil

    @feed_in_tariff_rate = nil

    @energyratestructure = []
    @energyweekdayschedule = []
    @energyweekendschedule = []
  end
  attr_accessor(:fixedmonthlycharge, :flatratebuy, :realtimeprice,
                :minmonthlycharge, :minannualcharge,
                :net_metering_excess_sellback_type, :net_metering_user_excess_sellback_rate,
                :feed_in_tariff_rate,
                :energyratestructure, :energyweekdayschedule, :energyweekendschedule)
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
    (0...fuel_time_series.size).to_a.each do |month|
      if is_production && fuel_type == FT::Elec && rate.feed_in_tariff_rate
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.feed_in_tariff_rate
      else
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.flatratebuy
      end

      if fuel_type == FT::Elec && sum_fuel_time_series != 0
        if is_production # has PV
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
        if not rate.fixedmonthlycharge.nil?
          # If the run period doesn't span the entire month, prorate the fixed charges
          prorate_fraction = calculate_monthly_prorate(header, month + 1)
          bill.monthly_fixed_charge[month] = rate.fixedmonthlycharge * prorate_fraction
        end

        bill.annual_energy_charge += bill.monthly_energy_charge[month]
        bill.annual_fixed_charge += bill.monthly_fixed_charge[month]
      end
    end
    return net_elec
  end

  def self.annual_true_up(utility_rates, utility_bills, net_elec)
    rate = utility_rates[FT::Elec]
    bill = utility_bills[FT::Elec]
    # Only make changes for cases where there's a user specified annual excess sellback rate
    if rate.net_metering_excess_sellback_type == HPXML::PVAnnualExcessSellbackRateTypeUserSpecified
      if bill.annual_production_credit > bill.annual_energy_charge
        bill.annual_production_credit = bill.annual_energy_charge
      end
      if net_elec < 0 # net producer, give credit at user specified rate
        bill.annual_production_credit += -net_elec * rate.net_metering_user_excess_sellback_rate
      end
    end
  end

  def self.detailed_electric(header, fuels, rate, bill)
    fuel_time_series = fuels[[FT::Elec, false]].timeseries
    pv_fuel_time_series = fuels[[FT::Elec, true]].timeseries
    net_elec_energy_ann = 0

    num_energyrate_periods = rate.energyratestructure.size
    has_periods = false
    if num_energyrate_periods > 1
      has_periods = true
    end

    length_tiers = []
    rate.energyratestructure.each do |period|
      length_tiers << period.size
    end
    num_energyrate_tiers = length_tiers.max
    has_tiered = false
    if num_energyrate_tiers > 1
      has_tiered = true
    end

    year = header.sim_calendar_year
    start_day = DateTime.new(year, header.sim_begin_month, header.sim_begin_day)
    today = start_day

    hourly_fuel_cost = [0] * fuel_time_series.size
    net_hourly_fuel_cost = [0] * fuel_time_series.size
    elec_month = [0] * 12
    net_elec_month = [0] * 12
    bill.monthly_energy_charge = [0] * 12
    net_monthly_energy_charge = [0] * 12
    production_fit_month = [0] * 12

    tier = 0
    net_tier = 0
    if !rate.energyratestructure.empty? || !rate.fixedmonthlycharge.nil?

      elec_period = [0] * num_energyrate_periods
      elec_tier = [0] * length_tiers.max

      if pv_fuel_time_series.sum != 0 # has PV
        net_elec_period = [0] * num_energyrate_periods
        net_elec_tier = [0] * length_tiers.max
      end

      (0...fuel_time_series.size).to_a.each do |hour|
        hour_day = hour % 24 # calculate hour of the day

        month = today.month - 1

        if (num_energyrate_periods != 0) || (num_energyrate_tiers != 0)
          if (1..5).to_a.include?(today.wday) # weekday
            sched_rate = rate.energyweekdayschedule[month][hour_day]
          else # weekend
            sched_rate = rate.energyweekendschedule[month][hour_day]
          end
        end

        elec_hour = fuel_time_series[hour]
        elec_month[month] += elec_hour

        if pv_fuel_time_series.sum != 0 # has PV
          pv_hour = pv_fuel_time_series[hour]
          net_elec_hour = elec_hour - pv_hour
          net_elec_month[month] += net_elec_hour
          net_elec_energy_ann += net_elec_hour
        end

        if (num_energyrate_periods > 1) || (num_energyrate_tiers > 1) # tiered or TOU
          tiers = rate.energyratestructure[sched_rate]

          if has_tiered

            # init
            new_tier = false
            if tiers.size > 1
              if tier < tiers.size
                if tiers[tier].keys.include?(:max) && elec_month[month] >= tiers[tier][:max]
                  tier += 1
                  new_tier = true
                  elec_lower_tier = elec_hour - (elec_month[month] - tiers[tier - 1][:max])
                end
              end
            end

            if !has_periods # tiered only
              elec_rate = tiers[tier][:rate]
              if new_tier
                hourly_fuel_cost[hour] = (elec_lower_tier * tiers[tier - 1][:rate]) + ((elec_hour - elec_lower_tier) * tiers[tier][:rate])
                bill.monthly_energy_charge[month] += hourly_fuel_cost[hour]
              else
                hourly_fuel_cost[hour] = elec_hour * elec_rate
                bill.monthly_energy_charge[month] += hourly_fuel_cost[hour]
              end

            else # tiered and TOU
              elec_period[sched_rate] += elec_hour
              if (tier > 0) && (tiers.size == 1)
                elec_tier[0] += elec_hour
              else
                if new_tier
                  elec_tier[tier - 1] += elec_lower_tier
                  elec_tier[tier] += elec_hour - elec_lower_tier
                else
                  elec_tier[tier] += elec_hour
                end
              end

            end
          else # TOU only
            elec_rate = tiers[0][:rate]

            hourly_fuel_cost[hour] = elec_hour * elec_rate
            bill.monthly_energy_charge[month] += hourly_fuel_cost[hour]

          end
        else # not tiered or TOU
          if (num_energyrate_periods == 1) && (num_energyrate_tiers == 1)
            elec_rate = rate.energyratestructure[0][0][:rate]
          end
          hourly_fuel_cost[hour] = elec_hour * elec_rate
          bill.monthly_energy_charge[month] += hourly_fuel_cost[hour]

        end

        if pv_fuel_time_series.sum != 0 # has PV
          if rate.feed_in_tariff_rate
            production_fit_month[month] += pv_hour * rate.feed_in_tariff_rate
          else
            if (num_energyrate_periods > 1) || (num_energyrate_tiers > 1)
              if has_tiered

                # init
                net_new_tier = false
                net_lower_tier = false
                if tiers.size > 1
                  if net_tier < tiers.size && tiers[net_tier].keys.include?(:max) && net_elec_month[month] >= tiers[net_tier][:max]
                    net_tier += 1
                    net_new_tier = true
                    net_elec_lower_tier = net_elec_hour - (net_elec_month[month] - tiers[net_tier - 1][:max])
                  end
                  if net_tier > 0 && tiers[net_tier - 1].keys.include?(:max) && net_elec_month[month] < tiers[net_tier - 1][:max]
                    net_tier -= 1
                    net_lower_tier = true
                    net_elec_upper_tier = net_elec_hour - (net_elec_month[month] - tiers[net_tier][:max])
                  end
                end

                if !has_periods # tiered only
                  net_elec_rate = tiers[net_tier][:rate]
                  if net_new_tier
                    net_hourly_fuel_cost[hour] = (net_elec_lower_tier * tiers[net_tier - 1][:rate]) + ((net_elec_hour - net_elec_lower_tier) * tiers[net_tier][:rate])
                    net_monthly_energy_charge[month] += net_hourly_fuel_cost[hour]
                  elsif net_lower_tier
                    net_hourly_fuel_cost[hour] = (net_elec_upper_tier * tiers[net_tier + 1][:rate]) + ((net_elec_hour - net_elec_upper_tier) * tiers[net_tier][:rate])
                    net_monthly_energy_charge[month] += net_hourly_fuel_cost[hour]
                  else
                    net_hourly_fuel_cost[hour] = net_elec_hour * net_elec_rate
                    net_monthly_energy_charge[month] += net_hourly_fuel_cost[hour]
                  end
                else # tiered and TOU
                  net_elec_period[sched_rate] += net_elec_hour
                  if (net_tier > 0) && (tiers.size == 1)
                    net_elec_tier[0] += net_elec_hour
                  else
                    if net_new_tier
                      net_elec_tier[net_tier - 1] += net_elec_lower_tier
                      net_elec_tier[net_tier] += net_elec_hour - net_elec_lower_tier
                    elsif net_lower_tier
                      net_elec_tier[net_tier + 1] += net_elec_upper_tier
                      net_elec_tier[net_tier] += net_elec_hour - net_elec_upper_tier
                    else
                      net_elec_tier[net_tier] += net_elec_hour
                    end
                  end
                end
              else # TOU only
                net_elec_rate = tiers[0][:rate]

                net_hourly_fuel_cost[hour] = net_elec_hour * net_elec_rate
                net_monthly_energy_charge[month] += net_hourly_fuel_cost[hour]

              end
            else # not tiered or TOU
              if (num_energyrate_periods == 1) && (num_energyrate_tiers == 1)
                net_elec_rate = rate.energyratestructure[0][0][:rate]
              end
              net_hourly_fuel_cost[hour] = net_elec_hour * net_elec_rate
              net_monthly_energy_charge[month] += net_hourly_fuel_cost[hour]

            end
          end
        end

        next unless hour_day == 23 # last hour of the day

        if Schedule.day_end_months(year).include?(today.yday)
          if not rate.fixedmonthlycharge.nil?
            # If the run period doesn't span the entire month, prorate the fixed charges
            prorate_fraction = calculate_monthly_prorate(header, month + 1)
            bill.monthly_fixed_charge[month] = rate.fixedmonthlycharge * prorate_fraction
          end

          if (num_energyrate_periods > 1) || (num_energyrate_tiers > 1) # tiered or TOU

            if has_periods && has_tiered # tiered and TOU
              frac_elec_period = [0] * num_energyrate_periods
              (0...num_energyrate_periods).each do |period|
                next unless elec_month[month] > 0

                frac_elec_period[period] = elec_period[period] / elec_month[month]
                (0...rate.energyratestructure[period].size).each do |t|
                  if t < elec_tier.size
                    bill.monthly_energy_charge[month] += rate.energyratestructure[period][t][:rate] * frac_elec_period[period] * elec_tier[t]
                  end
                end
              end
            end

            elec_period = [0] * num_energyrate_periods
            elec_tier = [0] * length_tiers.max
            tier = 0
          end

          if pv_fuel_time_series.sum != 0 && !rate.feed_in_tariff_rate # has PV
            if (num_energyrate_periods > 1) || (num_energyrate_tiers > 1) # tiered or TOU

              if has_periods && has_tiered # tiered and TOU
                net_frac_elec_period = [0] * num_energyrate_periods
                (0...num_energyrate_periods).each do |period|
                  next unless net_elec_month[month] > 0

                  net_frac_elec_period[period] = net_elec_period[period] / net_elec_month[month]
                  (0...rate.energyratestructure[period].size).each do |t|
                    if t < net_elec_tier.size
                      net_monthly_energy_charge[month] += rate.energyratestructure[period][t][:rate] * net_frac_elec_period[period] * net_elec_tier[t]
                    end
                  end
                end
              end

              net_elec_period = [0] * num_energyrate_periods
              net_elec_tier = [0] * length_tiers.max
              net_tier = 0
            end
          end

          if pv_fuel_time_series.sum != 0 # has PV
            if rate.feed_in_tariff_rate
              bill.monthly_production_credit[month] = production_fit_month[month]
            else
              bill.monthly_production_credit[month] = bill.monthly_energy_charge[month] - net_monthly_energy_charge[month]
            end
            bill.annual_production_credit += bill.monthly_production_credit[month]
          end
        end

        today += 1 # next day
      end # (0...fuel_time_series.size).to_a.each do |hour|

      annual_fixed_charge = bill.monthly_fixed_charge.sum
      annual_energy_charge = bill.monthly_energy_charge.sum
      annual_total_charge = annual_energy_charge + annual_fixed_charge
      true_up_month = 12

      if pv_fuel_time_series.sum != 0 && !rate.feed_in_tariff_rate # Net metering calculations

        annual_payments, end_of_year_bill_credit = apply_min_charges(bill.monthly_fixed_charge, net_monthly_energy_charge, rate.minannualcharge, rate.minmonthlycharge, true_up_month)
        end_of_year_bill_credit, excess_sellback = apply_excess_sellback(end_of_year_bill_credit, rate.net_metering_excess_sellback_type, rate.net_metering_user_excess_sellback_rate, net_elec_energy_ann)

        annual_total_charge_with_pv = annual_payments + end_of_year_bill_credit - excess_sellback
        bill.annual_production_credit = annual_total_charge - annual_total_charge_with_pv

      else # Either no PV or PV with FIT (Assume minimum charge does not apply to FIT systems)
        if rate.minannualcharge.nil?

          monthly_bill = [0] * 12
          (0..11).to_a.each do |m|
            monthly_bill[m] = bill.monthly_energy_charge[m] + bill.monthly_fixed_charge[m]
            if monthly_bill[m] < rate.minmonthlycharge
              bill.monthly_energy_charge[m] += (rate.minmonthlycharge - monthly_bill[m])
            end
          end

          annual_energy_charge = bill.monthly_energy_charge.sum

        else # California-style annual minimum
          # TODO
        end
      end

      bill.annual_energy_charge = annual_energy_charge
      bill.annual_fixed_charge = annual_fixed_charge
    end # if !rate.energyratestructure.empty? || !rate.fixedmonthlycharge.nil?
  end

  def self.apply_min_charges(monthly_fixed_charge, net_monthly_energy_charge, annual_min_charge, monthly_min_charge, true_up_month)
    # Calculate monthly payments, rollover, and min charges
    if annual_min_charge.nil?
      payments = [0] * 12
      rollover = [0] * 12
      net_monthly_bill = [0] * 12
      months_loop = (true_up_month...12).to_a + (0...true_up_month).to_a
      months_loop.to_a.each_with_index do |m, i|
        net_monthly_bill[m] = net_monthly_energy_charge[m] + monthly_fixed_charge[m]
        # Pay bill if rollover can't cover it, or just pay min charge.
        payments[i] = [net_monthly_bill[m] + rollover[i - 1], monthly_min_charge].max

        if net_monthly_bill[m] <= 0
          # Surplus this month, add to rollover total
          rollover[i] += (rollover[i - 1] + net_monthly_bill[m] - payments[i] + [monthly_min_charge - monthly_fixed_charge[m], 0].max)

        elsif rollover[i - 1] < 0
          # Use previous month's bill credit to pay this bill; subtract from rollover total
          rollover[i] += (rollover[i - 1] + net_monthly_bill[m] - payments[i])

        end
      end
      annual_payments = payments.sum
      end_of_year_bill_credit = rollover[-1]

    else # California-style Annual True-Up
      # TODO
    end

    return annual_payments, end_of_year_bill_credit
  end

  def self.apply_excess_sellback(end_of_year_bill_credit, net_metering_excess_sellback_type, net_metering_user_excess_sellback_rate, net_elec_energy_ann)
    if net_metering_excess_sellback_type == HPXML::PVAnnualExcessSellbackRateTypeRetailElectricityCost
      excess_sellback = 0
    else
      excess_sellback = -[net_elec_energy_ann, 0].min * net_metering_user_excess_sellback_rate
      end_of_year_bill_credit = 0
    end

    return end_of_year_bill_credit, excess_sellback
  end

  def self.real_time_pricing(header, fuels, rate, bill, net_elec)
    fuel_time_series = fuels[[FT::Elec, false]].timeseries
    pv_fuel_time_series = fuels[[FT::Elec, true]].timeseries

    year = header.sim_calendar_year
    start_day = DateTime.new(year, header.sim_begin_month, header.sim_begin_day)
    today = start_day

    hourly_fuel_cost = [0] * fuel_time_series.size
    net_hourly_fuel_cost = [0] * fuel_time_series.size
    bill.monthly_energy_charge = [0] * 12
    net_monthly_energy_charge = [0] * 12
    production_fit_month = [0] * 12

    (0...fuel_time_series.size).to_a.each do |hour|
      hour_day = hour % 24 # calculate hour of the day

      month = today.month - 1

      elec_hour = fuel_time_series[hour]

      if pv_fuel_time_series.sum != 0 # has PV
        pv_hour = pv_fuel_time_series[hour]
        net_elec_hour = elec_hour - pv_hour
        net_elec += net_elec_hour
      end

      elec_rate = rate.realtimeprice[hour]
      hourly_fuel_cost[hour] = elec_hour * elec_rate
      bill.monthly_energy_charge[month] += hourly_fuel_cost[hour]

      if pv_fuel_time_series.sum != 0 # has PV
        if rate.feed_in_tariff_rate
          production_fit_month[month] += pv_hour * rate.feed_in_tariff_rate
        else
          net_elec_rate = rate.realtimeprice[hour]
          net_hourly_fuel_cost[hour] = net_elec_hour * net_elec_rate
          net_monthly_energy_charge[month] += net_hourly_fuel_cost[hour]
        end
      end

      next unless hour_day == 23 # last hour of the day

      if Schedule.day_end_months(year).include?(today.yday)
        if not rate.fixedmonthlycharge.nil?
          # If the run period doesn't span the entire month, prorate the fixed charges
          prorate_fraction = calculate_monthly_prorate(header, month + 1)
          bill.monthly_fixed_charge[month] = rate.fixedmonthlycharge * prorate_fraction
        end

        if pv_fuel_time_series.sum != 0 # has PV
          if rate.feed_in_tariff_rate
            bill.monthly_production_credit[month] = production_fit_month[month]
          else
            bill.monthly_production_credit[month] = bill.monthly_energy_charge[month] - net_monthly_energy_charge[month]
          end
          bill.annual_production_credit += bill.monthly_production_credit[month]
        end
      end

      today += 1 # next day
    end

    annual_fixed_charge = bill.monthly_fixed_charge.sum
    annual_energy_charge = bill.monthly_energy_charge.sum
    # FIXME: unclear at this time whether real-time pricing should have applicable min monthly charges
    # annual_total_charge = annual_energy_charge + annual_fixed_charge
    # true_up_month = 12

    # if pv_fuel_time_series.sum != 0 && !rate.feed_in_tariff_rate # Net metering calculations

      # annual_payments, end_of_year_bill_credit = apply_min_charges(bill.monthly_fixed_charge, net_monthly_energy_charge, rate.minannualcharge, rate.minmonthlycharge, true_up_month)
      # end_of_year_bill_credit, excess_sellback = apply_excess_sellback(end_of_year_bill_credit, rate.net_metering_excess_sellback_type, rate.net_metering_user_excess_sellback_rate, net_elec_energy_ann)

      # annual_total_charge_with_pv = annual_payments + end_of_year_bill_credit - excess_sellback
      # bill.annual_production_credit = annual_total_charge - annual_total_charge_with_pv

    # else # Either no PV or PV with FIT (Assume minimum charge does not apply to FIT systems)
      # if rate.minannualcharge.nil?

        # monthly_bill = [0] * 12
        # (0..11).to_a.each do |m|
          # monthly_bill[m] = bill.monthly_energy_charge[m] + bill.monthly_fixed_charge[m]
          # if monthly_bill[m] < rate.minmonthlycharge
            # bill.monthly_energy_charge[m] += (rate.minmonthlycharge - monthly_bill[m])
          # end
        # end

        # annual_energy_charge = bill.monthly_energy_charge.sum

      # else # California-style annual minimum
        # # TODO
      # end
    # end

    bill.annual_energy_charge = annual_energy_charge
    bill.annual_fixed_charge = annual_fixed_charge
    return net_elec
  end

  def self.calculate_monthly_prorate(header, month)
    begin_month = header.sim_begin_month
    begin_day = header.sim_begin_day
    end_month = header.sim_end_month
    end_day = header.sim_end_day
    year = header.sim_calendar_year

    if month < begin_month || month > end_month
      num_days_in_month = 0
    else
      if month == begin_month
        day_begin = begin_day
      else
        day_begin = 1
      end
      if month == end_month
        day_end = end_day
      else
        day_end = Constants.NumDaysInMonths(year)[month - 1]
      end
      num_days_in_month = day_end - day_begin + 1
    end

    return num_days_in_month.to_f / Constants.NumDaysInMonths(year)[month - 1]
  end
end

def valid_filename(x)
  x = "#{x}".gsub(/[^0-9A-Za-z\s]/, '') # remove non-alphanumeric
  x = "#{x}".gsub(/\s+/, ' ').strip # remove multiple spaces
  return x
end

def process_usurdb(filepath)
  require 'csv'
  require 'json'

  skip_keywords = true
  keywords = ['lighting',
              'lights',
              'private light',
              'yard light',
              'security light',
              'lumens',
              'watt hps',
              'incandescent',
              'halide',
              'lamps',
              '[partial]',
              'rider',
              'irrigation',
              'grain']

  puts 'Parsing CSV...'
  rates = CSV.read(filepath, headers: true)
  rates = rates.map { |d| d.to_hash }

  puts 'Selecting residential rates...'
  residential_rates = []
  rates.each do |rate|
    # rates to skip
    next if rate['sector'] != 'Residential'
    next if !rate['enddate'].nil?
    next if keywords.any? { |x| rate['name'].downcase.include?(x) } && skip_keywords

    # map fixed charge to version 3
    if rate['fixedchargeunits'] == '$/day'
      next
    elsif rate['fixedchargeunits'] == '$/month'
      rate['fixedmonthlycharge'] = rate['fixedchargefirstmeter'] if !rate['fixedchargefirstmeter'].nil?
      rate['fixedmonthlycharge'] += rate['fixedchargeeaaddl'] if !rate['fixedchargeeaaddl'].nil?
    elsif rate['fixedchargeunits'] == '$/year'
      next
    end

    # map min charge to version 3
    if rate['minchargeunits'] == '$/day'
      next
    elsif rate['minchargeunits'] == '$/month'
      rate['minmonthlycharge'] = rate['mincharge'] if !rate['mincharge'].nil?
    elsif rate['minchargeunits'] == '$/year'
      rate['annualmincharge'] = rate['mincharge'] if !rate['mincharge'].nil?
    end

    rate.delete('fixedchargefirstmeter')
    rate.delete('fixedchargeeaaddl')
    rate.delete('fixedchargeunits')
    rate.delete('mincharge')
    rate.delete('minchargeunits')

    # ignore blank fields
    rate.each do |k, v|
      rate.delete(k) if v.nil?
    end

    # map schedules and structures
    structures = {}
    rate.each do |k, v|
      if ['eiaid'].include?(k)
        rate[k] = Integer(Float(v))
      elsif k.include?('schedule')
        rate[k] = eval(v) # arrays
      elsif k.include?('structure')
        rate.delete(k)

        k, period, tier = k.split('/')
        period_idx = Integer(period.gsub('period', ''))
        tier_idx = nil
        tier_name = nil
        ['max', 'unit', 'rate', 'adj', 'sell'].each do |k2|
          if tier.include?(k2)
            tier_idx = Integer(tier.gsub('tier', '').gsub(k2, ''))
            tier_name = k2
          end
        end

        # init
        if !structures.keys.include?(k)
          structures[k] = []
        end
        if structures[k].size == period_idx
          structures[k] << []
        end
        if structures[k][period_idx].size == tier_idx
          structures[k][period_idx] << {}
        end

        begin
          v = Float(v)
        rescue # string
        end

        structures[k][period_idx][tier_idx][tier_name] = v
      else # not eiaid, schedule, or structure
        begin
          rate[k] = Float(v)
        rescue # string
        end
      end
    end

    rate.update(structures)

    # ignore rates with demand charges
    next if !rate['demandweekdayschedule'].nil? || !rate['demandweekendschedule'].nil? || !rate['demandratestructure'].nil? || !rate['flatdemandstructure'].nil?

    # ignore rates without minimum fields
    next if rate['energyweekdayschedule'].nil? || rate['energyweekendschedule'].nil? || rate['energyratestructure'].nil?

    residential_rates << { 'items' => [rate] }
  end

  puts 'Exporting residential rates...'
  rates_dir = File.dirname(filepath)
  residential_rates.each do |residential_rate|
    utility = valid_filename(residential_rate['items'][0]['utility'])
    name = valid_filename(residential_rate['items'][0]['name'])
    startdate = residential_rate['items'][0]['startdate']

    filename = "#{utility} - #{name}"
    filename += " (Effective #{startdate.split(' ')[0]})" if !startdate.nil?

    ratepath = File.join(rates_dir, "#{filename}.json")
    File.open(ratepath, 'w') do |f|
      json = JSON.pretty_generate(residential_rate)
      f.write(json)
    end
  end

  FileUtils.rm(filepath)
end
