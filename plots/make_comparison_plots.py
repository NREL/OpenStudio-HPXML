import os
import argparse
import numpy as np
import pandas as pd
import bokeh.io as bio
import bokeh.plotting as bplt
from bokeh.models import ColumnDataSource, HoverTool
from bokeh.models.annotations import Label, Slope
from bokeh.layouts import gridplot
from lxml import etree
import re


here = os.path.dirname(os.path.abspath(__file__))


def get_address_from_hpxml_file(hpxml_filename):
    hpxml_filepath = os.path.join(here, '..', 'workflow', 'sample_files', hpxml_filename)
    tree = etree.parse(hpxml_filepath)
    address = tree.xpath('//h:Address1/text()', namespaces={'h': 'http://hpxmlonline.com/2019/10'}, smart_strings=False)[0]
    return address


def rename_col(colname):
    m = re.match(r'(\w+): (\w+) \[(\w+)\]', colname)
    if m:
        fueltype, enduse, units = m.groups()
        return f'{enduse}_{fueltype}'
    else:
        return colname


def make_comparison_plots(df_doe2, df_os):
    df_os2 = df_os.rename(columns=rename_col)
    df_os2['address'] = df_os2['HPXML'].map(get_address_from_hpxml_file)
    df = df_doe2.merge(df_os2, on='address', suffixes=('_doe2', '_os'))
    cols_to_diff_against_base = list(filter(re.compile(r'_(doe2|os)$').search, df.columns.values))
    df_diff = df[cols_to_diff_against_base].subtract(df[df['HPXML'] == 'Base_hpxml.xml'][cols_to_diff_against_base].values, axis=1)
    df2 = df.merge(df_diff, left_index=True, right_index=True, suffixes=('', '_basediff'))

    plots_dir = os.path.join(here, 'plots')
    if not os.path.exists(plots_dir):
        os.makedirs(plots_dir)
    bio.output_file(os.path.join(plots_dir, 'comparison_plots.html'))
    data_source = ColumnDataSource(df2)
    figures = []
    for colname in map(lambda y: y[:-5], filter(lambda x: x.endswith('_doe2'), df.columns)):
        row_figs = []
        for basediff in ('', '_basediff'):
            doe2_colname = colname + '_doe2' + basediff
            os_colname = colname + '_os' + basediff
            maxval = df2[[doe2_colname, os_colname]].max().max()
            minval = df2[[doe2_colname, os_colname]].min().min()
            minmaxrange = maxval - minval
            maxval += minmaxrange * 0.05
            minval -= minmaxrange * 0.05
            plot_title = colname + basediff
            p = bplt.figure(
                tools='pan,wheel_zoom,box_zoom,reset,save,box_select,lasso_select',
                width=400,
                height=400,
                title=plot_title,
                x_range=(minval, maxval),
                y_range=(minval, maxval)
            )
            p.xaxis.axis_label = 'DOE2'
            p.yaxis.axis_label = 'EnergyPlus'
            p.add_layout(Slope(gradient=1, y_intercept=0, line_color='firebrick'))
            c = p.circle(x=doe2_colname, y=os_colname, source=data_source)
            hover = HoverTool(
                tooltips=[
                    ('filename', '@HPXML'),
                    ('address', '@address'),
                    ('DOE2', f'@{doe2_colname}{{0,0.}}'),
                    ('E+', f'@{os_colname}{{0,0.}}')
                ],
                renderers=[c]
            )
            p.add_tools(hover)
            if not basediff:
                rmse = np.sqrt(np.mean((df[os_colname] - df[doe2_colname]).values**2))
                rmse_label = Label(x=maxval, y=minval, text=f'RMSE: {rmse:,.1f}', text_align='right')
                p.add_layout(rmse_label)
            row_figs.append(p)
        figures.append(row_figs)

    grid = gridplot(figures)
    bio.save(grid)
    


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--doe2_csv',
        type=argparse.FileType('r'),
        default=os.path.join(here, 'enduse_mstr_stg_v7_200303.csv')
    )
    parser.add_argument(
        'results_csv',
        type=argparse.FileType('r')
    )
    args = parser.parse_args()
    df_doe2 = pd.read_csv(args.doe2_csv)
    df_os = pd.read_csv(args.results_csv)
    make_comparison_plots(df_doe2, df_os)

if __name__ == '__main__':
    main()
