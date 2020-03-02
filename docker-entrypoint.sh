#!/bin/bash
#
# Adapted from https://github.com/docker-library/mongo by INESC TEC
# to remove lock files and change the authentication mechanism to MONGODB-CR
# before creating the user from the MONGO_INITDB_ROOT_USERNAME and
# MONGO_INITDB_ROOT_PASSWORD environment variables
#

set -Euo pipefail

echo "################### BEGIN MONGO DB DEFAULT SETUP #####################"

if [ "${1:0:1}" = '-' ]; then
	set -- mongod "$@"
fi

originalArgOne="$1"

remove_lock_files() {
	lockFiles=( "mongod.lock" "WiredTiger.lock" )

	for lockFile in "${lockFiles[@]}"
	do
		if [ -f /data/db/$lockFile ]; then
			echo "*** Removing $lockFile..."
			rm /data/db/$lockFile
			echo "$lockFile: EXIT CODE $?"
		fi
	done
}

# allow the container to be started with `--user`
# all mongo* commands should be dropped to the correct user
if [[ "$originalArgOne" == mongo* ]] && [ "$(id -u)" = '0' ]; then
	if [ "$originalArgOne" = 'mongod' ]; then
		chown -R mongodb /data/configdb /data/db /data/users
		remove_lock_files
	fi

	# make sure we can write to stdout and stderr as "mongodb"
	# (for our "initdb" code later; see "--logpath" below)
	chown --dereference mongodb "/proc/$$/fd/1" "/proc/$$/fd/2" || :
	# ignore errors thanks to https://github.com/docker-library/mongo/issues/149

	exec gosu mongodb "$BASH_SOURCE" "$@"
fi

# you should use numactl to start your mongod instances, including the config servers, mongos instances, and any clients.
# https://docs.mongodb.com/manual/administration/production-notes/#configuring-numa-on-linux
if [[ "$originalArgOne" == mongo* ]]; then
	numa='numactl --interleave=all'
	if $numa true &> /dev/null; then
		set -- $numa "$@"
	fi
fi

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# see https://github.com/docker-library/mongo/issues/147 (mongod is picky about duplicated arguments)
_mongod_hack_have_arg() {
	local checkArg="$1"; shift
	local arg
	for arg; do
		case "$arg" in
			"$checkArg"|"$checkArg"=*)
				return 0
				;;
		esac
	done
	return 1
}
# _mongod_hack_get_arg_val '--some-arg' "$@"
_mongod_hack_get_arg_val() {
	local checkArg="$1"; shift
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		case "$arg" in
			"$checkArg")
				echo "$1"
				return 0
				;;
			"$checkArg"=*)
				echo "${arg#$checkArg=}"
				return 0
				;;
		esac
	done
	return 1
}
declare -a mongodHackedArgs
# _mongod_hack_ensure_arg '--some-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_arg() {
	local ensureArg="$1"; shift
	mongodHackedArgs=( "$@" )
	if ! _mongod_hack_have_arg "$ensureArg" "$@"; then
		mongodHackedArgs+=( "$ensureArg" )
	fi
}
# _mongod_hack_ensure_no_arg '--some-unwanted-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_no_arg() {
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		if [ "$arg" = "$ensureNoArg" ]; then
			continue
		fi
		mongodHackedArgs+=( "$arg" )
	done
}
# _mongod_hack_ensure_no_arg '--some-unwanted-arg' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_no_arg_val() {
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		case "$arg" in
			"$ensureNoArg")
				shift # also skip the value
				continue
				;;
			"$ensureNoArg"=*)
				# value is already included
				continue
				;;
		esac
		mongodHackedArgs+=( "$arg" )
	done
}
# _mongod_hack_ensure_arg_val '--some-arg' 'some-val' "$@"
# set -- "${mongodHackedArgs[@]}"
_mongod_hack_ensure_arg_val() {
	local ensureArg="$1"; shift
	local ensureVal="$1"; shift
	_mongod_hack_ensure_no_arg_val "$ensureArg" "$@"
	mongodHackedArgs+=( "$ensureArg" "$ensureVal" )
}

# _js_escape 'some "string" value'
_js_escape() {
	jq --null-input --arg 'str' "$1" '$str'
}

jsonConfigFile="${TMPDIR:-/tmp}/docker-entrypoint-config.json"
tempConfigFile="${TMPDIR:-/tmp}/docker-entrypoint-temp-config.json"
_parse_config() {
	if [ -s "$tempConfigFile" ]; then
		return 0
	fi

	local configPath
	if configPath="$(_mongod_hack_get_arg_val --config "$@")"; then
		# if --config is specified, parse it into a JSON file so we can remove a few problematic keys (especially SSL-related keys)
		# see https://docs.mongodb.com/manual/reference/configuration-options/
		mongo --norc --nodb --quiet --eval "load('/js-yaml.js'); printjson(jsyaml.load(cat($(_js_escape "$configPath"))))" > "$jsonConfigFile"
		jq 'del(.systemLog, .processManagement, .net, .security)' "$jsonConfigFile" > "$tempConfigFile"
		return 0
	fi

	return 1
}
dbPath=
_dbPath() {
	if [ -n "$dbPath" ]; then
		echo "$dbPath"
		return
	fi

	if ! dbPath="$(_mongod_hack_get_arg_val --dbpath "$@")"; then
		if _parse_config "$@"; then
			dbPath="$(jq '.storage.dbPath' "$jsonConfigFile")"
		fi
	fi

	: "${dbPath:=/data/db}"

	echo "$dbPath"
}

mongodRunning=
_checkMongodIsRunning() {
	tries=30
	while true; do
		if ! { [ -s "$pidfile" ] && ps "$(< "$pidfile")" &> /dev/null; }; then
			# bail ASAP if "mongod" isn't even running
			echo >&2
			echo >&2 "error: $originalArgOne does not appear to have stayed running -- perhaps it had an error?"
			echo >&2
			mongodRunning=0
		fi
		if mongo 'admin' --eval 'quit(0)' &> /dev/null; then
			# success!
			mongodRunning=1
			break
		fi
		(( tries-- ))
		if [ "$tries" -le 0 ]; then
			echo >&2
			echo >&2 "error: $originalArgOne does not appear to have accepted connections quickly enough -- perhaps it had an error?"
			echo >&2
			mongodRunning=0
			break
		fi
		sleep 1
	done
}

if [ "$originalArgOne" = 'mongod' ]; then
	file_env 'MONGO_INITDB_ROOT_USERNAME'
	file_env 'MONGO_INITDB_ROOT_PASSWORD'
	# pre-check a few factors to see if it's even worth bothering with initdb
	shouldPerformInitdb=
	if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
		# if we have a username/password, let's set "--auth"
		_mongod_hack_ensure_arg '--auth' "$@"
		set -- "${mongodHackedArgs[@]}"
		shouldPerformInitdb='true'
	elif [ "$MONGO_INITDB_ROOT_USERNAME" ] || [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
		cat >&2 <<-'EOF'
			error: missing 'MONGO_INITDB_ROOT_USERNAME' or 'MONGO_INITDB_ROOT_PASSWORD'
			       both must be specified for a user to be created
		EOF
		exit 1
	fi

	if [ -z "$shouldPerformInitdb" ]; then
		# if we've got any /docker-entrypoint-initdb.d/* files to parse later, we should initdb
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh|*.js) # this should match the set of files we check for below
					shouldPerformInitdb="$f"
					break
					;;
			esac
		done
	fi

	# check for a few known paths (to determine whether we've already initialized and should thus skip our initdb scripts)
	if [ -n "$shouldPerformInitdb" ]; then
		dbPath="$(_dbPath "$@")"
		for path in \
			"$dbPath/WiredTiger" \
			"$dbPath/journal" \
			"$dbPath/local.0" \
			"$dbPath/storage.bson" \
		; do
			if [ -e "$path" ]; then
				shouldPerformInitdb=
				break
			fi
		done
	fi

	if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
		echo "*** MONGO_INITDB_ROOT_USERNAME ($MONGO_INITDB_ROOT_USERNAME) and MONGO_INITDB_ROOT_PASSWORD are defined."

		HOME=/data/users/$MONGO_INITDB_ROOT_USERNAME
		mkdir -p $HOME # to store the shell history file

		rootAuthDatabase='admin'

		pidfile="${TMPDIR:-/tmp}/docker-entrypoint-temp-mongod.pid"
		rm -f "$pidfile"

		echo "*** Running mongod..."
		mongod --bind_ip 127.0.0.1 --port 27017 -logpath /proc/1/fd/1 --pidfilepath $pidfile --fork
		
		_checkMongodIsRunning $pidfile

		if [ $mongodRunning == 1 ]; then
			echo "*** Checking if user $MONGO_INITDB_ROOT_USERNAME exists..."
			mongo -u $MONGO_INITDB_ROOT_USERNAME -p $MONGO_INITDB_ROOT_PASSWORD --authenticationDatabase $rootAuthDatabase --authenticationMechanism MONGODB-CR --eval "db.getUsers()" $rootAuthDatabase >/dev/null 2>&1
			shouldCreateUser=$?

			if [ $shouldCreateUser == 1 ]; then
				echo "*** User $MONGO_INITDB_ROOT_USERNAME does not exist."

				echo "*** Changing authentication mechanism to MONGODB-CR..."
				mongo "$rootAuthDatabase" <<-EOJS
					db.system.version.insert({ "_id" : "authSchema", "currentVersion" : 3 })
				EOJS

				echo "*** Creating user $MONGO_INITDB_ROOT_USERNAME on $rootAuthDatabase..."
				mongo "$rootAuthDatabase" <<-EOJS
					db.createUser({
						user: $(_js_escape "$MONGO_INITDB_ROOT_USERNAME"),
						pwd: $(_js_escape "$MONGO_INITDB_ROOT_PASSWORD"),
						roles: [ { role: 'root', db: $(_js_escape "$rootAuthDatabase") } ]
					})
				EOJS

				export MONGO_INITDB_DATABASE="${MONGO_INITDB_DATABASE:-test}"

				echo "*** Adding roles to user $MONGO_INITDB_ROOT_USERNAME on $rootAuthDatabase..."
				
				for f in /docker-entrypoint-initdb.d/*; do
					case "$f" in
						*.sh) echo "$0: running $f"; . "$f" ;;
						*.js) echo "$0: running $f"; mongo "$MONGO_INITDB_DATABASE" --eval "var username='$MONGO_INITDB_ROOT_USERNAME'; var password='$MONGO_INITDB_ROOT_PASSWORD'" "$f"; echo ;;
						*)    echo "$0: ignoring $f" ;;
					esac
					echo
				done
				
				mongo --eval "db.getUser('$MONGO_INITDB_ROOT_USERNAME')" $rootAuthDatabase

				echo "*** Successfully created user $MONGO_INITDB_ROOT_USERNAME on $rootAuthDatabase!"
			else
				echo "*** User $MONGO_INITDB_ROOT_USERNAME already exists. Skipping user creation..."
			fi
		else
			echo "*** [ERROR] Could not start mongod. Exiting..."
			exit 1
		fi

		"$@" --pidfilepath="$pidfile" --shutdown
		rm -f "$pidfile"		
	fi

	if [ -n "$shouldPerformInitdb" ]; then
		echo "*** Starting MongoDB initialization process..."
		mongodHackedArgs=( "$@" )
		# mongod --auth
		if _parse_config "$@"; then
			_mongod_hack_ensure_arg_val --config "$tempConfigFile" "${mongodHackedArgs[@]}"
		fi

		# mongod --auth
		_mongod_hack_ensure_arg_val --bind_ip 127.0.0.1 "${mongodHackedArgs[@]}"
		# mongod --auth --bind_ip 127.0.0.1
		_mongod_hack_ensure_arg_val --port 27017 "${mongodHackedArgs[@]}"
		# mongod --auth --bind_ip 127.0.0.1 --port 27017
		_mongod_hack_ensure_no_arg --bind_ip_all "${mongodHackedArgs[@]}"
		# mongod --auth --bind_ip 127.0.0.1 --port 27017

		# remove "--auth" and "--replSet" for our initial startup (see https://docs.mongodb.com/manual/tutorial/enable-authentication/#start-mongodb-without-access-control)
		# https://github.com/docker-library/mongo/issues/211
		_mongod_hack_ensure_no_arg --auth "${mongodHackedArgs[@]}"
		# mongod --bind_ip 127.0.0.1 --port 27017
		if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
			_mongod_hack_ensure_no_arg_val --replSet "${mongodHackedArgs[@]}"
		fi
		# mongod --bind_ip 127.0.0.1 --port 27017

		sslMode="$(_mongod_hack_have_arg '--sslPEMKeyFile' "$@" && echo 'allowSSL' || echo 'disabled')" # "BadValue: need sslPEMKeyFile when SSL is enabled" vs "BadValue: need to enable SSL via the sslMode flag when using SSL configuration parameters"
		_mongod_hack_ensure_arg_val --sslMode "$sslMode" "${mongodHackedArgs[@]}"

		if stat "/proc/$$/fd/1" > /dev/null && [ -w "/proc/$$/fd/1" ]; then
			# https://github.com/mongodb/mongo/blob/38c0eb538d0fd390c6cb9ce9ae9894153f6e8ef5/src/mongo/db/initialize_server_global_state.cpp#L237-L251
			# https://github.com/docker-library/mongo/issues/164#issuecomment-293965668
			#_mongod_hack_ensure_arg_val --logpath "/proc/$$/fd/1" "${mongodHackedArgs[@]}"
			_mongod_hack_ensure_arg_val --logpath "/dev/null" "${mongodHackedArgs[@]}"
		else
			#initdbLogPath="$(_dbPath "$@")/docker-initdb.log"
			initdbLogPath="/dev/null"
			echo >&2 "warning: initdb logs cannot write to '/proc/$$/fd/1', so they are in '$initdbLogPath' instead"
			_mongod_hack_ensure_arg_val --logpath "$initdbLogPath" "${mongodHackedArgs[@]}"
		fi
		_mongod_hack_ensure_arg --logappend "${mongodHackedArgs[@]}"

		pidfile="${TMPDIR:-/tmp}/docker-entrypoint-temp-mongod.pid"
		rm -f "$pidfile"
		_mongod_hack_ensure_arg_val --pidfilepath "$pidfile" "${mongodHackedArgs[@]}"

		# mongod --bind_ip 127.0.0.1 --port 27017 --sslMode disabled --logpath /proc/1/fd/1 --logappend --pidfilepath /tmp/docker-entrypoint-temp-mongod.pid
		"${mongodHackedArgs[@]}" --fork

		mongo=( mongo --host 127.0.0.1 --port 27017 --quiet )

		# check to see that our "mongod" actually did start up (catches "--help", "--version", MongoDB 3.2 being silly, slow prealloc, etc)
		# https://jira.mongodb.org/browse/SERVER-16292
		tries=30
		while true; do
			if ! { [ -s "$pidfile" ] && ps "$(< "$pidfile")" &> /dev/null; }; then
				# bail ASAP if "mongod" isn't even running
				echo >&2
				echo >&2 "error: $originalArgOne does not appear to have stayed running -- perhaps it had an error?"
				echo >&2
				exit 1
			fi
			if "${mongo[@]}" 'admin' --eval 'quit(0)' &> /dev/null; then
				# success!
				break
			fi
			(( tries-- ))
			if [ "$tries" -le 0 ]; then
				echo >&2
				echo >&2 "error: $originalArgOne does not appear to have accepted connections quickly enough -- perhaps it had an error?"
				echo >&2
				exit 1
			fi
			sleep 1
		done

		"$@" --pidfilepath="$pidfile" --shutdown
		rm -f "$pidfile"

		echo '*** MongoDB initialization process complete; ready for start up!'
	else
		echo "*** Skipping MongoDB initialization process..."
	fi

	# MongoDB 3.6+ defaults to localhost-only binding
	haveBindIp=
	if _mongod_hack_have_arg --bind_ip "$@" || _mongod_hack_have_arg --bind_ip_all "$@"; then
		haveBindIp=1
	elif _parse_config "$@" && jq --exit-status '.net.bindIp // .net.bindIpAll' "$jsonConfigFile" > /dev/null; then
		haveBindIp=1
	fi
	if [ -z "$haveBindIp" ]; then
		# so if no "--bind_ip" is specified, let's add "--bind_ip_all"
		set -- "$@" --bind_ip_all
	fi

	unset "${!MONGO_INITDB_@}"
fi

rm -f "$jsonConfigFile" "$tempConfigFile"

echo "################### END OF DEFAULT SETUP #####################"
echo
echo "*** Starting MongoDB..."
echo
exec "$@"
# $@: mongod --auth --bind_ip_all