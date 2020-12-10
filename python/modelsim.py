import contextlib
import enum
import os
import os.path
import re
import subprocess
import tempfile

from collections import namedtuple
from subprocess import Popen, check_output, STDOUT, DEVNULL


__version__ = (0, 1, 1, 'dev')


# the heart of the instrumentation: use blocking FIFO pipes to run TCL commands
SIMULATION_SCRIPT = r'''
set fifo_posi [open "__py_modelsim_posi.fifo" "r"]
set fifo_piso [open "__py_modelsim_piso.fifo" "w"]

puts $fifo_piso "ready"
flush $fifo_piso

gets $fifo_posi command

while {$command != "quit"} {
    if {[catch {
        set result [eval $command]
        puts $fifo_piso "S:$result"
        flush $fifo_piso
    } error ]} {
        puts $fifo_piso [string map {"\n" " "} "E:$error"]
        flush $fifo_piso
    }

    gets $fifo_posi command
}

quit -f
'''


RelativeTime = namedtuple('RelativeTime', ['value', 'unit'])
AbsoluteTime = namedtuple('AbsoluteTime', ['value', 'unit'])


def encode_time(timespec):
    if isinstance(timespec, int):
        return '{{{} ns}}'.format(timespec)
    elif isinstance(timespec, RelativeTime):
        return '{{{} {}}}'.format(timespec.value, timespec.unit)
    elif isinstance(timespec, AbsoluteTime):
        return '{{@{} {}}}'.format(timespec.value, timespec.unit)
    raise Exception('unknown time specification format')


def tcl_escape(value):
    return '{{{}}}'.format(str(value))


class Library:
    """
    ModelSim Verilog library with context manager support.

    If the directory argument is omitted a temporary directory is created on entering the
    context. Further the library is initialized and all Verilog files are compiled. When
    leaving the context, all temporary resources are freed.
    """

    def __init__(self, name, *files, directory=None):
        self.name = name
        self.directory = directory
        self.files = list(files)
        self.temporary = None

    def __enter__(self):
        if self.directory is None:
            self.temporary = tempfile.TemporaryDirectory()
            self.directory = self.temporary.name
            self.initialize()
            self.compile()
        return self

    def __exit__(self, exc_type, exc_value, exc_traceback):
        if self.temporary is not None:
            self.temporary.cleanup()
            self.directory = None
            self.temporary = None

    def initialize(self, *arguments):
        """
        Initialize the library using the `vlib` command.
        """
        if self.directory is None:
            raise Exception('unable to explicitly initialize temporary library')
        command = ['vlib', self.name] + list(arguments)
        try:
            check_output(command,  cwd=str(self.directory), stderr=STDOUT)
        except subprocess.CalledProcessError as error:
            raise Exception('unable to initialize verilog library', error.output)

    def compile(self, *arguments):
        """
        Compile the Verilog files using the `vlog` command.
        """
        if self.directory is None:
            raise Exception('unable to explicitly compile temporary library')
        command = ['vcom', '-2008', '-work', self.name] + list(arguments)
        command += (str(filename) for filename in self.files)
        try:
            check_output(command, cwd=str(self.directory), stderr=STDOUT)
        except subprocess.CalledProcessError as error:
            raise Exception('unable to compile verilog files', error.output)

    def simulate(self, toplevel, *arguments, commandline=True, **keywords):
        """
        Start the simulator with the given toplevel entity using the `vsim` command.
        """
        if self.directory is None:
            raise Exception('unable to simulate outside of the library context')
        command = ['vsim'] + list(arguments)
        if commandline:
            command.append('-c')
        command.append('{}.{}'.format(self.name, toplevel))
        return Popen(command, cwd=str(self.directory), **keywords)


class Object:
    """
    Represents a Verilog object within the simulation. Verilog objects support slicing for
    arrays and member access for structs using native Python syntax.
    """

    def __init__(self, path, simulator):
        self.path = path
        self.simulator = simulator

    def __repr__(self):
        return '<Object "{}">'.format(self.path)

    def __truediv__(self, segment):
        return Object('{}/{}'.format(self.path, segment), self.simulator)

    def __getitem__(self, item):
        if isinstance(item, int):
            return self.simulator.examine(self.path + '({})'.format(item))
        elif isinstance(item, slice):
            if not isinstance(item.start, int) or not isinstance(item.stop, int):
                raise Exception('unsupported slice types on verilog object')
            if item.step is not None:
                raise Exception('slice steps are not supported on verilog objects')
            path = self.path + '({}:{})'.format(item.start, item.stop)
            return self.simulator.examine(path)
        else:
            raise Exception('unsupported key access on verilog object')

    def __setitem__(self, item, value):
        if isinstance(item, int):
            self.simulator.change(self.path + '({})'.format(item), value)
        elif isinstance(item, slice):
            if not isinstance(item.start, int) or not isinstance(item.stop, int):
                raise Exception('unsupported slice types on verilog object')
            if item.step is not None:
                raise Exception('slice steps are not supported on verilog objects')
            for offset, number in enumerate(value):
                self[item.start + offset] = number
        else:
            raise Exception('unsupported key access on verilog object')

    def __getattr__(self, name):
        return Object(self.path + '.' + name, self.simulator)

    @property
    def value(self):
        """
        The value of the object as returned by the `examine` TCL command.
        """
        return self.simulator.examine(self.path)

    def force(self, *arguments, **keywords):
        """
        Force the value of a Verilog net by the `force` TCL command.
        """
        return self.simulator.force(self.path, *arguments, **keywords)

    def change(self, *arguments, **keywords):
        """
        Change the value of a parameter, variable or register by the `change` TCL command.
        """
        return self.simulator.change(self.path, *arguments, **keywords)

    def nets(self):
        """
        Find Verilog nets starting from the objects's path using the `find` command.
        """
        return self.simulator.nets(self.path)

    def signals(self):
        """
        Find Verilog signals starting from the objects's path using the `find` command.
        """
        return self.simulator.signals(self.path)

    def instances(self):
        """
        Find Verilog instances starting from the objects's path using the `find` command.
        """
        return self.simulator.instances(self.path)


class TCLError(Exception):
    """
    Error during the execution of a TCL command.
    """

    def __init__(self, command, message):
        super().__init__(message)
        self.command = command


# regular expression for the `examine` command result parser
EXAMINE_REGEX = re.compile(r'(?P<begin>{)|(?P<end>})|(?P<value>[0-9A-Fa-fx]+)')


def parse_examine_result(string, base=2):
    """
    Parse the result of an examine command into either a value or a list of values. Values
    typically are integers, however they might `None` if the value is undefined.
    """
    if not string.find('...') < 0:
        raise Exception('examine command returned incomplete result')
    stack = []
    print(string)
    for match in EXAMINE_REGEX.finditer(string):
        if match.lastgroup == 'value':
            string = str(match.group('value'))
            value = int(string, base) if string.find('x') < 0 else None
            if stack:
                stack[-1].append(value)
            else:
                return value
        elif match.lastgroup == 'begin':
            stack.append([])
        elif match.lastgroup == 'end':
            head = stack.pop()
            if stack:
                stack[-1].append(head)
            else:
                return head
    # raise Exception('unable to parse result of examine command')


# regular expression for the `find instances` command result parser
INSTANCES_REGEX = re.compile(r'{(?P<path>[^ ]+) \((?P<type>[^)]+)\)}')


def parse_find_instances_result(string, simulator):
    """
    Parse the result of an `find instances`.
    """
    result = {}
    for match in INSTANCES_REGEX.finditer(string):
        if match.group('type') not in result:
            result[match.group('type')] = []
        result[match.group('type')].append(Object(match.group('path'), simulator))
    return result


class ForceModes(enum.Enum):
    """
    Modes for the `force` command as described in the ModelSim documentation.
    """
    FREEZE = '-freeze'
    DRIVE = '-drive'
    DEPOSIT = '-deposit'


class Simulator:
    """
    Python interface to an instrumented ModelSim instance.
    """
    def __init__(self, library, toplevel, libraries=None):
        self.library = library
        self.toplevel = toplevel
        self.libraries = libraries or []
        self.directory = None
        self.running = False
        self.process = None
        self.posi = None
        self.piso = None
        self.time = None
        # cache for examine results: speedup multiple accesses
        self.examine_cache = {}

    def __getitem__(self, path):
        return Object(path, self)

    def __truediv__(self, segment):
        return Object('/{}/{}'.format(self.toplevel, segment), self)

    def start(self, *arguments, stdout=DEVNULL, stderr=DEVNULL):
        """
        Start an instrumented ModelSim instance simulating the toplevel entity.
        """
        if self.running:
            raise Exception('unable to start simulator: already running')

        self.running = True
        self.time = 0

        self.directory = self.library.directory

        posi_name = os.path.join(str(self.directory), '__py_modelsim_posi.fifo')
        piso_name = os.path.join(str(self.directory), '__py_modelsim_piso.fifo')
        script_name = os.path.join(str(self.directory), '__py_modelsim_script.do')

        os.mkfifo(posi_name)
        os.mkfifo(piso_name)

        with open(script_name, 'wb') as script:
            script.write(SIMULATION_SCRIPT.encode())

        arguments = ['-do', '__py_modelsim_script.do'] + list(arguments)
        for library in self.libraries:
            arguments.append('-Lf')
            arguments.append(library)

        self.process = self.library.simulate(self.toplevel, *arguments,
                                             stdout=stdout, stderr=stderr)

        self.posi = open(str(posi_name), 'wb', 0)
        self.piso = open(str(piso_name), 'rb')

        self.examine_cache = {}

        if self.piso.readline().decode().strip() != 'ready':
            self.process.kill()
            self.cleanup()
            raise Exception('unable to start simulator: internal communication error')

    def object(self, path):
        """
        Return an object for the given path.
        """
        return Object(path, self)

    def execute(self, command):
        """
        Execute the given TCL command by sending it to the simulator. Returns the result
        or raises a `TCLError` if the command failed.
        """
        if not self.running or self.process.returncode is not None:
            raise Exception('unable to execute command: simulator not running')
        self.posi.write((command + '\n').encode())
        code, data = self.piso.readline().decode().partition(':')[::2]
        if code == 'S':
            return data.strip()
        else:
            raise TCLError(command, data)

    def examine(self, path, cache=True):
        """
        Issue an examine command for the given path. Since we do not log any signals per
        default, time-travel is not supported.
        """
        if cache and path in self.examine_cache:
            return self.examine_cache[path]
        else:
            command = 'examine {}'.format(tcl_escape(path))
            result = parse_examine_result(self.execute(command))
            if cache:
                self.examine_cache[path] = result
            return result

    def change(self, path, value):
        """
        Change the value of Verilog parameters, registers, memories, and variables. This
        allows us for instance to change memory content and thereby simulate MMIO.
        """
        if isinstance(value, int):
            value = bin(value)[2:]
        elif isinstance(value, list):
            value = tcl_escape(' '.join(bin(item)[2:] for item in value))
        return self.execute('change {} {}'.format(tcl_escape(path), value))

    def force(self, path, value, *arguments, mode=None, cancel=None, repeat=None):
        """
        Force a Verilog net to a specified value. This allows us to control for instance
        the clock signal or stimulate external interrupts.
        """
        command = ['force']
        if mode is not None:
            command.append(mode.value)
        if cancel is not None:
            command.append('-cancel {}'.format(encode_time(cancel)))
        if repeat is not None:
            command.append('-repeat {}'.format(encode_time(repeat)))
        if isinstance(value, int):
            value = bin(value)[2:]
        command.append(tcl_escape(path))
        command.append(value)
        command += arguments
        return self.execute(' '.join(command))

    def noforce(self, *paths):
        """
        Removes the effect of any active force commands on the given objects.
        """
        self.examine('noforce {}'.format(' '.join(map(tcl_escape, paths))))

    def run(self, time):
        """
        Run the simulation for `time` nanoseconds.
        """
        self.examine_cache = {}
        self.time += time
        self.execute('run {}ns'.format(time))

    def cleanup(self):
        """
        Remove FIFO pipes and the TCL script.
        """
        os.unlink(os.path.join(self.directory, '__py_modelsim_posi.fifo'))
        os.unlink(os.path.join(self.directory, '__py_modelsim_piso.fifo'))

        os.unlink(os.path.join(self.directory, '__py_modelsim_script.do'))

    def quit(self):
        """
        Quit the simulation and wait until it has terminated, cleanup afterwards.
        """
        try:
            self.posi.write('quit\n'.encode())
            self.process.wait()
        finally:
            self.cleanup()

    def find(self, kind, *arguments):
        """
        Find simulation objects using the `find` TCL command.
        """
        return self.execute('find {} {}'.format(kind, ' '.join(arguments)))

    def nets(self, path=None):
        """
        Find Verilog nets using the `find` TCL command.
        """
        path = (path or '') + '/*'
        nets = self.find('nets', '-internal', tcl_escape(path), '-recursive')
        return list(map(self.object, nets.split()))

    def signals(self, path=None):
        """
        Find Verilog signals using the `find` TCL command.
        """
        path = (path or '') + '/*'
        signals = self.find('signals', '-internal', tcl_escape(path), '-recursive')
        return list(map(self.object, signals.split()))

    def instances(self, path=None):
        """
        Find Verilog instances using the `find` TCL command.
        """
        path = (path or '') + '/*'
        instances = self.find('instances', '-recursive', tcl_escape(path))
        return parse_find_instances_result(instances, self)


@contextlib.contextmanager
def simulate(toplevel, *files, libraries=None):
    """
    Context manager for easy usage of the simulator.
    """
    library = Library('simulation')
    library.files.extend(files)
    with library:
        simulator = Simulator(library, toplevel, libraries)
        simulator.start()
        yield simulator
        simulator.quit()


def interactive(toplevel, *files, namespace=None, libraries=None, **keywords):
    """
    Launch an interactive interpreter to control the simulator.
    """
    from ptpython.repl import embed

    with simulate(toplevel, *files, libraries=libraries) as simulator:
        namespace = namespace or {}
        namespace.update({
            'simulator': simulator,
            'run': simulator.run,
            'execute': simulator.execute,
            'examine': simulator.examine,
            'change': simulator.change,
            'force': simulator.force,
            'noforce': simulator.noforce,
            'nets': simulator.nets,
            'signals': simulator.signals,
            'instances': simulator.instances
        })

        embed(namespace, namespace, **keywords)