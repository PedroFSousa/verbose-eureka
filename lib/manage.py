
""" Manage the Coral Docker stack. """

__author__ = "INESC TEC <coral@lists.inesctec.pt>"

import sys, argparse, shutil, os, time, pathlib
from lib.util.logger import log, log_file, log_stdout
from lib.util import swarmadmin, fish
from lib import settings, deploy
from shutil import copyfile
from datetime import datetime

# Get Coral Docker objects of a given type
def get_coral_objs(obj_type: str, all_: bool = False, quiet: bool = False, format_: str = None, filters: list = ["label=system=Coral"]):
  if obj_type == "stack": filters=[]
  res = swarmadmin.ls(obj_type, all=all_, quiet=quiet, format=format_, filters=filters, suppress_stdout=True)
  fish.handle(res)

  return res["stdout"]

# List of Coral Docker objects of a given type
def list_(obj_type: str):
  log.info(f"Listing Coral {obj_type}:")
  objs_found = get_coral_objs(obj_type.rstrip("s"))

  if objs_found.count("\n") == 0:
    log.info(f"No Coral {obj_type} found.")
  else:
    log.info("\n{0}\n".format(objs_found))

# Remove Coral objects that depend on the given object type
def remove_coral_obj_dependencies(obj_type: str, silent: bool = False):
  if obj_type == "container":
    # must remove services first, or else containers will be automatically recreated
    if not silent: log.info("Must remove dependent services first")
    remove_coral_objects("service", silent=silent, list_found_objs=False, prompt=False, is_dep=True)

  if obj_type in ["image", "volume", "secret"]:
    # must remove associated containers first
    if not silent: log.info("Must remove dependent containers first")
    remove_coral_objects("container", silent=silent, list_found_objs=False, prompt=False, is_dep=True)

# Remove Coral objects of a given type
def remove_coral_objects(obj_type: str, silent: bool = False, list_found_objs:bool = True, prompt: bool = True, is_dep: bool = False):
  if not silent: log.info(f"Removing{' dependent ' if is_dep else ' '}Coral {obj_type}s...")

  cleanup_params = settings.get("cleanup_params")[obj_type]
  rm_confirmation_msg, all_, quiet, format_, filters, force = [ value for value in cleanup_params.values() ]

  obj_list = get_coral_objs(obj_type, all_=all_, quiet=quiet, format_=f"\"{format_}\"", filters=filters)

  if obj_list:
    bullets_obj_list = "\n".join([f"- {line}" for line in obj_list.split("\n")])

    if list_found_objs and not silent:
      log.info(f"The following Coral {obj_type}s were found:\n{bullets_obj_list}")
      log_stdout.info("")

    if prompt:
      question = f"{rm_confirmation_msg}\nAre you sure you want to remove these {obj_type}s? (y/n) "
      answer = fish.valid_answer_from_prompt(question, valid_answers=settings.get("prompt_boolean_answers"))
      log_file.info(question.replace("\n", " ") + answer)

    if not prompt or fish.user_prompt_yes(answer):
      remove_coral_obj_dependencies(obj_type, silent=silent)

      obj_ids = [i for i,j in (obj.split("\t") for obj in obj_list.split("\n"))]
      if not silent: log.info(f"Removing {obj_type}s...")
      res = swarmadmin.rm(obj_type, obj_ids, force=force, suppress_stdout=silent)
      fish.handle(res)
      if not silent: log.info(f"Done!")
  else:
    if not silent: log.info(f"No Coral {obj_type}s were found. Skipping...")
    # log_stdout.info("")


# Get Coral logs of the types in a given list
def logs(obj_types: list, is_all: bool = False, zip_name: str = ""):
  obj_types = list(set(obj_types))
  
  if not is_all:
    shutil.rmtree(settings.get_logs_tmp_folder("coral"), True)
    pathlib.Path(settings.get_logs_tmp_folder("coral")).mkdir(parents=True, exist_ok=True)
    log.info(f"Getting coral.log...")
    shutil.copyfile(settings.get_log_file_path("coral"), settings.get_log_tmp_file_path())
    log.info(f"Getting docker.log...")
    save_mixed_docker_command_logs(settings.get_logs_tmp_folder("docker"))

  if "all" in obj_types:
    zip_name = datetime.today().strftime("%Y%m%d") + "_" + time.strftime('%H%M%S', time.gmtime()) + "_all_logs"
    logs(["agate", "opal", "mica", "drupal", "apache"], True, zip_name)
  else:
    if "agate" in obj_types:
      get_coral_logs("agate")
      if not is_all: zip_name += "_agate"
    if "opal" in obj_types:
      get_coral_logs("opal")
      if not is_all: zip_name += "_opal"
    if "mica" in obj_types:
      get_coral_logs("mica")
      if not is_all: zip_name += "_mica"
    if "drupal" in obj_types:
      get_coral_logs("drupal")
      if not is_all: zip_name += "_drupal"
    if "apache" in obj_types:
      get_coral_logs("apache")
      if not is_all: zip_name += "_apache"
    if not is_all:
      zip_name = datetime.today().strftime("%Y%m%d") + "_" + time.strftime('%H%M%S', time.gmtime()) + zip_name + "_logs"

    file_name = shutil.make_archive(f"./logs/{zip_name}", "zip", settings.get_logs_tmp_folder("coral"))
    log.info(f"A zip file containing the requested services logs was saved in {file_name}")
    shutil.rmtree(settings.get_logs_tmp_folder("coral"), True)

# Get Coral log of a given type
def get_coral_logs(obj_type: str):
  log.info(f"Getting {obj_type} logs...")

  volumes_dir = os.path.join( swarmadmin.get_data_root(), "volumes")
  stack_name = get_stack_name()
  if stack_name == None:
    raise Exception("Unable to retrieve logs, No Coral deployment configuration found.")

  if obj_type in {"agate", "mica"}:
    fish.copy_folder(os.path.join(volumes_dir, f"{stack_name}_{obj_type}", "_data", "logs"), settings.get_logs_tmp_folder(obj_type))
    save_docker_service_log(f"{stack_name}_mongo", settings.get_logs_tmp_folder("mongodb"))
  elif obj_type == "apache":
    fish.copy_folder(os.path.join(volumes_dir, f"{stack_name}_{obj_type}-logs", "_data"), settings.get_logs_tmp_folder(obj_type))
  elif obj_type ==  "opal":
    fish.copy_folder(os.path.join(volumes_dir, f"{stack_name}_{obj_type}", "_data", "logs"), settings.get_logs_tmp_folder(obj_type))
    fish.copy_folder(os.path.join(volumes_dir, f"{stack_name}_rserver", "_data", "logs"), settings.get_logs_tmp_folder("rserver"))
    save_docker_service_log(f"{stack_name}_{obj_type}-data", settings.get_logs_tmp_folder("opal-data"))
    save_docker_service_log(f"{stack_name}_{obj_type}-ids", settings.get_logs_tmp_folder("opal-ids"))
  elif obj_type == "drupal":
    save_docker_service_log(f"{stack_name}_mica-{obj_type}", settings.get_logs_tmp_folder(obj_type)) 
    save_docker_service_log(f"{stack_name}_mica-{obj_type}-data", settings.get_logs_tmp_folder("mica-drupal-data")) 

# Get stack name from conf/deploymnet.json
def get_stack_name():
  try:
    resp_dict = fish.load_json( settings.get_conf_file_path("deployment") )
    return resp_dict["basic"]["stack_name"]
  except FileNotFoundError:
    return None

# Add logs from a set of docker commands and save it in a destination folder
def save_mixed_docker_command_logs(destination_folder: str):
  pathlib.Path(destination_folder).mkdir(parents=True, exist_ok=True)
  log_file_name = f"{destination_folder}docker.log"
  f = open(log_file_name, 'w')

  fish.write_cmd_output(f, swarmadmin.info(), "docker info")

  docker_object_types = ["node", "stack", "image", "service", "secret", "volume", "container"]
  filters = ["label=system=Coral"]

  for obj_type in docker_object_types:
    params = {
      "suppress_stdout": True,
      "all": True if obj_type == "container" else False,
      "filters": ["label=system=Coral"] if obj_type not in ["node", "stack"] else []
    }

    res = swarmadmin.ls(obj_type, **params)
    fish.write_cmd_output(f, res, res['cmd'])

  stdout_log = swarmadmin.ls("container", all=True, suppress_stdout=True, format="{{.ID}}", filters=["label=system=Coral", "status=exited"])
  ids_list = [y for y in (x.strip() for x in stdout_log["stdout"].splitlines()) if y]
  for id in ids_list: fish.write_cmd_output(f, fish.exec_cmd_live(f"docker logs {id}", print_stdout=False), f"docker logs {id}")
  f.close()

# Add logs from a specific docker service and save it in a destination folder
def save_docker_service_log(service_name: str, destination_folder: str):
  stdout_log = fish.exec_cmd(f"docker service logs {service_name}", True, True)
  try:
    pathlib.Path(destination_folder).mkdir(parents=True, exist_ok=True)
    log_file_name = f"{destination_folder}{service_name}.log"
    f = open(log_file_name, 'w')
    fish.write_cmd_output(f, stdout_log)
    f.close()
  except FileExistsError:
    #another service already saved the log. Just ignore.
    return None

# Remove Coral objects of the types in a given list
def remove(obj_types: list):
  obj_types = list(set(obj_types))

  if "all" in obj_types:
    remove(["services", "images", "containers", "volumes", "secrets", "stack"])
  else:
    if "services" in obj_types or "stack" in obj_types:
      # removing all of a stack's services also removes the stack itself
      remove_coral_objects("service")
    if "containers" in obj_types:
      remove_coral_objects("container")
    if "images" in obj_types:
      remove_coral_objects("image")
    if "volumes" in obj_types:
      remove_coral_objects("volume")
    if "secrets" in obj_types:
      remove_coral_objects("secret")

# Scale all Coral services to the given number of replicas
def scale_all_services(n_replicas: int, quiet: bool = False):
  coral_services = get_coral_objs("service", quiet=True, format_="{{.Name}}")

  if coral_services:
    coral_services_list = coral_services.split('\n')
    n_services = len(coral_services_list)

    # scale services one by one so progress can be displayed in stdout
    for i, service in enumerate(coral_services_list):
      # skip if service is already stopped/started
      res = swarmadmin.get_service_replicas(service)
      fish.handle(res)
      curr_replicas = int(res["stdout"])
      if n_replicas == 0 and curr_replicas == 0 or n_replicas == 1 and curr_replicas == 1:
        state = "stopped" if n_replicas == 0 else "running"
        if not quiet:
          log.info(f"{service} is already {state}. Skipping...")
          fish.print_progress_bar(i + 1, n_services, prefix=f"Progress:", suffix="Complete\n", length=50)      
        continue

      # TODO: check if service image needs to be pulled and warn user
      res = swarmadmin.scale([service], n_replicas, suppress_stdout=quiet, suppress_stderr=quiet, timeout=settings.get("scaling_timeout"))
      if not quiet: fish.print_progress_bar(i + 1, n_services, prefix=f"Progress:", suffix="Complete\n", length=50)
      fish.handle(res)

    if not quiet: log_stdout.info("")

    return 0
  else:
    return 1

# Log into Coral's Docker registry
def registry_login():
  resgistry = settings.get('docker_registry')

  log.info(f"Credentials for {resgistry}:")
  while True:
    try:
      swarmadmin.login(resgistry)
      break
    except Exception as e:
      log_file.warning("{0}: {1}".format(type(e).__name__, e))

# Pull all Coral Docker images by running 'docker-compose pull'
def pull_coral_images(docker_compose_path: str):
  res = swarmadmin.pull_images_from_compose(docker_compose_path)
  fish.handle(res)

# Start Coral by scaling all services to 1
def start(quiet: bool = False):
  # TODO: check if all Coral services exist
  if not quiet: log.info("Starting Coral...")
  status = scale_all_services(1)
  if not quiet and status == 0: log.info("Coral stack successfully started!")

  return status

# Start Coral by scaling all services to 0
def stop(quiet: bool = False):
  if not quiet: log.info("Stopping Coral...")
  status = scale_all_services(0, quiet=quiet)
  if not quiet and status == 0: log.info("Coral stack successfully stopped!")

  return status

# Retart Coral by scaling all services to 0 and then to 1
def restart():
  log.info("Restarting Coral...")
  status = stop(quiet=True)
  if status != 0: return status
  status = start(quiet=True)
  if status == 0: log.info("Coral stack successfully restarted!")

  return status

# Update Coral by pulling all Docker images
def update():
  question = "Coral will be stopped in order to perform the update. Do you wish to continue? (y/n) "
  answer = fish.valid_answer_from_prompt(question, valid_answers=settings.get("prompt_boolean_answers"))
  log_file.info(question + answer)

  if fish.user_prompt_yes(answer):
    docker_compose_path = settings.get("compose_path")
    original_compose_file = None

    log.info("Updating Coral Docker images...")

    # check if a current deployment is using dev images
    curr_depl_conf = deploy.get_curr_depl_config()
    if curr_depl_conf is not None:
      original_compose_file = fish.read_file(docker_compose_path)
      dev = curr_depl_conf["advanced"]["dev_images"]
      if dev: deploy.switch_to_dev_images(docker_compose_path) # switch to dev images

    try:
      registry_login()
      pull_coral_images(docker_compose_path)
    finally:
      if original_compose_file is not None:
        fish.write_file(original_compose_file, docker_compose_path)

    log_stdout.info("")
    log.info("Coral Docker images successfully updated!")

    curr_depl_conf = deploy.get_curr_depl_config()

    if (curr_depl_conf is None):
      log.info("Cannot start Coral. Please deploy first.")
    else:
      domain = curr_depl_conf["basic"]["domain"] # needed for logs after deployment
      deploy.prepare(skip_depl_config=True, is_update=True, docker_compose_path=docker_compose_path, domain=domain, email=None, cert_type=None, stack_name=None, no_prompt=True)
