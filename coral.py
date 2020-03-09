
""" Deploy and manage the Coral Docker Stack. """

__author__ = "INESC TEC <coral@lists.inesctec.pt>"

########## Python version and privileges check ##########
import sys, os, ctypes, time, glob

MIN_PY_VERSION = (3, 6)

# check Python version
if sys.version_info[:2] < MIN_PY_VERSION:
  raise ValueError("Python version must be >= " + ".".join(str(v) for v in MIN_PY_VERSION))

# check for admin privileges
admin = False
try:
  admin = os.getuid() == 0
except AttributeError:
  admin = ctypes.windll.shell32.IsUserAnAdmin() == 1

if not admin:
  raise PermissionError("Please run Coral with admin privileges")

#########################################################

import signal, argparse, shutil
from lib.util.logger import log, log_file, log_stdout
from lib.util import fish
from lib import deploy, manage, settings

# Cleanup temporary files
def cleanup_tmp_files():
  try:
    for file_ in glob.glob("*.tmp"):
      os.remove(file_)
    shutil.rmtree(settings.get_logs_tmp_folder("coral"), True)
  except OSError: pass

# To execute when SIGINT is caught
def signal_handler(sig, frame):
  msg = "Cancelled by user. Exiting..."
  log_stdout.info("\n" + msg)
  log_file.info(msg)

  sys.exit(0)

# Load a Coral JSON conf file
def load_conf_file(conf_name):
  file_path = settings.get_conf_file_path(conf_name)
  return fish.load_json(file_path)

# Set up argument parser
def config_arg_parser():
  parser_conf = load_conf_file("arg_parser")
  formatter = lambda prog: argparse.HelpFormatter(
    prog,
    max_help_position=parser_conf["help"]["position"],
    width=parser_conf["help"]["width"]
  )
  parser = argparse.ArgumentParser(
    description=parser_conf["description"],
    add_help=parser_conf["help"]["add_help"],
    formatter_class=formatter
  )

  for g in parser_conf["arg_groups"]:
    group = parser.add_argument_group(g["title"])

    for arg in g["args"]:
      flags = list(arg["flags"].values())
      other_args = {}
      if "choices" in arg: other_args["choices"] = arg["choices"]
      if "nargs" in arg: other_args["nargs"] = arg["nargs"]
      if "suppress" in arg and arg["suppress"] == True: arg["description"] = argparse.SUPPRESS

      group.add_argument(*flags, action=arg["action"], help=arg["description"], **other_args)

  return parser

# Return a list of valid arguments for a given argument group
def get_group_args(args, group_name):
  arg_groups = {}

  for group in parser._action_groups:
    group_dict = { a.dest: getattr(args, a.dest, None) for a in group._group_actions }
    arg_groups[group.title] = vars(argparse.Namespace(**group_dict))

  args_dict = arg_groups.get("> " + group_name.upper())
  if args_dict is None:
    raise LookupError("No such argument group: " + group_name)

  return list(args_dict.keys())

# Given an argument group, return a list with the arguments from that group that were used
def get_used_args_from_group(parsed_args, arg_group_name):
  group_args = get_group_args(sys.argv, arg_group_name)
  return list(filter(lambda x: vars(parsed_args)[x], group_args))

# Given an argument group, return the first argument from that group that was used
def get_first_used_arg_from_group(parsed_args, arg_group_name):
  used_args = get_used_args_from_group(parsed_args, arg_group_name)
  first_used_arg = None

  for arg in sys.argv:
    if arg.strip("-") in used_args:
      first_used_arg = arg
      break

  return first_used_arg

# Get required deployment arguments
def get_required_depl_args():
  arg_groups = load_conf_file("arg_parser")["arg_groups"]
  depl_group = list(filter(lambda x: x["name"] == "deployment", arg_groups)).pop()
  required_args = filter(lambda x: "required" in x and x["required"], depl_group["args"])
  return list(map(lambda x: x["flags"]["long"].lstrip("-"), required_args))

# Parse arguments
def parse_args(parser, skip_depl_config=False):
  parsed_args = parser.parse_args()
  help_msg = "Run with the '-h' flag for additional help."

  if len(sys.argv) == 1: # print help when no args are provided
    parser.print_help()
  else:
    try:
      # if the version arg is present, print version and finish
      if parsed_args.version:
        log.info(settings.get("version"))
        return parsed_args

      used_depl_args = get_used_args_from_group(parsed_args, "deployment")
      used_mgmt_args = get_used_args_from_group(parsed_args, "management")

      # do not allow deployment args without using '--deploy'
      if len(used_depl_args) > 0 and "deploy" not in used_depl_args:
        first_offending_arg = get_first_used_arg_from_group(parsed_args, "deployment")
        parser.error("Deployment arguments, such as '{0}', require '--deploy'.".format(first_offending_arg))

      # do not allow management args if '--deploy' is used
      if parsed_args.deploy and len(used_mgmt_args) > 0:
        first_offending_arg = get_first_used_arg_from_group(parsed_args, "management")
        parser.error("Management arguments, such as '{0}', are not allowed when using '--deploy'.".format(first_offending_arg))

      str_central_conf = settings.get("custom_apache")["central_rule"]
      original_custom_file = fish.read_file(settings.get_custom_apache_conf_file_path())

      # check for presence of the central arg
      if parsed_args.deploy and parsed_args.central:
        if str_central_conf not in original_custom_file:
          log.info("Including apache rule for central monitoring in " + settings.get_custom_apache_conf_file_path())
          original_custom_file = original_custom_file + str_central_conf
          fish.write_file(original_custom_file, settings.get_custom_apache_conf_file_path())  
      else:
        original_custom_file = original_custom_file.replace(str_central_conf, "")
        fish.write_file(original_custom_file, settings.get_custom_apache_conf_file_path())  

      if parsed_args.deploy and not skip_depl_config:
        # check for presence of required deployment args and validate them
        required_depl_args = get_required_depl_args()

        missing = list(filter(lambda x: x not in used_depl_args, required_depl_args))

        if len(missing) > 0:
          parser.error("Missing required deployment arguments: --{0}".format(", --".join(missing)))
        else:
          if not fish.is_valid("domain", parsed_args.domain):
            parser.error("Invalid domain: '{0}'".format(parsed_args.domain))
          if not fish.is_valid("email", parsed_args.email):
            parser.error("Invalid email: '{0}'".format(parsed_args.email))

        # make '--letsencrypt' and '--no-port-binding' incompatible
        if parsed_args.letsencrypt and parsed_args.no_port_binding:
          parser.error("Incompatible arguments: '--letsencrypt' and '--no-port-binding'. Cannot issue a Let's Encrypt certificate if port binding to host is disabled.")

        # do not allow dots in the stack name
        if parsed_args.stack_name is not None and "." in parsed_args.stack_name:
          parser.error("The stack name cannot contain dots.")

        # validate advertise and proxy addresses, if present
        if parsed_args.addr and not fish.is_valid("ip", parsed_args.addr):
          parser.error("Invalid IP address: '{0}'".format(parsed_args.addr))
        if parsed_args.http_proxy and not fish.is_valid("address", parsed_args.http_proxy):
          parser.error("Invalid proxy address: '{0}'".format(parsed_args.http_proxy))
        if parsed_args.https_proxy and not fish.is_valid("address", parsed_args.https_proxy):
          parser.error("Invalid proxy address: '{0}'".format(parsed_args.https_proxy))
      else:
        # only allow one management argument at a time
        if len(used_mgmt_args) > 1:
          parser.error("Only one management argument at a time is allowed.")
    except SystemExit as e:
      log_stdout.info("\n{0}".format(help_msg))
      sys.exit(e)

  return parsed_args

def main(parsed_args, skip_depl_conf=False):
  status = None

  if parsed_args.deploy:
    depl_args = {
      "docker_compose_path": settings.get("compose_path"),
      "domain": parsed_args.domain,
      "email": parsed_args.email,
      "cert_type": "letsencrypt" if parsed_args.letsencrypt else "custom",
      "stack_name": settings.get("name") if parsed_args.stack_name is None else parsed_args.stack_name,
      "addr": parsed_args.addr,
      "http_proxy": parsed_args.http_proxy,
      "https_proxy": parsed_args.https_proxy,
      "no_port_binding": parsed_args.no_port_binding,
      "dev": parsed_args.dev,
      "no_prompt": parsed_args.test,
      "central": parsed_args.central 
    }

    deploy.prepare(skip_depl_config=skip_depl_conf, is_update=False, **depl_args)
  elif parsed_args.list:
    manage.list_(parsed_args.list)
  elif parsed_args.remove:
    manage.remove(parsed_args.remove)
  elif parsed_args.logs:
    manage.logs(parsed_args.logs)
  elif parsed_args.update:
    manage.update()
  else:
    if parsed_args.start:
      status = manage.start()
    elif parsed_args.stop:
      status = manage.stop()
    elif parsed_args.restart:
      status = manage.restart()

  if status == 1:
    log.info("No Coral services were found (Coral stack is not currently deployed)")

if __name__ == "__main__":
  try:
    log_stdout.info(settings.get_intro())
    log_file.info("EXEC: [ {0} ]".format(", ".join(sys.argv)))

    signal.signal(signal.SIGINT, signal_handler)

    skip_depl_config = False
    if "--deploy" in sys.argv:
      skip_depl_config = deploy.check_skip_depl_config("--test" in sys.argv)
    parser = config_arg_parser()
    parsed_args = parse_args(parser, skip_depl_config)
    main(parsed_args, skip_depl_config)
  except (Exception, SystemExit) as e:
    e_name = type(e).__name__
    if e_name == "SystemExit":
      if e == 1: log_file.exception(e_name)
    else:
      log.exception("{0}: {1}".format(e_name, e))
    sys.exit(1)
  finally:
    cleanup_tmp_files()
