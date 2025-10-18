from sys import argv

from .sqlite import main


main(*argv[1:])
