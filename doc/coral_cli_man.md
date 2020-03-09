# The Coral CLI man page

> **NOTE**  
The information in this section can also be retrieved from the Coral CLI, by running: `sudo python3.6 coral.py -h`

### **Description**
The Coral CLI is the command line program used to deploy and manage the Coral Docker stack.  

### **Parameters**
The parameters accepted by the Coral CLI are divided into three groups: `Help`, `Deployment` and `Maintenance`:

- #### Help
  **-h**, **--help**  
  &emsp;&emsp;show help message and exit  
  **-v**, **--version**  
  &emsp;&emsp;print the version number

- #### Deployment
  **--deploy**  
  &emsp;&emsp;deploy a Coral stack (required for all the other deployment arguments)  
  **--domain** DOMAIN  
  &emsp;&emsp;`REQUIRED` specify a domain that points to this machine  
  **--email** EMAIL  
  &emsp;&emsp;`REQUIRED` specify a webmaster email  
  **--letsencrypt**  
  &emsp;&emsp;issue a Let's Encrypt certificate for the specified domain (letsencrypt.org)  
  **--stack-name** STACK_NAME  
  &emsp;&emsp;specify a name for the stack (for internal use by Docker)  
  **--addr** ADDR  
  &emsp;&emsp;specify an IP address, in case multiple network interfaces are available  
  **--http-proxy** HTTP_PROXY  
  &emsp;&emsp;specify an HTTP proxy address. Format: [http|https]://[ip|domain]:[port]  
  **--https-proxy** HTTPS_PROXY  
  &emsp;&emsp;specify an HTTPS proxy address. Format: [http|https]://[ip|domain]:[port]  
  **--no-port-binding**  
  &emsp;&emsp;disable the binding of ports 80 and 443 to the host  
  **--dev**  
  &emsp;&emsp;deploy using dev versions of Coral Docker images  
  **--test**  
  &emsp;&emsp;enable non-interactive deployment  

- #### Maintenance
  **--list** {services,images,containers,volumes,secrets,stack}  
  &emsp;&emsp;list Coral Docker objects  
  **--remove** {services,images,containers,volumes,secrets,stack,all} [{...} ...]  
  &emsp;&emsp;remove Coral Docker objects  
  **--start**  
  &emsp;&emsp;start all Coral services  
  **--stop**  
  &emsp;&emsp;stop all Coral services  
  **--restart**  
  &emsp;&emsp;restart all Coral services  
  **--update**  
  &emsp;&emsp;update the Coral Docker images  
