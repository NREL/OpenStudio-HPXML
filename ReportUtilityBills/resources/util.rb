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

    @net_metering_excess_sellback_type = nil
    @net_metering_user_excess_sellback_rate = nil

    @feed_in_tariff_rate = nil

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

  def self.detailed_electric(header, fuel_time_series, is_production, rate, bill, net_elec)
    num_energyrate_periods = rate.energyratestructure.size
    has_periods = false
    if num_energyrate_periods > 1
      has_periods = true
    end

    num_energyrate_tiers = rate.energyratestructure[0].size # can't this differ for each period?
    has_tiered = false
    if num_energyrate_tiers > 1
      has_tiered = true
    end

    year = header.sim_calendar_year
    start_day = DateTime.new(year, header.sim_begin_month, header.sim_begin_day)
    today = start_day

    hourly_fuel_cost = [0] * 8760
    bill.monthly_energy_charge = [0] * 12

    if rate.flatratebuy || !rate.energyratestructure.empty? || !rate.fixedmonthlycharge.nil?

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

        if (num_energyrate_periods > 1) || (num_energyrate_tiers > 1)
          tiers = rate.energyratestructure[sched_rate]

          if has_tiered
            tier = tiers[0] # TODO

            if !has_periods # tiered only

            else # tiered and TOU
              elec_rate = tier[:rate]

              hourly_fuel_cost[hour] = fuel_time_series[hour] * elec_rate
              bill.monthly_energy_charge[month] += hourly_fuel_cost[hour]
            end

          else # TOU only

          end
        else # not tiered or TOU
          elec_rate = rate.flatratebuy
          if (num_energyrate_periods == 1) && (num_energyrate_tiers == 1)
            elec_rate += rate.energyratestructure[0][0][:rate]

            hourly_fuel_cost[hour] = fuel_time_series[hour] * elec_rate
            bill.monthly_energy_charge[month] += hourly_fuel_cost[hour]
          end
        end

        next unless hour_day == 23 # last hour of the day

        if Schedule.day_end_months(year).include?(today.yday) # TODO: this wouldn't work if run period is within 1 month
          if is_production
            # TODO
          else
            if not rate.fixedmonthlycharge.nil?
              # If the run period doesn't span the entire month, prorate the fixed charges
              prorate_fraction = calculate_monthly_prorate(header, month + 1)
              bill.monthly_fixed_charge[month] = rate.fixedmonthlycharge * prorate_fraction
            end

            bill.annual_energy_charge += bill.monthly_energy_charge[month]
            bill.annual_fixed_charge += bill.monthly_fixed_charge[month]
          end
        end

        today += 1 # next day
      end
    end
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

def process_usurdb(filepath)
  require 'csv'
  require 'json'

  puts 'Parsing CSV...'
  rates = CSV.read(filepath, headers: true)
  rates = rates.map { |d| d.to_hash }

  puts 'Selecting residential rates...'
  residential_rates = []
  rates.each do |rate|
    next if rate['sector'] != 'Residential'

    rate.each do |k, v|
      rate.delete(k) if v.nil?
    end

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

    residential_rates << { 'items' => [rate] }
  end

  puts 'Exporting residential rates...'
  rates_dir = File.dirname(filepath)
  residential_rates.each do |residential_rate|
    label = residential_rate['items'][0]['label']
    ratepath = File.join(rates_dir, "#{label}.json")

    File.open(ratepath, 'w') do |f|
      json = JSON.pretty_generate(residential_rate)
      f.write(json)
    end
  end

  FileUtils.rm(filepath)
end
