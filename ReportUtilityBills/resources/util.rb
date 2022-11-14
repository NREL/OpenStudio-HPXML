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
    @realtimeprice = nil

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

    @monthly_energy_charge = [0] * 12
    @monthly_fixed_charge = [0] * 12

    @monthly_production_credit = [0] * 12
    @annual_production_credit = 0.0
  end
  attr_accessor(:annual_energy_charge, :annual_fixed_charge, :annual_total,
                :monthly_energy_charge, :monthly_fixed_charge,
                :monthly_production_credit, :annual_production_credit)
end

class CalculateUtilityBill
  def self.simple(fuel_type, header, fuel_time_series, is_production, rate, bill, net_elec)
    if fuel_time_series.size > 12
      # Must be no more than 12 months worth of simulation data
      fail 'Incorrect timeseries data.'
    end

    monthly_fuel_cost = [0] * 12
    for month in 0..fuel_time_series.size - 1
      if is_production && fuel_type == FT::Elec && rate.feed_in_tariff_rate
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.feed_in_tariff_rate
      else
        monthly_fuel_cost[month] = fuel_time_series[month] * rate.flatratebuy
      end

      if fuel_type == FT::Elec
        if is_production # has PV
          net_elec -= fuel_time_series[month]
        else
          net_elec += fuel_time_series[month]
        end
      end

      if is_production
        bill.monthly_production_credit[month] = monthly_fuel_cost[month]
      else
        bill.monthly_energy_charge[month] = monthly_fuel_cost[month]
        if not rate.fixedmonthlycharge.nil?
          # If the run period doesn't span the entire month, prorate the fixed charges
          prorate_fraction = calculate_monthly_prorate(header, month + 1)
          bill.monthly_fixed_charge[month] = rate.fixedmonthlycharge * prorate_fraction
        end
      end
    end

    bill.annual_energy_charge = bill.monthly_energy_charge.sum(0.0)
    bill.annual_fixed_charge = bill.monthly_fixed_charge.sum(0.0)
    bill.annual_production_credit = bill.monthly_production_credit.sum(0.0)

    if is_production && rate.net_metering_excess_sellback_type == HPXML::PVAnnualExcessSellbackRateTypeUserSpecified
      # Annual True-Up
      # Only make changes for cases where there's a user specified annual excess sellback rate
      if bill.annual_production_credit > bill.annual_energy_charge
        bill.annual_production_credit = bill.annual_energy_charge
      end
      if net_elec < 0 # net producer, give credit at user specified rate
        bill.annual_production_credit += -net_elec * rate.net_metering_user_excess_sellback_rate
      end
    end
    return net_elec
  end

  def self.detailed_electric(header, fuels, rate, bill)
    fuel_time_series = fuels[[FT::Elec, false]].timeseries
    pv_fuel_time_series = fuels[[FT::Elec, true]].timeseries

    if fuel_time_series.size < 24 || pv_fuel_time_series.size < 24
      # Must be at least 24 hours worth of simulation data
      fail 'Incorrect timeseries data.'
    end

    year = header.sim_calendar_year
    start_day = DateTime.new(year, header.sim_begin_month, header.sim_begin_day)
    today = start_day

    net_monthly_energy_charge = [0] * 12
    production_fit_month = [0] * 12
    has_pv = (pv_fuel_time_series.sum != 0)
    elec_month = [0] * 12
    net_elec_month = [0] * 12

    if !rate.realtimeprice.nil?
      num_periods = 0
      num_tiers = 0
    else
      num_periods = rate.energyratestructure.size
      num_tiers = rate.energyratestructure.map { |period| period.size }.max

      rate.energyratestructure.each do |period|
        period.each do |tier|
          tier[:rate] += tier[:adj] if tier.keys.include?(:adj)
        end
      end

      tier = 0
      net_tier = 0
      elec_period = [0] * num_periods
      elec_tier = [0] * num_tiers
      if has_pv
        net_elec_period = [0] * num_periods
        net_elec_tier = [0] * num_tiers
      end
    end

    for hour in 0..fuel_time_series.size - 1
      hour_day = hour % 24 # calculate hour of the day

      month = today.month - 1

      elec_hour = fuel_time_series[hour]
      elec_month[month] += elec_hour

      if has_pv
        pv_hour = pv_fuel_time_series[hour]
        net_elec_hour = elec_hour - pv_hour
        net_elec_month[month] += net_elec_hour
      end

      if !rate.realtimeprice.nil?
        # Real-Time Pricing
        bill.monthly_energy_charge[month] += elec_hour * rate.realtimeprice[hour]

        if has_pv
          if rate.feed_in_tariff_rate
            production_fit_month[month] += pv_hour * rate.feed_in_tariff_rate
          else
            net_monthly_energy_charge[month] += net_elec_hour * rate.realtimeprice[hour]
          end
        end

      else
        # Tiered and/or Time-of-Use

        if (num_periods != 0) || (num_tiers != 0)
          if (1..5).to_a.include?(today.wday) # weekday
            sched_rate = rate.energyweekdayschedule[month][hour_day]
          else # weekend
            sched_rate = rate.energyweekendschedule[month][hour_day]
          end
        end

        if (num_periods > 1) || (num_tiers > 1) # tiered or TOU
          tiers = rate.energyratestructure[sched_rate]

          if num_tiers > 1

            # init
            new_tier = false
            if tiers.size > 1 && tier < tiers.size
              if tiers[tier].keys.include?(:max) && elec_month[month] >= tiers[tier][:max]
                tier += 1
                new_tier = true
                elec_lower_tier = elec_hour - (elec_month[month] - tiers[tier - 1][:max])
              end
            end

            if num_periods == 1 # tiered only
              if new_tier
                bill.monthly_energy_charge[month] += (elec_lower_tier * tiers[tier - 1][:rate]) + ((elec_hour - elec_lower_tier) * tiers[tier][:rate])
              else
                bill.monthly_energy_charge[month] += elec_hour * tiers[tier][:rate]
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
            bill.monthly_energy_charge[month] += elec_hour * tiers[0][:rate]
          end
        else # not tiered or TOU
          bill.monthly_energy_charge[month] += elec_hour * rate.energyratestructure[0][0][:rate]
        end

        if has_pv
          if rate.feed_in_tariff_rate
            production_fit_month[month] += pv_hour * rate.feed_in_tariff_rate
          else
            if (num_periods > 1) || (num_tiers > 1)
              if num_tiers > 1

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

                if num_periods == 1 # tiered only
                  if net_new_tier
                    net_monthly_energy_charge[month] += (net_elec_lower_tier * tiers[net_tier - 1][:rate]) + ((net_elec_hour - net_elec_lower_tier) * tiers[net_tier][:rate])
                  elsif net_lower_tier
                    net_monthly_energy_charge[month] += (net_elec_upper_tier * tiers[net_tier + 1][:rate]) + ((net_elec_hour - net_elec_upper_tier) * tiers[net_tier][:rate])
                  else
                    net_monthly_energy_charge[month] += net_elec_hour * tiers[net_tier][:rate]
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
                net_monthly_energy_charge[month] += net_elec_hour * tiers[0][:rate]
              end
            else # not tiered or TOU
              net_monthly_energy_charge[month] += net_elec_hour * rate.energyratestructure[0][0][:rate]
            end
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

        if (num_periods > 1) || (num_tiers > 1) # tiered or TOU

          if num_periods > 1 && num_tiers > 1 # tiered and TOU
            frac_elec_period = [0] * num_periods
            for period in 0..num_periods - 1
              frac_elec_period[period] = elec_period[period] / elec_month[month]
              for t in 0..rate.energyratestructure[period].size - 1
                if t < elec_tier.size
                  bill.monthly_energy_charge[month] += rate.energyratestructure[period][t][:rate] * frac_elec_period[period] * elec_tier[t]
                end
              end
            end
          end

          elec_period = [0] * num_periods
          elec_tier = [0] * num_tiers
          tier = 0
        end

        if has_pv && !rate.feed_in_tariff_rate # has PV
          if (num_periods > 1) || (num_tiers > 1) # tiered or TOU

            if num_periods > 1 && num_tiers > 1 # tiered and TOU
              net_frac_elec_period = [0] * num_periods
              for period in 0..num_periods - 1
                net_frac_elec_period[period] = net_elec_period[period] / net_elec_month[month]
                for t in 0..rate.energyratestructure[period].size - 1
                  if t < net_elec_tier.size
                    net_monthly_energy_charge[month] += rate.energyratestructure[period][t][:rate] * net_frac_elec_period[period] * net_elec_tier[t]
                  end
                end
              end
            end

            net_elec_period = [0] * num_periods
            net_elec_tier = [0] * num_tiers
            net_tier = 0
          end
        end

        if has_pv
          if rate.feed_in_tariff_rate
            bill.monthly_production_credit[month] = production_fit_month[month]
          else
            bill.monthly_production_credit[month] = bill.monthly_energy_charge[month] - net_monthly_energy_charge[month]
          end
          bill.annual_production_credit += bill.monthly_production_credit[month]
        end
      end

      today += 1 # next day
    end # for hour in 0..fuel_time_series.size-1

    annual_total_charge = bill.monthly_energy_charge.sum + bill.monthly_fixed_charge.sum

    if has_pv && !rate.feed_in_tariff_rate # Net metering calculations
      annual_payments, monthly_min_charges, end_of_year_bill_credit = apply_min_charges(bill.monthly_fixed_charge, net_monthly_energy_charge, rate.minannualcharge, rate.minmonthlycharge)
      end_of_year_bill_credit, excess_sellback = apply_excess_sellback(end_of_year_bill_credit, rate.net_metering_excess_sellback_type, rate.net_metering_user_excess_sellback_rate, net_elec_month.sum(0.0))

      annual_total_charge_with_pv = annual_payments + end_of_year_bill_credit - excess_sellback
      bill.annual_production_credit = annual_total_charge - annual_total_charge_with_pv
      for m in 0..11
        bill.monthly_fixed_charge[m] += monthly_min_charges[m]
      end

    else # Either no PV or PV with FIT
      if rate.minannualcharge.nil?
        for m in 0..11
          monthly_bill = bill.monthly_energy_charge[m] + bill.monthly_fixed_charge[m]
          if monthly_bill < rate.minmonthlycharge
            bill.monthly_fixed_charge[m] += (rate.minmonthlycharge - monthly_bill)
          end
        end
      else
        if annual_total_charge < rate.minannualcharge
          bill.monthly_fixed_charge[11] += (rate.minannualcharge - annual_total_charge)
        end
      end
    end

    bill.annual_fixed_charge = bill.monthly_fixed_charge.sum
    bill.annual_energy_charge = bill.monthly_energy_charge.sum
  end

  def self.apply_min_charges(monthly_fixed_charge, net_monthly_energy_charge, annual_min_charge, monthly_min_charge)
    # Calculate monthly payments, rollover, and min charges
    monthly_min_charges = [0] * 12
    if annual_min_charge.nil?
      monthly_payments = [0] * 12
      monthly_rollover = [0] * 12
      for m in 0..11
        net_monthly_bill = net_monthly_energy_charge[m] + monthly_fixed_charge[m]
        # Pay bill if rollover can't cover it, or just pay min.
        monthly_payments[m] = [net_monthly_bill + monthly_rollover[m - 1], monthly_fixed_charge[m]].max
        if monthly_payments[m] < monthly_min_charge
          monthly_min_charges[m] += monthly_min_charge - monthly_payments[m]
        end
        monthly_rollover[m] += (monthly_rollover[m - 1] + net_monthly_bill - monthly_payments[m])
      end
      annual_payments = monthly_payments.sum
      end_of_year_bill_credit = monthly_rollover[-1]

    else
      annual_fixed_charge = monthly_fixed_charge.sum
      net_annual_bill = net_monthly_energy_charge.sum + annual_fixed_charge
      annual_payments = [net_annual_bill, annual_fixed_charge].max

      if annual_payments < annual_min_charge
        monthly_min_charges[11] = annual_min_charge - annual_payments
      end
      end_of_year_bill_credit = net_annual_bill - annual_payments
    end

    return annual_payments, monthly_min_charges, end_of_year_bill_credit
  end

  def self.apply_excess_sellback(end_of_year_bill_credit, net_metering_excess_sellback_type, net_metering_user_excess_sellback_rate, net_elec)
    # Note: Annual excess sellback can only be calculated at the end of the year on the net electricity consumption.
    if net_metering_excess_sellback_type == HPXML::PVAnnualExcessSellbackRateTypeRetailElectricityCost
      excess_sellback = 0
    else
      excess_sellback = -[net_elec, 0].min * net_metering_user_excess_sellback_rate
      end_of_year_bill_credit = 0
    end

    return end_of_year_bill_credit, excess_sellback
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
  # Map csv found at https://openei.org/apps/USURDB/download/usurdb.csv.gz to
  # https://openei.org/services/doc/rest/util_rates/?version=7#response-fields
  require 'csv'
  require 'json'
  require 'zip'

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

  puts 'Creating hashes...'
  rates = rates.map { |d| d.to_hash }

  puts 'Selecting residential rates...'
  residential_rates = []
  rates.each do |rate|
    # rates to skip
    next if rate['sector'] != 'Residential'
    next if !rate['enddate'].nil?
    next if keywords.any? { |x| rate['name'].downcase.include?(x) } && skip_keywords

    # fixed charges
    if ['$/day', '$/year'].include?(rate['fixedchargeunits'])
      next
    end

    # min charges
    if ['$/day'].include?(rate['minchargeunits'])
      next
    end

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
        # all of a sudden some fields have an "L" character (?)
        rate[k] = eval(v.gsub('L', '')) # arrays
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

    # ignore rates without a "rate" key
    next if rate['energyratestructure'].collect { |r| r.collect { |s| s.keys.include?('rate') } }.flatten.any? { |t| !t }

    # ignore rates with negative "rate" value
    next if rate['energyratestructure'].collect { |r| r.collect { |s| s['rate'] >= 0 } }.flatten.any? { |t| !t }

    # ignore rates with a "sell" key
    next if rate['energyratestructure'].collect { |r| r.collect { |s| s.keys } }.flatten.uniq.include?('sell')

    # set rate units to 'kWh'
    rate['energyratestructure'].collect { |r| r.collect { |s| s['unit'] = 'kWh' } }

    residential_rates << { 'items' => [rate] }
  end

  FileUtils.rm(filepath)

  puts 'Exporting residential rates...'
  rates_dir = File.dirname(filepath)
  zippath = File.join(rates_dir, 'openei_rates.zip')
  FileUtils.rm(zippath)
  zipcontents = []
  Zip::File.open(zippath, create: true) do |zipfile|
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
      zipname = File.basename(ratepath)
      next if zipcontents.include?(zipname)

      zipfile.add(zipname, ratepath)
      zipcontents << zipname
    end
  end

  num_rates_actual = Dir[File.join(rates_dir, '*.json')].count
  FileUtils.rm(Dir[File.join(rates_dir, '*.json')])

  return num_rates_actual
end
