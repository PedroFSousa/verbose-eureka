
""" Functions for managing Docker (swarm) stacks, secrets, images, services, containers and volumes. """

__author__ = "INESC TEC <coral@lists.inesctec.pt>"

import platform, time, os, yaml
from lib.util import fish
from lib.util.logger import log

base_cmd = "docker"
docker_object_types = ["image", "container", "volume", "stack", "service", "secret", "network"]

# Check whether an object type is in the given list of allowed types
def validate_object_type(obj_type, allowed_types):
  if obj_type not in allowed_types:
    raise ValueError(f"Type must be one of: {allowed_types}")

# Initiate Docker Swarm
def init_docker_swarm(advertise_addr=None, suppress_stdout=False):
  cmd = f"{base_cmd} swarm init"

  if advertise_addr is not None:
    if not fish.is_valid("ip", advertise_addr):
      raise ValueError(f"Invalid IP address: '{advertise_addr}'")
    else:
      cmd = add_argument(cmd, "--advertise-addr", advertise_addr)

  return fish.exec_cmd(cmd, suppress_stdout)

# Deploy a Docker swarm stack
def deploy_stack(docker_compose_path, docker_compose_override_path, stack_name):
  cmd = f"{base_cmd} stack deploy"
  cmd = add_argument(cmd, "--with-registry-auth")
  cmd = add_argument(cmd, "--compose-file", docker_compose_path)
  if docker_compose_override_path is not None:
    cmd = add_argument(cmd, "--compose-file", docker_compose_override_path)
  cmd = add_argument(cmd, stack_name)

  res = fish.exec_cmd_live(cmd)
  fish.handle(res)

# Add an argument to a command
def add_argument(cmd, arg, value=None, quote_value=False, use_eq_sign=False):
  if use_eq_sign and value is None:
    raise ValueError(f"Cannot use '=' without specifying a value for argument: {arg}")

  arg_str = arg
  if value is not None:
    arg_str += "=" if use_eq_sign else " "
    arg_str += "'" + value + "'" if quote_value else value

  return f"{cmd} {arg_str}"

# Get Docker information using the "docker info" command
def info(format=None, debug=False, suppress_stdout=True):
  cmd = f"{base_cmd} {'info'}"

  if debug: cmd = add_argument(cmd, "-D")
  if format is not None: cmd = add_argument(cmd, "--format", format, use_eq_sign=True)

  return fish.exec_cmd(cmd, suppress_stdout)

# List Docker objects
def ls(obj_type, all=False, quiet=False, format=None, filters=[], suppress_stdout=False):
  validate_object_type(obj_type, docker_object_types + ["node"])

  if all and obj_type in ["volume", "service", "secret"]:
    all = False
    log.info(f"Ignoring '-a' option (not supported for {obj_type}s)")
  if len(filters) > 0 and obj_type == "stack":
    filters = []
    log.info(f"Ignoring '--filter' option (not supported for {obj_type}s)")

  cmd = f"{base_cmd} {obj_type} ls"

  # set ls command options
  if all: cmd = add_argument(cmd, "-a")
  if quiet: cmd = add_argument(cmd, "-q")
  if format is not None: cmd = add_argument(cmd, "--format", format, use_eq_sign=True)
  if len(filters) > 0:
    for filter in filters:
      cmd = add_argument(cmd, "--filter", filter)
  
  return fish.exec_cmd(cmd, suppress_stdout)

# Scale Docker services
def scale(services, n_replicas, detach=False, suppress_stdout=False, suppress_stderr=False, timeout=None):
  cmd = f"{base_cmd} service scale"
  if detach: cmd = add_argument(cmd, "-d")
  if type(services) is list:
    services = map(lambda service: f"{service}={n_replicas}", services)
    services = ' '.join(services)
  else:
    services = f"{services}={n_replicas}"
  cmd += f" {services}"

  return fish.exec_cmd_live(cmd, (not suppress_stdout), (not suppress_stderr), filter_stdout=True, overlay_keyword="seconds", timeout=timeout)

# Remove Docker objects
def rm(obj_type, objs, force=False, suppress_stdout=False):
  validate_object_type(obj_type, docker_object_types)

  if force and obj_type in ["stack", "service", "secret"]:
    force = False
    log.info(f"Ignoring '--force' option (not supported for {obj_type}s)")

  cmd = f"{base_cmd} {obj_type} rm"
  if force: cmd = add_argument(cmd, "-f")
  if type(objs) is list: objs = ' '.join(objs)
  cmd += f" {objs}"

  return fish.exec_cmd(cmd, suppress_stdout)

# Inspect a Docker object
def inspect(obj_type, obj_name_or_id, format= None, pretty=False, size=False, validate_obj_type=True, suppress_stdout=False):
  if validate_obj_type: validate_object_type(obj_type, list(filter(lambda x: x != "stack", docker_object_types)))

  if pretty and obj_type not in ["service", "secret"]:
    pretty = False
    log.info(f"Ignoring '--pretty' option (not supported for {obj_type}s)")
  elif pretty and format is not None:
    pretty = False
    log.info("Ignoring '--pretty' option (not compatible with --format)")
  if size and obj_type != "container":
    size = False
    log.info(f"Ignoring '-s' option (not supported for {obj_type}s)")

  cmd = f"{base_cmd} {obj_type} inspect"
  if size: cmd = add_argument(cmd, "-s")
  if pretty: cmd = add_argument(cmd, "--pretty")
  if format is not None: cmd = add_argument(cmd, "--format", format, use_eq_sign=True)

  cmd = add_argument(cmd, obj_name_or_id)

  return fish.exec_cmd(cmd, suppress_stdout)

# Check if an object exists by trying to inspect it
def obj_exists(obj_type, obj_id):
  res = inspect(obj_type, obj_id, suppress_stdout=True)
  return res["exit_code"] != 1

# Pull images from docker-compose file
def pull_images_from_compose(docker_compose_path, suppress_stdout=False):
  cmd = f"{base_cmd}-compose --log-level ERROR -f {docker_compose_path} pull"
  # need to print stderr because 'docker-compose pull' always prints to stderr
  return fish.exec_cmd_live(cmd, print_stderr=(not suppress_stdout))

# Get a list of services/secrets/volumes/images from a docker-compose file
def get_objs_from_compose(obj_type, docker_compose_path):
  validate_object_type(obj_type, list(filter(lambda x: x != "stack" and x != "container", docker_object_types)))

  compose = fish.load_yaml(docker_compose_path)

  if obj_type == "image":
    # services = list(compose["services"].keys())
    return list(map(lambda x : compose["services"][x]["image"], compose["services"].keys()))
  else:
    return list(compose[f"{obj_type}s"].keys())

# Get the number of replicas of a service
def get_service_replicas(srv_name):
  return inspect("service", srv_name, format="{{.Spec.Mode.Replicated.Replicas}}", suppress_stdout=True)

# Get task ID from service
def get_task_id_from_service(service_name):
  cmd = f"{base_cmd} service ps"
  cmd = add_argument(cmd, "--filter", "desired-state=running")
  cmd = add_argument(cmd, "-q")
  cmd = add_argument(cmd, service_name)

  res = fish.handle(fish.exec_cmd(cmd, suppress_stdout=True))
  task_id = res["stdout"]
  if task_id == "":
    raise Exception(f"No tasks found for service {service_name}")
  if task_id.count("\n") > 0:
    raise Exception(f"Found multiple running tasks for service {service_name}")
  
  return task_id

# Get container ID from service task
def get_container_id_from_task(task_id):
  res = fish.handle(inspect("", task_id, format="{{.Status.ContainerStatus.ContainerID}}", validate_obj_type=False, suppress_stdout=True))
  container_id = res["stdout"]
  if container_id == "":
    raise Exception(f"No containers found for task {task_id}")

  return container_id

# Get the IPv4 address of the container's interface that is assigned to the given network
def get_container_addr_in_network(container_id, network_name):
  res = fish.handle(inspect("network", network_name, format="\"{{(index .Containers \\\"" + container_id + "\\\").IPv4Address}}\"", suppress_stdout=True))
  addr = res["stdout"]
  if addr == "":
    raise Exception(f"Container {container_id} not found in network {network_name}")

  return addr.split("/")[0]

# Get the Docker data root
def get_data_root():
  res = info("{{.DockerRootDir}}")
  fish.handle(res)
  return res["stdout"]

# Check if user namespaces are enabled
def userns_enabled():
  res = info("{{.SecurityOptions}}")
  fish.handle(res)
  return "userns" in res["stdout"]

# Get userns id
def get_userns_id():
  if not userns_enabled():
    raise Exception(f"Cannot get userns ID: user namespaces are not enabled in Docker")

  data_root_basename = os.path.basename(get_data_root())
  userns_id = data_root_basename.split(".")[0]
  return int(userns_id)

# Get Swarm state
def get_swarm_state():
  res = info("{{.Swarm.LocalNodeState}}")
  fish.handle(res)

  return res["stdout"]

# Check if Swarm mode is active
def swarm_is_active():
  state = get_swarm_state()
  state = state.replace("'", "") # for windows
  return True if state == "active" else False

# Create a Docker secret
def create_secret(secret_content, secret_name, label=None):
  fish.write_file(secret_content, "secret.tmp")

  cmd = f"{base_cmd} secret create"
  if label is not None: cmd = add_argument(cmd, "--label", label)
  cmd = add_argument(cmd, secret_name)
  cmd = add_argument(cmd, "secret.tmp")

  res = fish.exec_cmd(cmd)
  fish.handle(res)
  os.remove("secret.tmp")

# Log int a Docker registry
def login(registry, username=None, password=None, password_stdin=False, suppress_stdout=False, raise_exception=True):
  cmd = f"{base_cmd} {'login'}"

  if username is not None: cmd = add_argument(cmd, "-u", username)
  if password is not None: cmd = add_argument(cmd, "-p", password)
  if password_stdin: cmd = add_argument(cmd, "--password-stdin")
  cmd = add_argument(cmd, registry)
  
  return fish.exec_cmd_status(cmd, raise_exception)
