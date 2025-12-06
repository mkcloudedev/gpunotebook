"""
Magic commands preprocessor for IPython-like functionality.
Supports common magic commands like %pip, %matplotlib, %timeit, etc.
"""
import re
import time
import subprocess
from typing import Tuple, Optional, List


class MagicProcessor:
    """Process magic commands before execution."""

    def __init__(self):
        self._line_magics = {
            '%pip': self._magic_pip,
            '%conda': self._magic_conda,
            '%matplotlib': self._magic_matplotlib,
            '%timeit': self._magic_timeit,
            '%time': self._magic_time,
            '%pwd': self._magic_pwd,
            '%cd': self._magic_cd,
            '%ls': self._magic_ls,
            '%env': self._magic_env,
            '%who': self._magic_who,
            '%whos': self._magic_whos,
            '%reset': self._magic_reset,
            '%clear': self._magic_clear,
            '%history': self._magic_history,
            '%load': self._magic_load,
            '%run': self._magic_run,
            '%store': self._magic_store,
            '%recall': self._magic_recall,
            '%xdel': self._magic_xdel,
        }

        self._cell_magics = {
            '%%timeit': self._cell_magic_timeit,
            '%%time': self._cell_magic_time,
            '%%writefile': self._cell_magic_writefile,
            '%%bash': self._cell_magic_bash,
            '%%html': self._cell_magic_html,
            '%%javascript': self._cell_magic_javascript,
            '%%latex': self._cell_magic_latex,
            '%%markdown': self._cell_magic_markdown,
            '%%capture': self._cell_magic_capture,
        }

    def process(self, code: str) -> Tuple[str, Optional[dict]]:
        """
        Process magic commands in code.
        Returns transformed code and optional pre-execution result.
        """
        lines = code.strip().split('\n')
        if not lines:
            return code, None

        first_line = lines[0].strip()

        # Check for cell magics (%%magic)
        if first_line.startswith('%%'):
            parts = first_line.split(None, 1)
            magic_name = parts[0]
            args = parts[1] if len(parts) > 1 else ''
            rest_of_code = '\n'.join(lines[1:])

            if magic_name in self._cell_magics:
                return self._cell_magics[magic_name](args, rest_of_code)

        # Check for line magics (%magic) - process each line
        transformed_lines = []
        pre_results = []

        for line in lines:
            stripped = line.strip()
            if stripped.startswith('%') and not stripped.startswith('%%'):
                parts = stripped.split(None, 1)
                magic_name = parts[0]
                args = parts[1] if len(parts) > 1 else ''

                if magic_name in self._line_magics:
                    transformed, result = self._line_magics[magic_name](args)
                    if transformed:
                        transformed_lines.append(transformed)
                    if result:
                        pre_results.append(result)
                else:
                    # Unknown magic, pass through
                    transformed_lines.append(line)
            else:
                transformed_lines.append(line)

        final_code = '\n'.join(transformed_lines)

        if pre_results:
            combined_result = {
                'type': 'magic_output',
                'outputs': pre_results
            }
            return final_code, combined_result

        return final_code, None

    # ========================================================================
    # LINE MAGICS
    # ========================================================================

    def _magic_pip(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %pip install/uninstall commands."""
        code = f"""
import subprocess
import sys
result = subprocess.run([sys.executable, '-m', 'pip', {', '.join(repr(a) for a in args.split())}],
                       capture_output=True, text=True)
print(result.stdout)
if result.stderr:
    print(result.stderr)
"""
        return code, None

    def _magic_conda(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %conda commands."""
        code = f"""
import subprocess
result = subprocess.run(['conda'] + {repr(args.split())}, capture_output=True, text=True)
print(result.stdout)
if result.stderr:
    print(result.stderr)
"""
        return code, None

    def _magic_matplotlib(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %matplotlib inline/notebook/widget."""
        backend = args.strip() or 'inline'
        code = f"""
import matplotlib
matplotlib.use('agg')
import matplotlib.pyplot as plt
plt.switch_backend('agg')
get_ipython().run_line_magic('matplotlib', '{backend}')
print('Matplotlib backend set to: {backend}')
"""
        return code, None

    def _magic_timeit(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %timeit statement."""
        if not args:
            return '', {'type': 'error', 'text': '%timeit requires a statement'}

        code = f"""
import timeit
_timeit_result = timeit.timeit({repr(args)}, globals=globals(), number=1000)
print(f"1000 loops: {{_timeit_result:.6f}}s total, {{_timeit_result/1000*1000:.3f}}ms per loop")
"""
        return code, None

    def _magic_time(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %time statement."""
        if not args:
            return '', {'type': 'error', 'text': '%time requires a statement'}

        code = f"""
import time as _time_module
_start = _time_module.perf_counter()
{args}
_end = _time_module.perf_counter()
print(f"CPU times: {{(_end - _start)*1000:.2f}}ms")
"""
        return code, None

    def _magic_pwd(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %pwd - print working directory."""
        code = """
import os
print(os.getcwd())
"""
        return code, None

    def _magic_cd(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %cd path."""
        path = args.strip() or '~'
        code = f"""
import os
os.chdir(os.path.expanduser({repr(path)}))
print(os.getcwd())
"""
        return code, None

    def _magic_ls(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %ls - list directory."""
        path = args.strip() or '.'
        code = f"""
import os
for f in sorted(os.listdir({repr(path)})):
    print(f)
"""
        return code, None

    def _magic_env(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %env - show/set environment variables."""
        if '=' in args:
            # Set variable
            name, value = args.split('=', 1)
            code = f"""
import os
os.environ[{repr(name.strip())}] = {repr(value.strip())}
print(f"{name.strip()}={value.strip()}")
"""
        elif args.strip():
            # Get specific variable
            code = f"""
import os
print(os.environ.get({repr(args.strip())}, 'Not set'))
"""
        else:
            # Show all
            code = """
import os
for k, v in sorted(os.environ.items()):
    print(f"{k}={v}")
"""
        return code, None

    def _magic_who(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %who - list variables."""
        code = """
_who_vars = [name for name in dir() if not name.startswith('_')]
print(' '.join(_who_vars))
"""
        return code, None

    def _magic_whos(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %whos - detailed variable list."""
        code = """
import sys
print(f"{'Variable':<20} {'Type':<15} {'Data/Info':<40}")
print("-" * 75)
for name in sorted(dir()):
    if not name.startswith('_'):
        try:
            obj = eval(name)
            obj_type = type(obj).__name__
            if hasattr(obj, 'shape'):
                info = str(obj.shape)
            elif hasattr(obj, '__len__'):
                info = f"len={len(obj)}"
            else:
                info = str(obj)[:40]
            print(f"{name:<20} {obj_type:<15} {info:<40}")
        except:
            pass
"""
        return code, None

    def _magic_reset(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %reset - reset namespace."""
        code = """
get_ipython().reset()
print("Namespace reset.")
"""
        return code, None

    def _magic_clear(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %clear - clear output."""
        code = """
from IPython.display import clear_output
clear_output()
"""
        return code, None

    def _magic_history(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %history - show history."""
        code = """
for i, line in enumerate(get_ipython().history_manager.get_range()):
    print(f"{line[1]:>4}: {line[2]}")
"""
        return code, None

    def _magic_load(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %load filename - load file contents."""
        if not args.strip():
            return '', {'type': 'error', 'text': '%load requires a filename'}

        code = f"""
with open({repr(args.strip())}, 'r') as f:
    _loaded_code = f.read()
print(_loaded_code)
"""
        return code, None

    def _magic_run(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %run script.py - run a Python script."""
        if not args.strip():
            return '', {'type': 'error', 'text': '%run requires a filename'}

        code = f"""
exec(open({repr(args.strip())}).read())
"""
        return code, None

    def _magic_store(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %store variable - store variable for later."""
        return f"# %store {args} - not implemented in this kernel", None

    def _magic_recall(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %recall - recall history."""
        return f"# %recall {args} - not implemented in this kernel", None

    def _magic_xdel(self, args: str) -> Tuple[str, Optional[dict]]:
        """Handle %xdel variable - delete variable."""
        if not args.strip():
            return '', {'type': 'error', 'text': '%xdel requires a variable name'}

        code = f"""
del {args.strip()}
print("Deleted: {args.strip()}")
"""
        return code, None

    # ========================================================================
    # CELL MAGICS
    # ========================================================================

    def _cell_magic_timeit(self, args: str, code: str) -> Tuple[str, Optional[dict]]:
        """Handle %%timeit - time entire cell."""
        wrapped = f"""
import timeit

def _timeit_cell():
{chr(10).join('    ' + line for line in code.split(chr(10)))}

_result = timeit.timeit(_timeit_cell, number=100)
print(f"100 loops: {{_result:.6f}}s total, {{_result/100*1000:.3f}}ms per loop")
"""
        return wrapped, None

    def _cell_magic_time(self, args: str, code: str) -> Tuple[str, Optional[dict]]:
        """Handle %%time - time entire cell once."""
        wrapped = f"""
import time as _time_module
_start = _time_module.perf_counter()
{code}
_end = _time_module.perf_counter()
print(f"\\nCPU times: {{(_end - _start)*1000:.2f}}ms")
"""
        return wrapped, None

    def _cell_magic_writefile(self, args: str, code: str) -> Tuple[str, Optional[dict]]:
        """Handle %%writefile filename - write cell to file."""
        if not args.strip():
            return '', {'type': 'error', 'text': '%%writefile requires a filename'}

        filename = args.strip()
        wrapped = f"""
with open({repr(filename)}, 'w') as f:
    f.write({repr(code)})
print(f"Writing {{len({repr(code)})}} bytes to {filename}")
"""
        return wrapped, None

    def _cell_magic_bash(self, args: str, code: str) -> Tuple[str, Optional[dict]]:
        """Handle %%bash - run cell as bash script."""
        wrapped = f"""
import subprocess
result = subprocess.run(['bash', '-c', {repr(code)}], capture_output=True, text=True)
print(result.stdout)
if result.stderr:
    print(result.stderr)
"""
        return wrapped, None

    def _cell_magic_html(self, args: str, code: str) -> Tuple[str, Optional[dict]]:
        """Handle %%html - render as HTML."""
        wrapped = f"""
from IPython.display import HTML, display
display(HTML({repr(code)}))
"""
        return wrapped, None

    def _cell_magic_javascript(self, args: str, code: str) -> Tuple[str, Optional[dict]]:
        """Handle %%javascript - run JavaScript."""
        wrapped = f"""
from IPython.display import Javascript, display
display(Javascript({repr(code)}))
"""
        return wrapped, None

    def _cell_magic_latex(self, args: str, code: str) -> Tuple[str, Optional[dict]]:
        """Handle %%latex - render as LaTeX."""
        wrapped = f"""
from IPython.display import Latex, display
display(Latex({repr(code)}))
"""
        return wrapped, None

    def _cell_magic_markdown(self, args: str, code: str) -> Tuple[str, Optional[dict]]:
        """Handle %%markdown - render as Markdown."""
        wrapped = f"""
from IPython.display import Markdown, display
display(Markdown({repr(code)}))
"""
        return wrapped, None

    def _cell_magic_capture(self, args: str, code: str) -> Tuple[str, Optional[dict]]:
        """Handle %%capture - capture output to variable."""
        var_name = args.strip() or 'captured'
        wrapped = f"""
from IPython.utils.capture import capture_output
with capture_output() as {var_name}:
{chr(10).join('    ' + line for line in code.split(chr(10)))}
print(f"Output captured to '{var_name}'")
"""
        return wrapped, None


# Global instance
magic_processor = MagicProcessor()
