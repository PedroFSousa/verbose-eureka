
""" Functions for logging messages. """

__author__ = "INESC TEC <coral@lists.inesctec.pt>"

import sys, logging, logging.config
from .. import settings

# Configure the logger
conf_file_path = settings.get_conf_file_path("logger")
log_file_path = settings.get_log_file_path("coral")

logging.config.fileConfig(
  fname=conf_file_path,
  defaults={"logfilename": log_file_path},
  disable_existing_loggers=False
)

app_name = "coral"
log = logging.getLogger(app_name)
log_stdout = logging.getLogger(app_name + "Stdout")
log_file = logging.getLogger(app_name + "File")
