CORAL_SETTINGS = {
  "name": "coral",
  "version": "<coral_version>",
  "email": "coral@lists.inesctec.pt",
  "docker_registry": "docker-registry.inesctec.pt",
  "conf": {
    "dir": "conf",
    "arg_parser": "arg_parser.json",
    "logger": "logger.conf",
    "stack": "stack.env",
    "deployment": "deployment.json"
  },
  "logs": {
    "dir": "logs",
    "coral": "coral.log",
    "docker": "docker.log",
    "logs_tmp_folder": {
      "coral": "logs/tmp/",
      "docker": "logs/tmp/",
      "agate": "logs/tmp/agate/",
      "mica": "logs/tmp/mica/",
      "mongodb": "logs/tmp/mongodb/",
      "apache": "logs/tmp/apache/",
      "opal": "logs/tmp/opal/",
      "rserver": "logs/tmp/rserver/",
      "opal-data": "logs/tmp/opal-data/",
      "opal-ids": "logs/tmp/opal-ids/",
      "drupal": "logs/tmp/mica-drupal/",
      "mica-drupal-data": "logs/tmp/mica-drupal-data/"
    }
  },
  "custom_apache": {
    "dir": "custom/apache/conf",
    "custom": "custom.conf",
    "central_rule": "\nInclude /etc/apache2/conf-available/central.conf\n"
  },
  "compose_path": "docker-compose.yml",
  "scaling_timeout": 10*60,
  "min_secret_len": 8,
  "progress_tracking_timeout": {
    "agate": 10*60,
    "opal": 10*60,
    "mica": 10*60,
    "mica-drupal": 10*60
  },
  "deployment_template": {
    "basic": {
      "domain": "localhost",
      "email": "example@localhost.com",
      "cert_type": "custom",
      "stack_name": "coral",
      "apps": ["agate", "opal", "mica", "mica-drupal"]
    },
    "advanced": {
      "advertise_addr": None,
      "http_proxy": None,
      "https_proxy": None,
      "no_port_binding": False,
      "dev_images": False,
      "central": False
    }
  },
  "cleanup_params": {
    "image": {
      "rm_confirmation_msg": "Any related services and containers will also be removed.",
      "all": True,
      "quiet": True,
      "format": "{{.ID}}\t{{.Repository}}",
      "filters":["label=system=Coral"],
      "force": True
    },
    "container": {
      "rm_confirmation_msg": "Any related services will also be removed.",
      "all": True,
      "quiet": True,
      "format": "{{.ID}}\t{{.Names}}",
      "filters":["label=system=Coral"],
      "force": True
    },
    "volume": {
      "rm_confirmation_msg": "This operation is irreversible! ALL DATA WILL BE LOST!\nAny related services and containers will also be removed.",
      "all": False,    
      "quiet": True,
      "format": "{{.Name}}\t{{.Driver}}",
      "filters":["label=system=Coral"],
      "force": True
    },
    "stack": {},
    "service": {
      "rm_confirmation_msg": "Any related containers will also be removed.",
      "all": False,    
      "quiet": True,
      "format": "{{.ID}}\t{{.Name}}",
      "filters":["label=system=Coral"],
      "force": False
    },
    "secret": {
      "rm_confirmation_msg": "This operation is irreversible! Your will lose access to the stack's applications.\nAny related services and containers will also be removed.",
      "all": False,    
      "quiet": True,
      "format": "{{.ID}}\t{{.Name}}",
      "filters":["label=system=Coral"],
      "force": False
    }
  },
  "prompt_boolean_answers": ["yes", "y", "no", "n"]
}

ASCII_LOGO = ("" +
" _____ ___________  ___   _     \n" +
"/  __ \  _  | ___ \/ _ \ | |    \n" +
"| /  \/ | | | |_/ / /_\ \| |    \n" +
"| |   | | | |    /|  _  || |    \n" +
"| \__/\ \_/ / |\ \| | | || |____\n" +
" \____/\___/\_| \_\_| |_/\_____/\n")

INTRO_TEXT = f"CORAL {CORAL_SETTINGS['version']}\nDeveloped by INESC TEC ({CORAL_SETTINGS['email']})\nPowered by OBiBa (obiba.org)\n"

def get_intro():
  return ASCII_LOGO + INTRO_TEXT

def get(setting_name):
  return CORAL_SETTINGS[setting_name]

def get_conf_file_path(conf_name):
  conf_dir = CORAL_SETTINGS["conf"]["dir"]
  conf_file_name = CORAL_SETTINGS["conf"][conf_name]
  return f"{conf_dir}/{conf_file_name}"

def get_custom_apache_conf_file_path():
  conf_dir = CORAL_SETTINGS["custom_apache"]["dir"]
  conf_file_name = CORAL_SETTINGS["custom_apache"]["custom"]
  return f"{conf_dir}/{conf_file_name}"

def get_log_file_path(log_name:str):
  logs_dir = CORAL_SETTINGS["logs"]["dir"]
  log_file_name = CORAL_SETTINGS["logs"][log_name]
  return f"{logs_dir}/{log_file_name}"

def get_log_tmp_file_path():
  logs_dir = CORAL_SETTINGS["logs"]["logs_tmp_folder"]["coral"]
  log_file_name = CORAL_SETTINGS["logs"]["coral"]
  return f"{logs_dir}/{log_file_name}"

def get_logs_tmp_folder(service_name:str):
  return CORAL_SETTINGS["logs"]["logs_tmp_folder"][service_name]
