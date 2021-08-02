#!/usr/bin/env python

from setuptools import Distribution, setup, find_packages
from setuptools.extension import Extension

# Fetch numpy and Cython as build dependencies.
Distribution().fetch_build_eggs(['numpy', 'Cython'])

from Cython.Build import cythonize  # noqa: E402


setup(
    name='posixshmem',
    version='0.1.1',
    description='Small python library to access POSIX shared memory.',
    author='Philipp Schmidt',
    author_email='philipp.schmidt@xfel.eu',

    python_requires='>=3.6',
    ext_modules=cythonize([
        Extension('posixshmem', ['src/posixshmem.pyx'],
                  extra_compile_args=['-g0', '-O2', '-fpic'],
                  extra_link_args=['-lrt']),
    ], language_level=3, build_dir='build'),
)
