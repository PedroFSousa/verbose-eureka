
""" Functions for excuting filesystem and shell commands. """

__author__ = "INESC TEC <coral@lists.inesctec.pt>"

import subprocess, sys, platform, shutil, io, time, stat, errno, re, os, ctypes, json, distutils.dir_util, glob, getpass, zipfile, filecmp, socket, yaml
from lib.util.logger import log, log_file
from distutils.dir_util import copy_tree

######################  SHELL INTERACTION  ######################

# Execute command and return exit code, stdout and stderr
def exec_cmd(cmd, suppress_stdout=False, suppress_stderr=True):
  process = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  stdout = stderr = prev_line_stdout = ""

  while True:
    nextline_stdout = process.stdout.readline()
    nextline_stderr = process.stderr.readline()

    if nextline_stdout == b'' and nextline_stderr == b'' and process.poll() is not None: break

    line_stdout = nextline_stdout.decode('utf-8')
    line_stderr = nextline_stderr.decode('utf-8')
    stdout += line_stdout
    stderr += line_stderr

    if not suppress_stdout and line_stdout != prev_line_stdout and line_stdout != "\n":
      prev_line_stdout = line_stdout
      log.info(line_stdout.rstrip('\n'))
      # sys.stdout.write(line_stdout)
      # sys.stdout.flush()

  exit_code = process.returncode

  return {
    "cmd": cmd,
    "exit_code": exit_code,
    "stdout": stdout.rstrip('\n'),
    "stderr": stderr.rstrip('\n')
  }

# Execute command (printing stdout/stderr as it is generated) and return exit code, stdout and stderr
def exec_cmd_live(cmd, print_stdout=True, print_stderr=False, filter_stdout=False, overlay_keyword=None, timeout=None):
  # use file as pipe to allow for live printing of stdout/stderr
  with io.open("stdout.tmp", 'wb') as stdout_writer,\
    io.open("stderr.tmp", 'wb') as stderr_writer,\
    io.open("stdout.tmp", 'rb', 1) as stdout_reader,\
    io.open("stderr.tmp", 'rb', 1) as stderr_reader:

    prev_stdout = ""

    process = subprocess.Popen(cmd.split(" "), stdout=stdout_writer, stderr=stderr_writer)
    exit_code = None
    time_step = 0.5
    elapsed_time = 0

    while process.poll() is None:
      stdout = stdout_reader.read().decode('utf-8')
      stderr = stderr_reader.read().decode('utf-8')

      # filter out empty or duplicate lines
      if print_stdout and filter_stdout:
        if "\n" in stdout:
          stdout = list(filter(lambda x: x not in ["", "\n"], stdout.split("\n")))

        if stdout and stdout[0] != prev_stdout:
          stdout = stdout[0]
          prev_stdout = stdout

          if overlay_keyword is not None and overlay_keyword in stdout:
            sys.stdout.write(stdout + "\r") # overlay on top of previous line
          else:
            sys.stdout.write(stdout + "\n")

          # log stdout to file (excluding overlayed lines)
          if overlay_keyword not in stdout:
            log_file.info(stdout)
      else:
        if print_stdout: sys.stdout.write(stdout)
        if print_stderr: sys.stdout.write(stderr)

      time.sleep(time_step)
      elapsed_time += time_step

      if timeout and elapsed_time >= timeout:
        exit_code = 124
        break
    else:
      exit_code = process.returncode
      # read any remaining outpout
      if print_stdout: sys.stdout.write(stdout_reader.read().decode('utf-8'))

    result = {
      "cmd": cmd,
      "exit_code": exit_code,
      "stdout": stdout_reader.read().decode('utf-8'),
      "stderr": stderr_reader.read().decode('utf-8')
    }

  for file_ in glob.glob("*.tmp"):
    os.remove(file_)

  return result

# Execute commands whose stdout we do not need to store
def exec_cmd_status(cmd, raise_exception=True):
  try:
    return subprocess.check_call(cmd, shell=True)
  except subprocess.CalledProcessError as e:
    if raise_exception: raise
    return e.returncode

# Handle result exec_cmd and exec_cmd_live (raises exception if exit code is not 0)
def handle(res):
  exit_code = res["exit_code"]

  if exit_code != 0:
    cmd = res["cmd"]
    stderr = f"Timeout on: {cmd}" if exit_code == 124 else res["stderr"].replace("\n", "\\n")

    log.error(stderr.rstrip("\n"))

    raise subprocess.CalledProcessError(exit_code, cmd)

  return res

# Print progress a progress bar
def print_progress_bar(iteration, total, prefix="", suffix="", decimals=1, length=100, fill ="█", end_nl=False):
  percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
  filled_length = int(length * iteration // total)
  bar = fill * filled_length + "-" * (length - filled_length)
  # print(bar)
  print("\r%s |%s| %s%% %s" % (prefix, bar, percent, suffix), end = "\r")
  
  # print \n on complete
  if end_nl and iteration == total: 
    print()

# Prompt for user input
def user_input(input_message, is_pwd=False):
  input_ = ""

  while input_ == "":
    input_ = getpass.getpass(input_message) if is_pwd else (str(input(input_message)))

  return input_

# Prompt user until a valid answer is provided
def valid_answer_from_prompt(question="", valid_answers=[], lower_str=True):
  answer = ""
  valid = False

  while not valid:
    answer = user_input(question)

    if lower_str: answer = answer.lower()

    if len(valid_answers) > 0:
      if answer in valid_answers:
        valid = True
    else:
      valid = True if answer != "" else False

  return answer

# Check if user prompt is an equivalent to "yes"
def user_prompt_yes(answer=""):
  return True if answer == "yes" or answer == "y" else False

# Check if user prompt is an equivalent to "no"
def user_prompt_no(answer=""):
  return True if answer == "no" or answer == "n" else False

######################  FILE SYSTEM INTERACTION   ######################

# Load a JSON file from the given path into a dict
def load_json(file_path):
  with open(file_path, "r") as f:
    return json.load(f)

# Write the given string data into a JSON file
def write_json(data, file_path, indent):
  with open(file_path, 'w') as f:
    json.dump(data, f, **{"indent": indent})

# Load a YAML file from the given path into a dict
def load_yaml(file_path):
  with open(file_path, "r") as f:
    return yaml.load(f, Loader=yaml.Loader)

# Write the given string data into a YAML file
def write_yaml(data, file_path):
  with open(file_path, 'w') as f:
    yaml.dump(data, f)

# Load a file file from the given path into a string
def read_file(file_path):
  with open(file_path, "r") as f:
    return f.read()

# Write the given string data into a file
def write_file(data, file_path):
  with open(file_path, "w", newline="\n") as f:
    return f.write(data)

# Check if path exists or not. It can be a directory or a file. Wildcards supported.
def check_if_path_exists(path):
  return True if glob.glob(path) else False

# Copy folder content, ignoring when the source folder does not exist.
def copy_folder(source: str, destination: str):
  if os.path.isdir(source): 
    copy_tree(source, destination)

# Write in a given file the output of a command
def write_cmd_output(f, stdout_log, header: str = None):
  if header is not None: f.write(f"\n\n########## {header} ##########\n")
  f.write(f"\nstdout:\n\n")
  f.write(stdout_log["stdout"])
  f.write(f"\n\nstderr:\n\n")
  f.write(stdout_log["stderr"])

############################  MISC  ############################

# Check admin privileges
def is_admin():
  admin = False

  try:
    admin = os.getuid() == 0
  except AttributeError:
    admin = ctypes.windll.shell32.IsUserAnAdmin() == 1

  return admin


def get_env_var_value(file_path, var_name):
  f = open( file_path )
  file_content = f.readlines()

  regex = re.compile(r"^(" + var_name + "=).*$")
  
  for index, item in enumerate(file_content):
    result = regex.search(item)

    if (result != None):
      f.close()
      return {"index": index, "value": item.split("=")[1].strip()}  

  f.close()
  return None


# In the given file, replace text matching a regex pattern with a given string
def replace_regex(file_path, regex, new, multiline=False):
  if multiline: regex = re.compile(regex, re.MULTILINE)
  file_str = read_file(file_path)
  file_str = re.sub(regex, new, file_str)
  write_file(file_str, file_path)

validation_regex = {
  "domain": r"(([a-zA-Z]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])",
  "ip": r"(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])",
  "email": r"(^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$)"
}
validation_regex["address"] = r"(?:http)s?://(" + validation_regex["domain"] + r"|" + validation_regex["ip"] + r")(?::\d+)?" + r"(?:/?|[/?]\S+)"

# Validate strings based on given type and regex patterns
def is_valid(type_, value):
  valid_types = list(validation_regex.keys())
  if type_ in valid_types:
    regex = re.compile(r"^" + validation_regex[type_] + r"$", re.IGNORECASE)
  else:
    raise KeyError(f"Unknown type for regex validation: '{type_}'. Must be one of: {', '.join(valid_types)}")

  return re.match(regex, value) is not None
