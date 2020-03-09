
""" Deploy the Coral Docker Stack. """

__author__ = "INESC TEC <coral@lists.inesctec.pt>"

import os, json, re, getpass, time, sys
from lib.util.logger import log, log_stdout, log_file
from lib.util import fish, swarmadmin
from lib import manage, settings

# Get the current deployment configuration, if available
def get_curr_depl_config(format: str = None):
  depl_conf_path = settings.get_conf_file_path("deployment")
  if os.path.exists(depl_conf_path):
    return fish.load_json(depl_conf_path)
  
  return None

# Check whether user wishes to use the current deployment configuration
def check_skip_depl_config(no_prompt: bool = False):
  curr_depl_conf = get_curr_depl_config()

  if curr_depl_conf is None: return False

  curr_depl_conf = json.dumps(curr_depl_conf, indent=2)
  log.info("Previous deployment configuration found:\n{0}".format(curr_depl_conf))

  if no_prompt:
    return True
  else:
    question = f"Do you wish to reuse the configuration above? (y/n) "
    answer = fish.valid_answer_from_prompt(question, valid_answers=settings.get("prompt_boolean_answers"))
    log_file.info(question + answer)

    return fish.user_prompt_yes(answer)

# Initialise Docker Swarm
def enable_swarm_mode(advertise_addr: str):
  log.info("Enabling Docker Swarm...")
  if swarmadmin.swarm_is_active():
    log.info("Docker Swarm is enabled")
  else:
    res = swarmadmin.init_docker_swarm(advertise_addr)
    fish.handle(res)

# Configure deployment parameters in JSON conf file
def config_depl_params(domain: str, email: str, cert_type: str, stack_name: str, advertise_addr: str = None, http_proxy: str = None, https_proxy: str = None, no_port_binding: bool = False, dev: bool = False, central: bool = False):
  log.info("Configuring deployment parameters...")

  depl_conf_path = settings.get_conf_file_path("deployment")
  depl_conf_template = settings.get("deployment_template")

  # set basic configurations
  basic_depl_conf = depl_conf_template["basic"]
  basic_depl_conf["domain"] = domain
  basic_depl_conf["email"] = email
  basic_depl_conf["cert_type"] = cert_type
  basic_depl_conf["stack_name"] = stack_name

  # set advanced configurations
  adv_depl_conf = depl_conf_template["advanced"]
  adv_depl_conf["advertise_addr"] = advertise_addr
  adv_depl_conf["http_proxy"] = http_proxy
  adv_depl_conf["https_proxy"] = https_proxy
  adv_depl_conf["no_port_binding"] = no_port_binding
  adv_depl_conf["dev_images"] = dev
  adv_depl_conf["central"] = central

  depl_conf = {
    "basic" : basic_depl_conf,
    "advanced": adv_depl_conf
  }

  fish.write_json(depl_conf, depl_conf_path, indent=2)

# Set env variables for the Coral stack using the deployment JSON conf file and the Coral settings
def set_env_vars():
  log.info("Setting environment variables...")

  depl_config = get_curr_depl_config()
  env_file_path = settings.get_conf_file_path("stack")

  fish.replace_regex(env_file_path, r"^(SERVER_SYSTEM_NAME=).*$", fr"\1{settings.get('name')}", multiline=True)
  fish.replace_regex(env_file_path, r"^(SERVER_SYSTEM_VERSION=).*$", fr"\g<1>{settings.get('version')}", multiline=True)
  fish.replace_regex(env_file_path, r"^(DOMAIN=).*$", fr"\1{depl_config['basic']['domain']}", multiline=True)
  fish.replace_regex(env_file_path, r"^(WEBMASTER_MAIL=).*$", fr"\1{depl_config['basic']['email']}", multiline=True)
  fish.replace_regex(env_file_path, r"^(CERT_TYPE=).*$", fr"\1{depl_config['basic']['cert_type']}", multiline=True)
  if depl_config['advanced']['advertise_addr'] is not None:
    fish.replace_regex(env_file_path, r"^(MICA_DOMAIN=).*$", fr"\g<1>{depl_config['advanced']['advertise_addr']}/pub", multiline=True)
    fish.replace_regex(env_file_path, r"^(BASE_URL=).*$", fr"\g<1>https://{depl_config['advanced']['advertise_addr']}/cat", multiline=True)
  else:
    fish.replace_regex(env_file_path, r"^(MICA_DOMAIN=).*$", fr"\1{depl_config['basic']['domain']}/pub", multiline=True)
    fish.replace_regex(env_file_path, r"^(BASE_URL=).*$", fr"\1https://{depl_config['basic']['domain']}/cat", multiline=True)
  if depl_config['advanced']['http_proxy'] is not None:
    fish.replace_regex(env_file_path, r"^((HTTP_PROXY|http_proxy)=).*$", fr"\1{depl_config['advanced']['http_proxy']}", multiline=True)
  if depl_config['advanced']['https_proxy'] is not None:
    fish.replace_regex(env_file_path, r"^((HTTPS_PROXY|https_proxy)=).*$", fr"\1{depl_config['advanced']['https_proxy']}", multiline=True)

# Get the central monitor URL from the .env configuration file
def get_central_monitor_url():

  env_var_central_monitor_url = "CENTRAL_MONITORING_URL"
  env_file_path = settings.get_conf_file_path("stack")

  result = fish.get_env_var_value(env_file_path, env_var_central_monitor_url)

  if (result == None):
    raise Exception(f"Required {env_var_central_monitor_url} param doesn't exist in {env_file_path}.")

  return result

# Check if monitoring is to be enabled
def check_central_mon(env_file_path: str, no_prompt: bool = False):
  log.info("Checking for central monitoring configuration...")
  central_mon_url = get_central_monitor_url()

  if (len(central_mon_url["value"]) == 0 ):
    log.warn(f"A central monitoring URL has not been defined in {env_file_path}, line {str(central_mon_url['index'] + 1)}.\nThe monitoring features described in the 'Coral Monitor Stack' section of README.md will be disabled.")
    
    if not no_prompt:
      question = "Do you wish to continue? (y/n) "
      answer = fish.valid_answer_from_prompt(question, valid_answers=settings.get("prompt_boolean_answers"))
      log_file.info(question + answer)

      if fish.user_prompt_no(answer):
        sys.exit(0)

    return False
  else:
    log.info(f"Using {central_mon_url['value']} for central monitoring...")
    return True

# Prompt user for secrets and create them
def prompt_secrets(secrets: list):
  log_stdout.info("Please provide the secrets below:")
  for secret_name in secrets:
    secret_content = getpass.getpass(prompt=f"  {secret_name}: ")
    min_secret_len = settings.get("min_secret_len")

    while len(secret_content) < min_secret_len:
      log.info(f"Secrets must use at least {min_secret_len} characters. Try again:")
      secret_content = getpass.getpass(prompt=f"  {secret_name}: ")

    swarmadmin.create_secret(secret_content, secret_name, "system=Coral")
  
  log_stdout.warn("\n\033[1;31mIf you forget your passwords, you will loose access to your data.\nIt is highly recommended that you also manually store the passwords somewhere else safe.\033[0m")
  input("Press Enter to continue...")

# Check if required secrets exist
def check_secrets(docker_compose_path: str, no_prompt: bool = False):
  log.info("Checking Coral secrets...")
  required_secrets = swarmadmin.get_objs_from_compose("secret", docker_compose_path)
  missing_secrets = list(filter(lambda x: not swarmadmin.obj_exists("secret", x), required_secrets))

  if len(missing_secrets) > 0:
    log.info("Some required secrets are missing")

    if no_prompt:
      raise Exception("When running in test mode, all secrets must be manually created beforehand.")
    else:
      prompt_secrets(missing_secrets)
  else:
    if not no_prompt:
      question = "All required secrets are defined. Do you wish to redefine them? (y/n) "
      answer = fish.valid_answer_from_prompt(question, valid_answers=settings.get("prompt_boolean_answers"))
      log_file.info(question + answer)

      if fish.user_prompt_yes(answer):
        manage.remove_coral_objects("secret", silent=True, list_found_objs=False, prompt=False)
        prompt_secrets(required_secrets)

# Append '-dev' to image tags of the compose file
def switch_to_dev_images(docker_compose_path: str):
  fish.replace_regex(docker_compose_path, r"(image:.*)$", r"\1-dev", multiline=True)

# Remove ports tag that bind ports to host in the compose file
def unbind_ports(docker_compose_path):
  fish.replace_regex(docker_compose_path, r"^\s*ports:\n.*80:80.*\n.*443:443.*$\n", "", multiline=True)

# def check_volumes():
  # TODO check volume directories exist

# Return path to docker-compose.override.yml (return None if file does not exist)
def get_compose_override_path(docker_compose_path):
  compose_full_path = os.path.abspath(docker_compose_path)
  compose_parent_dir = os.path.dirname(compose_full_path)
  docker_compose_override_path = f"{compose_parent_dir}/docker-compose.override.yml"
  if not os.path.exists(docker_compose_override_path):
      docker_compose_override_path = None

  return docker_compose_override_path

# Deploy the Coral Docker stack
def start(docker_compose_path: str, docker_compose_override_path: str, stack_name: str, enable_mon: bool):
  log.info("Deploying Coral...")
  swarmadmin.deploy_stack(docker_compose_path, docker_compose_override_path, stack_name)

  if (enable_mon):
    log_stdout.info("")
    log.info("Deploying Monitor stack...")
    swarmadmin.deploy_stack("./monitor/docker-compose.monitor.yml", None, f"{stack_name}_monitor")


def track_progress(stack_name, docker_compose_path):
  curr_depl_conf = get_curr_depl_config()
  apps = curr_depl_conf["basic"]["apps"]
  timeouts = settings.get("progress_tracking_timeout")
  addrs = {}

  for app in apps:
    service_name = f"{stack_name}_{app}"
    timeout = timeouts[app]

    curr_replicas = 0
    while curr_replicas < 1:
      res = fish.handle(swarmadmin.get_service_replicas(service_name))
      curr_replicas = int(res["stdout"])
      time.sleep(0.1)

    task_id = swarmadmin.get_task_id_from_service(service_name)
    container_id = swarmadmin.get_container_id_from_task(task_id)

    addr = ""
    while addr == "":
      try:
        addr = swarmadmin.get_container_addr_in_network(container_id, "docker_gwbridge")
        time.sleep(0.1)
      except:
        pass

    addrs[app] = addr

  return addrs

# Prepare for deployment
def prepare(skip_depl_config: bool, is_update: bool, docker_compose_path: str, domain: str, email: str, cert_type: str, stack_name: str, addr: str = None, http_proxy: str = None, https_proxy: str = None, no_port_binding: bool = False, dev: bool = False, no_prompt: bool = False, central: bool = False):
  env_file_path = settings.get_conf_file_path("stack")
  original_env_file = fish.read_file(env_file_path)
  original_compose_file = fish.read_file(docker_compose_path)
  deploy_monitor_stack = True

  try:
    if skip_depl_config:
      log.info("Skipping configuration of deployment parameters...")
      log_stdout.info("")
      curr_depl_conf = get_curr_depl_config()
      domain = curr_depl_conf["basic"]["domain"]
      stack_name = curr_depl_conf["basic"]["stack_name"]
      addr = curr_depl_conf["advanced"]["advertise_addr"]
      dev = curr_depl_conf["advanced"]["dev_images"]
      no_port_binding = curr_depl_conf["advanced"]["no_port_binding"]
      central = curr_depl_conf["advanced"]["central"]

    enable_swarm_mode(addr)
    log_stdout.info("")

    # remove any current Coral services
    if not is_update:
      log.info("Cleaning up any previously deployed Coral services...")
      manage.remove_coral_objects("service", list_found_objs=False, prompt=False)
      log_stdout.info("")

    # save deployment parameters
    if not skip_depl_config:
      config_depl_params(domain, email, cert_type, stack_name, addr, http_proxy, https_proxy, no_port_binding, dev, central)
      log_stdout.info("")

    # set environment variables using deployment perameters
    set_env_vars()
    log_stdout.info("")

    # check central monitoring
    deploy_monitor_stack = check_central_mon(env_file_path, no_prompt)
    log_stdout.info("")

    # make sure all required secrets exist (if not, prompt)
    check_secrets(docker_compose_path, no_prompt)
    log_stdout.info("")

    # temporarilly edit compose file to set dev images or unbind ports to host
    if dev: switch_to_dev_images(docker_compose_path)
    if no_port_binding: unbind_ports(docker_compose_path)

    # pull Coral images
    if not is_update:
      log.info("Pulling Coral Docker images...")
      manage.registry_login()
      manage.pull_coral_images(docker_compose_path)
      log_stdout.info("")

    # check_volumes()

    # deploy Coral
    docker_compose_override_path = get_compose_override_path(docker_compose_path)
    start(docker_compose_path, docker_compose_override_path, stack_name, deploy_monitor_stack)
    log_stdout.info("")

    # track progress
    #track_progress(stack_name, docker_compose_path)

    log.info("\033[1;32mCoral has been deployed!\033[0m")
    log_stdout.info("After a few minutes, you should have access to the following services:\n"
      f"  \033[1;37mAgate\033[0m\t\t https://{domain}/auth\n"
      f"  \033[1;37mOpal\033[0m\t​\t https://{domain}/repo\n"
      f"  \033[1;37mMica\033[0m\t​\t https://{domain}/pub\n"
      f"  \033[1;37mMica Drupal\033[0m\t ​https://{domain}/cat​ (or just ​https://{domain}​)\n"
    )
  finally:
    # restore original env and docker-compose files
    fish.write_file(original_env_file, env_file_path)
    fish.write_file(original_compose_file, docker_compose_path)

  return 0
