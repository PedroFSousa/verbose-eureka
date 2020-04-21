# UPDATE

> **WARNING**  
Before updating to a new version, back up your volumes:  
`sudo zip -r volumes_backup.zip $(sudo docker info --format='{{.DockerRootDir}}')/volumes`

## 3.0.* -> 3.1.0
1. Copy your old configuration file:
    ```bash
    sudo cp <old_dist_dir>/conf/deployment.json <new_dist_dir>/conf/
    ```
1. Launch the stack:
    ```bash
    sudo python3.6 coral.py --deploy
    ```
    Answer `yes` when asked if you want to reuse the configuration file.

## 2.5.* -> 3.*.*
1. Remove your current stack and wait for services to stop
    ```
    sudo docker stack rm <YOUR_STACK_NAME>; sleep 20
    ```
    If you don't know the name of your stack, you can check it by running: `sudo docker stack ls`

1. Deploy Coral by executing:
    ```bash
    sudo python3.6 coral.py --deploy [PARAMETERS]
    ```
    The deployment configuration is now provided as parameters to the Coral CLI.  
    Read the [Deployment Configuration Parameters](README.md#Deployment-Configuration-Parameters) and [Deploying the Stack](README.md#Deploying-the-Stack) sections to learn how to build a deployment command with the same configuration you used before.

## 2.5.0 -> 2.5.1
1. Copy your old configuration file:
    ```bash
    sudo mkdir <new_dist_dir>/scripts/deployment/config
    sudo cp <old_dist_dir>/scripts/deployment/config/script_configs.txt <new_dist_dir>/scripts/deployment/config/
    ```
1. Launch the stack:
    ```bash
    cd <new_dist_dir>/scripts/deployment
    sudo python3.6 fresh_start.py
    ```
