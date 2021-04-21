require 'csv'

folder = 'comparisons'
files = Dir[File.join(File.dirname(__FILE__), 'base_results/*.csv')].map { |x| File.basename(x) }

dir = File.join(File.dirname(__FILE__), folder)
unless Dir.exist?(dir)
  Dir.mkdir(dir)
end

files.each do |file|
  results = { 'base' => {}, 'feature' => {} }

  # load files
  results.keys.each do |key|
    begin
      results[key]['file'] = "results/#{file}"
      results[key]['rows'] = CSV.read(File.join(File.dirname(__FILE__), results[key]['file']))
    rescue
      puts "Could not find #{results[key]['file']}."
      next
    end
  end

  # get columns
  results.keys.each do |key|
    results[key]['cols'] = results[key]['rows'][0]
  end

  # get data
  results.keys.each do |key|
    results[key]['rows'][1..-1].each do |row|
      hpxml = row[0]
      results[key][hpxml] = {}
      row[1..-1].each_with_index do |field, i|
        begin
          results[key][hpxml][results[key]['cols'][i + 1]] = field.split(',').map { |x| Float(x) }
        rescue
          begin
            results[key][hpxml][results[key]['cols'][i + 1]] = field.to_s
          rescue
          end
        end
      end
    end
  end

  # get hpxml union
  base_hpxmls = results['base']['rows'].transpose[0][1..-1]
  feature_hpxmls = results['feature']['rows'].transpose[0][1..-1]
  hpxmls = base_hpxmls | feature_hpxmls

  # get column union
  base_cols = results['base']['cols']
  feature_cols = results['feature']['cols']
  cols = base_cols | feature_cols

  # create comparison table
  rows = [cols]
  hpxmls.sort.each do |hpxml|
    row = [hpxml]
    cols.each_with_index do |col, i|
      next if i == 0

      begin
        base_field = results['base'][hpxml][col]
        feature_field = results['feature'][hpxml][col]
        m = []
        base_field.zip(feature_field).each do |b, f|
          m << (f - b).round(1)
        end
        m = m.join(',')
      rescue
        begin
          m = 0
          if base_field != feature_field
            m = 1
          end
        rescue
          m = 'N/A'
        end
      end

      row << m
    end
    rows << row
  end

  # export comparison table
  CSV.open(File.join(dir, file), 'wb') do |csv|
    rows.each do |row|
      csv << row
    end
  end
end
