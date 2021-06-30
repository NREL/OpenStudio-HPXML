import os
import argparse
import pandas as pd
import csv

class Compare:

  def samples(self, base_folder, feature_folder, export_folder):

    def value_counts(df, file):
      value_counts = []
      with open(file, 'w', newline='') as f:

        for col in sorted(df.columns):
          if col == 'Building':
            continue

          value_count = df[col].value_counts(normalize=True)
          value_count = value_count.round(2)
          keys_to_values = dict(zip(value_count.index.values, value_count.values))
          keys_to_values = dict(sorted(keys_to_values.items(), key=lambda x: (x[1], x[0]), reverse=True))
          value_counts.append([value_count.name])
          value_counts.append(keys_to_values.keys())
          value_counts.append(keys_to_values.values())
          value_counts.append('')

        w = csv.writer(f)
        w.writerows(value_counts)

    df = pd.read_csv(os.path.join(base_folder, 'base_buildstock.csv'))
    file = os.path.join(export_folder, 'base_samples.csv')
    value_counts(df, file)

    df = pd.read_csv(os.path.join(feature_folder, 'buildstock.csv'))
    file = os.path.join(export_folder, 'feature_samples.csv')
    value_counts(df, file)


  def results(self, base_folder, feature_folder, export_folder, aggregate_by=[]):
    base = 'base'
    feature = 'feature'

    files = []
    for file in os.listdir(base_folder):
      if file.endswith('.csv'):
        files.append(file)

    for file in files:
      results = { base: {}, feature: {} }

      # load files
      for key in results.keys():
        if key == base:
          results[key]['file'] = 'workflow/tests/base_results/{file}'.format(file=file)
        elif key == feature:
          results[key]['file'] = 'workflow/tests/results/{file}'.format(file=file)

        filepath = os.path.join(os.getcwd(), results[key]['file'])
        if os.path.isfile(filepath):
          with open(filepath) as f:
            results[key]['rows'] = list(csv.reader(f))
        else:
          print('Could not find {filepath}.'.format(filepath=filepath))

      if (not 'rows' in results[base].keys()) or (not 'rows' in results[feature].keys()):
        continue

      # get columns
      for key in results.keys():
        results[key]['cols'] = results[key]['rows'][0][1:-1] # exclude index column

      # get data
      for key in results.keys():
        for row in results[key]['rows'][1:-1]:
          hpxml = row[0]
          results[key][hpxml] = {}
          for i, field in enumerate(row[1:-1]):
            col = results[key]['cols'][i]

            if field is None:
              vals = [''] # string
            elif ',' in field:
              try:
                # vals = field.split(',').map { |x| Float(x) } # float
                vals = [float(x) for x in field.split(',')]
              except ValueError:
                vals = [field] # string
            else:
              try:
                vals = [Float(field)] # float
              except ValueError:
                vals = [field] # string

            results[key][hpxml][col] = vals

      # get hpxml union
      base_hpxmls = list(map(list, zip(*results[base]['rows'])))[0][1:-1]
      feature_hpxmls = list(map(list, zip(*results[feature]['rows'])))[0][1:-1]
      hpxmls = list(set(base_hpxmls) | set(feature_hpxmls))

      # get column union
      base_cols = results[base]['cols']
      feature_cols = results[feature]['cols']
      cols = list(set(base_cols) | set(feature_cols))

      # create comparison table
      rows = [[results[base]['rows'][0][0]] + cols] # index column + union of all other columns

      # populate the rows hash
      for hpxml in sorted(hpxmls):
        row = [hpxml]
        for i, col in enumerate(cols):
          if hpxml in results[base].keys() and (not hpxml in results[feature].keys()): # feature removed an xml
            m = 'N/A'
          elif (not hpxml in results[base].keys()) and hpxml in results[feature].keys(): # feature added an xml
            m = 'N/A'
          elif col in results[base][hpxml].keys() and (not col in results[feature][hpxml].keys()): # feature removed a column
            m = 'N/A'
          elif (not col in results[base][hpxml].keys()) and col in results[feature][hpxml].keys(): # feature added a column
            m = 'N/A'
          else:
            base_field = results[base][hpxml][col]
            feature_field = results[feature][hpxml][col]

            try:
              # float comparisons
              m = []
              for b, f in list(zip(base_field, feature_field)):
                m.append(round((f - b), 1))
            except TypeError:
              # string comparisons
              m = []
              for b, f in list(zip(base_field, feature_field)):
                if b != f:
                  m.append(1)
                else:
                  m.append(0)

            m = sum(m)

          row.append(m)

        rows.append(row)

      # export comparison table
      with open(os.path.join(export_folder, file), 'w', newline='') as f:
        w = csv.writer(f)
        w.writerows(rows)

  def visualize(self, base_folder, feature_folder, export_folder):
    return None



if __name__ == '__main__':

  default_base_folder = 'workflow/tests/base_results'
  default_feature_folder = 'workflow/tests/results'
  default_export_folder = 'workflow/tests/comparisons'

  actions = [method for method in dir(Compare) if method.startswith('__') is False]

  parser = argparse.ArgumentParser()
  parser.add_argument('-b', '--base_folder', default=default_base_folder, help='TODO')
  parser.add_argument('-f', '--feature_folder', default=default_feature_folder, help='TODO')
  parser.add_argument('-a', '--actions', action='append', choices=actions, help='TODO')
  parser.add_argument('-e', '--export_folder', default=default_export_folder, help='TODO')
  args = parser.parse_args()

  if not os.path.exists(args.export_folder):
    os.makedirs(args.export_folder)

  compare = Compare()

  if args.actions == None:
    args.actions = []

  for action in args.actions:
    getattr(compare, action)(args.base_folder, args.feature_folder, args.export_folder)
