"""
ShellRunner - 封装执行 .sh / bash 脚本（如 vpn.sh、ip-check.sh）
场景：
    1. 本地执行 shell 脚本
    2. 返回 stdout / stderr / exit code
    3. 支持超时（默认 10 分钟）
    4. 实时按行回调（后续可接 WebSocket 推送日志到前端）
    5. 可扩展到远程 SSH 执行 (paramiko) - 预留 run_remote

用法示例:
    from core.shell_runner import run_script, ShellResult
    result: ShellResult = run_script("/etc/s-box/vpn.sh", timeout=600)
    print(result.stdout, result.exit_code)
"""
from __future__ import annotations
import subprocess
import threading
from dataclasses import dataclass, field
from typing import List, Callable, Optional
import shlex


@dataclass
class ShellResult:
    command: str
    stdout: str = ""
    stderr: str = ""
    exit_code: int = -1
    timeout: bool = False
    duration_ms: int = 0
    log_lines: List[str] = field(default_factory=list)


def _stream_reader(pipe, sink_list: List[str], callback: Optional[Callable[[str], None]]):
    try:
        for line in iter(pipe.readline, ""):
            if not line:
                break
            line = line.rstrip("\n")
            sink_list.append(line)
            if callback:
                try:
                    callback(line)
                except Exception:
                    pass
    finally:
        pipe.close()


def run_script(
    script_path: str,
    args: Optional[List[str]] = None,
    timeout: int = 600,
    cwd: Optional[str] = None,
    env=None,
    shell: bool = False,
    on_stdout: Optional[Callable[[str], None]] = None,
    on_stderr: Optional[Callable[[str], None]] = None,
    log_command: bool = True,
) -> ShellResult:
    args = args or []
    if shell:
        cmd = " ".join([script_path] + [shlex.quote(a) for a in args])
    else:
        cmd_parts = [script_path] + args
        cmd = shlex.join(cmd_parts)

    import time

    start = time.time()
    out_lines: List[str] = []
    err_lines: List[str] = []
    result = ShellResult(command=cmd)

    try:
        proc = subprocess.Popen(
            cmd if shell else cmd_parts,
            shell=shell,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            cwd=cwd,
            env=env,
        )
        t_out = threading.Thread(target=_stream_reader, args=(proc.stdout, out_lines, on_stdout), daemon=True)
        t_err = threading.Thread(target=_stream_reader, args=(proc.stderr, err_lines, on_stderr), daemon=True)
        t_out.start()
        t_err.start()

        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.kill()
            result.timeout = True
            err_lines.append(f"[shell-runner] 脚本执行超过 {timeout}s 已强制终止")
        finally:
            t_out.join(timeout=3)
            t_err.join(timeout=3)

        result.exit_code = proc.returncode if proc.returncode is not None else -9
    except FileNotFoundError:
        err_lines.append(f"[shell-runner] 脚本或可执行文件不存在: {script_path}")
        result.exit_code = 127
    except OSError as e:
        err_lines.append(f"[shell-runner] 系统错误: {e}")
        result.exit_code = 126

    result.stdout = "\n".join(out_lines)
    result.stderr = "\n".join(err_lines)
    result.log_lines = out_lines + (["--STDERR--"] if err_lines else []) + err_lines
    result.duration_ms = int((time.time() - start) * 1000)
    return result


def run_bash_inline(
    bash_code: str, timeout: int = 60, cwd=None, env=None,
    on_stdout=None, on_stderr=None,
) -> ShellResult:
    """执行一段内联 bash 代码（字符串）"""
    return run_script(
        "bash",
        args=["-lc", bash_code],
        timeout=timeout,
        cwd=cwd,
        env=env,
        shell=False,
        on_stdout=on_stdout,
        on_stderr=on_stderr,
    )
