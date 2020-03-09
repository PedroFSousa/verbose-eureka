# CHANGELOG

## 3.1.0
* **General**
  * Added feature that uses `cAdvisor`, `Node Exporter` and `Prometheus` to periodically send a status report to a central monitoring InfluxDB server (see the `Coral Monitor Stack` section in `README.md` for further details)
  * Added new `--logs` parameter to extract logs from Coral services (see the `Obtain Coral Logs` section in `README.md` for further details)
  * Updated `coral-apache-docker` image to version 1.3.6 (allows multiple domains and checks for existing Let's Encrypt SSL certificates before issuing a new one)
  * Updated `coral-opal-docker` image to version 1.3.5 (uses the `DSBASE_VERSION` environament)
  * Pass the `DSBASE_VERSION` environament variable (configured in `conf/stack.env`) to the Opal container to set the version of the `dsBase` DataSHIELD packages that will be installed
  * Updated `README.md` with introduction about Docker and with documentation about new features

* **Development**
  * Before generating the zip file for distribution, a series of integration tests are performed by running [coral-tester](https://gitlab.inesctec.pt/coral/coral-tester/) within GitLab CI
  * The zip file is then posted to the Coral deployment service to be published at https://coral.inesctec.pt

---

## 3.0.1
* Updated `coral-apache-docker` image to version 1.3.1 (disables TLSv1.0 and TLSv1.1)
* Updated `coral-mica-drupal-docker` image to version 1.1.2 (updates PHP version to 7.3.11)

---

## 3.0.0
* Major restructuring of Python scripts:
  * there is only one main script (`coral.py` &ndash; the Coral CLI), which is now used to execute all commands
  * deployment configuration is now performed by passing parameters to the CLI
  * in addition to the previously existing deployment options, added the option to not bind the 80 and 443 ports to the host)
  * deployment configuration is stored in `deployment.json`
  * added management parameters to start, stop, restart, remove, list and update Coral
  * added help and version parameters
* main libraries are more modular and generic:
  * fish.py: for executing shell commands
  * swarmadmin.py: for executing Docker commands
  * deploy.py: to deploy Coral
  * manage.py: to execute Coral management commands
* Grouped all Coral configurations in settings.py
* Output of CLI is now timestamped and logged to a file (rotated)
* Added checks for execution permission level and Python version
* Do not allow dots in stack name
* Pull images before deploying stack (so that they are correctly tagged)
* Use 'git archive' instead of zip for artifacts
* Exclude dotfiles from zip artifact
* For RHEL and CentOS, dockerd options are now set in `daemon.json`, which makes them persistent
* Updated `coral-agate-docker` image to version 1.2.2 (fixes setting of admin pwd when respective secret is changed)
* Updated `coral-opal-docker` image to version 1.3.4 (fixes setting of admin pwd when respective secret is changed; updates Opal to version 2.15)
* Updated `coral-mica-docker` image to version 1.3.4 (fixes setting of admin pwd when respective secret is changed)
* Updated README

---

## 2.5.1
* Updated `coral-mica-drupal-docker` version to 1.1.1
* Updated `coral-opal-docker` to 1.3.1
* Renamed modules; Restructured scripts dir; Added docsrings
* Validate advertise IP address
* Added `CHANGELOG.md` and `UPDATE.md`

---

## 2.5.0 
Note: forked from [recap-docker-dist](https://gitlab.inesctec.pt/RECAP/recap-docker) v2.4.8
* Remove all recap-specific configurations
* Remove unnecessary RECAP references
* Use agnostic docker images in docker-compose.yml
* Base URLs are now changed dynamically
* Fix path in zip artifact
* Include version in zip artifact
* Update readme
