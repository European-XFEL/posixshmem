
from posix.fcntl cimport O_RDONLY, O_RDWR, O_CREAT
from posix.mman cimport PROT_READ, PROT_WRITE, MAP_SHARED, MAP_PRIVATE, \
    shm_open, shm_unlink, mode_t
from posix.stat cimport struct_stat, fstat
from posix.unistd cimport ftruncate
from libc.errno cimport errno

from mmap import mmap


cdef class SharedMemory:
    cdef int _fd
    cdef object _buf
    cdef object _view

    cdef object _name
    cdef size_t _size
    cdef bint _rw
    cdef int _mmap_flags

    def __cinit__(self, object name, size_t size=0, bint rw=True,
                  mode_t mode=0o777, int shm_flags=-1, int mmap_flags=-1):
        if not isinstance(name, str):
            name = str(name)

        self._name = name.encode('ascii')
        self._rw = rw
        self._buf = None
        self._view = None

        if size == 0 and rw:
            raise ValueError('size must be specified if not read only')

        if shm_flags < 0:
            shm_flags = (O_CREAT | O_RDWR) if rw else O_RDONLY

        self._fd = shm_open(self._name, shm_flags, mode)
        if self._fd == -1:
            raise OSError(errno)

        if rw:
            if ftruncate(self._fd, size) == -1:
                raise OSError(errno)

            self._mmap_flags = (PROT_WRITE | PROT_READ) if mmap_flags < 0 \
                else mmap_flags
        else:
            self._mmap_flags = PROT_READ if mmap_flags < 0 else mmap_flags

        self._size = self._get_size()

    cdef size_t _get_size(self):
        cdef struct_stat stat
        if fstat(self._fd, &stat) == -1:
            raise OSError(errno)

        return stat.st_size

    cdef object _get_buf(self):
        if self._buf is None:
            self._buf = mmap(self._fd, self._size, MAP_SHARED,
                             self._mmap_flags)

        return self._buf

    cdef object _get_view(self):
        if self._view is None:
            self._view = memoryview(self._get_buf())

        return self._view

    def __dealloc__(self):
        if self._view is not None:
            self._view = None

        if self._buf is not None:
            self._buf.close()
            self._buf = None

        if self._name is not None and self._rw:
            if shm_unlink(self._name) == -1:
                raise OSError(errno)

        self._name = None

    @property
    def fd(self):
        return self._fd

    @property
    def buf(self):
        return self._get_buf()

    @property
    def view(self):
        return self._get_view()

    @property
    def size(self):
        return self._size

    @property
    def name(self):
        return self._name.decode('ascii')

    def ndarray(self, dtype, shape=None, offset=0):
        import numpy as np

        if not isinstance(dtype, np.dtype):
            dtype = np.dtype(dtype)

        if shape is not None:
            count = int(np.array(shape).prod())
        else:
            count = int((self._size - offset) / dtype.itemsize)

        a = np.frombuffer(self._get_view(), dtype=dtype,
                          count=count, offset=offset)

        if shape is not None:
            a = a.reshape(*shape)

        return a
