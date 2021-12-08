import re


# Base class for errors in this package
class HPXMLtoHEScoreError(Exception):
    pass


class TranslationError(HPXMLtoHEScoreError):
    pass


class ElementNotFoundError(TranslationError):

    def __init__(self, parent, xpath, kwargs):
        self.parent = parent
        self.xpath = xpath
        self.kwargs = kwargs

    @property
    def message(self):
        tree = self.parent.getroottree()
        el_path = re.sub(r'{.*?}', '', tree.getelementpath(self.parent))
        xpath = self.xpath.replace('h:', '')
        if self.kwargs:
            post = ' with args ' + str(self.kwargs)
        else:
            post = ''
        return "Can't find element {}/{}{}".format(el_path, xpath, post)

    def __str__(self):
        return self.message


class InputOutOfBounds(HPXMLtoHEScoreError):
    def __init__(self, inpname, value):
        self.inpname = inpname
        self.value = value

    @property
    def message(self):
        return '{} is out of bounds: {}'.format(self.inpname, self.value)

    def __str__(self):
        return self.message


class RoundOutOfBounds(TranslationError):
    pass
