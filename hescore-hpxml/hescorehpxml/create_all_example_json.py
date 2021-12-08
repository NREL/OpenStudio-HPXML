from __future__ import print_function
from __future__ import unicode_literals
import os
from hescorehpxml import HPXMLtoHEScoreTranslator


def main():
    thisdir = os.path.dirname(os.path.abspath(__file__))
    exampledir = os.path.normpath(os.path.join(thisdir, '..', 'examples'))
    for filename in os.listdir(exampledir):
        filebase, ext = os.path.splitext(filename)
        if ext != '.xml':
            continue
        print(filename)
        tr = HPXMLtoHEScoreTranslator(os.path.join(exampledir, filename))
        with open(os.path.join(exampledir, filebase + '.json'), 'w') as f:
            tr.hpxml_to_hescore_json(f)


if __name__ == '__main__':
    main()
